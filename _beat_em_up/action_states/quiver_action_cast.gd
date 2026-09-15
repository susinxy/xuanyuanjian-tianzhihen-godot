@tool
class_name QuiverActionCast
extends QuiverCharacterAction

## 地面施法动作状态——"攻击的同款骨架去掉连段"版。
## 与 QuiverActionAttack 的差异：
## · 施法动画是**循环**动画（永不自然播完），由法术定义的 caster_cast_time 计时收尾；
## · 到点调用 SpellManager 注入的 release 回调让法术体上场，再回 Idle；
## · 无连段、无动画位移驱动；法力/冷却已由管理器在起手瞬间扣除（承诺制），
##   中途被打断则法术作废、不退还；
## · 皮肤无 "spell" 动画槽时降级：不播动画但**仍锁满时长**（节奏一致，2026-09 拍板）。
##
## msg 约定（由 SpellManager 投递）：{ cast_time: float, release: Callable }

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

var _skin_state: StringName = &"spell"

var _path_next_state := "Ground/Move/Idle"

var _should_enter_parent := true
var _should_exit_parent := true
var _should_process_parent := true

var _time_left := 0.0
var _release: Callable = Callable()
var _released := false

static var _warned_missing_anim: Dictionary = {}

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		QuiverEditorHelper.disable_all_processing(self)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	
	if _skin_state == &"":
		warnings.append("施法状态必须指定一个皮肤动画槽名（约定为 spell）。")
	
	return warnings

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func enter(msg: = {}) -> void:
	super(msg)
	if _should_enter_parent:
		get_parent().enter(msg)
	
	# 咏唱期间关闭输入窗口：攻击键不能把施法切走（与攻击 _can_combo=false 同语义）
	_state_machine.input_window_open = false
	
	_time_left = float(msg.get("cast_time", 0.0))
	_release = msg.get("release", Callable())
	_released = false
	_character.velocity = Vector2.ZERO
	
	# 方向归一化与攻击完全同款（与 SpellManager 出手共用唯一实现）
	_skin.skin_direction = SpellManager.snap_to_four_direction(_skin.skin_direction)
	
	if _skin.has_anim_state(_skin_state):
		_skin.transition_to(_skin_state)
	else:
		_warn_missing_anim()


func unhandled_input(_event: InputEvent) -> void:
	# 施法不消费任何输入（输入窗口也已在 enter 关闭）
	pass


func physics_process(delta: float) -> void:
	if _should_process_parent:
		get_parent().physics_process(delta)
	
	if _released:
		return
	
	_time_left -= delta
	if _time_left <= 0.0:
		_released = true
		if _release.is_valid():
			_release.call()
		_state_machine.transition_to(_path_next_state)


func exit() -> void:
	_release = Callable()
	_state_machine.input_window_open = true
	
	super()
	if _should_exit_parent:
		get_parent().exit()

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _connect_signals() -> void:
	get_parent()._connect_signals()
	super()


func _disconnect_signals() -> void:
	get_parent()._disconnect_signals()
	super()


func _warn_missing_anim() -> void:
	var key := str(_skin.name) + ":" + str(_skin_state)
	if _warned_missing_anim.has(key):
		return
	_warned_missing_anim[key] = true
	push_warning("皮肤 %s 缺少施法动画槽 '%s'，施法降级为无动画锁时长" % [
			_skin.name, _skin_state])

### -----------------------------------------------------------------------------------------------


###################################################################################################
# Custom Inspector ################################################################################
###################################################################################################

func _get_custom_properties() -> Dictionary:
	var custom_properties := {
		"_skin_state": {
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			hint = PROPERTY_HINT_ENUM,
			hint_string = \
					'ExternalEnum{"property": "_skin", "property_name": "_animation_list"}'
		},
		"_path_next_state": {
			default_value = "Ground/Move/Idle",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			hint = PROPERTY_HINT_NONE,
			hint_string = QuiverState.HINT_STATE_LIST,
		},
		"Parent State Settings": {
			type = TYPE_NIL,
			usage = PROPERTY_USAGE_GROUP,
			hint = PROPERTY_HINT_NONE,
			hint_string = "parent_"
		},
		"parent_should_enter": {
			backing_field = "_should_enter_parent",
			default_value = true,
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			hint = PROPERTY_HINT_NONE,
		},
		"parent_should_exit": {
			backing_field = "_should_exit_parent",
			default_value = true,
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			hint = PROPERTY_HINT_NONE,
		},
		"parent_should_process": {
			backing_field = "_should_process_parent",
			default_value = true,
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			hint = PROPERTY_HINT_NONE,
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
	
	return custom_properties

### Custom Inspector built in functions -----------------------------------------------------------

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	
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
