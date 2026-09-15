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


## 运行时加入阵营组并刷新缓存。**外部动态加 faction 组一律走本方法。**
## 引擎陷阱（2026-09-15 实测）：GDScript 对"已知静态类型变量"的方法调用直连
## Node 原生 add_to_group 绑定，**绕过**下方脚本层 override——只有 Variant
## 动态调用才会进 override。依赖 override 刷新缓存会让 typed 调用点静默失效
## （法术继承施法者阵营时踩中），故公开此显式刷新入口。
func add_faction_group(group: StringName) -> void:
	add_to_group(group)
	_refresh_faction_cache()


## 重写 add_to_group：捕获运行时的 faction group 变更
## （仅对 Variant 动态调用生效；typed 调用请改用 [method add_faction_group]）
func add_to_group(group: StringName, persistent: bool = false) -> void:
	super(group, persistent)
	if str(group).begins_with(QuiverHurtBox.FACTION_PREFIX):
		_refresh_faction_cache()


## 重写 remove_from_group：捕获运行时的 faction group 变更
func remove_from_group(group: StringName) -> void:
	super(group)
	if str(group).begins_with(QuiverHurtBox.FACTION_PREFIX):
		_refresh_faction_cache()


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
