extends Node

## 阶段 0 端到端：法术注入脚本重构（消灭双消费者）
## a) 模板字符串：助手模板不得再自建管理器/轮询，必须是"教给宿主"形态
## b) 引擎级永久回归锁：旧形态（自建管理器+轮询）在双消费者争抢下**永远看不到按键**
## c) 引擎级正向证明：新形态（learn_spell 延后一帧教给宿主）→ 注入按键 → 法术体上场
## 运行：godot --headless --path . res://tools/spell_cast_test/helper_e2e.tscn

const SPELL_PLUGIN := "res://addons/quiver.beat_em_up/custom_inspectors/create_new_spell/inspector_plugin.gd"
const CHEN := "res://characters/playable/chen/chen.tscn"

const OldHelperSim := preload("res://tools/spell_cast_test/old_helper_sim.gd")
const NewHelperSim := preload("res://tools/spell_cast_test/new_helper_sim.gd")

var _fails := 0


func _ready() -> void:
	_string_checks()
	await _old_structure_race()
	await _new_structure_cast()
	await _os_key_full_chain()
	print("════════ spell-helper-e2e: %s ════════" % ("PASS" if _fails == 0 else "FAIL"))
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails += 1
	print("  %s: %s" % ["PASS" if ok else "FAIL", label])


func _string_checks() -> void:
	var src := FileAccess.get_file_as_string(SPELL_PLUGIN)
	var rx := RegEx.new()
	rx.compile("(?s)var helper_script_content = \"\"\"(.*?)\"\"\"")
	var m := rx.search(src)
	if m == null:
		_check(false, "助手模板提取失败")
		return
	var t: String = m.get_string(1)
	_check(not t.contains("SpellManager.new("), "助手模板不再自建法术管理器")
	_check(t.contains("host.learn_spell(") and not t.contains("_spell_manager"),
			"助手模板为教给宿主形态（host.learn_spell，无自有管理器）")
	_check(not t.contains("func _physics_process"), "助手模板不再轮询按键（单消费者）")


func _spawn_chen(helper: Node) -> Dictionary:
	var stage := Node2D.new()
	stage.name = "Stage"
	add_child(stage)
	var chen: Node = (load(CHEN) as PackedScene).instantiate()
	if helper != null:
		chen.add_child(helper)  # 入树前先挂好 → 真实场景装载序：子 _ready 早于父
	stage.add_child(chen)
	return {"stage": stage, "chen": chen, "helper": helper}


func _old_structure_race() -> void:
	var ctx := _spawn_chen(OldHelperSim.new())
	for _i in 3:
		await get_tree().physics_frame
	ctx.chen.channel.press("spell_1")
	for _i in 3:
		await get_tree().physics_frame
	# 角色壳先轮询先吃边沿（空手册无声施法）→ 旧助手必须看不到键
	_check(ctx.helper.seen == false, "引擎级回归锁：双消费者下旧助手永不通键（chen 先吃）")
	ctx.stage.queue_free()


func _new_structure_cast() -> void:
	var ctx := _spawn_chen(NewHelperSim.new())
	for _i in 3:
		await get_tree().physics_frame
	_check(ctx.helper.taught == true, "新形态：法术已教给角色本人")
	var before := _spell_bodies(ctx.stage)
	ctx.chen.channel.press("spell_1")
	# 零引导仍含起手段（0.333s≈21 帧），等待必须跨过（2026-09-16 语义定档）
	for _i in 30:
		await get_tree().physics_frame
	_check(_spell_bodies(ctx.stage) > before, "新形态：注入 spell_1 后法术体真实上场")
	ctx.stage.queue_free()


## OS 键盘全链路（2026-09-15 定罪回归锁）：引擎的未处理输入流只广播带动作
## 匹配结果的原始按键事件、不广播 InputEventAction——行为脚本盖戳若只认
## InputEventAction 类，真实键盘法术键将永远无效（本 runner 其余场景直注通道
## 恰好测不到这一层）。用 Input.parse_input_event 走 OS 同一入口打全链路。
func _os_key_full_chain() -> void:
	var ctx := _spawn_chen(NewHelperSim.new())
	await _frames(3)
	var ev := InputEventKey.new()
	ev.keycode = KEY_1
	ev.physical_keycode = KEY_1
	ev.pressed = true
	Input.parse_input_event(ev)
	var ev2 := InputEventKey.new()
	ev2.keycode = KEY_1
	ev2.physical_keycode = KEY_1
	ev2.pressed = false
	Input.parse_input_event(ev2)
	await _frames(30)
	_check(_spell_bodies(ctx.stage) >= 1, "OS 真按键 spell_1 全链路施法成功")
	_check(not _first_body(ctx.stage).is_in_group("players"),
			"法术体不混入阵营包组（防查询污染）")
	ctx.stage.queue_free()


func _first_body(stage: Node) -> SpellBase:
	for c in stage.get_children():
		if c is SpellBase:
			return c
	return null


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _spell_bodies(stage: Node) -> int:
	var n := 0
	for c in stage.get_children():
		if c is SpellBase:
			n += 1
	return n
