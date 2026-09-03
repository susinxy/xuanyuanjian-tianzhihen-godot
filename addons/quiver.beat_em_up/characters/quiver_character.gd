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

## 高度层系统常量
## Godot 4 中，layer N 对应 bit (N-1)：layer 15 = bit 14 = 1<<14
## 这里使用 layer 编号（1-indexed），与 Godot Inspector 一致
const HEIGHT_LAYER_FIRST := 15
const HEIGHT_LAYER_COUNT := 10
const HEIGHT_LAYER_LAST := 24  # HEIGHT_LAYER_FIRST + HEIGHT_LAYER_COUNT - 1
const SETTINGS_STANDARD_HEIGHT := "quiver/beat_em_up/gameplay/standard_height"
const LAYER_THICKNESS_RATIO := 0.75

## 阴影渲染器脚本（由 _create_shadow_renderer() 动态挂载到 Polygon2D）
const SHADOW_CONTROLLER_SCRIPT := preload(
	"res://scripts/character_shadow_controller.gd")

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

# 高度层缓存（避免每帧重复设置 collision layer）
var _cached_height_layers: Array[int] = []

# 高度层定义（运行时从 project settings 构建）
var _height_definitions: Array = []

# HurtBox/HitBox 缓存引用（从 Skin 获取，在 _ready 中初始化）
var _hurtbox: QuiverHurtBox
var _hitboxes: Array[QuiverHitBox] = []

# 高度层 bitmask 缓存（_ready 中计算一次，避免每帧循环）
var _height_layers_all_mask: int = 0

# HitBox 高度层缓存（只在值变化时更新 collision_layer）
var _cached_hitbox_height_bits: int = -1

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
	
	# 高度层系统：从 project settings 构建层定义
	_height_definitions = _build_height_definitions()
	_height_layers_all_mask = _all_height_layers_bitmask()
	
	# 高度层系统：从 Skin 缓存 HurtBox/HitBox 引用
	if _skin:
		_hurtbox = _skin.hurtbox
		_hitboxes = _skin.hitboxes
	
	# 阴影系统：动态创建 ShadowRenderer
	_create_shadow_renderer()


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

## 动态创建阴影渲染器
## 创建一个 Sprite2D 节点，挂载 character_shadow_controller.gd 脚本
## vertex() 将 1×1 矩形变形为平行四边形
## 由 _ready() 在初始化阶段调用
func _create_shadow_renderer() -> void:
	if not _skin:
		return
	
	var sr := Sprite2D.new()
	sr.name = "ShadowRenderer"
	sr.z_index = -1
	sr.set_script(SHADOW_CONTROLLER_SCRIPT)
	add_child(sr)
	sr.setup(_skin)


func _disable_collisions() -> void:
	_collision.set_deferred("disabled", true)


func _enable_collisions() -> void:
	_collision.set_deferred("disabled", false)


func _update_collision_layers() -> void:
	# 高度层数据存放在 Skin 节点（由 AnimationPlayer track 直接写入）
	if not _skin:
		return
	
	var bh: float = _skin.base_height
	var ph: float = _skin.physical_height
	var ah: Array = _skin.attack_heights
	var pw: float = _skin.physical_width
	
	# 更新物理体碰撞胶囊宽度（CapsuleShape2D.height）
	if _collision and pw > 0.0:
		var capsule: CapsuleShape2D = _collision.shape as CapsuleShape2D
		if capsule and capsule.height != pw:
			capsule.height = pw
	
	# 角色整体占据的高度层 = base_height ~ base_height + physical_height
	var current_layers := _calculate_range_layers(bh, bh + ph)
	
	# 只在层集合变化时更新（逐元素比较）
	if current_layers != _cached_height_layers:
		_cached_height_layers = current_layers
		# 仅设置高度层，保留原有的 bits
		for layer in range(HEIGHT_LAYER_FIRST, HEIGHT_LAYER_LAST + 1):
			set_collision_layer_value(layer, layer in current_layers)
		# 同步更新 collision_mask，包含当前高度层（用于与高度层障碍物碰撞）
		# 保留除高度层之外的所有 bits，添加当前高度层
		var height_bitmask := _layers_to_bitmask(current_layers)
		collision_mask = (collision_mask & ~_height_layers_all_mask) | height_bitmask
		_update_hurtbox_layers(height_bitmask)
	
	_update_hitbox_layers(bh, ah, _layers_to_bitmask(_cached_height_layers))


