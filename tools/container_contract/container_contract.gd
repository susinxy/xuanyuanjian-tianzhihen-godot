extends Node

## 舞台容器契约（S2-M1-B1）：ChapterSession 语义（S 组）、壳切换（E 组）、
## 段检查点（D 组）、壳件（H 组）。运行：
## godot --headless --path . res://tools/container_contract/container_contract.tscn

const FIX_CHAPTER := "res://tools/container_contract/fixtures/chapter_fix.tscn"
const FIX_SEG_C := "res://tools/container_contract/fixtures/seg_light_c.tscn"

var _fails := 0
var _finished := false


func _ready() -> void:
	await _flow_session()
	await _flow_enter()
	await _flow_switch()
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
	_check(_lighting_matches_seg_c(shell), "E5 段入场光照色由壳复位")
	shell.queue_free()
	await _frames(6)


func _lighting_matches_seg_c(shell: ChapterShell) -> bool:
	var probe: StageContent = (load(FIX_SEG_C) as PackedScene).instantiate()
	var want: Color = probe.lighting_color
	probe.free()
	return shell.applied_lighting == want
