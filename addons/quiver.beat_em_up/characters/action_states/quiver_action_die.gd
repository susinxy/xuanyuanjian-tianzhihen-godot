@tool
class_name QuiverActionDie
extends QuiverCharacterAction

## Write your doc string for this file here

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

var _skin_state := &"die"

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		QuiverEditorHelper.disable_all_processing(self)
		return

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func enter(msg: = {}) -> void:
	super(msg)
	# 尸体保护（2026-10 死亡演出批 G4）：死亡演出开场即摘受击盒——不再被补刀
	# 打断信标链（用户实机"残余攻击再次打到"定罪）；exit 恢复（括弧式，复活/
	# 重进链复用防"死后永久隐形"）。
	if _skin != null and _skin.hurtbox != null:
		_skin.hurtbox.set_deferred("monitoring", false)
	# 非击飞死亡兜底开据（2026-10 死亡演出批）：法术直杀/受击复查进 die 等不
	# 经 launch 的死法同样"一次判定"——慢放旗此刻开=慢放死亡动画本身（目标3
	# 语义），击飞形态则由 launch 先行开据、此处防重让位。
	var settle := QuiverCharacterHelper.is_defeat_bound(_character)
	var slowmo := QuiverCharacterHelper.is_death_slowmo_bound(_character)
	HitFreeze.begin_death(_character, slowmo, settle)
	_skin.transition_to(_skin_state)


func exit() -> void:
	super()
	if _skin != null and is_instance_valid(_skin) and _skin.hurtbox != null:
		if is_instance_valid(_skin.hurtbox):
			_skin.hurtbox.set_deferred("monitoring", true)

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _connect_signals() -> void:
	super()
	QuiverEditorHelper.connect_between(_skin.skin_animation_finished, _on_skin_animation_finished)


func _disconnect_signals() -> void:
	super()
	if _skin != null:
		QuiverEditorHelper.disconnect_between(
			_skin.skin_animation_finished, _on_skin_animation_finished
		)


func _on_skin_animation_finished() -> void:
	# 锚点批单门：败北=defeat_bound（锚点∪被控者，无壳回落 player 兼容形）。
# 旧接管批曾用 is_player_identity——锚维度加入后演出与终局同闸迁移，
# 旁观者（既非锚也非控）之死=普通阵亡不劫持时间不触终局。
	# 死亡演出批 G1：凭据统计消费（HitFreeze）——不再二次查组籍；时钟归还、
	# 结算发出、"结算等全部在途慢放"的编排全部收敛中枢。false=无票据普通阵亡。
	if not HitFreeze.finish_death(_character):
		_character.queue_free()

### -----------------------------------------------------------------------------------------------

###################################################################################################
# Custom Inspector ################################################################################
###################################################################################################

func _get_custom_properties() -> Dictionary:
	return {
		"_skin_state": {
			default_value = &"die",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			hint = PROPERTY_HINT_ENUM,
			hint_string = \
					'ExternalEnum{"property": "_skin", "property_name": "_animation_list"}'
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
