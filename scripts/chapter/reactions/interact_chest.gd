class_name InteractChest
extends Node

## 宝箱反应件（S2-M1-B2 C 组，法典第十条⑤）：挂 InteractTrigger 子节点、
## _ready 订阅 interacted。判重单一真源在 session.open_chest（节点可被段丢弃
## 重建换新实例，二次开仍被 session 拦下）：首开→可选 grant 旗；无论首开与否
## 都显式 consume()（非重复触发件已在发射前自消耗，此处是⑤的收口仪式）并
## 0.4s 缩小消失→释放触发件（连带本件）。

@export var chest_id: StringName = &""
## 非空=首开时向壳 session 补挂此旗（无奖励旗的宝箱留空）
@export var grants_flag: StringName = &""


func _ready() -> void:
	var trig := get_parent() as InteractTrigger
	if trig:
		trig.interacted.connect(_on_interacted)


func _on_interacted() -> void:
	var trig := get_parent() as InteractTrigger
	if trig == null or not is_instance_valid(trig):
		return
	var shell := trig.find_shell()
	if shell == null:
		return   # 无壳=无 session 判重主体，静默不反应（独立场地不成章）
	trig.consume()
	if shell.session.open_chest(chest_id):
		if grants_flag != &"":
			shell.session.add_flag(grants_flag)
	# 消失演出 0.4s（tween 绑触发件本体）：二次判定已由 session 兜底，
	# 释放节点只负责"空箱不再诱惑"的视觉与物理清算
	var tw := trig.create_tween()
	tw.tween_property(trig, "scale", Vector2.ZERO, 0.4)
	tw.tween_callback(trig.queue_free)
