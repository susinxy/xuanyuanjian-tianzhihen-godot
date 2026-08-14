extends CanvasLayer

@export var character: CharacterBody2D

var _skin: QuiverCharacterSkin
var _panel: Panel
var _label: Label
var _draw_control: Control

func _ready() -> void:
	if not character:
		return
	
	_skin = character.get_node_or_null("ChenJingchouSkin")
	if not _skin:
		for child in character.get_children():
			if child is QuiverCharacterSkin:
				_skin = child
				break
	
	if not _skin:
		push_warning("DebugHeightOverlay: 未找到 QuiverCharacterSkin")
		return
	
	_panel = Panel.new()
	_panel.position = Vector2(10, 10)
	_panel.size = Vector2(350, 180)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.border_color = Color(0.5, 0.8, 1.0, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	
	_label = Label.new()
	_label.position = Vector2(10, 10)
	_label.size = Vector2(330, 160)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_panel.add_child(_label)
	
	_draw_control = Control.new()
	_draw_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_control.draw.connect(_on_draw)
	add_child(_draw_control)


func _process(_delta: float) -> void:
	if not character or not _skin:
		return
	
	var bh := _skin.base_height
	var ph := _skin.physical_height
	var ah := _skin.attack_heights
	var cl := character.collision_layer
	var pos := character.global_position
	
	var layers_str := ""
	for i in range(15, 20):
		if cl & (1 << (i - 1)):
			layers_str += str(i) + " "
	if layers_str.is_empty():
		layers_str = "无"
	
	_label.text = "=== 高度层调试信息 ===\n"
	_label.text += "base_height: %.1f px\n" % bh
	_label.text += "physical_height: %.1f px\n" % ph
	_label.text += "attack_heights: %s\n" % str(ah)
	_label.text += "高度层: %s\n" % layers_str
	_label.text += "位置: (%.0f, %.0f)\n" % [pos.x, pos.y]
	_label.text += "skin.position.y: %.1f" % _skin.position.y
	
	_draw_control.queue_redraw()


func _on_draw() -> void:
	if not character or not _skin:
		return
	
	var bh := _skin.base_height
	var bar_x := 1100.0
	var bar_width := 30.0
	var bar_height := 300.0
	var bar_y := 50.0
	
	var bg_rect := Rect2(bar_x, bar_y, bar_width, bar_height)
	_draw_control.draw_rect(bg_rect, Color(0, 0, 0, 0.5))
	_draw_control.draw_rect(bg_rect, Color(0.5, 0.8, 1.0, 0.8), false, 2.0)
	
	var thresholds := [
		{"h": 30, "name": "ground", "color": Color(0.8, 0.6, 0.3)},
		{"h": 100, "name": "low_air", "color": Color(0.3, 0.7, 0.5)},
		{"h": 200, "name": "mid_air", "color": Color(0.5, 0.5, 0.8)},
		{"h": 300, "name": "high_air", "color": Color(0.7, 0.4, 0.7)},
	]
	
	var max_h := 350.0
	for t in thresholds:
		var y: float = bar_y + bar_height - (t["h"] / max_h * bar_height)
		_draw_control.draw_line(Vector2(bar_x, y), Vector2(bar_x + bar_width, y), t["color"], 2.0)
		var font := ThemeDB.fallback_font
		_draw_control.draw_string(font, Vector2(bar_x + bar_width + 5, y + 5), t["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, t["color"])
	
	var current_y := bar_y + bar_height - (bh / max_h * bar_height)
	current_y = clamp(current_y, bar_y, bar_y + bar_height)
	_draw_control.draw_line(Vector2(bar_x - 10, current_y), Vector2(bar_x + bar_width + 10, current_y), Color(1, 1, 0), 3.0)
	_draw_control.draw_string(ThemeDB.fallback_font, Vector2(bar_x - 50, current_y + 5), "%.0f" % bh, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 0))
