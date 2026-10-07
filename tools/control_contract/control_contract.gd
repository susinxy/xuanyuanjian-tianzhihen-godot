extends Node

## control_contract —— 被控角色/接管系统契约（2026-10 接管批，矩阵新条目）
## 管辖腿表：
## · C1 take_control 主链：行为互换默认、controlled 组迁移、档位/行为类双证；
## · C2 身份判据：controlled 优先；树内无 controlled=回落 area2d:player（现状兼容形）；
## · C3 相机跟交接管（reparent+current 补位）；
## · C4 段申报（读法一严格申报制）：入场先接管后落位、无申报段回正初始被控者；
## · C5 索敌配置：场景导出注入 + 运行时增删即时生效（helper 通用入口）；
## · C6 索敌默认=玩家阵营组（现状等价回归锁）；
## · C7 拒接形态：空目标/树外目标/同体幂等；
## · C9 败北演出单门：旁观者之死不劫持 time_scale/被控者之死慢放+终局+归位
##   （锚点批；术前双红据 S5=launch 漏改判据的倒置实锤，永久锁）；
## · C10-C12 终局锚点：段申报挂锚+致死同闸+restart 随段还魂/申报驱动换段全清
##   +API 临时态/壳级 ghost 降级；C13 无壳回落兼容形（Run-Test 生态锁）。
## 全数门 EXPECTED=55（锚点批终账，改腿必须同步本数）。
## 测试主权法（B2.5）：本体一律 test_actor 替身（Kit 消费只读，缺席=红+处方）。
## 落盘卫生（影子条款）：C4 触检查点记账——首行重定向 slot 到本套 scratch，
## 永不碰生产档 save_auto.json。
## 【豁免】无——不消费 chen 本体数据。

const Kit := preload("res://tools/matrix_runner/test_actor_kit.gd")
const SHELL_TEMPLATE := "res://scenes/chapter/chapter_shell.tscn"
const STAGE_SCRIPT := "res://scripts/chapter/stage_content.gd"
const POLICY_FIXTURE := preload("res://tools/control_contract/contract_ai_policy.gd")

var _fails := 0
var _asserts := 0
var _finished := false


func _ready() -> void:
	# 落盘卫生：影子条款（六套同形制）
	var save_sys := get_node_or_null(^"/root/SaveSystem")
	if save_sys != null:
		save_sys.slot_path = "user://control_scratch.json"
	await _run_all()
	# 完成旗（协程静默跳段判例的防线）：全序列跑到尾才绿
	_finished = true
	_report()


func _check(cond: bool, msg: String) -> void:
	_asserts += 1
	if cond:
		print("  PASS: ", msg)
	else:
		_fails += 1
		print("  FAIL: ", msg)


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _require_kit(tag: String) -> bool:
	if not Kit.exists():
		_check(false, "%s test_actor 缺席（先跑 run_matrix.sh --ensure-only）" % tag)
		return false
	return true


func _mk_actor(p_name: String) -> QuiverCharacter:
	var a := (load(Kit.ACTOR_SCENE) as PackedScene).instantiate() as QuiverCharacter
	a.name = p_name
	return a


