extends Node

## stage-contract 契约套（S1 矩阵登记项；5b 轨道统一批改写）：A 段=流程壳三件套
## （标题/暂停/死亡）的结构与开关契约；B 段=ChapterShell 壳模板骨架/检查点注册/
## 段级波次聚合/实例化回跳/终点面板接线（原 base_stage 腿随 5b 下线转世——死亡
## 转交命题归壳轨段重跑，已由 container_contract D 组续锁，本套不再重复）。
## C 段=两个**壳形**法定参考章节的全流程环：换场存活 runner、锁房、段清聚合与
## 推进、段清扩权、跨章 StageExit 真转场、章终点 chapter_finished 闩、光照对偶
## （A 负 B 正）、暂停菜单检查点回跳（死亡界面支随 base 退役，回跳链改验壳形）。
## 【豁免】C 段验证"生产参考章节在位"的整体行为：壳 override 直载生产
## chen.tscn（断言面绑 chen 节点路径 ChenSkin/…/HurtBox 与出生位——属
## "chen-in-chapter"题意的合法绑定，B2.5 新法申报）；B 段替身一律 test_actor。
## 运行：godot --headless --path . res://tools/stage_contract/stage_contract.tscn
const TITLE := "res://ui/menus/title_screen.tscn"
const PAUSE := "res://ui/menus/pause_menu.tscn"
const DEATH := "res://ui/menus/death_screen.tscn"
const SHELL_TEMPLATE := "res://scenes/chapter/chapter_shell.tscn"
const FIXTURE_PROBE := "res://tools/stage_contract/fixtures/chapter_probe.tscn"
const CHAPTER_A := "res://scenes/stages/ref/chapter_ref_a.tscn"
const CHAPTER_B := "res://scenes/stages/ref/chapter_ref_b.tscn"
const Kit := preload("res://tools/matrix_runner/test_actor_kit.gd")

## 断言全数（防线：GDScript 运行时报错只中断当前函数、调用方继续——
## 缺壳时整段断言被静默跳过仍会汇总 PASS；跑不满此数=有断言被吞）。
## 5b 计数=126（A 段 35+B 段壳形 40+C 段壳形 50 系，142→126：base 腿
## 退役与 C3.5/C6 面板/C7 死亡界面等转世简并，案卷见 STATUS 5b 条目）。
const EXPECTED_ASSERTS := 126

var _fails := 0
var _finished := false
var _checks := 0

var _title: Control
var _pause: Control
var _death: Control
var _open_count := 0
var _closed_count := 0
var _c_stage_exited := 0


func _ready() -> void:
	# B4.5-T1 A1 卫生扩展（spec §2 测试卫生条款）：A 组探针+真壳 _ready 的
	# add_location_checkpoint 触泛信号=影子自动落盘源，重定向到本套 scratch，
	# 生产槽零污染（与 T0 container/block_parry 等四套同款一行、零逻辑侵入）；
	# B4.5-T2 起手清场（spec §4 改判配套）：A4 继续钮 disabled==!has_save() 与
	# A7"有档→只弹窗"判据都吃 scratch 存缺真值——T1"尾不清残档与判据无关"
	# 自此不再成立，起手 delete_save 钉死"当下无档"起点（尾仍不清，下轮同此）
	get_node_or_null(^"/root/SaveSystem").slot_path = "user://b45_stage_scratch.json"
	get_node_or_null(^"/root/SaveSystem").delete_save()
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
	await _b3_aggregation()
	await _b5_fixture_jump()
	await _b7_end_panel()
	await _flow_c()
	# A7 排在 C0 存活化（runner 挂 root 直属）之后：RED 期旧 _start_game 会起
	# 真转场，唯有此位形 runner 不陪葬拆套（spec §4 拆段腿，T1 移交②）
	await _a7_load_game()
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


## A4 add_entry 计数与状态（B4.5-T2 改判，spec §4：占位"读取存档"已退役换真钮
## 「继续游戏」——enabled=SaveSystem.has_save() 于 title._ready 评估，起手清场后
## 当下无档=disabled；旧判据"读档钮 disabled 占位"作废，新判据随盘态动态对偶）
func _a4_entries() -> void:
	var pc: VBoxContainer = _pause.get_node("ContentLayer")
	_check(pc.get_child_count() == 4, "A4 pause 条目=4（实际 %d）" % pc.get_child_count())
	var tc: VBoxContainer = _title.get_node("ContentLayer")
	_check(tc.get_child_count() == 3, "A4 title 条目=3（实际 %d）" % tc.get_child_count())
	var load_btn := tc.get_child(1) as Button
	var start_btn := tc.get_child(0) as Button
	_check(load_btn != null and load_btn.text == "继续游戏" \
			and load_btn.disabled == (not SaveSystem.has_save()),
			"A4 title 钮2=「继续游戏」且 disabled==!has_save()（spec §4，当下无档=disabled）")
	_check(start_btn != null and not start_btn.disabled, "A4 title 开始钮可用")