func _update_hurtbox_layers(character_bitmask: int) -> void:
	if _hurtbox:
		_hurtbox.collision_layer = (_hurtbox.collision_layer & ~_height_layers_all_mask) | character_bitmask
		_hurtbox.collision_mask = (_hurtbox.collision_mask & ~_height_layers_all_mask) | character_bitmask


func _update_hitbox_layers(base_h: float, attack_hs: Array, body_bitmask: int) -> void:
	var target_bits: int
	if attack_hs.is_empty():
		target_bits = body_bitmask
	else:
		target_bits = 0
		for attack_h in attack_hs:
			var absolute_h: float = base_h + attack_h
			target_bits |= (1 << (_height_to_layer(absolute_h) - 1))
	
	if target_bits != _cached_hitbox_height_bits:
		_cached_hitbox_height_bits = target_bits
		for hitbox in _hitboxes:
			hitbox.collision_layer = (hitbox.collision_layer & ~_height_layers_all_mask) | target_bits


## 区间查询：角色 range [min_h, max_h] 与哪些层 (min, max] 有交集
func _calculate_range_layers(min_h: float, max_h: float) -> Array[int]:
	var result: Array[int] = []
	for def in _height_definitions:
		if min_h <= def["max"] and max_h > def["min"]:
			result.append(def["layer"])
	if result.is_empty():
		result.append(HEIGHT_LAYER_FIRST)
	return result


## 点查询：某个高度 h 属于哪个层 (min, max]，返回单个层编号
func _height_to_layer(height: float) -> int:
	for def in _height_definitions:
		if height > def["min"] and height <= def["max"]:
			return def["layer"]
	return HEIGHT_LAYER_FIRST


## layer 编号转 bitmask：layer N 对应 bit (N-1)
func _layers_to_bitmask(layers: Array) -> int:
	var mask := 0
	for layer in layers:
		mask |= (1 << (layer - 1))
	return mask


func _all_height_layers_bitmask() -> int:
	return get_all_height_layers_mask()


## 计算全高度层 bitmask（静态方法，可在任何地方调用）
static func get_all_height_layers_mask() -> int:
	var mask := 0
	for i in range(HEIGHT_LAYER_COUNT):
		mask |= (1 << (HEIGHT_LAYER_FIRST + i - 1))
	return mask


## 从 project settings 构建高度层定义
## standard_height (SH) 从 project settings 读取，层厚度 = SH × LAYER_THICKNESS_RATIO
static func _build_height_definitions() -> Array:
	var sh: float = ProjectSettings.get_setting(SETTINGS_STANDARD_HEIGHT, 180.0)
	var thickness: float = sh * LAYER_THICKNESS_RATIO
	var result := []
	for i in range(HEIGHT_LAYER_COUNT):
		var min_h: float = i * thickness
		var max_h: float = INF if i == HEIGHT_LAYER_COUNT - 1 else (i + 1) * thickness
		result.append({"min": min_h, "max": max_h, "layer": HEIGHT_LAYER_FIRST + i})
	return result

## 获取高度层定义（公开包装方法，供外部调用）
static func get_height_definitions() -> Array:
	return _build_height_definitions()

## 将高度值转换为层号（公开方法，供外部调用）
static func height_to_layer(height: float, height_definitions: Array) -> int:
	for def in height_definitions:
		if height > def["min"] and height <= def["max"]:
			return def["layer"]
	return HEIGHT_LAYER_FIRST

## 将层号数组转换为 bitmask（公开方法，供外部调用）
static func layers_to_bitmask(layers: Array) -> int:
	var mask := 0
	for layer in layers:
		mask |= (1 << (layer - 1))
	return mask

### -----------------------------------------------------------------------------------------------
