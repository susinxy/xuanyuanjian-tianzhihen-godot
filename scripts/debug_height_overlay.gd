extends CanvasLayer

## 高度层图形仪表（2026-09-16 HUD 定档瘦身后）：只画屏幕右缘的竖条
## （角色占高区间/层格/基准线）。文字信息全部迁往 DebugDock[高度层]页——
## 旧文字区用 _process 刷新，headless 不派发 idle 帧从不出活，已随 Dock 拉取制根治。
##
## 要显示哪个角色的数据：存路径、运行时解析（_ready 里 get_node）。
## 注意：不要用节点对象引用型导出——文本形式赋 NodePath 时引擎不会
## 转换成节点引用（实测恒为 null，2026-09-15 复盘），一律 NodePath + get_node。
@export var character_path: NodePath = NodePath("../Character")

## 运行时解析结果（_ready 填充；解析不到则竖条静默不画）
var character: CharacterBody2D

var _skin: QuiverCharacterSkin
var _draw_control: Control


func _ready() -> void:
	if not character_path.is_empty():
		character = get_node_or_null(character_path)
	if character == null:
		_auto_find_character()
	if character == null:
		return
	_find_skin()
	_draw_control = Control.new()
	_draw_control.size = get_viewport().get_visible_rect().size
	_draw_control.draw.connect(_on_draw)
	add_child(_draw_control)


func _auto_find_character() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if child is CharacterBody2D:
			character = child
			return


func _find_skin() -> void:
	for child in character.get_children():
		if child is QuiverCharacterSkin:
			_skin = child
			return


func _physics_process(_delta: float) -> void:
	# 物理心跳（_process 在 headless 不派发——Dock 同批定档）；竖条逐帧跟手
	if _draw_control != null:
		var viewport_size := get_viewport().get_visible_rect().size
		if _draw_control.size != viewport_size:
			_draw_control.size = viewport_size
		_draw_control.queue_redraw()


func _on_draw() -> void:
	if not character or not _skin:
		return
	
	var quiver_char := character as QuiverCharacter
	if not quiver_char or quiver_char._height_definitions.is_empty():
		return
	
	var bh := _skin.base_height
	var ph := _skin.physical_height
	var defs := quiver_char._height_definitions
	
	var bar_x := get_viewport().get_visible_rect().size.x - 100.0
	var bar_width := 30.0
	var bar_height := 500.0
	var bar_y := 50.0
	
	# 计算最大显示高度（最后一层的下界 + 10%）
	var max_h: float = defs[-1]["min"] * 1.1
	if max_h <= 0:
		max_h = 1400.0
	
	# 背景
	var bg_rect := Rect2(bar_x, bar_y, bar_width, bar_height)
	_draw_control.draw_rect(bg_rect, Color(0, 0, 0, 0.5))
	_draw_control.draw_rect(bg_rect, Color(0.5, 0.8, 1.0, 0.8), false, 2.0)
	
	# 层边界线（10 层，每对 low/high 使用相近颜色）
	var colors := [
		Color(0.8, 0.6, 0.3), Color(0.8, 0.6, 0.3),  # ground_low, ground_high
		Color(0.3, 0.7, 0.5), Color(0.3, 0.7, 0.5),  # low_air_low, low_air_high
		Color(0.5, 0.5, 0.8), Color(0.5, 0.5, 0.8),  # mid_air_low, mid_air_high
		Color(0.7, 0.4, 0.7), Color(0.7, 0.4, 0.7),  # high_air_low, high_air_high
		Color(0.6, 0.3, 0.5), Color(0.6, 0.3, 0.5),  # very_high_low, very_high_high
	]
	
	for i in range(defs.size()):
		var h: float = defs[i]["max"]
		if h == INF:
			continue
		var y: float = bar_y + bar_height - (h / max_h * bar_height)
		_draw_control.draw_line(Vector2(bar_x, y), Vector2(bar_x + bar_width, y), colors[i], 2.0)
		var font := ThemeDB.fallback_font
		var layer_name := "L%d:%.0f" % [defs[i]["layer"], h]
		_draw_control.draw_string(font, Vector2(bar_x + bar_width + 5, y + 5), layer_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, colors[i])
	
	# occupied range 填充矩形
	var top_y := bar_y + bar_height - ((bh + ph) / max_h * bar_height)
	var bottom_y := bar_y + bar_height - (bh / max_h * bar_height)
	top_y = clamp(top_y, bar_y, bar_y + bar_height)
	bottom_y = clamp(bottom_y, bar_y, bar_y + bar_height)
	_draw_control.draw_rect(Rect2(bar_x, top_y, bar_width, bottom_y - top_y), Color(1, 1, 0, 0.3))
	
	# 底边线（base_height）
	_draw_control.draw_line(Vector2(bar_x - 10, bottom_y), Vector2(bar_x + bar_width + 10, bottom_y), Color(1, 1, 0), 2.0)
	_draw_control.draw_string(ThemeDB.fallback_font, Vector2(bar_x - 70, bottom_y + 5), "base:%.0f" % bh, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 0))
	
	# 顶边线（base_height + physical_height）
	_draw_control.draw_line(Vector2(bar_x - 10, top_y), Vector2(bar_x + bar_width + 10, top_y), Color(1, 0.8, 0), 2.0)
	_draw_control.draw_string(ThemeDB.fallback_font, Vector2(bar_x - 70, top_y + 5), "top:%.0f" % (bh + ph), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.8, 0))