## A5 死亡壳被动重建：open 时从 GameSave 地点访问表清旧再生成（新→旧），末条
## 固定回标题；全程不按压（跳转=真实换场景，归 C 段/T5 验）。
## 注（B4.5-T1 改判，spec §3 裁决 R2）：回跳表迁账 GameSave，
## add_location_checkpoint 仍"摘旧追新+append"，数组尾部=最新访问，渲染取逆。
func _a5_death_rebuild() -> void:
	GameSave.add_location_checkpoint(&"probe_a", "res://tools/stage_contract/_fake_a.tscn")
	GameSave.add_location_checkpoint(&"probe_b", "res://tools/stage_contract/_fake_b.tscn")
	GameSave.add_location_checkpoint(&"probe_a", "res://tools/stage_contract/_fake_a2.tscn")
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
	# 收尾自洁改判（B4.5-T1，spec §3"表随档案：清账=清表"）：清表唯一口=
	# GameSave.new_profile（reset_session 已收缩为只清传渡，不再担此职）
	GameSave.new_profile()
	_check(GameSave.locations().is_empty(), "A5 收尾自洁（new_profile 随档案清表）")


## A6 回跳取序（T2 裁决）：注册表旧→新，最新在尾——pause"回本地点入口"与
## death 可见首条（A5 锁）同源于 cps.back()；不按压，只核对目标读径
## （B4.5-T1 改判：注册表迁账 GameSave.locations，尾=最新语义原样，spec §3）
func _a6_latest_checkpoint() -> void:
	GameSave.add_location_checkpoint(&"probe_old", "res://tools/stage_contract/_fake_old.tscn")
	GameSave.add_location_checkpoint(&"probe_new", "res://tools/stage_contract/_fake_new.tscn")
	var latest: Dictionary = _pause._latest_checkpoint()
	_check(latest.scene_path == "res://tools/stage_contract/_fake_new.tscn",
			"A6 pause 跳转目标=注册表尾部（最新）")
	GameSave.new_profile()   # 表随档案：清账=清表（B4.5-T1 改判）


