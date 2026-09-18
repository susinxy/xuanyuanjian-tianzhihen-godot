extends Node

## stage-contract 契约套（S1 矩阵登记项）：A 段=流程壳三件套（标题/暂停/死亡）
## 的结构与开关契约；B 段（T3）=base_stage 父骨架结构/检查点注册/波次聚合/
## 死亡转场/实例化回跳语义。C 段（T5 全流程，含跳转钮按压→真实换场景）后续续加
## ——A/B 段不按压任何跳转钮（终点面板钮同理，STAGE_A_PATH 待 T5 落地）。
## 运行：godot --headless --path . res://tools/stage_contract/stage_contract.tscn

const TITLE := "res://ui/menus/title_screen.tscn"
const PAUSE := "res://ui/menus/pause_menu.tscn"
const DEATH := "res://ui/menus/death_screen.tscn"
const BASE_STAGE := "res://scenes/base/base_stage.tscn"
const FIXTURE_PROBE := "res://tools/stage_contract/fixtures/stage_probe.tscn"

## 断言全数（防线：GDScript 运行时报错只中断当前函数、调用方继续——
## 缺壳时整段断言被静默跳过仍会汇总 PASS；跑不满此数=有断言被吞）。
## 计数在"跑满"这条自身计入前比对：A 段流内 35 + B 段流内 48 + 全序列 1 = 84
const EXPECTED_ASSERTS := 84

var _fails := 0
var _finished := false
var _checks := 0

var _title: Control
var _pause: Control
var _death: Control
var _stage: BaseStage
var _open_count := 0
var _closed_count := 0


func _ready() -> void:
	await _flow()
	_check(_finished, "全序列执行完成（协程静默中断防线）")
	_check(_checks == EXPECTED_ASSERTS,
			"断言全数跑满 %d/%d（防分段静默跳过假绿）" % [_checks, EXPECTED_ASSERTS])
	print("════════ stage-contract: %s ════════" % ("PASS" if _fails == 0 else "FAIL"))
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print("  %s: %s" % ["PASS" if ok else "FAIL", label])


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _flow() -> void:
	_a1_structure()
	await _a2_open_close()
	await _a3_esc_chain()
	_a4_entries()
	_a5_death_rebuild()
	_a6_latest_checkpoint()
	await _b1_structure()
	await _b2_checkpoint()
	await _b3_aggregation()
	await _b4_death_forward()
	await _b5_fixture_jump()
	await _b7_end_panel()
	_finished = true


## A1 三壳可实例化；根 Control + process_mode=ALWAYS + 三层子节点齐；
## 初始可见性：pause/death 隐藏，title 可见（标题即落地页）
func _a1_structure() -> void:
	_title = (load(TITLE) as PackedScene).instantiate()
	_pause = (load(PAUSE) as PackedScene).instantiate()
	_death = (load(DEATH) as PackedScene).instantiate()
	add_child(_title)
	add_child(_pause)
	add_child(_death)
	for shell in [_title, _pause, _death]:
		_check(shell is Control, "A1 %s 根类型 Control" % shell.name)
		_check(shell.process_mode == Node.PROCESS_MODE_ALWAYS,
				"A1 %s process_mode=ALWAYS（暂停态下壳仍收输入）" % shell.name)
		for layer in ["BgLayer", "DecoLayer", "ContentLayer"]:
			_check(shell.get_node_or_null(layer) != null, "A1 %s 含 %s" % [shell.name, layer])
	_check(not _pause.visible, "A1 pause 初始隐藏")
	_check(not _death.visible, "A1 death 初始隐藏")
	_check(_title.visible, "A1 title 初始可见")


