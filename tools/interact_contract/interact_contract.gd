extends Node

## 互动触发件契约（S2-M1-B2 I 组）：InteractTrigger 的距感/E 键发射/一次性与
## 冷却/旗标门/consume 消耗/提示随距翻转。形制=container_contract 同款：
## 每流完成旗（协程炸跳段防线）+ _check/_frames/_wait_until。运行：
## godot --headless --path . res://tools/interact_contract/interact_contract.tscn

const FIX_CHAPTER := "res://tools/interact_contract/fixtures/chapter_it.tscn"
## I 组注入判例（法典输入流+控制器定档）：interact 绑定是 keycode:0 /
## physical:69，_unhandled_input 只收原始按键 → raw InputEventKey 双键位都填
## KEY_E（spell 盖戳判例同款），is_action_pressed 走默认 exact=false。

var _fails := 0
var _finished := false
var _done := {}    # 各流完成旗：i1..i6
var _hits: Array[int] = []   # interacted 计数（lambda 捕获数组引用通道，E6 判例）


func _ready() -> void:
	await _flow_i1()
	_check(bool(_done.get("i1")), "I1 流全序列执行完成（协程静默中断防线）")
	await _flow_i2()
	_check(bool(_done.get("i2")), "I2 流全序列执行完成（协程静默中断防线）")
	await _flow_i3()
	_check(bool(_done.get("i3")), "I3 流全序列执行完成（协程静默中断防线）")
	await _flow_i4()
	_check(bool(_done.get("i4")), "I4 流全序列执行完成（协程静默中断防线）")
	await _flow_i5()
	_check(bool(_done.get("i5")), "I5 流全序列执行完成（协程静默中断防线）")
	await _flow_i6()
	_check(bool(_done.get("i6")), "I6 流全序列执行完成（协程静默中断防线）")
	_finished = true
	_check(_finished, "全序列执行完成（协程静默中断防线）")
	print("════════ interact-contract: %s ════════" % ("PASS" if _fails == 0 else "FAIL"))
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails += 1
	print("  %s: %s" % ["PASS" if ok else "FAIL", label])


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _wait_until(pred: Callable, cap: int = 600) -> bool:
	for _i in cap:
		if pred.call():
			return true
		await get_tree().physics_frame
	return pred.call()


## 一次一场：新壳实例化（新 session、段丢弃重建=触发件全新生效态）
func _make_shell() -> ChapterShell:
	var ps := load(FIX_CHAPTER) as PackedScene
	var shell: ChapterShell = ps.instantiate()
	get_tree().root.add_child.call_deferred(shell)
	await _frames(20)
	return shell


func _dismantle(shell: ChapterShell) -> void:
	shell.queue_free()
	await _frames(6)


func _find_trigger(shell: ChapterShell) -> InteractTrigger:
	for n in shell._current.find_children("*", "", true, false):
		if n is InteractTrigger:
			return n
	return null


## raw E 键连发（down→up），构造法逐位镜像 helper_e2e._os_key_full_chain
func _press_e() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_E
	ev.physical_keycode = KEY_E
	ev.pressed = true
	Input.parse_input_event(ev)
	var ev2 := InputEventKey.new()
	ev2.keycode = KEY_E
	ev2.physical_keycode = KEY_E
	ev2.pressed = false
	Input.parse_input_event(ev2)
	await get_tree().physics_frame


## I1 距外 E 不发 / 距内发恰一次（法典第十条：入口=传送进区≥2 帧后判在距）
func _flow_i1() -> void:
	var shell := await _make_shell()
	var trig := _find_trigger(shell)
	_hits = []
	trig.interacted.connect(func(): _hits.append(1))
	# 壳出生位=入口(500,600)本在感应区内——先挪出，等 exited 计数结算
	shell.playable.global_position = Vector2(1500, 600)
	var out: bool = await _wait_until(func(): return not trig.in_range(), 120)
	_check(out, "I1a 前置：角色挪到距外（感应盒 160 宽 vs x=1500）")
	await _press_e()
	await _frames(3)
	_check(_hits.is_empty(), "I1b 距外按 E 不发信号")
	shell.playable.global_position = Vector2(500, 600)
	var inr: bool = await _wait_until(func(): return trig.in_range(), 120)
	_check(inr, "I1c 传送进感应区后有限帧内 in_range 成立")
	await _press_e()
	var fired: bool = await _wait_until(func(): return _hits.size() == 1, 60)
	_check(fired, "I1d 距内按 E 发信号恰一次")
	await _dismantle(shell)
	_done["i1"] = true