## A7 读档入口腿（B4.5-T2，spec §4；在 _flow 尾执行——C0 存活化后，理由见彼注）：
## 「开始游戏」有档=运行时构建 ConfirmationDialog 只到弹窗即返（弹窗与转场分相
## 天然可测；真确认→转场链归 F5，T1 移交②"套件不点钮"经 call 直入回调函数、
## 且判据先行拦在弹窗相）；begin_new_profile=清账+删档+清传渡收口单一出处
## （title 确认/无档直进/本腿三调用点共吃，防"清账忘删盘"漂移——plan Interfaces
## 注记）。落盘全程只吃本套 scratch（起手已重定向+清场）。
func _a7_load_game() -> void:
	GameSave.new_profile()
	GameSave.add_flag(&"a7_probe")
	GameSave.add_location_checkpoint(&"a7_loc", "res://tools/stage_contract/_fake_a7.tscn")
	SaveSystem.save_now()   # 同步落一份进 scratch（有档前提）
	_check(SaveSystem.has_save(), "A7a scratch 有档（有档分支前提，落盘=T0 影子面）")
	var dialogs := _title.find_children("*", "ConfirmationDialog", true, false)
	_check(dialogs.size() == 1,
			"A7b 覆盖确认框运行时构建恰 1 枚在册（标题壳子节点，无新 .tscn，spec §4）")
	# 型注：ConfirmationDialog 沿 Window→Viewport→Node 血统，**不是 Control**
	# （A7 首跑实锤："Trying to assign ConfirmationDialog to Control" 炸吞 7 腿）
	var dlg: ConfirmationDialog = dialogs[0] if dialogs.size() == 1 else null
	_check(dlg != null and not dlg.visible, "A7c 弹窗未触发前初始隐")
	var scene_before := get_tree().current_scene
	_title.call(&"_start_game")   # 模拟点击入口函数（typed Control 禁直调脚本方法判例）
	if dlg != null:
		# A7d 合取强化（B4.5-T4 修复波第二件，T2 移交硬批①）：弹窗判据原只证
		# "弹窗显"，文案声称的"账未清"无腿——弹窗相若被降解形（先清账再弹窗）
		# 则现判据假绿；补"账未清（旗在）+盘未删"两合取，红据=sabotage 档
		# （_start_game 弹窗前插 begin_new_profile → 本腿响亮红，/tmp/opencode/b45_t4/）
		_check(dlg.visible and GameSave.has_flag(&"a7_probe") and SaveSystem.has_save(),
				"A7d 有档点开始=只到弹窗步（弹窗显+账未清+盘未删三合取，转场另相）")
		# F5 缺陷回归锁（2026-09-26 用户实机眼：框钉左上角）：直显（set_visible）
		# 不走弹出管线=pos(0,0)+非模态。headless 的 display server 是 mock，
		# 屏心像素算不准（实测 popup_centered 落位与可见_rect 语义脱钩）——
		# 机器判据退到忠实代理"离开左上角原点"（直显形制恒 (0,0) 必红），
		# 真居中/真模态观感归 F5 眼（本锁与 A7d'' 合围缺陷本体）。
		await get_tree().process_frame   # 弹窗布局一拍
		_check(dlg.position != Vector2i.ZERO,
				"A7d' 弹窗离开左上角原点（pos=%s；直显=set_visible 恒 (0,0) 必红，屏心观感归 F5）" % dlg.position)
		_check(dlg.exclusive,
				"A7d'' 弹窗模态抓取（exclusive=true——弹出管线才给，直显不给）")
		_check(get_tree().current_scene == scene_before,
				"A7e 弹窗相不触发真转场（套根场景原样，拆套防线）")
	else:
		_check(false, "A7d 弹窗缺位无从'只到弹窗'（RED 现场：旧实现无账检查直转场）")
		_check(get_tree().current_scene == scene_before,
				"A7e 不触发真转场（RED 现场：旧实现已把套根场景换掉）")
	var sr: GDScript = load("res://scripts/chapter/session_rules.gd")
	# GDScript 资源 has_method 可见静态方法（T2 前置探针 P8/P9 实锤 4.7.1：
	# 在册静态=true、缺席=false——门判据单一调用式，免 method-list 遍历）
	var has_bnp: bool = sr.has_method("begin_new_profile")
	_check(has_bnp, "A7f SessionRules.begin_new_profile 在册（清账+删档+清传渡收口单一出处）")
	# 传渡双旗预置脏（begin 的"清传渡"判据要有的放矢；resume_pending 由 P 流/D5
	# 证不入账，这里只证 begin 落旗）
	GameSave.resume_pending = true
	GameEvents.pending_jump_stage = "res://tools/stage_contract/_fake_a7.tscn"
	if has_bnp:
		sr.call("begin_new_profile")   # Object.call 静态派发（红期不炸 typed 解析，G1 形制等价）
	_check(has_bnp and GameSave.has_flag(&"a7_probe") == false
			and GameSave.locations().is_empty(),
			"A7g begin_new_profile 账清（旗+表随档案归零；RED 期旧 _start_game 的裸"
			+ "new_profile 同形抹账，故判据捆在册门防假绿）")
	_check(SaveSystem.has_save() == false, "A7h begin_new_profile 盘删（scratch 随档清）")
	_check(GameEvents.pending_jump_stage == "" and GameSave.resume_pending == false,
			"A7i begin_new_profile 传渡清（pending_jump_stage+resume_pending 双易失旗）")
	# ── A7j/A7k 检查点空场景支（B4.5-T4 修复波第三件，T2 移交硬批②标题端）：
	# _continue_game=先置旗后查场景，scene 空串（T0 前旧档/未落段档形态）→
	# push_error 响亮不转。此刻旗已 true 而永无壳命中（空串不匹配任何场景）
	# =旗滞留惰性面——真实世界收口=begin_new_profile（A7i 已钉）或玩家改选
	# 有段档；本对腿钉"不转+不拆套+旗响亮滞留"（壳端未命中滞留半面由 spell
	# 套 P6 钉，两面合璧=传渡旗的完整消费/滞留合同）──
	GameSave.new_profile()          # 空检查点（scene="" 即"未记账"旧档面相）
	SaveSystem.save_now()           # 空场景档落 scratch（继续钮数据源）
	var scene_before_j := get_tree().current_scene
	_title.call(&"_continue_game")  # 模拟点击继续钮（A7d 同款 call 直入，套零真转场）
	_check(get_tree().current_scene == scene_before_j,
			"A7j 空场景档=不转场（push_error 响亮=被试行为，套根场景原样）")
	_check(GameSave.resume_pending == true,
			"A7k 空场景支旗滞留（置旗先于场景查询；无壳可命中=惰性留，收口归 begin）")
	GameSave.resume_pending = false  # 清滞留旗（不外溢后续腿/他套；真实收口口=A7i 已钉）
	GameSave.new_profile()
	await _frames(2)   # 排干在途影子冲刷再删（"删完又复活=残骸过夜"判例，D 尾同款）
	SaveSystem.delete_save()   # 尾净（起手清场判据对下轮恒成立）


