extends Node

## WP1 输入通道改造的 headless 断言集。
## 运行：godot --headless --path . res://tools/input_channel_test/test_runner.tscn
##
## 主权迁移（S2-M1-B2.5 Task3）：
## - 本套只**读消费**矩阵专属替身 test_actor（TestActorKit.ACTOR_SCENE），不再
##   绑定活体内容角色 chen——用户手调打击感（如 attack1=0.1s/6 物理帧）会过期
##   本套的固定等待帧预算（本套转红的根因，结构上根治而非数值对表）。
## - 头部三态守卫阶梯（终审波 peek() 化）：peek()=ABSENT → 打处方
##   （run_matrix.sh --ensure-only）并 FAIL（可读红>静默跳>裸崩，消费套
##   结构性不碰创建）；NEEDS_IMPORT（已建未导入）→ 同处方 FAIL。
##   守卫通过喊出 ACTOR-GATE（M4 见证）。
## - 攻击腿一律**上升沿观察**（逐物理帧盯状态机，曾进入即真）：6 帧拳也可能被
##   固定等待后的瞬时抽查漏采，观察式不依赖任何角色的招式时长。

const Kit := preload("res://tools/matrix_runner/test_actor_kit.gd")
const ACTOR_SCENE := Kit.ACTOR_SCENE
const TEST_POLICY := "res://tools/input_channel_test/test_policy.gd"

## 上升沿观察帧帽：推导 = 小抄按压时刻（PRESS_AT_TICK）+ 事件投递/状态链延迟
## + 连段窗余量。与招式时长无关（拳再短也被逐帧盯住）。
const ATTACK_OBSERVE_CAP := TestChannelPolicy.PRESS_AT_TICK + 60

var _pass := 0
var _fail := 0
var _fail_names: Array[String] = []


func _ready() -> void:
	await _run_all()
	print("════════ RESULT: %d PASS / %d FAIL ════════" % [_pass, _fail])
	if _fail > 0:
		print("失败项: ", _fail_names)
	get_tree().quit(0 if _fail == 0 else 1)


func _check(ok: bool, name: String) -> void:
	if ok:
		_pass += 1
		print("  PASS: ", name)
	else:
		_fail += 1
		_fail_names.append(name)
		print("  FAIL: ", name)


func _in_attack_flow(state_name: NodePath) -> bool:
	var s := String(state_name)
	return s.contains("Attack") or s.contains("Combo")


func _tick(frames: int = 2) -> void:
	for i in frames:
		await get_tree().physics_frame


## 上升沿观察（interact_contract 同名孪生，套间不共享、保持独立）：逐物理帧
## 轮询 pred，命中即真返回；帽耗尽仍无=假。先判后等=第 0 帧也算一次采样。
func _wait_until(pred: Callable, cap_frames: int) -> bool:
	for _i in cap_frames:
		if pred.call():
			return true
		await get_tree().physics_frame
	return pred.call()


