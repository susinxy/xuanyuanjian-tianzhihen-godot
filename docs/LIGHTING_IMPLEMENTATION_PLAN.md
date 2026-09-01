# 天之痕 ARPG 光影系统实施计划

> 版本：v1.0  
> 创建日期：2026-09-01  
> 状态：待实施

---

## 一、系统概述

### 1.1 目标

为天之痕 ARPG 实现完整的 2D 光影系统，包括：
- 角色动态阴影（随动画帧、光源方向、跳跃高度变化）
- 昼夜循环系统（场景默认时间段 + 剧情/法术触发切换 + 可选自动循环）
- 建筑/静态物体阴影（通过 LightOccluder2D）
- 全局环境光控制（CanvasModulate）
- 环境点光源（PointLight2D：灯笼、火把等）

### 1.2 技术方案总结

| 层级 | 内容 | 实现方式 |
|------|------|---------|
| L0 | 手绘背景光影 | 美术工作，不涉及代码 |
| L1 | CanvasModulate 全局色调 | 场景配置 + DayNightManager 控制 |
| L2 | DirectionalLight2D 主光源 | 关闭内置 shadow，配合 SDF shader |
| L2 | 建筑阴影 | LightOccluder2D（手动配置 polygon） |
| L3 | PointLight2D 环境光源 | 场景配置（灯笼、火把等） |
| L4 | 角色阴影 | LightOccluder2D + SDF Ray Marching Shader |
| L5 | 昼夜循环 | DayNightManager + DayNightController |

### 1.3 核心技术选型

**角色阴影方案：LightOccluder2D + 2D SDF Shader**

- 复用项目已有的轮廓检测工具（contour_tracer.gd）生成阴影 polygon
- 通过 animation track 逐帧驱动 OccluderPolygon2D.polygon（与 HurtShape 同机制）
- 关闭 DirectionalLight2D 的内置 shadow（因为无限长阴影是 Godot 4.x 已知限制）
- 用自定义 shader 读取 Godot 自动生成的 2D SDF 纹理，做有限长度的 ray marching 阴影
- 阴影长度、角度、柔和度通过 shader uniform 参数化

**参考来源**：jess-hammer/2d-shadows-demo-godot（MIT 协议，Godot 4.3+）

### 1.4 光源方向参数设计：方位角 + 仰角（非 3D 向量）

**设计决策**：光源方向用两个独立角度表示，而非单一 3D 方向向量 `(lx, ly, lz)`。

| 参数 | 含义 | 用途 | 来源 |
|------|------|------|------|
| **Azimuth（方位角）** | 光源在 2D 屏幕上的水平方向 | 控制阴影的**指向** | `DirectionalLight2D.rotation` |
| **Elevation（仰角）** | 光源在地平线以上的垂直角度 | 控制阴影的**长度** | DayNightManager 按相位配置 |

**示例**：
- 白天（DAY）：方位角 = -45°（右上方），仰角 = 45°（中等高度）
- 黎明（DAWN）：方位角 = -70°（右侧），仰角 = 20°（很低）→ 影子很长
- 正午：方位角 = 0°（正上方），仰角 = 90°（头顶）→ 影子很短

**为什么不用单一 3D 向量？**

数学上，3D 方向向量 `(lx, ly, lz)` 完全包含方位角和仰角的信息（可互相转换）。但本设计选择分离两个角度，原因：

| 维度 | 方位角 + 仰角 | 3D 向量方案 |
|------|--------------|------------|
| **语义清晰度** | ✅ 直接表达 2.5D 本质（2D 屏幕 + 高度） | ❌ 隐藏 2.5D 语义 |
| **配置直观性** | ✅ 美术可直接配置"黎明太阳在右侧，仰角 20°" | ❌ 需理解 `(0.94, -0.34, 0.34)` |
| **实现复杂度** | ✅ 简单，无额外计算 | ❌ 需要反三角函数（`atan2`, `atan`） |
| **独立控制** | ✅ 阴影方向和长度可独立变化 | ⚠️ 修改向量需同时影响两个属性 |

**结论**：当前项目的昼夜循环是简化的相位系统，不需要真实物理模拟。分离两个角度是更清晰、更实用的选择。

---

## 二、SDF 阴影 Shader 详细设计

### 2.1 SDF 原理

SDF（Signed Distance Field，有符号距离场）是一张纹理，每个像素存储"到最近遮挡物边缘的距离"：
- 黑色（0）= 在遮挡物内部或边缘
- 灰色 = 离遮挡物有一定距离
- 白色（1）= 离遮挡物很远

Godot 4.x 内置此功能：当 LightOccluder2D 的 `sdf_collision = true`（默认开启）时，引擎每帧自动将所有 occluder polygon 栅格化为 SDF 纹理。shader 可通过 `texture_sdf()` 和 `screen_uv_to_sdf()` 内置函数读取。

### 2.2 Shader 代码

```glsl
shader_type canvas_item;
render_mode unshaded;

// ── 阴影外观 ──
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.1, 0.4);
// color.rgb = 阴影颜色
// color.a   = 阴影最大深度（0=完全透明，1=完全不透明）

// ── 光源方向 ──
// angle 定义：光源在屏幕上的方位角（度）
//   0° = 光源在屏幕正上方 → 阴影向下投射
//  90° = 光源在屏幕正右方 → 阴影向左投射
// 135° = 光源在右上方    → 阴影向左下方投射（默认）
// 180° = 光源在正下方    → 阴影向上投射
// 270° = 光源在正左方    → 阴影向右投射
//
// 与 DirectionalLight2D.rotation_degrees 的映射：
//   shader_angle = fmod(light_rotation + 180.0, 360.0)
uniform float angle : hint_range(0.0, 360.0) = 135.0;

// ── 阴影长度上限 ──
// max_dist = 阴影最大长度（SDF 空间单位），超过此距离的阴影被截断
// 由 GDScript 根据"参考角色身高"和光源仰角动态计算后传入
// 
// 物理含义：max_dist 基于当前角色的 physical_height 计算
// （多 ShadowRenderer 方案：每个角色独立计算自己的 max_dist）
// 计算公式（在 GDScript 中）：
//   physical_height = 当前角色的身高（屏幕像素，由 AnimationPlayer track 每帧更新）
//   tan_elev = tan(太阳仰角)
//   shadow_pixels = physical_height / tan_elev
//   sdf_scale = ProjectSettings.rendering/2d/sdf/scale
//   max_dist = shadow_pixels * sdf_scale
//
// 注意：max_dist 只控制阴影长度上限，不影响实际阴影长度
// 实际阴影长度由 occluder 几何位置决定（ray march 碰到 occluder 时 break）
uniform float max_dist : hint_range(0.0, 1000.0) = 100.0;

// ── 阴影柔和度（gradientTexture 未配置时的 fallback）──
// 0.0 = 最柔和（线性过渡，淡出区间最长）
// 1.0 = 硬边缘（阶跃过渡，无淡出）
// 原理：smoothstep(0, max(0.001, 1-softness), alpha)，softness 越大过渡区间越窄
uniform float softness : hint_range(0.0, 1.0) = 0.4;

// ── 渐变纹理（可选，配置后覆盖 softness）──
uniform sampler2D gradientTexture;

void fragment() {
    // 角度转方向向量
    float ang_rad = angle * 3.1416 / 180.0;
    vec2 dir = vec2(sin(ang_rad), cos(ang_rad));

    // 当前像素的 SDF 坐标
    vec2 at = screen_uv_to_sdf(SCREEN_UV);

    // Ray Marching
    // d = texture_sdf(at) 返回从当前位置到最近 occluder 边缘的距离
    // 远离 occluder 时 d 很大（一步跳远），接近时 d 很小（一步逼近）
    // 正常情况步数约 8-15 步，由 max_dist 保证循环必然终止
    float accum = 0.0;
    while (true) {
        float d = texture_sdf(at);
        accum += d;
        if (d < 0.01) {
            break;  // 碰到 occluder 边缘
        }
        if (accum >= max_dist) {
            break;  // 超过阴影长度上限
        }
        at += d * dir;
    }

    // 计算基础透明度
    float ratio = clamp(accum / max_dist, 0.0, 1.0);
    float alpha = 1.0 - ratio;

    // 柔和度处理
    // 先尝试 gradientTexture，未配置时 fallback 到 softness
    vec4 grad_sample = texture(gradientTexture, vec2(alpha, 0.5));
    if (grad_sample.r > 0.99) {
        // 未配置纹理（默认 1x1 白色纹理，采样值=1.0）→ 用 softness
        alpha = smoothstep(0.0, max(0.001, 1.0 - softness), alpha);
    } else {
        // 配置了有效渐变纹理 → 用纹理
        alpha = grad_sample.r;
    }

    // 最终输出
    COLOR = vec4(color.rgb, alpha * color.a);
}
```

### 2.3 与原版的差异

| 项目 | 原版 | 调整后 | 理由 |
|------|------|--------|------|
| gradientTexture | 必须配置 | 可选，softness 作为 fallback | 降低初始配置门槛 |
| PI 精度 | 3.1416 | 保持 3.1416 | 改动无实际意义 |
| max_dist 文档 | 无 | 完整注释 | 明确单位和换算 |
| 角度约定 | 无文档 | 完整注释 + 映射公式 | 避免方向混淆 |

### 2.4 Ray Marching 原理详解

#### SDF 纹理的含义

SDF（Signed Distance Field）纹理是 Godot 自动生成的，每个像素存储"到最近 occluder 边缘的距离"：

```
OccluderPolygon2D 内部/边缘：d ≈ 0
OccluderPolygon2D 外部：      d = 到最近边缘的距离（越大离得越远）
```

#### `d` 的值如何决定步长

```glsl
float d = texture_sdf(at);  // 从当前位置到最近 occluder 边缘的距离
accum += d;                  // 累计已走过的距离
at += d * dir;               // 向光源方向跳 d 个单位
```

**关键点**：每步跳的距离 = 该位置的 `d` 值

- 远离 occluder 时：`d` 很大（50、100）→ 一步跳远
- 接近 occluder 时：`d` 很小（0.5、0.1）→ 一步逼近
- 碰到 occluder 时：`d < 0.01` → break

#### Ray march 过程示例

从每个屏幕像素出发，沿"指向光源"的方向逐步前进：

```
步骤1: 采样 SDF → d = 50（离最近遮挡物 50 像素）
  → 向光源方向跳 50 像素（50 像素内肯定没有遮挡物）
  → accum = 50

步骤2: 新位置采样 → d = 20
  → 跳 20 像素
  → accum = 70

步骤3: 新位置采样 → d = 0.005（< 0.01）
  → 碰到了遮挡物！break
  → accum = 70.005

alpha = 1.0 - 70.005 / max_dist
→ 如果 max_dist=100 → alpha ≈ 0.3（中等阴影）
→ 如果 max_dist=200 → alpha ≈ 0.65（深阴影）
```

#### 典型步数

