extends Node2D

## 角色阴影控制器
## 由 QuiverCharacter._ready() 动态创建
## 管理：读取 ShadowBox polygon → 沿光线投影到地面 → Polygon2D 渲染

const SHADOW_SHADER_PATH := "res://shaders/shadow_polygon.gdshader"
const DEBUG_OVERLAY_SCRIPT := preload("res://scripts/shadow_debug_overlay.gd")
const DEBUG_ENABLED := true
const MIN_ELEVATION := 5.0
const DEFAULT_ELEVATION := 45.0
const MAX_FADE_HEIGHT := 400.0

static var _shared_material: ShaderMaterial = null

var _skin: QuiverCharacterSkin
var _day_night: Node
var _shadow_polygon: Polygon2D
var _debug_overlay: Node2D = null
var _current_elevation: float = DEFAULT_ELEVATION
var _current_azimuth: float = -45.0

func setup(skin: QuiverCharacterSkin) -> void:
	_skin = skin
	_day_night = get_node_or_null("/root/DayNightManager")
	_setup_shared_material()
	_create_shadow_polygon()
	if DEBUG_ENABLED:
		_create_debug_overlay()
	_update_shadow()

func _setup_shared_material() -> void:
	if _shared_material == null:
		_shared_material = ShaderMaterial.new()
		_shared_material.shader = preload(SHADOW_SHADER_PATH)
		_shared_material.set_shader_parameter("shadow_color", Color(0.0, 0.0, 0.05, 0.55))

func _create_shadow_polygon() -> void:
	_shadow_polygon = Polygon2D.new()
	_shadow_polygon.name = "ShadowPolygon"
	_shadow_polygon.material = _shared_material
	add_child(_shadow_polygon)

func _create_debug_overlay() -> void:
	_debug_overlay = Node2D.new()
	_debug_overlay.name = "ShadowDebugOverlay"
	_debug_overlay.z_index = 1
	_debug_overlay.set_script(DEBUG_OVERLAY_SCRIPT)
	add_child(_debug_overlay)

func _process(_delta: float) -> void:
	_update_shadow()

func _update_shadow() -> void:
	if not _skin:
		return
	# 1. 投影 ShadowBox polygon 到地面（锚定在脚部）
	var projected := _project_polygon_to_ground()
	if projected.size() > 0:
		_shadow_polygon.polygon = projected
	# 2. 跳跃时整体移动 ShadowRenderer（沿光线方向，正向位移）
	var jump_height: float = _skin.base_height if _skin else 0.0
	var elevation := _get_current_elevation()
	var shadow_dir := _get_shadow_direction()
	var tan_elev := tan(deg_to_rad(max(elevation, MIN_ELEVATION)))
	var shadow_displacement := jump_height / tan_elev
	position = Vector2(shadow_displacement * shadow_dir.x, shadow_displacement * shadow_dir.y)
	# 3. 跳跃淡出
	var fade: float = 1.0 - clamp(jump_height / MAX_FADE_HEIGHT, 0.0, 0.8)
	_shadow_polygon.modulate.a = fade
	# 4. 更新调试覆盖层
	if _debug_overlay:
		_debug_overlay.update_polygon(projected)

## 将 ShadowBox polygon 投影到地面
## 坐标空间：AnimatedSprite2D 本地 → 角色空间
## 投影原理：沿光线方向压扁 polygon，锚定在脚部位置
## 使用 Transform2D 矩阵一次性完成所有顶点的仿射变换
## 返回投影后的顶点数组（PackedVector2Array）
func _project_polygon_to_ground() -> PackedVector2Array:
	var sprite := _skin.get_node_or_null("AnimatedSprite2D")
	if not sprite:
		return PackedVector2Array()
	var shadow_box := sprite.get_node_or_null("ShadowBox")
	if not shadow_box or not shadow_box is LightOccluder2D:
		return PackedVector2Array()
	var occ: LightOccluder2D = shadow_box
	if not occ.occluder:
		return PackedVector2Array()
	var polygon: PackedVector2Array = occ.occluder.polygon
	if polygon.size() < 3:
		return PackedVector2Array()

	var sprite_pos: Vector2 = sprite.position
	var elevation := _get_current_elevation()
	var shadow_dir := _get_shadow_direction()
	var tan_elev := tan(deg_to_rad(max(elevation, MIN_ELEVATION)))

	# 用 Transform2D 批量平移（C++ 实现，更快）
	var translate_transform := Transform2D.IDENTITY.translated(sprite_pos)
	var char_polygon := translate_transform * polygon

	# 找到脚部位置（角色空间中 Y 最大的点）
	var foot_y: float = -INF
	for v in char_polygon:
		foot_y = max(foot_y, v.y)

	# 构建投影变换矩阵
	# 投影公式：
	#   projected.x = v.x + (foot_y - v.y) / tan_elev * shadow_dir.x
	#   projected.y = foot_y + (foot_y - v.y) / tan_elev * shadow_dir.y
	var basis_x := Vector2(1, 0)
	var basis_y := Vector2(-shadow_dir.x / tan_elev, -shadow_dir.y / tan_elev)
	var origin := Vector2(foot_y * shadow_dir.x / tan_elev, foot_y + foot_y * shadow_dir.y / tan_elev)
	var transform := Transform2D(basis_x, basis_y, origin)

	return transform * char_polygon

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
