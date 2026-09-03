class_name SceneTimeData
extends Resource
## 场景时间配置资源
##
## 每个场景一份，定义该场景的昼夜行为：
## - 默认相位（进入场景时的初始相位）
## - 是否自动循环及循环时长
## - 每个相位的 CanvasModulate 颜色和 DirectionalLight2D 参数

## 默认相位（进入场景时切换到此相位）
@export var default_phase: int = 1  # TimePhase.DAY

## 是否自动循环（DAY → DUSK → NIGHT → DAWN → DAY ...）
@export var can_cycle: bool = false

## 一个完整循环的秒数（四个相位平分）
@export var cycle_duration: float = 300.0

## 相位切换过渡时长（秒）
@export var transition_duration: float = 2.0

## 每个相位的 CanvasModulate 颜色（场景整体色调）
@export var phase_colors: Dictionary = {}

## 每个相位的 DirectionalLight2D 旋转角度（度）
## 与阴影系统的映射：shader_angle = fmod(rotation + 180.0, 360.0)
@export var phase_light_rotations: Dictionary = {}

## 每个相位的 DirectionalLight2D 能量
@export var phase_light_energies: Dictionary = {}

## 每个相位的 DirectionalLight2D 颜色
@export var phase_light_colors: Dictionary = {}

## 哪些相位开启环境点光源（灯笼/火把等）
@export var point_lights_enabled_phases: Array = []

func _init() -> void:
	# TimePhase: DAWN=0, DAY=1, DUSK=2, NIGHT=3
	phase_colors = {
		0: Color(0.95, 0.85, 0.75),   # DAWN 暖橙
		1: Color(1.0, 1.0, 1.0),       # DAY 白色
		2: Color(0.9, 0.7, 0.5),       # DUSK 黄昏橙
		3: Color(0.3, 0.4, 0.6),       # NIGHT 冷蓝
	}
	phase_light_rotations = {
		0: -70.0,   # DAWN 右侧低角度
		1: -45.0,   # DAY 右上方 45°
		2: 70.0,    # DUSK 左侧低角度
		3: 45.0,    # NIGHT 左上方
	}
	phase_light_energies = {
		0: 0.6,
		1: 1.0,
		2: 0.5,
		3: 0.3,
	}
	phase_light_colors = {
		0: Color(1.0, 0.8, 0.6),
		1: Color(1.0, 1.0, 0.95),
		2: Color(1.0, 0.6, 0.3),
		3: Color(0.6, 0.7, 1.0),
	}
	point_lights_enabled_phases = [2, 3]  # DUSK, NIGHT