正常情况下的典型步数约 8-15 步：
- 远离 occluder 时大步跨越（2-3 步）
- 接近 occluder 时小步逼近（5-10 步）
- 碰到 occluder 时 break

循环必然终止，因为 `accum` 每步至少增加 `d`（`d ≥ 0`），最终必然 `accum >= max_dist`。

#### `d < 0.01` 的 break 条件

`d` 不会精确等于 0（浮点精度），所以用 0.01 作为阈值——当 ray 足够接近 occluder 边缘时，认为"碰到了"，停止 marching。这个阈值越小，阴影边缘越精确，但可能需要更多步数逼近。

#### SDF 精度与 `d` 的关系

```
sdf_scale = 0.5（50%）：
  SDF 纹理分辨率 = 视口分辨率 × 0.5
  1 个 SDF 单位 = 2 个屏幕像素
  d = 50 SDF 单位 = 100 屏幕像素

sdf_scale = 1.0（100%）：
  1 个 SDF 单位 = 1 个屏幕像素
  d = 50 SDF 单位 = 50 屏幕像素
  精度更高，但 SDF 纹理更大（GPU 开销增加）
```

### 2.5 跳跃阴影偏移的自动处理

SDF ray marching 的几何关系自然处理跳跃偏移，不需要手动计算：

```
角色在地面：
  LightOccluder2D 在地面位置
  地面像素 ray march → 很快碰到 occluder → 阴影在角色附近

角色跳起 h 像素（Skin.position.y = -h）：
  LightOccluder2D 跟着 AnimatedSprite2D 上移 h 像素
  地面像素 ray march 向光源方向 → 需要走更远才碰到空中的 occluder
  → accum 更大 → alpha 更小 → 阴影更淡
  → 阴影位置自然偏移（偏移量 = h / tan(光源仰角)）
```

### 2.6 所有光源方向验证

| 时间段 | 视觉效果 | Light rotation | Shader angle | dir 方向 | 阴影方向 | 验证 |
|--------|---------|---------------|-------------|---------|---------|------|
| 默认/白天 | 右上方 45° | -45° | 135° | (0.7, -0.7) | 左下方 | ✅ |
| 黎明 | 右侧低角度 | -70° | 110° | (0.94, -0.34) | 左侧偏上 | ✅ |
| 正午 | 近乎头顶 | 0° | 180° | (0, -1) | 正下方 | ✅ |
| 黄昏 | 左侧低角度 | 70° | 250° | (-0.94, -0.34) | 右侧偏上 | ✅ |
| 夜晚月光 | 左上方 | 45° | 225° | (-0.7, -0.7) | 右下方 | ✅ |

**边界情况**：光源几乎水平时，阴影很长，需要 max_dist 足够大。在 GDScript 中根据仰角动态计算 max_dist 解决。

### 2.7 性能分析

**CPU 端**（polygon 更新）：
- animation track 每帧写入 PackedVector2Array → 触发 OccluderPolygon2D.set_polygon()
- 调用链：`set_polygon() → RenderingServer.canvas_occluder_polygon_set_shape() → 标记 dirty`
- 开销与 HurtShape（CollisionPolygon2D）的 CPU 端几乎相同

**GPU 端**（SDF + shader）：
- SDF 生成：Godot 引擎自动，GPU 并行，开销固定
- Shader 渲染：逐像素 ray marching，开销 = 屏幕像素数 × 平均步数

**与 HurtBox 物理碰撞的性能对比**：

| | CollisionPolygon2D（HurtBox） | OccluderPolygon2D（ShadowBox） |
|---|---|---|
| 计算位置 | CPU | GPU |
| 复杂度 | O(N² × V)（N=物体数，V=顶点数） | O(屏幕像素)（与物体数无关） |
| 10 个角色 | 45 对 × 多边形求交 → 慢 | 屏幕像素固定，不随角色增多变慢 |
| 性质 | 物理碰撞检测（串行） | 图形渲染（GPU 并行） |

#### 方案 A：全屏单 Shader（参考基线）

| 视口分辨率 | SDF 像素数 | 平均步数 | 总采样数 | 中端 GPU 耗时 | 集显耗时 |
|-----------|-----------|---------|---------|-------------|---------|
| 720p (1280×720) | 230K | ~8 | ~1.8M | ~5ms ✅ | ~12ms ✅ |
| 900p (1600×900) | 360K | ~8 | ~2.9M | ~8ms ✅ | ~19ms ⚠️ |
| 1080p (1920×1080) | 518K | ~8 | ~4.1M | ~11ms ✅ | ~27ms ❌ |

#### 方案 B：多 ShadowRenderer 平行四边形（实际采用）

每角色 ShadowRenderer 覆盖平行四边形区域（典型物理宽度 66px + margin，阴影长度 ~180px），面积约 12K 像素。

| 角色数 | 总像素数 | 平均步数 | 总采样数 | Draw Call 数 | Draw Call 开销 | Shader 耗时(集显) | 总耗时(集显) |
|--------|---------|---------|---------|-------------|---------------|-----------------|-------------|
| 1 | 12K | ~8 | ~96K | 1 | ~0.05ms | ~1ms | ~1ms ✅ |
| 5 | 60K | ~8 | ~480K | 5 | ~0.25ms | ~5ms | ~5ms ✅ |
| 10 | 120K | ~8 | ~960K | 10 | ~0.5ms | ~10ms | ~10ms ✅ |
| 20 | 240K | ~8 | ~1.9M | 20 | ~1.0ms | ~19ms | ~20ms ⚠️ |

**Draw Call 开销分析**（基于业界实测数据）：
- 桌面 GPU 每帧 Draw Call 预算：2000-5000（完全无压力）
- 每次 Draw Call CPU 固定开销：12-50μs（含驱动验证、状态切换）
- 10 个 ShadowRenderer = 10 次 Draw Call ≈ 0.5ms → 可忽略
- Godot 4.x 中 Polygon2D 不参与自动 batching（Godot 源码确认），每次独立 Draw Call

**SDF 纹理生成开销**（两种方案共同）：
- Godot 每帧自动将所有 LightOccluder2D 栅格化为 SDF 纹理
- 开销与 occluder 数量相关，与 ShadowRenderer 数量无关
- 典型开销 1-3ms（GPU），是两种方案的共同固定开销

**结论**：多 ShadowRenderer 方案在 10 角色同屏时，集显上总耗时约 10ms（含 SDF 生成），满足 60fps 的 16.67ms 预算。桌面端完全无压力。

**当前项目视口为 1280×720**，所有 GPU 均可流畅运行。
窗口大小不影响性能（stretch/mode="canvas_items" 只缩放显示，不增加计算量）。

---

## 三、角色阴影节点设计

### 3.1 多 ShadowRenderer 架构（核心决策）

**每个角色拥有独立的 ShadowRenderer（Polygon2D）**，在 `QuiverCharacter._ready()` 中动态创建。

**设计理由**：
- 解决 2.5D 空气阴影问题：阴影只出现在角色脚底附近的地面区域，不会出现在天空或角色身边的空气中
- GPU 效率高：每角色 ~12K 像素 vs 全屏 921K 像素（节省约 50 倍）
- 每角色的 `max_dist` 基于自身的 `physical_height`，高角色阴影长，矮角色阴影短
- 性能与全屏单 Shader 方案相当（详见 2.7 节性能分析）

### 3.2 节点层级

```
Characters 容器 (y_sort_enabled = true)
├── CharacterBody2D (position.y = ground_level，跳跃时不变)
│   ├── Collision (CollisionShape2D)
│   ├── Skin (QuiverCharacterSkinAnimTree) ← 跳跃时 position.y 变负
│   │   ├── AnimatedSprite2D (position = (0, -96))
│   │   │   ├── HurtBox (Area2D)
│   │   │   │   └── HurtShape (CollisionPolygon2D) ← polygon track 驱动
│   │   │   └── ShadowBox (LightOccluder2D) ← 新增，与 HurtBox 同级
│   │   │       └── occluder: OccluderPolygon2D ← polygon track 驱动
│   │   └── Attacks/
│   ├── ShadowRenderer (Polygon2D) ← 动态创建，z_index = -1
│   │   └── material: ShaderMaterial(shadow_sdf.gdshader)
│   └── StateMachine/
```

**关键设计**：
- ShadowRenderer 是 CharacterBody2D 的子节点（不是 Skin 的子节点）
- CharacterBody2D 始终在地面（跳跃时不变）→ ShadowRenderer 固定在地面
- ShadowBox 是 Skin 的子节点 → 跳跃时跟着上移到空中
- SDF ray marching 从地面像素向光源方向走 → 碰到空中的 ShadowBox → 阴影自然偏移+淡化

### 3.3 y_sort 绘制顺序

```
Characters 容器 (y_sort_enabled = true) 中的绘制顺序：

角色 A (y=500, 远处)：
  z=-1 → ShadowRenderer → 先画（阴影在地面）
  z=0  → 角色精灵        → 后画（覆盖阴影）

角色 B (y=600, 近处)：
  z=-1 → ShadowRenderer → 再后画
  z=0  → 角色精灵        → 最后画

结果：
  A 的阴影在 A 的精灵下面 ✅
  A 的阴影在 B 的精灵下面 ✅（A.y=500 < B.y=600，先画）
  B 的阴影在 B 的精灵下面 ✅
  B 的阴影不在 A 的精灵下面 ✅（B.y=600 > A.y=500，后画）
```

### 3.4 LightOccluder2D 配置

```
LightOccluder2D:
  sdf_collision = true（默认，生成 SDF 用）
  occluder_light_mask = 1
  visible = false（编辑器中可选显示/隐藏）

OccluderPolygon2D（子资源）:
  closed = true（默认）
  cull_mode = CULL_DISABLED（对闭合多边形无效，不需要设置）
  polygon = PackedVector2Array(...)（由 track 驱动）
```

### 3.5 跳跃偏移的自动处理

```
地面状态：
  Skin.position.y = 0
  CharacterBody2D.position.y = ground_level
  ShadowRenderer.position.y = 0（相对于 CharacterBody2D）
  → ShadowRenderer 在世界空间 y = ground_level
  → 阴影正常出现在脚底以下 ✅

跳跃状态：
  Skin.position.y = -100（上移 100px）
  CharacterBody2D.position.y = ground_level（不变）
  ShadowRenderer.position.y = 0（相对于 CharacterBody2D，不变）
  → ShadowRenderer 仍在世界空间 y = ground_level
  → ShadowBox（在 Skin 下）跟着上移到空中
  → ray march 从地面像素向光源方向走 → 碰到空中的 ShadowBox → 阴影自然偏移+淡化 ✅

不需要任何额外代码处理跳跃偏移。
```

### 3.6 ShadowRenderer Polygon 形状：平行四边形算法

ShadowRenderer 的 polygon 不是固定矩形，而是**根据光源方向和角色尺寸动态计算的平行四边形**。

#### 算法

