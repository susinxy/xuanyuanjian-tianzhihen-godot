@tool
class_name  QuiverCharacterSkinAnimTree 
extends QuiverCharacterSkin
## Extends base CharacterSkin class, for skins that use AnimationTree.

## Write your doc string for this file here

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

## Path to animation tree. [br][br]
## Kept the underscore to make it "private" because it's not suposed to be changed
## from outside of the scene, to point to an external [AnimationTree] for example.
@export_node_path("AnimationTree") var _path_animation_tree := ^"AnimationTree"

## Path to [AnimationNodeStateMachinePlayback]. Usually I create an [AnimationNodeBlendTree] as the
## root for the [AnimationTree] and the [AnimationNodeStateMachine] inside it, so I can do anything 
## with the output of the state machine playback, like changing the time scale for example. 
## Use this to point to the correct path if you structure your [AnimationTree] in a different way. 
## [br][br]
## See [member _path_animation_tree] for "private" reasoning.
@export var _path_playback := "parameters/StateMachine/playback"

var _blend_positions_1d := []
var _blend_positions_2d := []
var _last_facing_x: float = 1.0

@onready var _animation_tree := get_node(_path_animation_tree) as AnimationTree
@onready var _playback := _animation_tree.get(_path_playback) as AnimationNodeStateMachinePlayback

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _get_configuration_warnings() -> PackedStringArray:
	var msgs := PackedStringArray()
	
	if not _animation_tree:
		msgs.append("Invalid _path_animation_tree: %s"%[_path_animation_tree])
	
	if not _playback:
		msgs.append(
				"Invalid _path_playback: %s. Could not find playback in AnimationTree"%[
					_path_playback
				]
		)
	
	return msgs


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_POST_SAVE and Engine.is_editor_hint():
		if is_instance_valid(_animation_tree) and _animation_tree.tree_root != null:
			_animation_list.clear()
			_populate_animation_list()

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## Main public method for the skin, it will check if the parameter is valid and transition to it.
## 脑（游戏状态机）最近一次指挥的目的地。自回访的同步判据基于它：
## "脑改主意"才是新播放请求；同目的地的每帧重登记（mid_air 等腾空产线
## 惯例）是幂等声明，绝不允许扰动身体——rising/falling 尾帧保持正是设计意图。
var _brain_destination := &""


func transition_to(anim_state: StringName) -> void:
	if not _is_valid_state(anim_state):
		return
	var is_new_intent := anim_state != _brain_destination
	_brain_destination = anim_state
	if String(_playback.get_current_node()) == String(anim_state):
		# 自回访（2026-09-17 三案终定档，判据=脑的意图而非身体的时钟）：
		#  · 攻击末帧冻结案——脑同栈背靠背 idle→attack1 而身体从未离开、
		#    动画已钉死末尾：新意图+身体在原地=不同步，start() 重入倒带
		#    完成同步（seek/current_position 参数写入全静默无效，复现台裁决）。
		#  · 腾空倒带回归案——同目的地幂等重登记一律 no-op：rising/falling
		#    播完停尾帧是悬停姿势的设计意图（H6 双断言锁死两面）。
		if is_new_intent:
			_playback.start(anim_state)
	else:
		_playback.travel(anim_state)


## 历史注记（2026-09-26 拆除）：本类曾覆写 end_of_skin_animation 做"travel 在途
## 吞信标"守卫（上游 3.x 遗产，作者自注来历不明）。4.7.1 探针实测：状态离开后
## 旧动画时钟冻结，假想中的"在途误发/重发"不存在；六次合法发射全部发生在
## travel_path 清空之后——守卫零触发面，且保留反而有吞真信标的负风险。
## 基类 QuiverCharacterSkin.end_of_skin_animation 直接接管。案卷见
## docs/PLUGIN_ARCHITECTURE.md 皮肤章与根 PLUGIN_CHANGES.md。


## 时间控制通道（B4.7，真皮肤判决 2026-09-26 probe4）：本树内置的
## AnimationNodeTimeScale 节点（output←time_scale←state_machine）——上游
## 作者在 _path_playback 注释里明写此树为"改时间刻度"而设。
## ⚠ 勘误 T0 裁决：player.speed_scale 在合成台架上确有 2.55× 拉长（P3），
## 但**真皮肤树驱动下不通电**（基线 8f vs player 档 8f，零差；time_scale
## 档 13f=6 帧窗×0.2 的算术精确应验）——H1b 行为级锁当场抓获"属性挂上
## ≠时钟变慢"。本仓全部皮肤树（chen/template/spar/vendor/test_actor 4/4 查
## 验）均含该节点；缺失=非标准皮肤，降级告警并退回 player 路（直驱皮肤）。
const TIME_SCALE_PARAM := "parameters/time_scale/scale"

var _no_timescale_warned := false

