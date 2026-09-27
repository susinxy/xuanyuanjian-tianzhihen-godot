extends Node2D

## 接触点特效两层本体（B4.7 R4/R5，零美术；T5 观感升级波）：
## · 火花层 CPUParticles2D——**运行时程序化拖尾贴图**（3×6 短桩光针，
##   Image 手画零文件）+ `particle_flag_align_y` 使针尖沿速度方向（本构建
##   该特性实名 particle_flag_align_y，探针实锤——texture_align 系幻影名），
##   加色混合 canvas_item shader（LDR 判例族：乘法调制只暗不亮，发光走合成器
##   通道，混白 shader 先例同款惰性 static 构建）；喷散布角由参数卡供；
##   T5b 调档：阻尼 300-420 速生速灭（长命+低阻尼=碎屑飘感元凶）。
## · 闪光层 Line2D **毛刺空心环双层**（T6：暗底衬+亮环共享抖动点列，高
##   对比=质量感），scale 0.35→~1.9 + alpha 1→0 短促"啪"。
## · 烫芯层 Polygon2D 实心圆加色压顶 0.06s 炸散（白芯彩尾的芯位）。
## · 碎块层第二条 CPUParticles2D：少颗大、半速、倍重力、弱阻尼——
##   细火星"擦过"、碎块"砸出去"，双层分布=实感（chunk_amount=0 卡免）。
## 生命周期：闪 0.08s → 等 (lifetime−0.08) → queue_free；timer 挂树，
## 节点 free 时引擎自动回收，无泄漏。
## 观测通道（契约 E 流）：`preset` 卡引用 + `particles` 属性搬运卡参
## （gravity/amount 断言由此供证；flash 类型不锁）。

## 闪光时长（秒，单一出处；R8/契约折算拍数用）
const FLASH_DURATION := 0.08
const FLASH_SCALE_FROM := 0.35
const FLASH_SCALE_TO := 1.9
const RING_RADIUS := 7.0
const RING_SEGMENTS := 24
const RING_WIDTH := 2.5
## 拖尾针贴图尺寸（宽×高，纵向=对齐方向；T5b 收短：14 行长针在
## 用户 F5 读作"被打碎的物体飞散"，6 行短桩读作"火星迸溅"）
const STREAK_W := 3
const STREAK_H := 6

## 加色混合透射 shader（惰性构建一次全体复用；热重载丢 static 自动重建，
## 混白闪件同款主帧单线程判例）
static var _add_shader: Shader
## 程序化拖尾贴图（惰性构建一次全体复用）
static var _streak_tex: ImageTexture

## 烫芯参数（白芯彩尾的"芯"位：0.06s 高亮小核炸散）
const CORE_DURATION := 0.06
const CORE_RADIUS := 3.5
const CORE_SCALE_FROM := 0.4
const CORE_SCALE_TO := 1.5

var preset: HitSparkPreset = null
var particles: CPUParticles2D = null
var chunks: CPUParticles2D = null
var core: Polygon2D = null
var flash: Line2D = null
var flash_shadow: Line2D = null


## 装配入口：add_child 前调（configure→入树，_ready 用已到位的参数建形）。
func configure(p: HitSparkPreset, dir: Vector2) -> void:
	preset = p
	position = Vector2.ZERO
	rotation = dir.angle()


func _ready() -> void:
	if preset == null:
		push_warning("HitSparkFx 未 configure 即入树（缺参数卡），自毁")
		queue_free()
		return
	_build_particles()
	_build_chunks()
	_build_flash()
	_build_core()
	_schedule_death()


func _build_particles() -> void:
	particles = CPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true
	particles.amount = preset.amount
	particles.lifetime = preset.lifetime
	particles.lifetime_randomness = 0.25
	particles.initial_velocity_min = preset.speed_min
	particles.initial_velocity_max = preset.speed_max
	# 本构建无持续速度通道（探针实锤 velocity_min 系幻影名），收速手感全走 damping
	particles.damping_min = 300.0
	particles.damping_max = 420.0
	particles.gravity = preset.gravity
	# direction 已是本节点局部 +x（configure 旋转了本体），粒子沿局部右向喷出
	particles.direction = Vector2.RIGHT
	particles.spread = preset.spread_deg
	# 针形贴图纵轴转向速度方向（本构建实名 particle_flag_align_y）
	particles.particle_flag_align_y = true
	particles.texture = _get_streak_tex()
	var mat := ShaderMaterial.new()
	mat.shader = _get_add_shader()
	particles.material = mat
	var grad := Gradient.new()
	grad.colors = PackedColorArray([preset.color_hot, preset.color_cool])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	particles.color_ramp = grad
	# 尺寸随机小针（拖尾感靠贴图形状，不靠放大）
	particles.scale_amount_min = 0.4
	particles.scale_amount_max = 0.8
	add_child(particles)