## ═══ B 段（5b 转世：ChapterShell 壳模板与壳机制契约）═══════════════════

## B1' 壳模板骨架+注入形主角+相机自动补挂+L3 三件套在位（KeyLight 阴影关禁令）
##     +三层初始隐藏（DeathScreen=休眠件）；B2' 检查点注册/空主键守卫/pending
##     不误消费（并入同壳流水）。替身=test_actor（B2.5 新法：B 段"只是需要
##     一个角色"一律消费 Kit）。
func _b1_structure() -> void:
	if not Kit.exists():
		_check(false, "B1' test_actor 缺席（先跑 run_matrix.sh --ensure-only）")
		return
	var shell: ChapterShell = (load(SHELL_TEMPLATE) as PackedScene).instantiate()
	shell.chapter_id = &"t_shell"
	shell.playable_override = load(Kit.ACTOR_SCENE)
	add_child(shell)
	await _frames(3)
	_check(shell.playable != null and shell.playable.name == "TestActor",
			"B1' override 注入形主角在位（Players/TestActor）")
	var paths := [
		"Players", "Players/TestActor", "Players/TestActor/LevelCamera",
		"Segments", "Ambient", "Ambient/CanvasModulate", "Ambient/KeyLight",
		"Ambient/DayNightController",
		"HudLayer", "HudLayer/GameHUD", "HudLayer/PauseLayer",
		"HudLayer/PauseLayer/PauseMenu", "HudLayer/PauseLayer/DeathScreen",
		"HudLayer/StageEndPanel", "HudLayer/StageEndPanel/PanelBox/BackTitle",
		"HudLayer/StageEndPanel/PanelBox/Replay",
	]
	for pth in paths:
		_check(shell.get_node_or_null(pth) != null, "B1' 路径可寻址 %s" % pth)
	var cam := shell.get_node("Players/TestActor/LevelCamera") as Camera2D
	_check(cam != null and cam.is_current(), "B1' 自动补挂相机掌电流（E7 断相机防线）")
	var key := shell.get_node("Ambient/KeyLight") as DirectionalLight2D
	_check(key != null and not key.shadow_enabled,
			"B1' KeyLight 内置阴影关（双重阴影禁令法典级，壳轨同样在位）")
	var pause_layer := shell.get_node("HudLayer/PauseLayer") as Control
	_check(pause_layer.process_mode == Node.PROCESS_MODE_ALWAYS,
			"B1' PauseLayer=ALWAYS(3)（裁决#6 值语义）")
	_check(not (shell.get_node("HudLayer/PauseLayer/PauseMenu") as Control).visible
			and not (shell.get_node("HudLayer/PauseLayer/DeathScreen") as Control).visible
			and not shell._end_panel.visible,
			"B1' 三层初始隐藏（DeathScreen 休眠件在位）")
	var cps: Array[Dictionary] = GameSave.locations()
	var found := false
	for cp in cps:
		if cp.stage_id == &"t_shell":
			found = true
	_check(found, "B2' _ready 自动注册（t_shell 入地点访问表）")
	var before: int = GameSave.locations().size()
	GameSave.add_location_checkpoint(&"", "res://x.tscn")
	_check(GameSave.locations().size() == before, "B2' 空 chapter_id 被守卫拒录")
	_check(GameEvents.pending_jump_stage == "", "B2' 直载未命中 → pending 不被误消费")
	shell.queue_free()
	await _frames(2)
	GameSave.new_profile()