## 倍速写通道：树刻度节点优先（覆写基类 player 路）。
func set_anim_time_scale(rate: float) -> void:
	if _animation_tree != null and TIME_SCALE_PARAM in _animation_tree:
		_animation_tree.set(TIME_SCALE_PARAM, rate)
		return
	if not _no_timescale_warned:
		_no_timescale_warned = true
		push_warning(
				"B4.7: 皮肤 %s 动画树无 %s 节点，时间倍速降级 AnimationPlayer 通道"
				% [name, TIME_SCALE_PARAM])
	super(rate)


## 倍速观测通道：与写通道同源（读树刻度节点；退化路读 player）。
func anim_time_scale() -> float:
	if _animation_tree != null and TIME_SCALE_PARAM in _animation_tree:
		return float(_animation_tree.get(TIME_SCALE_PARAM))
	return super()


## 状态树路的"当前动画总长"（B4.7 命中慢放窗口分母；覆写基类直驱路——
## AnimTree 驱动下 player.get_current_animation() 恒空，探针实锤）：
## playback 当前状态 → states/<名>/node → 混合空间按 blend_position 就近取点
## → AnimationNodeAnimation 全名（含"库/"前缀）→ AnimationPlayer 查库取长。
## 枚举全走属性列表法（本构建 get_nodes/get_node_names/get_input_count 族
## 不可用/具误导性，T0 判例）。任一环节不可得=-1.0，由调用方兜底。
func current_anim_length_ms() -> float:
	var player := _resolve_anim_player()
	if player == null or _animation_tree == null or _playback == null:
		return -1.0
	var cur := String(_playback.get_current_node())
	if cur.is_empty():
		return -1.0
	var sm := _state_machine_node()
	if sm == null:
		return -1.0
	var state_node: AnimationNode = sm.get("states/%s/node" % cur)
	if state_node == null:
		return -1.0
	var anim_full := _resolve_state_anim(state_node, cur)
	if anim_full == &"":
		return -1.0
	return _anim_length_ms(player, anim_full)


## 由 _path_playback 反推主状态机节点（本仓皮肤形制 "parameters/<名>/playback"
## —— BlendTree 根 + 命名节点；裸 "parameters/playback" 则根即状态机）。
## 硬编码节点名是雷：test_actor 皮肤实况名 = "state_machine"，非模板默认
## "StateMachine"（探针实锤），一切从 _path_playback 推导。
func _state_machine_node() -> AnimationNodeStateMachine:
	if _animation_tree == null or _animation_tree.tree_root == null:
		return null
	var parts := _path_playback.split("/")
	if parts.size() < 2:
		return null
	if parts.size() == 2:
		return _animation_tree.tree_root as AnimationNodeStateMachine
	return _animation_tree.tree_root.get("nodes/%s/node" % parts[1]) \
			as AnimationNodeStateMachine


## 当前状态节点 → 实际在播的动画全名：直连动画节点取 animation；
## 混合空间按参数 blend_position 就近取点（皮肤契约=方向量化到混合基、
## 单动画满权重，见 snap_to_blend_basis；"就近"只是对非满权形制的保守
## 退化，本仓正常路径下距离恒 0）。取不到=空 StringName。
func _resolve_state_anim(state_node: AnimationNode, cur: String) -> StringName:
	if state_node is AnimationNodeAnimation:
		return (state_node as AnimationNodeAnimation).animation
	var is_1d := state_node is AnimationNodeBlendSpace1D
	var is_2d := state_node is AnimationNodeBlendSpace2D
	if not (is_1d or is_2d):
		return &""
	var param_path := _path_playback.replace("playback", "") + cur + "/blend_position"
	if not param_path in _animation_tree:
		return &""
	var blend = _animation_tree.get(param_path)
	var target := _as_blend_vector(blend)
	var best: AnimationNodeAnimation = null
	var best_dist := INF
	for prop in state_node.get_property_list():
		var pname := String(prop.name)
		if not pname.begins_with("blend_point_") or not pname.ends_with("/pos"):
			continue
		var point_pos = state_node.get(pname)
		var dist: float = target.distance_to(_as_blend_vector(point_pos))
		if dist < best_dist:
			best_dist = dist
			var node_key := pname.trim_suffix("/pos") + "/node"
			best = state_node.get(node_key) as AnimationNodeAnimation
	if best == null:
		return &""
	return best.animation


## 混合坐标归一：1D 的标量 pos 视作 (x,0)，2D 原样（属性枚举混合空间的
## 通用底座；Vector2.INF=不可比哨兵，distance_to 自然得 INF 不被选中）。
static func _as_blend_vector(v) -> Vector2:
	match typeof(v):
		TYPE_VECTOR2:
			return v
		TYPE_FLOAT:
			return Vector2(v, 0.0)
		TYPE_INT:
			return Vector2(float(v), 0.0)
	return Vector2.INF

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _populate_animation_list() -> void:
	_find_all_animation_nodes_from()
	_blend_positions_1d.clear()
	_blend_positions_2d.clear()
	_categorize_blend_positions(_animation_tree.tree_root, "parameters")