```
输入：
  center_x ≈ 0（CharacterBody2D 原点 = 角色左右中心）
  lowest_y = 0（CharacterBody2D 原点 = 角色脚底）
  physical_width = _skin.physical_width（每帧 AnimationPlayer 更新）
  physical_height = _skin.physical_height（每帧 AnimationPlayer 更新）
  light_direction = 光源方向向量（从 DayNightManager 获取）
  elevation = 光源仰角（从 DayNightManager 获取）

计算：
  shadow_dir = -light_direction（阴影方向 = 光源反方向）
  shadow_length = physical_height / tan(elevation)
  shadow_length = clamp(shadow_length, 30, 600)
  dx = shadow_dir.x × shadow_length
  dy = shadow_dir.y × shadow_length
  margin = BASE_MARGIN + (1 - softness) × shadow_length × 0.1
  half_w = physical_width / 2 + margin

4 个顶点（CharacterBody2D 本地坐标）：
  top_left:     (-half_w, -margin)
  top_right:    (half_w, -margin)
  bot_right:    (half_w + dx, dy + margin)
  bot_left:     (-half_w + dx, dy + margin)
```

#### 各光源方向示例

```
正午（elevation=90°，光源正上方）：
  shadow_dir ≈ (0, +1)
  shadow_length ≈ 30（最小值）

  (-33, 0) ──── (33, 0)
    │              │
  (-33, 30) ─── (33, 30)     ← 几乎正下方的短矩形

白天（elevation=45°，光源右上方）：
  shadow_dir ≈ (-0.7, +0.7)
  shadow_length ≈ 180

  (-33, 0) ──── (33, 0)
      \               \
       \               \
  (-159, 126) ── (-93, 126)  ← 向左下方倾斜的平行四边形

黎明（elevation=20°，光源右侧低角度）：
  shadow_dir ≈ (-0.94, +0.34)
  shadow_length ≈ 495

  (-33, 0) ──── (33, 0)
        \                    \
         \  很长的平行四边形    \
          \                    \
  (-498, 168) ────── (-432, 168)

光源在下方（如营火，光源近处地面）：
  shadow_dir ≈ (0, -1)  → dy 为负
  → 平行四边形向上延伸（远处地面）
  → 在 2.5D 中 y 减小方向 = 远处地面 = 合理 ✅
  → 不需要对 dy 做 clamping
```

#### margin 计算

margin 防止阴影柔和边缘被平行四边形边界裁剪：

```
shader 中的 alpha 淡出：
  smoothstep(0, 1-softness, alpha)
  → softness 越大，淡出区间越窄
  → softness 越小，淡出区间越宽

margin = BASE_MARGIN(20px) + (1 - softness) × shadow_length × 0.1

示例（softness=0.4, shadow_length=200）：
  margin = 20 + 0.6 × 200 × 0.1 = 20 + 12 = 32px
```

#### 性能对比

```
平行四边形方案：
  每角色面积约 12K 像素（以 physical_width=66, shadow_length=180 为例）
  10 角色 = 120K 像素

全屏单 Shader：
  921K 像素（1280×720 全屏）

平行四边形节省约 87% 的 GPU 采样量。
```

**Draw Call 开销**：
- Polygon2D 在 Godot 4.x 中不参与自动 batching（Godot 源码 `rasterizer_canvas_gles3.cpp` 确认）
- 10 个 ShadowRenderer = 10 次独立 Draw Call
- 每次 Draw Call 的 CPU 固定开销约 12-50μs（含驱动验证、状态切换）
- 10 次 ≈ 0.1-0.5ms → 桌面端完全可忽略
- 桌面 GPU 每帧 Draw Call 预算为 2000-5000，10 次远在预算内
- 所有 ShadowRenderer 共用同一个 shader（shadow_sdf.gdshader），GPU 不需要切换 shader program

**SDF 纹理生成是共同开销**：
- Godot 每帧自动将所有 LightOccluder2D 栅格化为 SDF 纹理
- 与 ShadowRenderer 数量无关，只与 occluder 数量相关
- 两种方案的 SDF 生成开销相同（典型 1-3ms GPU）

**详细性能数据见 Section 2.7。**

### 3.7 character_shadow_controller.gd

这个脚本在 `QuiverCharacter._ready()` 中动态创建并挂载到 ShadowRenderer (Polygon2D) 上：

```gdscript
extends Polygon2D

## 角色阴影控制器
## 由 QuiverCharacter._ready() 动态创建
## 管理：polygon 形状（平行四边形）+ shader 参数更新

const SHADOW_SHADER_PATH := "res://shaders/shadow_sdf.gdshader"
const DEFAULT_MAX_DIST := 100.0
const DEFAULT_ANGLE := 135.0
const BASE_MARGIN := 20.0
const MIN_ELEVATION := 5.0
const MAX_SHADOW_LENGTH := 600.0
const MIN_SHADOW_LENGTH := 30.0
const DEFAULT_ELEVATION := 45.0

var _material: ShaderMaterial
var _skin: QuiverCharacterSkin
var _day_night: Node
var _softness: float = 0.4

func setup(skin: QuiverCharacterSkin) -> void:
    _skin = skin
    _day_night = get_node_or_null("/root/DayNightManager")
    _setup_material()
    _update_polygon()

func _setup_material() -> void:
    _material = ShaderMaterial.new()
    _material.shader = preload(SHADOW_SHADER_PATH)
    _material.set_shader_parameter("max_dist", DEFAULT_MAX_DIST)
    _material.set_shader_parameter("angle", DEFAULT_ANGLE)
    _material.set_shader_parameter("softness", _softness)
    material = _material

func _process(_delta: float) -> void:
    if not _material:
        return
    _update_shadow_params()
    _update_polygon()

func _update_shadow_params() -> void:
    if not _day_night:
        return
    if not _day_night.has_method("get_sun_elevation_deg"):
        return

    var elevation := _day_night.get_sun_elevation_deg()
    var azimuth := _day_night.get_sun_azimuth_deg()

    var shader_angle := fmod(azimuth + 180.0, 360.0)
    _material.set_shader_parameter("angle", shader_angle)

    var ph: float = _skin.physical_height if _skin else 180.0
    var tan_elev := tan(deg_to_rad(max(elevation, MIN_ELEVATION)))
    var shadow_pixels := ph / tan_elev
    shadow_pixels = clamp(shadow_pixels, MIN_SHADOW_LENGTH, MAX_SHADOW_LENGTH)

    var sdf_scale: float = ProjectSettings.get_setting(
        "rendering/2d/sdf/scale", 0.5)
    _material.set_shader_parameter("max_dist", shadow_pixels * sdf_scale)

func _update_polygon() -> void:
    var pw: float = _skin.physical_width if _skin else 66.0
    var ph: float = _skin.physical_height if _skin else 180.0

    var elevation := _get_current_elevation()
    var shadow_dir := _get_shadow_direction()

    var tan_elev := tan(deg_to_rad(max(elevation, MIN_ELEVATION)))
    var shadow_len := ph / tan_elev
    shadow_len = clamp(shadow_len, MIN_SHADOW_LENGTH, MAX_SHADOW_LENGTH)

    var dx := shadow_dir.x * shadow_len
    var dy := shadow_dir.y * shadow_len

    var margin := BASE_MARGIN + (1.0 - _softness) * shadow_len * 0.1
    var half_w := pw / 2.0 + margin

    polygon = PackedVector2Array([
        Vector2(-half_w, -margin),
        Vector2(half_w, -margin),
        Vector2(half_w + dx, dy + margin),
        Vector2(-half_w + dx, dy + margin),
    ])

func _get_current_elevation() -> float:
    if _day_night and _day_night.has_method("get_sun_elevation_deg"):
        return _day_night.get_sun_elevation_deg()
    return DEFAULT_ELEVATION

func _get_shadow_direction() -> Vector2:
    if _day_night and _day_night.has_method("get_sun_azimuth_deg"):
        var azimuth := _day_night.get_sun_azimuth_deg()
        var shader_angle := fmod(azimuth + 180.0, 360.0)
        var ang_rad := shader_angle * PI / 180.0
        var light_dir := Vector2(sin(ang_rad), cos(ang_rad))
        return -light_dir
    return Vector2(-0.7, 0.7).normalized()
```

### 3.8 QuiverCharacter._ready() 中的动态创建

在 `quiver_character.gd` 的 `_ready()` 末尾添加：

```gdscript
# 在 _ready() 末尾（现有代码之后）添加：
    _create_shadow_renderer()

# 新增常量和方法：
const SHADOW_CONTROLLER_SCRIPT := preload(
    "res://scripts/character_shadow_controller.gd")

func _create_shadow_renderer() -> void:
    var sr := Polygon2D.new()
    sr.name = "ShadowRenderer"
    sr.z_index = -1
    sr.set_script(SHADOW_CONTROLLER_SCRIPT)
    add_child(sr)
    sr.setup(_skin)
```

**执行时机**：`QuiverCharacter._ready()` → 子节点角色脚本的 `_ready()` → 游戏开始。所有 Autoload（包括 DayNightManager）在 `_ready()` 之前创建完毕，所以 `get_node_or_null("/root/DayNightManager")` 在 `setup()` 中一次性查找即可。

### 3.9 ShadowRenderer 生命周期

```
创建：
  QuiverCharacter._ready()
    → _create_shadow_renderer()
      → Polygon2D.new() → set_script() → add_child() → setup(_skin)

每帧更新：
  character_shadow_controller._process()
    → _update_shadow_params()：从 DayNightManager 读取角度/仰角 → 更新 shader 参数
    → _update_polygon()：根据 physical_width/height + 光源方向 → 更新平行四边形

跳跃时：
  CharacterBody2D.position.y 不变 → ShadowRenderer 固定在地面
  Skin.position.y 变负 → ShadowBox 上移到空中
  → SDF ray marching 自然产生偏移阴影 ✅

销毁：
  CharacterBody2D 被 queue_free() → 子节点 ShadowRenderer 自动销毁
```

---

## 四、轮廓检测工具扩展

### 4.1 目标

在现有的 body 轮廓转换流程中，同时为 LightOccluder2D 的 OccluderPolygon2D 注入 polygon track。

### 4.2 核心问题：OccluderPolygon2D 只暴露一个属性

现有工具支持三种碰撞形状类型（Polygon / Capsule / Rectangle），但 OccluderPolygon2D **只有 `polygon: PackedVector2Array` 属性**，没有 position / rotation / shape:size / shape:radius 等子属性。

#### 现有三种形状类型的 track 格式对比

| 形状类型 | HurtShape 节点类型 | Track 数量 | Track 属性 |
|----------|-------------------|-----------|-----------|
| **Polygon** | `CollisionPolygon2D` | 3 | `:polygon` + `:position`(固定0) + `:rotation`(固定0) |
| **Capsule** | `CollisionShape2D` | 4 | `:shape:radius` + `:shape:height` + `:position`(动态) + `:rotation`(动态) |
| **Rectangle** | `CollisionShape2D` | 3 | `:shape:size` + `:position`(动态) + `:rotation`(动态) |