func _run_all() -> void:
	print("════════ control-contract 开始 ════")

	# ── C6/C2-fallback：无壳判据与索敌默认（须在任何 controlled 存在之前跑）──
	# 挂点=self（runner Node，已入树且不忙）——root._ready 期间 add_child
	# 触发 "busy setting up children" 丢演员判例（4.7.1 实测，首跑假绿根因）。
	var standalone := self
	var p_near := _mk_actor("C6Near")
	var p_far := _mk_actor("C6Far")
	p_near.global_position = Vector2(100, 0)
	p_far.global_position = Vector2(900, 0)
	standalone.add_child(p_near)
	standalone.add_child(p_far)
	await _frames(2)
	var ai := _mk_actor("C6Ai")
	standalone.add_child.call_deferred(ai)  # 先挂树再换档（switch_behavior 非编辑态要树）
	await _frames(2)
	_check(standalone.get_tree() != null, "C6 独立演员挂树就绪")
	# C2 回落腿：树内无 controlled → player 标签身份成立（现状兼容形）
	_check(QuiverCharacterHelper.is_player_identity(p_near),
			"C2 无 controlled 组时判据回落 area2d:player（现状零漂移腿）")
	# C5/C6：行为档+索敌入口
	ai.ai_policy_script = POLICY_FIXTURE
	ai.switch_behavior(QuiverCharacter.BehaviorMode.AI_POLICY)
	await _frames(1)
	_check(ai.behavior is QuiverBehaviorAI, "C5 AI 档=策略小抄实例化为行为")
	var tgt: QuiverCharacter = (ai.behavior as QuiverBehaviorAI).closest_target()
	_check(tgt == p_near, "C6 默认索敌=玩家组最近者（现状等价；实际 %s）" % str(tgt))
	# 运行时增删即时生效：先摘 near 的玩家标签→目标漂 far；加 controlled 组并配置→回 near
	p_near.remove_from_group(&"area2d:player")
	tgt = (ai.behavior as QuiverBehaviorAI).closest_target()
	_check(tgt == p_far, "C5 索敌读配置即时生效：摘组后目标漂移（实际 %s）" % str(tgt))
	p_near.add_to_group(&"controlled")
	ai.add_ai_target_group(&"controlled")
	tgt = (ai.behavior as QuiverBehaviorAI).closest_target()
	_check(tgt == p_near, "C5 add_ai_target_group 后 controlled 优先最近（实际 %s）" % str(tgt))
	ai.remove_ai_target_group(&"controlled")
	ai.remove_ai_target_group(&"area2d:player")
	tgt = (ai.behavior as QuiverBehaviorAI).closest_target()
	_check(tgt == null, "C5 remove 至空集=索敌空（无隐藏兜底；实际 %s）" % str(tgt))
	# 场景持久值注入腿：导出非空覆盖默认
	var ai2 := _mk_actor("C5Persist")
	ai2.add_to_group(&"fixture_persist_tag")
	ai2.ai_target_groups = [&"fixture_persist_tag"]
	standalone.add_child(ai2)
	await _frames(2)
	ai2.switch_behavior(QuiverCharacter.BehaviorMode.AI_POLICY)
	await _frames(1)
	tgt = (ai2.behavior as QuiverBehaviorAI).closest_target()
	_check(tgt == null,
			"C5 反向锁：导出=persist 组时玩家组目标一律不认（整体覆盖非并集；实际 %s）" % str(tgt))
	# 注入正向腿：导出改回玩家组重切档，应命中玩家组目标
	ai2.ai_target_groups = [&"area2d:player"]
	ai2.switch_behavior(QuiverCharacter.BehaviorMode.AI_POLICY)
	await _frames(1)
	tgt = (ai2.behavior as QuiverBehaviorAI).closest_target()
	# 期望=C6Ai（此刻它仍挂树带玩家组且距 ai2 最近；p_near 已在先腿摘组）
	_check(tgt == ai, "C5 注入正向腿：导出=玩家组时命中玩家组最近者（实际 %s）" % str(tgt))
	standalone.remove_child(ai2)
	ai2.queue_free()
	standalone.remove_child(ai)
	ai.queue_free()
	# 清理 C 段残组（controlled 必须出清，否则后续壳腿判据被污染）
	standalone.remove_child(p_near)
	p_near.queue_free()
	standalone.remove_child(p_far)
	p_far.queue_free()
	await _frames(2)
	_check(standalone.get_tree().get_nodes_in_group(&"controlled").is_empty(),
			"C2 前置腿清场：controlled 出净（判据回落形的前提）")

	# ── C1/C3/C7：壳+接管主链 ──
	if not _require_kit("C1"):
		return
	var shell: ChapterShell = (load(SHELL_TEMPLATE) as PackedScene).instantiate()
	shell.chapter_id = &"t_ctl"
	shell.playable_override = load(Kit.ACTOR_SCENE)
	add_child(shell)
	await _frames(3)
	var first := shell.playable as QuiverCharacter
	_check(first != null and first.is_in_group(&"controlled"),
			"C1 初始被控者出生即挂 controlled（壳申报制地基）")
	_check(shell._initial_playable == first, "C1 初始被控者存位（回正锚）")
	var npc := _mk_actor("Npc")
	npc.remove_from_group(&"area2d:player")  # 出身无玩家标签（中立 NPC 形）
	shell.get_node("Players").add_child(npc)
	await _frames(2)
	# C7 拒接腿先行（不改变状态）
	_check(not shell.take_control(null), "C7 空目标拒接")
	var outside := _mk_actor("Outside")
	_check(not shell.take_control(outside), "C7 树外目标拒接（壳管辖门）")
	outside.free()
	# 互换语义：npc 先降被动（模拟出身档位），接管后旧体应继承 npc 的 PASSIVE
	npc.switch_behavior(QuiverCharacter.BehaviorMode.PASSIVE)
	await _frames(1)
	_check(shell.take_control(npc), "C1 take_control 返回绿")
	_check(npc.behavior_mode == QuiverCharacter.BehaviorMode.PLAYER_INPUT
			and npc.behavior is QuiverBehaviorPlayer,
			"C1 新体=PLAYER_INPUT 档+玩家行为实例")
	_check(npc.is_in_group(&"controlled") and first.is_in_group(&"controlled") == false,
			"C1 controlled 组迁移（新体摘旧体）")
	_check(first.behavior_mode == QuiverCharacter.BehaviorMode.PASSIVE
			and not (first.behavior is QuiverBehaviorPlayer),
			"C1 旧体继承新体原档位（行为互换默认，old_policy=-1）")
	_check(shell.playable == npc, "C1 身份权威 playable 换引用")
	_check(QuiverCharacterHelper.is_player_identity(npc)
			and not QuiverCharacterHelper.is_player_identity(first),
			"C2 接管后判据：controlled 说了算（旧体玩家标签不再=身份）")
	# C3 相机
	var cam := shell.get_node_or_null("Players/Npc/LevelCamera") as Camera2D
	_check(cam != null and cam.is_current() and shell.playable == npc,
			"C3 相机自动跟挂新体（reparent+current 补位判例）")
	_check(shell.take_control(npc), "C7 同体重复接管=幂等 true")
	# 显式 old_policy 腿：旧体按参数处置（非互换）——npc 当前 PLAYER_INPUT，
	# 互换形旧体应继承 PLAYER_INPUT；显式 PASSIVE 形旧体=PASSIVE（与互换结果分岔=判据）
	_check(shell.take_control(first, int(QuiverCharacter.BehaviorMode.PASSIVE)),
			"C1 显式 old_policy 接管绿")
	_check(first.behavior_mode == QuiverCharacter.BehaviorMode.PLAYER_INPUT
			and npc.behavior_mode == QuiverCharacter.BehaviorMode.PASSIVE,
			"C1 old_policy 显式形：旧体(npc)切指定档，新体(first)恒 PLAYER_INPUT")
	shell.queue_free()
	await _frames(3)

	# ── C4：段申报（读法一）+先接管后落位+回正 ──
	if not _require_kit("C4"):
		return
	var seg_x := _mk_seg_declaring(&"t_segx")
	var packed_x := _pack(seg_x)
	seg_x.free()
	var seg_y := Node2D.new()
	seg_y.set_script(load(STAGE_SCRIPT))
	seg_y.segment_id = &"t_segy"
	var packed_y := PackedScene.new()
	_check(packed_y.pack(seg_y) == OK, "C4 无申报段打包 OK")
	seg_y.free()
	if packed_x == null or packed_y == null:
		_check(false, "C4 打包失败（前置红）")
		return
	var shell2: ChapterShell = (load(SHELL_TEMPLATE) as PackedScene).instantiate()
	shell2.chapter_id = &"t_ctl2"
	shell2.playable_override = load(Kit.ACTOR_SCENE)
	shell2.segment_scenes = [packed_x, packed_y]
	add_child(shell2)
	await _frames(3)
	# 出生即入第一段=申报自动应用
	var declared := shell2._current.get_node_or_null("Npc2") as QuiverCharacter
	var hero := shell2._initial_playable as QuiverCharacter
	_check(declared != null, "C4 段树接管目标 Npc2 在位")
	if declared == null:
		return
	_check(shell2.playable == declared,
			"C4 入场申报自动接管（首段声明=出生即应用；playable=%s）" % str(shell2.playable))
	_check(declared.global_position == shell2._current.to_global(Vector2(500, 600)),
			"C4 先接管后落位：入口点写到新被控者（旧体原地留守）")
	_check(hero.global_position == Vector2(0, 0),
			"C4 旧被控者未被落位挪动（原地留守腿）")
	_check(declared.is_in_group(&"controlled") and not hero.is_in_group(&"controlled"),
			"C4 申报接管的 controlled 迁移")
	_check(shell2._current.get_node("Npc2/LevelCamera") != null,
			"C4 camera_host_path 申报=镜头挂段内目标")
	# 推进到无申报段=回正
	shell2.enter_segment(&"t_segy", &"default")
	await _frames(3)
	_check(shell2.playable == hero, "C4 无申报段回正初始被控者（读法一，无幽灵延续）")
	_check(hero.is_in_group(&"controlled"), "C4 回正后 controlled 在初始体")
	# 段重建语义腿（未清段丢弃重建法理）：segX 未判清随段重建，段内 Npc2
	# 释放——回正腿必须对悬垂旧体免疫（take_control is_instance_valid 守卫，
	# 本守卫由本契约抓获后补入生产）。
	_check(is_instance_valid(declared)
			and declared.get_parent() == shell2.get_node("Players"),
			"C4 捞人批改判：未清段丢弃时被控者获救收编 Players（不再随段释放；"
			+ "悬垂守卫仍防其它非被控段内实体路径）")
	_check(QuiverCharacterHelper.is_player_identity(hero)
			and shell2._camera != null and shell2._camera.is_current(),
			"C4 回正后判据/相机链完好（悬垂旧体未拖垮接管链）")
	shell2.queue_free()
	await _frames(3)

	# ── C9 败北演出单门（锚点批：慢放+终局= defeat_bound 一个闸）──
	await _c9_single_gate()

	# ── C10-C12 终局锚点申报面 ──
	await _c10_anchor_segment()

	# ── C14-C15 段生命周期×被控者（捞人不变量）──
	await _c14_15_segment_lifecycle()


