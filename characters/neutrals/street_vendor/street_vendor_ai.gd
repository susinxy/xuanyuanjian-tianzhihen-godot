extends QuiverBehaviorAI
class_name StreetVendorAI

## 站街小贩 的策略小抄（模板默认版）。
##
## 行为循环：歇 2 秒 → 追击最近的玩家阵营角色 → 追到攻击距离出拳，
## 连段窗口内按帧跟进（最多三段）→ 回到待机后再歇。
## 受击短暂定身 0.8 秒（上游"受击打断决策"的精华，落在纯代码层）。
## 这是演示级默认值——正式敌人请直接改本文件（身体、壳、通道都不必动）。

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

enum Phase { REST, CHASE, ASSAULT }

#--- constants ------------------------------------------------------------------------------------

const ATTACK_RANGE := 95.0        ## 出拳距离（像素），按攻击 hitbox 实际长度调
const REST_DURATION := 2.0        ## 每轮攻击后休息秒数
const HURT_COOLDOWN := 0.8        ## 受击定身秒数

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

var _phase := Phase.REST
var _rest_left := 1.0
var _hurt_cooldown := 0.0
var _last_state: NodePath

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func tick(_delta: float) -> void:
	if _hurt_cooldown > 0.0:
		_hurt_cooldown -= _delta
		stop_moving()
		return
	
	var target := closest_target()
	match _phase:
		Phase.REST:
			stop_moving()
			_rest_left -= _delta
			if _rest_left <= 0.0 and target != null:
				_phase = Phase.CHASE
		Phase.CHASE:
			if target == null:
				_enter_rest()
			elif distance_to(target) <= ATTACK_RANGE:
				_phase = Phase.ASSAULT
				stop_moving()
				press_attack()
			else:
				move_towards(target)
		Phase.ASSAULT:
			# 连段跟进：状态机每进入新的 Combo 窗态就补按一拳（最多三段，
			# attack3 无后续窗口，自然回到 Idle）
			var state := _state_name()
			if state != _last_state:
				if String(state).contains("Idle"):
					_enter_rest()
				elif String(state).contains("Combo"):
					press_attack()
			_last_state = state

func on_hurt(_knockback: QuiverKnockbackData) -> void:
	_hurt_cooldown = HURT_COOLDOWN
	_enter_rest()


### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _enter_rest() -> void:
	_phase = Phase.REST
	_rest_left = REST_DURATION
	stop_moving()


func _state_name() -> NodePath:
	var machine := _get_machine()
	if machine == null:
		return NodePath()
	return machine.state_name

### -----------------------------------------------------------------------------------------------