#### 问题：Capsule / Rectangle 无法直接映射到 OccluderPolygon2D

- Capsule 用 `:shape:radius` + `:shape:height` 参数化 → OccluderPolygon2D 没有这些属性
- Rectangle 用 `:shape:size` + `:position` + `:rotation` 参数化 → OccluderPolygon2D 没有这些属性

#### 解决方案：ShadowBox 始终使用原始 polygon 顶点

**关键发现**：现有流水线中，**所有形状类型都是先生成 polygon，再从 polygon 推导 Capsule/Rectangle**。

`frame_info` 同时包含所有形状的数据：
```
{
  "contours": Array[PackedVector2Array],   ← ShadowBox 取这里
  "capsule": { "center", "radius", "height", "angle" },
  "rectangle": { "size", "angle" },
  "mabr": { "center", "size", "angle", "area", "corners" },
  ...
}
```

ShadowBox 直接使用 `frame_info["contours"]`（原始 polygon 顶点），**不经过 MABR/Capsule/Rectangle 转换**，写入 OccluderPolygon2D.polygon。

### 4.3 现有完整数据流（含行号）

```
PNG 文件
  ↓ [_scan_frames_contours, line 278]
  ↓ 调用 ContourTracer.trace_contours(simplify_tolerance, min_area_ratio, erosion_radius)
  ↓   → bitmap → opaque_to_polygons(simplify_tolerance) → raw_contours
raw_contours: Array[PackedVector2Array]（像素坐标）
  ↓
  ↓ [后处理 7a — category 特有字段, line 415]
  ↓   Body: physical_height, width（从 raw_contours 像素坐标计算）
  ↓   Attack: attack_heights（从 raw_contours 像素坐标计算）
  ↓
  ↓ [后处理 7b — 坐标变换, lines 418-421]
  ↓   pixels_to_shape_local(raw, img_w, img_h)
contours: Array[PackedVector2Array]（shape-local 坐标）  ← ShadowBox 数据源
  ↓
  ↓ [后处理 7c — MABR/Capsule/Rectangle, lines 424-431]
  ↓   calc_mabr(local_contours[0]) → mabr
  ↓   calc_capsule_from_mabr(mabr) → capsule
  ↓   rectangle = { size: mabr.size, angle: mabr.angle }
  ↓
  ↓ [清理, line 433]
  ↓   erase("raw_contours")
最终 frame_info
  ↓
  ↓ [_inject_all_tracks → _get_track_value, lines 1219-1283]
  ↓   根据 shape_type 选择写入 tracks：
  ↓     POLYGON → :polygon + :position(固定0) + :rotation(固定0)
  ↓     CAPSULE → :shape:radius + :shape:height + :position + :rotation
  ↓     RECTANGLE → :shape:size + :position + :rotation
Animation track keyframes
```

**`simplify_tolerance` 和 `min_area_ratio` 使用位置**：
- `animation_track_injector.gd` line 278：传给 `ContourTracer.trace_contours()`
- `contour_tracer.gd` line 65：`bitmap.opaque_to_polygons(rect, simplify_tolerance)`
- `contour_tracer.gd` line 63：`min_area = true_rect面积 * min_area_ratio`

**`erosion_radius` 使用位置**：
- `animation_track_injector.gd` line 397：**仅对非 POLYGON 类型生效**，POLYGON 强制为 0
- `contour_tracer.gd` lines 52-53：在 bitmap 空间执行形态学腐蚀，收缩 alpha 区域

### 4.4 扩展后的完整数据流（新增 ShadowBox 双扫描）

```
PNG 文件
  ↓
  ↓ [Body 扫描 — _scan_frames_contours, line 278]
  ↓ 参数：simplify_tolerance, min_area_ratio, erosion_radius
  ↓   → raw_contours（像素坐标）
  ↓   → physical_height, width, attack_heights（从 raw_contours 计算）
  ↓   → pixels_to_shape_local() → contours（shape-local 坐标）
  ↓   → MABR → capsule / rectangle
  ↓
  ↓ [Shadow 扫描 — 新增, 仅 body category]
  ↓ 参数：shadow_simplify_tolerance, shadow_min_area_ratio, erosion_radius=0
  ↓   → shadow_raw_contours（像素坐标）
  ↓   → pixels_to_shape_local() → shadow_contours（shape-local 坐标）
  ↓   ← 不执行 MABR/Capsule/Rectangle 转换
  ↓   ← 不计算 physical_height/width
  ↓
  ↓ [清理]
  ↓   erase("raw_contours")
  ↓   erase("shadow_raw_contours")
最终 frame_info 包含：
  {
    "contours": Array[PackedVector2Array],        ← HurtShape tracks（按 shape_type 选择）
    "shadow_contours": Array[PackedVector2Array], ← ShadowBox track（始终使用）
    "capsule": { ... },
    "rectangle": { ... },
    "mabr": { ... },
    "physical_height": float,
    "width": float,
    "attack_heights": Array[float],
    ...
  }
  ↓
  ↓ [_inject_all_tracks]
  ↓   HurtShape tracks: 按 shape_type 选择（polygon / capsule / rectangle）
  ↓   ShadowBox track: 始终使用 frame["shadow_contours"][0]
  ↓     → AnimatedSprite2D/ShadowBox:occluder:polygon
Animation track keyframes
```

### 4.5 为什么需要双扫描（独立简化参数）

阴影 polygon 和碰撞 polygon 有不同的需求：

| 用途 | 精度要求 | simplify_tolerance 默认值 | 典型顶点数 |
|------|---------|-------------------------|-----------|
| 碰撞 (HurtShape) | 高（影响游戏逻辑） | 100 | 10-20 |
| 阴影 (ShadowBox) | 低（视觉效果） | 150 | 4-8 |

更大的 `simplify_tolerance` = 更少的顶点 = 更小的 SDF 栅格化开销。

由于简化参数在 `_scan_frames_contours()` 阶段（`ContourTracer.trace_contours()` 调用）就影响了 polygon 生成，不能在后处理阶段调整。因此需要**两次独立扫描**：
- Body 扫描：body 参数
- Shadow 扫描：shadow 参数

**注意**：这是 authoring-time 操作（用户点击"轮廓转换"按钮时执行），不影响运行时性能。多一次扫描的额外时间可忽略。

### 4.6 ShadowBox 与 body shape_type 的关系

**ShadowBox track 注入与 body 选择的 shape_type 完全无关。**

无论 body 选择 Polygon / Capsule / Rectangle：
- HurtShape tracks 按 shape_type 选择写入方式（现有逻辑不变）
- ShadowBox track 始终使用 `frame["shadow_contours"][0]`，写入 `:occluder:polygon`

| Body shape_type | HurtShape tracks | ShadowBox track |
|----------------|-----------------|----------------|
| Polygon | `:polygon` + `:position` + `:rotation` | `:occluder:polygon`（shadow_contours） |
| Capsule | `:shape:radius` + `:shape:height` + `:position` + `:rotation` | `:occluder:polygon`（shadow_contours） |
| Rectangle | `:shape:size` + `:position` + `:rotation` | `:occluder:polygon`（shadow_contours） |

### 4.7 需要修改的文件和位置

#### 文件 1：`animation_track_injector.gd`

**修改点 A：新增常量**
```gdscript
const SHADOW_OCCLUDER_PATH := "AnimatedSprite2D/ShadowBox"
```

**修改点 B：`_convert_contours_common()` 中增加 shadow 扫描**

在 `_scan_frames_contours()` 调用之后（line 398-401 之后），对 body category 增加第二次扫描：

```gdscript
# 5.5 Shadow 扫描（仅 body category）
var shadow_frames_data: Dictionary = {}
if category == "body":
    # Shadow 扫描：复用大部分参数，仅替换 simplify_tolerance、min_area_ratio，erosion_radius=0
    shadow_frames_data = await _scan_frames_contours(
        sprite_frames,
        alpha_threshold,              # 复用 body 参数
        shadow_simplify_tolerance,    # 新增参数，默认 150
        shadow_min_area_ratio,        # 新增参数，默认 0.2
        relevant_anims,               # 复用 body 参数
        unified_filter,               # 复用 body 参数
        category,                     # 复用 body 参数（mask_suffix）
        callback_obj,                 # 复用 body 参数
        result.errors,                # 复用 body 参数
        0                             # erosion_radius=0，阴影不需要腐蚀
    )
```

在后处理循环中（line 407-434 的后处理循环内），将 shadow_contours 合并到 frames_data：

```gdscript
# 在 7c. MABR/Capsule/Rectangle 计算之后，7d. 清理之前
if category == "body" and shadow_frames_data.has(sprite_anim_name) and shadow_frames_data[sprite_anim_name].has(frame_idx):
    var shadow_frame: Dictionary = shadow_frames_data[sprite_anim_name][frame_idx]
    var shadow_raw: Array = shadow_frame["raw_contours"]
    
    # 坐标变换（与 body contours 相同的逻辑）
    var shadow_local: Array[PackedVector2Array] = []
    for contour in shadow_raw:
        shadow_local.append(ContourTracer.pixels_to_shape_local(
            contour, img_w, img_h
        ))
    
    # 写入当前帧的 frame 字典
    frame["shadow_contours"] = shadow_local
```

**修改点 C：新增 `_ensure_shadow_occluder_exists()` 方法**

在 body 轮廓转换时，确保场景树中存在 LightOccluder2D 节点：
```gdscript
func _ensure_shadow_occluder_exists(skin_node: Node) -> void:
    var anim_sprite := skin_node.get_node("AnimatedSprite2D")
    var occluder := anim_sprite.get_node_or_null("ShadowBox")
    if occluder == null:
        occluder = LightOccluder2D.new()
        occluder.name = "ShadowBox"
        occluder.sdf_collision = true
        var occ_poly := OccluderPolygon2D.new()
        occ_poly.closed = true
        occluder.occluder = occ_poly
        anim_sprite.add_child(occluder)
        occluder.owner = skin_node.owner
```

**修改点 D：`_inject_all_tracks()` 中调用 ShadowBox track 注入**

在共享 tracks 区域（line 1196-1200 附近），`_inject_physical_height_track()` 调用之后，增加 ShadowBox track 注入：

```gdscript
# 共享 tracks
if category == "body":
    _inject_width_track(anim, frame_dict, sprite_fps)
    _inject_physical_height_track(anim, frame_dict, sprite_fps)
    _inject_shadow_occluder_track(anim, frame_dict, sprite_fps, flip_track_data)  # 新增
    anim_modified = true
```

**修改点 E：新增 `_inject_shadow_occluder_track()` 方法**

与 `_inject_width_track()`、`_inject_physical_height_track()` 同模式的方法：

