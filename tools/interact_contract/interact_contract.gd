extends Node

## 互动触发件契约（S2-M1-B2 I/C/G/Q 组）：InteractTrigger 的距感/E 键发射/
## 一次性与冷却/旗标门/consume 消耗/提示随距翻转/摘树计数清算（I 组）+
## 宝箱反应件 session 判重（C 组）+ 船闸限时强推复用 T2 链（G 组）+
## 跳河 QTE 窗口循环/失败钳伤不死/距外按 E 零成本（Q 组）。
## 形制=container_contract 同款：每流完成旗（协程炸跳段防线）+
## _check/_frames/_wait_until。运行：
## godot --headless --path . res://tools/interact_contract/interact_contract.tscn

const FIX_CHAPTER := "res://tools/interact_contract/fixtures/chapter_it.tscn"
const FIX_CHAPTER2 := "res://tools/interact_contract/fixtures/chapter_it2.tscn"
const FIX_CHAPTER3 := "res://tools/interact_contract/fixtures/chapter_it3.tscn"
## Q 组时间预算与夹具同源（river：window 0.6 / pause 1.2 / damage 15，
## 数值改一边必改另一边——cap 由这些常数推导，不留裸魔法数）
const QTE_WINDOW := 0.6
const QTE_PAUSE := 1.2
const QTE_DAMAGE := 15
## I 组注入判例（法典输入流+控制器定档）：interact 绑定是 keycode:0 /
## physical:69，_unhandled_input 只收原始按键 → raw InputEventKey 双键位都填
## KEY_E（spell 盖戳判例同款），is_action_pressed 走默认 exact=false。

var _fails := 0
var _finished := false
var _done := {}    # 各流完成旗：i1..i7 / c / g / q1..q4
var _hits: Array[int] = []   # interacted 计数（lambda 捕获数组引用通道，E6 判例）
var _chest_ids: Array[StringName] = []   # session.chest_opened 收录（C 组）
var _flag_ids: Array[StringName] = []    # session.flag_added 收录（C 组）


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
	await _flow_i7()
	_check(bool(_done.get("i7")), "I7 流全序列执行完成（协程静默中断防线）")
	await _flow_c()
	_check(bool(_done.get("c")), "C 流全序列执行完成（协程静默中断防线）")
	await _flow_g()
	_check(bool(_done.get("g")), "G 流全序列执行完成（协程静默中断防线）")
	await _flow_q1()
	_check(bool(_done.get("q1")), "Q1 流全序列执行完成（协程静默中断防线）")
	await _flow_q2()
	_check(bool(_done.get("q2")), "Q2 流全序列执行完成（协程静默中断防线）")
	await _flow_q3()
	_check(bool(_done.get("q3")), "Q3 流全序列执行完成（协程静默中断防线）")
	await _flow_q4()
	_check(bool(_done.get("q4")), "Q4 流全序列执行完成（协程静默中断防线）")
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
func _make_shell(path: String = FIX_CHAPTER) -> ChapterShell:
	var ps := load(path) as PackedScene
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


func _find_qte(shell: ChapterShell) -> InteractQte:
	for n in shell._current.find_children("*", "", true, false):
		if n is InteractQte:
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


## I7 摘树计数清算（R13 定档）：评审预测的"detach 不补发 exited→回挂双计→
## stale-true 误发射"漂移，4.7.1 headless 探针实测**不复现**（PROBE：摘树即补发
## 一枚 exited 归零、回挂 insert-scan 重发 entered——两事件对称）。守卫照落为
## 结构性保险（不赌引擎该行为），本流锁定"detach/reattach 往返后距感语义正确"
## 的观测面：出距结算归零 + 距外按 E 不发。载体=chapter_it2 的 seg_chest
## （触发件与出生位同址，往返期间角色不动身）。
func _flow_i7() -> void:
	var shell := await _make_shell(FIX_CHAPTER2)
	var trig := _find_trigger(shell)
	_hits = []
	trig.interacted.connect(func(): _hits.append(1))
	var inr: bool = await _wait_until(func(): return trig.in_range(), 120)
	_check(inr, "I7a 前置：出生位与感应盒重叠 → in_range")
	var seg_inst: int = shell._current.get_instance_id()
	shell.session.mark_cleared(&"seg_chest")
	shell.switch_segment(&"seg_gate", &"default")
	var away: bool = await _wait_until(
			func(): return shell.current_segment_id() == &"seg_gate", 600)
	_check(away, "I7b 判清后离开=缓存保活腿（remove_child 摘树，不 free）")
	shell.switch_segment(&"seg_chest", &"default")
	var back: bool = await _wait_until(
			func(): return shell.current_segment_id() == &"seg_chest", 600)
	_check(back and shell._current.get_instance_id() == seg_inst,
			"I7c 再入=缓存复用同实例（回挂 insert-scan 就地重发 body_entered）")
	# 回挂后计数恰=1（探针实测对称）；出距一枚 exited 即归零
	shell.playable.global_position = Vector2(1500, 600)
	var drained: bool = await _wait_until(func(): return trig._in_range == 0, 120)
	_check(drained, "I7d 回挂往返后传送出距：计数结算归零（无双计残留）")
	await _press_e()
	await _frames(3)
	_check(_hits.is_empty(), "I7e 往返后距外按 E 不发（stale-true 误发射防线）")
	await _dismantle(shell)
	_done["i7"] = true