## 把动作按键事件推入真实分发管线（_unhandled_input 链路）。
## 注意：Input.action_press 只改轮询状态、不产生事件，测事件路径必须走这里。
func _push_action(action: String, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = StringName(action)
	e.pressed = pressed
	get_window().push_input(e)


## 头部三态守卫（只读阶梯，见文件头注释）；通过返回 true。
func _guard_actor() -> bool:
	var remedy := "先跑 bash tools/matrix_runner/run_matrix.sh --ensure-only 建好 test_actor"
	# 终审波：判态结构性断奶 ensure()——peek() 零副作用三态分类，
	# ABSENT/NEEDS_IMPORT 两支都只打处方红，创建泄漏在类型上不可能
	var st: int = Kit.peek()  # 只读分类（peek 承诺零副作用、永不建档）
	match st:
		Kit.READY:
			print("ACTOR-GATE: test_actor 就绪（只读三态守卫通过）")
			return true
		Kit.NEEDS_IMPORT:
			_check(false, "替身守卫：test_actor 已建未导入（%s）" % remedy)
		Kit.ABSENT:
			_check(false, "替身守卫：test_actor 缺席（%s）" % remedy)
		_:
			_check(false, "替身守卫：peek() 返回未知态 %d（kit 契约破损，查 test_actor_kit）" % st)
	return false


func _run_all() -> void:
	print("════ 组1：通道单元语义 ════")
	_test_channel_unit()

	print("════ 组2：玩家角色场景链路 ════")
	if not _guard_actor():
		return
	await _test_player_chain()

	print("════ 组3：泄漏灭绝 + AI 注入 ════")
	await _test_no_leak_and_ai()


# ── 组1 ──────────────────────────────────────────────────────────────

func _test_channel_unit() -> void:
	var ch := QuiverInputChannel.new()

	ch.press("attack")
	_check(ch.just_pressed("attack"), "边沿：按下后读到一次 true")
	_check(not ch.just_pressed("attack"), "边沿：读一次即消费")
	_check(ch.is_held("attack"), "按住：按下进名单")
	ch.release("attack")
	_check(not ch.is_held("attack"), "按住：松开出名单")
	
	ch.press("jump")
	ch._edge_tick["jump"] = Engine.get_physics_frames() - 5  # 伪造超龄边沿
	ch.prune_stale_edges()
	_check(not ch.just_pressed("jump"), "超龄边沿被清理丢弃")
	
	var ch2 := QuiverInputChannel.new()
	ch2.set_axis(Vector2(1, 0))
	ch2.set_held("walk", true)
	ch2.press("spell_1")
	ch2.reset()
	_check(ch2.axis == Vector2.ZERO and not ch2.is_held("walk") \
			and not ch2.just_pressed("spell_1"), "reset 清空三样状态")


# ── 组2 ──────────────────────────────────────────────────────────────

func _test_player_chain() -> void:
	var actor: QuiverCharacter = load(ACTOR_SCENE).instantiate()
	add_child(actor)
	await _tick(4)
	
	_check(actor.channel != null, "玩家角色：通道已创建")
	_check(actor.behavior != null \
			and actor.behavior is QuiverBehaviorPlayer, "默认挂玩家行为脚本")
	
	# 走路链路：OS 按键 → 行为脚本泵 → 通道 → 移动
	var start_x: float = actor.global_position.x
	Input.action_press("move_right")
	await _tick(20)
	var moved_x: float = actor.global_position.x - start_x
	Input.action_release("move_right")
	await _tick(2)
	_check(moved_x > 1.0, "移动链路：按 move_right 产生位移（%f px）" % moved_x)
	
	# 攻击链路：OS 攻击键 → 玩家行为 → deliver_event → Idle/Move 链 → 攻击流程
	# （Attack1 起手后转入 Combo 窗态，两者都算"已进入攻击"）。
	# 上升沿观察：曾进入即真，与拳速无关。
	_push_action("attack", true)
	_push_action("attack", false)
	var seen: bool = await _wait_until(
			func(): return _in_attack_flow(actor.state_machine.state_name),
			ATTACK_OBSERVE_CAP)
	_check(seen, "攻击链路：attack 键按下后曾进入攻击流程（观察帽 %d 帧）" \
			% ATTACK_OBSERVE_CAP)
	
	actor.free()
	await _tick(1)


# ── 组3 ──────────────────────────────────────────────────────────────

func _test_no_leak_and_ai() -> void:
	# 被动角色在场时按下攻击键：玩家听见、被动角色毫 unaffected
	var player: QuiverCharacter = load(ACTOR_SCENE).instantiate()
	add_child(player)
	await _tick(4)
	var passive: QuiverCharacter = load(ACTOR_SCENE).instantiate()
	passive.behavior_mode = QuiverCharacter.BehaviorMode.PASSIVE
	passive.position = Vector2(200, 0)
	add_child(passive)
	await _tick(4)
	
	_check(passive.behavior is QuiverBehaviorIdle, "被动档挂零写入行为")
	
	# 泄漏腿双观察：同窗逐帧盯两角色——玩家"曾出拳"（上升沿），
	# 被动"全程未被劫持"（反上升沿：任何一帧进了攻击流即泄漏）。
	_push_action("attack", true)
	_push_action("attack", false)
	var player_punched := false
	var passive_leaked := false
	for _i in ATTACK_OBSERVE_CAP:
		if _in_attack_flow(player.state_machine.state_name):
			player_punched = true
		if _in_attack_flow(passive.state_machine.state_name):
			passive_leaked = true
		if player_punched and passive_leaked:
			break
		await get_tree().physics_frame
	_check(player_punched, "泄漏测试：玩家角色正常出拳（曾进入攻击流程）")
	_check(not passive_leaked, "泄漏灭绝：被动角色不被物理键盘劫持（观察窗内从未进攻击流，当前 %s）" \
			% str(passive.state_machine.state_name))
	_check(not passive.channel.is_held("attack"), "被动角色通道干净")
	
	# 窗口门控：deliver_event 尊重 input_window_open=false——观察式同构：
	# 注入后整窗盯被动，任何一帧进攻击流即门失效（30 帧足够盖住最短拳）。
	passive.state_machine.input_window_open = false
	passive.state_machine.deliver_event(
			passive.behavior.make_action_event("attack", true))
	passive.state_machine.deliver_event(
			passive.behavior.make_action_event("attack", false))
	var gate_breached: bool = await _wait_until(
			func(): return _in_attack_flow(passive.state_machine.state_name), 30)
	_check(not gate_breached, \
			"窗口门控：关闭输入窗口时注入事件被拒（观察窗内未进攻击流）")
	passive.state_machine.input_window_open = true
	
	passive.free()
	await _tick(1)
	
	# AI 小抄链路：策略脚本 press_attack → 同一状态机管道 → Attack
	var ai_char: QuiverCharacter = load(ACTOR_SCENE).instantiate()
	ai_char.behavior_mode = QuiverCharacter.BehaviorMode.AI_POLICY
	ai_char.ai_policy_script = load(TEST_POLICY)
	ai_char.position = Vector2(-200, 0)
	add_child(ai_char)
	await _tick(4)
	_check(ai_char.behavior != null \
			and ai_char.behavior is TestChannelPolicy, "AI 档挂策略小抄实例")
	# 上升沿观察：小抄第 PRESS_AT_TICK 次 tick 按拳（旧版"固定 20 tick 后查瞬时
	# 态"被 6 帧短拳过期——本腿即当时转红的那条），观察式与招式时长解耦。
	var ai_seen: bool = await _wait_until(
			func(): return _in_attack_flow(ai_char.state_machine.state_name),
			ATTACK_OBSERVE_CAP)
	_check(ai_seen, "AI 注入链路：小抄按拳后曾进入攻击流程（观察帽 %d 帧）" \
			% ATTACK_OBSERVE_CAP)
	ai_char.free()