```gdscript
func _inject_shadow_occluder_track(
    anim: Animation,
    frame_dict: Dictionary,
    sprite_fps: float,
    flip_track_data: Array
) -> void:
    var track_path := SHADOW_OCCLUDER_PATH + ":occluder:polygon"
    var track_idx := _find_or_add_value_track(anim, track_path)
    anim.track_set_interpolation_type(track_idx, Animation.INTERPOLATION_NEAREST)
    anim.value_track_set_update_mode(track_idx, Animation.UPDATE_DISCRETE)
    
    var frame_duration: float = 1.0 / max(1.0, sprite_fps)
    
    for frame_idx in frame_dict:
        var frame_info: Dictionary = frame_dict[frame_idx]
        var shadow_contours: Array = frame_info.get("shadow_contours", [])
        if shadow_contours.is_empty():
            continue
        
        var polygon: PackedVector2Array = shadow_contours[0]
        var time: float = float(frame_idx) * frame_duration
        var is_flipped := _is_flipped_at_time(flip_track_data, time)
        if is_flipped:
            polygon = _mirror_polygon_x(polygon)
        
        anim.track_insert_key(track_idx, time, polygon)
```

**关键设计**：
- 复用 `sprite_fps` 参数，内部计算 `frame_duration`（与现有方法一致）
- 复用 `_is_flipped_at_time()` 和 `_mirror_polygon_x()`（现有 flip 处理逻辑）
- 复用 `_find_or_add_value_track()`（现有 track 管理方法）
- 不需要发明新的时间计算方法

#### 文件 2：`height_layers_widget.gd`

**修改点 A：新增 shadow 参数 UI 控件**

在 Body 轮廓转换面板中增加 shadow 专用参数（与现有 body 参数并列）：
```gdscript
# shadow_simplify_tolerance（默认 150）
var shadow_tolerance_spinbox := SpinBox.new()
shadow_tolerance_spinbox.min_value = 1.0
shadow_tolerance_spinbox.max_value = 500.0
shadow_tolerance_spinbox.value = 150.0  # 默认值，比 body 的 100 更大

# shadow_min_area_ratio（默认 0.2）
var shadow_area_spinbox := SpinBox.new()
shadow_area_spinbox.min_value = 0.01
shadow_area_spinbox.max_value = 1.0
shadow_area_spinbox.step = 0.05
shadow_area_spinbox.value = 0.2  # 默认值，比 body 的 0.3 更小
```

**修改点 B：传递参数给 `_convert_contours_common()`**

在"Body 轮廓转换"按钮回调中，收集 shadow 参数并传递：
```gdscript
var shadow_simplify_tolerance: float = shadow_tolerance_spinbox.value
var shadow_min_area_ratio: float = shadow_area_spinbox.value
```

**参数含义**：
- `shadow_simplify_tolerance`（默认 150）：阴影 polygon 的 RDP 简化容差（像素）。值越大 = 顶点越少 = 阴影形状越粗糙。150 比 body 的 100 更大，生成更少顶点的多边形。
- `shadow_min_area_ratio`（默认 0.2）：阴影 polygon 的最小面积阈值（占精灵图面积的比率）。值越小 = 保留更多小碎片。0.2 比 body 的 0.3 更小，避免阴影丢失小的突出物（如武器尖端）。

#### 文件 3：`template_skin.tscn`

在 `AnimatedSprite2D` 下添加 `ShadowBox` 节点（与 `HurtBox` 同级）：
```
AnimatedSprite2D
├── HurtBox (Area2D)
│   └── HurtShape (CollisionPolygon2D / CollisionShape2D)
└── ShadowBox (LightOccluder2D)          ← 新增
    └── occluder: OccluderPolygon2D       ← 子资源，closed=true
```

### 4.8 Track 路径格式对比

```
HurtShape tracks（现有，按 shape_type 选择）：
  Polygon:
    AnimatedSprite2D/HurtBox/HurtShape:polygon    → PackedVector2Array
    AnimatedSprite2D/HurtBox/HurtShape:position    → Vector2（固定 0,0）
    AnimatedSprite2D/HurtBox/HurtShape:rotation    → float（固定 0.0）
  Capsule:
    AnimatedSprite2D/HurtBox/HurtShape:shape:radius → float
    AnimatedSprite2D/HurtBox/HurtShape:shape:height → float
    AnimatedSprite2D/HurtBox/HurtShape:position     → Vector2（MABR center）
    AnimatedSprite2D/HurtBox/HurtShape:rotation     → float（MABR angle）
  Rectangle:
    AnimatedSprite2D/HurtBox/HurtShape:shape:size  → Vector2
    AnimatedSprite2D/HurtBox/HurtShape:position    → Vector2（MABR center）
    AnimatedSprite2D/HurtBox/HurtShape:rotation    → float（MABR angle）

ShadowBox track（新增，与 body shape_type 无关）：
    AnimatedSprite2D/ShadowBox:occluder:polygon → PackedVector2Array
```

**注意**：
- `occluder` 是 LightOccluder2D 的属性名（类型为 OccluderPolygon2D 资源）
- `polygon` 是 OccluderPolygon2D 的属性名
- Godot AnimationPlayer 支持这种 sub-resource property path 格式（`node:resource:property`）
- ShadowBox 只需要 1 条 track（vs HurtShape 的 3-4 条），因为 OccluderPolygon2D 没有 position/rotation 属性

---

## 五、昼夜循环系统设计

### 5.1 架构

```
DayNightManager (Autoload 单例)
├── 管理全局时间状态
├── 处理相位切换和过渡动画
├── 光照覆盖栈（法术/剧情触发）
└── 提供 API

SceneTimeData (Resource)
├── 每个场景的时间配置
├── 默认相位、是否循环、循环间隔
└── 每个相位的颜色和角度

DayNightController (场景节点)
├── 添加到每个 stage
├── 监听 DayNightManager 信号
├── 控制 CanvasModulate 颜色插值
└── 控制 DirectionalLight2D 角度/能量

ShadowController (场景节点，挂在 ShadowRenderer 上)
├── 读取 DayNightManager 的光源参数
├── 计算 max_dist（根据仰角）
└── 传给 shadow shader
```

### 5.2 数据结构

#### TimePhase 枚举

```gdscript
enum TimePhase {
    DAWN,   # 黎明
    DAY,    # 白天
    DUSK,   # 黄昏
    NIGHT,  # 夜晚
}
```

#### SceneTimeData.gd

```gdscript
class_name SceneTimeData
extends Resource

@export var default_phase: DayNightManager.TimePhase = DayNightManager.TimePhase.DAY

# 循环配置
@export var can_cycle: bool = false
@export var cycle_duration: float = 300.0  # 一个完整循环的秒数

# 过渡时长
@export var transition_duration: float = 2.0

# 每个相位的 CanvasModulate 颜色
@export var phase_colors: Dictionary = {
    DayNightManager.TimePhase.DAWN:  Color(0.95, 0.85, 0.75),  # 暖橙
    DayNightManager.TimePhase.DAY:   Color(1.0, 1.0, 1.0),     # 白色（无色调）
    DayNightManager.TimePhase.DUSK:  Color(0.9, 0.7, 0.5),     # 黄昏橙
    DayNightManager.TimePhase.NIGHT: Color(0.3, 0.4, 0.6),     # 冷蓝月光
}

# 每个相位的 DirectionalLight2D 旋转角度（度）
@export var phase_light_rotations: Dictionary = {
    DayNightManager.TimePhase.DAWN:  -70.0,  # 右侧低角度
    DayNightManager.TimePhase.DAY:   -45.0,  # 右上方 45°
    DayNightManager.TimePhase.DUSK:  70.0,   # 左侧低角度
    DayNightManager.TimePhase.NIGHT: 45.0,    # 左上方
}

# 每个相位的 DirectionalLight2D 能量
@export var phase_light_energies: Dictionary = {
    DayNightManager.TimePhase.DAWN:  0.6,
    DayNightManager.TimePhase.DAY:   1.0,
    DayNightManager.TimePhase.DUSK:  0.5,
    DayNightManager.TimePhase.NIGHT: 0.3,
}

# 每个相位的 DirectionalLight2D 颜色
@export var phase_light_colors: Dictionary = {
    DayNightManager.TimePhase.DAWN:  Color(1.0, 0.8, 0.6),
    DayNightManager.TimePhase.DAY:   Color(1.0, 1.0, 0.95),
    DayNightManager.TimePhase.DUSK:  Color(1.0, 0.6, 0.3),
    DayNightManager.TimePhase.NIGHT: Color(0.6, 0.7, 1.0),
}

# PointLight2D 控制（是否开启环境点光源）
@export var point_lights_enabled_phases: Array = [
    DayNightManager.TimePhase.DUSK,
    DayNightManager.TimePhase.NIGHT,
]
```

#### LightingOverride.gd

```gdscript
class_name LightingOverride
extends Resource

@export var color: Color = Color.WHITE        # 目标 CanvasModulate 颜色
@export var light_rotation: float = -45.0     # 目标 DirectionalLight2D 旋转
@export var light_energy: float = 1.0         # 目标 DirectionalLight2D 能量
@export var light_color: Color = Color.WHITE  # 目标 DirectionalLight2D 颜色
@export var transition_duration: float = 1.0  # 过渡时长
@export var priority: int = 0                 # 优先级（高覆盖低）
```

### 5.3 DayNightManager.gd

```gdscript
class_name DayNightManager
extends Node

signal phase_changed(new_phase: int)
signal phase_transitioning(from_phase: int, to_phase: int, progress: float)
signal override_applied(override: LightingOverride)
signal override_removed()

var current_phase: int = TimePhase.DAY
var _transition_tween: Tween = null
var _transition_generation: int = 0
var _override_stack: Array[Dictionary] = []
var _cycle_tween: Tween = null
var _current_scene_data: SceneTimeData = null

# ── 公共 API ──

func enter_scene(scene_data: SceneTimeData) -> void:
    _current_scene_data = scene_data
    transition_to(scene_data.default_phase, scene_data.transition_duration)
    if scene_data.can_cycle:
        _start_auto_cycle(scene_data)

func transition_to(target_phase: int, duration: float = 2.0) -> void:
    if _transition_tween:
        _transition_tween.kill()
    _transition_generation += 1
    var my_generation := _transition_generation
    var from_phase := current_phase
    current_phase = target_phase
    _transition_tween = create_tween()
    _transition_tween.tween_method(
        func(progress: float):
            phase_transitioning.emit(from_phase, target_phase, progress),
        0.0, 1.0, duration
    )
    await _transition_tween.finished
    if my_generation == _transition_generation:
        phase_changed.emit(target_phase)

func apply_lighting_override(override: LightingOverride, duration: float = -1.0) -> String:
    var override_id := str(Time.get_ticks_msec())
    _override_stack.push_back({
        "id": override_id,
        "data": override,
        "duration": duration,
        "start_time": Time.get_ticks_msec(),
    })
    _apply_top_override()
    if duration > 0:
        get_tree().create_timer(duration).timeout.connect(
            func(): remove_lighting_override(override_id)
        )
    return override_id

func remove_lighting_override(override_id: String) -> void:
    _override_stack = _override_stack.filter(func(o): return o.id != override_id)
    _apply_top_override()

# 光源参数查询 API（供 ShadowController 等调用）
func get_sun_elevation_deg() -> float:
    # 从当前相位的光源旋转推算仰角
    # 简化模型：DAWN=20°, DAY=45°, DUSK=20°, NIGHT=30°
    match current_phase:
        TimePhase.DAWN:  return 20.0
        TimePhase.DAY:   return 45.0
        TimePhase.DUSK:  return 20.0
        TimePhase.NIGHT: return 30.0
    return 45.0

func get_sun_azimuth_deg() -> float:
    if _current_scene_data:
        return _current_scene_data.phase_light_rotations.get(current_phase, -45.0)
    return -45.0

func stop_cycle() -> void:
    if _cycle_tween:
        _cycle_tween.kill()
        _cycle_tween = null

# ── 内部方法 ──

func _start_auto_cycle(scene_data: SceneTimeData) -> void:
    stop_cycle()
    _cycle_tween = create_tween().set_loops()
    var phases := [TimePhase.DAY, TimePhase.DUSK, TimePhase.NIGHT, TimePhase.DAWN]
    var phase_duration := scene_data.cycle_duration / 4.0
    for phase in phases:
        _cycle_tween.tween_callback(
            func(): transition_to(phase, phase_duration * 0.8)
        )
        _cycle_tween.tween_interval(phase_duration)

func _apply_top_override() -> void:
    if _override_stack.is_empty():
        override_removed.emit()
        return
    # 按优先级排序，取最高的
    _override_stack.sort_custom(func(a, b): return a.data.priority > b.data.priority)
    override_applied.emit(_override_stack[0].data)
```

