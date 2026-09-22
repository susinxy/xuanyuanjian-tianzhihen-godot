class_name InteractQte
extends Node

## 跳河 QTE 反应件（S2-M1-B2 Q 组，法典第十条⑤）：固定悲剧——玩家至此必落河，
## 本件只决定"多久后落"。窗口循环：开窗 window 秒→窗内收到父触发件 interacted
## 且当前在开态=成功，走 force_advance_current(success_reason)（复用 T2 赢链：
## 落位才判清源段）；窗尾未收=失败，对壳 playable 钳制扣伤（maxi(1, health -
## damage)，**永不越 0**——先读 quiver_attributes health_current setter：越 0 会
## 广播 health_depleted 触发死亡重跑，与"悲剧只延迟不否决"相悖）→ 歇拍
## pause_between → 再开窗，无限循环直到某窗成功。距外（非开态）按 E 经触发件
## repeatable 拒发在前，本件不看，故零成本、窗口按自身排期继续。
## R15 纪律：整条链零 await，全部 create_timer → timeout lambda；每个 lambda
## **只捕本件实例 id** + 相位枚举（局部值拷贝），触节点前先 is_instance_id_valid
## 自门卫——被丢弃/缓存摘树的旧链静默自灭，绝不 resume-on-freed、绝不在成功后
## 由陈旧计时器补刀。

enum Phase { IDLE, OPEN, COOLDOWN, DONE }

@export var window := 1.2
@export var pause_between := 2.6
@export var damage := 15
@export var success_reason: StringName = &"qte_jump"

## 契约可读公开面
var window_open := false   # 当前是否处开态（QTE 据此接单，距外按 E 由触发件先拒）
var failures := 0          # 已失败轮数

var _phase: Phase = Phase.IDLE


func _ready() -> void:
	# 跨节点引用判例：父触发件的 interacted 在 _ready 接（信号连线，非对象拖拽）
	var trig := get_parent() as InteractTrigger
	if trig:
		trig.interacted.connect(_on_interacted)
	_open_window()


func _on_interacted() -> void:
	# 仅开态接单：歇拍/已结束/未开=静默（距外拒发已在触发件侧，此为第二道闸）
	if _phase != Phase.OPEN:
		return
	_phase = Phase.DONE
	window_open = false
	var trig := get_parent() as InteractTrigger
	if trig == null or not is_instance_valid(trig):
		return
	var shell := trig.find_shell()
	if shell == null:
		return   # 无壳=无段可推，静默
	shell.force_advance_current(success_reason)


func _open_window() -> void:
	_phase = Phase.OPEN
	window_open = true
	_schedule(window, _on_window_expire)


func _on_window_expire() -> void:
	if _phase != Phase.OPEN:
		return   # 陈旧/已被消费的开态超时：作废
	window_open = false
	_apply_damage()
	failures += 1
	_phase = Phase.COOLDOWN
	_schedule(pause_between, _open_window)


func _apply_damage() -> void:
	var trig := get_parent() as InteractTrigger
	if trig == null:
		return
	var shell := trig.find_shell()
	if shell == null or shell.playable == null:
		return
	var attrs := shell.playable.attributes
	# 钳制下限 1：setter 面若见 <=0 会广播 health_depleted→死亡重跑（悲剧不该
	# 变否决），故永不经此路越 0（Q3 连败钳伤实证）
	attrs.health_current = maxi(1, int(attrs.health_current) - damage)


func _schedule(secs: float, continuation: Callable) -> void:
	# lambda 只捕实例 id + 相位续命，零节点引用；出树/被 free→id 失效→静默
	var self_id := get_instance_id()
	var timer := get_tree().create_timer(secs)
	timer.timeout.connect(func() -> void:
		if not is_instance_id_valid(self_id):
			return
		var q := instance_from_id(self_id) as InteractQte
		if q == null:
			return
		continuation.call()
	)