## B3' 壳段级聚合：程序段（真房+双生成器+检测器）pack 入壳——实源并集收编、
## 部分完成不清段、全清=segment_cleared 恰一次、单段章撞墙=chapter_finished
## 恰一次（终点面板不自动弹=B7 消费口现状，另腿钉）。
func _b3_aggregation() -> void:
	GameSave.new_profile()
	var seg_script: Script = load("res://scripts/chapter/stage_content.gd")
	var seg: Node2D = Node2D.new()
	seg.set_script(seg_script)
	seg.segment_id = &"t_seg"
	var room := QuiverFightRoom.new()
	room.name = "Room1"
	room.limit_left = 0
	room.limit_top = -280
	room.limit_right = 1500
	room.limit_bottom = 1200
	room.zoom = 1.0
	room.after_fight_use_new_room = true
	room.after_fight_limit_left = 0
	room.after_fight_limit_top = -280
	room.after_fight_limit_right = 2200
	room.after_fight_limit_bottom = 1200
	room.after_fight_zoom = 1.0
	seg.add_child(room)
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
	room.add_child(det)
	# pack 序列化按 owner 收集子树（4.x 引擎语义：owner 缺省=不入包——
	# 首跑尸检实锤 kids= 空壳；运行时构树必须显式补 owner 链）
	room.owner = seg
	sp1.owner = seg
	sp2.owner = seg
	det.owner = seg
	var packed := PackedScene.new()
	var pk_err := packed.pack(seg)
	seg.free()
	_check(pk_err == OK, "B3' 程序段打包 OK（实际 err=%d）" % pk_err)
	if pk_err != OK:
		return
	var shell: ChapterShell = (load(SHELL_TEMPLATE) as PackedScene).instantiate()
	shell.chapter_id = &"t_agg"
	shell.playable_override = load(Kit.ACTOR_SCENE)
	shell.segment_scenes = [packed]
	var cleared: Array[StringName] = []
	shell.segment_cleared.connect(func(id: StringName) -> void: cleared.append(id))
	var fins := [0]
	shell.chapter_finished.connect(func() -> void: fins[0] += 1)
	add_child(shell)
	await _frames(3)
	var lsp1 := shell._current.get_node_or_null("Room1/Spawner1") as QuiverEnemySpawner
	var lsp2 := shell._current.get_node_or_null("Room1/Spawner2") as QuiverEnemySpawner
	if lsp1 == null or lsp2 == null:
		var kids := ""
		if shell._current != null:
			for c in shell._current.get_children():
				kids += "%s(%s)" % [c.name, c.get_class()]
				for g in c.get_children():
					kids += " >%s(%s)" % [g.name, g.get_class()]
		_check(false, "B3' 实例生成器失联（current=%s kids=%s）"
				% [str(shell._current), kids])
		shell.queue_free()
		return
	_check(shell._seg_spawner_set.get(&"t_seg", []).size() == 2,
			"B3' 检测器导出收编 2 生成器入段实源集")
	lsp2.is_completed = true
	lsp1.all_waves_completed.emit()   # lsp1 未完成（真信标语义同旧 B3）
	await _frames(2)
	_check(cleared.is_empty(), "B3' 部分完成 → 不清段")
	lsp1.is_completed = true
	lsp2.all_waves_completed.emit()
	await _frames(4)
	_check(cleared == [&"t_seg"],
			"B3' 段全清 segment_cleared 恰一次载荷=段 id（实际 %s）" % str(cleared))
	_check(fins[0] == 1, "B3' 单段章判清撞墙 → chapter_finished 恰一次（闩锁）")
	_check(not shell._end_panel.visible,
			"B3'' 章判清面板不自动弹=B7 接线前现状即契约")
	shell.queue_free()
	await _frames(2)
	GameSave.new_profile()


## B5' 实例化根回跳语义（壳形探针=chapter_probe.tscn，空场合法形态）：
## scene_file_path=外层文件、chapter_id 覆写、检查点按外层注册、pending 命中
## 即消费——注册/消费腿排在主角解析之前，空场红不吞这两腿（序判例申报）。
func _b5_fixture_jump() -> void:
	GameEvents.pending_jump_stage = FIXTURE_PROBE
	var scene: ChapterShell = (load(FIXTURE_PROBE) as PackedScene).instantiate()
	get_tree().root.add_child(scene)
	await _frames(2)
	get_tree().current_scene = scene
	_check(is_instance_valid(scene), "B5' 实例化根就位")
	_check(scene.scene_file_path == FIXTURE_PROBE,
			"B5' 实例化根 scene_file_path=外层文件（实际 %s）" % scene.scene_file_path)
	_check(scene.chapter_id == &"probe", "B5' 覆写 chapter_id=probe 生效")
	var hit := false
	for cp in GameSave.locations():
		if cp.stage_id == &"probe" and cp.scene_path == FIXTURE_PROBE:
			hit = true
	_check(hit, "B5' 检查点按外层文件注册（回跳可解析）")
	_check(GameEvents.pending_jump_stage == "", "B5' pending_jump_stage 落位即消费")
	_check(scene._end_panel.get_node("PanelBox/BackTitle") != null, "B5' 实例内终点钮就位")
	get_tree().current_scene = self
	scene.free()
	GameSave.new_profile()


