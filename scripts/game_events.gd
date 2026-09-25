extends Node
## 项目侧事件总线（S1 立法，B4.5-T1 降纯总线）：插件 Events 保持上游三信号不动，
## 职责互不侵入。后续子项目只往本文件加信号（S2 flag、S3 item_picked、S4
## xp_gained……用到才加，YAGNI）。
## 历史注记（S1 立法句"一切项目概念的事件与**会话状态**住这里"中的"会话状态"
## 四字已出历史）：回跳表数据 B4.5-T1 迁账 GameSave（add_location_checkpoint/
## locations 随快照，spec §3 裁决 R2），story_checkpoint_added 信号随迁更名
## location_visited；本文件只留事件两条 + pending_jump_stage 传渡 +
## reset_session（语义收缩为只清传渡）。

## 某战斗房的全部波次清场（载荷=房节点名 StringName）
signal room_cleared(room_id: StringName)
## 玩家触发地点出口（切场前发；S2 对话/S5 存档挂点）
signal stage_exited(stage_id: StringName)

## 检查点回跳传渡：死亡/暂停界面置目标场景路径，重载后的地点经 BaseStage 消费一次即清空
var pending_jump_stage: String = ""


## 清传渡（回标题/重跑时调用）：只清 pending_jump_stage，**不清账**——
## 清账唯一口 GameSave.new_profile（spec §3：回标题≠清档）。旧"会话检查点表
## 清空"语义随 B4.5-T1 迁账寿终（表随档案：new_profile 清账=清表）。
func reset_session() -> void:
	pending_jump_stage = ""
