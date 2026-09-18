extends Node

## Write your doc string for this file here

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

enum HurtTypes {
	MID,
	HIGH
}

## KnockbackStrength 五档枚举已退役（2026-09-18 统一模型）：击打值改为
## [member QuiverAttackData.knock_strength] 连续浮点，档位表/阈值线不复存在。

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func is_in_same_lane_as(defender: QuiverAttributes, attacker: QuiverAttributes) -> bool:
	var lane_limits := defender.get_hit_lane_limits()
	var value := lane_limits.is_value_inside_lane(attacker.ground_level)
	return value


func apply_damage(attack: QuiverAttackData, target: QuiverAttributes) -> void:
	if target.is_invulnerable:
		return
	target.health_current -= attack.attack_damage
	HitFreeze.start()


## 击退/击飞分发（统一模型）：规则判定全部下沉在
## [method QuiverAttributes.apply_knock]（唯一判定点），本函数只按裁决
## 结果三选一：起飞信号 / 受击信号 / 吞事件（空中零击打值穿身）。
## 注意：须由调用方在扣血之后调用（死亡强飞判定读的是伤后血量）。
func apply_knockback(
	knockback: QuiverKnockbackData, 
	target: QuiverAttributes
) -> void:
	if target.is_invulnerable:
		return
	var verdict: Dictionary = target.apply_knock(knockback.knock_value)
	if verdict.swallow:
		return
	if verdict.launched:
		knockback.impulse = verdict.impulse
		target.knockout_requested.emit(knockback)
	elif not target.has_superarmor:
		target.hurt_requested.emit(knockback)

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