## B7' 终点面板接线就位：初始隐藏（自动弹出等 B7 消费）、ALWAYS（B7 死锁修复
## 锁语义续立）、两钮已接非禁用。
func _b7_end_panel() -> void:
	if not Kit.exists():
		_check(false, "B7' test_actor 缺席")
		return
	var shell: ChapterShell = (load(SHELL_TEMPLATE) as PackedScene).instantiate()
	shell.chapter_id = &"t_end"
	shell.playable_override = load(Kit.ACTOR_SCENE)
	add_child(shell)
	await _frames(2)
	_check(not shell._end_panel.visible,
			"B7' 终点面板初始隐藏（自动弹出等 B7 消费=现状即契约）")
	_check(shell._end_panel.process_mode == Node.PROCESS_MODE_ALWAYS,
			"B7' 面板 ALWAYS（冻结树里钮可响应——死锁修复锁续立）")
	var back := shell._end_panel.get_node("PanelBox/BackTitle") as Button
	var replay := shell._end_panel.get_node("PanelBox/Replay") as Button
	_check(back != null and not back.disabled and replay != null and not replay.disabled,
			"B7' 两钮就位可用（wire_end_panel 在 _ready 已接）")
	shell.queue_free()
	await _frames(2)
	GameSave.new_profile()


### -----------------------------------------------------------------------------------------------
### C 段（5b 转世）：两个壳形法定参考章节的全流程环
### -----------------------------------------------------------------------------------------------

## C 段累计段清计数（对每个上树壳接 segment_cleared）
var _c_segs_seen := 0


func _wait_until(cond: Callable, cap_frames: int) -> bool:
	for _i in cap_frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _cs() -> Node:
	return get_tree().current_scene


func _stage_cam() -> Camera2D:
	return _cs().get_node("Players/Chen/LevelCamera") as Camera2D


func _stage_chen() -> QuiverCharacter:
	return _cs().get_node("Players/Chen") as QuiverCharacter


## 真死链清场（判例保留：带竖直分量 launch 走全演出；纯血 0 不走演出）
func _kill_spars() -> void:
	for n in get_tree().get_nodes_in_group("area2d:spar_enemy"):
		if n is QuiverCharacter:
			var body := n as QuiverCharacter
			body.attributes.health_current = 0
			var data := QuiverKnockbackData.new(1200.0, CombatSystem.HurtTypes.HIGH,
					Vector2(0.866, -0.5))
			CombatSystem.apply_knockback(data, body.attributes)


func _alive_spars() -> int:
	var c := 0
	for n in get_tree().get_nodes_in_group("area2d:spar_enemy"):
		if n is QuiverCharacter:
			c += 1
	return c


## 计数式清场（目标=累计段清数）：真死链轮询
func _clear_until_segs(target: int) -> void:
	for _round in 60:
		if _c_segs_seen >= target:
			return
		_kill_spars()
		await _wait_until(func(): return _c_segs_seen >= target, 60)