### 5.4 DayNightController.gd

```gdscript
class_name DayNightController
extends Node

## 场景内昼夜控制器
## 添加到每个 stage，引用场景中的 CanvasModulate 和 DirectionalLight2D

@export var scene_time_data: SceneTimeData
@export var canvas_modulate: CanvasModulate
@export var directional_light: DirectionalLight2D
@export var point_lights: Array[PointLight2D] = []

func _ready() -> void:
    var manager := get_node_or_null("/root/DayNightManager")
    if not manager:
        return
    
    manager.phase_transitioning.connect(_on_phase_transitioning)
    manager.override_applied.connect(_on_override_applied)
    manager.override_removed.connect(_on_override_removed)
    manager.enter_scene(scene_time_data)

func _on_phase_transitioning(from_phase: int, to_phase: int, progress: float) -> void:
    if not scene_time_data:
        return
    
    # CanvasModulate 颜色插值
    if canvas_modulate:
        var from_color: Color = scene_time_data.phase_colors.get(from_phase, Color.WHITE)
        var to_color: Color = scene_time_data.phase_colors.get(to_phase, Color.WHITE)
        canvas_modulate.color = from_color.lerp(to_color, progress)
    
    # DirectionalLight2D 参数插值
    if directional_light:
        var from_rot: float = scene_time_data.phase_light_rotations.get(from_phase, -45.0)
        var to_rot: float = scene_time_data.phase_light_rotations.get(to_phase, -45.0)
        directional_light.rotation_degrees = lerp(from_rot, to_rot, progress)
        
        var from_energy: float = scene_time_data.phase_light_energies.get(from_phase, 1.0)
        var to_energy: float = scene_time_data.phase_light_energies.get(to_phase, 1.0)
        directional_light.energy = lerp(from_energy, to_energy, progress)
        
        var from_color: Color = scene_time_data.phase_light_colors.get(from_phase, Color.WHITE)
        var to_color: Color = scene_time_data.phase_light_colors.get(to_phase, Color.WHITE)
        directional_light.color = from_color.lerp(to_color, progress)
    
    # PointLight2D 开关
    for light in point_lights:
        var should_enable := to_phase in scene_time_data.point_lights_enabled_phases
        light.enabled = should_enable

func _on_override_applied(override: LightingOverride) -> void:
    var tween := create_tween()
    if canvas_modulate:
        tween.parallel().tween_property(canvas_modulate, "color", override.color, override.transition_duration)
    if directional_light:
        tween.parallel().tween_property(directional_light, "rotation_degrees", override.light_rotation, override.transition_duration)
        tween.parallel().tween_property(directional_light, "energy", override.light_energy, override.transition_duration)
        tween.parallel().tween_property(directional_light, "color", override.light_color, override.transition_duration)

func _on_override_removed() -> void:
    # 恢复到当前相位的默认值
    if scene_time_data:
        var tween := create_tween()
        if canvas_modulate:
            tween.parallel().tween_property(
                canvas_modulate, "color",
                scene_time_data.phase_colors.get(DayNightManager.current_phase, Color.WHITE),
                1.0
            )
```

### 5.5 使用示例

#### 场景配置

```gdscript
# 在 stage 场景编辑器中：
# 1. 添加 DayNightController 节点
# 2. 创建 SceneTimeData 资源并配置
# 3. 拖入 CanvasModulate、DirectionalLight2D 引用

# 月河村示例：
# default_phase = NIGHT
# can_cycle = false
# phase_colors[NIGHT] = Color(0.3, 0.4, 0.6)  # 冷蓝月光
# phase_light_rotations[NIGHT] = 45.0           # 左上方

# 大雁岭示例：
# default_phase = DUSK
# can_cycle = true
# cycle_duration = 600.0  # 10分钟一个循环
```

#### 剧情触发

```gdscript
# Boss 战开始，天空变暗
var override := LightingOverride.new()
override.color = Color(0.2, 0.2, 0.3)
override.light_rotation = 200.0
override.light_energy = 0.3
override.transition_duration = 1.0
DayNightManager.apply_lighting_override(override)

# Boss 战结束（移除覆盖，恢复场景默认）
DayNightManager.remove_lighting_override(override_id)
```

#### 法术触发

```gdscript
# 暗影法术：临时变暗 3 秒
var override := LightingOverride.new()
override.color = Color(0.1, 0.1, 0.2)
override.light_rotation = 180.0
override.light_energy = 0.2
override.transition_duration = 0.5
DayNightManager.apply_lighting_override(override, duration=3.0)  # 3秒后自动移除

# 圣光法术：临时变亮 5 秒
var override := LightingOverride.new()
override.color = Color(1.0, 0.95, 0.8)
override.light_rotation = 0.0  # 正上方
override.light_energy = 1.5
override.transition_duration = 0.3
DayNightManager.apply_lighting_override(override, duration=5.0)
```

---

## 六、场景光影节点结构

### 6.1 Stage 场景模板

```
Stage (Node2D, script: base_stage.gd)
├── DayNightController (DayNightController)  ← 新增
│   ├── scene_time_data: SceneTimeData
│   ├── canvas_modulate → 引用下方 CanvasModulate
│   ├── directional_light → 引用下方 DirectionalLight2D
│   └── point_lights → 引用下方的 PointLight2D 数组
├── CanvasModulate                           ← 新增
│   └── color: Color.WHITE（初始值）
├── DirectionalLight2D                       ← 新增
│   ├── rotation_degrees: -45.0（默认右上方）
│   ├── shadow/enabled: false（关键！关闭内置阴影）
│   ├── energy: 1.0
│   └── color: Color.WHITE
├── Background (Node2D, z_index=5)
│   ├── SkyboxLayer (ParallaxBackground)
│   └── ...（背景精灵、PointLight2D 灯笼等）
├── Level (Node2D, z_index=15, y_sort=true)
│   ├── Characters (y_sort=true)
│   │   └── 角色实例（动态包含 ShadowRenderer + ShadowBox）
│   ├── Objects (y_sort=true)
│   │   └── 建筑/道具（可手动添加 LightOccluder2D）
│   └── Collisions
├── Foreground (z_index=25)
├── FightRooms (z_index=30)
└── HudLayer (CanvasLayer)
```

**注意**：Stage 场景模板中**不再包含场景级 ShadowRenderer**。ShadowRenderer 由每个角色在 `_ready()` 中动态创建（见 Section 三），polygon 形状由平行四边形算法动态计算。

---

## 七、project.godot 配置

### 7.1 SDF 设置

```ini
[rendering]

2d/sdf/oversize=2
2d/sdf/scale=0.5
```

**`oversize=2`（200%）**：SDF 纹理尺寸 = 视口 × 200%

- 作用：SDF 纹理向外扩展，覆盖视口之外的区域
- 原因：角色站在屏幕边缘时，其 ShadowBox (LightOccluder2D) 可能部分在视口外。如果 oversize=1（100%），SDF 纹理只覆盖视口范围，边缘的 occluder 会被截断，导致阴影硬切断
- 代价：纹理面积增大 4 倍（线性 2 倍 → 面积 2² 倍），GPU 内存增加
- 当前视口 1280×720，oversize=2 → SDF 纹理实际尺寸 2560×1440

**`scale=0.5`（50%）**：SDF 纹理分辨率 = 视口 × 50%

- 作用：降低 SDF 纹理的采样分辨率，1 个 SDF 单位 = 2 个屏幕像素
- 原因：阴影 polygon 通常只有 4-8 个顶点，不需要像素级精度。50% 分辨率足够，同时显著减少 GPU 计算量
- 代价：阴影边缘精度降低（2 像素误差），可通过 `softness` 参数柔化掩盖
- 当前视口 1280×720，scale=0.5 → SDF 纹理解析度 640×360

**两个参数的组合效果**：
- 最终 SDF 纹理尺寸 = 视口 × oversize × scale = 1280×720 × 2 × 0.5 = **1280×720**（与视口同分辨率）
- 但覆盖范围是视口的 200%（oversize 的作用）
- `character_shadow_controller.gd` 中读取 `scale` 计算 `max_dist`：`max_dist = shadow_pixels * sdf_scale`

### 7.2 Autoload 注册

```ini
[autoload]

DayNightManager="*res://scripts/day_night/day_night_manager.gd"
```

---

## 八、文件清单

### 8.1 新增文件

| 文件路径 | 类型 | 说明 |
|---------|------|------|
| `shaders/shadow_sdf.gdshader` | Shader | SDF 阴影渲染 shader |
| `scripts/character_shadow_controller.gd` | 脚本 | 角色阴影控制器（动态挂载到 ShadowRenderer） |
| `scripts/day_night/day_night_manager.gd` | Autoload | 昼夜循环全局管理器 |
| `scripts/day_night/day_night_controller.gd` | 脚本 | 场景内昼夜控制器 |
| `scripts/day_night/scene_time_data.gd` | Resource | 场景时间配置资源定义 |
| `scripts/day_night/lighting_override.gd` | Resource | 光照覆盖资源定义 |
| `docs/LIGHTING_SETUP_GUIDE.md` | 文档 | L1-L3 操作指南（场景配置步骤） |

### 8.2 修改文件

