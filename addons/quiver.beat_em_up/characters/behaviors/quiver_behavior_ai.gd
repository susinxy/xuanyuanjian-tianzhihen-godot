class_name QuiverBehaviorAI
extends QuiverBehavior

## AI 行为脚本基类——"策略小抄"的宿主。
##
## 每只 AI 角色的行为由其策略脚本（继承本类）决定：覆写 [method tick]，
## 每物理帧被调用一次，用本类提供的工具方法向宿主通道写决策：
## [br]· [method move_towards] / [method stop_moving] —— 追与停
## [br]· [method press_attack] / [method release_attack] —— 出拳（走与玩家
##   完全相同的连段窗口机制，AI 的"连段水平"就是它再按的时机）
## [br]· [method closest_target] —— 找最近的玩家阵营角色
##
## 受击/死亡钩子：[method on_hurt]、[method on_died] 由宿主属性信号
## （hurt_requested / health_depleted）驱动，小抄覆写即可
## （对应上游"受击打断决策"的精华，落在纯代码层）。

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

var _attributes_connected := false

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	super()
	# 属性就绪可能晚于一帧（宿主 _ready 里 duplicate），延后接线
	_connect_attributes.call_deferred()


### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func pre_physics(delta: float) -> void:
	if _character == null or _channel == null or not active:
		return
	tick(delta)


## 决策钩子：子类（策略小抄）覆写。每物理帧一次。
func tick(_delta: float) -> void:
	pass


## 受击钩子：子类覆写（可暂停追击、插入恢复节奏等）。
func on_hurt(_knockback: QuiverKnockbackData) -> void:
	pass


## 死亡钩子：子类覆写（结算、掉落、消失）。
func on_died() -> void:
	pass

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _connect_attributes() -> void:
	if _attributes_connected:
		return
	if _character == null or _character.attributes == null:
		# 宿主还没就绪，下一帧再试
		_connect_attributes.call_deferred()
		return
	_attributes_connected = true
	_character.attributes.hurt_requested.connect(_on_attributes_hurt)
	_character.attributes.health_depleted.connect(_on_attributes_died)


func _on_attributes_hurt(knockback: QuiverKnockbackData) -> void:
	on_hurt(knockback)


func _on_attributes_died() -> void:
	on_died()


## —— 以下为给小抄子类用的工具方法（protected 语义）——

## 最近的玩家阵营角色（找不到返回 null）。
func closest_target() -> QuiverCharacter:
	return QuiverCharacterHelper.find_closest_player_to(_character)


## 朝目标写摇杆（单位方向向量），即"追"。
func move_towards(target: Node2D) -> void:
	if target == null:
		stop_moving()
		return
	_channel.set_axis((_target_dir_to(target)).normalized())


## 摇杆归零，即"站住"。
func stop_moving() -> void:
	_channel.set_axis(Vector2.ZERO)


## 与目标的像素距离。
func distance_to(target: Node2D) -> float:
	if target == null:
		return INF
	return _character.global_position.distance_to(target.global_position)


## 按一下攻击键（走状态机事件注入路径，与玩家按键同一条神经通路）。
func press_attack() -> void:
	_channel.press("attack")
	_get_machine().deliver_event(make_action_event("attack", true))


## 松开攻击键。
func release_attack() -> void:
	_channel.release("attack")
	_get_machine().deliver_event(make_action_event("attack", false))


func _target_dir_to(target: Node2D) -> Vector2:
	return target.global_position - _character.global_position


func _get_machine() -> QuiverStateMachine:
	if _character == null:
		return null
	return _character.state_machine

### -----------------------------------------------------------------------------------------------