## A2 open/close 信号与树冻结收口：open→paused=true+menu_opened×1；close→归零+menu_closed×1
func _a2_open_close() -> void:
	_pause.menu_opened.connect(func(): _open_count += 1)
	_pause.menu_closed.connect(func(): _closed_count += 1)
	_pause.open_menu()
	_check(get_tree().paused, "A2 open_menu → 树冻结")
	_check(_open_count == 1 and _closed_count == 0, "A2 menu_opened 恰 1 次")
	_pause.close_menu()
	_check(not get_tree().paused, "A2 close_menu → 树解冻")
	_check(_closed_count == 1, "A2 menu_closed 恰 1 次")


## A3 ESC 全链路：仓库头则——未处理输入流只收原始按键事件，故注入真 InputEventKey。
## 真机教训（2026-09-18）：parse_input_event 注入的事件排到**下一次 OS 事件泵**
## 才进场，headless 无帧率上限+物理补帧使"固定 N 拍 physics_frame"不可靠，
## 故用有界轮询等待状态落定（超时=断言 FAIL，不挂死）。
func _a3_esc_chain() -> void:
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.device = -1
	esc.pressed = true
	# 4.7 引擎警告"同一事件对象同帧重复投递 unsafe"（T2 遗留噪音，T3 清理）：
	# 每次投递用 duplicate 副本，源 esc 只作模板
	Input.parse_input_event(esc.duplicate())
	var opened := await _wait_state(func() -> bool: return _pause.visible and get_tree().paused)
	_check(opened, "A3 ESC 第一按 → 开壳+冻结")
	esc.pressed = false
	Input.parse_input_event(esc.duplicate())
	await _frames(1)
	esc.pressed = true
	Input.parse_input_event(esc.duplicate())
	var closed := await _wait_state(func() -> bool: return not _pause.visible and not get_tree().paused)
	_check(closed, "A3 ESC 第二按 → 关壳+解冻（末尾未冻结防线）")


func _wait_state(cond: Callable, max_frames := 240) -> bool:
	for _i in max_frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


## A4 add_entry 计数与 disabled 态（读条钮=数据驱动占位，不点击）
func _a4_entries() -> void:
	var pc: VBoxContainer = _pause.get_node("ContentLayer")
	_check(pc.get_child_count() == 4, "A4 pause 条目=4（实际 %d）" % pc.get_child_count())
	var tc: VBoxContainer = _title.get_node("ContentLayer")
	_check(tc.get_child_count() == 3, "A4 title 条目=3（实际 %d）" % tc.get_child_count())
	var load_btn := tc.get_child(1) as Button
	var start_btn := tc.get_child(0) as Button
	_check(load_btn != null and load_btn.disabled, "A4 title 读档钮 disabled 占位")
	_check(start_btn != null and not start_btn.disabled, "A4 title 开始钮可用")


## A5 死亡壳被动重建：open 时从 GameEvents 清旧再生成（新→旧），末条固定回标题；
## 全程不按压（跳转=真实换场景，归 C 段/T5 验）。
## 注：T1 add_checkpoint 为"摘旧追新+append"，数组尾部=最新访问，渲染取逆。
func _a5_death_rebuild() -> void:
	GameEvents.add_checkpoint(&"probe_a", "res://tools/stage_contract/_fake_a.tscn")
	GameEvents.add_checkpoint(&"probe_b", "res://tools/stage_contract/_fake_b.tscn")
	GameEvents.add_checkpoint(&"probe_a", "res://tools/stage_contract/_fake_a2.tscn")
	_death.open_screen()
	var dc: VBoxContainer = _death.get_node("ContentLayer")
	_check(dc.get_child_count() == 3, "A5 条目=2 检查点+1 回标题（实际 %d）" % dc.get_child_count())
	var c0 := dc.get_child(0) as Button
	var c1 := dc.get_child(1) as Button
	var c2 := dc.get_child(2) as Button
	_check(c0 != null and c0.text == "probe_a", "A5 新→旧：首条=probe_a（重入后最新）")
	_check(c1 != null and c1.text == "probe_b", "A5 新→旧：次条=probe_b")
	_check(c2 != null and c2.text == "返回标题", "A5 末条固定=返回标题")
	_death.close_screen()
	# 二次开合不累积残留（清空重建契约）
	_death.open_screen()
	_check(dc.get_child_count() == 3, "A5 二次 open 仍 3 条（无叠加残留）")
	_death.close_screen()
	GameEvents.reset_session()
	_check(GameEvents.get_checkpoints().is_empty(), "A5 收尾清会话（测试自洁）")