## C10-C12 锚点申报：段申报挂锚→锚点致死触发慢放+终局（锚与被控同闸）→
## restart 重建段自然还魂重挂；C11 换无申报段=锚清空（申报驱动+API 临时态
## 归零）；C12 壳级锚路径失效=降级无锚不崩。
func _c10_anchor_segment() -> void:
	Engine.time_scale = 1.0
	if not _require_kit("C10"):
		return
	var guard_seg := Node2D.new()
	guard_seg.set_script(load(STAGE_SCRIPT))
	guard_seg.segment_id = &"t_seg_guard"
	var annie := _mk_actor("Annie")
	guard_seg.add_child(annie)
	annie.owner = guard_seg
	guard_seg.set("defeat_anchor_path", NodePath("Annie"))
	var gp := PackedScene.new()
	if gp.pack(guard_seg) != OK:
		_check(false, "C10 锚点段打包失败")
		guard_seg.free()
		return
	guard_seg.free()
	var plain := Node2D.new()
	plain.set_script(load(STAGE_SCRIPT))
	plain.segment_id = &"t_seg_plain"
	var pp := PackedScene.new()
	var pack_plain: bool = pp.pack(plain) == OK
	plain.free()

	var shell4: ChapterShell = (load(SHELL_TEMPLATE) as PackedScene).instantiate()
	shell4.chapter_id = &"t_ctl4"
	shell4.playable_override = load(Kit.ACTOR_SCENE)
	shell4.segment_scenes = [gp, pp]
	add_child(shell4)
	await _frames(3)
	var annie2: QuiverCharacter = shell4._current.get_node_or_null("Annie")
	var hero4: QuiverCharacter = shell4.playable
	_check(annie2 != null and annie2.is_in_group(&"defeat_anchor"),
			"C10 段申报入场挂锚（护送对象=不能死的人）")
	_check(hero4 != null and hero4.is_in_group(&"controlled"),
			"C10 被控者不受锚点申报影响（维度正交）")
	_check(QuiverCharacterHelper.is_defeat_bound(hero4)
			and QuiverCharacterHelper.is_defeat_bound(annie2),
			"C10 败北集合=锚∪被控 双真")
	var died := {"n": 0}
	var cb := func() -> void: died["n"] += 1
	Events.player_died.connect(cb)
	annie2.attributes.health_current = 0.0
	var dir := Vector2(cos(deg_to_rad(-30.0)), sin(deg_to_rad(-30.0)))
	CombatSystem.apply_knockback(_mk_kd(1200.0, dir), annie2.attributes)
	var l1 := await _wait_state(annie2, "Air/Knockout/Launch", 90)
	_check(l1, "C10 锚点破线起飞（演出链物理前提）")
	await _frames(6)
	_check(Engine.time_scale < 1.0, "C10 锚点致死触发慢放演出（同闸待遇）实=%s"
			% str(Engine.time_scale))
	for _i in range(300):
		if died["n"] > 0:
			break
		await get_tree().physics_frame
	_check(died["n"] == 1, "C10 锚点死亡终局广播恰一次（实=%d）" % died["n"])
	Events.player_died.disconnect(cb)
	Engine.time_scale = 1.0
	# 终局→段重跑（_on_player_died→restart_segment）→申报段重建=锚点自然还魂
	await _frames(180)
	var annie3: QuiverCharacter = shell4._current.get_node_or_null("Annie") if shell4._current != null else null
	_check(annie3 != null and annie3.is_in_group(&"defeat_anchor"),
			"C10 护送失败重跑后锚点随段还魂重挂（申报驱动自愈）")
	var api_t := _mk_actor("ApiT")
	shell4.get_node("Players").add_child(api_t)
	await _frames(1)
	shell4.add_defeat_anchor(api_t)
	_check(api_t.is_in_group(&"defeat_anchor"), "C11 add_defeat_anchor 运行时挂锚绿")
	if pack_plain:
		shell4.enter_segment(&"t_seg_plain", &"default")
		await _frames(3)
		_check(shell4.get_tree().get_nodes_in_group(&"defeat_anchor").is_empty(),
				"C11 无申报段=锚全清（申报驱动，API 临时态换段归零）")
	shell4.defeat_anchor_path = NodePath("Players/Ghost")
	shell4.enter_segment(&"t_seg_guard", &"default")
	await _frames(3)
	var annie4: QuiverCharacter = shell4._current.get_node_or_null("Annie") if shell4._current != null else null
	_check(annie4 != null and annie4.is_in_group(&"defeat_anchor"),
			"C12 壳级失效路径不夺段申报锚（段申报优先腿在位）")
	shell4.defeat_anchor_path = NodePath("")
	shell4.enter_segment(&"t_seg_plain", &"default")
	await _frames(3)
	_check(QuiverCharacterHelper.is_defeat_bound(shell4.playable)
			and shell4.get_tree().get_nodes_in_group(&"defeat_anchor").is_empty(),
			"C12 壳级 ghost 失配=仅被控者算败北（降级形不崩）")
	shell4.queue_free()
	await _frames(3)

	# C13 无壳兼容形：裸 player 标签角色=败北集合（Run-Test 生态回归锁）
	var lone := _mk_actor("Lone")
	add_child(lone)
	await _frames(1)
	_check(QuiverCharacterHelper.is_defeat_bound(lone)
			and QuiverCharacterHelper.is_player_identity(lone),
			"C13 无锚无控树=回落 area2d:player 兼容形（单跑零漂移）")
	lone.queue_free()
	await _frames(2)


