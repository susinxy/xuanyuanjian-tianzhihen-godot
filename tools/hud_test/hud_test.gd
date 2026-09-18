extends Node

## GameHUD 契约测试（批 3）：players 组跟手/血蓝同步/名字头像/已学名/
## 冷却遮罩/目标消失自隐。
## 运行：godot --headless --path . res://tools/hud_test/hud_test.tscn

const CHEN := "res://characters/playable/chen/chen.tscn"
const HUD := "res://ui/game_hud.tscn"
const FIRE_DEF := "res://spells/fire_ball/resources/fire_ball_definition.tres"
const FIRE_SCENE := "res://spells/fire_ball/fire_ball.tscn"

var _fails := 0
var _finished := false


func _ready() -> void:
	await _flow()
	_check(_finished, "全序列执行完成（协程静默中断防线）")
	print("════════ game-hud: %s ════════" % ("PASS" if _fails == 0 else "FAIL"))
	get_tree().quit(0 if _fails == 0 else 1)


## 解析器三链单元段：①icon 提供即优先 ②派生链非空 ③无链可派生 null 不崩
func _resolver_cases() -> void:
	var Resolver := load("res://ui/spell_icon_resolver.gd")
	var bare: SpellDefinition = (load(FIRE_DEF) as SpellDefinition).duplicate(true)
	bare.icon = null
	bare.spell_scene = load(FIRE_SCENE)
	_check(Resolver.icon_for(bare) != null, "resolver：②派生链非空")
	var fake := SpellDefinition.new()
	fake.icon = load("res://spells/fire_ball/resources/sprites/chen_00001.png")
	_check(Resolver.icon_for(fake) == fake.icon, "resolver：①icon 提供即优先")
	var junk := SpellDefinition.new()
	junk.spell_scene = null
	_check(Resolver.icon_for(junk) == null, "resolver：③无链可派生 null 不崩")


func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails += 1
	print("  %s: %s" % ["PASS" if ok else "FAIL", label])


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _flow() -> void:
	var stage := Node2D.new()
	add_child(stage)
	var chen: QuiverCharacter = (load(CHEN) as PackedScene).instantiate()
	stage.add_child(chen)
	var hud := (load(HUD) as PackedScene).instantiate()
	stage.add_child(hud)
	# players 组由行为档延迟挂接（组注册晚于 _ready 若干物理帧）——等到跟手为止
	for _i in 90:
		await get_tree().physics_frame
		if hud._bound != null:
			break

	var frame := hud.get_node("Frame")
	var name_l: Label = hud.get_node("Frame/Row/Info/Name")
	var portrait: TextureRect = hud.get_node("Frame/Row/Portrait")
	var hp: ProgressBar = hud.get_node("Frame/Row/Info/Hp")
	var slots_row: HBoxContainer = hud.get_node("Frame/Row/Info/Slots")

	_check(frame.visible and name_l.text == "陈靖仇", "跟随 players 组：名字上屏（%s）" % name_l.text)
	_check(portrait.texture != null, "头像自 attributes.profile_texture 上屏")
	_check(name_l.get_theme_color("font_color").v > 0.5, "HUD 名字浅色 override 在位")

	chen.attributes.health_current = 57.0
	await _frames(2)
	_check(is_equal_approx(hp.value, 57.0), "血条与属性同值（%.0f）" % hp.value)

	var def: SpellDefinition = (load(FIRE_DEF) as SpellDefinition).duplicate(true)
	def.cooldown = 5.0
	def.mana_cost = 0.0
	def.spell_scene = load(FIRE_SCENE)
	_check(chen.learn_spell(def), "学会冷却 5s 版火球")
	await _frames(2)
	var slot0: Panel = slots_row.get_child(0)
	var slot0_icon: TextureRect = slot0.get_child(0)
	var slot0_label: Label = slot0.get_child(1)
	_check(slot0_icon.texture != null, "无 icon 定义→派生 right 动画首帧上屏")
	_check(slot0_label.text == "1", "槽内键位角标数字（%s）" % slot0_label.text)
	_check(slot0.tooltip_text == "火球术", "显示名进 tooltip（%s）" % slot0.tooltip_text)

	chen.channel.press("spell_1")
	await _frames(80)
	var cover: ColorRect = (slots_row.get_child(0) as Panel).get_child(2)
	# 断言落几何（尺寸）不落锚点属性：锚点被改而矩形不动曾是隐身事故本故
	_check(cover.size.y > 25 and cover.size.y <= 57,
			"冷却遮罩真实下压（遮罩高 %.0f/槽 56）" % cover.size.y)

	# —— 可变性加固断言：遗忘即时性（拉取制核心承诺）——
	var sm = chen.get("_spell_manager")
	sm.forget_spell(0)
	await _frames(2)
	var s0: Panel = slots_row.get_child(0)
	_check((s0.get_child(0) as TextureRect).texture == null
			and s0.tooltip_text == ""
			and (s0.get_child(1) as Label).text == "1",
			"遗忘一帧内：图标清/tooltip 空/回数字态")

	# —— 可变性加固断言：数量双向自校准（白盒改容量模拟未来扩容）——
	sm._slots.append(SpellSlot.new())
	await _frames(2)
	_check(slots_row.get_child_count() == sm.slot_count(),
			"扩容即时跟随：HUD %d 格 = manager %d 格" % [slots_row.get_child_count(), sm.slot_count()])
	sm._slots.pop_back()
	await _frames(2)
	_check(slots_row.get_child_count() == sm.slot_count(),
			"缩容即时跟随：HUD %d 格" % slots_row.get_child_count())

	chen.queue_free()
	await _frames(4)
	_check(not frame.visible, "players 组清空 → HUD 自隐")
	_resolver_cases()
	_finished = true
