extends Node

## 弹体命中集成测试（真实物理、真实帧）：
##   chen 与 spar 同地面并排，chen 朝右瞬发火球，弹体飞行窗口内
##   spar 血量必须下降。12 套契约全部测"施法流程"，无一条测"飞行物真的打中人"，
##   导致 2026-09-16 F5 才暴露"弹体从头顶飞过去 + 判定盒是针"的复合回归。
## 运行：godot --headless --path . res://tools/spell_hit_test/projectile_hit.tscn

const CHEN := "res://characters/playable/chen/chen.tscn"
const TARGET := "res://characters/neutrals/street_vendor/street_vendor.tscn"  # 被动站桩，去走位抖动
const FIRE_DEF := "res://spells/fire_ball/resources/fire_ball_definition.tres"
const FIRE_SCENE := "res://spells/fire_ball/fire_ball.tscn"

var _fails := 0
var _stage: Node2D
var _chen: QuiverCharacter
var _spar: Node


func _ready() -> void:
	await _main_flow()
	print("════════ projectile-hit: %s ════════" % ("PASS" if _fails == 0 else "FAIL"))
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails += 1
	print("  %s: %s" % ["PASS" if ok else "FAIL", label])


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _main_flow() -> void:
	_stage = Node2D.new()
	_stage.name = "Stage"
	add_child(_stage)

	_chen = (load(CHEN) as PackedScene).instantiate()
	_stage.add_child(_chen)
	_spar = (load(TARGET) as PackedScene).instantiate()
	_spar.position = Vector2(150, 0)
	_stage.add_child(_spar)
	await _frames(5)

	var def: SpellDefinition = (load(FIRE_DEF) as SpellDefinition).duplicate(true)
	def.caster_cast_time = 0.0
	def.mana_cost = 0.0
	def.spell_scene = load(FIRE_SCENE)
	_check(_chen.learn_spell(def), "slot0 学会瞬发火球")

	var hp0: float = _spar.attributes.hp_current
	_chen.channel.press("spell_1")
	await _frames(2)

	var spell: SpellBase = null
	for c in _stage.get_children():
		if c is SpellBase:
			spell = c
	_check(spell != null, "弹体已上场")
	if spell == null:
		return
	print("    [诊断] 弹体出生 y=%.1f（角色身高 %.0f，脚底=0，头顶=-%.0f）" % [
			spell.global_position.y, _chen._skin.physical_height, _chen._skin.physical_height])

	var hit := false
	for _i in 240:
		await get_tree().physics_frame
		if _spar.attributes.hp_current < hp0:
			hit = true
			break
	_check(hit, "站桩目标血量在飞行窗口内下降（弹体真实命中）")
	if not hit:
		var hb: Area2D = _spar.find_child("HurtBox", true, false) as Area2D
		var rect: String = "N/A"
		if hb != null and hb.get_visible_rect().size.x > 0.0:
			rect = str(hb.get_global_rect())
		print("    [诊断] 弹体最后位置 y=%.1f；spar HurtBox 全局矩形=%s；阵营组=%s" % [
				spell.global_position.y, rect, spell.get_groups()])
