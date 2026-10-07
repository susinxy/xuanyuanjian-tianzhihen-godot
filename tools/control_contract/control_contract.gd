extends Node

## control_contract —— 被控角色/接管系统契约（2026-10 接管批，矩阵新条目）
## 管辖腿表：
## · C1 take_control 主链：行为互换默认、controlled 组迁移、档位/行为类双证；
## · C2 身份判据：controlled 优先；树内无 controlled=回落 area2d:player（现状兼容形）；
## · C3 相机跟交接管（reparent+current 补位）；
## · C4 段申报（读法一严格申报制）：入场先接管后落位、无申报段回正初始被控者；
## · C5 索敌配置：场景导出注入 + 运行时增删即时生效（helper 通用入口）；
## · C6 索敌默认=玩家阵营组（现状等价回归锁）；
## · C7 拒接形态：空目标/树外目标/同体幂等。
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
	_check(not is_instance_valid(declared),
			"C4 旧被控者随未清段丢弃重建而释放（悬垂守卫前提形态）")
	_check(QuiverCharacterHelper.is_player_identity(hero)
			and shell2._camera != null and shell2._camera.is_current(),
			"C4 回正后判据/相机链完好（悬垂旧体未拖垮接管链）")
	shell2.queue_free()
	await _frames(3)


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
	var ok := _fails == 0 and _finished and _asserts >= 30
	print("════════ control-contract: %s ════（断言 %d，红 %d，完成旗=%s）"
			% ["PASS" if ok else "FAIL", _asserts, _fails, str(_finished)])
	get_tree().quit(0 if ok else 1)
