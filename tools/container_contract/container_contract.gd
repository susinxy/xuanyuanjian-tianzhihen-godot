extends Node

## 舞台容器契约（S2-M1-B1）：壳切换（E 组）、段检查点（D 组）、
## 壳件五职责（H 组）。运行：
## godot --headless --path . res://tools/container_contract/container_contract.tscn
##
## B4-T1 迁移注记：原 S 组（ChapterSession 语义直测）移交 spell_save_contract
## （S6 兼容层腿，B4-T1 改判）——账本单例化后"新壳=新账"语义废除，
## 本套各建壳流水起点显式 GameSave.new_profile()（spec §2/§6 隔离规约）。
##
## B2.5/T5 主权迁移：chapter_fix 夹具经 playable_override 接缝把模板内嵌 chen
## 换成矩阵代管 test_actor（E/D/H 全流经 shell.playable 泛型消费，替身在场即
## 全套跑通；身份见证腿登记在 interact_contract X 流）。

## 替身产线 kit（preload 路径引用，全局类缓存判例与 interact 同款）
const Kit := preload("res://tools/matrix_runner/test_actor_kit.gd")

const FIX_CHAPTER := "res://tools/container_contract/fixtures/chapter_fix.tscn"
const FIX_SEG_C := "res://tools/container_contract/fixtures/seg_light_c.tscn"
const FIX_SEG_A := "res://tools/container_contract/fixtures/seg_gate_a.tscn"
## E7 炸窗自测子进程场景（Task 6 双保险第二层的靶面）
const FIX_E7_PROBE := "res://tools/container_contract/fixtures/e7_late_cb_probe.tscn"
## E8 孤儿链自测子进程场景（B2-T1：切换链在途时壳被删的靶面）
const FIX_E8_PROBE := "res://tools/container_contract/fixtures/e8_orphan_probe.tscn"
## resume-on-freed stderr 指纹稳定核（R7 定档；本机 4.7.1 Linux 实测不可达，
## 本断言作 Windows 侧回归锁，Linux 恒绿无害——承红见 E8c 结构守卫）
const E8_FREED_FINGERPRINT := "Resumed function"
## D1 行容差带：入口 y=地面顶线，角色碰撞体在原点下沿 ~20px，落位后首个
## 物理帧即被顶到静止位（实测 579.93，任何入场同款）——带宽由入口坐标推导。
const SETTLE_TOLERANCE := 24.0

var _fails := 0
var _finished := false
var _death_done := false   # D 流全序列旗（子协程炸尾防线，见 _flow_death 注）
var _kit_done := false     # H 流全序列旗（同款炸跳段防线）
var _e7_done := false      # E7 流全序列旗（同款防线）
var _orphan_done := false  # E8 流全序列旗（B2-T1 同款防线）


