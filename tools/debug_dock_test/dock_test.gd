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
	await _frames(20)
	var tabs := _tabs_ctrl(dock)
	var probe_tab := tabs.get_node("探针")
	var rich := probe_tab.get_child(0) as RichTextLabel
	_check(rich != null and "探针行一 42" in rich.text, "0.15s 拉取刷新把 provider 内容送达")

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
	_finished = true
