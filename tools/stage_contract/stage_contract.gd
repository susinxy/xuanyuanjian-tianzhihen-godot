extends Node

## stage-contract 契约套（S1 矩阵登记项）：A 段=流程壳三件套（标题/暂停/死亡）
## 的结构与开关契约；B 段（T3）=base_stage 父骨架结构/检查点注册/波次聚合/
## 死亡转场/实例化回跳语义。C 段（T5 全流程，含跳转钮按压→真实换场景）后续续加
## C 段（T5）=两个真实参考地点的全流程环：换场存活 runner、锁房、波次聚合
## 解锁、跨地点 StageExit 真转场、清场终点面板、真死链→死亡界面→检查点回跳。
## 运行：godot --headless --path . res://tools/stage_contract/stage_contract.tscn

const TITLE := "res://ui/menus/title_screen.tscn"
const PAUSE := "res://ui/menus/pause_menu.tscn"
const DEATH := "res://ui/menus/death_screen.tscn"
const BASE_STAGE := "res://scenes/base/base_stage.tscn"
const FIXTURE_PROBE := "res://tools/stage_contract/fixtures/stage_probe.tscn"
const STAGE_A := "res://scenes/stages/ref/stage_ref_a.tscn"
const STAGE_B := "res://scenes/stages/ref/stage_ref_b.tscn"

## 断言全数（防线：GDScript 运行时报错只中断当前函数、调用方继续——
## 缺壳时整段断言被静默跳过仍会汇总 PASS；跑不满此数=有断言被吞）。
## 计数在"跑满"这条自身计入前比对：A 段流内 35 + B 段流内 48 + C 段 27 + 全序列 1 = 111
##（C 段实测 27：C7 同场景重载修复给 restored/consumed 拆了独立等待断言）
const EXPECTED_ASSERTS := 111

var _fails := 0
var _finished := false
var _checks := 0

var _title: Control
var _pause: Control
var _death: Control
var _stage: BaseStage
var _open_count := 0
var _closed_count := 0
var _c_room_cleared := 0
var _c_stage_exited := 0


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
	await _flow_c()
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


### -----------------------------------------------------------------------------------------------
### C 段（T5）：真实地点全流程环
### -----------------------------------------------------------------------------------------------

## 轮询直到条件成立（换场含转场淡入淡出，用 process_frame；上限防挂死）
func _wait_until(cond: Callable, cap_frames: int) -> bool:
	for _i in cap_frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _cs() -> Node:
	return get_tree().current_scene


func _stage_cam() -> Camera2D:
	return _cs().get_node("Level/Characters/Chen/LevelCamera") as Camera2D


func _stage_chen() -> QuiverCharacter:
	return _cs().get_node("Level/Characters/Chen") as QuiverCharacter


## 计数目标式清场（防 flaky：死亡演出链 起飞+弹地+Die 动画总时长远超单轮帧预算，
## 固定循环数会随机器节奏失败——按目标计数轮询，kill 与等待交替）
func _clear_until(target: int) -> bool:
	for _round in 40:
		if _c_room_cleared >= target:
			return true
		_kill_spars()
		var ok: bool = await _wait_until(func():
				return _c_room_cleared >= target, 40)
		if ok:
			return true
	return _c_room_cleared >= target

func _kill_spars() -> void:
	# 真死链（非数值清零浅杀）：扣血+致死最后一击强飞→弹地→Die 动画→离场。
	# 教训入档：只设 health=0 敌人不会走死亡演出，spawner 的 tree_exited await
	# 会挂到场景 teardown 才放行——真实击杀链路才是本契约要验的东西。
	for n in get_tree().get_nodes_in_group("area2d:spar_enemy"):
		if n is QuiverCharacter:
			var body := n as QuiverCharacter
			# 血要归零才走 die 分支；向量必须带竖直分量——纯水平 launch 会
			# 立刻触地进 Bounce（探针尸检实证，勿再踩）
			body.attributes.health_current = 0
			var data := QuiverKnockbackData.new(1200.0, CombatSystem.HurtTypes.HIGH,
					Vector2(0.866, -0.5))
			CombatSystem.apply_knockback(data, body.attributes)


