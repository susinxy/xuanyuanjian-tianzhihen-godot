@tool
class_name QuiverAttackData
extends Resource

## Write your doc string for this file here

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

@export_range(0, 1, 1, "or_greater") var attack_damage = 1:
	set(value):
		attack_damage = value
		emit_changed()

@export var hurt_type: CombatSystem.HurtTypes = CombatSystem.HurtTypes.HIGH:
	set(value):
		hurt_type = value
		emit_changed()

## 击打值 K（统一模型 2026-09-18，原五档枚举退役）：命中时从受击方抗击打
## 额度中扣减的连续数值；扣穿瞬间以溢出量+保底起飞。0=纯伤害不碰额度，
## 且空中零击打值攻击不打断弹道。旧档位等价：轻60/中600/重1200/极重2400。
@export var knock_strength: float = 0.0:
	set(value):
		knock_strength = value
		emit_changed()

## 接触点特效风格路由旗（B4.7 R4）：命中时 HitFx 按此名选参数卡；枚举只
## 路由查表、零数值推导（B4.6 attack_axis_mode 合法路由旗同族注例），
## 未配置=default 卡兜底——任何攻击命中都有火花。
@export var hit_effect_style: StringName = &"default":
	set(value):
		hit_effect_style = value
		emit_changed()

@export_range(0, 360, 1) var launch_angle := 0:
	set(value):
		launch_angle = value
		var raw_direction := QuiverMathHelper.get_direction_by_angle(deg_to_rad(launch_angle))
		launch_vector = raw_direction.reflect(Vector2.RIGHT)
		emit_changed()

var launch_vector := Vector2.RIGHT

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