## C14/C15 段生命周期捞人不变量："被控者永不随段离场"——
## C15a 判清缓存保活腿（demo 纯灰事故根因复刻）；C15b 未清丢弃重跑腿；
## C14 demo 真实资产全链（旁观者之死无全局慢放+判清换段后仍可操控+锚重挂）。
func _c14_15_segment_lifecycle() -> void:
	Engine.time_scale = 1.0
	if not _require_kit("C15"):
		return

	# ══ C15a：接管段内 NPC → 判清换段 → 被控者必须仍在树内 ══
	var segL := _mk_judged_seg(&"t_segl", "NpcD")
	var pl: PackedScene = _pack(segL)
	segL.free()
	var segR := Node2D.new()
	segR.set_script(load(STAGE_SCRIPT))
	segR.segment_id = &"t_segr"
	var pr := PackedScene.new()
	var pack_r: bool = pr.pack(segR) == OK
	segR.free()
	var shell5: ChapterShell = (load(SHELL_TEMPLATE) as PackedScene).instantiate()
	shell5.chapter_id = &"t_ctl5"
	shell5.playable_override = load(Kit.ACTOR_SCENE)
	shell5.segment_scenes = [pl, pr]
	add_child(shell5)
	await _frames(3)
	var npcd: QuiverCharacter = shell5._current.get_node_or_null("NpcD")
	var actorE: QuiverCharacter = shell5._initial_playable
	_check(npcd != null and shell5.playable == npcd, "C15a 段申报接管 NpcD 在位")
	if npcd == null or not pack_r:
		shell5.queue_free()
		await _frames(2)
		return
	var sp: QuiverEnemySpawner = shell5._current.get_node_or_null("Room1/EnemySpawner1")
	_check(sp != null, "C15a 判清件（spawner）在位")
	if sp == null:
		shell5.queue_free()
		await _frames(2)
		return
	sp.is_completed = true
	sp.all_waves_completed.emit()
	await _frames(160)  # 90 静默窗+落位链
	_check(npcd.is_inside_tree(),
			"C15a 判清换段后被控者不随段离场（捞人不变量；修前红据=被 remove_child 收走=纯灰根因）")
	_check(shell5.playable == actorE and actorE.is_in_group(&"controlled"),
			"C15a 换段回正成功（ActorE 接管回）实=%s" % str(shell5.playable))
	_check(not npcd.is_in_group(&"controlled"), "C15a 交班后 NpcD 不再被控")
	_check(npcd.get_parent() == shell5.get_node("Players"),
			"C15a 获救被控者收编壳层 Players（不随段进缓存）")
	shell5.queue_free()
	await _frames(3)

	# ══ C15b：接管段内 NPC → 死亡重跑（未清丢弃腿）→ 被控者仍活 ══
	var shell6: ChapterShell = (load(SHELL_TEMPLATE) as PackedScene).instantiate()
	shell6.chapter_id = &"t_ctl6"
	shell6.playable_override = load(Kit.ACTOR_SCENE)
	shell6.segment_scenes = [pl]
	add_child(shell6)
	await _frames(3)
	var npce := shell6._current.get_node_or_null("NpcD") as QuiverCharacter
	_check(npce != null and shell6.playable == npce, "C15b 出生段申报接管在位")
	shell6.restart_segment(&"manual")   # 未判清→丢弃重建腿
	await _frames(200)
	_check(npce.is_inside_tree(),
			"C15b 重跑丢弃腿同样捞人（被控者不随丢弃释放；修前红据=悬垂灰死变体）")
	var fresh: QuiverCharacter = shell6._current.get_node_or_null("NpcD") if shell6._current != null else null
	_check(fresh != null and fresh != npce and shell6.playable == fresh,
			"C15b 重建段新申报体接管（旧获救体让位旁观=孪生锁：fresh=%s old=%s）"
			% [str(fresh != null), str(npce != null)])
	# C15c 判清账章维度锁：shell5（t_ctl5）已判清 t_segl 不得串到 shell6（t_ctl6）
	_check(not shell6.session.is_cleared(&"t_segl", &"t_ctl6")
			and shell6.session.is_cleared(&"t_segl", &"t_ctl5"),
			"C15c 判清 key 含章维度：同段 id 跨章不串扰（串扰时 shell6 走缓存腿=本次事故根因之一）")
	shell6.queue_free()
	await _frames(3)

	# ══ C14：demo 真实资产全链（用户实机路线永久化）══
	var shellD: ChapterShell = (load("res://scenes/stages/demo_control/chapter_demo_ctl.tscn") as PackedScene).instantiate()
	add_child(shellD)
	await _frames(3)
	var vendD: QuiverCharacter = shellD.playable
	var chenD: QuiverCharacter = shellD._initial_playable
	_check(vendD != null and vendD.name == "Vendor" and Engine.time_scale == 1.0,
			"C14 demo 出生接管小贩+无慢放残留")
	if vendD == null or chenD == null:
		shellD.queue_free()
		await _frames(2)
		return
	# 怪实战打死旁观靖仇：致死击飞走单闸——不得触碰全局时间
	chenD.attributes.health_current = 0.0
	var dirD := Vector2(cos(deg_to_rad(-30.0)), sin(deg_to_rad(-30.0)))
	CombatSystem.apply_knockback(_mk_kd(1200.0, dirD), chenD.attributes)
	await _frames(6)
	_check(is_equal_approx(Engine.time_scale, 1.0),
			"C14 旁观者致死击不劫持全局时间（用户报「慢放」归因=B4.7 攻击方自慢放，非 time_scale）实=%s"
			% str(Engine.time_scale))
	var chen_gone := false
	for _i in range(400):
		if not is_instance_valid(chenD):
			chen_gone = true
			break
		await get_tree().physics_frame
	_check(chen_gone, "C14 旁观者之死=普通阵亡离场（queue_free 腿）")
	# 判清换段（seg01 真 spawner 手动 emit 同款）
	var spD: QuiverEnemySpawner = shellD._current.get_node_or_null("Room1/EnemySpawner1")
	if spD != null:
		spD.is_completed = true
		spD.all_waves_completed.emit()
	await _frames(170)
	_check(shellD._current != null and shellD._current.segment_id == &"seg_d02",
			"C14 判清推进到第二段（实=%s）" % str(shellD._current.segment_id if shellD._current else null))
	_check(vendD.is_inside_tree() and shellD.playable == vendD,
			"C14 换段后小贩仍在场可继续操控（回正扑空降级腿；修前红据=随 seg01 离场=纯灰）")
	var escD := shellD._current.get_node_or_null("Escort") as QuiverCharacter
	_check(escD != null and escD.is_in_group(&"defeat_anchor"),
			"C14 第二段 Escort 锚点重挂（护送幕在位）")
	_check(is_equal_approx(Engine.time_scale, 1.0), "C14 全程无 time_scale 泄漏")
	shellD.queue_free()
	await _frames(3)