## C 流（宝箱，一次一场）：首开=chest_opened 恰一 + grants_flag 落 session +
## 触发件 0.4s 缩小释放；消亡窗内连按无二次 loot；丢弃重建出的假宝箱再开被
## session 判重拦下（chest_opened/flag_added 总量恒一）。
func _flow_c() -> void:
	var shell := await _make_shell(FIX_CHAPTER2)
	_chest_ids = []
	_flag_ids = []
	shell.session.chest_opened.connect(func(id): _chest_ids.append(id))
	shell.session.flag_added.connect(func(id): _flag_ids.append(id))
	var trig := _find_trigger(shell)
	var trig_id: int = trig.get_instance_id()
	var inr: bool = await _wait_until(func(): return trig.in_range(), 120)
	_check(inr, "C0 前置：出生位与宝箱触发件重叠→在距")
	await _press_e()
	var opened: bool = await _wait_until(
			func(): return _chest_ids == [&"it_chest"], 60)
	await _frames(2)
	_check(opened and shell.session.has_flag(&"chest_it")
			and _flag_ids == [&"chest_it"],
			"C1a 首开：chest_opened 恰一 + grants_flag 同步恰一进 session")
	# 消亡窗（0.4s tween 未完）内连按：触发件已自消耗→无二次发射
	await _press_e()
	await _frames(3)
	_check(_chest_ids.size() == 1 and _flag_ids.size() == 1,
			"C2 消亡窗内再按 E：无二次 loot（消耗先于信号）")
	var gone: bool = await _wait_until(
			func(): return not is_instance_id_valid(trig_id), 120)
	_check(gone, "C1b 触发件 0.4s 缩小后释放（实例 id 失效）")
	# C3 丢弃重建假宝箱：chest 段从未判清→离开走 queue_free 腿→回=新实例
	var seg_inst: int = shell._current.get_instance_id()
	shell.switch_segment(&"seg_gate", &"default")
	var away: bool = await _wait_until(
			func(): return shell.current_segment_id() == &"seg_gate", 600)
	shell.switch_segment(&"seg_chest", &"default")
	var back: bool = await _wait_until(
			func(): return shell.current_segment_id() == &"seg_chest", 600)
	_check(away and back and shell._current.get_instance_id() != seg_inst,
			"C3a 未清段离开再回=丢弃重建（段实例 id 已更换）")
	var trig2 := _find_trigger(shell)
	_check(trig2 != null and trig2.get_instance_id() != trig_id,
			"C3b 重建出新触发件新反应节点（无旧消耗态携带）")
	var inr2: bool = await _wait_until(func(): return trig2.in_range(), 120)
	# 判例：等"释放"的轮询必须先存实例 id——对已 free 对象调 get_instance_id()
	# 的每帧运行时错误让 pred 返回 null=恒假（首轮 C3c 假红根因）
	var tid2: int = trig2.get_instance_id()
	await _press_e()
	var gone2: bool = await _wait_until(
			func(): return not is_instance_id_valid(tid2), 120)
	_check(inr2 and gone2 and _chest_ids == [&"it_chest"]
			and _flag_ids.size() == 1,
			"C3c 假宝箱再开：open_chest 判重 false（信号总量仍各一，无二次 grant）")
	await _dismantle(shell)
	_done["c"] = true


