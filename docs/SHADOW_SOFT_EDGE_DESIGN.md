# 阴影柔边（P2）设计：共享离屏缓冲 + 可分离模糊（方案 A，可配置开关）

> 版本：v2.1
> 日期：2026-09-05
> 状态：已实现（默认关闭），L 键实测开启正常、柔化 OK；待真关卡遮挡/低配帧率验证
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
  ├─ 关闭软边：照旧把投影多边形画在自己(body 子)的 _shadow_polygon 上   ← 与现状一致
  └─ 开启软边：隐藏 _shadow_polygon，改在 ShadowSoftEdge.shadow_world 里建/更新一个 _proxy Polygon2D
               （复制 projected/vertex_colors/modulate.a + global_transform）
 模糊 shader: shaders/shadow_blur.gdshader  (5-tap 可分离高斯, uniform src/dir/texel_size/radius)
 运行时开关: input action `soft_edge_toggle`（默认物理键 L）
```
- **两级离屏**：H 模糊在 `SubH` 里做，V 模糊合进最终合成 Sprite 的材质（省一张 RT；两趟模糊都在，成本不变）。
- 关闭时：无代理、离屏缓冲 `render_target_update_mode=UPDATE_ONCE`（冻结）→ 几乎零成本、零行为差异。
- 相机同步：`ShadowCam.global_position/zoom/rotation = 主相机.copy`，`zoom` 再乘缓冲放大系数 → 世界取景不变、仅提高像素密度。
- 合成 Sprite 对齐：`position=主相机`，`scale=1/(zoom*eff)` → 均匀缩放、不旋转时能铺满视口并随 zoom 自适应（非均匀 zoom 或相机旋转未处理）。
- 缓冲分辨率：**钳制单边 ≤ 8192**（超 GPU RT 上限会渲染失败——spike 实测踩到过）。

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
- 待办：真关卡里验 §3.1 遮挡（设对 `composite_z`）；低配机测开/关帧率差以定默认档；如需再核非均匀 zoom / 相机旋转下的对齐。

## 7. 为何放弃 Line2D 裙边（v1）
Godot 4.7 `Line2D` **无逐顶点 `colors` 属性**（仅 `default_color`/`gradient`），无法把 P1 距离衰减复用到边缘；`gradient` 只按弧长，不按身体高度 → 影尖易残留等强度描边。离屏方案让阴影仍是每角色精确投影轮廓，只是**集中做一次模糊**，更干净，故改走 A。

## 8. 落地文件
- 新增 `scripts/shadow_soft_edge.gd`、`shaders/shadow_blur.gdshader`。
- 改 `scripts/character_shadow_controller.gd`（开关分支 + 代理）。
- `project.godot` 注册 autoload `ShadowSoftEdge` + 新增 input action `soft_edge_toggle`（物理键 L）。
- 一次性验证用的 spike（`scenes/_shadow_blur_spike.tscn`、`scripts/shadow_blur_spike.gd`）已删除（模糊 shader 保留复用）。
