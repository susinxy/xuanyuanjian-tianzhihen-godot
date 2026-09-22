extends Node

## 弹体命中集成测试（真 Run Test 场景复现 + 淡入淡出系统断言，2026-09-16 定档版）：
##   一、真实吟唱链路：上场→淡入门→命中→ENDING 淡出→真删，全程逐帧采样判定门；
##   二、双实例隔离：两发弹体各自的命中/消亡/回执事件必须各归各身；
##   三、僵尸回执：死体不得二次宣告。
## 【豁免】被测场景=addons 产线 Run-Test 镜像（ensure_spell_run_test 生成，
## 主角位绑 CHEN_SCENE 硬码=插件红线不许碰，场景根亦非 BaseStage/ChapterShell，
## playable_override 接缝在架构上不及此处）——绑定生产角色属题意
## （B2.5 新法申报，与 wp2_creation_test 镜像豁免同判例）。
## 教训固化：协程内报错=静默跳段（AGENTS 明文），本 runner 设完成旗汇总前必查；
##   事件帧号一律用循环内状态采样记录，不用 lambda 捕获局部变量（值拷贝陷阱）。
## 运行：godot --headless --path . res://tools/spell_hit_test/projectile_hit.tscn

const RUN_TEST := "res://test_scenes/_test_spell_fire_ball.tscn"
var _fade_in_f := 10    # 淡入帧窗：从磁盘定义派生（用户手感参数随时可调，测试
var _fade_out_f := 25   # 不得假设默认值——9/15 纪律执行化；+受击定格余量）

var _fails := 0
var _finished := false


func _ready() -> void:
	var def: SpellDefinition = load("res://spells/fire_ball/resources/fire_ball_definition.tres")
	_fade_in_f = int(ceil(def.fade_in_time * 60.0)) + 2
	_fade_out_f = int(ceil(def.fade_out_time * 60.0)) + 12
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


func _hitbox(spell: SpellBase) -> Area2D:
	if spell != null and is_instance_valid(spell) and spell._skin.hitboxes.size() > 0:
		return spell._skin.hitboxes[0]
	return null


func _layer_bits(spell: SpellBase) -> int:
	var hb := _hitbox(spell)
	if hb == null:
		return -1
	return hb.collision_layer & QuiverCharacter.get_all_height_layers_mask()


func _main_flow() -> void:
	# 自愈（2026-09-17）：test_scenes 是编辑器生成物，外部角色被删会留悬空
	# 引用场景（实例：陪练 test 角色删除→本套整场解析失败）。读前一律过
	# 编辑器同一 ensure 入口重建，幂等零写盘。
	QuiverRunTestSceneBuilder.ensure_spell_run_test("fire_ball", "chen")
	var stage := (load(RUN_TEST) as PackedScene).instantiate()
	add_child(stage)
	await _frames(5)

	var chen := stage.get_node_or_null("Character") as QuiverCharacter
	var enemy := stage.get_node_or_null("Enemy")
	_check(chen != null and enemy != null, "场景含被测角色与默认对手")
	if chen == null or enemy == null:
		_finished = true
		return
	_check(chen._spell_manager != null, "角色法术管理器就位")

	var hp_prev: float = enemy.attributes.health_current
	var hp_dropped := false
	chen.channel.press("spell_1")
	# 事件流追踪（点零距离贴身会让弹体出生即命中，固定帧号查岗会扑错——按事件序列）
	var spell: SpellBase = null
	var seen := false
	var seen_frame := -1
	var hit_frame := -1      # 弹体视角：自己的状态离开 ACTIVE 的帧
	var gone_frame := -1
	var viol_in := 0         # 淡入窗内层位非零的帧数
	var gate_open_frame := -1
	var viol_out := 0        # 离 ACTIVE 后层位非零的帧数
	for i in 340:
		await get_tree().physics_frame
		if enemy.attributes.health_current < hp_prev:
			hp_dropped = true
		if not seen:
			var found := _find_spell(stage)
			if found != null:
				spell = found
				seen = true
				seen_frame = i
		else:
			if is_instance_valid(spell):
				if hit_frame < 0 and spell.state != SpellBase.SpellState.ACTIVE:
					hit_frame = i
			elif gone_frame < 0:
				gone_frame = i
		if seen and spell != null and is_instance_valid(spell):
			var bits := _layer_bits(spell)
			# 违例=物理事实判定：淡入未完（亮度<1）或已离场（非 ACTIVE）而层非零。
			# 门与亮度同源一个倒计时，此断言即"同呼吸"证明，不用帧数窗口模拟。
			if bits != 0 and gate_open_frame < 0:
				gate_open_frame = i
			if bits != 0:
				if hit_frame < 0 and spell.modulate.a < 0.999:
					viol_in += 1
				elif hit_frame >= 0:
					viol_out += 1
		if seen and hit_frame >= 0 and gone_frame >= 0:
			break
	_check(seen, "弹体已上场（吟唱走完释放）")
	_check(hp_dropped, "spar_enemy 血量下降（弹体真实命中）")
	_check(hit_frame >= 0, "弹体进入 ENDING（命中回执→淡出）")
	_check(gone_frame >= 0, "弹体淡出完毕后真删")
	_check(viol_in == 0,
			"淡入期攻击盒层恒 0（无出生帧判定，违规 %d 帧）" % viol_in)
	_check(hit_frame >= 0 and gate_open_frame > 0,
			"淡入结束判定门开启（第 %d 帧，命中=%d）" % [gate_open_frame, hit_frame])
	_check(hit_frame < 0 or hit_frame >= gate_open_frame,
			"公平性：首次命中不早于门开（命中=%d 门开=%d）" % [hit_frame, gate_open_frame])
	_check(viol_out == 0, "淡出期攻击盒层恒 0（残壳不补刀，违规 %d 帧）" % viol_out)
	if hit_frame >= 0:
		_check(gone_frame >= 0 and gone_frame - hit_frame <= _fade_out_f,
				"淡出时长吻合（ENDING@%d 真删@%d ≤%d 帧）" % [hit_frame, gone_frame, _fade_out_f])
	await _dual_instance_isolation(stage, chen, enemy)
	await _zombie_receipt_guard(stage, chen, enemy)
	_finished = true