## G 流（船闸，gate_seconds=1.0 夹具加速）：G1 门体上提；G2 倒计时到点强推
## 自动切下段 + 赢链判清源段（T2 成功腿）+ 残血原样穿越（D4/F-1 语义穿透）；
## G3 竞态重演：force 链在途×restart 顶位→赢的是重跑、落回闸段入口且
## cleared==false（输链零副作用），余尘后倒计时无再推（窗口静默）。
func _flow_g() -> void:
	var shell := await _make_shell(FIX_CHAPTER2)
	shell.switch_segment(&"seg_gate", &"default")
	var arrived: bool = await _wait_until(
			func(): return shell.current_segment_id() == &"seg_gate", 600)
	var trig := _find_trigger(shell)
	var door := shell._current.get_node_or_null("Door") as Polygon2D
	var y0 := door.position.y if door != null else 0.0
	var inr: bool = await _wait_until(func(): return trig.in_range(), 120)
	_check(arrived and door != null and inr,
			"G0 前置：落闸段 + 门体在位 + 出生重叠在距")
	shell.playable.attributes.health_current = 40   # 强推链前先埋残血（G2c 观察面）
	await _press_e()
	var moved: bool = await _wait_until(
			func(): return door.position.y < y0 - 100.0, 40)
	_check(moved, "G1 interacted 后门 tween 上提中（40 帧内 y<起点-100）")
	# G2 限时到点：1.0s 倒计时 + force 链 90f 静默 → 自动落下一段
	var landed: bool = await _wait_until(
			func(): return shell.current_segment_id() == &"seg_it_end", 600)
	_check(landed, "G2a 倒计时到点自动强推：current=seg_it_end")
	await _frames(30)   # 盖过链尾信标窗，防"先到后改"漏网
	_check(shell.session.is_cleared(&"seg_gate"),
			"G2b T2 成功腿：赢链把源段（seg_gate）判清")
	_check(shell.playable.attributes.health_current == 40,
			"G2c 强推不治疗：残血 40 原样带进下段（F-1 语义穿透船闸）")
	await _dismantle(shell)
	# --- G3 竞态（新的一场）：force 链在途 × restart 顶位
	shell = await _make_shell(FIX_CHAPTER2)
	shell.switch_segment(&"seg_gate", &"default")
	var arrived3: bool = await _wait_until(
			func(): return shell.current_segment_id() == &"seg_gate", 600)
	var trig3 := _find_trigger(shell)
	var inr3: bool = await _wait_until(func(): return trig3.in_range(), 120)
	_check(arrived3 and inr3, "G3a 前置：新 shell 落闸段且在距")
	var gen0: int = shell._transition_gen
	var whys: Array[StringName] = []
	shell.segment_restarted.connect(func(w): whys.append(w))
	await _press_e()
	# 1.0s 倒计时到点后 force 登记（gen+1）；趁其 90f 静默窗顶入 restart
	var armed: bool = await _wait_until(
			func(): return shell._transition_gen > gen0, 300)
	shell.restart_segment(&"death")
	var landed3: bool = await _wait_until(func(): return not whys.is_empty(), 600)
	await _frames(30)
	_check(armed and landed3 and whys == [&"death"]
			and shell.current_segment_id() == &"seg_gate",
			"G3b 重跑链赢：落回闸段入口、被顶 force 链零信标")
	_check(not shell.session.is_cleared(&"seg_gate"),
			"G3c 输链不留判清（T2 判词实船集成面：重跑走丢弃重建）")
	await _frames(300)
	_check(shell.current_segment_id() == &"seg_gate" and whys == [&"death"],
			"G3d 余尘静默：300 帧无后续强推/信标（作废倒计时不复活）")
	await _dismantle(shell)
	_done["g"] = true


## Q1 成功腿：开窗→窗内 E→赢链落尾段 + 判清河段 + health 原样不动。
func _flow_q1() -> void:
	var shell := await _make_shell(FIX_CHAPTER3)
	var qte := _find_qte(shell)
	shell.playable.attributes.health_current = 100
	var hp0: int = shell.playable.attributes.health_current
	var opened: bool = await _wait_until(func(): return qte.window_open, 60)
	_check(opened, "Q1a 出生河段开窗（window_open 有限帧内 true）")
	await _press_e()
	var landed: bool = await _wait_until(
			func(): return shell.current_segment_id() == &"seg_it_end", 600)
	_check(landed, "Q1b 窗内 E → force 赢链落尾段（seg_it_end）")
	await _frames(30)
	_check(shell.session.is_cleared(&"seg_river"),
 			"Q1c T2 成功腿：赢链把河段（seg_river）判清")
	_check(shell.playable.attributes.health_current == hp0,
 			"Q1d 成功不掉血：health 原样（hp0==hp_now）")
	await _dismantle(shell)
	_done["q1"] = true


