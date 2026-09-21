# 光照与阴影系统 — 配置指南（2026-09-20 光照收编版）

> 本文取代旧版"每个 stage 手摆 L3 节点树"教程——那套手工流程随 test_stage 退役，
> **昼夜三件套现已预置在 base_stage 骨架里，装配者默认零操作**。
> 收编案卷见根目录 PLUGIN_CHANGES；执法见 STAGE_ASSEMBLY 法典九条 R10。

## 一、三层架构与接线现状

| 层 | 内容 | 载体 | 状态 |
|---|---|---|---|
| L1 全局 | DayNightManager / ShadowSoftEdge autoload、SDF 配置 | project.godot | ✅ 常驻 |
| L2 角色阴影 | ShadowRenderer 动态创建 + ShadowBox 遮罩 + SDF shader | `QuiverCharacter._ready` | ✅ 自动，随太阳角旋转 |
| L3 场景昼夜 | CanvasModulate + KeyLight + DayNightController | `base_stage.tscn` 的 `Ambient/` | ✅ 骨架预置，**空数据=自禁** |

## 二、装配者视角（就两个可选项）

1. **挂时间数据**：`Ambient/DayNightController.scene_time_data` 填一份 SceneTimeData
   （起步件在 `resources/lighting/`：`day_neutral` 定格正午 / `day_cycle_default`
   300 秒四相位循环 / `day_cycle_demo` 60 秒快循环=演示档）。
   **留空=本地点无昼夜（画布纯白，行为与收编前逐帧等价）**。
   法定实配对偶：ref_a=空数据负例、ref_b=挂 `day_cycle_demo` 的活体正例（契约 LC 组锁）。
   自建数据=复制起步件改四相位字典（`_init` 已给全默认值，tres 里只写要改的）。
2. **摆阴影区域**（性能件）：地点根下加 `ShadowRegion`（ReferenceRect 拖框）。
   语义：实心/软边阴影都只在框内生成；**0 个框=全屏回退**；多框=并集但**重叠处
   双倍变暗（禁止重叠）**。实配参考=`stage_ref_b.tscn`（覆盖全战区一框）。

## 三、自动档说明（为什么不配软边阴影层）

软边合成是一整张全屏 Sprite，只有一个 z。**正式地点自动取
`Level.z_index - 1`**（压所有背景/裸层件之上、所有关卡内容之下，ShadowSoftEdge.
`derived_z_for` 是唯一判定点，改 Level 随动）。Run-Test 场景（非 BaseStage 根）
回退手动态导出（-1），互不干扰。

专家覆写：地点根 `BaseStage.shadow_composite_override`（哨兵=自动）。唯一合法
改值理由=本地点有"压在世界内容之上、又要被阴影压在下面"的特殊裸层件。

## 四、法典级禁令

- **DirectionalLight2D 的 `shadow_enabled` 必须 false**——阴影唯一来源是角色
  ShadowBox+SDF，开内置阴影=双重阴影+性能塌方（骨架已预置关，审稿勿改开）；
- **Background CanvasLayer `layer` 必须 < 0**（R10）——≥0 连角色带阴影层整个盖掉；
  文本校验只抓显式错写，"新 CanvasLayer 忘写 layer=默认 1"由 BaseStage 运行时
  canary push_warning 兜底。debug 背景自设 -10 合规。

## 五、剧情/法术临时光照

`DayNightManager.apply_lighting_override(override: LightingOverride, duration)`
（压暗、圣光等；override 栈出栈自动还原）。消费端=场景里的 DayNightController
——**地点须先挂 scene_time_data 才生效**（空数据自禁含不接 override 信号）。

## 六、调试面（2026-09-20 调试面板正式化：正式地点与测试场景同权）

- `=`/`+` 唤/熄全局 DebugDock（正式地点默认关、测试场景自开；按键一览常驻"帮助"页）；
- dock **"光照"交互页**：四相位按钮、循环倍速（1×/4×/16×/停）、覆盖演示（O 同款
  配方唯一源）、**高度条/阴影调试线两个 overlay 开关**（场景缺件时 debug 构建下
  自动补生成；开关状态每次拉取刷新跟随现实，无实物自动回弹）；
- 直按键 `5-8` 相位 / `O` 覆盖：dock 内置统一处理；场景自带 DebugDayNightInput
  （Run-Test 模板件）时 dock 整体让位（覆盖不双压栈，dock_test 有断言）；
  `T` 区域 / `L` 软边仍由各组件自带；
- 正式关卡 F5 验昼夜的正确姿势：进 ref_b（活体正例 60 秒循环）或在 dock 光照页
  直接点相位/开倍速，不再"改数据重跑"；
- KeyLight 现为**无贴图的参数载体**（驱动阴影方向/颜色插值）；要真实方向光效
  需给它配光照贴图（未来美术项，非装配必需）。
