class_name QuiverKnockbackData
extends RefCounted

## Write your doc string for this file here

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

## 输入：本击击打值 K（来自 QuiverAttackData.knock_strength）
var knock_value := 0.0
## 输出：结算冲量（CombatSystem 经 QuiverAttributes.apply_knock 判定时写入，
## 起飞状态消费；未破线的受击为 0）
var impulse := 0.0
var hurt_type: CombatSystem.HurtTypes = CombatSystem.HurtTypes.HIGH
var launch_vector := Vector2.ZERO

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _init(
	p_knock_value: float, 
	p_hurt: CombatSystem.HurtTypes, 
	p_vector: Vector2
) -> void:
	knock_value = p_knock_value
	hurt_type = p_hurt
	launch_vector = p_vector

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

