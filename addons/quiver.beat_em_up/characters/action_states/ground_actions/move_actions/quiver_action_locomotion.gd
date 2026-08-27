@tool
class_name QuiverActionLocomotion
extends QuiverCharacterAction

## 地面位移通用类
## 
## Walk 和 Run 通过实例配置区分，仅数据不同：
##   _is_walk_mode=true  → 使用 walk_speed（modifier 减速），walk 松开时切换 Run
##   _is_walk_mode=false → 使用 move_speed（原值），walk 按下时切换 Walk
## 
## 速度通过 QuiverAttributes.add_modifier 控制，enter 时设置，exit 时移除。
## _path_other_state 为空字符串时跳过切换检查（兼容旧角色无 Run 节点）。

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var & onready -------------------------------------

var _move_skin_state: StringName
var _is_walk_mode := false
var _path_idle_state := "Ground/Move/Idle"
var _path_other_state := ""
var _path_grabbing_state := "Ground/Grab/Grabbing"

@onready var _move_state := get_parent() as QuiverActionGroundMove

var _speed_modifier := 1.0

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	super()
	update_configuration_warnings()
	if Engine.is_editor_hint():
		QuiverEditorHelper.disable_all_processing(self)
		return


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	
	if not get_parent() is QuiverActionGroundMove:
		warnings.append(
				"This ActionState must be a child of Action QuiverActionGroundMove or a state " 
				+ "inheriting from it."
		)
	
	return warnings


### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func enter(msg: = {}) -> void:
	_move_state._direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	super(msg)
	_move_state.enter(msg)
	if _is_walk_mode and _attributes.move_speed > 0:
		_speed_modifier = float(_attributes.walk_speed) / float(_attributes.move_speed)
		_attributes.add_modifier(&"locomotion_speed", &"move_speed", "multiply", _speed_modifier)
	_character.velocity = _attributes.move_speed * _move_state._direction
	_skin.transition_to(_move_skin_state)


func unhandled_input(event: InputEvent) -> void:
	var has_handled := false
	if not has_handled:
		get_parent().unhandled_input(event)


func physics_process(delta: float) -> void:
	_move_state._direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if not _move_state._direction.is_equal_approx(Vector2.ZERO):
		_skin.skin_direction = _move_state._direction.normalized()
	_move_state.physics_process(delta)
	if _move_state._direction.is_equal_approx(Vector2.ZERO):
		_state_machine.transition_to(_path_idle_state)
		return
	if _path_other_state != "" and Input.is_action_pressed("walk") != _is_walk_mode:
		_state_machine.transition_to(_path_other_state)


func exit() -> void:
	if _is_walk_mode:
		_attributes.remove_modifier(&"locomotion_speed")
	super()
	_move_state.exit()

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _connect_signals() -> void:
	super()
	
	QuiverEditorHelper.connect_between(_attributes.grab_requested, _on_grab_requested)


func _disconnect_signals() -> void:
	super()
	
	if _attributes != null and _state_machine.has_node(_path_grabbing_state):
		QuiverEditorHelper.disconnect_between(_attributes.grab_requested, _on_grab_requested)


func _on_grab_requested(grab_target: QuiverAttributes) -> void:
	_state_machine.transition_to(_path_grabbing_state, {target = grab_target})

### -----------------------------------------------------------------------------------------------


###################################################################################################
# Custom Inspector ################################################################################
###################################################################################################

func _get_custom_properties() -> Dictionary:
	return {
		"_move_skin_state": {
			default_value = &"walk",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			hint = PROPERTY_HINT_ENUM,
			hint_string = \
					'ExternalEnum{"property": "_skin", "property_name": "_animation_list"}'
		},
		"_is_walk_mode": {
			default_value = false,
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			hint = PROPERTY_HINT_NONE,
			hint_string = "",
		},
		"_path_idle_state": {
			default_value = "Ground/Move/Idle",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			hint = PROPERTY_HINT_NONE,
			hint_string = QuiverState.HINT_STATE_LIST,
		},
		"_path_other_state": {
			default_value = "",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			hint = PROPERTY_HINT_NONE,
			hint_string = QuiverState.HINT_STATE_LIST,
		},
		"_path_grabbing_state": {
			default_value = "Ground/Grab/Grabbing",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			hint = PROPERTY_HINT_NONE,
			hint_string = QuiverState.HINT_STATE_LIST,
		},
#		"": {
#			backing_field = "", # use if dict key and variable name are different
#			default_value = "", # use if you want property to have a default value
#			type = TYPE_NIL,
#			usage = PROPERTY_USAGE_DEFAULT,
#			hint = PROPERTY_HINT_NONE,
#			hint_string = "",
#		},
	}

### Custom Inspector built in functions -----------------------------------------------------------

func _get_property_list() -> Array:
	var properties: = []
	
	var custom_properties := _get_custom_properties()
	for key in custom_properties:
		var dict: Dictionary = custom_properties[key]
		if not dict.has("name"):
			dict.name = key
		properties.append(dict)
	
	return properties


func _property_can_revert(property: StringName) -> bool:
	var custom_properties := _get_custom_properties()
	if property in custom_properties and custom_properties[property].has("default_value"):
		return true
	else:
		return false


func _property_get_revert(property: StringName):
	var value
	
	var custom_properties := _get_custom_properties()
	if property in custom_properties and custom_properties[property].has("default_value"):
		value = custom_properties[property]["default_value"]
	
	return value


func _get(property: StringName):
	var value
	
	var custom_properties := _get_custom_properties()
	if property in custom_properties and custom_properties[property].has("backing_field"):
		value = get(custom_properties[property]["backing_field"])
	
	return value


func _set(property: StringName, value) -> bool:
	var has_handled: = false
	
	var custom_properties := _get_custom_properties()
	if property in custom_properties and custom_properties[property].has("backing_field"):
		set(custom_properties[property]["backing_field"], value)
		has_handled = true
	
	return has_handled

### -----------------------------------------------------------------------------------------------