## A6 回跳取序（T2 裁决）：注册表旧→新，最新在尾——pause"回本地点入口"与
## death 可见首条（A5 锁）同源于 cps.back()；不按压，只核对目标读径
func _a6_latest_checkpoint() -> void:
	GameEvents.add_checkpoint(&"probe_old", "res://tools/stage_contract/_fake_old.tscn")
	GameEvents.add_checkpoint(&"probe_new", "res://tools/stage_contract/_fake_new.tscn")
	var latest: Dictionary = _pause._latest_checkpoint()
	_check(latest.scene_path == "res://tools/stage_contract/_fake_new.tscn",
			"A6 pause 跳转目标=注册表尾部（最新）")
	GameEvents.reset_session()


## B 段共享桩：计数替身房——覆写 setup_after_fight_room 记录调用次数
## （相机缺席时真身会 push_error"无有效相机"，测试输出必须零噪音）
class RoomProbe:
	extends QuiverFightRoom
	var setup_calls := 0

	func setup_after_fight_room() -> void:
		setup_calls += 1


## B1 base_stage 节点树契约：直载可实例化；约定子树路径全可寻址；
## PauseLayer=ALWAYS(3)；pause/death/终点面板初始隐藏；终点面板两钮就位
func _b1_structure() -> void:
	_stage = (load(BASE_STAGE) as PackedScene).instantiate()
	# 裸骨架在 _scene_path 两分支下都解析成节点路径（探针实证=引擎限制，
	# 外层文件语义由 B5 锁）；B 段各实例 stage_id 一律入树前设好，
	# 走 _ready 自动注册腿且零守卫警告
	_stage.stage_id = &"t_base"
	add_child(_stage)
	await _frames(2)
	_check(_stage is BaseStage, "B1 根脚本类型 BaseStage")
	var paths := [
		"Background", "Background/Ground", "Level", "Level/Characters",
		"Level/Objects", "Level/Collisions", "Ambient", "Ambient/CanvasModulate",
		"Foreground", "FightRooms", "HudLayer", "HudLayer/GameHUD",
		"HudLayer/PauseLayer", "HudLayer/PauseLayer/PauseMenu",
		"HudLayer/PauseLayer/DeathScreen", "HudLayer/StageEndPanel",
		"HudLayer/StageEndPanel/PanelBox", "HudLayer/StageEndPanel/PanelBox/BackTitle",
		"HudLayer/StageEndPanel/PanelBox/Replay",
	]
	for p in paths:
		_check(_stage.get_node_or_null(p) != null, "B1 路径可寻址 %s" % p)
	var pause_layer := _stage.get_node("HudLayer/PauseLayer") as Control
	_check(pause_layer.process_mode == Node.PROCESS_MODE_ALWAYS,
			"B1 PauseLayer=ALWAYS(3)（裁决#6 值语义；WHEN_PAUSED 实为 1）")
	_check(not _stage._pause_menu.visible, "B1 pause 初始隐藏")
	_check(not _stage._death_screen.visible, "B1 death 初始隐藏")
	_check(not _stage._end_panel.visible, "B1 终点面板初始隐藏")