| 文件路径 | 修改内容 | 修改点详情 |
|---------|---------|-----------|
| `project.godot` | 添加 [rendering] SDF 设置 + [autoload] DayNightManager | 新增 `2d/sdf/oversize=2`、`2d/sdf/scale=0.5`、`DayNightManager` autoload |
| `addons/.../quiver_character.gd` | 新增 `_create_shadow_renderer()` 方法 | `_ready()` 末尾调用，动态创建 Polygon2D + 挂载 character_shadow_controller.gd |
| `addons/.../animation_track_injector.gd` | 新增 ShadowBox OccluderPolygon2D 双扫描 + track 注入 | 修改点 A-E：新增常量、双扫描逻辑、`_ensure_shadow_occluder_exists()`、`_inject_occluder_polygon_tracks()`、shadow_contours 合并 |
| `addons/.../height_layers_widget.gd` | UI 增加 shadow 专用参数输入 | 新增 `shadow_simplify_tolerance`（默认150）和 `shadow_min_area_ratio`（默认0.2）SpinBox，传递给 `_convert_contours_common()` |
| `characters/playable/_template/template_skin.tscn` | 添加 ShadowBox (LightOccluder2D) 节点 | 在 AnimatedSprite2D 下新增 ShadowBox 子节点，与 HurtBox 同级，occluder 子资源 closed=true |

### 8.3 场景配置（每个 stage 需要手动添加）

| 节点 | 类型 | 说明 |
|------|------|------|
| DayNightController | Node | 引用 SceneTimeData + CanvasModulate + DirectionalLight2D |
| CanvasModulate | CanvasModulate | 全局环境光 |
| DirectionalLight2D | DirectionalLight2D | 主光源（shadow/enabled = false） |
| PointLight2D（可选） | PointLight2D | 灯笼、火把等环境光源 |
| LightOccluder2D（可选） | LightOccluder2D | 建筑/静态物体阴影 |

**注意**：ShadowRenderer 不再需要在场景中添加，由每个角色动态创建。

---

## 九、实施顺序

### Phase 1：基础设施搭建 + 多 ShadowRenderer 验证

1. 创建 `shaders/shadow_sdf.gdshader`（从文档 Section 2.2 中的代码）
2. 创建 `scripts/character_shadow_controller.gd`（从文档 Section 3.7 中的完整代码）
3. 修改 `project.godot` 添加 SDF 设置：
   - `2d/sdf/oversize=2`
   - `2d/sdf/scale=0.5`
4. 修改 `quiver_character.gd`：
   - 添加 `SHADOW_CONTROLLER_SCRIPT` 常量
   - 添加 `_create_shadow_renderer()` 方法
   - 在 `_ready()` 末尾调用 `_create_shadow_renderer()`
5. 手动给 run_test 角色添加 ShadowBox (LightOccluder2D) + 静态 polygon
6. 在 Godot 中运行验证：
   - ShadowRenderer 是否被正确创建（在 Remote 场景树中可见，作为 CharacterBody2D 的子节点）
   - polygon 形状是否为平行四边形（在 Inspector 中查看 Polygon2D.polygon）
   - shader 是否渲染出阴影
   - 调整 Inspector 中 shader 参数 angle → 阴影方向变化
   - 调整 Inspector 中 shader 参数 max_dist → 阴影长度变化
   - 调整 Inspector 中 shader 参数 softness → 柔和度变化（注意：0=最柔和，1=硬边缘）
   - 角色行走时阴影是否跟随
   - 角色跳跃时阴影是否偏移+淡化
   - Phase 1 不需要 DayNightManager（脚本使用默认值 45° 仰角、135° 方位角）

### Phase 2：动画同步验证

1. 验证 AnimatedSprite2D 的 `animation` 和 `frame` 属性在 AnimationTree 控制下是否实时更新
2. 如果验证通过：LightOccluder2D 的 polygon 通过 track 驱动即可自动同步
3. 如果验证失败：需要备选方案（通过 AnimationTree playback API 推断当前动画）

### Phase 3：轮廓检测工具扩展（双扫描 + ShadowBox track 注入）

**目标**：无论 body 选择 Polygon / Capsule / Rectangle，ShadowBox 始终使用独立扫描的原始 polygon 顶点写入 `:occluder:polygon`。

#### 步骤 3.1：修改 `template_skin.tscn`

在 `AnimatedSprite2D` 下添加 `ShadowBox (LightOccluder2D)` 节点（与 `HurtBox` 同级）：
- `name = "ShadowBox"`
- `sdf_collision = true`
- 创建 `OccluderPolygon2D` 子资源，`closed = true`

#### 步骤 3.2：修改 `height_layers_widget.gd` — UI 增加 shadow 参数

在 Body 轮廓转换面板中新增两个 SpinBox：

| 参数名 | 默认值 | 说明 |
|--------|--------|------|
| `shadow_simplify_tolerance` | 150 | 阴影 polygon 的 RDP 简化容差（像素），比 body 的 100 更大 = 更少顶点 |
| `shadow_min_area_ratio` | 0.2 | 阴影 polygon 的最小面积阈值（占精灵图面积比率），比 body 的 0.3 更小 = 保留更多小碎片 |

在"Body 轮廓转换"按钮回调中，将这两个参数传递给 `_convert_contours_common()`。

#### 步骤 3.3：修改 `animation_track_injector.gd` — 核心逻辑

**3.3a 新增常量**：
```gdscript
const SHADOW_OCCLUDER_PATH := "AnimatedSprite2D/ShadowBox"
```

**3.3b `_convert_contours_common()` 中增加 shadow 扫描**（仅 body category）：
- 在现有 body 扫描完成后，调用 `_scan_frames_contours()` 第二次，使用 shadow 专用参数
- `erosion_radius = 0`（阴影不需要形态学腐蚀）
- 对 shadow_raw_contours 执行 `pixels_to_shape_local()` 坐标变换
- 将结果存入 `frame["shadow_contours"]`
- **不执行** MABR / Capsule / Rectangle 转换（不需要）
- **不计算** physical_height / width（不需要）

**3.3c 新增 `_ensure_shadow_occluder_exists()`**：
- 检查 AnimatedSprite2D 下是否有 "ShadowBox" 节点
- 不存在则创建 `LightOccluder2D`（name="ShadowBox", sdf_collision=true）+ `OccluderPolygon2D`（closed=true）

**3.3d `_inject_all_tracks()` 中增加 ShadowBox track**（仅 body category）：

**关键点：`flip_track_data` 复用机制**

`_inject_all_tracks()` 中已有提取 flip_h track 的逻辑（line 1142）：
```gdscript
var flip_track_data := _extract_flip_h_track(anim)  # 每个动画提取一次
```

这个 `flip_track_data` 是局部变量，所有 track 注入（包括 ShadowBox）直接复用它，**不需要重复提取**。

**ShadowBox track 注入逻辑**：
```gdscript
# 在 _inject_all_tracks() 的 body category 分支中，与现有 HurtShape track 并列
if category == "body":
    var track_idx := anim.add_track(Animation.TYPE_VALUE)
    anim.track_set_path(track_idx, SHADOW_OCCLUDER_PATH + ":occluder:polygon")
    anim.track_set_interpolation_type(track_idx, Animation.INTERPOLATION_NEAREST)
    anim.value_track_set_update_mode(track_idx, Animation.UPDATE_DISCRETE)
    
    for time_idx in range(key_times.size()):
        var time := key_times[time_idx]
        var frame_idx := frame_indices[time_idx]
        var frame_info: Dictionary = frames_data[sprite_anim_name][frame_idx]
        
        var shadow_contours: Array = frame_info.get("shadow_contours", [])
        if shadow_contours.is_empty():
            continue
        
        var polygon: PackedVector2Array = shadow_contours[0]
        
        # 复用已有的 flip_track_data（不重新提取）
        var is_flipped := _is_flipped_at_time(flip_track_data, time)
        if is_flipped:
            polygon = _mirror_polygon_x(polygon)
        
        anim.track_insert_key(track_idx, time, polygon)
```

**为什么只取 `shadow_contours[0]`？**

与 HurtShape 的 `contours[0]` 行为一致：
- `OccluderPolygon2D.polygon` 只支持单一 `PackedVector2Array`（与 `CollisionPolygon2D.polygon` 同限制）
- 如果精灵有多个分离部分（如断臂、分身），只取第一个轮廓（最大面积）
- 这是 Godot 引擎节点的限制，不是设计选择

**3.3e 新增 `_inject_occluder_polygon_tracks()` 方法**（封装复用）

#### 步骤 3.4：验证

对 run_test 角色执行 Body 轮廓转换，选择三种 shape_type 分别测试：

| 测试项 | 验证内容 |
|--------|---------|
| Polygon 模式 | ShadowBox track 和 HurtShape:polygon track 都正确生成，但顶点数不同 |
| Capsule 模式 | HurtShape 用 CapsuleShape2D tracks，ShadowBox 仍用 polygon track |
| Rectangle 模式 | HurtShape 用 RectangleShape2D tracks，ShadowBox 仍用 polygon track |
| shadow_simplify_tolerance=150 | ShadowBox polygon 顶点数比 HurtShape polygon 少 |
| shadow_simplify_tolerance=50 | ShadowBox polygon 顶点数接近 HurtShape polygon |

在 Godot 中播放动画，观察 ShadowBox 的 OccluderPolygon2D.polygon 是否逐帧变化：
- 行走时：阴影形状跟随动画帧变化
- 跳跃时：阴影形状切换到跳跃帧的 polygon
- flip_h 时：polygon X 坐标正确镜像

### Phase 4：昼夜循环系统

1. 创建 `day_night_manager.gd`（Autoload）
2. 创建 `day_night_controller.gd`
3. 创建 `scene_time_data.gd` 和 `lighting_override.gd` 资源
4. 注册 Autoload 到 project.godot
5. 在 test 场景中配置测试

### Phase 5：集成与调参

1. 将光影节点集成到 base_stage 模板（如果有的话）
2. 为每个场景配置 SceneTimeData
3. 调参：阴影颜色、长度、柔和度
4. 性能测试：多角色同屏

### Phase 6：操作指南文档

1. 编写 `docs/LIGHTING_SETUP_GUIDE.md`
2. 涵盖 L1-L3 的配置步骤、推荐参数、场景示例

---

## 十、验证清单

- [ ] shader 在 720p 视口下正确渲染
- [ ] 调整 angle 参数，所有 8 个方向阴影方向正确
- [ ] 调整 max_dist 参数，阴影长度变化符合预期
- [ ] softness=0 时阴影最柔和（线性淡出），softness=1 时硬边缘（阶跃）
- [ ] 角色行走时阴影形状跟随动画帧变化
- [ ] 角色跳跃时阴影偏移 + 淡化
- [ ] 角色被击飞时阴影正确偏移
- [ ] DirectionalLight2D 旋转 → shader angle 自动更新
- [ ] 昼夜循环相位切换平滑过渡
- [ ] 法术/剧情触发覆盖生效，到期自动恢复
- [ ] 10 个角色同屏，FPS 不低于 55（720p）
- [ ] 轮廓检测工具生成的 ShadowBox tracks 正确驱动 OccluderPolygon2D
- [ ] Body 选择 Polygon 模式时，ShadowBox track 正确生成（顶点数少于 HurtShape）
- [ ] Body 选择 Capsule 模式时，HurtShape 用 CapsuleShape2D，ShadowBox 仍用 polygon
- [ ] Body 选择 Rectangle 模式时，HurtShape 用 RectangleShape2D，ShadowBox 仍用 polygon
- [ ] shadow_simplify_tolerance=150 生成的阴影 polygon 顶点数明显少于 body 的 100

