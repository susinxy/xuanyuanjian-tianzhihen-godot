extends CanvasLayer

@export var character: CharacterBody2D

var _skin: QuiverCharacterSkin
var _panel: Panel
var _label: Label
var _draw_control: Control
var _error_message: String = ""

func _ready() -> void:
	_create_panel()
	
	if not character:
		_auto_find_character()
	
	if not character:
		_error_message = "❌ character: null (NodePath 未正确设置，且自动查找失败)"
		return
	
	_find_skin()
	
	if not _skin:
		_error_message = "❌ skin: 未找到 QuiverCharacterSkin"
		return
	
	_error_message = ""


func _auto_find_character() -> void:
	var parent := get_parent()
	if not parent:
		return
	
	for child in parent.get_children():
		if child is CharacterBody2D:
			character = child
			return


func _create_panel() -> void:
	_panel = Panel.new()
	_panel.position = Vector2(10, 10)
	_panel.size = Vector2(350, 480)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.border_color = Color(0.5, 0.8, 1.0, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	
	_label = Label.new()
	_label.position = Vector2(10, 10)
	_label.size = Vector2(330, 460)
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_panel.add_child(_label)
	
	_draw_control = Control.new()
	_draw_control.size = get_viewport().get_visible_rect().size
	_draw_control.draw.connect(_on_draw)
	add_child(_draw_control)


func _find_skin() -> void:
	for child in character.get_children():
		if child is QuiverCharacterSkin:
			_skin = child
			return


func _process(_delta: float) -> void:
	if not _panel or not _label:
		return
	
	if _error_message != "":
		_label.text = "=== 高度层调试信息 ===\n" + _error_message
		return
	
	if not character or not _skin:
		return
	
	var viewport_size := get_viewport().get_visible_rect().size
	if _draw_control.size != viewport_size:
		_draw_control.size = viewport_size
	
	var bh := _skin.base_height
	var ph := _skin.physical_height
	var ah := _skin.attack_heights
	var cl := character.collision_layer
	var pos := character.global_position
	
	var layers_str := ""
	for i in range(QuiverCharacter.HEIGHT_LAYER_FIRST, QuiverCharacter.HEIGHT_LAYER_LAST + 1):
		if cl & (1 << (i - 1)):
			layers_str += str(i) + " "
	if layers_str.is_empty():
		layers_str = "无"
	
	var occupied_str := "[%.0f, %.0f]" % [bh, bh + ph]
	
	var fps := Engine.get_frames_per_second()
	_label.text = "FPS: %d\n\n" % fps
	_label.text += "=== 高度层调试信息 ===\n"
	_label.text += "base_height: %.1f px\n" % bh
	_label.text += "physical_height: %.1f px\n" % ph
	_label.text += "occupied: %s\n" % occupied_str
	_label.text += "attack_heights: %s\n" % str(ah)
	_label.text += "高度层: %s\n" % layers_str
	_label.text += "位置: (%.0f, %.0f)\n" % [pos.x, pos.y]
	_label.text += "skin.position.y: %.1f\n" % _skin.position.y
	
	var anim_sprite := _skin.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var sr := character.get_node("ShadowRenderer") as Sprite2D
	if anim_sprite and sr:
		var tex := anim_sprite.sprite_frames.get_frame_texture(anim_sprite.animation, anim_sprite.frame)
		var sprite_w: float = tex.get_size().x if tex else 0.0
		var sprite_h: float = tex.get_size().y if tex else 0.0
		var sprite_pos := anim_sprite.position
		var shadow_size_val = sr.get_instance_shader_parameter("shadow_size")
		var shadow_max_dist_val = sr.get_instance_shader_parameter("shadow_max_dist")
		var top_off_val = sr.get_instance_shader_parameter("shadow_top_offset")
		var bot_off_val = sr.get_instance_shader_parameter("shadow_bottom_offset")
		
		if shadow_size_val and shadow_max_dist_val and top_off_val and bot_off_val:
			var shadow_size: Vector2 = shadow_size_val
			var shadow_max_dist: float = shadow_max_dist_val
			var top_off: Vector2 = top_off_val
			var bot_off: Vector2 = bot_off_val
			var ratio: float = shadow_size.y / sprite_h if sprite_h > 0 else 0.0
			
			var elevation: float = 45.0
			var azimuth: float = -45.0
			if sr.has_method("get_current_elevation"):
				elevation = sr.get_current_elevation()
			if sr.has_method("get_current_azimuth"):
				azimuth = sr.get_current_azimuth()
			
			var shader_angle := fmod(azimuth + 180.0, 360.0)
			var ang_rad := shader_angle * PI / 180.0
			var shadow_dir := -Vector2(sin(ang_rad), cos(ang_rad))
			
			var effective_height := sprite_h + bh
			var tan_elev := tan(deg_to_rad(max(elevation, 5.0)))
			var shadow_len := effective_height / tan_elev
			shadow_len = clamp(shadow_len, 30.0, 600.0)
			var full_h: float = shadow_size.y
			
			var v0 := Vector2(-0.5, -0.5) * shadow_size + top_off
			var v1 := Vector2(-0.5, 0.5) * shadow_size + bot_off
			var v2 := Vector2(0.5, 0.5) * shadow_size + bot_off
			var v3 := Vector2(0.5, -0.5) * shadow_size + top_off
			_label.text += "\n=== 阴影调试 ===\n"
			_label.text += "精灵图: %.0f×%.0f px\n" % [sprite_w, sprite_h]
			_label.text += "AnimSprite.pos: (%.0f, %.0f)\n" % [sprite_pos.x, sprite_pos.y]
			_label.text += "elevation: %.1f°\n" % elevation
			_label.text += "azimuth: %.1f°\n" % azimuth
			_label.text += "shadow_dir: (%.3f, %.3f)\n" % [shadow_dir.x, shadow_dir.y]
			_label.text += "jump_height: %.1f\n" % bh
			_label.text += "effective_height: %.1f\n" % effective_height
			_label.text += "shadow_len: %.1f\n" % shadow_len
			_label.text += "shadow_size: (%.0f, %.0f)\n" % [shadow_size.x, shadow_size.y]
			_label.text += "full_h: %.1f\n" % full_h
			_label.text += "top_off: (%.1f, %.1f)\n" % [top_off.x, top_off.y]
			_label.text += "bot_off: (%.1f, %.1f)\n" % [bot_off.x, bot_off.y]
			_label.text += "shadow_max_dist: %.1f\n" % shadow_max_dist
			_label.text += "阴影/身高比: %.2f\n" % ratio
			_label.text += "v0(top-left):  (%.1f, %.1f)\n" % [v0.x, v0.y]
			_label.text += "v1(bot-left):  (%.1f, %.1f)\n" % [v1.x, v1.y]
			_label.text += "v2(bot-right): (%.1f, %.1f)\n" % [v2.x, v2.y]
			_label.text += "v3(top-right): (%.1f, %.1f)" % [v3.x, v3.y]
		else:
			_label.text += "\n=== 阴影调试 ===\n"
			_label.text += "等待 shader 初始化...\n"
	
	_draw_control.queue_redraw()
	_auto_resize_panel()

func _auto_resize_panel() -> void:
	if not _panel or not _label:
		return
	var line_count: int = _label.text.count("\n") + 1
	var font_size: int = 12
	var line_height: float = font_size * 1.6
	var padding: float = 20.0
	var required_height: float = line_count * line_height + padding * 2.0
	var panel_width := 350.0
	_panel.size = Vector2(panel_width, required_height)
	_label.size = Vector2(panel_width - padding * 2.0, required_height - padding * 2.0)


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
