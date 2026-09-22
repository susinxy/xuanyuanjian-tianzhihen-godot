class_name InteractGate
extends Node

## 船闸反应件（S2-M1-B2 G 组，法典第十条⑤）：interacted→门体 Polygon2D 上提
## 开门（position:y 单轴 tween，复合属性标量陷阱绕行）+ gate_seconds 限时
## 倒计时，到点走 force_advance_current(timeout_reason)——复用 T2 强推链：
## 赢链落位才判清源段，被死亡重跑顶位则零副作用（G3 集成面）。
## R12 纪律：倒计时 lambda **只捕实例 id**（触发件/壳各一枚）+ 局部值拷贝，
## 零 await 零节点引用——丢弃重建的段里触发件先亡 → id 失效 → 静默取消，
## 绝不 resume-on-freed。

@export var door_path: NodePath
@export var gate_seconds := 6.0
@export var timeout_reason := &"gate_timeout"

var _door: Polygon2D


func _ready() -> void:
	# 跨节点引用判例：NodePath 导出在 _ready 解析（.tscn 文本对象赋值恒 null）
	_door = get_node_or_null(door_path) as Polygon2D
	var trig := get_parent() as InteractTrigger
	if trig:
		trig.interacted.connect(_on_interacted)


func _on_interacted() -> void:
	var trig := get_parent() as InteractTrigger
	if trig == null or not is_instance_valid(trig):
		return
	var shell := trig.find_shell()
	if shell == null:
		return   # 无壳=无段可推，静默
	if _door:
		var tw := create_tween()
		tw.tween_property(_door, "position:y", _door.position.y - 320.0, 0.6)
	# 只捕实例 id（GDScript 标量捕获=拷贝，正合需求；成员 timeout_reason
	# 直引会隐式捕 self=节点引用，先拷成局部值）
	var trig_id := trig.get_instance_id()
	var shell_id := shell.get_instance_id()
	var reason: StringName = timeout_reason
	var timer := get_tree().create_timer(gate_seconds)
	timer.timeout.connect(func() -> void:
		if not is_instance_id_valid(trig_id) or not is_instance_id_valid(shell_id):
			return   # 段被丢弃重建=倒计时随旧触发件作废（静默取消）
		var t := instance_from_id(trig_id) as InteractTrigger
		var sh := instance_from_id(shell_id) as ChapterShell
		if t == null or sh == null or t.find_shell() != sh:
			return   # 双 id 各自还活着但关系已散架：同样作废
		sh.force_advance_current(reason)
	)