## 双实例隔离（用户锁定要求）：两发弹体同屏，各自的上场/门/命中/消亡事件
## 全部按弹体个体采样配对——任何跨实例串线（替死、抢门、补刀）当场破裂。
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
	var emits := [0, 0]
	for k in range(2):
		balls[k].spell_hit.connect(func(_tb): emits[k] += 1)
	var hits := [-1, -1]
	var gones := [-1, -1]
	var viols_in := [0, 0]
	var opens := [-1, -1]
	for i in 200:
		await get_tree().physics_frame
		for k in range(2):
			if gones[k] >= 0:
				continue
			if not is_instance_valid(balls[k]):
				gones[k] = i
				continue
			var bb := balls[k] as SpellBase
			if hits[k] < 0 and bb.state != SpellBase.SpellState.ACTIVE:
				hits[k] = i
			var bits := _layer_bits(bb)
			if bits != 0:
				if hits[k] < 0 and bb.modulate.a < 0.999:
					viols_in[k] += 1
				elif hits[k] >= 0:
					viols_in[k] += 100
		if gones[0] >= 0 and gones[1] >= 0:
			break
	_check(hits[0] >= 0 and hits[1] >= 0,
			"双弹各自命中离场（ENDING 帧 %s）" % [str(hits)])
	_check(gones[0] >= 0 and gones[1] >= 0, "双弹各自淡出真删（帧 %s）" % [str(gones)])
	if hits[0] >= 0 and gones[0] >= 0 and hits[1] >= 0 and gones[1] >= 0:
		var ok := true
		for k in range(2):
			if gones[k] - hits[k] > _fade_out_f or viols_in[k] != 0:
				ok = false
		_check(ok, "每弹独立淡入无判定/淡出时长吻合（viol=%s）" % [str(viols_in)])
	_check(emits[0] == 1 and emits[1] == 1,
			"每发弹体对外 spell_hit 恰好一次（实际 %s）" % [str(emits)])


## 僵尸回执守卫：多敌同帧重叠时后续回执落在已离场弹体上——
## 不得二次 emit、不得改状态。淡入中途被打中（alpha≈0）→ 淡出余量为 0
## → 瞬时 DEAD，属正确分支，ENDING/DEAD 皆为合法终态。
func _zombie_receipt_guard(stage: Node2D, chen: QuiverCharacter, enemy: Node) -> void:
	var scene: PackedScene = load("res://spells/fire_ball/fire_ball.tscn")
	var spell_def: SpellDefinition = load("res://spells/fire_ball/resources/fire_ball_definition.tres")
	var b := scene.instantiate() as SpellBase
	stage.add_child(b)
	b.global_position = Vector2(3000.0, 363.0)
	b.cast(chen, spell_def, Vector2.RIGHT)
	var emits := [0]
	b.spell_hit.connect(func(_tb): emits[0] += 1)
	var hb := enemy.find_child("HurtBox", true, false) as QuiverHurtBox
	b.on_hit(hb)
	b.on_hit(hb)
	_check(emits[0] == 1,
			"僵尸回执：已离场弹体第二张回执不再 emit（实际 %d 次）" % emits[0])
	_check(b.state == SpellBase.SpellState.ENDING or b.state == SpellBase.SpellState.DEAD,
			"僵尸回执：状态已离 ACTIVE（实际 %d）" % b.state)
	b.destroy()
	_check(b.state == SpellBase.SpellState.DEAD, "销毁幂等：二次 destroy 不改写 DEAD")
