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

	chen.attributes.health_current = 57.0
	await _frames(2)
	_check(is_equal_approx(hp.value, 57.0), "血条与属性同值（%.0f）" % hp.value)

	var def: SpellDefinition = (load(FIRE_DEF) as SpellDefinition).duplicate(true)
	def.cooldown = 5.0
	def.mana_cost = 0.0
	def.spell_scene = load(FIRE_SCENE)
	_check(chen.learn_spell(def), "学会冷却 5s 版火球")
	await _frames(2)
	var slot0_label: Label = (slots_row.get_child(0) as Panel).get_child(0)
	_check(slot0_label.text == "火球术", "已学名进槽位（%s）" % slot0_label.text)

	chen.channel.press("spell_1")
	await _frames(80)
	var cover: ColorRect = (slots_row.get_child(0) as Panel).get_child(1)
	_check(cover.anchor_bottom > 0.5, "冷却遮罩按剩余比例下压（%.2f）" % cover.anchor_bottom)

	chen.queue_free()
	await _frames(4)
	_check(not frame.visible, "players 组清空 → HUD 自隐")
	_finished = true
