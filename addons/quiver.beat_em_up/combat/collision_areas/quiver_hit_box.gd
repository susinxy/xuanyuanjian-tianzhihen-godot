@tool
class_name QuiverHitBox
extends Area2D

## Write your doc string for this file here

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

@export var character_type: CombatSystem.CharacterTypes = \
		CombatSystem.CharacterTypes.PLAYERS:
	set(value):
		character_type = value 
		_handle_character_type_presets()
		notify_property_list_changed()
		update_configuration_warnings()

var character_attributes: QuiverAttributes = null
@export var attack_data: QuiverAttackData = null:
	set(value):
		if value == null:
			attack_data = QuiverAttackData.new()
		else:
			attack_data = value as QuiverAttackData
	get:
		if attack_data == null:
			attack_data = QuiverAttackData.new()
		return attack_data

#--- private variables - order: export > normal var > onready -------------------------------------

## 阵营 group 缓存（只缓存 area2d: 前缀的 group，避免每次遍历所有 groups）
var _faction_groups: Array[StringName] = []

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	if not has_meta(QuiverCollisionTypes.META_KEY):
		_handle_character_type_presets()
	
	if Engine.is_editor_hint():
		QuiverEditorHelper.disable_all_processing(self)
		return
	
	add_to_group(StringName(owner.get_path()))
	_refresh_faction_cache()


## 重写 add_to_group：捕获运行时的 faction group 变更
func add_to_group(group: StringName, persistent: bool = false) -> void:
	super(group, persistent)
	if str(group).begins_with(QuiverHurtBox.FACTION_PREFIX):
		_refresh_faction_cache()


## 重写 remove_from_group：捕获运行时的 faction group 变更
func remove_from_group(group: StringName) -> void:
	super(group)
	if str(group).begins_with(QuiverHurtBox.FACTION_PREFIX):
		_refresh_faction_cache()


## 重写 set_groups：捕获批量替换 groups 的情况
func set_groups(groups: Array) -> void:
	super(groups)
	_refresh_faction_cache()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	
	var collision_type := get_meta(QuiverCollisionTypes.META_KEY, "default") as String
	if collision_type.find("hit_box") == -1 and collision_type != "custom":
		warnings.append("hit box area is using an invalid presset")
	
	return warnings

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

## 刷新阵营 group 缓存（只缓存 area2d: 前缀的 group）
func _refresh_faction_cache() -> void:
	_faction_groups.clear()
	for group in get_groups():
		if str(group).begins_with(QuiverHurtBox.FACTION_PREFIX):
			_faction_groups.append(group)


func _handle_character_type_presets() -> void:
	var collision_type := get_meta(QuiverCollisionTypes.META_KEY, "default") as String
	if collision_type == "custom":
		return
	
	var target_collision_type := ""
	match character_type:
		CombatSystem.CharacterTypes.PLAYERS:
			target_collision_type = "player_hit_box"
		CombatSystem.CharacterTypes.ENEMIES:
			target_collision_type = "enemy_hit_box"
		CombatSystem.CharacterTypes.BOUNCE_OBSTACLE:
			target_collision_type = "world_hit_box"
		_:
			push_error("Unimplemented CharacterType: %s. Possible types: %s"%[
					character_type,
					CombatSystem.CharacterTypes.keys()
			])
			return
	
	if target_collision_type != collision_type:
		QuiverCollisionTypes.apply_preset_to(
				QuiverCollisionTypes.PRESETS[target_collision_type], self
		)

### -----------------------------------------------------------------------------------------------
