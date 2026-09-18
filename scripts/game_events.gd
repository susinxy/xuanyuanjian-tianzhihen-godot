extends Node
## 项目侧事件总线（S1 立法）：一切"项目概念"（房间/检查点/切场）的事件与
## 会话状态住这里；插件 Events 保持上游三信号不动，职责互不侵入。
## 后续子项目只往本文件加信号（S2 flag、S3 item_picked、S4 xp_gained……
## 用到才加，YAGNI）。

## 某战斗房的全部波次清场（载荷=房节点名 StringName）
signal room_cleared(room_id: StringName)
## 检查点注册完成（S5 的自动存档触发源；S1 消费方=DeathScreen 重建列表）
signal story_checkpoint_added(stage_id: StringName)
## 玩家触发地点出口（切场前发；S2 对话/S5 存档挂点）
signal stage_exited(stage_id: StringName)

## 会话检查点表：[{stage_id, scene_path}]，新进入追加；同 stage_id 重入时
## 摘旧追新（保持"新→旧"渲染顺序稳定）
var _session_checkpoints: Array[Dictionary] = []


func add_checkpoint(stage_id: StringName, scene_path: String) -> void:
	if stage_id == &"" or scene_path.is_empty():
		push_warning("GameEvents: 检查点参数不全，忽略 (id=%s path=%s)" % [stage_id, scene_path])
		return
	for i in _session_checkpoints.size():
		if _session_checkpoints[i].stage_id == stage_id:
			_session_checkpoints.remove_at(i)
			break
	_session_checkpoints.append({stage_id = stage_id, scene_path = scene_path})
	story_checkpoint_added.emit(stage_id)


func get_checkpoints() -> Array[Dictionary]:
	return _session_checkpoints.duplicate()


## 清会话（回标题时调用；"重走一遍"同）
func reset_session() -> void:
	_session_checkpoints.clear()
