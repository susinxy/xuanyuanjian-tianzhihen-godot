# 阴影 P2 柔边设计：Line2D 朝外羽化裙边

> 版本：v1.0
> 日期：2026-09-04
> 状态：已确认设计，待实施
> 前置：`SHADOW_REDESIGN_PLAN.md`（P0 polygon 投影）、P1 距离衰减（`FAR_END_ALPHA` + `vertex_colors`）
> 关联：本文实现阴影渲染迭代的 P2（软边缘）

---

## 1. 背景与目标

P0/P1 后，角色阴影已是"ShadowBox 轮廓沿光线投影到地面 → 单个 `Polygon2D` 填充 + 逐顶点距离衰减"。遗留问题是 **polygon 填充是硬边**：剪影边界只有 1px 抗锯齿级别的过渡，缺少真实影子的柔和 penumbra（早期 SDF ray-march 时代"白送"的软，在改成投影后丢了）。

**P2 目标**：在不牺牲性能（目标机 Intel UHD）的前提下，给阴影边缘加上朝外的柔和羽化。

**硬约束（性能优先）**：不得引入逐像素距离场/模糊核、不得引入离屏 RT / 额外渲染 pass、不得回到已弃用的 SDF 通道。

---

## 2. 方案选型

| 方案 | 做法 | 否决理由 |
|------|------|----------|
| 引擎 2D 光阴影（LightOccluder2D + PCF5/13） | 打开 Light2D 阴影 | 与自定义投影阴影模型冲突；工程当前 `shadow/enabled=false`；大范围 PCF 成本高；推翻既定设计 |
| SDF ray-march / 逐像素高斯（如 TABmk） | 片元里采样/嵌套循环 | 正是 P0 为性能**特意抛弃**的路线 |
| SubViewport 模糊 | 渲进 RT + 可分离模糊 | 额外 RT + pass，破坏共享材质 batching，2.5D y-sort/透明排序复杂化，弱卡风险高 |
| **Line2D 朝外羽化裙边（选定）** | 轮廓边缘贴一条跨宽度 alpha 渐变的带 | 见下，唯一在效果/性能/架构契合上全面占优 |

**Line2D 原理**：Line2D 是一条**有宽度的四边形带（ribbon）**，GPU 仍按三角形画。它自动生成的 UV 中，一条轴**横跨带宽**（0→1，两侧边缘→中心）。给这条带贴/算一个"跨宽度 alpha 帐篷（sin）"渐变，光栅化时每像素按其横向位置采样 → 带子沿宽度方向渐隐 = 软边。这是几何带 + 逐像素 alpha，**无额外几何/无 RT/无循环**。

---

## 3. 已确认的设计决策

1. **软边模型**：边缘实、只朝外羽化。实现方式：软边 `Line2D` 画在实心 `Polygon2D` **下方**（z_index 更低），其朝内一半被实心遮住，只露朝外那半 → 干净的朝外羽化，**无叠色变深环**。
2. **羽化宽度** `FEATHER_PX := 6.0` 起步（朝外可见宽度；F5 调）。Line2D `width = 2*FEATHER_PX`，带心压在轮廓上。
3. **跳跃淡出统一**：`fade` 从 `_shadow_polygon.modulate.a` 上移到 `ShadowRenderer` 自身 `modulate.a`，使实心 + 软边一起淡。
4. **跨宽度 alpha 由解析式 shader 生成**（不运行时生成纹理）：新建 `shadow_edge.gdshader`，用跨宽度 UV 轴取 `sin` 帐篷。
5. **颜色单一源**：抽出 `const SHADOW_COLOR`，实心/软边两材质共用，消除颜色漂移。

---

## 4. 实现细节