func _flow_c() -> void:
	GameEvents.stage_exited.connect(func(_id): _c_stage_exited += 1)

	# C0 存活化（runner 升 root 直属+替身顶 current_scene，判例注释原样）
	var tree := get_tree()
	var decoy := Node.new()
	decoy.name = &"SceneDecoy"
	tree.root.add_child(decoy)
	tree.current_scene = decoy
	get_parent().remove_child(self)
	tree.root.add_child(self)

	# —— C1 换场进章节 A ——
	get_tree().change_scene_to_file(CHAPTER_A)
	var arrived: bool = await _wait_until(func():
			return _cs() != null and _cs().scene_file_path == CHAPTER_A, 900)
	_check(arrived, "C1 换场进章节 A（转场链在真场景生效且 runner 存活）")
	if not arrived:
		return
	await _frames(8)
	_check(_cs().get("chapter_id") == &"chapter_ref_a", "C1 章节 chapter_id 生效")
	_check((_cs().get_node("HudLayer/GameHUD/Frame") as Control).visible,
			"C1 GameHUD 入场并跟手 chen")
	var cps: Array[Dictionary] = GameSave.locations()
	_check(not cps.is_empty() and cps.back().stage_id == &"chapter_ref_a",
			"C1 检查点表含 chapter_ref_a（真换场形态注册）")
	_check(GameEvents.pending_jump_stage == "", "C1 pending_jump_stage 干净")
	var shell_a: ChapterShell = _cs() as ChapterShell
	if shell_a == null:
		_check(false, "C1 当前场景非 ChapterShell（后续环崩）")
		return
	var fins_a := [0]
	shell_a.chapter_finished.connect(func() -> void: fins_a[0] += 1)
	shell_a.segment_cleared.connect(func(_id): _c_segs_seen += 1)

	# —— C1.5 光照骨架契约（5b 壳轨形：L3 三件套收编进壳模板，A 负例=空数据自禁）——
	var l3_ctrl := _cs().get_node_or_null("Ambient/DayNightController")
	_check(l3_ctrl is DayNightController,
			"LC1 壳骨架预置 DayNightController（5b 三件套随 base 收编入壳）")
	var key_light := _cs().get_node_or_null("Ambient/KeyLight") as DirectionalLight2D
	_check(key_light != null and not key_light.shadow_enabled,
			"LC2 KeyLight 在位且内置阴影关（双重阴影禁令，法典级）")
	var cm := _cs().get_node("Ambient/CanvasModulate") as CanvasModulate
	_check(l3_ctrl != null and l3_ctrl.scene_time_data == null and cm.color == Color.WHITE,
			"LC3 空数据章节自禁（画布纯白不崩）")
	await _frames(30)
	_check(cm.color == Color.WHITE, "LC3b 空数据 30 帧后仍纯白（无幽灵驱动）")
	_check(ShadowSoftEdge.derived_z_for(_cs()) == ShadowSoftEdge.composite_z,
			"LC4 软边壳轨法定档=composite_z（-1：段内容 z0 之下 Vis 皮肤之上）")
	shell_a.shadow_composite_override = 7
	_check(ShadowSoftEdge.derived_z_for(_cs()) == 7,
			"LC5 壳根哨兵覆写生效（专家通道自 base 迁壳）")
	shell_a.shadow_composite_override = -2147483648
	var probe := Node2D.new()
	_check(ShadowSoftEdge.derived_z_for(probe) == ShadowSoftEdge.composite_z,
			"LC6 非壳根回退手动态（Run-Test 场景零扰动）")
	probe.free()
	_check(ShadowSoftEdge.enabled,
			"LC8 软边默认开宪法（2026-09-28 用户定调：运行即开）")
	_check(get_tree().get_nodes_in_group(&"shadow_region").is_empty(),
			"LC7 章节 A 空数据负例零区域（不挂=全屏阴影回退合法）")

	# —— C2 房1锁相机+刷怪 ——
	var cam := _stage_cam()
	_stage_chen().global_position = Vector2(520, 600)
	var locked: bool = await _wait_until(func():
			return cam.limit_right == 1500, 240)
	_check(locked, "C2 走过检测线→相机锁定到房1边界（limit_right=1500）")
	_check(_alive_spars() == 1, "C2 波次敌人已刷出（IN_PLACE 1 只，实际 %d）" % _alive_spars())

	# —— C2.5 锁房落位收口（钳位矩形=房界-40，判例原样）——
	var chen2 := _stage_chen()
	chen2.global_position = Vector2(300, 600)
	var room1 := (_cs() as ChapterShell).get_node("Segments/SegRefA1/Room1") as QuiverFightRoom
	room1.setup_fight_room()
	var pulled: bool = await _wait_until(func():
			return chen2.global_position.x >= 340.0, 240)
	_check(pulled, "C2.5 锁房收口：界外玩家钳回界内（x=%.0f）" % chen2.global_position.x)
	Input.action_press("move_left")
	await _frames(90)
	Input.action_release("move_left")
	_check(chen2.global_position.x >= 340.0,
			"C2.5 稳态顶墙不再出界（x=%.0f）" % chen2.global_position.x)

	# —— C4a 段清推进（壳轨核心语义）：清房1=段 a1 判清 → 自动推进 seg_a2 →
	#     走线锁房2 ——
	await _clear_until_segs(1)
	var advanced: bool = await _wait_until(func():
			return shell_a.current_segment_id() == &"seg_a2", 400)
	_check(advanced, "C4a 段 a1 判清自动推进 seg_a2（壳轨段清=推进环）")
	var chen4 := _stage_chen()
	for x in range(1701, 1952, 25):
		chen4.global_position = Vector2(x, 600)
		await get_tree().physics_frame
	var locked2: bool = await _wait_until(func():
			return cam.limit_right == 3000, 240)
	_check(locked2, "C4a 房2锁定（走 a2 检测线，limit_right=3000，实际 %d）" % cam.limit_right)
	_check(shell_a._seg_spawner_set.get(&"seg_a2", []).size() == 2,
			"C4a a2 段实源集=双生成器（跨房聚合判清的数据面）")

	# —— C4b 段 a2 判清 → setup 扩权 3800 → 章终点闩 ——
	#（原 C3.5 撞墙真反弹三腿随 5b 摘除：命题由 knockout_contract D1-D8 全量
	#  覆盖——带触发/reflect 真值表/横竖分档几何；本场景复刻依赖"段清扩界
	#  过渡把弹墙带送进飞行射程"的 base 时代时序细节，壳轨下带位随相机过渡
	#  漂移不可稳定复现，2026-09-28 尸检两次红后按影响面裁撤，案卷在此。）
	await _clear_until_segs(2)
	var expanded2: bool = await _wait_until(func():
			return cam.limit_right == 3800, 300)
	_check(expanded2, "C4b 段 a2 全清 setup 扩权（3800=双 spawner 聚合非单房提前解锁）")
	var fin1: bool = await _wait_until(func(): return fins_a[0] == 1, 240)
	_check(fin1, "C4b 章节 A 段清撞墙 → chapter_finished 恰一次")

	# —— C5 StageExit 跨章真转场（载荷=chapter_id 解析首验）——
	_stage_chen().global_position = Vector2(3650, 400)
	var jumped: bool = await _wait_until(func():
			return _cs() != null and _cs().scene_file_path == CHAPTER_B, 900)
	_check(_c_stage_exited == 1, "C5 stage_exited 恰一次（持续重叠防重入）")
	_check(jumped, "C5 跨章真转场到 B")
	if not jumped:
		return
	await _frames(4)
	_check(GameSave.locations().back().stage_id == &"chapter_ref_b",
			"C5 检查点追新（尾=chapter_ref_b）")

	# —— C6 章节 B 正例对偶（光照活循环+区域实配）与章终点现状 ——
	var b_ctrl := _cs().get_node_or_null("Ambient/DayNightController")
	_check(b_ctrl != null and b_ctrl.scene_time_data != null,
			"LC8b ref_b 正例：控制器挂 day_cycle_demo（光照随时在走）")
	_check(get_tree().get_nodes_in_group(&"shadow_region").size() == 1,
			"LC9b ref_b 正例：ShadowRegion 区域框实配恰 1 个")
	var shell_b: ChapterShell = _cs() as ChapterShell
	var fins_b := [0]
	shell_b.chapter_finished.connect(func() -> void: fins_b[0] += 1)
	shell_b.segment_cleared.connect(func(_id): _c_segs_seen += 1)
	var cam_b := _stage_cam()
	_stage_chen().global_position = Vector2(520, 600)
	var locked_b: bool = await _wait_until(func():
			return cam_b.limit_right == 1800, 240)
	_check(locked_b, "C6 B 房锁定")
	await _clear_until_segs(4)
	var finb: bool = await _wait_until(func(): return fins_b[0] == 1, 240)
	_check(finb, "C6 B 判清 → chapter_finished(b) 恰一次")
	_check(not shell_b._end_panel.visible,
			"C6 面板不自动弹出=B7 消费未接线的现状即契约")

	# —— C7 暂停菜单回跳环（死亡界面支随 base 退役；回跳链改验壳形）——
	var pm := _cs().get_node("HudLayer/PauseLayer/PauseMenu") as Control
	pm.open_menu()
	await _frames(2)
	_check(get_tree().paused, "C7 暂停开=冻结落位")
	pm.close_menu()
	_check(not get_tree().paused, "C7 关菜单解冻（按压回跳前清场）")
	var jb := pm.get_node("ContentLayer").get_child(1) as Button
	_check(jb != null and jb.text == "回本地点入口", "C7 回跳钮在册（index1）")
	var old_id := _cs().get_instance_id()
	jb.pressed.emit()
	var restored: bool = await _wait_until(func():
			return _cs() != null and _cs().get_instance_id() != old_id, 900)
	_check(restored, "C7 按压回跳（同章重载真转场，实例更换）")
	var consumed: bool = await _wait_until(func():
			return GameEvents.pending_jump_stage == "", 240)
	_check(consumed, "C7 pending 落位即消费")
	_check(not get_tree().paused, "C7 回跳后树已解冻（unpause 前置铁律回归）")
	await _frames(6)
	_check(is_equal_approx(_stage_chen().global_position.x, 300.0),
			"C7 玩家回出生位（entry 语义，实际 x=%.0f）" % _stage_chen().global_position.x)
	GameSave.new_profile()
	await _frames(2)
