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

## 行为模式：决定"谁往本角色的私有输入通道里写指令"。
enum BehaviorMode {
	PLAYER_INPUT,  ## 玩家行为：采集物理键盘/手柄（全场唯一 OS 听众）
	AI_POLICY,     ## AI 行为：策略小抄脚本按决策写入
	PASSIVE,       ## 站立行为：零写入（剧情路人/商人/活道具）
}

#--- constants ------------------------------------------------------------------------------------

## 三种行为脚本的路径（运行时 load，避免与行为脚本形成编译期互引）
const BEHAVIOR_SCRIPTS := {
	BehaviorMode.PLAYER_INPUT: "res://addons/quiver.beat_em_up/characters/behaviors/quiver_behavior_player.gd",
	BehaviorMode.AI_POLICY: "res://addons/quiver.beat_em_up/characters/behaviors/quiver_behavior_ai.gd",
	BehaviorMode.PASSIVE: "res://addons/quiver.beat_em_up/characters/behaviors/quiver_behavior_idle.gd",
}

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

## 行为模式：玩家操控 / AI 策略 / 被动站立。非玩家角色由创建器写入场景。
@export var behavior_mode: BehaviorMode = BehaviorMode.PLAYER_INPUT

## AI_POLICY 模式挂载的策略小抄脚本（须为 QuiverBehaviorAI 的子类脚本）。
## 未配置时按约定自动加载同目录 `<场景文件名>_ai.gd`；两者皆无则退化为站立并告警。
@export var ai_policy_script: Script = null

@onready var _skin := get_node_or_null(_path_skin) as QuiverCharacterSkin
@onready var _collision := get_node_or_null(_path_collision) as Node2D
@warning_ignore("unused_private_class_variable")
@onready var _state_machine := $StateMachine as QuiverStateMachine

## 本角色私有的输入通道（虚拟手柄），_ready 中创建。
var channel: QuiverInputChannel = null

## 当前行为脚本节点（QuiverBehavior 子类实例；宽松类型避免编译期互引）。
var behavior: Node = null

## 状态机公开只读访问（行为脚本投递事件用）。
var state_machine: QuiverStateMachine:
	get:
		return _state_machine

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
	
	# 输入通道 + 行为脚本：本角色一切动作指令的唯一来源
	channel = QuiverInputChannel.new()
	_attach_behavior()

	# 阵营下发：根节点的 area2d:* 标签是唯一存放点，运行时挂到全部战斗盒
	# （皮肤场景不再存阵营数据——与高度层同款"运行时统一下发"模式）
	_distribute_factions()
	add_to_group("quiver_characters")  # 调试名册（坞用），非阵营语义


## 阵营下发（2026-09-17 单一存放点定档）：查敌我豁免的代码只认盒上的
## area2d: 组，而那份数据如今只存于根节点（表单"阵营标签"字段写入）。
## 经 add_faction_group 公开入口挂到受击盒与全部攻击盒——typed 直调
## add_to_group 会绕过脚本覆写导致缓存冻结（AGENTS 在案的陷阱，法术线同源）。
func _distribute_factions() -> void:
	var tags: Array[String] = []
	for g in get_groups():
		var gs := String(g)
		if gs.begins_with("area2d:"):
			tags.append(gs)
	if tags.is_empty():
		return
	if _hurtbox != null:
		for tag in tags:
			_hurtbox.add_faction_group(StringName(tag))
	for hb in _hitboxes:
		if hb != null:
			for tag in tags:
				hb.add_faction_group(StringName(tag))


