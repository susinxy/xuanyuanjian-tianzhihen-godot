extends Node

## E7 子进程自测（Task 6，C2 双保险第二层的靶面）：复刻 spike C2 "在途 Tween
## 孤儿"炸点——锁房 tween 在途时切段，清场缓存段走 remove_child 保活腿（房间
## 出树但不死），tween.finished 迟到回调打在 get_tree()==null 的出树节点上。
## 判分在父侧：container_contract 用 OS.execute 捕获本子进程 stderr 指纹
## （守卫前必红=有 _clamp_players_into_room 的 SCRIPT ERROR，守卫后绿）。
## 本脚本只负责：构造真实炸窗（走引擎事件流，不做构造必绿的直调）+ 前提
## 刻痕（父侧据此识别"窗口未成立"的假绿）+ 哨兵收尾。

const FIX_CHAPTER := "res://tools/container_contract/fixtures/chapter_fix.tscn"


func _ready() -> void:
	# B4.5 测试卫生条款（spec §2）：子进程建壳触泛信号=影子落盘源，与父套同槽
	# 重定向 scratch（父侧 OS.execute 阻塞收尸，父套尾 delete_save 一并删净）
	get_node_or_null(^"/root/SaveSystem").slot_path = "user://b45_container_scratch.json"
	await _run()
	print("E7PROBE-DONE")
	get_tree().quit(0)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _run() -> void:
	var shell: ChapterShell = (load(FIX_CHAPTER) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(shell)
	await _frames(20)
	var chen: QuiverCharacter = shell.playable
	# 预设判清：摘段腿走"缓存保活"（房间出树不死=迟到回调的活靶）
	shell.session.mark_cleared(&"seg_a")
	# R7 判例：跨线逐帧扫（瞬移跳变零宽线永不判交）→ 检测器锁房，
	# delimitate_room 发出 0.8s(≈48 物理帧) tween 在途
	for x in range(500, 651, 25):
		chen.global_position = Vector2(x, 600)
		await get_tree().physics_frame
	var cam := get_tree().root.get_camera_2d() as QuiverLevelCamera
	var in_flight := cam != null and cam._tween != null and cam._tween.is_running()
	print("E7PROBE-LOCKED %s" % in_flight)
	if not in_flight:
		return   # 窗口未构造（锁房没发生）——父侧按 LOCKED 刻痕判假绿并现场
	# 直调 enter_segment = 绕过 switch 的 90 帧静默窗（一层保险故意不走，
	# 本探针专打二层）；壳公开 API，非白盒手术
	shell.enter_segment(&"seg_b", &"default")
	var cached: StageContent = shell._instances.get(&"seg_a")
	var room := cached.get_node_or_null("Room1") as QuiverFightRoom
	print("E7PROBE-DETACHED %s" % (room != null and is_instance_valid(room)
			and not room.is_inside_tree()))
	# 盖过 tween 尾点：finished 迟到落在出树活房间上（守卫前=炸点）
	await _frames(90)