---

## 十一、风险与备选方案

### 风险 1：AnimatedSprite2D 属性在 AnimationTree 下不实时更新

**验证方法**：在 `_process()` 中 print `anim_sprite.animation` 和 `anim_sprite.frame`

**备选方案**：通过 AnimationTree 的 playback API 获取当前状态：
```gdscript
var current_state = playback.get_current_node()  # 如 "walk"
# 根据 skin_direction 推断方向后缀
var direction_suffix = "_right" if skin.facing_x > 0 else "_left"
var full_anim_name = current_state + direction_suffix
```

### 风险 2：OccluderPolygon2D sub-resource track 路径不被 AnimationPlayer 支持

**问题**：track 路径 `AnimatedSprite2D/ShadowBox:occluder:polygon` 使用了 sub-resource property path 格式。Godot AnimationPlayer 是否支持这种格式需要验证。

**验证方法**：手动创建 track `AnimatedSprite2D/ShadowBox:occluder:polygon`，观察是否生效

**备选方案**：不使用 sub-resource path，而是在 GDScript 中每帧同步 shadow_contours 到 OccluderPolygon2D：
```gdscript
func _process(delta):
    var hurt_polygon = hurt_shape.polygon
    shadow_occluder.occluder.polygon = hurt_polygon
```

**注意**：备选方案会增加每帧 CPU 开销（PackedVector2Array 赋值），但开销极小（~0.01ms/角色）。

### 风险 3：SDF 精度不足导致阴影边缘锯齿

**解决**：调整 SDF scale 到 100%，或在 shader 中增加 softness 参数柔化边缘

### 风险 4：多角色 LightOccluder2D 导致 SDF 重建开销

**解决**：阴影 polygon 使用更大的 simplify_tolerance（更少的顶点），降低 SDF 栅格化开销。双扫描方案中 shadow_simplify_tolerance 默认 150，典型生成 4-8 个顶点，比 body 的 10-20 个顶点显著减少。

### 风险 5：双扫描增加 authoring 时间

**问题**：两次 `_scan_frames_contours()` 调用会使轮廓转换时间翻倍。

**评估**：这是 authoring-time 操作（用户点击按钮时执行），多 1-2 秒可接受。不影响运行时性能。

**缓解措施**：
- shadow 扫描可复用 body 扫描已加载的 PNG Image 缓存（`_image_cache`）
- shadow 扫描使用更大的 simplify_tolerance，生成更少的轮廓，计算更快

### 风险 6：shadow_contours 数据量大导致 .tscn 文件膨胀

**问题**：每个动画每帧增加一个 PackedVector2Array track，文件体积增加。

**评估**：shadow_simplify_tolerance=150 时，典型多边形 4-8 个顶点，每个顶点 2 个 float = 16-32 字节。一帧 16-32 字节，一个动画 10 帧 = 160-320 字节。可接受。

---

## 十二、小步快跑实施计划

> 将每个 Phase 拆分为独立可验证的步骤，每步完成后立即测试，不累积问题。

### Phase 1：基础设施（6 步）

#### Step 1.1：创建 shader 文件
- 创建 `xuanyuan-sword/shaders/shadow_sdf.gdshader`
- 复制 Section 2.2 的代码
- 验证：Godot File System 中可见，双击打开无报错

#### Step 1.2：配置 project.godot SDF
- 在 `project.godot` 末尾添加 `[rendering]` section：
  ```ini
  [rendering]
  2d/sdf/oversize=2
  2d/sdf/scale=0.5
  ```
- 验证：重启 Godot，Project Settings → Rendering → 2D → SDF 参数可见

#### Step 1.3：创建 character_shadow_controller.gd
- 创建 `xuanyuan-sword/scripts/character_shadow_controller.gd`
- 复制 Section 3.7 的完整代码
- 验证：Godot 编辑器无语法错误

#### Step 1.4：修改 quiver_character.gd
- 添加 `SHADOW_CONTROLLER_SCRIPT` 常量（preload shadow controller）
- 添加 `_create_shadow_renderer()` 方法（Section 3.8）
- 在 `_ready()` 末尾调用 `_create_shadow_renderer()`
- 验证：无语法错误，保存后自动 reload 成功
- 回滚：`git diff` 撤销

#### Step 1.5：手动添加 ShadowBox 到 run_test
- 打开 `characters/playable/run_test/run_test_skin.tscn`
- 在 `AnimatedSprite2D` 下添加 `LightOccluder2D`（name=ShadowBox）
- 创建 `OccluderPolygon2D` 子资源，closed=true
- 手动绘制一个简单矩形 polygon（4 个顶点）
- 验证：场景树可见，Inspector 可编辑 polygon

#### Step 1.6：Godot 验证（关键里程碑 ⭐）
- 运行测试场景
- 验证清单：
  - [ ] CharacterBody2D 下有 ShadowRenderer (Polygon2D) 子节点
  - [ ] polygon 是平行四边形（4 个顶点）
  - [ ] 屏幕可见阴影
  - [ ] 调整 angle → 阴影方向变化
  - [ ] 调整 max_dist → 阴影长度变化
  - [ ] 调整 softness（0→1）→ 柔和变硬
  - [ ] 行走时阴影跟随
  - [ ] 跳跃时阴影偏移+淡化

### Phase 2：动画同步验证（2 步）

#### Step 2.1：验证 AnimatedSprite2D 属性实时更新
- 在 character_shadow_controller.gd 的 `_process()` 添加临时 print
- 运行场景，观察控制台
- 验证：
  - [ ] 控制台持续输出变化的动画名和帧号
  - [ ] 切换动画时名称变化
- 风险：如果失败，需启用备选方案（AnimationTree playback API）

#### Step 2.2：移除调试代码
- 删除 print 语句
- 验证：控制台无调试输出，阴影正常

### Phase 3：轮廓检测工具扩展（7 步）

#### Step 3.1：修改 template_skin.tscn
- 在 `AnimatedSprite2D` 下添加 `ShadowBox (LightOccluder2D)` 子节点
- 创建 `OccluderPolygon2D` 子资源
- 验证：场景树正确显示

#### Step 3.2：height_layers_widget.gd 添加 UI 参数
- 添加 `shadow_simplify_tolerance` SpinBox（默认 150）
- 添加 `shadow_min_area_ratio` SpinBox（默认 0.2）
- 验证：Inspector 工具中可见

#### Step 3.3：animation_track_injector.gd 修改点 A
- 添加常量 `SHADOW_OCCLUDER_PATH`
- 验证：无语法错误

#### Step 3.4：animation_track_injector.gd 修改点 B（shadow 扫描）
- 在 `_convert_contours_common()` 中增加 shadow 扫描逻辑
- 修改方法签名：添加 `shadow_simplify_tolerance` 和 `shadow_min_area_ratio` 参数
- 验证：无语法错误，工具可调用不崩溃

#### Step 3.5：animation_track_injector.gd 修改点 C
- 添加 `_ensure_shadow_occluder_exists()` 方法
- 验证：无语法错误

#### Step 3.6：animation_track_injector.gd 修改点 D+E（track 注入）
- 在共享 tracks 区域调用 `_inject_shadow_occluder_track()`
- 添加 `_inject_shadow_occluder_track()` 方法
- 验证：无语法错误

#### Step 3.7：验证工具功能（关键里程碑 ⭐）
- 对 run_test 角色执行 Body 轮廓转换
- 验证清单：
  - [ ] 工具执行无报错
  - [ ] 动画包含 `AnimatedSprite2D/ShadowBox:occluder:polygon` track
  - [ ] 播放动画时 OccluderPolygon2D.polygon 逐帧变化
  - [ ] flip_h 时 polygon X 坐标正确镜像
  - [ ] Polygon 模式：ShadowBox 顶点数少于 HurtShape
  - [ ] Capsule/Rectangle 模式：HurtShape 用 shape 参数，ShadowBox 仍用 polygon

### Phase 4：昼夜循环系统（5 步）

#### Step 4.1：创建 SceneTimeData.gd
- 创建 `scripts/day_night/scene_time_data.gd`（Section 5.2）
- 验证：可在 Inspector 中创建 SceneTimeData 资源

#### Step 4.2：创建 LightingOverride.gd
- 创建 `scripts/day_night/lighting_override.gd`（Section 5.2）
- 验证：无语法错误

#### Step 4.3：创建 DayNightManager.gd + 注册 Autoload
- 创建 `scripts/day_night/day_night_manager.gd`（Section 5.3）
- 在 `project.godot` 的 `[autoload]` 中注册
- 验证：重启后可通过 `DayNightManager` 全局访问

#### Step 4.4：创建 DayNightController.gd
- 创建 `scripts/day_night/day_night_controller.gd`（Section 5.4）
- 验证：无语法错误

#### Step 4.5：验证昼夜循环（关键里程碑 ⭐）
- 在测试场景中添加 DayNightController + CanvasModulate + DirectionalLight2D
- 验证清单：
  - [ ] 相位切换时 CanvasModulate 颜色平滑过渡
  - [ ] DirectionalLight2D 旋转/能量/颜色平滑过渡
  - [ ] 角色阴影方向跟随光源变化
  - [ ] apply_lighting_override() 临时覆盖生效
  - [ ] 覆盖到期后自动恢复

### Phase 5：集成调参（2 步）

#### Step 5.1：集成到 stage 模板
- 在 base_stage 或测试场景中添加 DayNightController/CanvasModulate/DirectionalLight2D
- 验证：场景加载无报错

#### Step 5.2：调参优化
- 调整阴影颜色、长度、柔和度
- 多角色同屏性能测试
- 验证：10 角色同屏 FPS ≥ 55（720p）

### Phase 6：文档（1 步）

#### Step 6.1：编写 LIGHTING_SETUP_GUIDE.md
- 涵盖 L1-L3 配置步骤、推荐参数、常见问题排查

### 时间估算

| 阶段 | 步骤数 | 预计时间 |
|------|--------|---------|
| Phase 1 | 6 | 2-3 小时 |
| Phase 2 | 2 | 30 分钟 |
| Phase 3 | 7 | 3-4 小时 |
| Phase 4 | 5 | 2 小时 |
| Phase 5 | 2 | 1 小时 |
| Phase 6 | 1 | 1 小时 |
| **总计** | **23** | **9-11 小时** |

### 风险控制
- 每步完成后立即验证，不累积问题
- 使用 `git diff` 随时撤销修改
- 只改必要代码，不重构
- 遇到问题记录到文档风险部分

**缓解措施**：如果文件体积问题严重，可考虑将 shadow polygon 数据提取到外部 .tres 资源文件，动画通过引用加载。
