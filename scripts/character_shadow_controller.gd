extends Sprite2D

## 角色阴影控制器
## 由 QuiverCharacter._ready() 动态创建
## 管理：Sprite2D vertex 变形（平行四边形）+ shader instance uniform 更新

const SHADOW_SHADER_PATH := "res://shaders/shadow_sdf.gdshader"
const DEBUG_OVERLAY_SCRIPT := preload("res://scripts/shadow_debug_overlay.gd")
const BASE_MARGIN := 20.0
const MIN_ELEVATION := 5.0
const MAX_SHADOW_LENGTH := 600.0
const MIN_SHADOW_LENGTH := 30.0
const DEFAULT_ELEVATION := 45.0
const DEFAULT_ANGLE := 135.0
const DEFAULT_SPRITE_WIDTH := 66.0
const DEFAULT_SPRITE_HEIGHT := 180.0

static var _shared_material: ShaderMaterial = null
static var _shared_texture: PlaceholderTexture2D = null

var _skin: QuiverCharacterSkin
var _day_night: Node
var _softness: float = 0.4
var _debug_overlay: Node2D = null
var _current_elevation: float = DEFAULT_ELEVATION
var _current_azimuth: float = -45.0

func setup(skin: QuiverCharacterSkin) -> void:
	_skin = skin
	_day_night = get_node_or_null("/root/DayNightManager")
	_setup_shared_resources()
	_create_debug_overlay()
	_update_verts()
	_update_shadow_params()

func _create_debug_overlay() -> void:
	_debug_overlay = Node2D.new()
	_debug_overlay.name = "ShadowDebugOverlay"
	_debug_overlay.z_index = 1
	_debug_overlay.set_script(DEBUG_OVERLAY_SCRIPT)
	add_child(_debug_overlay)

func _setup_shared_resources() -> void:
	if _shared_texture == null:
		_shared_texture = PlaceholderTexture2D.new()
		_shared_texture.size = Vector2(1, 1)
	texture = _shared_texture

	if _shared_material == null:
		_shared_material = ShaderMaterial.new()
		_shared_material.shader = preload(SHADOW_SHADER_PATH)
		_shared_material.set_shader_parameter("softness", _softness)
		_shared_material.set_shader_parameter("angle", DEFAULT_ANGLE)
	material = _shared_material

func _process(_delta: float) -> void:
	_update_shadow_params()
	_update_verts()

func _update_shadow_params() -> void:
	if not _day_night:
		return
	if not _day_night.has_method("get_sun_elevation_deg"):
		return

	var elevation: float = _day_night.get_sun_elevation_deg()
	var azimuth: float = _day_night.get_sun_azimuth_deg()
	_current_elevation = elevation
	_current_azimuth = azimuth

	var shader_angle := fmod(azimuth + 180.0, 360.0)
	_shared_material.set_shader_parameter("angle", shader_angle)

	var sprite_h := _get_sprite_height()
	var tan_elev := tan(deg_to_rad(max(elevation, MIN_ELEVATION)))
	var shadow_pixels := sprite_h / tan_elev
	shadow_pixels = clamp(shadow_pixels, MIN_SHADOW_LENGTH, MAX_SHADOW_LENGTH)

	set_instance_shader_parameter("shadow_max_dist", shadow_pixels)

func get_current_elevation() -> float:
	return _current_elevation

func get_current_azimuth() -> float:
	return _current_azimuth

func _compute_shadow_vertices() -> Dictionary:
	var sprite_w := _get_sprite_width()
	var sprite_h := _get_sprite_height()

	var elevation := _get_current_elevation()
	var shadow_dir := _get_shadow_direction()

	var jump_height: float = _skin.base_height if _skin else 0.0
	var effective_height := sprite_h + jump_height

	var tan_elev := tan(deg_to_rad(max(elevation, MIN_ELEVATION)))
	var shadow_len := effective_height / tan_elev
	shadow_len = clamp(shadow_len, MIN_SHADOW_LENGTH, MAX_SHADOW_LENGTH)

	var dx := shadow_dir.x * shadow_len
	var full_w := sprite_w
	var full_h: float = shadow_len * abs(shadow_dir.y)
	var half_len: float = full_h / 2.0

	var top_off := Vector2(0.0, half_len)
	var bot_off := Vector2(dx, half_len)

	var shadow_size := Vector2(full_w, full_h)
	var v0 := Vector2(-0.5, -0.5) * shadow_size + top_off
	var v1 := Vector2(-0.5, 0.5) * shadow_size + bot_off
	var v2 := Vector2(0.5, 0.5) * shadow_size + bot_off
	var v3 := Vector2(0.5, -0.5) * shadow_size + top_off

	return {
		"vertices": [v0, v1, v2, v3],
		"full_w": full_w, "full_h": full_h,
		"top_off": top_off, "bot_off": bot_off,
	}

func _update_verts() -> void:
	var data := _compute_shadow_vertices()

	set_instance_shader_parameter("shadow_size", Vector2(data.full_w, data.full_h))
	set_instance_shader_parameter("shadow_top_offset", data.top_off)
	set_instance_shader_parameter("shadow_bottom_offset", data.bot_off)

	# 计算 custom_rect 精确匹配平行四边形范围
	# 顶边：从 (-full_w/2, 0) 到 (full_w/2, 0)
	# 底边：从 (-full_w/2 + dx, full_h) 到 (full_w/2 + dx, full_h)
	var dx: float = data.bot_off.x
	var min_x: float = min(-data.full_w / 2.0, -data.full_w / 2.0 + dx)
	var max_x: float = max(data.full_w / 2.0, data.full_w / 2.0 + dx)
	var custom_rect_pos := Vector2(min_x, 0.0)
	var custom_rect_size := Vector2(max_x - min_x, data.full_h)
	
	RenderingServer.canvas_item_set_custom_rect(
		get_canvas_item(),
		true,
		Rect2(custom_rect_pos, custom_rect_size)
	)

	if _debug_overlay:
		_debug_overlay.update_vertices(
			data.vertices[0], data.vertices[1],
			data.vertices[2], data.vertices[3]
		)

func _get_sprite_width() -> float:
	if not _skin:
		return DEFAULT_SPRITE_WIDTH
	var sprite: AnimatedSprite2D = _skin.get_node("AnimatedSprite2D")
	if not sprite or not sprite.sprite_frames:
		return DEFAULT_SPRITE_WIDTH
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex:
		return tex.get_size().x
	return DEFAULT_SPRITE_WIDTH

func _get_sprite_height() -> float:
	if not _skin:
		return DEFAULT_SPRITE_HEIGHT
	var sprite: AnimatedSprite2D = _skin.get_node("AnimatedSprite2D")
	if not sprite or not sprite.sprite_frames:
		return DEFAULT_SPRITE_HEIGHT
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex:
		return tex.get_size().y
	return DEFAULT_SPRITE_HEIGHT

func _get_current_elevation() -> float:
	if _day_night and _day_night.has_method("get_sun_elevation_deg"):
		return _day_night.get_sun_elevation_deg()
	return DEFAULT_ELEVATION

func _get_shadow_direction() -> Vector2:
	if _day_night and _day_night.has_method("get_sun_azimuth_deg"):
		var azimuth: float = _day_night.get_sun_azimuth_deg()
		var shader_angle := fmod(azimuth + 180.0, 360.0)
		var ang_rad := shader_angle * PI / 180.0
		var light_dir := Vector2(sin(ang_rad), cos(ang_rad))
		return -light_dir
	return Vector2(-0.7, 0.7).normalized()
