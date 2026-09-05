# 阴影柔边（P2）设计：共享离屏缓冲 + 可分离模糊（方案 A，可配置开关）

> 版本：v2.2
> 日期：2026-09-05
> 状态：已实现（默认关闭），L 键实测开启正常、柔化 OK；新增 §9 投影区域(ShadowRegion) 裁剪，headless 已验证三态；待真关卡遮挡/低配帧率验证
> 前置：`SHADOW_REDESIGN_PLAN.md`(P0 投影)、P1 距离衰减
> 取代：本文 v1 曾拟的 Line2D 裙边方案（见 §7 为何放弃）

---

## 1. 目标
给"ShadowBox 轮廓投影成地面阴影"（现为硬边 Polygon2D）加**朝外的柔和 penumbra**，且：
- **性能优先**（目标含低配机；当初 SDF→polygon 就是为 Intel UHD 降开销）；
- **可配置**：需要时开，不需要时关；**关闭时必须与现状逐像素一致、零额外成本**。

## 2. 调研结论（为何是离屏模糊）
Godot 通用软阴影做法：①引擎 Light2D+PCF（全场景光照模型，非脚底投影剪影，弃）；②SDF/逐像素高斯（正是我们弃掉的）；③**离屏缓冲 + 可分离模糊**；④Line2D 几何裙边（见 §7，因 API 与长度向淡出受限弃）。
在"矢量投影轮廓 + 弱卡"下，唯一同时满足形状保真 + 真软边 + 成本可控的是 **③**，且要做成**半/低分辨率、两趟可分离**（官方 separable 范式），成本≈固定两趟全屏模糊，与角色数基本无关。

## 3. 架构（正式实现）
```
ShadowSoftEdge (autoload, scripts/shadow_soft_edge.gd)   ← 全局单例，默认 enabled=false
  ├─ SubViewport SubShadow (独立 World2D) : 各角色阴影代理多边形 + ShadowCam(镜像主相机)
  ├─ SubViewport SubH  : ColorRect H 模糊 (采样 SubShadow)
  └─ Sprite2D (主世界, z=composite_z) : 材质做末趟 V 模糊, 采样 SubH → 合成回场景
character_shadow_controller (每角色)
  ├─ 关闭软边：投影多边形（经 §9 区域裁剪，可能多块）画在 _shadow_polygon + _solid_extras 池
  └─ 开启软边：隐藏实心，改在 ShadowSoftEdge.shadow_world 里建/更新 _proxies[] 池
               （逐块 polygon/vertex_colors/modulate.a + global_transform）
 模糊 shader: shaders/shadow_blur.gdshader  (5-tap 可分离高斯, uniform src/dir/texel_size/radius)
 运行时开关: input action `soft_edge_toggle`（默认物理键 L）
```
- **两级离屏**：H 模糊在 `SubH` 里做，V 模糊合进最终合成 Sprite 的材质（省一张 RT；两趟模糊都在，成本不变）。
- 关闭时：无代理、离屏缓冲 `render_target_update_mode=UPDATE_ONCE`（冻结）→ 几乎零成本、零行为差异。
- 区域驱动（§9）：有 `ShadowRegion` 时，`_sync()` 令离屏缓冲尺寸/ShadowCam 取景/合成 Sprite 贴回**都按区域并集**（区域外阴影被裁、且 R 缩小=省性能）；**无区域时退化为相机视矩形，与旧全屏逐像素等价**。
- 合成 Sprite 对齐：`scale=size_world/buf`（区域版）→ 均匀缩放、不旋转时精确铺满；缓冲分辨率 `= size_world × zoom × SCALE`，钳制 ≤ 8192（超限会渲染失败——spike 实测踩到过）。

### 3.1 z 序遮挡（真关卡必查）
柔边是**一整张全屏 Sprite，只有一个 z**，只能"整层压在某 z 上/某 z 下"，无逐像素深度。
- 测试场景 `_test_run_test` 的 Background 在 `z=-10`、角色在 `z=0` → `composite_z=-1` 恰好落在中间，观感正确。
- **真实 `base_stage` 是 Background `z=5` / Level(角色) `z=15` / Foreground `z=25`** → 若仍用 `-1`，全屏影子层会被 `z=5` 背景整张埋掉→看不见。
- 修法：真关卡里把 `composite_z` 设为**介于背景与角色之间**（如 `6`）。该值已 `@export`，运行时/Inspector 可调。

