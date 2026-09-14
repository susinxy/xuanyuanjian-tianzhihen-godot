@tool
class_name QuiverStateMachine
extends Node

## Based on GDQuest's StateMachine but with some modifications to make it a 
## [code]@tool[/code] script and convert to GDScript 2.0.
##
## Generic State Machine that can be used for handling States as nodes. It has a signal to notify 
## about transitions.
## [br][br]
## It also has a read-only [member state_name] property to help with debugging or checking 
## current state.

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

## Emitted whenever there is a state transtion.
signal transitioned(state_path)

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

## Value returned by [member state_name] when [member state] is [code]null[/code].
const INVALID_NODEPATH = ^"invalid"

#--- public variables - order: export > normal var > onready --------------------------------------

## [NodePath] to initial state, should be defined in the inspector.
@export_node_path("QuiverState") var initial_state := NodePath(""):
	set(value):
		initial_state = value
		update_configuration_warnings()

@export var should_process_input := true

## 输入窗口开关：deliver_event 是否放行事件。
## 攻击连段窗口、空中攻击许可等机制在 enter/exit/计时回调里切换它。
## 注意：不要改用 Node 原生 is_processing_unhandled_input 标志——Godot 4 会
## 根据"脚本是否覆写 _unhandled_input 虚函数"自动改写该标志（本脚本已不覆写，
## 标志恒为 false，用它当门控会把输入永久锁死）。
var input_window_open := true

## Current state.
var state: QuiverState = null:
	set(value):
		state = value
		if is_inside_tree() and is_instance_valid(state):
			state_name = get_path_to(state)
## Current state name.
var state_name: NodePath = INVALID_NODEPATH

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	if Engine.is_editor_hint():
		QuiverEditorHelper.disable_all_processing(self)
		return
	
	if is_instance_valid(owner):
		await owner.ready
	
	state = get_node(initial_state) as QuiverState
	state.enter()
	emit_signal("transitioned", get_path_to(state))


## 事件注入口。本节点不再监听物理键盘（旧 _unhandled_input 管道已拆除，
## 串台漏洞从源头消灭）。输入只能由角色的行为脚本投递：
## [br]· 玩家 → QuiverBehaviorPlayer._unhandled_input 转投真实 OS 事件
## [br]· AI → QuiverBehaviorAI 的合成事件（press_attack 等）
## 原有的"输入窗口"语义完整保留：连段/空中攻击窗口通过 [member
## input_window_open] 切换本入口的通过率。
func deliver_event(event: InputEvent) -> void:
	if not should_process_input:
		return
	if not input_window_open:
		return
	# 初始状态就绪（_ready 中 await owner.ready）之前可能已到输入帧，静默丢弃
	if not is_instance_valid(state):
		return
	state.unhandled_input(event)


func _process(delta: float) -> void:
	state.process(delta)


func _physics_process(delta: float) -> void:
	state.physics_process(delta)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	
	if initial_state.is_empty():
		warnings.append("An initial state node must be defined.")
	
	return warnings

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## Takes a [NodePath] to the next state node, and transitions to it. Can optionally receive a 
## dictionary to be passed to the [method QuiverState.enter] method of the new state.[br]
## Note that the [NodePath] passed in must be relative to the StateMachine node.
func transition_to(target_state_path: NodePath, msg: = {}) -> void:
	if not has_node(target_state_path):
		push_error("Could not find state in path: %s"%[target_state_path])
		return
	
	var target_state := get_node(target_state_path) as QuiverState
	
	QuiverDebugLogger.log_message([get_path(), "Exiting State", get_path_to(state)])
	state.exit()
	
	state = target_state
	QuiverDebugLogger.log_message([get_path(), "Entering State", target_state_path])
	state.enter(msg)
	
	emit_signal("transitioned", target_state_path)

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