func _mk_judged_seg(sid: StringName, npc_name: String) -> Node2D:
	# 判清演示段：Room1+Spawner+Detector+申报接管段内 NPC（stage_contract B3 形制）
	var seg := Node2D.new()
	seg.set_script(load(STAGE_SCRIPT))
	seg.segment_id = sid
	var room := ReferenceRect.new()
	room.name = "Room1"
	room.set_script(load("res://addons/quiver.beat_em_up/utilities/custom_nodes/quiver_fight_room.gd"))
	seg.add_child(room)
	room.owner = seg
	var sp := Marker2D.new()
	sp.name = "EnemySpawner1"
	sp.set_script(load("res://addons/quiver.beat_em_up/utilities/custom_nodes/enemy_spawner/quiver_enemy_spawner.gd"))
	room.add_child(sp)
	sp.owner = seg
	var det := Area2D.new()
	det.name = "PlayerDetector"
	det.set_script(load("res://addons/quiver.beat_em_up/utilities/custom_nodes/quiver_player_detector.gd"))
	room.add_child(det)
	det.owner = seg
	det.path_fight_room = NodePath("../Room1")
	var sp_paths: Array[NodePath] = [NodePath("../EnemySpawner1")]
	det.paths_enemy_spawners = sp_paths
	var npc := _mk_actor(npc_name)
	seg.add_child(npc)
	npc.owner = seg
	seg.set("control_target_path", NodePath(npc_name))
	return seg


