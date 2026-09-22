extends Node

## 舞台容器契约（S2-M1-B1）：ChapterSession 语义（S 组）、壳切换（E 组）、
## 段检查点（D 组）、壳件（H 组）。运行：
## godot --headless --path . res://tools/container_contract/container_contract.tscn

const FIX_CHAPTER := "res://tools/container_contract/fixtures/chapter_fix.tscn"
const FIX_SEG_C := "res://tools/container_contract/fixtures/seg_light_c.tscn"
const FIX_SEG_A := "res://tools/container_contract/fixtures/seg_gate_a.tscn"
## D1 行容差带：入口 y=地面顶线，角色碰撞体在原点下沿 ~20px，落位后首个
## 物理帧即被顶到静止位（实测 579.93，任何入场同款）——带宽由入口坐标推导。
const SETTLE_TOLERANCE := 24.0

var _fails := 0
var _finished := false
var _death_done := false   # D 流全序列旗（子协程炸尾防线，见 _flow_death 注）


func _ready() -> void:
	await _flow_session()
	await _flow_enter()
	await _flow_switch()
	await _flow_agg()
	await _flow_death()
	# 判例（4.7 探针实锤）：await 的子协程运行时炸掉后**父协程照常续跑**，
	# _finished 拦不住"子流尾段静默蒸发"——每流自带完成旗单独锁。
	_check(_death_done, "D 流全序列执行完成（子协程炸跳段防线）")
	_finished = true   # 全链末端才置位：早于任何后续流程会截断静默跳段防线
	_check(_finished, "全序列执行完成（协程静默中断防线）")
	print("════════ container-contract: %s ════════" % ("PASS" if _fails == 0 else "FAIL"))
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails += 1
	print("  %s: %s" % ["PASS" if ok else "FAIL", label])


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _flow_session() -> void:
	var s := ChapterSession.new()
	var got_flag: Array[StringName] = []
	s.flag_added.connect(func(id): got_flag.append(id))
	s.add_flag(&"key_lantern")
	s.add_flag(&"key_lantern")
	_check(s.has_flag(&"key_lantern") and got_flag.size() == 1,
			"S1 旗标幂等（信号只发一次）")
	_check(s.open_chest(&"chest_a") and not s.open_chest(&"chest_a")
			and s.is_chest_open(&"chest_a"), "S2 宝箱一次性语义")
	s.mark_cleared(&"seg_01")
	_check(s.is_cleared(&"seg_01") and not s.is_cleared(&"seg_02"),
			"S3 清场记录按段隔离")
	s.record_checkpoint(&"seg_02", &"gate")
	_check(s.checkpoint_segment() == &"seg_02" and s.checkpoint_entry() == &"gate",
			"S4 检查点记录段+入口名")


func _wait_until(pred: Callable, cap: int = 600) -> bool:
	for _i in cap:
		if pred.call():
			return true
		await get_tree().physics_frame
	return pred.call()


func _spar_count() -> int:
	var n := 0
	for x in get_tree().get_nodes_in_group("area2d:spar_enemy"):
		if x is QuiverCharacter:
			n += 1
	return n


