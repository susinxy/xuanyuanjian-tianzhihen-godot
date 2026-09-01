extends Polygon2D

## 角色阴影控制器
## 由 QuiverCharacter._ready() 动态创建
## 管理：polygon 形状（平行四边形）+ shader 参数更新

const SHADOW_SHADER_PATH := "res://shaders/shadow_sdf.gdshader"
const DEFAULT_MAX_DIST := 100.0
const DEFAULT_ANGLE := 135.0
const BASE_MARGIN := 20.0
const MIN_ELEVATION := 5.0
const MAX_SHADOW_LENGTH := 600.0
const MIN_SHADOW_LENGTH := 30.0
const DEFAULT_ELEVATION := 45.0

var _material: ShaderMaterial
var _skin: QuiverCharacterSkin
var _day_night: Node
var _softness: float = 0.4

func setup(skin: QuiverCharacterSkin) -> void:
	_skin = skin
	_day_night = get_node_or_null("/root/DayNightManager")
	_setup_material()
	_update_polygon()

func _setup_material() -> void:
	_material = ShaderMaterial.new()
	_material.shader = preload(SHADOW_SHADER_PATH)
	_material.set_shader_parameter("max_dist", DEFAULT_MAX_DIST)
	_material.set_shader_parameter("angle", DEFAULT_ANGLE)
	_material.set_shader_parameter("softness", _softness)
	material = _material

func _process(_delta: float) -> void:
	if not _material:
		return
	_update_shadow_params()
	_update_polygon()

func _update_shadow_params() -> void:
	if not _day_night:
		return
	if not _day_night.has_method("get_sun_elevation_deg"):
		return

	var elevation: float = _day_night.get_sun_elevation_deg()
	var azimuth: float = _day_night.get_sun_azimuth_deg()

	var shader_angle := fmod(azimuth + 180.0, 360.0)
	_material.set_shader_parameter("angle", shader_angle)

	var ph: float = _skin.physical_height if _skin else 180.0
	var tan_elev := tan(deg_to_rad(max(elevation, MIN_ELEVATION)))
	var shadow_pixels := ph / tan_elev
	shadow_pixels = clamp(shadow_pixels, MIN_SHADOW_LENGTH, MAX_SHADOW_LENGTH)

	var sdf_scale: float = ProjectSettings.get_setting(
		"rendering/2d/sdf/scale", 0.5)
	_material.set_shader_parameter("max_dist", shadow_pixels * sdf_scale)

func _update_polygon() -> void:
	var pw: float = _skin.physical_width if _skin else 66.0
	var ph: float = _skin.physical_height if _skin else 180.0

	var elevation := _get_current_elevation()
	var shadow_dir := _get_shadow_direction()

	var tan_elev := tan(deg_to_rad(max(elevation, MIN_ELEVATION)))
	var shadow_len := ph / tan_elev
	shadow_len = clamp(shadow_len, MIN_SHADOW_LENGTH, MAX_SHADOW_LENGTH)

	var dx := shadow_dir.x * shadow_len
	var dy := shadow_dir.y * shadow_len

	var margin := BASE_MARGIN + (1.0 - _softness) * shadow_len * 0.1
	var half_w := pw / 2.0 + margin

	polygon = PackedVector2Array([
		Vector2(-half_w, -margin),
		Vector2(half_w, -margin),
		Vector2(half_w + dx, dy + margin),
		Vector2(-half_w + dx, dy + margin),
	])

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
