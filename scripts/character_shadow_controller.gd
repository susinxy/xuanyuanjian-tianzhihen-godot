extends Node2D

## 角色阴影控制器
## 由 QuiverCharacter._ready() 动态创建
## 管理：读取 ShadowBox polygon → 沿光线投影到地面 → Polygon2D 渲染

const SHADOW_SHADER_PATH := "res://shaders/shadow_polygon.gdshader"
const DEBUG_OVERLAY_SCRIPT := preload("res://scripts/shadow_debug_overlay.gd")
const DEBUG_ENABLED := false
const MIN_ELEVATION := 5.0
const DEFAULT_ELEVATION := 45.0
const MAX_FADE_HEIGHT := 400.0
## 距离衰减：影子远端顶点的 alpha（近端恒为 1.0，远端 = 此值；随俯视角/高度可调观感）
const FAR_END_ALPHA := 0.3

static var _shared_material: ShaderMaterial = null

var _skin: QuiverCharacterSkin
var _day_night: Node
var _shadow_polygon: Polygon2D
var _solid_extras: Array[Polygon2D] = []   # 区域裁剪后实心阴影的第 2..N 块（对象池）
var _debug_overlay: Node2D = null
var _soft_edge: Node = null          # 共享柔边合成器（autoload ShadowSoftEdge）
var _proxies: Array[Polygon2D] = []  # 开启软边时，注入合成器 shadow_world 的代理多边形池
var _current_elevation: float = DEFAULT_ELEVATION
var _current_azimuth: float = -45.0

func setup(skin: QuiverCharacterSkin) -> void:
	_skin = skin
	_day_night = get_node_or_null("/root/DayNightManager")
	_soft_edge = get_node_or_null("/root/ShadowSoftEdge")
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

func _exit_tree() -> void:
	# 代理挂在 autoload 的 shadow_world 下，不随角色释放 → 必须手动回收
	for pr in _proxies:
		pr.queue_free()
	_proxies.clear()

func _update_shadow() -> void:
	if not _skin:
		return
	# 1. 投影 ShadowBox polygon 到地面（锚定在脚部）+ 逐顶点距离衰减 alpha
	var data := _project_polygon_to_ground()
	var projected: PackedVector2Array = data.get("polygon", PackedVector2Array())
	var colors: PackedColorArray = data.get("colors", PackedColorArray())
	# 2. 跳跃时整体移动 ShadowRenderer（沿光线方向，正向位移）
	var jump_height: float = _skin.base_height if _skin else 0.0
	var elevation := _get_current_elevation()
	var shadow_dir := _get_shadow_direction()
	var tan_elev := tan(deg_to_rad(max(elevation, MIN_ELEVATION)))
	var shadow_displacement := jump_height / tan_elev
	position = Vector2(shadow_displacement * shadow_dir.x, shadow_displacement * shadow_dir.y)
	# 3. 跳跃淡出
	var fade: float = 1.0 - clamp(jump_height / MAX_FADE_HEIGHT, 0.0, 0.8)

	# 4. 区域裁剪（无 ShadowRegion 时 = 原样单块，与旧行为一致）
	var pieces := _clip_pieces(projected, colors, data)

	var soft_on: bool = (_soft_edge != null) and _soft_edge.enabled
	if soft_on:
		# 开启软边：实心隐藏，多块代理注入合成器离屏世界
		_shadow_polygon.visible = false
		for s in _solid_extras:
			s.visible = false
		_apply_proxies(pieces, fade)
	else:
		# 关闭软边：实心路径（含区域裁剪），代理池隐藏
		_hide_proxies()
		_apply_solid(pieces, fade)
	# 5. 更新调试覆盖层
	if _debug_overlay:
		var polys: Array[PackedVector2Array] = []
		for p in pieces:
			polys.append(p["polygon"])
		_debug_overlay.update_polygons(polys)

## 把投影多边形（本地空间）与世界区域求交 → 多块（本地空间 + 重算顶点色）
## 无启用区域 → 原样单块返回（零行为差异）
func _clip_pieces(projected: PackedVector2Array, colors: PackedColorArray, data: Dictionary) -> Array[Dictionary]:
	if projected.size() < 3:
		return []
	var regions := _region_polygons()
	if regions.is_empty():
		return [{"polygon": projected, "colors": colors}]
	var xf := get_global_transform()
	var xf_inv := xf.affine_inverse()
	var world_poly := xf * projected
	var pieces: Array[Dictionary] = []
	for reg in regions:
		for clipped in Geometry2D.intersect_polygons(world_poly, reg):
			if clipped.size() < 3:
				continue
			var local_poly: PackedVector2Array = xf_inv * clipped
			pieces.append({"polygon": local_poly, "colors": _colors_for(local_poly, data)})
	return pieces

## 解析重算顶点色：距离衰减本是"投影前顶点 Y"的函数，对求交新生成的切割顶点同样成立
func _colors_for(local_poly: PackedVector2Array, data: Dictionary) -> PackedColorArray:
	var out := PackedColorArray()
	var xf: Transform2D = data.get("transform", Transform2D.IDENTITY)
	var foot_y: float = data.get("foot_y", 0.0)
	var tan_elev: float = data.get("tan_elev", 1.0)
	var max_offset: float = data.get("max_offset", 0.0)
	if absf(xf.determinant()) < 1e-6:
		# 投影退化（理论上几乎不发生）：全 1 alpha 兜底
		for i in local_poly.size():
			out.append(Color(1.0, 1.0, 1.0, 1.0))
		return out
	var inv := xf.affine_inverse()
	for v in local_poly:
		var src: Vector2 = inv * v
		var t := 0.0
		if max_offset > 0.0001:
			t = clamp(((foot_y - src.y) / tan_elev) / max_offset, 0.0, 1.0)
		var s := smoothstep(0.0, 1.0, t)
		out.append(Color(1.0, 1.0, 1.0, lerpf(1.0, FAR_END_ALPHA, s)))
	return out

