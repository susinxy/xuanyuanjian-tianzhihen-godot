extends Node
## 昼夜循环管理器（Autoload 单例）
##
## 职责：
## - 管理全局时间相位状态（DAWN / DAY / DUSK / NIGHT）
## - 处理相位切换和过渡动画（通过信号驱动各场景的 DayNightController）
## - 光照覆盖栈（法术/剧情触发的临时光照变化）
## - 提供光源参数查询 API（供角色阴影控制器等调用）
##
## 注意：本脚本不静态引用 SceneTimeData 类型（避免与 SceneTimeData 形成循环依赖），
## enter_scene() 参数和 _current_scene_data 均使用 Resource 类型。

## 时间相位枚举
enum TimePhase {
	DAWN,   # 黎明
	DAY,    # 白天
	DUSK,   # 黄昏
	NIGHT,  # 夜晚
}

## 相位切换完成信号（过渡动画结束后发出）
signal phase_changed(new_phase: int)
## 相位过渡中信号（过渡期间持续发出，progress 从 0 到 1）
signal phase_transitioning(from_phase: int, to_phase: int, progress: float)
## 光照覆盖应用信号（覆盖栈变化且栈非空时发出）
signal override_applied(override: LightingOverride)
## 光照覆盖全部移除信号
signal override_removed()

## 当前相位（切换时立即更新；视觉过渡由信号驱动）
var current_phase: int = TimePhase.DAY

var _transition_tween: Tween = null
var _transition_generation: int = 0
var _override_stack: Array[Dictionary] = []
var _cycle_tween: Tween = null
# 注意：用 Resource 类型而非 SceneTimeData，避免循环依赖
var _current_scene_data: Resource = null

# 过渡状态（用于光源参数插值，使角色阴影方向在相位过渡时平滑旋转）
var _transition_from_phase: int = -1
var _transition_progress: float = 1.0

# 缓存的插值结果（由 Tween 回调每帧更新，getter 直接返回）
var _interpolated_elevation: float = 45.0
var _interpolated_azimuth: float = -45.0

# ── 公共 API ──

## 进入场景时调用，传入该场景的 SceneTimeData 配置
## 参数用 Resource 类型（避免循环依赖），运行时按 SceneTimeData 使用
func enter_scene(scene_data: Resource) -> void:
	_current_scene_data = scene_data
	stop_cycle()
	transition_to(scene_data.default_phase, scene_data.transition_duration)
	if scene_data.can_cycle:
		_start_auto_cycle(scene_data)

## 切换到目标相位（带过渡动画）
## 过渡期间：
## - phase_transitioning 信号持续发出（驱动 DayNightController 插值光照节点）
## - get_sun_elevation_deg() / get_sun_azimuth_deg() 返回插值后的光源参数
##   （角色阴影控制器每帧读取，阴影方向随之平滑旋转）
func transition_to(target_phase: int, duration: float = 2.0) -> void:
	if _transition_tween:
		_transition_tween.kill()
	_transition_generation += 1
	var my_generation := _transition_generation
	var from_phase := current_phase
	_transition_from_phase = from_phase
	_transition_progress = 0.0
	current_phase = target_phase
	
	# 初始化插值缓存（避免第一帧跳变）
	_interpolated_elevation = _phase_elevation(from_phase)
	if _current_scene_data != null:
		var rotations: Dictionary = _current_scene_data.phase_light_rotations
		_interpolated_azimuth = rotations.get(from_phase, -45.0)
	
	_transition_tween = create_tween()
	_transition_tween.tween_method(
		func(progress: float):
			_transition_progress = progress
			# 预计算插值，确保所有 getter 在同一帧内返回一致的值
			_interpolated_elevation = lerp(_phase_elevation(from_phase), _phase_elevation(target_phase), progress)
			if _current_scene_data != null:
				var rotations: Dictionary = _current_scene_data.phase_light_rotations
				var from_rot: float = rotations.get(from_phase, -45.0)
				var to_rot: float = rotations.get(target_phase, -45.0)
				_interpolated_azimuth = lerp(from_rot, to_rot, progress)
			phase_transitioning.emit(from_phase, target_phase, progress),
		0.0, 1.0, duration
	)
	await _transition_tween.finished
	if my_generation == _transition_generation:
		_transition_progress = 1.0
		phase_changed.emit(target_phase)

## 应用光照覆盖（法术/剧情）
## duration > 0 时，duration 秒后自动移除
## 返回覆盖 ID，可调用 remove_lighting_override() 提前移除
func apply_lighting_override(override: LightingOverride, duration: float = -1.0) -> String:
	var override_id := str(Time.get_ticks_msec())
	_override_stack.push_back({
		"id": override_id,
		"data": override,
		"duration": duration,
		"start_time": Time.get_ticks_msec(),
	})
	_apply_top_override()
	if duration > 0:
		get_tree().create_timer(duration).timeout.connect(
			func(): remove_lighting_override(override_id)
		)
	return override_id

## 移除指定光照覆盖
func remove_lighting_override(override_id: String) -> void:
	_override_stack = _override_stack.filter(func(o): return o.id != override_id)
	_apply_top_override()

## 获取太阳仰角（度）—— 供角色阴影控制器计算阴影长度
## 简化模型：每个相位固定仰角；相位过渡期间返回插值（由 Tween 回调预计算）
func get_sun_elevation_deg() -> float:
	return _interpolated_elevation

## 获取太阳方位角（度）—— 供角色阴影控制器计算阴影方向
## 返回当前相位的 DirectionalLight2D 旋转角度；相位过渡期间返回插值（由 Tween 回调预计算）
## 与阴影系统的映射：shader_angle = fmod(azimuth + 180.0, 360.0)
func get_sun_azimuth_deg() -> float:
	return _interpolated_azimuth

## 停止自动循环
func stop_cycle() -> void:
	if _cycle_tween:
		_cycle_tween.kill()
		_cycle_tween = null

# ── 内部方法 ──

## 每个相位的太阳仰角（简化模型）
func _phase_elevation(phase: int) -> float:
	match phase:
		TimePhase.DAWN: return 20.0
		TimePhase.DAY: return 45.0
		TimePhase.DUSK: return 20.0
		TimePhase.NIGHT: return 30.0
	return 45.0

## 启动自动循环（DAY → DUSK → NIGHT → DAWN）
func _start_auto_cycle(scene_data: Resource) -> void:
	stop_cycle()
	_cycle_tween = create_tween().set_loops()
	var phases := [TimePhase.DAY, TimePhase.DUSK, TimePhase.NIGHT, TimePhase.DAWN]
	var phase_duration: float = scene_data.cycle_duration / 4.0
	for phase in phases:
		_cycle_tween.tween_callback(
			func(): transition_to(phase, phase_duration * 0.8)
		)
		_cycle_tween.tween_interval(phase_duration)

## 应用覆盖栈顶的覆盖（按优先级排序，取最高）
func _apply_top_override() -> void:
	if _override_stack.is_empty():
		override_removed.emit()
		return
	_override_stack.sort_custom(func(a, b): return a.data.priority > b.data.priority)
	override_applied.emit(_override_stack[0].data)
