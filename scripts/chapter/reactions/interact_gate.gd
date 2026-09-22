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
# 一次性闩：见 _on_interacted 顶部说明——封堵 repeatable 触发件的"双推跳段"雷。
var _armed := false


func _ready() -> void:
	# 跨节点引用判例：NodePath 导出在 _ready 解析（.tscn 文本对象赋值恒 null）
	_door = get_node_or_null(door_path) as Polygon2D
	var trig := get_parent() as InteractTrigger
	if trig:
		trig.interacted.connect(_on_interacted)


func _on_interacted() -> void:
	# _armed 闩封堵"repeatable × 门"多段静默跳过雷：作者若把触发件设 repeatable=true，
	# 则每次 interacted 都会另起一枚倒计时，而倒计时目标在注册时按 force 时的 _current
	# 现取——首链落位 settle 后，第二枚倒计时到点会把**新段**也一并 advance，静默跳过
	# 一整段剧情。闩令每个门节点实例的倒计时至多开一次（与 repeatable 设定无关）。
	if _armed:
		return
	var trig := get_parent() as InteractTrigger
	if trig == null or not is_instance_valid(trig):
		return
	var shell := trig.find_shell()
	if shell == null:
		return   # 无壳=无段可推，静默
	# 三关（trig 有效 + 有壳）通过、即将开门起钟——先落闩，杜绝同实例二次起钟
	_armed = true
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