## 碎块层：少量大颗粒、半速出膛、倍重下坠、弱阻尼——细火星是"擦过"，
## 碎块是"砸出去"，双层速度/寿命分布=质量感（chunk_amount=0 的卡无此层）
func _build_chunks() -> void:
	if preset.chunk_amount <= 0:
		return
	chunks = CPUParticles2D.new()
	chunks.one_shot = true
	chunks.explosiveness = 1.0
	chunks.emitting = true
	chunks.amount = preset.chunk_amount
	chunks.lifetime = preset.lifetime + 0.08
	chunks.initial_velocity_min = preset.speed_min * 0.5
	chunks.initial_velocity_max = preset.speed_max * 0.55
	chunks.damping_min = 60.0
	chunks.damping_max = 110.0
	chunks.gravity = preset.gravity * 2.2
	chunks.direction = Vector2.RIGHT
	chunks.spread = minf(preset.spread_deg * 1.25, 180.0)
	chunks.particle_flag_align_y = true
	chunks.texture = _get_streak_tex()
	var mat := ShaderMaterial.new()
	mat.shader = _get_add_shader()
	chunks.material = mat
	var grad := Gradient.new()
	grad.colors = PackedColorArray([preset.color_hot, preset.color_cool])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	chunks.color_ramp = grad
	chunks.scale_amount_min = 0.5 * preset.chunk_scale_mult
	chunks.scale_amount_max = 0.8 * preset.chunk_scale_mult
	add_child(chunks)


## 毛刺环双层（T6）：暗底衬先加（更宽）、亮环后加（压上）——共享同一
## 抖动点列保证轮廓咬合；两层同 tween 保持形状同步
func _build_flash() -> void:
	var pts := PackedVector2Array()
	for i in RING_SEGMENTS:
		var ang := TAU * float(i) / float(RING_SEGMENTS)
		pts.append(Vector2.from_angle(ang)
				* RING_RADIUS * randf_range(0.72, 1.28))
	var jit_rot := randf_range(0.0, TAU)
	var jit_w := randf_range(RING_WIDTH * 0.8, RING_WIDTH * 1.3)
	flash_shadow = Line2D.new()
	flash_shadow.points = pts
	flash_shadow.closed = true
	flash_shadow.width = jit_w + 2.4
	flash_shadow.rotation = jit_rot
	flash_shadow.default_color = preset.ring_dark
	flash_shadow.material = _ring_mat()
	flash_shadow.scale = Vector2.ONE * FLASH_SCALE_FROM
	add_child(flash_shadow)
	flash = Line2D.new()
	flash.points = pts
	flash.closed = true
	flash.width = jit_w
	flash.rotation = jit_rot
	flash.default_color = preset.flash_color
	flash.material = _ring_mat()
	flash.scale = Vector2.ONE * FLASH_SCALE_FROM
	add_child(flash)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(flash, "scale",
			Vector2.ONE * FLASH_SCALE_TO * preset.flash_scale, FLASH_DURATION)
	tw.tween_property(flash, "modulate:a", 0.0, FLASH_DURATION * 1.4)
	tw.tween_property(flash_shadow, "scale",
			Vector2.ONE * FLASH_SCALE_TO * preset.flash_scale * 1.06, FLASH_DURATION)
	tw.tween_property(flash_shadow, "modulate:a", 0.0, FLASH_DURATION * 1.4)


## 烫芯：实心小圆（非环）加色压顶，0.06s 内从 0.4 放大到 1.5 并炸散——
## 命中"那一下"的锚点，环与火星都是它的余波
func _build_core() -> void:
	core = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 12:
		var ang := TAU * float(i) / 12.0
		pts.append(Vector2.from_angle(ang) * CORE_RADIUS)
	core.polygon = pts
	core.color = preset.core_color
	core.material = _ring_mat()
	core.scale = Vector2.ONE * CORE_SCALE_FROM
	add_child(core)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(core, "scale", Vector2.ONE * CORE_SCALE_TO, CORE_DURATION)
	tw.tween_property(core, "modulate:a", 0.0, CORE_DURATION * 1.3)


func _schedule_death() -> void:
	var wait := maxf(preset.lifetime + (0.08 if preset.chunk_amount > 0 else 0.0),
			FLASH_DURATION)
	var timer := get_tree().create_timer(wait)
	timer.timeout.connect(_on_lifetime_over)


func _on_lifetime_over() -> void:
	if is_instance_valid(self):
		queue_free()


## 加色混合环件材质（环也要发光；与粒共用透射 shader）
func _ring_mat() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _get_add_shader()
	return mat


static func _get_add_shader() -> Shader:
	if _add_shader == null:
		_add_shader = Shader.new()
		_add_shader.code = "\n".join([
			"shader_type canvas_item;",
			"blend_mode add;",
			"",
			"void fragment() {",
			"\tCOLOR = COLOR * texture(TEXTURE, UV);",
			"}",
		])
	return _add_shader


static func _get_streak_tex() -> ImageTexture:
	if _streak_tex == null:
		var img := Image.create(STREAK_W, STREAK_H, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var mid := float(STREAK_H - 1) * 0.5
		for y in STREAK_H:
			# 纵向纺锤形：中心亮、两端 alpha 收 0（针尖针尾收势）
			var t := 1.0 - absf(float(y) - mid) / (mid + 1.0)
			var row_a := t * t
			for x in STREAK_W:
				var xa := 1.0 if x == STREAK_W / 2 else 0.45
				img.set_pixel(x, y, Color(1, 1, 1, row_a * xa))
		_streak_tex = ImageTexture.create_from_image(img)
	return _streak_tex