func _region_polygons() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for n in get_tree().get_nodes_in_group(&"shadow_region"):
		if n.has_method("world_polygon"):
			var p: PackedVector2Array = n.world_polygon()
			if p.size() >= 3:
				out.append(p)
	return out

func _apply_solid(pieces: Array[Dictionary], fade: float) -> void:
	var need: int = maxi(pieces.size() - 1, 0)
	while _solid_extras.size() < need:
		var p := Polygon2D.new()
		p.name = "ShadowPiece"
		p.material = _shared_material
		add_child(p)
		_solid_extras.append(p)
	if pieces.size() > 0:
		_shadow_polygon.visible = true
		_shadow_polygon.polygon = pieces[0]["polygon"]
		_shadow_polygon.vertex_colors = pieces[0]["colors"]
		_shadow_polygon.modulate.a = fade
	else:
		_shadow_polygon.visible = false
	for i in _solid_extras.size():
		if i < need:
			_solid_extras[i].visible = true
			_solid_extras[i].polygon = pieces[i + 1]["polygon"]
			_solid_extras[i].vertex_colors = pieces[i + 1]["colors"]
			_solid_extras[i].modulate.a = fade
		else:
			_solid_extras[i].visible = false

func _apply_proxies(pieces: Array[Dictionary], fade: float) -> void:
	while _proxies.size() < pieces.size():
		var pr := Polygon2D.new()
		pr.name = "ShadowProxy"
		pr.material = _shared_material
		_soft_edge.shadow_world.add_child(pr)
		_proxies.append(pr)
	var xf := get_global_transform()
	for i in _proxies.size():
		var pr := _proxies[i]
		if i < pieces.size():
			pr.visible = true
			pr.polygon = pieces[i]["polygon"]
			pr.vertex_colors = pieces[i]["colors"]
			pr.modulate.a = fade
			pr.global_transform = xf
		else:
			pr.visible = false

func _hide_proxies() -> void:
	for pr in _proxies:
		pr.visible = false

## 将 ShadowBox polygon 投影到地面
## 坐标空间：AnimatedSprite2D 本地 → 角色空间（经 sprite 完整局部变换：rotation/scale/position 全生效）
## 投影原理：沿光线方向压扁 polygon，锚定在脚部位置
## 使用 Transform2D 矩阵一次性完成所有顶点的仿射变换
## 距离衰减：按各顶点投影偏移量（≈ 离脚底高度）逐帧归一化 → smoothstep → alpha
##          近端(脚底) alpha=1.0，远端(最高点)=FAR_END_ALPHA；GPU 在三角形间插值成渐变
## 返回 { "polygon": PackedVector2Array, "colors": PackedColorArray }（两者顶点顺序/数量一致）
func _project_polygon_to_ground() -> Dictionary:
	var sprite := _skin.get_node_or_null("AnimatedSprite2D")
	if not sprite:
		return {}
	var shadow_box := sprite.get_node_or_null("ShadowBox")
	if not shadow_box or not shadow_box is LightOccluder2D:
		return {}
	var occ: LightOccluder2D = shadow_box
	if not occ.occluder:
		return {}
	var polygon: PackedVector2Array = occ.occluder.polygon
	if polygon.size() < 3:
		return {}

	# sprite.transform 即渲染器实际使用的完整局部变换（rotation/scale/position 组合）
	var sprite_xf: Transform2D = sprite.transform
	var elevation := _get_current_elevation()
	var shadow_dir := _get_shadow_direction()
	var tan_elev := tan(deg_to_rad(max(elevation, MIN_ELEVATION)))

	# 用 Transform2D 批量应用 sprite 的旋转/缩放/平移（C++ 实现，更快）
	# scale=1、rotation=0 时与旧的"仅平移"公式逐位等价
	var char_polygon := sprite_xf * polygon
	# 找到脚部位置（角色空间中 Y 最大的点）
	var foot_y: float = -INF
	for v in char_polygon:
		foot_y = max(foot_y, v.y)

	# 本帧最大投影偏移（离脚底最高的顶点 → 影子最远端）作为归一化基准
	var max_offset := 0.0
	for v in char_polygon:
		var off := (foot_y - v.y) / tan_elev
		if off > max_offset:
			max_offset = off

	# 逐顶点衰减 alpha：offset/max_offset → smoothstep → [1.0 .. FAR_END_ALPHA]
	var colors := PackedColorArray()
	for v in char_polygon:
		var t := 0.0
		if max_offset > 0.0001:
			t = clamp(((foot_y - v.y) / tan_elev) / max_offset, 0.0, 1.0)
		var s := smoothstep(0.0, 1.0, t)
		colors.append(Color(1.0, 1.0, 1.0, lerpf(1.0, FAR_END_ALPHA, s)))

	# 构建投影变换矩阵
	# 投影公式：
	#   projected.x = v.x + (foot_y - v.y) / tan_elev * shadow_dir.x
	#   projected.y = foot_y + (foot_y - v.y) / tan_elev * shadow_dir.y
	var basis_x := Vector2(1, 0)
	var basis_y := Vector2(-shadow_dir.x / tan_elev, -shadow_dir.y / tan_elev)
	var origin := Vector2(foot_y * shadow_dir.x / tan_elev, foot_y + foot_y * shadow_dir.y / tan_elev)
	var transform := Transform2D(basis_x, basis_y, origin)

	return {
		"polygon": transform * char_polygon, "colors": colors,
		"transform": transform, "foot_y": foot_y,
		"tan_elev": tan_elev, "max_offset": max_offset,
	}

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
