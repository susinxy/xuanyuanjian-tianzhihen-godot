extends Node

## stage-contract 契约套（S1 矩阵登记项）：本批=A 段，流程壳三件套（标题/暂停/
## 死亡）的结构与开关契约。B 段（T3 base_stage 聚合机制）/C 段（T5 全流程，
## 含按钮按压→真实换场景路径）后续批次续加——A 段不点击任何跳转钮（尚无地点
## 场景可换），只断接线条存在与 disabled 态。
## 运行：godot --headless --path . res://tools/stage_contract/stage_contract.tscn

const TITLE := "res://ui/menus/title_screen.tscn"
const PAUSE := "res://ui/menus/pause_menu.tscn"
const DEATH := "res://ui/menus/death_screen.tscn"

## A 段断言全数（防线：GDScript 运行时报错只中断当前函数、调用方继续——
## 缺壳时整段断言被静默跳过仍会汇总 PASS；跑不满此数=有断言被吞）。
## 计数在"跑满"这条自身计入前比对：流内 34 + 全序列 1 = 35
const EXPECTED_ASSERTS := 35

var _fails := 0
var _finished := false
var _checks := 0

var _title: Control
var _pause: Control
var _death: Control
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
	Input.parse_input_event(esc)
	var opened := await _wait_state(func() -> bool: return _pause.visible and get_tree().paused)
	_check(opened, "A3 ESC 第一按 → 开壳+冻结")
	esc.pressed = false
	Input.parse_input_event(esc)
	await _frames(1)
	esc.pressed = true
	Input.parse_input_event(esc)
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
