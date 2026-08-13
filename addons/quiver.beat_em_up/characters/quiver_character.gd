@tool
class_name QuiverCharacter
extends CharacterBody2D

## Base class for characters, either player characters or enemies.
##
## It is recomended to use this class by inheriting from the base scene at
## [code]res://characters/_base/character/base_character.tscn[/code].
## [br][br]It has a [QuiverCharacterSkin], and a collision dependency, that must be added in the 
## inherited scene and configured in their respective properties in the editor.
## [br][br]It also has an internal dependencie for a state machine, which in the base scene has no
## states in it, as this is also something that must be added per character, according to the
## character's requirements.

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

## Godot 4 中，layer N 对应 bit (N-1)：layer 15 = bit 14 = 1<<14
## 这里使用 layer 编号（1-indexed），与 Godot Inspector 一致
const HEIGHT_LAYER_DEFINITIONS = [
	{ "min": 0,   "max": 30,   "layer": 15 },
	{ "min": 30,  "max": 100,  "layer": 16 },
	{ "min": 100, "max": 200,  "layer": 17 },
	{ "min": 200, "max": 300,  "layer": 18 },
	{ "min": 300, "max": INF,  "layer": 19 },
]

#--- public variables - order: export > normal var > onready --------------------------------------

var attributes: QuiverAttributes = null:
	set(value):
		attributes = value
		if is_instance_valid(_skin):
			# I need to add it directly to the skin because the skin is a scene of it's own,
			# so it's "owner path" is different than the character's. Also because I need to 
			# animate some of the attributes properties so it needs to be exported to 
			# the editor anyway.
			_skin.attributes = attributes
		
		if not Engine.is_editor_hint():
			if not is_inside_tree():
				await ready
			
			# But other cases, like the AI State machine can benefit from this.
			get_tree().set_group(StringName(get_path()), "character_attributes", attributes)

var is_on_air := false

## 三大高度参数（由 AnimationPlayer 轨道每帧赋值）
@export var base_height: float = 0.0

## 物理身高，用于 Layer 扩展计算（随动作变化，由 value track 写入）
@export var physical_height: float = 0.0

## 攻击判定相对 base_height 的高度偏移数组（由 value track 写入）
## 注意：必须使用 untyped Array（而非 Array[float]），因为 Godot 4 的 AnimationMixer
## 对 typed array 属性的 track 解析支持有限，会报 "couldn't resolve track" 警告
@export var attack_heights: Array = []

# 高度层缓存（避免每帧重复设置 collision layer）
var _cached_height_layers: Array[int] = []

# HurtBox/HitBox 缓存引用（从 Skin 获取，在 _ready 中初始化）
var _hurtbox: QuiverHurtBox
var _hitboxes: Array[QuiverHitBox] = []

#--- private variables - order: export > normal var > onready -------------------------------------

## This is also here as a "hack" for the lack of custom typed exports. It is private because I don't 
## want to deal with this in code, it's just an editor field to populate the real property which
## is the public [member attributes]. Once custom typed exports exist this will be converted
## to it.
@export var _attributes: Resource:
	set(value):
		attributes = value as QuiverAttributes
	get:
		return attributes

## Must point to a valid skin node. 
## [br][br]This is a "private" exported property just as reminder that this property 
## shouldn't be changed outside of it's own scene neither point to a Node that
## is outside the Scene.
@export_node_path("Node2D") var _path_skin := NodePath("Skin"):
	set(value):
		_path_skin = value
		if is_inside_tree():
			_skin = get_node_or_null(_path_skin) as QuiverCharacterSkin
		update_configuration_warnings()

## Must point to a valid collision node, either a CollisionPolygon2D or CollisionShape2D.
## [br][br]This is a "private" exported property just as reminder that this property 
## shouldn't be changed outside of it's own scene neither point to a Node that
## is outside the Scene.
@export_node_path("CollisionPolygon2D", "CollisionShape2D") 
var _path_collision := NodePath("Collision"):
	set(value):
		_path_collision = value
		if is_inside_tree():
			_collision = get_node_or_null(_path_collision)
		update_configuration_warnings()

@onready var _skin := get_node_or_null(_path_skin) as QuiverCharacterSkin
@onready var _collision := get_node_or_null(_path_collision) as Node2D
@warning_ignore("unused_private_class_variable")
@onready var _state_machine := $StateMachine as QuiverStateMachine

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	if Engine.is_editor_hint():
		QuiverEditorHelper.disable_all_processing(self)
		return
	
	const ERROR_BASE_SCENE_USED_DIRECTLY = (
		"You should not use this scene directly, inherit from it to create your characters"
	)
	var is_not_base_scene = \
			scene_file_path != "res://addons/quiver.beat_em_up/characters/quiver_character_base.tscn"
	assert(is_not_base_scene, ERROR_BASE_SCENE_USED_DIRECTLY)
	
	if attributes != null:
		attributes.character_node = self
	
	# 高度层系统：从 Skin 缓存 HurtBox/HitBox 引用
	if _skin:
		_hurtbox = _skin.hurtbox
		_hitboxes = _skin.hitboxes


