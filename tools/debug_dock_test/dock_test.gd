extends Node

## DebugDock 骨架契约测试（批 1）：默认开声明/键切换/原始按键链路/
## 页签注册与拉取刷新/Tab 循环。运行：
## godot --headless --path . res://tools/debug_dock_test/dock_test.tscn

var _fails := 0
var _finished := false


func _ready() -> void:
	await _flow()
	_check(_finished, "全序列执行完成（协程静默中断防线）")
	print("════════ debug-dock: %s ════════" % ("PASS" if _fails == 0 else "FAIL"))
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails += 1
	print("  %s: %s" % ["PASS" if ok else "FAIL", label])


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _dock() -> CanvasLayer:
	return get_tree().root.get_node_or_null("DebugDock") as CanvasLayer


func _tabs_ctrl(dock: CanvasLayer) -> TabContainer:
	return dock.get_node("Panel/VBox/Tabs") as TabContainer


func _flow() -> void:
	var dock := _dock()
	_check(dock != null, "DebugDock autoload 就位")
	if dock == null:
		_finished = true
		return
	await _frames(3)
	_check(dock.visible, "场景声明组 debug_dock_default_open → 入场自开")
	await _frames(5)

	Input.action_press("debug_dock_toggle")
	await _frames(2)
	Input.action_release("debug_dock_toggle")
	await _frames(2)
	_check(not dock.visible, "toggle 动作 → 关")
	Input.action_press("debug_dock_toggle")
	await _frames(2)
	Input.action_release("debug_dock_toggle")
	await _frames(2)
	_check(dock.visible, "toggle 再来 → 开（往返成立）")

	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_EQUAL
	ev.pressed = true
	Input.parse_input_event(ev)
	var ev_up := InputEventKey.new()
	ev_up.physical_keycode = KEY_EQUAL
	ev_up.pressed = false
	Input.parse_input_event(ev_up)
	await _frames(3)
	_check(not dock.visible, "OS 同款原始按键（=键）全链路可唤/熄")

	# 重新开坞后注册页签（刷新只在可见时跑）
	Input.action_press("debug_dock_toggle")
	await _frames(2)
	Input.action_release("debug_dock_toggle")
	await _frames(2)
	var lines := ["探针行一 42", "探针行二"]
	dock.add_text_tab("探针", func() -> Array[String]: return lines.duplicate())
	dock.add_text_tab("第二页", func() -> Array[String]: return ["x"])
	var titles: PackedStringArray = dock.get_tab_titles()
	_check(titles.has("探针") and titles.has("第二页"),
			"两个页签注册成功（%s）" % [str(titles)])
	_check(["角色", "弹体", "诊断", "高度层", "击飞", "光照", "帮助", "系统"]
			.all(func(t): return titles.has(t)),
			"内容层八页签自动注册在位（%s）" % [str(titles)])
	await _frames(20)
	var tabs := _tabs_ctrl(dock)
	var probe_tab := tabs.get_node("探针")
	var rich := probe_tab.get_child(0) as RichTextLabel
	_check(rich != null and "探针行一 42" in rich.text, "0.15s 拉取刷新把 provider 内容送达")
	var sys_tab := tabs.get_node("系统")
	var sys_rich: RichTextLabel = sys_tab.get_child(0)
	_check("FPS" in sys_rich.text, "系统页 provider 送达（FPS 行）")
	# 非当前页签不经排版（尺寸恒 0 是 TabContainer 本性）——切过去量
	tabs.current_tab = titles.find("系统")
	await _frames(5)
	_check(sys_tab.size.x > 50 and sys_rich.size.x > 50,
			"页签与文本头寸撑开（%d/%d，防宽度塌陷回归）" % [sys_tab.size.x, sys_rich.size.x])
	var scroll_tab := tabs.get_current_tab_control()
	var wheel_label: RichTextLabel = null
	for ch in scroll_tab.get_children():
		if ch is RichTextLabel:
			wheel_label = ch
	_check(wheel_label != null
			and wheel_label.mouse_filter != Control.MOUSE_FILTER_STOP,
			"页签标签不得 STOP 吞事件（当前 filter=%d）"
			% (wheel_label.mouse_filter if wheel_label else -1))
	_check(sys_rich.get_theme_color("default_color").v > 0.5,
			"字色浅色 override 在位（防黑纸黑字回归）")
	var title := dock.get_node("Panel/VBox/Title") as Control
	_check(title.size.y >= 24, "拖拽把手条几何高度足够（%d px）" % title.size.y)
	_check(title.mouse_default_cursor_shape == Control.CURSOR_MOVE,
			"把手光标=可移动型（说真话）")
	var help_tab := tabs.get_node("帮助")
	var help_rich: RichTextLabel = help_tab.get_child(0)
	_check("测试说明第一行" in help_rich.text and "第二行按键提示" in help_rich.text,
			"帮助页读出说明牌多行内容（split 类型陷阱回归锁）")

	# Tab 键循环（窗口此刻可见）
	var start_tab := tabs.current_tab
	var ev2 := InputEventKey.new()
	ev2.physical_keycode = KEY_TAB
	ev2.pressed = true
	Input.parse_input_event(ev2)
	var ev2up := InputEventKey.new()
	ev2up.physical_keycode = KEY_TAB
	ev2up.pressed = false
	Input.parse_input_event(ev2up)
	await _frames(3)
	_check(tabs.current_tab == (start_tab + 1) % tabs.get_tab_count(),
			"Tab 键循环页签（%d→%d / %d 页）" % [start_tab, tabs.current_tab, tabs.get_tab_count()])

	# 拖拽摆放三件套：自由落位 / 视口夹取 / 存档记忆（标题条 gui_input 走同一内部接口）
	var panel := dock.get_node("Panel")
	dock._save_layout()  # 先固化当前布局再实验
	dock._move_to(Vector2(300, 200))
	_check(panel.position == Vector2(300, 200), "任意落位（300,200）")
	dock._move_to(Vector2(99999, 99999))
	var vs := get_tree().root.get_visible_rect().size
	_check(absf(panel.position.x - (vs.x - panel.size.x)) < 1.5
			and absf(panel.position.y - (vs.y - panel.size.y)) < 1.5,
			"越界夹取贴右下不丢窗")
	dock._move_to(Vector2(777, 421))
	dock._save_layout()
	dock._place_default_or_saved()
	_check(panel.position == Vector2(777, 421), "跨调用读回记忆位（777,421）")
	# —— 光照·仪表交互页（2026-09-20 调试面板正式化批）——
	var mgr := get_tree().root.get_node_or_null("DayNightManager")
	var light_tab := tabs.get_node("光照")
	var btn_night: Button = null
	var btn_x4: Button = null
	var chk_height: CheckBox = null
	var chk_shadow: CheckBox = null
	for c in light_tab.find_children("*", "Button", true, false):
		if (c as Button).text == "夜晚":
			btn_night = c
		elif (c as Button).text == "4×":
			btn_x4 = c
	for c in light_tab.find_children("*", "CheckBox", true, false):
		if "高度" in (c as CheckBox).text:
			chk_height = c
		elif "阴影" in (c as CheckBox).text:
			chk_shadow = c
	_check(btn_night != null and btn_x4 != null
			and chk_height != null and chk_shadow != null,
			"相位/倍速按钮与两开关全部在位")
	btn_night.pressed.emit()
	_check(mgr.current_phase == 3, "页签按钮→相位即时切到 NIGHT")
	btn_x4.pressed.emit()
	_check(is_equal_approx(mgr.cycle_speed, 4.0), "倍速 4× 送达 manager")
	btn_x4.pressed.emit()
	var e6 := InputEventKey.new()
	e6.keycode = KEY_6
	e6.physical_keycode = KEY_6
	e6.pressed = true
	Input.parse_input_event(e6)
	var e6u := InputEventKey.new()
	e6u.keycode = KEY_6
	e6u.physical_keycode = KEY_6
	e6u.pressed = false
	Input.parse_input_event(e6u)
	await _frames(2)
	_check(mgr.current_phase == 1, "6 键 dock 内置→DAY（OS 原始键全链路）")
	# 共存让位：场景自带 DebugDayNightInput 时 dock 不响应 O→覆盖恰压栈一次
	var dnin := Node.new()
	dnin.set_script(preload("res://scripts/debug_day_night_input.gd"))
	add_child(dnin)
	var eo := InputEventKey.new()
	eo.keycode = KEY_O
	eo.physical_keycode = KEY_O
	eo.pressed = true
	Input.parse_input_event(eo)
	var eou := InputEventKey.new()
	eou.keycode = KEY_O
	eou.physical_keycode = KEY_O
	eou.pressed = false
	Input.parse_input_event(eou)
	await _frames(3)
	_check(mgr.override_count() == 1,
			"场景自带调试件→dock 让位（覆盖恰 1 非 2）")
	dnin.free()
	# 阴影开关：无角色=空操作，拉取刷新令开关回弹（状态跟随现实）
	chk_shadow.set_pressed(true)
	await _frames(20)
	# 状态属性是 button_pressed——Button.pressed 是信号不是属性（本测试首跑自证）
	_check(not chk_shadow.button_pressed, "阴影开关无实物回弹（不撒谎契约）")
	# 高度条：无自带件场景动态生成，关闭后隐藏
	chk_height.set_pressed(true)
	await _frames(8)
	var hv := false
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var s := (n as Node).get_script() as Script
		if s != null and s.resource_path == "res://scripts/debug_height_overlay.gd":
			hv = (n as CanvasLayer).visible
	_check(hv, "高度条正式场景式动态生成且可见")
	chk_height.set_pressed(false)
	await _frames(4)
	var hv_on := false
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var s := (n as Node).get_script() as Script
		if s != null and s.resource_path == "res://scripts/debug_height_overlay.gd" \
				and (n as CanvasLayer).visible:
			hv_on = true
	_check(not hv_on, "高度条关闭后隐藏（常驻不误绘）")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://debug_dock.cfg"))
	_finished = true
