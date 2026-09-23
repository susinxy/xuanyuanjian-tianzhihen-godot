# S2-M1-B2.5 测试主权批 · F5 人工验收单（Windows）

> **关账状态（2026-09-23）**：眼①**结构性关闭**——生产场景/模板 grep 零 `playable_override`
> 设置（null 路径成立），且用户以生产内嵌 chen 实跑 it2/it3（E 响应正常）顺带实证；
> 眼②**由 R10 三方探针关闭**（chen 本体同 harness 亦报 3×，"新角色独有病"前提证伪，非产线缺陷）。
> 本单两眼均无需再人工执行。Syncthing 忽略 `characters/playable/test_actor*` 建议随下次
> Windows 会话顺手设置（运维项，不阻塞）。

批范围 headless 已跑：**全矩阵首通 23 跑 RED=0**（含转治的 input_channel 与
R8/R9 诚实化后的 attack_freeze_repro、wp2 overlay_e2e）。本单只做机器测不了的事。

## 验收点

1. **接缝未泄漏进生产（本批唯一必眼）**：Windows 端同步到 `s2-m1-b25-done`
   后开 Godot 编辑器（工程应无报错打开），F5 从标题壳进正式场景：
   - chen 照常操控、走路/攻击如旧；E 键互动游乐场（it2/it3 同款触发件）反应如旧；
   - Inspector 抽查：正式场景（`scenes/stages/` 下任意地点/章节壳）的玩家位
     **仍嵌 chen**，`BaseStage`/壳节点的 `playable_override` 属性 = null（Empty）。
     任何一处 override 非空或场景主角变替身=接缝泄漏，报回回炉。
2. ~~新建角色听告警腿~~ **豁免**（Task6 STEP 0 三方对比探针裁决）：
   "AnimationNode is null" 定性为插件 walker 撞引擎空槽的预存噪音——
   chen 本体在同 harness 下同报 3×，非创建产线缺陷，无需专耳验收。
   若日常编辑器出现**新类别**告警，另开案登记。

任何一条异常：截图/日志发回，按 SDD 修复轮回炉。
