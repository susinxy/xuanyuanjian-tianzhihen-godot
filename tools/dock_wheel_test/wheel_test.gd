extends Node

## 滚轮端到端回归套（17 号；2026-09-16 悬案定案后转正）：headless 里把
## 真实滚轮事件经 Window.push_input 打进**真 DebugDock 全树**（CanvasLayer+
## TabContainer+DebugTextTab），断言 scroll_vertical 真的变化。
## 定案记录：真凶=RichTextLabel.fit_content=false（自报最小高 0 → 容器
## 零溢出 → 滚动条不出现+滚轮无范围）；同伴契约=标签 mouse_filter 不得
## 吞事件。本套同时锁死两者——任何一条回归都直接红。
## 坐标系教训：push_input 收屏幕坐标，必须经 get_screen_transform() 换算，
## headless 窗口/内容尺寸缩比下裸 canvas 坐标会让指针飞到 (11840,50780)。
## 全程单协程串行，杜绝"未 await 的假绿跳段"。

var _dock: CanvasLayer
var _tab: ScrollContainer
var _ok := true


func _ready() -> void:
	await get_tree().physics_frame
	_dock = preload("res://ui/debug_dock.tscn").instantiate()
	add_child(_dock)
	await get_tree().physics_frame
	_dock.visible = true
	var lines: Array[String] = []
	for i in 80:
		lines.append("第%02d行 —— 滚轮取证长文填充行" % i)
	_dock.add_text_tab("轮测", func() -> Array[String]: return lines)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var tabs: TabContainer = _dock.get_node("Panel/VBox/Tabs")
	for i in tabs.get_tab_count():
		if tabs.get_tab_title(i) == "轮测":
			tabs.current_tab = i
	await get_tree().physics_frame
	_tab = tabs.get_current_tab_control() as ScrollContainer
	_ok = _check(_tab != null, "轮测页签装配到位") and _ok
	if _tab == null:
		_finish()
		return

	# 等内容真实送达（0.15s 拉取式刷新，最多等 2 秒；空标签测滚轮=测空气）
	var label := _tab.get_child(0) as Control
	var waited := 0
	while label.get_combined_minimum_size().y <= 200.0 and waited < 60:
		await get_tree().physics_frame
		waited += 1
	var rt := label as RichTextLabel
	print("[轮测] 内容送达等待 %d 帧，min高=%.0f 文本长=%d fit_content=%s scroll_active=%s 换行=%d 内容高=%.0f 标签尺寸=%s" % [
			waited, label.get_combined_minimum_size().y,
			rt.text.length(), rt.fit_content, rt.scroll_active,
			rt.autowrap_mode, rt.get_content_height(), label.size])
	for i in _tab.get_child_count():
		print("[轮测]   容器子节点[%d] %s %s" % [
				i, _tab.get_child(i).get_class(), _tab.get_child(i).name])

	var center := _tab.get_global_rect().get_center()
	# 坐标换算：push_input 收"屏幕坐标"，headless 窗口(64x64)与内容尺寸
	# (2560x1440)间存在 content scale——不经 canvas→screen 变换的话，指针
	# 会被换算到万里之外，GUI pick 永远落空（首版取证套就栽在这，
	# 落点=(11840,50780) 现场为证）。
	var screen_pos: Vector2 = get_window().get_screen_transform() * center
	print("[轮测] canvas落点=%s → 屏幕投递=%s" % [center, screen_pos])
	var motion := InputEventMouseMotion.new()
	motion.global_position = screen_pos
	motion.position = screen_pos
	get_window().push_input(motion)
	var before := _tab.scroll_vertical
	for i in 4:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.global_position = screen_pos
		wheel.position = screen_pos
		wheel.pressed = true
		get_window().push_input(wheel)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var after := _tab.scroll_vertical
	var label_min := (_tab.get_child(0) as Control).get_combined_minimum_size().y
	print("[轮测] 裁决：滚动前=%d 滚动后=%d 内容最低高=%.0f 容器高=%.0f 标签filter=%d" % [
			before, after, label_min, _tab.size.y,
			(_tab.get_child(0) as Control).mouse_filter])
	_ok = _check(after > before, "真滚轮事件驱动内容滚动（%d→%d）" % [before, after]) and _ok
	_finish()


func _check(cond: bool, label: String) -> bool:
	print("  %s: %s" % ["PASS" if cond else "FAIL", label])
	return cond


func _finish() -> void:
	print("════════ dock-wheel: %s ════════" % ("PASS" if _ok else "FAIL"))
	get_tree().quit(0 if _ok else 1)
