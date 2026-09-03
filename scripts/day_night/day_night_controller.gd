class_name DayNightController
extends Node
## 场景内昼夜控制器
##
## 添加到每个 stage 场景，引用场景中的光照节点，
## 监听 DayNightManager 信号，驱动：
## - CanvasModulate 颜色插值（场景整体色调）
## - DirectionalLight2D 旋转/能量/颜色插值（光源方向与强度）
## - PointLight2D 数组开关（灯笼/火把等环境点光源）
##
## 注意：DirectionalLight2D 必须 shadow/enabled = false，
## 阴影由角色身上的 ShadowBox (LightOccluder2D) + SDF shader 负责，
## 不能开启 DirectionalLight2D 的内置阴影（会双重阴影且性能差）。

## 场景时间配置（SceneTimeData 实例，使用 Resource 类型避免 class_name 注册时序问题）
@export var scene_time_data: Resource

## 场景整体色调节点路径（在 _runtime_ready 中解析为实际节点）
@export var canvas_modulate_path: NodePath

## 主方向光源路径（在 _runtime_ready 中解析为实际节点）
@export var directional_light_path: NodePath

var canvas_modulate: CanvasModulate = null
var directional_light: DirectionalLight2D = null

## 环境点光源数组（灯笼/火把等，DUSK/NIGHT 自动点亮）
## 使用 NodePath 存储，在 _runtime_ready() 中解析为实际节点
@export var point_lights_paths: Array[NodePath] = []
var point_lights: Array[PointLight2D] = []

func _ready() -> void:
	if not Engine.is_editor_hint():
		_runtime_ready()

func _runtime_ready() -> void:
	# 解析节点路径
	if canvas_modulate_path:
		canvas_modulate = get_node_or_null(canvas_modulate_path)
	if directional_light_path:
		directional_light = get_node_or_null(directional_light_path)
	
	# 解析 NodePath 为实际 PointLight2D 节点
	for path in point_lights_paths:
		var light = get_node_or_null(path)
		if light is PointLight2D:
			point_lights.append(light)
	
	var manager = get_node_or_null("/root/DayNightManager")
	if not manager:
		push_warning("DayNightController: DayNightManager autoload 未找到")
		return
	
	manager.phase_transitioning.connect(_on_phase_transitioning)
	manager.override_applied.connect(_on_override_applied)
	manager.override_removed.connect(_on_override_removed)
	manager.enter_scene(scene_time_data)

func _on_phase_transitioning(from_phase: int, to_phase: int, progress: float) -> void:
	if not scene_time_data:
		return
	
	# CanvasModulate 颜色插值
	if canvas_modulate:
		var from_color: Color = scene_time_data.phase_colors.get(from_phase, Color.WHITE)
		var to_color: Color = scene_time_data.phase_colors.get(to_phase, Color.WHITE)
		canvas_modulate.color = from_color.lerp(to_color, progress)
	
	# DirectionalLight2D 参数插值
	if directional_light:
		var from_rot: float = scene_time_data.phase_light_rotations.get(from_phase, -45.0)
		var to_rot: float = scene_time_data.phase_light_rotations.get(to_phase, -45.0)
		directional_light.rotation_degrees = lerp_angle(from_rot, to_rot, progress)
		
		var from_energy: float = scene_time_data.phase_light_energies.get(from_phase, 1.0)
		var to_energy: float = scene_time_data.phase_light_energies.get(to_phase, 1.0)
		directional_light.energy = lerp(from_energy, to_energy, progress)
		
		var from_color: Color = scene_time_data.phase_light_colors.get(from_phase, Color.WHITE)
		var to_color: Color = scene_time_data.phase_light_colors.get(to_phase, Color.WHITE)
		directional_light.color = from_color.lerp(to_color, progress)
	
	# PointLight2D 开关：目标相位启用时开启，否则关闭
	for light in point_lights:
		if light == null:
			continue
		var should_enable: bool = to_phase in scene_time_data.point_lights_enabled_phases
		light.enabled = should_enable

func _on_override_applied(override: LightingOverride) -> void:
	var tween := create_tween()
	if canvas_modulate:
		tween.parallel().tween_property(
			canvas_modulate, "color", override.color, override.transition_duration
		)
	if directional_light:
		tween.parallel().tween_property(
			directional_light, "rotation_degrees",
			override.light_rotation, override.transition_duration
		)
		tween.parallel().tween_property(
			directional_light, "energy",
			override.light_energy, override.transition_duration
		)
		tween.parallel().tween_property(
			directional_light, "color",
			override.light_color, override.transition_duration
		)

func _on_override_removed() -> void:
	# 恢复到当前相位的默认值
	if not scene_time_data:
		return
	var manager = get_node_or_null("/root/DayNightManager")
	if not manager:
		return
	var current_phase: int = manager.current_phase
	var tween := create_tween()
	if canvas_modulate:
		var target_color: Color = scene_time_data.phase_colors.get(
			current_phase, Color.WHITE
		)
		tween.parallel().tween_property(canvas_modulate, "color", target_color, 1.0)
	if directional_light:
		var target_rot: float = scene_time_data.phase_light_rotations.get(
			current_phase, -45.0
		)
		var target_energy: float = scene_time_data.phase_light_energies.get(
			current_phase, 1.0
		)
		var target_color: Color = scene_time_data.phase_light_colors.get(
			current_phase, Color.WHITE
		)
		tween.parallel().tween_property(
			directional_light, "rotation_degrees", target_rot, 1.0
		)
		tween.parallel().tween_property(
			directional_light, "energy", target_energy, 1.0
		)
		tween.parallel().tween_property(
			directional_light, "color", target_color, 1.0
		)
