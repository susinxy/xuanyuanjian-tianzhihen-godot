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

	chen.channel.press("spell_1")
	# 事件流追踪（不定时点查岗：咏唱期间陪练可能贴身，点零距离命中会让弹体
	# 出生即灭——那是正确战斗行为，测试必须按事件序列判定而非固定帧号）
	var spell: SpellBase = null
	var seen := false
	var seen_frame := -1
	var hit_frame := -1
	var gone_frame := -1
	var hp_prev: float = enemy.attributes.health_current
	for i in 340:
		await get_tree().physics_frame
		if not seen:
			var found := _find_spell(stage)
			if found != null:
				spell = found
				seen = true
				seen_frame = i
		else:
			if is_instance_valid(spell):
				if hit_frame < 0 and enemy.attributes.health_current < hp_prev:
					hit_frame = i
			elif gone_frame < 0:
				gone_frame = i
		if seen and hit_frame >= 0 and gone_frame >= 0:
			break
	_check(seen, "弹体已上场（吟唱走完释放）")
	_check(hit_frame >= 0, "spar_enemy 血量下降（弹体真实命中）")
	if not seen:
		_dump_evidence(chen, enemy, null)
	elif hit_frame < 0:
		_dump_evidence(chen, enemy, spell)
	else:
		# 命中通知链闭合断言（2026-09-16 定罪）：敌人 hurtbox 沿 hit_box.owner
		# 反射调 on_hit——链路修复前通知静默丢弃，弹体穿体飞到 5s 超时（300 帧）
		# 才灭；修复后必须在掉血数帧内消亡（超时灭与命中灭以帧距判别）。
		_check(gone_frame >= 0 and gone_frame - hit_frame <= 3,
				"命中即灭：掉血后 ≤3 帧弹体消亡（掉血帧=%d 消亡帧=%d）" % [hit_frame, gone_frame])
	await _dual_instance_isolation(stage, chen, enemy)
	_finished = true


## 双实例隔离（2026-09-16 用户锁定要求：多发法术的通知/生命必须实例私有）。
## 直接构造两发弹体（不同起点、同泳道）飞向同一敌人：两次掉血事件与两次
## 弹体消亡事件必须按时间严格配对——若通知跨实例串线（两发都响应第一击、
## 或某发收到别人的回执），配对当场破裂。
func _dual_instance_isolation(stage: Node2D, chen: QuiverCharacter, enemy: Node) -> void:
	var scene: PackedScene = load("res://spells/fire_ball/fire_ball.tscn")
	var spell_def: SpellDefinition = load("res://spells/fire_ball/resources/fire_ball_definition.tres")
	var balls: Array = []
	for x in [258.0, 358.0]:
		var b := scene.instantiate() as SpellBase
		stage.add_child(b)
		b.global_position = Vector2(x, 363.0)
		b.cast(chen, spell_def, Vector2.RIGHT)
		balls.append(b)
	var drops: Array[int] = []
	var gones := [-1, -1]
	var prev: float = enemy.attributes.health_current
	for i in 160:
		await get_tree().physics_frame
		var now: float = enemy.attributes.health_current
		if now < prev:
			drops.append(i)
		prev = now
		for k in range(balls.size()):
			if gones[k] < 0 and not is_instance_valid(balls[k]):
				gones[k] = i
		if drops.size() >= 2 and gones[0] >= 0 and gones[1] >= 0:
			break
	_check(drops.size() == 2, "双弹双命中：两次掉血事件（帧 %s）" % [str(drops)])
	_check(gones[0] >= 0 and gones[1] >= 0,
			"两发弹体各自消亡（帧 %s）" % [str(gones)])
	if drops.size() == 2 and gones[0] >= 0 and gones[1] >= 0:
		var gs := gones.duplicate()
		gs.sort()
		var paired := true
		for j in 2:
			if gs[j] < drops[j] or gs[j] - drops[j] > 3:
				paired = false
		_check(paired, "消亡与掉血严格一对一配对（通知实例私有，零串线）")


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
