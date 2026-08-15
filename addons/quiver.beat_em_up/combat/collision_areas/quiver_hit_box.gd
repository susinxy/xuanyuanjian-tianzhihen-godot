@tool
class_name QuiverHitBox
extends Area2D

## Write your doc string for this file here

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

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

## 阵营 group 缓存（Dictionary 格式，key 为 faction name，value 为 true）
## 使用 Dictionary 实现 O(1) 查找，比 Array 遍历更快
var _faction_dict: Dictionary = {}

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
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


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	
	var collision_type := get_meta(QuiverCollisionTypes.META_KEY, "default") as String
	if collision_type == "world_hit_box" or collision_type == "player_detector":
		warnings.append("HitBox should not use %s preset" % collision_type)
	
	return warnings

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

## 刷新阵营 group 缓存（只缓存 area2d: 前缀的 group，使用 Dictionary 存储）
func _refresh_faction_cache() -> void:
	_faction_dict.clear()
	for group in get_groups():
		if str(group).begins_with(QuiverHurtBox.FACTION_PREFIX):
			_faction_dict[group] = true

### -----------------------------------------------------------------------------------------------