## C9 败北演出单门：接管在场时——①旁观者（保留玩家标签）被破线击飞
## 不得触发全局慢放（术前红据：launch 漏改判据=慢放触发且 die 不恢复=卡慢速）；
## ②被控者（无玩家标签）被破线击飞必须触发慢放+终局广播+时间恢复
## （术前红据：漏改期被控者死亡无演出）。
func _c9_single_gate() -> void:
	Engine.time_scale = 1.0
	if not _require_kit("C9"):
		return
	var shell3: ChapterShell = (load(SHELL_TEMPLATE) as PackedScene).instantiate()
	shell3.chapter_id = &"t_ctl3"
	shell3.playable_override = load(Kit.ACTOR_SCENE)
	add_child(shell3)
	await _frames(3)
	var npc := _mk_actor("NpcC")
	npc.remove_from_group(&"area2d:player")  # 中立出身形：旧判据（标签）必然漏演
	shell3.get_node("Players").add_child(npc)
	await _frames(2)
	_check(shell3.take_control(npc), "C9 接管预备绿")
	var bystander: QuiverCharacter = shell3._initial_playable
	_check(bystander != null and not QuiverCharacterHelper.is_player_identity(bystander)
			and bystander.is_in_group(&"area2d:player"),
			"C9a 前提：旁观者保留玩家标签但非身份（漏改判据的抓获位）")
	var dir := Vector2(cos(deg_to_rad(-30.0)), sin(deg_to_rad(-30.0)))
	bystander.attributes.health_current = 0.0
	CombatSystem.apply_knockback(_mk_kd(1200.0, dir), bystander.attributes)
	var l1 := await _wait_state(bystander, "Air/Knockout/Launch", 90)
	_check(l1, "C9a 旁观者破线起飞（演出链物理前提在位）")
	await _frames(8)
	_check(is_equal_approx(Engine.time_scale, 1.0),
			"C9a 旁观者之死不触发慢放不劫持时间（锚点批单门；术前红据=S5a 卡慢速）实=%s"
			% str(Engine.time_scale))
	Engine.time_scale = 1.0
	var died := {"n": 0}
	var cb := func() -> void: died["n"] += 1
	Events.player_died.connect(cb)
	npc.attributes.health_current = 0.0
	CombatSystem.apply_knockback(_mk_kd(1200.0, dir), npc.attributes)
	var l2 := await _wait_state(npc, "Air/Knockout/Launch", 90)
	_check(l2, "C9b 被控者破线起飞")
	await _frames(6)
	_check(Engine.time_scale < 1.0,
			"C9b 被控者致死击触发慢放演出（术前红据=无演出）实=%s" % str(Engine.time_scale))
	var dead := false
	for _i in range(300):
		if died["n"] > 0:
			dead = true
			break
		await get_tree().physics_frame
	Events.player_died.disconnect(cb)
	_check(dead and died["n"] == 1, "C9b 被控者死亡终局广播恰一次（实=%d）" % died["n"])
	_check(is_equal_approx(Engine.time_scale, 1.0), "C9b 终局后 time_scale 归位")
	Engine.time_scale = 1.0
	shell3.queue_free()
	await _frames(3)


