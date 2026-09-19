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


## 受击"列"判定（2026-09-19 车道换轴批）：纵向攻击时双方比对 x（同列容忍），
## 窗口家族同款（lane_size±hit_lane_offset，中心由防守方给出）。x 坐标取双方
## 碰撞盒节点的 global x：x 无跳跃漂浮（Y 才必须用 ground_level），攻击盒挂载
## 位带 ≤16px 姿态偏置，对 60px 窗口属噪声级。
func is_in_same_column_as(
		defender: QuiverAttributes,
		attacker: QuiverAttributes,
		defender_x: float,
		attacker_x: float
) -> bool:
	return defender.get_hit_lane_limits(defender_x).is_value_inside_lane(attacker_x)


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
	elif not verdict.swallow:
		# 分发器纯三向开关（2026-09-18 霸体 elif 退役）：政策全在 apply_knock
		target.hurt_requested.emit(knockback)

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
