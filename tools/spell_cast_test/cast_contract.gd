extends Node

## 阶段 1 施法契约测试（引擎级、真实帧）：
##  A 起手即转 Cast 状态、法术体未出现（前摇锁定时）
##  B 时长未满不放体、满后放体并归 Idle
##  C 法力起手即扣（承诺制）
##  D 咏唱中二次按键被拒（只出一发）
##  E 受击打断：法术作废、法力不退还
##  F 输入窗口：咏唱中关、结束后开
##  G chen 与模板场景均已挂 Cast 状态（角色改动必须进模板）
##  H caster_cast_time=0 维持旧瞬发行为（向后兼容）
## 运行：godot --headless --path . res://tools/spell_cast_test/cast_contract.tscn

const CHEN := "res://characters/playable/chen/chen.tscn"
const FIRE_DEF := "res://spells/fire_ball/resources/fire_ball_definition.tres"
const FIRE_SCENE := "res://spells/fire_ball/fire_ball.tscn"
const TEMPLATE_TSCN := "res://characters/playable/_template/__NAME__.tscn"

var _fails := 0
var _finished := false
var _stage: Node2D
var _chen: QuiverCharacter


func _ready() -> void:
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


func _file_checks() -> void:
	var chen_src := FileAccess.get_file_as_string(CHEN)
	var tpl_src := FileAccess.get_file_as_string(TEMPLATE_TSCN)
	_check(chen_src.contains('name="Cast"') and chen_src.contains('_skin_state = &"spell"'),
			"chen.tscn 已挂 Cast 施法状态")
	_check(tpl_src.contains('name="Cast"') and tpl_src.contains('_skin_state = &"spell"'),
			"模板 __NAME__.tscn 已挂 Cast（新角色出生即有）")


func _bodies() -> int:
	var n := 0
	for c in _stage.get_children():
		if c is SpellBase:
			n += 1
	return n


func _state() -> String:
	return str(_chen.state_machine.state_name)


func _spell_has_caster_faction() -> bool:
	for b in _stage.get_children():
		if b is SpellBase:
			for node in b.find_children("*", "", true):
				if node.is_in_group("area2d:chen"):
					return true
	return false


func _make_def(cast_time: float, mana_cost: float) -> SpellDefinition:
	var def := (load(FIRE_DEF) as SpellDefinition).duplicate(true)
	def.caster_cast_time = cast_time
	def.mana_cost = mana_cost
	def.spell_scene = load(FIRE_SCENE)
	return def


func _main_flow() -> void:
	_stage = Node2D.new()
	_stage.name = "Stage"
	add_child(_stage)
	_chen = (load(CHEN) as PackedScene).instantiate()
	_stage.add_child(_chen)
	await _frames(3)
	
	var def_a := _make_def(0.5, 10.0)
	_check(_chen.learn_spell(def_a), "slot0 学会 0.5s 施法版火球")
	var def_h := _make_def(0.0, 0.0)
	_check(_chen.learn_spell(def_h), "slot1 学会瞬发版火球（兼容旧行为）")
	
	# ── A/B/C/F：起手 → 锁定 → 到点释放 ──
	var mana0 := _chen.attributes.mana_current
	_chen.channel.press("spell_1")
	await _frames(1)
	_check(_state() == "Ground/Cast", "A 起手转入 Ground/Cast")
	_check(is_equal_approx(_chen.attributes.mana_current, mana0 - 10.0), "C 法力起手即扣")
	_check(not _chen.state_machine.input_window_open, "F 咏唱中输入窗口关闭")
	_check(_bodies() == 0, "A 前摇期间法术体未出现")
	await _frames(10)
	_check(_state() == "Ground/Cast" and _bodies() == 0, "B 时长未满：仍在咏唱、未出手")
	await _frames(35)
	_check(_bodies() == 1, "B 时长已满：法术体上场")
	_check(_state() == "Ground/Move/Idle", "B 施毕归 Idle（实际=%s）——法术体不得自伤施法者" % _state())
	_check(_spell_has_caster_faction(), "阵营跟随：法术体携带施法者 area2d 组（贴身不误伤）")
	_check(_chen.state_machine.input_window_open, "F 施毕输入窗口重开")
	
	# ── D：咏唱中二次按键被拒 ──
	_chen.channel.press("spell_1")
	await _frames(2)
	_chen.channel.press("spell_1")
	await _frames(48)
	_check(_bodies() == 2, "D 咏唱中二次按键被拒（本回合一发）")
	
	# ── E：受击打断 ──
	_chen.channel.press("spell_1")
	await _frames(2)
	var mana_pre := _chen.attributes.mana_current
	_chen.state_machine.transition_to("Ground/Hurt", {hurt_type = CombatSystem.HurtTypes.HIGH})
	await _frames(40)
	_check(_bodies() == 2, "E 打断后法术作废（无新实体）")
	_check(is_equal_approx(_chen.attributes.mana_current, mana_pre), "E 打断不退还法力")
	_check(_state() != "Ground/Cast", "E 已离开咏唱态")
	
	# ── H：cast_time=0 瞬发旧行为 ──
	_chen.channel.press("spell_2")
	await _frames(2)
	_check(_bodies() == 3, "H 施法时长 0 定义 = 瞬发（向后兼容）")
	_check(_state() == "Ground/Move/Idle", "H 瞬发不进入咏唱态（实际=%s）" % _state())
	
	# ── 四向：朝上出手，法术体方向=上（旧 Skin 路径 bug 修复锁） ──
	_chen._skin.skin_direction = Vector2.UP
	_chen.channel.press("spell_2")
	await _frames(2)
	var last: SpellBase = null
	for b in _stage.get_children():
		if b is SpellBase:
			last = b
	_check(last != null and last.direction == Vector2.UP,
			"四向出手：朝上施法法术体向上飞（实际=%s）" % (last.direction if last else null))
	_check(last != null and (last.get("_skin") as SpellSkin).skin_direction == Vector2(0, -1),
			"四向出手：法术体皮肤朝向同步量化为上（blend 坐标 0,-1）")
	
	# ── 槽位配对断言 ──
	_check(_chen._skin.has_anim_state(&"spell"), "chen 皮肤已含 spell 动画槽")
	var spar := (load("res://characters/enemies/spar_enemy/spar_enemy.tscn") as PackedScene).instantiate()
	_stage.add_child(spar)
	await _frames(2)
	_check(not spar._skin.has_anim_state(&"spell"),
			"spar 皮肤无 spell 槽（has_anim_state 降级门语义对照组）")
	spar.queue_free()
	
	# ── I：跑动起手（run→spell 直连边）──
	var sprite = _chen._skin.find_child("AnimatedSprite2D", true, false)
	Input.action_press("move_right")
	var running := false
	for _i in 20:
		await get_tree().physics_frame
		if "run" in String(sprite.animation):
			running = true
			break
	_check(running, "I 前置：跑动动画已就位（实际=%s）" % sprite.animation)
	_chen.channel.press("spell_1")
	await _frames(2)
	Input.action_release("move_right")
	_check(_state() == "Ground/Cast", "I 跑动中起手成功转 Cast")
	var anim_now := String(sprite.animation)
	_check("run" not in anim_now, "I 咏唱中不残留跑动动画（实际=%s）" % anim_now)
	_check(_chen._skin._playback.get_current_node() == &"spell",
			"I 咏唱中动画树活动状态=spell（槽位已接）")
	await _frames(40)
	_check(_bodies() >= 4, "I 跑动起手同样到点出手")
	_mark_done()


func _mark_done() -> void:
	_finished = true
