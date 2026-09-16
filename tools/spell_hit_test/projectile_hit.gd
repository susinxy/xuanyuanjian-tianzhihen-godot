extends Node

## 弹体命中集成测试（真 Run Test 场景复现，2026-09-16 定罪版）：
##   直接载入统一底版生成的 _test_spell_fire_ball.tscn（自带 chen+默认对手 spar_enemy+
##   helper 教真定义 0.8s 吟唱），私有通道按 spell_1，与 Windows F5 一字不差；
##   断言 Enemy 血量在弹体寿命窗口内下降。
## 教训固化：协程中途报错=静默假绿（AGENTS 明文），本 runner 设完成旗汇总前必查；
##   断言失败自动打印双方阵营字典/矩形/开关四元现场证据。
## 运行：godot --headless --path . res://tools/spell_hit_test/projectile_hit.tscn

const RUN_TEST := "res://test_scenes/_test_spell_fire_ball.tscn"

var _fails := 0
var _finished := false


func _ready() -> void:
	await _main_flow()
	_check(_finished, "全序列执行完成（协程静默中断防线）")
	print("════════ projectile-hit: %s ════════" % ("PASS" if _fails == 0 else "FAIL"))
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails += 1
	print("  %s: %s" % ["PASS" if ok else "FAIL", label])


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _find_spell(root: Node) -> SpellBase:
	for c in root.get_children():
		if c is SpellBase:
			return c
		var found := _find_spell(c)
		if found != null:
			return found
	return null


func _main_flow() -> void:
	var stage := (load(RUN_TEST) as PackedScene).instantiate()
	add_child(stage)
	await _frames(5)  # helper call_deferred 教法术 + 角色落地

	var chen := stage.get_node_or_null("Character") as QuiverCharacter
	var enemy := stage.get_node_or_null("Enemy")
	_check(chen != null and enemy != null, "场景含被测角色与默认对手")
	if chen == null or enemy == null:
		_finished = true
		return
	_check(chen._spell_manager != null, "角色法术管理器就位")

	var hp0: float = enemy.attributes.health_current
	chen.channel.press("spell_1")
	await _frames(70)  # 真定义：起手 0.333s + 引导 0.8s ≈ 1.15s，给 100 帧冗余内的余量

	var spell := _find_spell(stage)
	_check(spell != null, "弹体已上场（吟唱走完释放）")
	if spell == null:
		_dump_evidence(chen, enemy, null)
		_finished = true
		return
	print("   [底账] chen.global=%s chen.ground_level=%.0f 弹体.global=%s enemy.global=%s" % [
			str(chen.global_position), chen.attributes.ground_level,
			str(spell.global_position), str(enemy.global_position)])

	var hit := false
	for _i in 260:
		await get_tree().physics_frame
		if not is_instance_valid(spell):
			break  # 命中即消（end→destroy）
		if enemy.attributes.health_current < hp0:
			hit = true
			break
	if not hit:
		hit = enemy.attributes.health_current < hp0
	_check(hit, "spar_enemy 血量在飞行窗口内下降（弹体真实命中）")
	if not hit:
		_dump_evidence(chen, enemy, spell)
	_finished = true


func _dump_evidence(chen: QuiverCharacter, enemy: Node, spell: SpellBase) -> void:
	print("  ── [现场取证] ──")
	if spell == null:
		print("   弹体不存在，吟唱/放体链路先查 cast_contract")
		return
	var hb: Area2D = null
	for node in spell.find_children("*", "QuiverHitBox", true):
		hb = node
		break
	if hb != null:
		print("   法术 hitbox 阵营=%s layer=%d mask=%d disabled=%s 全局位置=%s" % [
				hb._faction_dict.keys(), hb.collision_layer, hb.collision_mask,
				str(hb.get_child(0).disabled) if hb.get_child_count() > 0 else "n/a",
				str(hb.global_position)])
	var hurt := enemy.find_child("HurtBox", true, false) as Area2D
	if hurt != null:
		print("   敌人 hurtbox 阵营=%s layer=%d mask=%d" % [
				hurt._faction_dict.keys(), hurt.collision_layer, hurt.collision_mask])
	print("   弹体全局位置=%s 速度方向=%s" % [str(spell.global_position), str(spell.direction)])
	var chen_hb := chen.find_child("HurtBox", true, false) as Area2D
	if chen_hb != null:
		print("   施法者 chen hurtbox 阵营=%s（wall 从这张脸上被抄走）" % chen_hb._faction_dict.keys())