## I2 一次性：非 repeatable 触发一次后不再发
func _flow_i2() -> void:
	var shell := await _make_shell()
	var trig := _find_trigger(shell)
	_hits = []
	trig.interacted.connect(func(): _hits.append(1))
	var inr: bool = await _wait_until(func(): return trig.in_range(), 120)
	_check(inr, "I2a 前置：入口落位即在感应区")
	await _press_e()
	var first: bool = await _wait_until(func(): return _hits.size() == 1, 60)
	_check(first, "I2b 首按发射")
	await _press_e()
	await _frames(3)
	_check(_hits.size() == 1, "I2c 一次性：第二次按 E 不再发")
	await _dismantle(shell)
	_done["i2"] = true


## I3 repeatable + cooldown=1.0s：冷却窗内不重发，65 物理帧（headless 恒速
## ≈60 tick/s ⇒ ≥1.05s 墙钟）后第二发
func _flow_i3() -> void:
	var shell := await _make_shell()
	var trig := _find_trigger(shell)
	_hits = []
	trig.interacted.connect(func(): _hits.append(1))
	trig.repeatable = true
	trig.cooldown = 1.0
	var inr: bool = await _wait_until(func(): return trig.in_range(), 120)
	_check(inr, "I3a 前置：在感应区")
	await _press_e()
	var first: bool = await _wait_until(func(): return _hits.size() == 1, 60)
	_check(first, "I3b 可重复首发射")
	await _frames(10)
	await _press_e()
	await _frames(3)
	_check(_hits.size() == 1, "I3c 冷却窗内（~0.2s < 1.0s）不重发")
	await _frames(65)
	await _press_e()
	var second: bool = await _wait_until(func(): return _hits.size() == 2, 60)
	_check(second, "I3d 65 帧后冷却期满第二发")
	await _dismantle(shell)
	_done["i3"] = true


## I4 旗标门：requires_flag 无旗静默拒发 → 壳 session.add_flag 后放行恰一次
func _flow_i4() -> void:
	var shell := await _make_shell()
	var trig := _find_trigger(shell)
	_hits = []
	trig.interacted.connect(func(): _hits.append(1))
	trig.requires_flag = &"gate_x"
	var inr: bool = await _wait_until(func(): return trig.in_range(), 120)
	_check(inr, "I4a 前置：在感应区")
	await _press_e()
	await _frames(3)
	_check(_hits.is_empty(), "I4b 无旗拒发（静默，不吃树）")
	shell.session.add_flag(&"gate_x")
	await _press_e()
	var fired: bool = await _wait_until(func(): return _hits.size() == 1, 60)
	_check(fired, "I4c 补旗后放行恰一次")
	await _dismantle(shell)
	_done["i4"] = true


## I5 consume()：反应侧显式消耗后不再响应，且 Prompt 在距也永久隐身
func _flow_i5() -> void:
	var shell := await _make_shell()
	var trig := _find_trigger(shell)
	_hits = []
	trig.interacted.connect(func(): _hits.append(1))
	var inr: bool = await _wait_until(func(): return trig.in_range(), 120)
	_check(inr, "I5a 前置：在感应区")
	trig.consume()
	await _press_e()
	await _frames(3)
	_check(_hits.is_empty(), "I5b consume 后按 E 不再响应")
	var prompt := trig.get_node("Prompt") as Label
	_check(prompt != null and not prompt.visible and trig.in_range(),
 			"I5c consume 后 Prompt 在距仍隐身")
	await _dismantle(shell)
	_done["i5"] = true


## I6 Prompt：文本=导出值，visible 随在距翻转
func _flow_i6() -> void:
	var shell := await _make_shell()
	var trig := _find_trigger(shell)
	var prompt := trig.get_node("Prompt") as Label
	_check(prompt != null and prompt.text == trig.prompt_text,
 			"I6a Prompt 文本=prompt_text 导出值")
	var inr: bool = await _wait_until(func(): return trig.in_range(), 120)
	await _frames(2)
	_check(inr and prompt.visible, "I6b 在距显示")
	shell.playable.global_position = Vector2(1500, 600)
	var gone: bool = await _wait_until(func(): return not prompt.visible, 120)
	_check(gone, "I6c 出距隐藏")
	shell.playable.global_position = Vector2(500, 600)
	var back: bool = await _wait_until(func(): return prompt.visible, 120)
	_check(back, "I6d 再入距重新显示")
	await _dismantle(shell)
	_done["i6"] = true
