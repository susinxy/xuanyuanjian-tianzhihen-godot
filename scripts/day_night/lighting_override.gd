class_name LightingOverride
extends Resource
## 光照覆盖资源
##
## 用于法术/剧情临时覆盖场景光照（如 Boss 战变暗、圣光法术变亮）。
## 通过 DayNightManager.apply_lighting_override() 应用，
## 支持优先级（高覆盖低）和定时自动移除。

## 目标 CanvasModulate 颜色
@export var color: Color = Color.WHITE

## 目标 DirectionalLight2D 旋转（度）
@export var light_rotation: float = -45.0

## 目标 DirectionalLight2D 能量
@export var light_energy: float = 1.0

## 目标 DirectionalLight2D 颜色
@export var light_color: Color = Color.WHITE

## 过渡时长（秒）
@export var transition_duration: float = 1.0

## 优先级（多个覆盖共存时，高优先级生效）
@export var priority: int = 0