## B2 进地点注册检查点：_ready 即以 (stage_id, _scene_path()) 入注册表；
## 空 stage_id 走 GameEvents 守卫拒录腿（全套件唯一预期内警告一行）
func _b2_checkpoint() -> void:
	var cps: Array[Dictionary] = GameEvents.get_checkpoints()
	var found := false
	for cp in cps:
		if cp.stage_id == &"t_base" and cp.scene_path == str(_stage.get_path()):
			found = true
	_check(found, "B2 _ready 自动注册腿：(t_base, 裸骨架解析径) 入表")
	# 守卫腿真验：空 id 再注册应被拒且 push_warning（噪音控制：仅此一处）
	var before: int = GameEvents.get_checkpoints().size()
	GameEvents.add_checkpoint(&"", "res://x.tscn")
	_check(GameEvents.get_checkpoints().size() == before, "B2 空 stage_id 被守卫拒录")
	_check(GameEvents.pending_jump_stage == "", "B2 直载未命中 → pending 不被误消费（消费真验在 B5）")


## B3 波次聚合：空 FightRooms 不建档；检测器 paths_enemy_spawners 导出被收编；
## 任一 spawner 未完成→不解锁；全部完成→setup_after_fight_room 恰 1 次+room_cleared
func _b3_aggregation() -> void:
	_check(_stage._rooms.is_empty(), "B3 空 FightRooms → 聚合表空")
	_stage.queue_free()
	await _frames(2)
	GameEvents.reset_session()
	_stage = (load(BASE_STAGE) as PackedScene).instantiate()
	_stage.stage_id = &"t_base"
	add_child(_stage)
	await _frames(2)
	var room := RoomProbe.new()
	room.name = "RoomProbe"
	_stage.get_node("FightRooms").add_child(room)
	var sp1 := QuiverEnemySpawner.new()
	sp1.name = "Spawner1"
	room.add_child(sp1)
	var sp2 := QuiverEnemySpawner.new()
	sp2.name = "Spawner2"
	room.add_child(sp2)
	var det := QuiverPlayerDetector.new()
	det.name = "PlayerDetector"
	det.path_fight_room = NodePath("..")
	det.paths_enemy_spawners = [NodePath("../Spawner1"), NodePath("../Spawner2")]
	room.add_child(det)  # 最后入树：_ready 自接线时兄弟节点已全部就位
	_stage._collect_rooms()
	var entry: Dictionary = _stage._rooms.get(room.get_path(), {})
	_check(entry.get("spawners", []).size() == 2,
			"B3 检测器导出收编 2 生成器（实际 %d）" % entry.get("spawners", []).size())
	var cleared_ids: Array[StringName] = []
	var spy := func(rid: StringName): cleared_ids.append(rid)
	GameEvents.room_cleared.connect(spy)
	sp2.is_completed = true
	sp1.all_waves_completed.emit()  # sp2 已完成、sp1 未完成 → 不许解锁
	await _frames(2)
	_check(room.setup_calls == 0, "B3 部分完成 → 不解锁")
	_check(cleared_ids.is_empty(), "B3 部分完成 → 无 room_cleared")
	sp1.is_completed = true  # 模拟真信标语义：all_waves_completed 只在自身完成后发
	sp2.all_waves_completed.emit()  # 全完成 → 解锁恰一次
	await _frames(2)
	_check(room.setup_calls == 1, "B3 全部完成 → setup_after_fight_room 恰 1 次")
	_check(cleared_ids == [&"RoomProbe"], "B3 room_cleared 载荷=房名")
	GameEvents.room_cleared.disconnect(spy)
	_stage.queue_free()
	_stage = null
	await _frames(2)
	GameEvents.reset_session()


