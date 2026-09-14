extends Node

## WP1 输入通道改造的 headless 断言集。
## 运行：godot --headless --path . res://tools/input_channel_test/test_runner.tscn

const CHEN_SCENE := "res://characters/playable/chen/chen.tscn"
const TEST_POLICY := "res://tools/input_channel_test/test_policy.gd"

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


## 把动作按键事件推入真实分发管线（_unhandled_input 链路）。
## 注意：Input.action_press 只改轮询状态、不产生事件，测事件路径必须走这里。
func _push_action(action: String, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = StringName(action)
	e.pressed = pressed
	get_window().push_input(e)


func _run_all() -> void:
	print("════ 组1：通道单元语义 ════")
	_test_channel_unit()
	
	print("════ 组2：玩家角色场景链路 ════")
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
	var chen: QuiverCharacter = load(CHEN_SCENE).instantiate()
	add_child(chen)
	await _tick(4)
	
	_check(chen.channel != null, "玩家角色：通道已创建")
	_check(chen.behavior != null \
			and chen.behavior is QuiverBehaviorPlayer, "默认挂玩家行为脚本")
	
	# 走路链路：OS 按键 → 行为脚本泵 → 通道 → 移动
	var start_x: float = chen.global_position.x
	Input.action_press("move_right")
	await _tick(20)
	var moved_x: float = chen.global_position.x - start_x
	Input.action_release("move_right")
	await _tick(2)
	_check(moved_x > 1.0, "移动链路：按 move_right 产生位移（%f px）" % moved_x)
	
	# 攻击链路：OS 攻击键 → 玩家行为 → deliver_event → Idle/Move 链 → 攻击流程
	# （Attack1 起手后转入 Combo 窗态，两者都算"已进入攻击"）
	_push_action("attack", true)
	_push_action("attack", false)
	await _tick(4)
	_check(_in_attack_flow(chen.state_machine.state_name), \
			"攻击链路：attack 键进入攻击流程（当前 %s）" \
			% str(chen.state_machine.state_name))
	
	chen.free()
	await _tick(1)


# ── 组3 ──────────────────────────────────────────────────────────────

func _test_no_leak_and_ai() -> void:
	# 被动角色在场时按下攻击键：玩家听见、被动角色毫 unaffected
	var player: QuiverCharacter = load(CHEN_SCENE).instantiate()
	add_child(player)
	await _tick(4)
	var passive: QuiverCharacter = load(CHEN_SCENE).instantiate()
	passive.behavior_mode = QuiverCharacter.BehaviorMode.PASSIVE
	passive.position = Vector2(200, 0)
	add_child(passive)
	await _tick(4)
	
	_check(passive.behavior is QuiverBehaviorIdle, "被动档挂零写入行为")
	
	_push_action("attack", true)
	_push_action("attack", false)
	await _tick(6)
	_check(_in_attack_flow(player.state_machine.state_name), \
			"泄漏测试：玩家角色正常出拳")
	_check(String(passive.state_machine.state_name).contains("Idle"), \
			"泄漏灭绝：被动角色不被物理键盘劫持（当前 %s）" \
			% str(passive.state_machine.state_name))
	_check(not passive.channel.is_held("attack"), "被动角色通道干净")
	
	# 窗口门控：deliver_event 尊重 input_window_open=false
	passive.state_machine.input_window_open = false
	passive.state_machine.deliver_event(
			passive.behavior.make_action_event("attack", true))
	passive.state_machine.deliver_event(
			passive.behavior.make_action_event("attack", false))
	await _tick(3)
	_check(String(passive.state_machine.state_name).contains("Idle"), \
			"窗口门控：关闭输入窗口时注入事件被拒")
	passive.state_machine.input_window_open = true
	
	passive.free()
	await _tick(1)
	
	# AI 小抄链路：策略脚本 press_attack → 同一状态机管道 → Attack
	var ai_char: QuiverCharacter = load(CHEN_SCENE).instantiate()
	ai_char.behavior_mode = QuiverCharacter.BehaviorMode.AI_POLICY
	ai_char.ai_policy_script = load(TEST_POLICY)
	ai_char.position = Vector2(-200, 0)
	add_child(ai_char)
	await _tick(4)
	_check(ai_char.behavior != null \
			and ai_char.behavior is TestChannelPolicy, "AI 档挂策略小抄实例")
	await _tick(20)  # 小抄在第 10 次 tick 按攻击
	_check(_in_attack_flow(ai_char.state_machine.state_name), \
			"AI 注入链路：小抄按拳进入攻击流程（当前 %s）" \
			% str(ai_char.state_machine.state_name))
	ai_char.free()
