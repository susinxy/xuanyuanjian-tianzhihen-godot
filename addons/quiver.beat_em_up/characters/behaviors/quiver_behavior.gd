class_name QuiverBehavior
extends Node

## 行为脚本基类——"谁在发号施令"的抽象。
##
## 每个角色出生时（QuiverCharacter._ready）按 behavior_mode 挂一个子类实例，
## 它是该角色私有输入通道（QuiverInputChannel）唯一的写入口：
## [br]· QuiverBehaviorPlayer —— 把物理键盘/手柄抄进通道（全场唯一 OS 听众）
## [br]· QuiverBehaviorAI —— 策略小抄（其子类脚本）按决策写通道
## [br]· QuiverBehaviorIdle —— 什么都不写（被动站立角色）
## 运行时可换挂 = 操控权无缝交接（QuiverCharacter.switch_behavior）。

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

var _character: QuiverCharacter = null
var _channel: QuiverInputChannel = null

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	pass

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## 由 QuiverCharacter 在挂载后调用，注入宿主与通道引用。
func configure(character: QuiverCharacter, channel: QuiverInputChannel) -> void:
	_character = character
	_channel = channel


## 物理帧前置泵水钩子：由宿主角色的 _physics_process 显式调用，
## 先于状态机子节点执行，从根上免疫节点处理顺序问题。子类覆写。
func pre_physics(_delta: float) -> void:
	pass


## 构造一个可注入状态机动作管道的合成按键事件（AI 小抄"按键"用）。
func make_action_event(action: String, pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = StringName(action)
	event.pressed = pressed
	return event

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
