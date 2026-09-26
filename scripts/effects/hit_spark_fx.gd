extends Node2D

## 接触点特效两层本体（B4.7 R4/R5，零美术）：
## · 火花层 CPUParticles2D——无贴图方块粒（不设 texture），one_shot+
##   explosiveness=1.0 一次性喷出，方向沿 dir（受击→攻击来向）；
## · 闪光层 Polygon2D——16 顶点程序圆，Tween 走 scale 0.3→1.2 / alpha 1→0
##   （0.08s 短促"啪"），随后 await 粒子寿命毕自毁。
## 生命周期：闪 0.08s → 等 (lifetime−0.08) → queue_free；表挂本体 tween /
## create_timer（节点 free 时引擎自动回收，无泄漏）。
## 观测通道（契约 E 流）：`preset` 卡引用 + `particles`/`flash` 子节点引用
## ——E5 风格路由断言"经节点属性"由此供证（风格名回执由 Events 侧采集）。

## 闪光时长（秒，单一出处；R8/契约折算拍数用）
const FLASH_DURATION := 0.08
const FLASH_SCALE_FROM := 0.3
const FLASH_SCALE_TO := 1.2
const CIRCLE_RADIUS := 6.0
const CIRCLE_SEGMENTS := 16

var preset: HitSparkPreset = null
var particles: CPUParticles2D = null
var flash: Polygon2D = null


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
	_build_flash()
	_schedule_death()


func _build_particles() -> void:
	particles = CPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true
	particles.amount = preset.amount
	particles.lifetime = preset.lifetime
	particles.initial_velocity_min = preset.speed_min
	particles.initial_velocity_max = preset.speed_max
	particles.gravity = preset.gravity
	# direction 已是本节点局部 +x（configure 旋转了本体），粒子沿局部右向喷出
	particles.direction = Vector2.RIGHT
	var grad := Gradient.new()
	grad.colors = PackedColorArray([preset.color_hot, preset.color_cool])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	particles.color_ramp = grad
	add_child(particles)


func _build_flash() -> void:
	flash = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in CIRCLE_SEGMENTS:
		var ang := TAU * float(i) / float(CIRCLE_SEGMENTS)
		pts.append(Vector2.from_angle(ang) * CIRCLE_RADIUS)
	flash.polygon = pts
	flash.color = preset.flash_color
	flash.scale = Vector2.ONE * FLASH_SCALE_FROM
	add_child(flash)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(flash, "scale",
			Vector2.ONE * FLASH_SCALE_TO * preset.flash_scale, FLASH_DURATION)
	tw.tween_property(flash, "modulate:a", 0.0, FLASH_DURATION)


func _schedule_death() -> void:
	var wait := maxf(preset.lifetime, FLASH_DURATION)
	var timer := get_tree().create_timer(wait)
	timer.timeout.connect(_on_lifetime_over)


func _on_lifetime_over() -> void:
	if is_instance_valid(self):
		queue_free()
