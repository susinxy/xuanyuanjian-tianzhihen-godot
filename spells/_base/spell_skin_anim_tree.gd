class_name SpellSkinAnimTree
extends SpellSkin

@export_node_path("AnimationTree") var _path_animation_tree := ^"AnimationTree"
@export var _path_playback := "parameters/state_machine/playback"

var _blend_positions := []

@onready var _animation_tree := get_node(_path_animation_tree) as AnimationTree
@onready var _playback := _animation_tree.get(_path_playback) as AnimationNodeStateMachinePlayback

func transition_to(anim_state: StringName) -> void:
	if _is_valid_state(anim_state):
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
	_animation_tree.active = true

func _in_editor_ready() -> void:
	super()
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
