extends VBoxContainer

## 光照·仪表交互页（2026-09-20 调试面板正式化批）：昼夜相位/倍速/覆盖演示 +
## 高度条、阴影调试线两个可视化开关 + 状态行。
## 刷新走 dock 拉取制（refresh_from_provider 契约，0.15s）——本页绝不做每帧活；
## 复选框每次刷新跟随现实（无实物自动回弹，不撒谎）。

const HEIGHT_OVERLAY_SCRIPT := "res://scripts/debug_height_overlay.gd"
const PHASE_NAMES := ["黎明", "白天", "黄昏", "夜晚"]

var _status: Label
var _height_check: CheckBox
var _shadow_check: CheckBox
## dock 动态生成的高度条（场景自带时直接操控自带件，不重复生成）
var _height_overlay: CanvasLayer = null


func _ready() -> void:
	var phases := HBoxContainer.new()
	for i in PHASE_NAMES.size():
		var b := Button.new()
		b.text = PHASE_NAMES[i]
		b.pressed.connect(_on_phase_pressed.bind(i))
		phases.add_child(b)
	add_child(phases)

	var speeds := HBoxContainer.new()
	speeds.add_child(_mk_label("循环倍速:"))
	for s in [1.0, 4.0, 16.0]:
		var b := Button.new()
		b.text = "%d×" % int(s)
		b.pressed.connect(_on_speed_pressed.bind(s))
		speeds.add_child(b)
	var stop := Button.new()
	stop.text = "停"
	stop.pressed.connect(_on_speed_pressed.bind(0.0))
	speeds.add_child(stop)
	add_child(speeds)

	var demo := Button.new()
	demo.text = "覆盖演示（3 秒压暗，同 O 键）"
	demo.pressed.connect(_on_demo_pressed)
	add_child(demo)

	var checks := HBoxContainer.new()
	_height_check = CheckBox.new()
	_height_check.text = "高度层条"
	_height_check.toggled.connect(_on_height_toggled)
	checks.add_child(_height_check)
	_shadow_check = CheckBox.new()
	_shadow_check.text = "阴影调试线"
	_shadow_check.toggled.connect(_on_shadow_toggled)
	checks.add_child(_shadow_check)
	add_child(checks)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	_status.add_theme_font_size_override("font_size", 13)
	add_child(_status)
	refresh_from_provider()


func _mk_label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	return l


func _mgr() -> Node:
	return get_tree().root.get_node_or_null("DayNightManager")


func _on_phase_pressed(i: int) -> void:
	var m := _mgr()
	if m != null:
		m.transition_to(i)


func _on_speed_pressed(s: float) -> void:
	var m := _mgr()
	if m != null:
		m.set_cycle_speed(s)


func _on_demo_pressed() -> void:
	var dock := get_tree().root.get_node_or_null("DebugDock")
	if dock != null and dock.has_method("debug_apply_demo_override"):
		dock.debug_apply_demo_override()


## 阴影调试线：全场角色影控的调试子节点统一显隐（无角色=合法空操作）
func _on_shadow_toggled(on: bool) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for n in scene.find_children("ShadowDebugOverlay", "", true, false):
		(n as CanvasItem).visible = on


## 高度条：场景自带件直接扳可见；无自带件按需动态生成（挂 root，layer=80 在坞之下）
func _on_height_toggled(on: bool) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var owned: CanvasLayer = null
	for n in scene.find_children("*", "CanvasLayer", true, false):
		var s := (n as Node).get_script() as Script
		if s != null and s.resource_path == HEIGHT_OVERLAY_SCRIPT:
			owned = n as CanvasLayer
			break
	if owned != null:
		owned.visible = on
		return
	if on:
		_height_overlay = preload("res://scripts/debug_height_overlay.gd").new()
		var player := _find_player()
		if player != null:
			# NodePath 文本形式=跨树绝对路径，overlay._ready 里 get_node 解析
			_height_overlay.character_path = player.get_path()
		_height_overlay.layer = 80
		get_tree().root.add_child.call_deferred(_height_overlay)
	elif _height_overlay != null:
		_height_overlay.visible = false


func _find_player() -> Node:
	for n in get_tree().get_nodes_in_group("area2d:player"):
		if n is QuiverCharacter:
			return n
	return null


## dock 拉取制刷新（0.15s）：状态行 + 复选框反映现实
func refresh_from_provider() -> void:
	var m := _mgr()
	if m == null:
		_status.text = "DayNightManager 缺席（检查 [autoload]）"
		return
	var parts: Array[String] = ["相位 %s" % PHASE_NAMES[m.current_phase]]
	parts.append("倍速 %s" % ("停" if is_zero_approx(m.cycle_speed) else "%d×" % int(m.cycle_speed)))
	var ctrl_with_data := 0
	var ctrl_count := 0
	var shadow_vis := false
	var height_vis := false
	var scene := get_tree().current_scene
	if scene != null:
		for n in scene.find_children("*", "", true, false):
			if n is DayNightController:
				ctrl_count += 1
				if (n as DayNightController).scene_time_data != null:
					ctrl_with_data += 1
		for n in scene.find_children("ShadowDebugOverlay", "", true, false):
			if (n as CanvasItem).visible:
				shadow_vis = true
		for n in scene.find_children("*", "CanvasLayer", true, false):
			var s := (n as Node).get_script() as Script
			if s != null and s.resource_path == HEIGHT_OVERLAY_SCRIPT \
					and (n as CanvasLayer).visible:
				height_vis = true
	if _height_overlay != null and _height_overlay.visible:
		height_vis = true
	parts.append("光照数据 %d/%d 台" % [ctrl_with_data, ctrl_count])
	parts.append("启用区域 %d" % get_tree().get_nodes_in_group(&"shadow_region").size())
	var se := get_tree().root.get_node_or_null("ShadowSoftEdge")
	if se != null:
		parts.append("软边 %s" % ("开" if se.enabled else "关"))
	parts.append("覆盖栈 %d" % m.override_count())
	var yielding := _scene_has_script("res://scripts/debug_day_night_input.gd")
	parts.append("5-8/O %s" % ("让位场景件" if yielding else "dock 内置生效"))
	_status.text = " | ".join(parts)
	_shadow_check.set_pressed_no_signal(shadow_vis)
	_height_check.set_pressed_no_signal(height_vis or (
			_height_overlay != null and _height_overlay.visible))


func _scene_has_script(path: String) -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	for c in scene.find_children("*", "", true, false):
		var s := (c as Node).get_script() as Script
		if s != null and s.resource_path == path:
			return true
	return false