## Q2 失败循环：开窗不接→窗尾恰掉 damage、段不变、歇拍后 window_open 再 true。
func _flow_q2() -> void:
	var shell := await _make_shell(FIX_CHAPTER3)
	var qte := _find_qte(shell)
	shell.playable.attributes.health_current = 100
	var opened: bool = await _wait_until(func(): return qte.window_open, 60)
	_check(opened, "Q2a 前置：开窗")
	var hp0: int = shell.playable.attributes.health_current
	# 窗尾结算在到期帧内原子发生（window_open=false + failures++ + 掉血同步）
	var failed: bool = await _wait_until(func(): return qte.failures == 1,
 			int((QTE_WINDOW + 0.5) * 60.0))
	_check(failed, "Q2b 不接 → 窗尾 failures 0→1（window+margin 帧内）")
	await _frames(2)
	_check(shell.playable.attributes.health_current == hp0 - QTE_DAMAGE,
 			"Q2c 首败恰掉 damage（新==旧-damage，未触钳制）")
	_check(shell.current_segment_id() == &"seg_river", "Q2d 失败不换段（仍在河段）")
	_check(not qte.window_open, "Q2e 失败后进歇拍（window_open 转 false）")
	var reopen: bool = await _wait_until(func(): return qte.window_open,
 			int((QTE_PAUSE + 0.5) * 60.0))
	_check(reopen, "Q2f 歇拍后 window_open 再 true（循环可续，pause+margin 帧内）")
	await _dismantle(shell)
	_done["q2"] = true


## Q3 钳伤不死：预置 health=10 → 两窗连败 → 恰钳到 1、未死、player_died 未发、段不变。
func _flow_q3() -> void:
	var shell := await _make_shell(FIX_CHAPTER3)
	var qte := _find_qte(shell)
	var died: Array[int] = []
	var died_cb := func(): died.append(1)   # 存引用：全局 autoload 信号用完必摘
	Events.player_died.connect(died_cb)
	shell.playable.attributes.health_current = 10
	var opened: bool = await _wait_until(func(): return qte.window_open, 60)
	_check(opened and qte.failures == 0, "Q3a 前置：残血 10 开局、零失败")
	# 两窗连败（各含一次歇拍→再开窗→再窗尾）
	var two: bool = await _wait_until(func(): return qte.failures == 2,
 			int((2.0 * (QTE_WINDOW + QTE_PAUSE) + 0.5) * 60.0))
	_check(two, "Q3b 两窗连败（failures==2）")
	await _frames(2)
	_check(shell.playable.attributes.health_current == 1,
 			"Q3c 钳制生效：残血 10 连败两窗恰钳到 1（maxi 下限，非 0/负）")
	_check(died.is_empty(), "Q3d 悲剧只延迟不否决：Events.player_died 未收")
	_check(shell.current_segment_id() == &"seg_river",
 			"Q3e 未触发死亡重跑：仍在河段")
	Events.player_died.disconnect(died_cb)
	await _dismantle(shell)
	_done["q3"] = true


## Q4 距外（歇拍相）按 E 零成本：不吃失败、不消耗窗口，下窗照排期开、窗内接=成功。
func _flow_q4() -> void:
	var shell := await _make_shell(FIX_CHAPTER3)
	var qte := _find_qte(shell)
	shell.playable.attributes.health_current = 100
	# 先自然输掉首窗进入歇拍（不按键）
	var failed: bool = await _wait_until(func(): return qte.failures == 1,
 			int((QTE_WINDOW + 0.5) * 60.0))
	var in_cooldown: bool = await _wait_until(func(): return not qte.window_open, 60)
	_check(failed and in_cooldown, "Q4a 前置：首窗已输、处歇拍（window_open=false）")
	var f0: int = qte.failures
	var hp0: int = shell.playable.attributes.health_current
	await _press_e()
	await _frames(3)
	_check(qte.failures == f0, "Q4b 歇拍按 E：失败数不增（既非答案亦非新失）")
	_check(shell.playable.attributes.health_current == hp0,
 			"Q4c 歇拍按 E：零掉血（不吃窗口=零成本）")
	_check(shell.current_segment_id() == &"seg_river",
 			"Q4d 歇拍按 E：段未变（未提前跳过）")
	var reopen: bool = await _wait_until(func(): return qte.window_open,
 			int((QTE_PAUSE + 0.5) * 60.0))
	_check(reopen, "Q4e 下窗照排期开（歇拍按 E 未打乱节奏）")
	await _press_e()
	var landed: bool = await _wait_until(
			func(): return shell.current_segment_id() == &"seg_it_end", 600)
	_check(landed, "Q4f 复开窗内 E → 成功落尾段")
	await _dismantle(shell)
	_done["q4"] = true
