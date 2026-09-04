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

	_refresh_sizes(true)
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

func _eff_scale() -> float:
	if _full.x <= 0:
		return 1.0
	return float(_buf.x) / float(_full.x)

func _calc_buf() -> Vector2i:
	var s: float = SCALES[clampi(scale_idx, 0, SCALES.size() - 1)]
	var w := float(_full.x) * s
	var h := float(_full.y) * s
	var m: float = max(w, h)
	if m > MAX_RT_DIM:
		var k := float(MAX_RT_DIM) / m
		w *= k
		h *= k
	return Vector2i(maxi(int(w), 1), maxi(int(h), 1))

func _refresh_sizes(force: bool) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var vs := get_viewport().get_visible_rect().size
	var nf := Vector2i(int(vs.x), int(vs.y))
	if force or nf != _full:
		_full = nf
		_buf = _calc_buf()
		for sv in [_sub_shadow, _sub_h]:
			(sv as Viewport).size = _buf
		_h_rect.size = Vector2(_buf)
		_apply_params()

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
	var cam := get_viewport().get_camera_2d()
	_refresh_sizes(false)
	if not enabled:
		_final.visible = false
		shadow_world.visible = false
		_set_buffers_update(SubViewport.UPDATE_ONCE)   # 关闭→冻结离屏，几乎零成本
		return
	if cam == null:
		return
	_set_buffers_update(SubViewport.UPDATE_ALWAYS)
	shadow_world.visible = true
	# 相机镜像（含分辨率放大），保持世界取景与主屏一致
	_shadow_cam.global_position = cam.global_position
	_shadow_cam.zoom = cam.zoom * _eff_scale()
	_shadow_cam.rotation = cam.rotation
	# 合成 Sprite：贴图给 UV，材质对 _sub_h(横模糊结果) 做末趟纵模糊
	_final.z_index = composite_z
	_final.texture = _sub_h.get_texture()
	_final.visible = true
	_final.position = cam.global_position
	var zoom: float = cam.zoom.x
	var eff: float = _eff_scale()
	if zoom > 0.0 and eff > 0.0:
		_final.scale = Vector2(1.0 / (zoom * eff), 1.0 / (zoom * eff))

## 供外部/UI 运行时切换
func set_enabled(v: bool) -> void:
	enabled = v