### 4.1 新建 `shaders/shadow_edge.gdshader`
```glsl
shader_type canvas_item;
render_mode unshaded;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.05, 0.55);

void fragment() {
    float across = UV.y;                 // 跨宽度轴；首跑若方向不对改 UV.x
    float tent = sin(across * PI);       // 0(边)→1(中心)→0(边)
    COLOR = vec4(shadow_color.rgb, shadow_color.a * COLOR.a * tent);
}
```
- 进入片元的 `COLOR.a` 已含 `vertex_color.a(=P1 距离衰减) × modulate.a(=跳跃 fade)`（Godot canvas_item 语义：COLOR = 顶点色 × modulate × self_modulate）。
- 故软边 alpha = `shadow_color.a × P1 × fade × tent`；实心 alpha = `shadow_color.a × P1 × fade`。二者同基、仅差 `tent`，在带心（压在轮廓、tent=1）处连续，无接缝突变。

### 4.2 改 `scripts/character_shadow_controller.gd`
- 常量区新增：`SHADOW_EDGE_SHADER_PATH`、`SHADOW_COLOR`、`FEATHER_PX`；把 `:38` 的字面量 `Color(...)` 改引用 `SHADOW_COLOR`。
- 新增 `static var _edge_material: ShaderMaterial = null` 与 `var _shadow_edge: Line2D = null`。
- `_setup_shared_material()`：追加构建 `_edge_material`（null 守卫、共享、`shadow_color = SHADOW_COLOR`）。
- `_create_shadow_polygon()`：先建 `_shadow_edge`（`Line2D`：`material=_edge_material`、`width=2*FEATHER_PX`、`joint_mode=ROUND`、`close=true`、`default_color=WHITE`、`z_index=-1`），再建实心（`z_index=0`）。
- `_update_shadow()`：`projected.size()>0` 时，实心与软边**同时**赋 `polygon/points = projected`、`vertex_colors = colors`；`fade` 改为赋 `modulate.a`（自身）。
- `_project_polygon_to_ground()` 与 `_get_*` **不变**。

---

## 5. 性能

- 相比 P1 态，增量 = 多一个 `Line2D` draw call + 朝外一圈 `FEATHER_PX` 宽的填充 + 每像素一次 `sin`。
- `points`/`vertex_colors` 每帧只是引用已算好的投影数组。
- **无 Clipper / 无纹理生成 / 无 RT / 无逐像素循环**。满足"性能优先"。

---

## 6. 风险与首跑必验点

1. **跨宽度 UV 轴**：若首跑羽化方向错（羽化跑到端帽而非侧边）→ `shadow_edge.gdshader` 里 `UV.y` 改 `UV.x`。
2. **接缝细线**：实心边与带心相接，可能有极细不连续 → 令 `width` 略增（重叠半 px）或微调 `SHADOW_COLOR.a`；通常不可见。
3. **凹角断缝**：`joint_mode=ROUND` 保证转角不断带。
4. **DEBUG 覆盖层**：`fade` 上移后 dev 轮廓也会随跳淡——仅调试可见，可忽略。
5. **烘焙自交**：软边闭合环依赖轮廓已规整（`contour_tracer` 的 `_make_simple_largest`），坏帧自交已消除，带子不会自叠。

---

## 7. 测试 / 回退 / 提交

- **验证**：本机 headless 仅能验"无脚本错误 / 材质与 Line2D 构建成功"；**软边观感与 `FEATHER_PX` 调参必须 Windows F5**（观察：边缘朝外柔化、随距离淡、跳起整体淡、无叠色环/无断缝）。
- **可叠加**：④ 2D MSAA（工程设置，逐几何边去 1px 锯齿）作锦上添花，独立可关。
- **回退**：仅涉 1 新 shader + 1 脚本改动；`git checkout scripts/character_shadow_controller.gd` + 删 `shaders/shadow_edge.gdshader` 即回到 P1 态。
- **提交**：`feat: 阴影 P2 柔边（Line2D 朝外羽化裙边）`。

---

## 8. 后续（非本轮）
- B 模型：penumbra 随离脚底距离变宽（真·半影），Line2D 支持逐点 `width` 曲线，可作后续升级。
- 阴影与墙体/台阶坡度的渲染顺序（P5，SHADOW_REDESIGN_PLAN 已暂缓）。
