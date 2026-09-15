@tool
class_name QuiverActionCast
extends QuiverCharacterAction

## 地面施法动作状态——两段式起手+引导（2026-09-15 定稿契约）。
##
## 时间轴（信号/计时分工）：
##   enter ──▶ spell_start 槽（非循环，角色资产自然时长，唯一信源是动画尾帧
##             的 end_of_skin_animation 方法调用——与攻击结束同款机制）
##         ──信号──▶ spelling 槽（循环姿势保持；时长=法术定义 caster_cast_time，
##                   本状态倒计时）──倒计时归零──▶ release 出手 → 回 Idle。
## 分工原则：起手时长归角色动画（每个法术都必须完整经历），引导时长归法术数据
## （循环天然适配任意时长，禁止变速/掐断/定格的中间态）。
##
## 降级阶梯（缺资产时节奏与计时一律不变，2026-09-15 拍板）：
##   缺 spell_start 槽 → 跳过起手段，进 Cast 即上膛引导计时；
##   缺 spelling 槽   → 起手播完定格保持（不切循环），引导照常倒数；
##   两槽全缺         → 有 idle 切 idle，无则维持残影但计时照走（一次性告警）。
##
## 承诺制：法力/冷却由 SpellManager 在起手瞬间扣除，中途被打断法术作废不退还；
## 咏唱期间关闭输入窗口（攻击键不可切走），受击/击倒走 Ground 现成信号链打断。
##
## msg 约定（SpellManager 投递）：{ cast_time: float(引导段秒数), release: Callable }

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

## 起手段槽名（非循环动画，尾帧方法调用宣告结束）
var _start_state: StringName = &"spell_start"

## 引导段槽名（循环动画，时长由法术定义驱动）
var _loop_state: StringName = &"spelling"

var _path_next_state := "Ground/Move/Idle"

var _should_enter_parent := true
var _should_exit_parent := true
var _should_process_parent := true

var _time_left := 0.0
var _timing_active := false
var _release: Callable = Callable()
var _released := false
var _start_signal_on := false

static var _warned_missing_anim: Dictionary = {}

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		QuiverEditorHelper.disable_all_processing(self)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	
	if _start_state == &"" and _loop_state == &"":
		warnings.append("施法状态至少要指定一个皮肤动画槽（起手或引导）。")
	
	return warnings

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func enter(msg: = {}) -> void:
	super(msg)
	if _should_enter_parent:
		get_parent().enter(msg)
	
	# 咏唱期间关闭输入窗口（与攻击 _can_combo=false 同语义）
	_state_machine.input_window_open = false
	
	_time_left = float(msg.get("cast_time", 0.0))
	_release = msg.get("release", Callable())
	_released = false
	_timing_active = false
	_character.velocity = Vector2.ZERO
	
	# 方向归一化与攻击完全同款（与 SpellManager 出手共用唯一实现）
	_skin.skin_direction = SpellManager.snap_to_four_direction(_skin.skin_direction)
	
	if _skin.has_anim_state(_start_state):
		_skin.transition_to(_start_state)
		_arm_start_listener()
	elif _skin.has_anim_state(_loop_state):
		_skin.transition_to(_loop_state)
		_timing_active = true
		_warn_missing_once("spell_start")
	else:
		if _skin.has_anim_state(&"idle"):
			_skin.transition_to(&"idle")
		_timing_active = true
		_warn_missing_once("spell_start/spelling")


func unhandled_input(_event: InputEvent) -> void:
	# 施法不消费任何输入（输入窗口已在 enter 关闭）
	pass


func physics_process(delta: float) -> void:
	if _should_process_parent:
		get_parent().physics_process(delta)
	
	if not _timing_active or _released:
		return
	
	_time_left -= delta
	if _time_left <= 0.0:
		_released = true
		if _release.is_valid():
			_release.call()
		_state_machine.transition_to(_path_next_state)


func exit() -> void:
	_disarm_start_listener()
	_timing_active = false
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


## 起手段监听：一次性消费设计——信号到达即断开，杜绝循环槽误触发
func _arm_start_listener() -> void:
	if _start_signal_on:
		return
	QuiverEditorHelper.connect_between(
			_skin.skin_animation_finished, _on_start_animation_finished)
	_start_signal_on = true


func _disarm_start_listener() -> void:
	if not _start_signal_on:
		return
	QuiverEditorHelper.disconnect_between(
			_skin.skin_animation_finished, _on_start_animation_finished)
	_start_signal_on = false


func _on_start_animation_finished() -> void:
	# 起手播完（动画尾帧方法轨道宣告）：上膛引导 + 切循环槽
	_disarm_start_listener()
	if _skin.has_anim_state(_loop_state):
		_skin.transition_to(_loop_state)
	_timing_active = true


func _warn_missing_once(what: String) -> void:
	var key := str(_skin.name) + ":" + what
	if _warned_missing_anim.has(key):
		return
	_warned_missing_anim[key] = true
	push_warning("皮肤 %s 缺少施法动画槽 %s，施法按降级节奏执行" % [_skin.name, what])

### -----------------------------------------------------------------------------------------------


###################################################################################################
# Custom Inspector ################################################################################
###################################################################################################

func _get_custom_properties() -> Dictionary:
	var custom_properties := {
		"_start_state": {
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			hint = PROPERTY_HINT_ENUM,
			hint_string = \
					'ExternalEnum{"property": "_skin", "property_name": "_animation_list"}'
		},
		"_loop_state": {
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