func _skin_direction_updated() -> void:
	_update_blend_directions()


func _in_editor_ready() -> void:
	QuiverEditorHelper.disable_all_processing(self)
	if _animation_tree and _animation_tree.tree_root:
		_animation_tree.set_deferred("active", false)


func _runtime_ready() -> void:
	super()
	if _animation_tree and _animation_tree.tree_root:
		_animation_tree.active = true
		for path in _blend_positions_1d:
			_animation_tree[path] = facing_x


## Helper to create getters for public condition properties.
func _get_animation_tree_condition(path: StringName) -> bool:
	if not is_inside_tree() or not path in _animation_tree:
		return false
	return _animation_tree.get(path)


## Helper to create setters for public condition properties.
func _set_animation_tree_condition(path: StringName, value: bool) -> void:
	if not is_inside_tree():
		await ready
	
	if not path in _animation_tree:
		return
	
	_animation_tree.set(path, value)


func _update_blend_directions() -> void:
	if facing_x != _last_facing_x:
		for path in _blend_positions_1d:
			_animation_tree[path] = facing_x
		_last_facing_x = facing_x
	for path in _blend_positions_2d:
		_animation_tree[path] = skin_direction


func _get_blend_position_paths_from(animation_tree: AnimationTree) -> Array:
	var blend_positions = []
	
	for property in animation_tree.get_property_list():
		if property.usage >= PROPERTY_USAGE_DEFAULT and property.name.ends_with("blend_position"):
			blend_positions.append(property.name)
	
	return blend_positions


func _categorize_blend_positions(node: AnimationNode, path: String) -> void:
	if node == null:
		return
	
	for prop in node.get_property_list():
		if prop.hint_string == "AnimationNode":
			var child = node.get(prop.name)
			if child == null:
				continue
			var parameter_name = _get_actual_parameter_name(prop.name)
			var child_path = path.path_join(parameter_name)
			if child is AnimationNodeBlendSpace1D:
				_blend_positions_1d.append(child_path.path_join("blend_position"))
				_categorize_blend_positions(child, child_path)
			elif child is AnimationNodeBlendSpace2D:
				_blend_positions_2d.append(child_path.path_join("blend_position"))
				_categorize_blend_positions(child, child_path)
			else:
				_categorize_blend_positions(child, child_path)


func _find_all_animation_nodes_from(
		animation_node: AnimationNode = null, 
		property_path := "parameters"
) -> void:
	if property_path == "parameters":
		animation_node = _animation_tree.tree_root
	
	if animation_node == null:
		return
	
	var should_ignore_child_state_machines := true
	if animation_node is AnimationNodeStateMachine:
		should_ignore_child_state_machines = false
	
	var properties := animation_node.get_property_list()
	for property_dict in properties:
		match property_dict:
			{"hint_string": "AnimationNode", ..}:
				_handle_animation_node(
						animation_node.get(property_dict.name), 
						property_dict.name,
						property_path,
						should_ignore_child_state_machines
				)


func _handle_animation_node(
		node: AnimationNode, 
		property_name: String, 
		property_path: String,
		ignore_groups := false
) -> void:
	if node == null:
		if property_name.find("Start") == -1 and property_name.find("End") == -1:
			push_warning("%s is null"%[property_name])
		return
	
	var node_class := node.get_class()
	match node_class:
		"AnimationNodeAnimation", "AnimationNodeBlendSpace1D", \
		"AnimationNodeBlendSpace2D", "AnimationNodeBlendTree":
			var animation_name := _filter_main_playback_path(property_name, property_path) 
			_animation_list.append(animation_name)
		"AnimationNodeStateMachine":
			if not ignore_groups :
				var animation_name := _filter_main_playback_path(property_name, property_path) 
				_animation_list.append(animation_name)
			
			var parameter_name = _get_actual_parameter_name(property_name)
			property_path = property_path.path_join(parameter_name)
			_find_all_animation_nodes_from(node, property_path)
		_:
			if node is AnimationRootNode:
				push_error("Unknown animation node: %s"%[node_class])


func _filter_main_playback_path(animation_name: String, path: String) -> StringName:
	var parameter_name = _get_actual_parameter_name(animation_name)
	var full_path = path.path_join(parameter_name)
	var path_to_main_playback = _path_playback.replace("playback", "")
	var value = full_path.replace(path_to_main_playback, "") as StringName
	return value


## property names for these AnimationNodes are in the format "nodes/name/node" 
## or "states/name/node" so this is to get the middle part of that name
func _get_actual_parameter_name(property_name: String) -> String:
	var parameter_name = property_name.split("/")[1]
	return parameter_name

### -----------------------------------------------------------------------------------------------