## 4. 配置项（“做成可配置”）
`ShadowSoftEdge`（autoload）导出：
- `enabled: bool = false` —— 总开关（关闭=现状）。运行时 `set_enabled(bool)` 或按 `L`（action `soft_edge_toggle`）可切。
- `radius: float` —— 模糊半径（0–8 档）。
- `scale_idx` / `SCALES=[0.5,1,2,4,8]` —— 缓冲分辨率档（越低越省）。
- `composite_z: int = -1` —— 合成全屏 Sprite 的世界 z（真关卡需调到背景与角色之间，见 §3.1）。
未来接正式设置面板/昼夜配置时，把这几项数据化即可。

## 5. 性能
- 额外成本 = 两趟可分离模糊（∝ 缓冲像素，半分辨率下很小）+ 一次全屏 Sprite 合成。
- **与角色数无关**（所有影子在同一张缓冲里一次模糊）；per-character 仅多一个代理 Polygon2D 的赋值。
- 关闭时冻结离屏，成本≈0。

## 6. 验证
- headless：开/关两路径运行期无脚本/着色器错误；`enabled` 默认 false 已确认。
- F5（9800X3D/RTX5080）：按 `L` 开启，朝外柔边正常、贴脚、切换恢复正常。**教训**：调试期误把开关绑 `F9/F10` —— `F9` 是 Godot 运行时的**编辑器暂停键**，会导致"看起来冻结"，与离屏管线无关；已改用 input action `soft_edge_toggle`(物理键 L) 规避。**切勿把运行时开关绑到功能键。**
- headless 三态验证（临时探针，跑完即删）：区域内 `pts=8` 原样穿过、区域外 `visible=false` 整块裁没、跨界截成 `pts=6 且 vertex_colors=6`（数量匹配，证明解析重算顶点色与裁剪块一一对应）、软边代理正常创建可见。
- Geometry2D API 实测：`intersect_polygons`=交集(凹形可 1 块/相离返回空)，`clip_polygons`=**差集**(勿误用)，`merge_polygons`=并集。
- 待办：真关卡里验 §3.1 遮挡（设对 `composite_z`）；低配机测开/关帧率差以定默认档；§9 区域在凹多边形渗出与 2/3 级临界 `R*` 的实测取舍；若 MaxHub 不达标 → 按 §10 备用方案启动（先 B1 后 B2，再考虑 `scale_idx` 降档）。

## 9. 投影区域 ShadowRegion（性能底座，与软边开关无关）
**语义**：场景中"阴影可生成区域"。投影阴影**只保留与区域相交部分**（完全在外=该帧无阴影）；软边**额外借它把离屏缓冲缩到区域 AABB**（省全屏片元）。实心/软边在区域内语义一致。
- 节点：`scripts/shadow_region.gd` `@tool class_name ShadowRegion extends ReferenceRect`（编辑器可拖拽，沿用 `QuiverFightRoom` 惯例），运行时加入 group `shadow_region`。
- 可视化：生产语义 **零绘制**（`editor_only=true`，仅编辑器可见绿框）。`@export debug_preview := false` 才在运行时自绘边框+淡填充；**测试场景模板自动设 true**。坑：ReferenceRect 原生绘制在 `_notification`、**无 `_draw` 虚方法可 super 调用**（子类 `_draw` 里调 `super._draw()` 会每帧 Invalid call）。
- 交互：**T**（action `shadow_region_toggle`）实时开关 `enabled`（游戏性裁剪切换，控制台有打印）；编辑器分支 `QuiverEditorHelper.disable_all_processing` 防 @tool 误触发。
- 测试场景 = **生成物**：`test_scenes/_test_<char>.tscn`（该目录已 gitignore）每次 Run Test 由 `inspector_plugin.gd` 模板幂等重写（模板已内置 `ShadowRegion`(50,400,900×300, debug_preview=true)）；**手改生成的 tscn 会被覆盖，改测试场景=改模板**。
- 发现：controller/合成器都通过 `get_tree().get_nodes_in_group("shadow_region")` 取；**0 个启用区域 → 全屏，与无此特性时逐像素一致**（安全默认）。
- 裁剪：controller 把投影多边形（本地）→ 世界，`Geometry2D.intersect_polygons` 与每个区域求交（各自独立→天然并集），结果转回本地；**顶点色用"投影前顶点 Y"的解析式重算**（切割新生成顶点也成立），故距离衰减不丢。多块用对象池（`_solid_extras[]` / `_proxies[]`）。
- 性能：裁剪是 CPU 布尔运算(µs 级)；软边缓冲按区域 AABB → R 缩小；矩形情形合成 quad 只盖区域 → V 全屏片元降到区域片元（主要省钱点）。
- 已知取舍：① 多区域重叠处阴影会双倍变暗（应避免重叠）；② 凹多边形区域 + 跨边阴影，软边会有 ≈`3.2×radius` 缓冲像素的极淡尾渗到界外（v1 用矩形则物理不渗，因合成只盖矩形）。

