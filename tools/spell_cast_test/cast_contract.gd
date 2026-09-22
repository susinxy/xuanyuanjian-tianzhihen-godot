extends Node

## 阶段 1 施法契约测试（引擎级、真实帧）：
##  A 起手即转 Cast 状态、法术体未出现（前摇锁定时）
##  B 时长未满不放体、满后放体并归 Idle
##  C 法力起手即扣（承诺制）
##  D 咏唱中二次按键被拒（只出一发）
##  E 受击打断：法术作废、法力不退还
##  F 输入窗口：咏唱中关、结束后开
##  G 替身出生场景与模板场景均已挂 Cast 状态（角色改动必须进模板；
##    B2.5 主权迁移后 G 腿读产线产物 test_actor.tscn，不再盯活体 chen）
##  H caster_cast_time=0 = 无引导段，起手照播、播完立即出手（2026-09-16 语义定档）
## 运行：godot --headless --path . res://tools/spell_cast_test/cast_contract.tscn

const Kit := preload("res://tools/matrix_runner/test_actor_kit.gd")
const FIRE_DEF := "res://spells/fire_ball/resources/fire_ball_definition.tres"
const FIRE_SCENE := "res://spells/fire_ball/fire_ball.tscn"
const TEMPLATE_TSCN := "res://templates/character/__NAME__.tscn"

var _fails := 0
var _finished := false
var _stage: Node2D
var _actor: QuiverCharacter


func _ready() -> void:
	# 消费铁律：只读三态守卫（缺席打可读红+处方，绝不代 runner 创建）；
	# 守卫不过则整轮跳过，_finished 防线照样把总判定压成 FAIL（可读红>静默跳）
	if _guard_actor():
		_file_checks()
		await _main_flow()
	_check(_finished, "契约全序列执行完成（防协程静默中断假绿）")
	print("════════ cast-contract: %s ════════" % ("PASS" if _fails == 0 else "FAIL"))
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails += 1
	print("  %s: %s" % ["PASS" if ok else "FAIL", label])


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


## 头部三态守卫（input_channel 同款只读阶梯）；通过喊出 ACTOR-GATE（M4 见证）
func _guard_actor() -> bool:
	var remedy := "先跑 bash tools/matrix_runner/run_matrix.sh --ensure-only 建好 test_actor"
	if not Kit.exists():
		_check(false, "替身守卫：test_actor 缺席（%s）" % remedy)
		return false
	var rc := Kit.ensure()
	if rc == Kit.NEEDS_IMPORT:
		_check(false, "替身守卫：test_actor 在但本进程不可加载=NEEDS_IMPORT(42)（%s）" % remedy)
		return false
	if rc != OK:
		_check(false, "替身守卫：ensure() 报产线失败（rc=%d，诊断见上行）" % rc)
		return false
	print("ACTOR-GATE: test_actor 就绪（只读三态守卫通过）")
	return true


func _file_checks() -> void:
	var actor_src := FileAccess.get_file_as_string(Kit.ACTOR_SCENE)
	var tpl_src := FileAccess.get_file_as_string(TEMPLATE_TSCN)
	_check(actor_src.contains('name="Cast"') and actor_src.contains('_start_state = &"spell_start"')
			and actor_src.contains('_loop_state = &"spelling"'),
			"test_actor.tscn（产线产物）已挂两段式 Cast 施法状态")
	_check(tpl_src.contains('name="Cast"') and tpl_src.contains('_start_state = &"spell_start"')
			and tpl_src.contains('_loop_state = &"spelling"'),
			"模板 __NAME__.tscn 已挂两段式 Cast（新角色出生即有）")


func _bodies() -> int:
	var n := 0
	for c in _stage.get_children():
		if c is SpellBase and (c as SpellBase).state == SpellBase.SpellState.ACTIVE:
			n += 1
	return n


func _state() -> String:
	return str(_actor.state_machine.state_name)


func _spell_has_caster_faction() -> bool:
	for b in _stage.get_children():
		if b is SpellBase:
			for node in b.find_children("*", "", true):
				if node.is_in_group("area2d:player"):
					return true
	return false


func _make_def(cast_time: float, mana_cost: float) -> SpellDefinition:
	var def := (load(FIRE_DEF) as SpellDefinition).duplicate(true)
	def.caster_cast_time = cast_time
	def.mana_cost = mana_cost
	def.cooldown = 0.0
	def.spell_scene = load(FIRE_SCENE)
	return def


