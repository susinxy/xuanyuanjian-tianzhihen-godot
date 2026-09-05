extends Node

## 共享阴影柔边合成器（方案 A）。默认关闭 → 关闭时各角色维持现状实心阴影，本节点几乎不工作。
## 开启时：各 character_shadow_controller 把投影多边形塞进 shadow_world(独立 World2D)，
## 经 subShadow → H 模糊两级离屏，再由一张主世界 Sprite2D(z=composite_z) 的材质做末趟 V 模糊合成回场景，
## 从而把"每角色硬边多边形"变成"一帧共享的柔和影层"。缓冲成本≈两趟全屏模糊，与角色数基本无关。
const BLUR_SHADER := preload("res://shaders/shadow_blur.gdshader")
const MAX_RT_DIM := 8192
const SCALES := [0.5, 1.0, 2.0, 4.0, 8.0]

## 数据可配：整体开关 + 模糊半径 + 缓冲分辨率档 + 合成层 z
@export var enabled := false
@export var radius := 2.0
@export var scale_idx := 1
## 全屏合成图的世界 z。柔边是一整张全屏 Sprite，只有一个 z，只能"整层压在某个 z 上/某
## 个 z 下"。测试场景 Background 在 z=-10、角色在 z=0，故 -1 恰好落在中间。真实 base_stage
## 的 Background z=5 / Level(角色) z=15，需把此值设为介于二者之间（如 6），否则会被背景埋掉。
@export var composite_z := -1

var shadow_world: Node2D

var _sub_shadow: SubViewport
var _sub_h: SubViewport
var _shadow_cam: Camera2D
var _h_rect: ColorRect
var _final: Sprite2D          # 世界空间 Sprite，其材质做末趟 V 模糊并采样 _sub_h
var _final_mat: ShaderMaterial

var _full := Vector2i(1280, 720)
var _buf := Vector2i(640, 360)

func _ready() -> void:
	_sub_shadow = _mk_vp("SubShadow")
	_sub_shadow.world_2d = World2D.new()
	add_child(_sub_shadow)
	shadow_world = Node2D.new()
	shadow_world.name = "ShadowWorld"
	_sub_shadow.add_child(shadow_world)
	_shadow_cam = Camera2D.new()
	_shadow_cam.name = "ShadowCam"
	_sub_shadow.add_child(_shadow_cam)
	_shadow_cam.enabled = true
	_shadow_cam.make_current()

	_sub_h = _mk_vp("SubH")
	add_child(_sub_h)
	_h_rect = ColorRect.new()
	_h_rect.name = "HBlur"
	_h_rect.material = _mk_blur(Vector2(1, 0))
	_sub_h.add_child(_h_rect)

	# 世界空间合成 Sprite：自带末趟 V 模糊材质，采样 _sub_h（两级离屏 + 合成趟做 V，省一张 RT）
	_final_mat = _mk_blur(Vector2(0, 1))
	_final = Sprite2D.new()
	_final.name = "SoftShadowComposite"
	_final.z_index = composite_z
	_final.material = _final_mat
	_final.centered = true
	add_child(_final)

	_apply_params()               # 初始参数（首帧 _process 会按区域/视口重算尺寸）
	process_priority = 100            # 离屏渲染在本帧所有 _process 之后统一发生，故此处顺序不敏感

func _mk_vp(nm: String) -> SubViewport:
	var v := SubViewport.new()
	v.name = nm
	v.transparent_bg = true
	v.disable_3d = true
	v.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return v

func _set_buffers_update(mode: int) -> void:
	for sv in [_sub_shadow, _sub_h]:
		(sv as Viewport).render_target_update_mode = mode

func _mk_blur(d: Vector2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = BLUR_SHADER
	m.set_shader_parameter("dir", d)
	return m

## 启用的 ShadowRegion 世界矩形并集；无 → 空 Rect2
func _region_union() -> Rect2:
	var u := Rect2()
	for n in get_tree().get_nodes_in_group(&"shadow_region"):
		if n.has_method("world_rect"):
			var r: Rect2 = n.world_rect()
			if r.has_area():
				u = r if not u.has_area() else u.merge(r)
	return u

## 按目标区域 R（ShadowRegion 并集，或当前相机视矩形=旧全屏行为）
## 同步缓冲尺寸、离屏相机取景、合成 Sprite 的贴回位置/缩放
func _sync(cam: Camera2D) -> void:
	var center := cam.global_position
	var size_world := Vector2(float(_full.x) / cam.zoom.x, float(_full.y) / cam.zoom.y)
	var reg := _region_union()
	if reg.has_area():
		center = reg.get_center()
		size_world = reg.size
	var s: float = SCALES[clampi(scale_idx, 0, SCALES.size() - 1)]
	var w := size_world.x * cam.zoom.x * s
	var h := size_world.y * cam.zoom.y * s
	var m: float = maxf(w, h)
	if m > MAX_RT_DIM:
		var k := float(MAX_RT_DIM) / m
		w *= k
		h *= k
	var nbuf := Vector2i(maxi(int(w), 1), maxi(int(h), 1))
	if nbuf != _buf:
		_buf = nbuf
		for sv in [_sub_shadow, _sub_h]:
			(sv as Viewport).size = _buf
		_h_rect.size = Vector2(_buf)
		_apply_params()
	# 离屏相机取景 = 恰好世界区域 R（区域外阴影被裁掉）
	_shadow_cam.global_position = center
	_shadow_cam.zoom = Vector2(float(_buf.x) / size_world.x, float(_buf.y) / size_world.y)
	_shadow_cam.rotation = cam.rotation
	# 合成 Sprite 贴回 = 覆盖同一块区域（尺寸/位置由 R 决定；观感与缓冲分辨率无关）
	_final.texture = _sub_h.get_texture()
	_final.visible = true
	_final.position = center
	_final.scale = Vector2(size_world.x / float(_buf.x), size_world.y / float(_buf.y))

func _apply_params() -> void:
	var texel := Vector2(1.0 / float(_buf.x), 1.0 / float(_buf.y))
	var chain := [
		[_h_rect.material, _sub_shadow.get_texture()],
		[_final_mat, _sub_h.get_texture()],
	]
	for pair in chain:
		var m: ShaderMaterial = pair[0]
		m.set_shader_parameter("src", pair[1])
		m.set_shader_parameter("texel_size", texel)
		m.set_shader_parameter("radius", radius)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("soft_edge_toggle"):
		set_enabled(not enabled)
		print("[ShadowSoftEdge] enabled=", enabled)
	var vs := get_viewport().get_visible_rect().size
	_full = Vector2i(int(vs.x), int(vs.y))
	var cam := get_viewport().get_camera_2d()
	if not enabled:
		_final.visible = false
		shadow_world.visible = false
		_set_buffers_update(SubViewport.UPDATE_ONCE)   # 关闭→冻结离屏，几乎零成本
		return
	if cam == null:
		return
	_set_buffers_update(SubViewport.UPDATE_ALWAYS)
	shadow_world.visible = true
	_final.z_index = composite_z
	_sync(cam)

## 供外部/UI 运行时切换
func set_enabled(v: bool) -> void:
	enabled = v