func _flow_c() -> void:
	GameEvents.room_cleared.connect(func(_id): _c_room_cleared += 1)
	GameEvents.stage_exited.connect(func(_id): _c_stage_exited += 1)

	# C0 存活化：把 runner 从"可被换场释放的场景根"升为 root 直属，
	# 并让 current_scene 先指向替身（否则 change_scene_to_file 释放本 runner=自毁）
	# 注意：remove_child 后本节点瞬间离树 get_tree()=null，树引用必须先取
	var tree := get_tree()
	var decoy := Node.new()
	decoy.name = &"SceneDecoy"
	tree.root.add_child(decoy)
	tree.current_scene = decoy
	get_parent().remove_child(self)
	tree.root.add_child(self)

	# —— C1 进地点 A ——
	get_tree().change_scene_to_file(STAGE_A)
	var arrived: bool = await _wait_until(func():
			return _cs() != null and _cs().scene_file_path == STAGE_A, 900)
	_check(arrived, "C1 换场进地点 A（转场链在真场景生效且 runner 存活）")
	if not arrived:
		return
	await _frames(4)
	_check(_cs().get("stage_id") == &"stage_ref_a", "C1 地点 stage_id 覆写生效")
	_check((_cs().get_node("HudLayer/GameHUD/Frame") as Control).visible,
			"C1 GameHUD 入场并跟手 chen")
	var cps: Array[Dictionary] = GameEvents.get_checkpoints()
	_check(not cps.is_empty() and cps.back().stage_id == &"stage_ref_a",
			"C1 检查点表含 stage_ref_a（真换场形态注册）")
	_check(GameEvents.pending_jump_stage == "", "C1 pending_jump_stage 干净")

	# —— C2 房1锁相机+刷怪 ——
	var cam := _stage_cam()
	_stage_chen().global_position = Vector2(520, 600)
	var locked: bool = await _wait_until(func():
			return cam.limit_right == 1500, 240)
	_check(locked, "C2 走过检测线→相机锁定到房1边界（limit_right=1500）")
	var bodies := 0
	for n in get_tree().get_nodes_in_group("area2d:spar_enemy"):
		if n is QuiverCharacter:
			bodies += 1
	_check(bodies == 1, "C2 波次敌人已刷出（IN_PLACE 1 只身体，实际 %d）" % bodies)

	# —— C3 清房1（聚合与解锁） ——
	var cleared1: bool = await _clear_until(1)
	_check(cleared1, "C3 房1清场→room_cleared（全灭→解锁链在真场景走通）")
	var expanded: bool = await _wait_until(func():
			return cam.limit_right == 2200, 240)
	_check(expanded, "C3 解锁扩权（after_fight_limit_right=2200）")

	# —— C4 房2双生成器聚合 ——
	_stage_chen().global_position = Vector2(1950, 600)
	var locked2: bool = await _wait_until(func():
			return cam.limit_right == 3000, 240)
	# 锁定语义=相机右缘收到房框 limit_right（房2=3000）；解锁才到 after_fight 3800
	_check(locked2, "C4 房2锁定（limit_right=3000，实际 %d）" % cam.limit_right)
	# 循环清场：波2在第一波全灭后由 spawner 自动续刷，直到聚合计数+1
	var agg: bool = await _clear_until(2)
	_check(agg,
			"C4 双生成器全清才聚合 room_cleared（单 spawner 不提前解锁）")
	var expanded2: bool = await _wait_until(func():
			return cam.limit_right == 3800, 240)
	_check(expanded2, "C4 房2解锁扩权（3800，出口在界内）")

	# —— C5 StageExit 跨地点真转场 ——
	_stage_chen().global_position = Vector2(3650, 600)
	var jumped: bool = await _wait_until(func():
			return _cs() != null and _cs().scene_file_path == STAGE_B, 900)
	_check(_c_stage_exited == 1, "C5 stage_exited 恰好一次（防重入旗真验）")
	_check(jumped, "C5 跨地点真转场到 B")
	if not jumped:
		return
	await _frames(4)
	_check(GameEvents.get_checkpoints().back().stage_id == &"stage_ref_b",
			"C5 检查点追新（尾=b）")

	# —— C6 终点腿：清 B 房 → ends_after_last_room → 面板+冻结 ——
	var cam_b := _stage_cam()
	_stage_chen().global_position = Vector2(520, 600)
	var locked_b: bool = await _wait_until(func():
			return cam_b.limit_right == 1800, 240)
	_check(locked_b, "C6 B 房锁定")
	var b_cleared: bool = await _clear_until(3)
	_check(b_cleared, "C6 B 清场 room_cleared")
	var panel: Control = _cs().get_node("HudLayer/StageEndPanel")
	var shown: bool = await _wait_until(func():
			return panel.visible, 120)
	_check(shown, "C6 ends_after_last_room 真链：终点面板弹出")
	_check(get_tree().paused, "C6 终点树冻结")
	# 为后续死亡腿恢复运转
	get_tree().paused = false
	panel.visible = false

	# —— C7 真死链 → 死亡界面 → 点最新检查点（B）回跳 ——
	var chen := _stage_chen()
	chen.attributes.health_current = 0
	# 玩家侧纯水平 launch 经弹地路径仍抵达 Die（与上方敌人侧教训不矛盾，实测全绿）
	var data := QuiverKnockbackData.new(1200.0, CombatSystem.HurtTypes.HIGH, Vector2.RIGHT)
	CombatSystem.apply_knockback(data, chen.attributes)
	var death_ui := _cs().get_node("HudLayer/PauseLayer/DeathScreen") as Control
	var died: bool = await _wait_until(func():
			return death_ui != null and death_ui.visible, 900)
	_check(died, "C7 真死链走完（血0+击飞→Die 动画→player_died→死亡界面，含击飞链复用）")
	if not died:
		return
	_check(get_tree().paused, "C7 死亡树冻结")
	var entries: VBoxContainer = death_ui.get_node("ContentLayer")
	_check(entries.get_child_count() == 3,
			"C7 按钮=两检查点+返回标题（实际 %d）" % entries.get_child_count())
	_check((entries.get_child(0) as Button).text == "stage_ref_b",
			"C7 最新检查点在首位（新→旧渲染真验）")
	var old_stage_id := _cs().get_instance_id()
	(entries.get_child(0) as Button).pressed.emit()
	# 同场景重载：scene_file_path 全程相同会骗轮询——盯"实例更换+pending 被新场景消费"
	var restored: bool = await _wait_until(func():
			return _cs() != null and _cs().get_instance_id() != old_stage_id, 900)
	_check(restored, "C7 按压回跳 B（同场景重载真转场）")
	var consumed: bool = await _wait_until(func():
			return GameEvents.pending_jump_stage == "", 240)
	await _frames(4)
	_check(not get_tree().paused, "C7 回跳后树已解冻（unpause 前置铁律回归）")
	_check(is_equal_approx(_stage_chen().global_position.x, 300.0),
			"C7 玩家回出生位（场景重载语义，实际 x=%.0f）" % _stage_chen().global_position.x)
	_check(consumed and GameEvents.pending_jump_stage == "", "C7 pending 落位即消费")
	GameEvents.reset_session()
