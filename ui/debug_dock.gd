extends CanvasLayer

## 全局调试坞（Autoload，2026-09-16 HUD 设计定档批 1）：
## 一个半透明、多标签、可滚动的窗口收纳全游戏的文字型调试信息，
## "+"唤出、Tab 循环页签；场景打组 debug_dock_default_open 即入场自开
## （Run Test 底版注入此声明，正式场景默认关）。
## 页签注册制：模块 add_text_tab(标题, 行生产者)——拉取式 0.15s 刷新，
## 绝不在每帧做（窗口永不拖游戏帧率）。手绘可视化（高度/击倒仪表）
## 按设计留在各自位置，不进本坞。

const REFRESH_INTERVAL := 0.15
const STYLE_BG := Color(0.05, 0.05, 0.08, 0.72)

@export var dock_size := Vector2(560, 340)
@export var default_open_group: StringName = &"debug_dock_default_open"

@onready var _panel: PanelContainer = $Panel
@onready var _tabs: TabContainer = $Panel/VBox/Tabs
@onready var _title: Control = $Panel/VBox/Title

var _refresh_accum := 0.0
## 拖拽态与位置持久化（user:// 存一次位置，跨启动记忆）
var _dragging := false
var _grab := Vector2.ZERO
const CFG_PATH := "user://debug_dock.cfg"


func _ready() -> void:
	layer = 90
	visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = STYLE_BG
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 8.0
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.custom_minimum_size = dock_size
	_panel.reset_size()
	_place_default_or_saved()
	_title.gui_input.connect(_on_title_gui)
	_apply_scene_default.call_deferred()
	_selfcheck_content.call_deferred()


# 物理帧驱动而非 _process：headless 环境不派发 idle 帧（2026-09-16 探针实证
# dock 与测试节点自身 _process 均 0 tick），物理心跳是全环境唯一可靠时钟。
func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("debug_dock_toggle"):
		visible = not visible
	if visible and Input.is_action_just_pressed("debug_dock_next_tab"):
		var n := _tabs.get_tab_count()
		if n > 1:
			_tabs.current_tab = (_tabs.current_tab + 1) % n
	if visible:
		_refresh_accum += delta
		if _refresh_accum >= REFRESH_INTERVAL:
			_refresh_accum = 0.0
			_refresh_providers()


## 注册文字页签；provider() 返回 Array[String] 或 String。
func add_text_tab(title: String, provider: Callable) -> void:
	var tab := preload("res://ui/debug_text_tab.gd").new()
	tab.setup(title, provider)
	add_tab(title, tab)


## 注册任意控件为页签（未来非文字页用）。
func add_tab(title: String, control: Control) -> void:
	control.name = title
	_tabs.add_child(control)


func get_tab_titles() -> PackedStringArray:
	var out := PackedStringArray()
	for i in _tabs.get_tab_count():
		out.append(_tabs.get_tab_title(i))
	return out


func _apply_scene_default() -> void:
	if get_tree().get_nodes_in_group(default_open_group).size() > 0:
		visible = true


## 零页签自诊断（2026-09-16 排查成本反哺）：内容层 autoload 缺席/配置漂移时，
## 窗口不再沉默摆空——自己报告病因，用户不必拿人眼跨三台机器对文件。
func _selfcheck_content() -> void:
	await get_tree().physics_frame
	if _tabs.get_tab_count() == 0:
		add_text_tab("⚠装载", func() -> Array[String]: return [
			"没有注册任何页签：内容层 DebugDockTabs 未装载。",
			"① 检查 project.godot [autoload] 是否有 DebugDockTabs 行；",
			"② 该文件被外部改动过则必须重启 Windows 编辑器（编辑器会用内存旧版回写覆盖）；",
			"③ Syncthing 同步是否已把 ui/debug_dock_tabs.gd 送达本机。"])


func _refresh_providers() -> void:
	for child in _tabs.get_children():
		if child.has_method("refresh_from_provider"):
			child.refresh_from_provider()


## 摆放：有档读档并夹回视口；无档默认左下角
func _place_default_or_saved() -> void:
	var vs := get_viewport().get_visible_rect().size
	var pos := Vector2(16, maxf(16.0, vs.y - _panel.size.y - 16))
	var cf := ConfigFile.new()
	if cf.load(CFG_PATH) == OK:
		pos = Vector2(cf.get_value("dock", "x", pos.x), cf.get_value("dock", "y", pos.y))
	_move_to(pos)


func _move_to(p: Vector2) -> void:
	var vs := get_viewport().get_visible_rect().size
	_panel.position = Vector2(
			clampf(p.x, 0.0, maxf(0.0, vs.x - _panel.size.x)),
			clampf(p.y, 0.0, maxf(0.0, vs.y - _panel.size.y)))


func _save_layout() -> void:
	var cf := ConfigFile.new()
	cf.set_value("dock", "x", _panel.position.x)
	cf.set_value("dock", "y", _panel.position.y)
	cf.save(CFG_PATH)


func _on_title_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_grab = _panel.get_global_mouse_position() - _panel.position
		else:
			if _dragging:
				_save_layout()
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		_move_to(_panel.get_global_mouse_position() - _grab)