func _get_configuration_warnings() -> PackedStringArray:
	const INVALID_SKIN = "_path_skin must point to a valid QuiverCharacterSkin Node." 
	const INVALID_COLLISION = \
			"_path_collision must point to a valid CollisionShape2D or CollisionPolygon2D Node."
	const INVALID_ATTRIBUTES = "attributes must have a valid CharacterAttributes resource."
	const NO_FACTION_TAG = \
			"根节点缺少 area2d:<阵营标签> 组——阵营是免伤的唯一通道，无标签的角色会打到自己。"
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

	# 阵营是免伤的唯一通道（判定层无 owner 自查）：根节点无标签=会打到自己
	var has_faction := false
	for g in get_groups():
		if String(g).begins_with("area2d:"):
			has_faction = true
			break
	if not has_faction:
		@warning_ignore("return_value_discarded")
		warnings.append(NO_FACTION_TAG)

	return warnings


func _physics_process(delta: float) -> void:
	# 泵水先行：父节点回调先于全部子节点执行，保证行为脚本写入通道的值
	# 在本物理帧内即可被状态机子节点读到，且不依赖场景树中的节点顺序
	if channel != null:
		channel.prune_stale_edges()
	if behavior != null:
		behavior.pre_physics(delta)
	_update_collision_layers()

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## Method to be overridden for character that can't be grabbed.
func can_deny_grabs() -> bool:
	return false


## 运行时切换操控权（剧情夺舍/队友接管等场景的接口位）。
## 通道保持原样挂载，只更换"写通道的人"；切换瞬间清空旧操控者残留。
func switch_behavior(mode: BehaviorMode) -> void:
	behavior_mode = mode
	if Engine.is_editor_hint():
		return
	if behavior != null:
		behavior.queue_free()
	if channel != null:
		channel.reset()
	_attach_behavior()

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

## 动态创建阴影渲染器
## 创建一个 Node2D 节点，挂载 character_shadow_controller.gd 脚本
## 内部创建 Polygon2D 子节点，渲染 ShadowBox polygon 投影到地面的形状
## 由 _ready() 在初始化阶段调用
func _create_shadow_renderer() -> void:
	if not _skin:
		return
	
	var sr := Node2D.new()
	sr.name = "ShadowRenderer"
	sr.z_index = -1
	sr.set_script(SHADOW_CONTROLLER_SCRIPT)
	add_child(sr)
	sr.setup(_skin)


## 按 behavior_mode 实例化行为脚本并挂到本角色下，注入宿主与通道。
## AI 档若未配置策略小抄，退化为站立并告警（不崩溃，方便场景调试期）。
func _attach_behavior() -> void:
	var script_path: String = BEHAVIOR_SCRIPTS.get(behavior_mode, "")
	if script_path.is_empty():
		return
	
	if behavior_mode == BehaviorMode.AI_POLICY:
		var policy := ai_policy_script
		if policy == null:
			policy = _load_policy_by_convention()
		if policy != null:
			# 策略小抄本身就是行为脚本的子类，直接用它实例化
			behavior = Node.new()
			behavior.set_script(policy)
			behavior.name = "Behavior"
			add_child(behavior)
			behavior.configure(self, channel)
			return
		push_warning("AI_POLICY 模式但未找到策略小抄（导出属性未配置且无约定文件 <场景名>_ai.gd），角色退化为被动站立。")
		script_path = BEHAVIOR_SCRIPTS[BehaviorMode.PASSIVE]
	
	var behavior_script := load(script_path)
	behavior = behavior_script.new()
	behavior.name = "Behavior"
	add_child(behavior)
	behavior.configure(self, channel)


## 约定加载：与场景文件同目录、同名的 `_ai.gd` 即为本角色的策略小抄。
## 创建器因此只需写一个 behavior_mode 整数，无需做 ext_resource 手术。
func _load_policy_by_convention() -> Script:
	if scene_file_path.is_empty():
		return null
	var policy_path := scene_file_path.get_base_dir().path_join(
			scene_file_path.get_file().get_basename() + "_ai.gd")
	# FileAccess 判定而非 ResourceLoader.exists：新建角色文件可能未经导入扫描
	if FileAccess.file_exists(policy_path):
		return load(policy_path) as Script
	return null


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