func _get_configuration_warnings() -> PackedStringArray:
	const INVALID_SKIN = "_path_skin must point to a valid QuiverCharacterSkin Node." 
	const INVALID_COLLISION = \
			"_path_collision must point to a valid CollisionShape2D or CollisionPolygon2D Node."
	const INVALID_ATTRIBUTES = "attributes must have a valid CharacterAttributes resource."
	var warnings := PackedStringArray()
	
	if _attributes == null:
		@warning_ignore("return_value_discarded")
		warnings.append(INVALID_ATTRIBUTES)
	
	if _path_skin.is_empty() or _skin == null:
		@warning_ignore("return_value_discarded")
		warnings.append(INVALID_SKIN)
	
	if _path_collision.is_empty() or _collision == null:
		@warning_ignore("return_value_discarded")
		warnings.append(INVALID_COLLISION)
	
	return warnings


func _physics_process(_delta: float) -> void:
	_update_collision_layers()

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## Method to be overridden for character that can't be grabbed.
func can_deny_grabs() -> bool:
	return false

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _disable_collisions() -> void:
	_collision.set_deferred("disabled", true)


func _enable_collisions() -> void:
	_collision.set_deferred("disabled", false)


## AnimationPlayer 的 method track 每帧调用此方法
## 从 _skin.position.y 派生 base_height
func _sync_base_height() -> void:
	if is_instance_valid(_skin):
		base_height = -_skin.position.y


func _update_collision_layers() -> void:
	# 角色整体占据的高度层 = base_height ~ base_height + physical_height
	var current_layers := _calculate_range_layers(
		base_height, base_height + physical_height
	)
	
	# 只在层集合变化时更新（逐元素比较）
	if current_layers != _cached_height_layers:
		_cached_height_layers = current_layers
		# 仅设置 layer 15-19，保留原有的 bits
		for layer in range(15, 20):
			set_collision_layer_value(layer, layer in current_layers)
		_update_hurtbox_layers(_layers_to_bitmask(current_layers))
	
	_update_hitbox_layers()


func _update_hurtbox_layers(character_bitmask: int) -> void:
	if _hurtbox:
		_hurtbox.collision_layer = character_bitmask
		_hurtbox.collision_mask = _all_height_layers_bitmask()


func _update_hitbox_layers() -> void:
	var body_bitmask := _layers_to_bitmask(_cached_height_layers)
	
	if attack_heights.is_empty():
		# 非攻击状态：HitBox 复位为身体高度层（防御性复位）
		for hitbox in _hitboxes:
			hitbox.collision_layer = body_bitmask
		return
	
	# 攻击状态：根据 attack_heights 计算专属高度层
	var layers := []
	for attack_h in attack_heights:
		var absolute_h: float = base_height + attack_h
		layers.append_array(_height_to_layers(absolute_h))
	
	# 使用 Dictionary key 去重（GDScript Array 没有 .deduplicate() 方法）
	var unique_layers: Dictionary = {}
	for layer in layers:
		unique_layers[layer] = true
	layers = unique_layers.keys()
	
	var attack_bitmask := _layers_to_bitmask(layers)
	for hitbox in _hitboxes:
		hitbox.collision_layer = attack_bitmask


## 区间查询：角色 range [min_h, max_h] 与哪些层 (min, max] 有交集
func _calculate_range_layers(min_h: float, max_h: float) -> Array[int]:
	var result: Array[int] = []
	for def in HEIGHT_LAYER_DEFINITIONS:
		if min_h <= def["max"] and max_h > def["min"]:
			result.append(def["layer"])
	if result.is_empty():
		result.append(15)
	return result


## 点查询：某个高度 h 属于哪些层 (min, max]
func _height_to_layers(height: float) -> Array[int]:
	var result: Array[int] = []
	for def in HEIGHT_LAYER_DEFINITIONS:
		if height > def["min"] and height <= def["max"]:
			result.append(def["layer"])
	if result.is_empty():
		result.append(15)
	return result


## layer 编号转 bitmask：layer N 对应 bit (N-1)
func _layers_to_bitmask(layers: Array) -> int:
	var mask := 0
	for layer in layers:
		mask |= (1 << (layer - 1))
	return mask


func _all_height_layers_bitmask() -> int:
	var mask := 0
	for def in HEIGHT_LAYER_DEFINITIONS:
		mask |= (1 << (def["layer"] - 1))
	return mask

### -----------------------------------------------------------------------------------------------