func _ready() -> void:
	# B4.5 测试卫生条款（spec §2）：影子落盘一律重定向 scratch，永不碰生产槽
	#（本套建壳链触泛信号=自动落盘源；scene runner 里 /root/SaveSystem 恒在场，
	# 取空即当场炸=响亮红，不静默跳闸）
	get_node_or_null(^"/root/SaveSystem").slot_path = "user://b45_container_scratch.json"
	# 替身门（消费铁律②）：夹具 ext_resource 引用 test_actor，缺席=夹具整体
	# 解析失败、各流经此即炸点——前置判 exists() 打可读红+处方即退，绝不
	# 代 runner 创建（创建归 run_matrix.sh 生命周期）。
	if not Kit.exists():
		print("  FAIL: test_actor 替身缺席——chapter_fix 等夹具经 playable_override "
				+ "依赖其主场景，不可解析（处方：bash tools/matrix_runner/"
				+ "run_matrix.sh --ensure-only 建好替身后复跑）")
		print("════════ container-contract: FAIL ════════")
		get_tree().quit(1)
		return
	await _flow_enter()
	await _flow_switch()
	await _flow_agg()
	await _flow_guard()
	_check(_e7_done, "E7 流全序列执行完成（协程静默中断防线）")
	await _flow_orphan()
	_check(_orphan_done, "E8 流全序列执行完成（协程静默中断防线）")
	await _flow_death()
	# 判例（4.7 探针实锤）：await 的子协程运行时炸掉后**父协程照常续跑**，
	# _finished 拦不住"子流尾段静默蒸发"——每流自带完成旗单独锁。
	_check(_death_done, "D 流全序列执行完成（子协程炸跳段防线）")
	await _flow_shellkit()
	_check(_kit_done, "H 流全序列执行完成（子协程炸跳段防线）")
	_finished = true   # 全链末端才置位：早于任何后续流程会截断静默跳段防线
	_check(_finished, "全序列执行完成（协程静默中断防线）")
	get_node_or_null(^"/root/SaveSystem").delete_save()   # B4.5 测试卫生：套尾删净 scratch 不过夜
	print("════════ container-contract: %s ════════" % ("PASS" if _fails == 0 else "FAIL"))
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails += 1
	print("  %s: %s" % ["PASS" if ok else "FAIL", label])


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


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
	GameSave.new_profile()   # B4-T1 隔离规约：建壳流水起点清账（账随进程不随壳）
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
	GameSave.new_profile()   # B4-T1 隔离规约：建壳流水起点清账
	var shell: ChapterShell = (load(FIX_CHAPTER) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(shell)
	await _frames(20)
	# E2 主动切换：摘挂+落位+玩家留存（switch 登记即返，等链落位——B2-T1 后
	# switch_segment 不再是协程，观察面从 await 完成改为落位轮询）
	var chen: QuiverCharacter = shell.playable
	shell.switch_segment(&"seg_b", &"default")
	await _wait_until(func(): return shell.current_segment_id() == &"seg_b", 600)
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
	shell.switch_segment(&"seg_a", &"default")
	await _wait_until(func(): return shell.current_segment_id() == &"seg_a", 600)
	shell.switch_segment(&"seg_b", &"default")
	await _wait_until(func(): return shell.current_segment_id() == &"seg_b", 600)
	_check(_spar_count() == 0,
			"E3 已清场段缓存复用：零复活（清场持久本体）")
	# E4 未清场丢弃：seg_a 被踢出后再进=全新（检测器可再触发）。
	# R7 判例：零宽线对瞬移跳变永不判交，必须逐帧扫线（同 E1b 模式）。
	shell.switch_segment(&"seg_a", &"default")
	await _wait_until(func(): return shell.current_segment_id() == &"seg_a", 600)
	for x in range(500, 701, 25):
		chen.global_position = Vector2(x, 600)
		await get_tree().physics_frame
	var respawn: bool = await _wait_until(func(): return _spar_count() == 1, 240)
	_check(respawn, "E4 未清场丢弃重建：段重试可再触发（检测器自毁语义闭环）")
	# E5 光照复位：进带色段后壳记录画布色=段配置（brief 简化口径：不摸引擎合成）
	shell.switch_segment(&"seg_c", &"default")
	await _wait_until(func(): return shell.current_segment_id() == &"seg_c", 600)
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
	GameSave.new_profile()   # B4-T1 隔离规约：建壳流水起点清账
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


## E7（Task 6，spike C2 双保险第二层）：锁房收口 tween 的 finished 迟到落在
## "清场缓存段 remove_child 保活"的出树房间上 → get_tree()==null 炸。
## SCRIPT ERROR 只存在于引擎进程 stderr，本进程内无从断言"无错"——故炸窗
## 由 fork 的 --headless 子进程（e7_late_cb_probe）走真实引擎事件流构造，
## 父进程拿子进程全输出做指纹判定：守卫前必真红（实测指纹=
## "Cannot call method 'get_nodes_in_group' on a null value" 回溯点名
## _clamp_players_into_room），守卫后绿；刻痕断言防"窗口没搭起来"的假绿。
## 捕获通道判例（4.7.1 实测）：OS.execute 的 output 数组在本环境恒空（连
## echo 都捕不到）——改走 shell 重定向到临时文件再读；OS.execute 实测阻塞
## 至子进程退出（不放心仍留有限轮询）。双平台：Windows 用户端同样可跑。
## （B2-T1 R5：执行/轮询本体提为共享 helper _run_probe_subprocess，
## E7a/E7b 两断言原文不动=该 helper 的逐位哨兵。）
func _flow_guard() -> void:
	var log_path := OS.get_temp_dir().path_join("xuanyuan_e7_probe.log")
	var texts: Array = await _run_probe_subprocess(
			FIX_E7_PROBE, log_path, log_path, "E7PROBE-DONE")
	var err: int = texts[3]
	var text: String = "%s\n%s" % [texts[0], texts[1]]
	var window := text.contains("E7PROBE-LOCKED true") \
			and text.contains("E7PROBE-DETACHED true")
	var done := text.contains("E7PROBE-DONE")
	_check(err == OK and window and done,
			"E7a 炸窗真实构造：锁房 tween 在途 + 缓存段摘树保活 + 子进程跑完")
	_check(done and not text.contains("_clamp_players_into_room"),
			"E7b finished 迟到回调在出树房间不再炸（子进程输出无收口函数指纹）")
	if not (window and done):
		print("──── E7 子进程现场（尾 2000 字）────\n", text.right(2000))
	_e7_done = true


## 探针子进程共享运行体（B2-T1 R5 自 E7 段提取；两流共用）。
## out_path==err_path 时走 E7 原形态 `2>&1` 合流；分写时两路各自重定向。
## 返回 [stdout 文本, stderr 文本, 落盘哨兵是否等到, OS.execute 错误码]；
## 临时文件读毕即清。有限轮询 10s 兜底（正常子进程退出首轮即中）。
func _run_probe_subprocess(target_scene: String, out_path: String,
		err_path: String, sentinel: String, max_frames: int = 600) -> Array:
	for p in [out_path, err_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	var inner := '"%s" --headless --path "%s" "%s" --quit-after 3600' % [
			OS.get_executable_path(),
			ProjectSettings.globalize_path("res://"), target_scene]
	var err := OK
	var redir: String
	var merged := out_path == err_path
	if merged:
		redir = ' 1>"%s" 2>&1' % out_path
	elif OS.get_name() == "Windows":
		redir = ' 1>"%s" 2>"%s"' % [out_path, err_path]
	else:
		redir = ' > "%s" 2> "%s"' % [out_path, err_path]
	if OS.get_name() == "Windows":
		err = OS.execute("cmd", ["/c", inner + redir],
				PackedStringArray(), false, false)
	else:
		err = OS.execute("/bin/sh", ["-c", inner + redir],
				PackedStringArray(), false, false)
	var out := ""
	var found := false
	for _i in max_frames:   # 有限轮询：等子进程落盘（正常首轮即中）
		out = FileAccess.get_file_as_string(out_path)
		if out.contains(sentinel):
			found = true
			break
		await get_tree().physics_frame
	var errt := out if merged else FileAccess.get_file_as_string(err_path)
	DirAccess.remove_absolute(out_path)
	if not merged:
		DirAccess.remove_absolute(err_path)
	return [out, errt, found, err]


## E8（B2-T1，终审 Issue 1）：切换链在途时壳被删=await-self 炸点收口锁。
## 三段判据：E8c 结构守卫（本体承红）——修复前 switch_segment 是壳协程，
## callv 动态调用返回在途 GDScriptFunctionState（≠null 即红）；收口后同步
## 登记+RefCounted 载体，返回 null。为何走 callv：裸直调在修复前后都编译
## 合法（D3 现例），静态取返回值在修复前是 parse error——动态通道是两侧
## 唯一合法观察窗。E8a/E8b 子进程对（e8_orphan_probe 靶面 + 共享 helper）：
## 壳在 90 帧静默窗正中删除、链孤儿化，子进程仍须跑完收口且不吐
## resume-on-freed 指纹。**Step 0 实探判词（Linux 4.7.1 headless）**：
## 修复前靶面全部静默死亡零输出（GDScriptInstance 析构先断开在途协程的
## 信号连接，godot 4.7 gdscript.cpp:2066-2079），"Resumed function" 指纹
## 在本平台不可达 → E8b 在 Linux 恒绿、仅作 Windows 侧回归锁（R7 定档）。
func _flow_orphan() -> void:
	# E8c：结构守卫（进程内动态调用，修复前必红）
	GameSave.new_profile()   # B4-T1 隔离规约：建壳流水起点清账
	var shell: ChapterShell = (load(FIX_CHAPTER) as PackedScene).instantiate()
	add_child(shell)
	await _frames(20)   # 让 _ready 进首段链跑完
	var r: Variant = shell.callv(&"switch_segment",
			[&"seg_b", &"default", &"", false, &""])
	_check(r == null, "E8c switch_segment 不再是壳协程（动态调用返回=%s）" % r)
	shell.queue_free()
	await _frames(6)
	# E8a/E8b：子进程靶面（stdout/stderr 分文件捕获）
	var tmp := OS.get_temp_dir()
	var texts: Array = await _run_probe_subprocess(FIX_E8_PROBE,
			tmp.path_join("xuanyuan_e8_out.txt"),
			tmp.path_join("xuanyuan_e8_err.txt"), "E8-DONE", 1200)
	var code: int = texts[3]
	var txt := String(texts[0])
	var errt := String(texts[1])
	_check(code == OK and txt.contains("E8-DONE"),
			"E8a 炸链真实构造：壳在切换窗中被删且子进程跑完（非假绿）")
	_check(not errt.contains(E8_FREED_FINGERPRINT),
			"E8b 在途链孤儿化不再 resume-on-freed（指纹=%s）" % E8_FREED_FINGERPRINT)
	if not txt.contains("E8-DONE"):
		print("──── E8 子进程现场（尾 2000 字）────\n", txt.right(2000))
	_orphan_done = true


func _one_shot_attack() -> QuiverAttackData:
	var a := QuiverAttackData.new()
	a.attack_damage = 50
	return a


## D 组（spec D4）：玩家死亡=段内重跑，不再弹地点死亡壳。
## 编排判例（评审轮 1 I4）：R12 双入块走"**清场缓存复用**"通道（=同批检测器，
## 假快照陷阱的成立前提），且必须在检测器 one-shot 自毁前跑——故置于首次扫线
## 之前；D2 靠"实例 id 变化+新实例检测器再触"锁真·丢弃重建，不搭 R12 的便车。
func _flow_death() -> void:
	GameSave.new_profile()   # B4-T1 隔离规约：建壳流水起点清账
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
	# 复原"未清场"（丢弃重建语义有效）：账本私有化后走销账门洞 erase_record
	# （B4-T1/D-T1-1——合法销账=record 对偶，不开裸字典口）
	shell.session.erase_record(shell.session.NS_CLEARED, &"seg_a")
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
	# --- D5（B2-T2 终裁）：船闸竞态——force 链在途 × 更晚死亡重跑顶位
	# 裁决（法源=终审 Issue 2 + spec §4 船闸竞态，2026-09-22 定档）：判清登记
	# 随"链赢落位"才落，被顶掉的陈旧链零副作用（严格=判清/落位/信标三件，reg+90
	# 战场强清除外；源段不背判清→死亡重跑走
	# 丢弃重建→不出现"缓存复用腿带进半战场"）。复用 D3 并发模板：
	# 第一意图=force_advance_current（携 seg_b 判清登记），第二意图=restart。
	var src_seg: StringName = shell.current_segment_id()   # = seg_b（D4 落位段）
	var race_whys: Array[StringName] = []
	shell.segment_restarted.connect(func(w): race_whys.append(w))
	shell.force_advance_current(&"race")     # 链 #1（判清登记按终裁悬置在链尾）
	await _frames(10)                          # 静默窗中：链 #1 在途未落位
	shell.restart_segment(&"death_race")      # 链 #2 顶掉链 #1（同段死亡重跑）
	var race_landed: bool = await _wait_until(
			func(): return not race_whys.is_empty(), 600)
	await _frames(30)   # 盖过链 #1 最晚尾点，防"顶位失败仍落位"竞态漏网
	_check(race_landed and race_whys == [&"death_race"]
			and shell.current_segment_id() == src_seg
			and shell.session.checkpoint_segment() == src_seg,
			"D5a 重跑链落位：checkpoint=本段入口，被顶 force 链零信标")
	_check(not shell.session.is_cleared(src_seg),
			"D5b 被顶掉的 force 链不把源段标 cleared（修复前必红）")
	# --- D5c 对照腿：无竞争 force 链判清照常随落位登记，再入走缓存复用
	# （实例 id 不变）——证明 b 非"永远无缓存"，成功路径未被搬移破坏。
	var seg_b_inst: int = shell._current.get_instance_id()
	shell.force_advance_current(&"legit")      # 独链：mark 必在 enter 前落
	var legit_landed: bool = await _wait_until(
			func(): return shell.current_segment_id() == &"seg_c", 600)
	await _frames(30)
	shell.switch_segment(&"seg_b", &"default")  # 判清段再入 → 缓存腿
	var back_landed: bool = await _wait_until(
			func(): return shell.current_segment_id() == &"seg_b", 600)
	await _frames(30)
	_check(legit_landed and back_landed
			and shell.session.is_cleared(src_seg)
			and shell._current.get_instance_id() == seg_b_inst,
			"D5c 对照：赢链判清落位后再入=缓存复用（实例 id 不变）")
	shell.queue_free()
	await _frames(6)
	_death_done = true


## H 组（T5 五职责齐平，spec D10/D11）：模板五壳件在位 + B7 冻结纪律容器版 +
## raw ESC 全链 + 检查点注册/回跳消费 + 章节终点语义 + set_playable 接口位。
## 注入判例（stage_contract A3 同源）：未处理输入流只收原始按键，有界轮询等落定。
func _flow_shellkit() -> void:
	GameSave.new_profile()   # B4-T1 隔离规约：建壳流水起点清账
	# 回跳消费真验前置：pending 预置为章节外层文件，壳 _ready 一次性吃掉
	GameEvents.pending_jump_stage = FIX_CHAPTER
	var shell: ChapterShell = (load(FIX_CHAPTER) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(shell)
	await _frames(20)
	_check(GameEvents.pending_jump_stage == "",
			"H1 地点回跳由壳 _ready 一次性消费（与 BaseStage 同规则）")
	# H2 检查点注册：(fix → 外层章节文件)，回跳目标可解析
	var hit := false
	for cp in GameEvents.get_checkpoints():
		if cp.stage_id == &"fix" and cp.scene_path == FIX_CHAPTER:
			hit = true
	_check(hit, "H2 章节检查点注册（fix→外层文件，B5 同形态）")
	# H3 五壳件在位（模板场景经 fixture 同实例通道带出）
	var pause_layer := shell.get_node_or_null("HudLayer/PauseLayer") as Control
	var pm := shell.get_node_or_null("HudLayer/PauseLayer/PauseMenu") as Control
	var ds := shell.get_node_or_null("HudLayer/PauseLayer/DeathScreen") as Control
	var endp := shell.get_node_or_null("HudLayer/StageEndPanel") as Control
	_check(pause_layer != null and pm != null and ds != null,
			"H3a PauseLayer/PauseMenu/DeathScreen 在位")
	_check(endp != null and endp.get_node_or_null("PanelBox/BackTitle") != null
			and endp.get_node_or_null("PanelBox/Replay") != null,
			"H3b StageEndPanel 两钮就位")
	_check(pause_layer != null and pause_layer.process_mode == Node.PROCESS_MODE_ALWAYS,
			"H3c PauseLayer=ALWAYS（B7 容器同款）")
	_check(endp != null and endp.process_mode == Node.PROCESS_MODE_ALWAYS
			and not endp.visible,
			"H3d 终点面板 ALWAYS+初始隐藏（冻结树里钮可响应——B7 锁容器版）")
	_check(pm != null and pm.process_mode == Node.PROCESS_MODE_ALWAYS
			and not pm.visible and not ds.visible,
			"H3e PauseMenu 自置 ALWAYS；pause/death 初始隐藏")
	# H4 GameHUD 上幕并跟手壳内 chen（组扫描通道与 base 同源，零胶水）
	var hud_frame := shell.get_node_or_null("HudLayer/GameHUD/Frame") as Control
	_check(hud_frame != null and hud_frame.visible, "H4 GameHUD 上幕并跟手 chen")
	# H5 raw ESC 全链：开→冻结；再按→关+解冻
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.device = -1
	esc.pressed = true
	# 4.7 判例：同一事件对象同帧重复投递 unsafe——每次投 duplicate 副本
	Input.parse_input_event(esc.duplicate())
	var opened: bool = await _wait_until(
			func() -> bool: return pm.visible and get_tree().paused, 240)
	_check(opened, "H5a raw ESC → 暂停壳开+树冻结（注入事件在冻结树抵达 ALWAYS 壳）")
	esc.pressed = false
	Input.parse_input_event(esc.duplicate())
	await _frames(1)
	esc.pressed = true
	Input.parse_input_event(esc.duplicate())
	var closed: bool = await _wait_until(
			func() -> bool: return not pm.visible and not get_tree().paused, 240)
	_check(closed, "H5b 再按 ESC → 关壳+解冻（末尾未冻结防线）")
	# H5c B7 冻结所有权容器版：他人冻结态（模拟终点面板/死亡壳持有）ESC 不叠开
	get_tree().paused = true
	esc.pressed = false
	Input.parse_input_event(esc.duplicate())
	await _frames(1)
	esc.pressed = true
	Input.parse_input_event(esc.duplicate())
	await _frames(30)
	_check(not pm.visible, "H5c 他人冻结态 ESC 不叠开（冻结所有权 I-1 容器版）")
	get_tree().paused = false
	await _frames(2)
	# H6 终点链（E6 廉价通道：session 判清 + switch 链走到终点段）
	var finished: Array[String] = []
	shell.chapter_finished.connect(func(): finished.append("f"))
	var failed: Array[String] = []
	shell.segment_advance_failed.connect(func(r): failed.append(r))
	shell.session.mark_cleared(&"seg_a")
	shell.switch_segment(&"seg_b", &"default")
	await _wait_until(func(): return shell.current_segment_id() == &"seg_b", 600)
	shell.session.mark_cleared(&"seg_b")
	shell.switch_segment(&"seg_c", &"default")
	await _wait_until(func(): return shell.current_segment_id() == &"seg_c", 600)
	_check(shell.current_segment_id() == &"seg_c", "H6a 三段夹具按序推进到终点段")
	# 终点强推（未判清）：F-2 只发失败、不判清、不发章节完成
	shell.force_advance_current(&"h6")
	var neg: bool = await _wait_until(func(): return not failed.is_empty(), 240)
	_check(neg and failed.size() == 1 and finished.is_empty()
			and not shell.session.is_cleared(&"seg_c"),
			"H6b 终点强推未判清：仅 advance_failed（不伪判清不广播完成）")
	# 终点段清且无后继 → chapter_finished 恰一次（B7 过场批消费口）
	shell.session.mark_cleared(&"seg_c")
	shell.switch_segment()
	await _frames(6)
	_check(failed.size() == 2 and finished.size() == 1,
			"H6c 终点段清+无后继 → advance_failed 且 chapter_finished 恰一次")
	shell.switch_segment()
	await _frames(6)
	_check(finished.size() == 1, "H6d 重复终点推不重发（chapter_finished 闩锁）")
	# H7 D11 换角接口位：null/缺身份组拒换；带组仅换引用（迁移留 D2 批）
	var errs: Array[String] = []
	shell.chapter_error.connect(func(m): errs.append(m))
	var before: QuiverCharacter = shell.playable
	shell.set_playable(null)
	var stranger := QuiverCharacter.new()
	shell.set_playable(stranger)
	_check(errs.size() == 2 and shell.playable == before,
			"H7a set_playable 空目标/缺 area2d:player → chapter_error 拒换")
	stranger.free()
	var ally := QuiverCharacter.new()
	ally.add_to_group("area2d:player")
	shell.set_playable(ally)
	_check(shell.playable == ally, "H7b 带身份组目标 → 换引用（换人实现留 D2 批）")
	shell.playable = before   # 还原引用再拆场（防 dangling 观察面）
	ally.free()
	shell.queue_free()
	await _frames(6)
	GameEvents.reset_session()
	_check(GameEvents.get_checkpoints().is_empty(), "H8 会话自洁（测试收尾清表）")
	_kit_done = true