func _flow_enter() -> void:
	var shell: ChapterShell = (load(FIX_CHAPTER) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(shell)
	await _frames(20)
	_check(shell.current_segment_id() == &"seg_a",
			"E1a 章节就绪自动进入首段（段内锁房刷怪由 E1b 实证）")
	var chen: QuiverCharacter = shell.playable
	# 发丝检测线对"瞬移跨越"不判交（Godot 面积监控按 tick 离散重合，扫掠路径
	# 不算——R6 落位后直跳 700 实测不触发即此引擎事实）：逐帧平移真实过线。
	for x in range(500, 701, 25):
		chen.global_position = Vector2(x, 600)
		await get_tree().physics_frame
	var spawned: bool = await _wait_until(func(): return _spar_count() == 1, 240)
	_check(spawned, "E1b 进段后三件套照常：跨线锁房+波次刷怪")
	shell.queue_free()
	await _frames(6)


func _flow_switch() -> void:
	var shell: ChapterShell = (load(FIX_CHAPTER) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(shell)
	await _frames(20)
	# E2 主动切换：摘挂+落位+玩家留存
	var chen: QuiverCharacter = shell.playable
	await shell.switch_segment(&"seg_b", &"default")
	_check(shell.current_segment_id() == &"seg_b"
			and chen.is_inside_tree() and _spar_count() == 0,
			"E2 切段：A 摘树/B 进树/玩家永驻且场上无敌残留")
	# R8/spec C4 落位屏蔽窗：切换同帧新段检测器应闭合，数物理帧后恢复
	var det_b := _first_detector(shell._current)
	_check(det_b != null and det_b.monitoring == false,
			"E2b 落位窗：新段检测器 monitoring 临时闭合（R8）")
	await _frames(4)
	_check(det_b != null and is_instance_valid(det_b) and det_b.monitoring == true,
			"E2c 落位窗：有界帧内恢复 monitoring")
	# E3 清场持久：回 A 前先标记清场 → 缓存复用（刷怪不复出）
	shell.session.mark_cleared(&"seg_b")
	await shell.switch_segment(&"seg_a", &"default")
	await shell.switch_segment(&"seg_b", &"default")
	_check(_spar_count() == 0,
			"E3 已清场段缓存复用：零复活（清场持久本体）")
	# E4 未清场丢弃：seg_a 被踢出后再进=全新（检测器可再触发）。
	# R7 判例：零宽线对瞬移跳变永不判交，必须逐帧扫线（同 E1b 模式）。
	await shell.switch_segment(&"seg_a", &"default")
	for x in range(500, 701, 25):
		chen.global_position = Vector2(x, 600)
		await get_tree().physics_frame
	var respawn: bool = await _wait_until(func(): return _spar_count() == 1, 240)
	_check(respawn, "E4 未清场丢弃重建：段重试可再触发（检测器自毁语义闭环）")
	# E5 光照复位：进带色段后壳记录画布色=段配置（brief 简化口径：不摸引擎合成）
	await shell.switch_segment(&"seg_c", &"default")
	await _frames(4)
	_check(_spar_count() == 0,
			"E5+ 切换强清：E4 残留敌经策略 A 无存活（静默窗+tree_exited 结算）")
	_check(_lighting_matches_seg_c(shell), "E5 段入场光照色由壳复位")
	shell.queue_free()
	await _frames(6)


func _lighting_matches_seg_c(shell: ChapterShell) -> bool:
	var probe: StageContent = (load(FIX_SEG_C) as PackedScene).instantiate()
	var want: Color = probe.lighting_color
	probe.free()
	return shell.applied_lighting == want


func _first_spar() -> QuiverCharacter:
	for x in get_tree().get_nodes_in_group("area2d:spar_enemy"):
		if x is QuiverCharacter:
			return x
	return null


func _first_detector(seg: StageContent) -> QuiverPlayerDetector:
	for n in seg.find_children("*", "", true, false):
		if n is QuiverPlayerDetector:
			return n
	return null


func _flow_agg() -> void:
	# E6 聚合链真覆盖（R10）：杀穿 spawner→段清广播→壳自动推进下一段。
	var shell: ChapterShell = (load(FIX_CHAPTER) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(shell)
	await _frames(20)
	var chen: QuiverCharacter = shell.playable
	# R7 判例：跨线必须逐帧扫（瞬移跳变零宽线永不判交）
	for x in range(500, 701, 25):
		chen.global_position = Vector2(x, 600)
		await get_tree().physics_frame
	var spawned: bool = await _wait_until(func(): return _spar_count() == 1, 240)
	_check(spawned, "E6a 前置：新段跨线刷怪")
	var cleared_ids: Array[StringName] = []
	shell.segment_cleared.connect(func(id): cleared_ids.append(id))
	# 真死链（container_prototype 判例）：血归零+带竖直分量 launch，浅杀不走演出
	var foe := _first_spar()
	foe.attributes.health_current = 0
	var data := QuiverKnockbackData.new(1200.0, CombatSystem.HurtTypes.HIGH,
			Vector2(0.866, -0.5))
	CombatSystem.apply_knockback(data, foe.attributes)
	var done: bool = await _wait_until(func(): return not cleared_ids.is_empty(), 600)
	_check(done and cleared_ids[0] == &"seg_a",
			"E6b 聚合链：段内全 spawner 完成 → segment_cleared(seg_a) 广播")
	var advanced: bool = await _wait_until(
			func(): return shell.current_segment_id() == &"seg_b", 600)
	_check(advanced, "E6c 自动推进：段清链把壳按顺序推进到 seg_b")
	shell.queue_free()
	await _frames(6)


func _one_shot_attack() -> QuiverAttackData:
	var a := QuiverAttackData.new()
	a.attack_damage = 50
	return a


## D 组（spec D4）：玩家死亡=段内重跑，不再弹地点死亡壳。
## 编排判例（评审轮 1 I4）：R12 双入块走"**清场缓存复用**"通道（=同批检测器，
## 假快照陷阱的成立前提），且必须在检测器 one-shot 自毁前跑——故置于首次扫线
## 之前；D2 靠"实例 id 变化+新实例检测器再触"锁真·丢弃重建，不搭 R12 的便车。
func _flow_death() -> void:
	var shell: ChapterShell = (load(FIX_CHAPTER) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(shell)
	await _frames(20)
	var chen: QuiverCharacter = shell.playable
	var probe: StageContent = (load(FIX_SEG_A) as PackedScene).instantiate()
	var entry_a: Vector2 = probe.entry_position(&"default")
	probe.free()
	# --- R12 屏蔽窗代际防线（趁检测器未消费）：开窗内二次入场若以"当前值"
	# 作快照会把 monitoring=false 当原值恢复=静默软锁。
	shell.session.mark_cleared(&"seg_a")
	shell.enter_segment(&"seg_a", &"default")      # 窗 #1（缓存复用=同批检测器）
	var det_mid := _first_detector(shell._current)
	_check(det_mid != null and not det_mid.monitoring,
			"R12a 落位窗内：monitoring 闭合")
	shell.enter_segment(&"seg_a", &"default")      # 开窗内再入（假快照陷阱）
	await _frames(8)
	var det_a := _first_detector(shell._current)
	_check(det_a != null and is_instance_valid(det_a) and det_a.monitoring,
			"R12b 双入窗内：检测器最终恢复 monitoring=true（假快照免疫）")
	shell.session.cleared_segments.erase(&"seg_a")  # 复原"未清场"（丢弃重建语义有效）
	var entry_inst_id: int = shell._current.get_instance_id()
	# --- 真死链：跨线引刷→血尽→knockout→Die→player_died→段重跑
	# R7 判例：跨线必须逐帧扫（瞬移跳变零宽线永不判交）
	for x in range(entry_a.x, 701, 25):
		chen.global_position = Vector2(x, entry_a.y)
		await get_tree().physics_frame
	var armed: bool = await _wait_until(func(): return _spar_count() == 1, 240)
	_check(armed, "D0 前置：跨线锁房刷怪（真死链有敌在场）")
	chen.attributes.health_current = 1
	CombatSystem.apply_damage(_one_shot_attack(), chen.attributes)  # 真死链
	chen.attributes.health_current = 0
	# 判例：GDScript lambda 对局部**标量**捕获是拷贝，lambda 内重新赋值不回传
	# （E6 的 cleared_ids.append 走的是数组引用通道才成立）——旗标走 Array 壳。
	var restarted := [false]
	shell.segment_restarted.connect(func(_w): restarted[0] = true)
	# 死亡链含玩家慢动作（time_scale=0.2 ⇒ 动画/腾空按 5× 物理帧数走，
	# 探针实测发射点在击杀后 ~1000 tick）+重跑静默窗 90f，封顶宽放至 1800
	var got_restart: bool = await _wait_until(func(): return restarted[0], 1800)
	_check(got_restart, "D0b 真死链终点 player_died → 段重跑广播（落位后才发）")
	await _frames(120)   # 落位后的稳定观察窗
	_check(chen.attributes.health_current == chen.attributes.health_max
			and absf(chen.global_position.x - entry_a.x) < 0.5
			and chen.global_position.y > entry_a.y - SETTLE_TOLERANCE
			and chen.global_position.y <= entry_a.y
			and shell.current_segment_id() == &"seg_a",
			"D1 死亡=段重跑：满血/回入口点/仍在本段")
	# I5 复活真身：动作脑精确回起点+输入窗重开（Die 冻死/连段窗带尸两案并锁）
	var sm := shell.playable.state_machine
	_check(sm.state_name == NodePath("Ground/Move/Idle") and sm.input_window_open,
			"D1b 段重跑后：状态机=Ground/Move/Idle 且输入窗已开")
	# I4 丢弃重建测真身：重跑后在场实例必须是新对象（≠扫线时的入场实例）
	_check(shell._current.get_instance_id() != entry_inst_id,
			"D1c 重跑=丢弃重建：段实例 id 已更换（敌复位的机制本体）")
	# --- D2：新实例的检测器应可再触发（此处 count 起点=0：敌已被重跑链清场）
	for x in range(entry_a.x, 701, 25):
		chen.global_position = Vector2(x, entry_a.y)
		await get_tree().physics_frame
	var spawn_again: bool = await _wait_until(func(): return _spar_count() == 1, 300)
	_check(spawn_again, "D2 未清场段重跑=敌复位（新实例检测器再触发）")
	# --- I2 并发锁：两链在途，最新意图接管落位，被顶掉的陈旧链不得回填
	var entered: Array[StringName] = []
	shell.segment_entered.connect(func(i): entered.append(i))
	shell.switch_segment(&"seg_b", &"default")     # 链 #1（不 await，留场在途）
	await _frames(10)
	shell.switch_segment(&"seg_a", &"default")     # 链 #2 顶掉链 #1
	var single: bool = await _wait_until(
			func(): return not entered.is_empty(), 600)
	await _frames(150)   # 盖过链 #1 最晚尾点（90f 静默+120f 清场结算上限）
	_check(single and entered == [&"seg_a"]
			and shell.current_segment_id() == &"seg_a",
			"D3 I2 并发切段：仅最新意图落位一次，陈旧链静默让位")
	# --- D4（F-1/spec D6）：强制推进=纯推进，绝不隐式复活（剧情跳段≠免费治疗）
	chen.attributes.health_current = 40   # 带残血过链
	var adv_why: Array[StringName] = []
	shell.segment_restarted.connect(func(w): adv_why.append(w))
	shell.force_advance_current(&"scripted")
	var adv_landed: bool = await _wait_until(
			func(): return shell.current_segment_id() == &"seg_b", 600)
	await _frames(30)   # 宽限盖过链尾信标，防"先到后改"竞态漏网
	_check(adv_landed and chen.attributes.health_current == 40
			and adv_why == [&"scripted"],
			"D4 强制推进：残血原样带段/信标恰一次（无 reset 满血无复活复位）")
	shell.queue_free()
	await _frames(6)
	_death_done = true
