@tool
extends EditorInspectorPlugin
## Inspector plugin for character management (create and delete characters)
## 
## This plugin activates when the user selects a CharacterTemplate node,
## which is located at characters/playable/_template/character_template.tscn
##
## Provides a widget with:
## - Create character form (name, class name, display name)
## - Delete character dropdown (lists all existing characters)

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const CreateNewCharacterWidget = preload(
	"res://addons/quiver.beat_em_up/custom_inspectors/create_new_character/"
	+"create_new_character_widget.gd"
)
const SCENE_WIDGET = preload(
	"res://addons/quiver.beat_em_up/custom_inspectors/create_new_character/"
	+"create_new_character_widget.tscn"
)

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var & onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _can_handle(object) -> bool:
	# Only activate when selecting a CharacterTemplate node
	# Check by class name to avoid issues before Godot scans the script
	if object is Node and object.get_script():
		var script = object.get_script()
		if script and script.get_global_name() == "CharacterTemplate":
			return true
	# Fallback type check
	return object is CharacterTemplate


func _parse_begin(object: Object) -> void:
	var widget := SCENE_WIDGET.instantiate() as CreateNewCharacterWidget
	QuiverEditorHelper.connect_between(widget.character_created, _on_character_created)
	QuiverEditorHelper.connect_between(widget.character_deleted, _on_character_deleted)
	QuiverEditorHelper.connect_between(widget.character_test_requested, _on_character_test_requested)
	add_custom_control(widget)


func _on_character_created(char_name: String) -> void:
	# Refresh the editor to show the new character
	EditorInterface.get_resource_filesystem().scan()
	print("[CharacterCreator] Character '%s' created successfully!" % char_name)


func _on_character_deleted(char_name: String) -> void:
	# Refresh the editor to hide the deleted character
	EditorInterface.get_resource_filesystem().scan()
	print("[CharacterCreator] Character '%s' deleted successfully!" % char_name)


func _on_character_test_requested(char_name: String) -> void:
	var test_scene_path = "res://scenes/_test_" + char_name + ".tscn"
	var character_scene_path = "res://characters/playable/" + char_name + "/" + char_name + ".tscn"
	
	# Check if character scene exists
	if not FileAccess.file_exists(character_scene_path):
		push_error("[CharacterCreator] Character scene not found: %s" % character_scene_path)
		return
	
	# Build test scene content using {{TOKEN}} replace pattern
	# (avoids GDScript `%` operator issues with multiline strings written to .tscn files)
	var test_scene_template = """[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="{{CHAR_PATH}}" id="1_character"]
[ext_resource type="PackedScene" path="res://addons/quiver.beat_em_up/utilities/custom_nodes/level_camera/quiver_level_camera.tscn" id="2_camera"]

[sub_resource type="RectangleShape2D" id="ground_shape"]
size = Vector2(4000, 100)

[node name="TestStage" type="Node2D"]

[node name="Background" type="ColorRect" parent="."]
offset_left = -5000.0
offset_top = -500.0
offset_right = 5000.0
offset_bottom = 2000.0
color = Color(0.18, 0.2, 0.25, 1)

[node name="Character" parent="." instance=ExtResource("1_character")]
position = Vector2(640, 400)

[node name="LevelCamera" parent="Character" instance=ExtResource("2_camera")]
offset = Vector2(0, -80)

[node name="GroundVisual" type="ColorRect" parent="."]
offset_left = -2000.0
offset_top = 480.0
offset_right = 4000.0
offset_bottom = 2000.0
color = Color(0.32, 0.28, 0.22, 1)

[node name="Ground" type="StaticBody2D" parent="."]
position = Vector2(640, 500)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Ground"]
shape = SubResource("ground_shape")

[node name="DebugLabel" type="Label" parent="."]
offset_left = 10.0
offset_top = 10.0
offset_right = 700.0
offset_bottom = 150.0
text = "测试角色: {{CHAR_NAME}}
操作: WASD 移动, Space 跳跃, J 攻击
按 F8 退出测试"
"""
	
	var test_scene_content = test_scene_template\
		.replace("{{CHAR_PATH}}", character_scene_path)\
		.replace("{{CHAR_NAME}}", char_name)
	
	# Ensure scenes directory exists
	if not DirAccess.dir_exists_absolute("res://scenes"):
		DirAccess.make_dir_recursive_absolute("res://scenes")
	
	# Write test scene
	var file = FileAccess.open(test_scene_path, FileAccess.WRITE)
	if file == null:
		push_error("[CharacterCreator] Failed to write test scene: %s" % test_scene_path)
		return
	file.store_string(test_scene_content)
	file.close()
	
	# Refresh filesystem and run the scene
	EditorInterface.get_resource_filesystem().scan()
	
	# Small delay to let filesystem scan pick up the new file
	await EditorInterface.get_resource_filesystem().filesystem_changed
	EditorInterface.play_custom_scene(test_scene_path)
	print("[CharacterCreator] Testing character '%s' - test scene: %s" % [char_name, test_scene_path])

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
