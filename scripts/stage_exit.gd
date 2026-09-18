extends Area2D
## 跨地点出口触发件（地点制契约）：玩家（area2d:player）进入即发
## stage_exited 并转场到 next_stage_path；防重入旗（转场 await 期间可再次
## 交叠）。检测 body；identity 过滤靠 area2d:player 组，但 Area2D 仍需要
## collision_mask 与 body 的 collision_layer 求交非零才收得到 body_entered
## （S1-T4 探针实测：chen 落地 body layer=16761856、spar=16384，均 ⊇ 高度
## 位段），故 _ready 里写死全高度层掩码（QuiverCharacter 静态单一来源）。

@export_file("*.tscn") var next_stage_path := ""

var _triggered := false


func _ready() -> void:
	collision_mask = QuiverCharacter.get_all_height_layers_mask()  # 16760832
	monitoring = true
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _triggered or not body.is_in_group("area2d:player"):
		return
	if next_stage_path.is_empty():
		push_error("StageExit 未配置 next_stage_path: %s" % get_path())
		return
	_triggered = true
	# StageExit 不认"自己属于哪个地点"（可被任何地点实例化）：载荷取当前场景
	# （BaseStage）的 stage_id 导出；非地点场景（理论不该发生）发空 StringName
	var stage: Node = get_tree().current_scene
	var raw: Variant = stage.get("stage_id") if stage != null else null
	GameEvents.stage_exited.emit(raw if raw is StringName else &"")
	ScreenTransitions.transition_to_scene(next_stage_path)