func _mk_kd(k: float, v: Vector2) -> QuiverKnockbackData:
	return QuiverKnockbackData.new(k, CombatSystem.HurtTypes.HIGH, v)


func _wait_state(ch: QuiverCharacter, path: String, cap: int) -> bool:
	for _i in range(cap):
		if str(ch.state_machine.state_name) == path:
			return true
		await get_tree().physics_frame
	return str(ch.state_machine.state_name) == path


## C4 用：带申报的段（树内 Npc2 + 双申报导出）
func _mk_seg_declaring(sid: StringName) -> Node2D:
	var seg := Node2D.new()
	seg.set_script(load(STAGE_SCRIPT))
	seg.segment_id = sid
	var npc2 := _mk_actor("Npc2")
	seg.add_child(npc2)
	npc2.owner = seg  # pack 序列化 owner 链判例（缺 owner=子树丢包）
	seg.set("control_target_path", NodePath("Npc2"))
	seg.set("camera_host_path", NodePath("Npc2"))
	return seg


func _pack(seg: Node2D) -> PackedScene:
	var packed := PackedScene.new()
	if packed.pack(seg) != OK:
		return null
	return packed


func _report() -> void:
	var ok := _fails == 0 and _finished and _asserts >= 72  # 全数门：捞人批 C14/C15 后定账（首跑核数校准）
	print("════════ control-contract: %s ════（断言 %d，红 %d，完成旗=%s）"
			% ["PASS" if ok else "FAIL", _asserts, _fails, str(_finished)])
	get_tree().quit(0 if ok else 1)