## B4 死亡转交：player_died → 冻结树 + DeathScreen 开机（列表=t_base 检查点
## +回标题）；close 解冻收口；暂停壳在死亡流程后仍可开关（导航不变量烟雾）
func _b4_death_forward() -> void:
	_stage = (load(BASE_STAGE) as PackedScene).instantiate()
	_stage.stage_id = &"t_base"
	add_child(_stage)
	await _frames(2)
	Events.player_died.emit()
	var shown := await _wait_state(func() -> bool:
		return _stage._death_screen.visible and get_tree().paused)
	_check(shown, "B4 player_died → death 可见 + 树冻结")
	var dc: VBoxContainer = _stage.get_node("HudLayer/PauseLayer/DeathScreen/ContentLayer")
	_check(dc.get_child_count() == 2,
			"B4 死亡列表=t_base+回标题（实际 %d）" % dc.get_child_count())
	_stage._death_screen.close_screen()
	await _frames(2)
	_check(not get_tree().paused, "B4 close_screen 解冻收口（B 段收尾不欠冻结）")
	_stage._pause_menu.open_menu()
	_check(_stage._pause_menu.visible and get_tree().paused, "B4 死亡流程后暂停仍可开（烟雾）")
	_stage._pause_menu.close_menu()
	await _frames(2)
	_check(not get_tree().paused, "B4 暂停开→关复原（末尾未冻结防线）")


## B5 实例化根回跳语义（T5 正式关卡=base_stage 实例的预演）：经 fixtures/
## stage_probe.tscn（根 instance + stage_id 覆写）；场景树内实例化根的
## scene_file_path=外层文件（探针实证，current_scene 非自）→ 检查点注册指向
## 可跳转的完整地点文件；pending_jump_stage 命中该路径时被实例 _ready 一次性消费
func _b5_fixture_jump() -> void:
	# 裁决#3 原令 change_scene_to_file——4.7 探针实证 runner 自身就是
	# current_scene，换场=当场释放自己（后续 await 全灭）；等价复刻：
	# 实例挂 root + current_scene 指针改指（_ready 正常触发，语义同真换场）
	GameEvents.pending_jump_stage = FIXTURE_PROBE
	var scene := (load(FIXTURE_PROBE) as PackedScene).instantiate()
	get_tree().root.add_child(scene)
	await _frames(2)
	get_tree().current_scene = scene
	_check(scene is BaseStage and is_instance_valid(scene), "B5 实例化根就位且为 BaseStage")
	_check(scene.scene_file_path == FIXTURE_PROBE,
			"B5 场景树内实例化根 scene_file_path=外层文件（实际 %s）" % scene.scene_file_path)
	_check(scene.stage_id == &"probe", "B5 覆写 stage_id=probe 生效")
	var cps: Array[Dictionary] = GameEvents.get_checkpoints()
	var hit := false
	for cp in cps:
		if cp.stage_id == &"probe" and cp.scene_path == FIXTURE_PROBE:
			hit = true
	_check(hit, "B5 检查点按外层文件注册（回跳可解析）")
	_check(GameEvents.pending_jump_stage == "", "B5 pending_jump_stage 落位即消费")
	_check(scene._end_panel.get_node("PanelBox/BackTitle") != null, "B5 实例内终点钮就位")
	get_tree().current_scene = self
	scene.free()
	GameEvents.reset_session()


## B7 终点面板冻结树活性（评审轮1 死锁修复闭环）：_show_end_panel 冻结全树，
## 面板若继承不到 ALWAYS 则两钮 pressed 永闸=不可解软锁。三点+钮可用性断言；
## 真转场按压归 T5 C 段（runner=current_scene 换场自毁雷，B5 注释在案）
func _b7_end_panel() -> void:
	_stage = (load(BASE_STAGE) as PackedScene).instantiate()
	_stage.stage_id = &"t_base"
	add_child(_stage)
	await _frames(2)
	_stage.ends_after_last_room = true
	_stage._show_end_panel()
	_check(_stage._end_panel.visible, "B7 终点面板可见")
	_check(get_tree().paused, "B7 冻结树落位")
	_check(_stage._end_panel.process_mode == Node.PROCESS_MODE_ALWAYS,
			"B7 面板 process_mode=ALWAYS（冻结树里钮可响应——死锁修复锁）")
	var back := _stage._end_panel.get_node("PanelBox/BackTitle") as Button
	_check(back != null and not back.disabled, "B7 返回标题钮就位可用")
	get_tree().paused = false
	_stage.queue_free()
	_stage = null
	await _frames(2)
	GameEvents.reset_session()