func _main_flow() -> void:
	_stage = Node2D.new()
	_stage.name = "Stage"
	add_child(_stage)
	_actor = (load(Kit.ACTOR_SCENE) as PackedScene).instantiate()
	_stage.add_child(_actor)
	await _frames(3)
	
	var def_a := _make_def(0.5, 10.0)
	_check(_actor.learn_spell(def_a), "slot0 学会 0.5s 施法版火球")
	var def_h := _make_def(0.0, 0.0)
	_check(_actor.learn_spell(def_h), "slot1 学会零引导版火球")
	
	# ── A/B/C/F：起手 → 锁定 → 到点释放 ──
	var mana0 := _actor.attributes.mana_current
	_actor.channel.press("spell_1")
	await _frames(1)
	_check(_state() == "Ground/Cast", "A 起手转入 Ground/Cast")
	_check(is_equal_approx(_actor.attributes.mana_current, mana0 - 10.0), "C 法力起手即扣")
	_check(not _actor.state_machine.input_window_open, "F 咏唱中输入窗口关闭")
	_check(_bodies() == 0, "A 前摇期间法术体未出现")
	await _frames(3)
	_check(_actor._skin._playback.get_current_node() == &"spell_start",
			"B1 起手期（0.05s）活动态=spell_start")
	await _frames(22)
	_check(_state() == "Ground/Cast" and _bodies() == 0,
			"B 引导未满（0.42s）：仍在咏唱、未出手")
	_check(_actor._skin._playback.get_current_node() == &"spelling",
			"B2 起手播完（0.333s）已切入 spelling（活动态=%s）" % _actor._skin._playback.get_current_node())
	await _frames(40)
	_check(_bodies() == 1, "B 总时长已满（起手0.333+引导0.5）：法术体上场")
	_check(_state() == "Ground/Move/Idle", "B 施毕归 Idle（实际=%s）——法术体不得自伤施法者" % _state())
	_check(_spell_has_caster_faction(), "阵营跟随：法术体携带施法者 area2d 组（贴身不误伤）")
	_check(_actor.state_machine.input_window_open, "F 施毕输入窗口重开")
	
	# ── D：咏唱中二次按键被拒 ──
	_actor.channel.press("spell_1")
	await _frames(2)
	_actor.channel.press("spell_1")
	await _frames(70)
	_check(_bodies() == 2, "D 咏唱中二次按键被拒（本回合一发）")
	
	# ── E：受击打断 ──
	_actor.channel.press("spell_1")
	await _frames(2)
	var mana_pre := _actor.attributes.mana_current
	_actor.state_machine.transition_to("Ground/Hurt", {hurt_type = CombatSystem.HurtTypes.HIGH})
	await _frames(40)
	_check(_bodies() == 2, "E 打断后法术作废（无新实体）")
	_check(is_equal_approx(_actor.attributes.mana_current, mana_pre), "E 打断不退还法力")
	_check(_state() != "Ground/Cast", "E 已离开咏唱态")
	
	# ── H：cast_time=0 = 无引导段（起手是角色身份，恒完整播）──
	_actor.channel.press("spell_2")
	await _frames(2)
	_check(_state() == "Ground/Cast" and _bodies() == 2,
			"H 零引导仍转入 Cast 播起手，未提前放体")
	_check(_actor._skin._playback.get_current_node() == &"spell_start",
			"H 零引导期活动态=spell_start")
	await _frames(30)
	_check(_bodies() == 3, "H 起手播完（0.333s）当帧出手")
	_check(_state() == "Ground/Move/Idle", "H 施毕归 Idle（实际=%s）" % _state())
	
	# ── 四向：朝上出手，法术体方向=上（旧 Skin 路径 bug 修复锁） ──
	_actor._skin.skin_direction = Vector2.UP
	_actor.channel.press("spell_2")
	await _frames(30)
	var last: SpellBase = null
	for b in _stage.get_children():
		if b is SpellBase:
			last = b
	_check(last != null and last.direction == Vector2.UP,
			"四向出手：朝上施法法术体向上飞（实际=%s）" % (last.direction if last else null))
	_check(last != null and (last.get("_skin") as SpellSkin).skin_direction == Vector2(0, -1),
			"四向出手：法术体皮肤朝向同步量化为上（blend 坐标 0,-1）")
	
	# ── 槽位配对断言 ──
	_check(_actor._skin.has_anim_state(&"spell_start") and _actor._skin.has_anim_state(&"spelling"),
			"替身皮肤已含 spell_start+spelling 两槽")
	var spar := (load("res://characters/enemies/spar_enemy/spar_enemy.tscn") as PackedScene).instantiate()
	_stage.add_child(spar)
	await _frames(2)
	_check(not spar._skin.has_anim_state(&"spell_start"),
			"spar 皮肤无起手槽（has_anim_state 降级门语义对照组）")
	spar.queue_free()
	
	# ── I：跑动起手（run→spell 直连边）──
	var sprite = _actor._skin.find_child("AnimatedSprite2D", true, false)
	Input.action_press("move_right")
	var running := false
	for _i in 20:
		await get_tree().physics_frame
		if "run" in String(sprite.animation):
			running = true
			break
	_check(running, "I 前置：跑动动画已就位（实际=%s）" % sprite.animation)
	_actor.channel.press("spell_1")
	await _frames(2)
	Input.action_release("move_right")
	_check(_state() == "Ground/Cast", "I 跑动中起手成功转 Cast")
	var anim_now := String(sprite.animation)
	_check("run" not in anim_now, "I 咏唱中不残留跑动动画（实际=%s）" % anim_now)
	_check(String(_actor._skin._playback.get_current_node()) in ["spell_start", "spelling"],
			"I 跑动起手切入施法槽（活动态=%s）" % _actor._skin._playback.get_current_node())
	await _frames(70)
	_check(_bodies() >= 4, "I 跑动起手同样到点出手")
	_mark_done()


func _mark_done() -> void:
	_finished = true
