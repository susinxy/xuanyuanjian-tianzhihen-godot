extends Node

## 复现定罪 runner：装载磁盘上真实的法术测试场景（用户 Windows 端同款文件），
## 用真 OS 键盘事件注入走完整输入链路，五段探针定位断点：
##  装载段（helper/脚本/教成/slot）→ 采集段（OS 键→通道边沿）→
##  轮询段（chen 读到）→ 闸口段（四闸逐一放行状态）→ 出手段（法术体计数）
## 对照组：直接 channel.press（helper_e2e 证明过可用的旁路）。
## 运行：godot --headless --path . res://tools/spell_cast_test/repro_spell_scene.tscn

const SCENE := "res://test_scenes/_test_spell_fire_ball.tscn"

var _stage: Node
var _chen: Node
var _helper: Node
var _edge_observed := ""
var _edge_seen_frames := 0
var _listen_log: Array[String] = []


func _unhandled_input(event: InputEvent) -> void:
	_listen_log.append("%s(%s)" % [event.get_class(),
			event.action if event is InputEventAction else event.physical_keycode])


func _ready() -> void:
	var ps := load(SCENE)
	if ps == null:
		print("REPRO 场景加载失败")
		get_tree().quit(1)
		return
	_stage = ps.instantiate()
	add_child(_stage)
	for _i in 5:
		await get_tree().physics_frame
	
	_chen = _stage.get_node_or_null("Character")
	_helper = _chen.get_node_or_null("TestSpellHelper") if _chen else null
	
	# ── 装载段 ──
	print("REPRO 1装载 helper=", _helper, " 脚本=", _helper.get_script().resource_path if _helper else "无")
	print("REPRO 1装载 taught=", _helper._taught if _helper else "N/A")
	var mgr = _chen.get_spell_manager() if _chen else null
	var slot = mgr.get_spell_slot(0) if mgr else null
	print("REPRO 1装载 slot0=", "空" if slot == null or slot.is_empty() else slot.definition.spell_id)
	var ov = _stage.get_node_or_null("DebugOverlay")
	print("REPRO 1装载 面板_player=", ov._player if ov else "无面板")
	
	if _chen == null or mgr == null:
		print("REPRO 装载段崩，后续无意义")
		get_tree().quit(1)
		return
	
	# ── 闸口段（按键前静态体检）──
	var def = slot.definition if not slot.is_empty() else null
	print("REPRO 4闸口 状态=", str(_chen.state_machine.state_name),
			" 白名单过=", mgr._is_state_allowed(def) if def else "N/A",
			" 咏唱中=", mgr._is_casting(), " 空中=", mgr._is_in_air(),
			" 蓝=", _chen.attributes.mana_current)
	
	# 行为节点输入处理开关体检
	var bhv = _chen.get_node_or_null("Behavior")
	print("REPRO 3行为 node=", bhv, " 处理中=", bhv.is_processing_unhandled_input() if bhv else "N/A",
			" active=", bhv.active if bhv else "N/A", " 在组=", bhv.is_in_group("vp_unhandled_input") if bhv else "")
	
	# ── 采集段：真 OS 键盘事件（1 和 J 双对照）──
	_listen_log.clear()
	for key in [KEY_1, KEY_J]:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		ev.keycode = key  # 引擎只对带主键码的事件做动作映射（physical-only 不产 InputEventAction）
		ev.pressed = true
		Input.parse_input_event(ev)
		var ev2 := InputEventKey.new()
		ev2.physical_keycode = key
		ev2.keycode = key
		ev2.pressed = false
		Input.parse_input_event(ev2)
	for _i in 6:
		await get_tree().physics_frame
	print("REPRO 2采集 监听到的事件=", _listen_log)
	print("REPRO 2采集 通道边沿(近帧观测)=", _edge_observed if _edge_observed != "" else "从未见边沿")
	print("REPRO 2采集 动作态 spell_1按住=", Input.is_action_pressed("spell_1"), " attack按住=", Input.is_action_pressed("attack"))
	print("REPRO 2采集 通道边沿(近4帧观测)=", _edge_observed if _edge_observed != "" else "从未见边沿")
	print("REPRO 5出手 法球数=", _count_bodies(), " chen状态=", str(_chen.state_machine.state_name))
	
	# ── 对照组：旁路直接压通道 ──
	_chen.channel.press("spell_1")
	await get_tree().physics_frame
	print("REPRO 对照 直接press后一帧 法球数=", _count_bodies())
	for _i in 4:
		await get_tree().physics_frame
	print("REPRO 对照 稳定后 法球数=", _count_bodies())
	get_tree().quit(0)


func _physics_process(_d: float) -> void:
	# 每帧开头抢在 chen 消费前偷看通道边沿表
	if _chen == null or _chen.channel == null:
		return
	var t: Dictionary = _chen.channel._edge_tick
	if not t.is_empty():
		_edge_seen_frames += 1
		_edge_observed = "%s @帧%s" % [t.keys(), Engine.get_physics_frames()]


func _count_bodies() -> int:
	var n := 0
	var stack: Array = [_stage]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is SpellBase:
			n += 1
		for c in node.get_children():
			stack.append(c)
	return n
