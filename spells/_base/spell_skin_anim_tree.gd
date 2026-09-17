class_name SpellSkinAnimTree
extends SpellSkin

@export_node_path("AnimationTree") var _path_animation_tree := ^"AnimationTree"
@export var _path_playback := "parameters/state_machine/playback"

var _blend_positions := []

@onready var _animation_tree := get_node(_path_animation_tree) as AnimationTree
@onready var _playback := _animation_tree.get(_path_playback) as AnimationNodeStateMachinePlayback

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

func end_of_spell_animation(_animation_name := "") -> void:
	if not _playback.get_travel_path().is_empty():
		return
	super()

func _populate_animation_list() -> void:
	_find_all_animation_nodes_from()
	_blend_positions = _get_blend_position_paths_from(_animation_tree)

func _skin_direction_updated() -> void:
	_update_blend_directions()

func _runtime_ready() -> void:
	super()
	if _animation_tree and _animation_tree.tree_root:
		_animation_tree.active = true

func _in_editor_ready() -> void:
	super()
	if _animation_tree and _animation_tree.tree_root:
		_animation_tree.set_deferred("active", false)

func _update_blend_directions() -> void:
	for path in _blend_positions:
		_animation_tree[path] = skin_direction

func _get_blend_position_paths_from(animation_tree: AnimationTree) -> Array:
	var blend_positions = []
	for property in animation_tree.get_property_list():
		if property.usage >= PROPERTY_USAGE_DEFAULT and property.name.ends_with("blend_position"):
			blend_positions.append(property.name)
	return blend_positions

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
			push_warning("%s is null" % [property_name])
		return
	
	var node_class := node.get_class()
	match node_class:
		"AnimationNodeAnimation", "AnimationNodeBlendSpace1D", \
		"AnimationNodeBlendSpace2D", "AnimationNodeBlendTree":
			var animation_name := _filter_main_playback_path(property_name, property_path) 
			_animation_list.append(animation_name)
		"AnimationNodeStateMachine":
			if not ignore_groups:
				var animation_name := _filter_main_playback_path(property_name, property_path) 
				_animation_list.append(animation_name)
			
			var parameter_name = _get_actual_parameter_name(property_name)
			property_path = property_path.path_join(parameter_name)
			_find_all_animation_nodes_from(node, property_path)
		_:
			if node is AnimationRootNode:
				push_error("Unknown animation node: %s" % [node_class])

func _filter_main_playback_path(animation_name: String, path: String) -> StringName:
	var parameter_name = _get_actual_parameter_name(animation_name)
	var full_path = path.path_join(parameter_name)
	var path_to_main_playback = _path_playback.replace("playback", "")
	var value = full_path.replace(path_to_main_playback, "") as StringName
	return value

func _get_actual_parameter_name(property_name: String) -> String:
	var parameter_name = property_name.split("/")[1]
	return parameter_name