## 7. 为何放弃 Line2D 裙边（v1）
Godot 4.7 `Line2D` **无逐顶点 `colors` 属性**（仅 `default_color`/`gradient`），无法把 P1 距离衰减复用到边缘；`gradient` 只按弧长，不按身体高度 → 影尖易残留等强度描边。离屏方案让阴影仍是每角色精确投影轮廓，只是**集中做一次模糊**，更干净，故改走 A。

## 8. 落地文件
- 新增 `scripts/shadow_soft_edge.gd`、`scripts/shadow_region.gd`、`shaders/shadow_blur.gdshader`。
- 改 `scripts/character_shadow_controller.gd`（开关分支 + 多块代理池 + §9 区域求交裁剪/顶点色重算）、`scripts/shadow_debug_overlay.gd`（多块绘制）。
- `project.godot` 注册 autoload `ShadowSoftEdge` + input action `soft_edge_toggle`（L）/ `shadow_region_toggle`（T）。
- 测试场景的 `ShadowRegion` 演示节点由 `inspector_plugin.gd` 的 Run Test 模板内置生成（勿手改生成物，见 §9）。
- 一次性验证用的 spike（`scenes/_shadow_blur_spike.tscn`、`scripts/shadow_blur_spike.gd`）已删除（模糊 shader 保留复用）。

## 10. 备用方案（未实施）：模糊刷新降频（B）
> **状态：设计存档。仅当 MaxHub 2K+区域 实测帧率仍不达标时启动**；启动前先试零改动的 `scale_idx` 降档。顺序建议：B1 → （不够）scale_idx 降档 → （仍不够）B2。

**原理**：模糊结果跨帧复用，与绘制帧率解耦——"每帧都变的只有影子形状"，若接受 ≤1 个刷新周期的形状滞后，模糊链可低频跑。

### B1（最小改动：两级拓扑下只降"离屏链"）
- 参数：`@export var blur_hz := 0.0`（0=逐帧全速=现状；>0 启用）。
- 机制：两张缓冲不再 `UPDATE_ALWAYS`；仅刷新帧把它们**重新赋值为 `UPDATE_ONCE`**（Godot 4 中重设该属性即可再渲一次），`_final` 仍每帧画（V 趟逐帧，读冻结的 SubH 纹理）。
- 成本账（P=区域屏幕像素数，h=blur_hz/60）：平均 `5P(V 逐帧) + (raster + 5P(H))×h`。h=0.5（30Hz）≈ 省 25%；h=1/3（20Hz）≈ 省 33%。**只省得掉一半税**（V 在屏幕上跑着），价值=改动极小、先行试水。
- **正确性红线**：仅区域模式有效。无区域时 R=相机视矩形，相机一动缓冲内容必变，降频=全屏拖影。实现内置规则：**检测到无启用区域 → 强制全速**。

### B2（全链降频：需 3 级离屏 + 廉价 blit）
- 补第三张缓冲 SubV 承载 V 趟（与 H 同频刷新），`_final` 材质退化为 `dir=0` 单采样 blit（每帧仅 1 采样，无模糊）。
- 成本：`P(逐帧 blit) + (raster + 5P + 5P)×h`。h=0.5 ≈ 省 40%；h=1/3 ≈ 省 57%。代价=+1 张 RT、+1 次 render pass 切换（正是 §临界 R* 讨论里的固定开销项——区域大时才值得）。
- V 的目的地从屏幕像素变成（可再降半的）缓冲像素，观感≈再降一档 scale_idx。

### 事件强制刷新（B1/B2 一并实现的兜底）
以下事件将下一帧钉为全速刷新，压死最坏拖影：动画状态切换 / 受击击飞 / knockout 弹起落地 / 跳跃落地 / 相机瞬移 / 区域集合变化（T 键、节点增删）/ 软边开启首帧。判定成本 O(角色数) 可忽略。

### 验收清单（决定采纳与否，全部在 MaxHub 上做）
1. 行走最高速：30Hz 下影位置滞后（≈速度×1/30s）是否肉眼可察；
2. 击飞/冲刺轨迹：强制刷新是否消除重影；
3. 昼夜快进：影子方向步进感（预期 20Hz 无感）；
4. 多同屏角色：滞后叠加的最坏情况；
5. 帧率差：hz=0/30/20 三档 vs `L` 关。

### 改动面与明确不做
- 改动集中于 `shadow_soft_edge.gd`（`_process`/`_sync`/`_set_buffers_update` + 2 个 export）；B2 另需重建三级链（材质已具备）。controller/区域/shader/文档外文件零改动。
- **不做**：姿势帧快照缓存（太阳连续漂移污染缓存 key、体积失控、miss 即全链重糊）；静止场景脏检查（idle 动画与光照恒动，预期收益≈0）。
