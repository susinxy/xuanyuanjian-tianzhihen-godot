@tool
extends EditorInspectorPlugin
## Inspector plugin for spell management (create and delete spells)
## 
## This plugin activates when the user selects a SpellTemplate node,
## which is located at spells/_template/spell_template.tscn
##
## Provides a widget with:
## - Create spell form (name, class name, display name)
## - Delete spell dropdown (lists all existing spells)

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const CreateNewSpellWidget = preload(
	"res://addons/quiver.beat_em_up/custom_inspectors/create_new_spell/"
	+"create_new_spell_widget.gd"
)
const SCENE_WIDGET = preload(
	"res://addons/quiver.beat_em_up/custom_inspectors/create_new_spell/"
	+"create_new_spell_widget.tscn"
)

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var & onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _can_handle(object) -> bool:
	if object is Node and object.get_script():
		var script = object.get_script()
		if script and script.get_global_name() == "SpellTemplate":
			return true
	return object is SpellTemplate


func _parse_begin(object: Object) -> void:
	var widget := SCENE_WIDGET.instantiate() as CreateNewSpellWidget
	QuiverEditorHelper.connect_between(widget.spell_created, _on_spell_created)
	QuiverEditorHelper.connect_between(widget.spell_deleted, _on_spell_deleted)
	QuiverEditorHelper.connect_between(widget.spell_test_requested, _on_spell_test_requested)
	add_custom_control(widget)


func _on_spell_created(spell_name: String) -> void:
	EditorInterface.get_resource_filesystem().scan()
	print("[SpellCreator] Spell '%s' created successfully!" % spell_name)


func _on_spell_deleted(spell_name: String) -> void:
	EditorInterface.get_resource_filesystem().scan()
	print("[SpellCreator] Spell '%s' deleted successfully!" % spell_name)


func _on_spell_test_requested(char_name: String, spell_name: String) -> void:
	var test_scene_path = "res://scenes/_test_spell_" + spell_name + ".tscn"
	var character_scene_path = "res://characters/playable/" + char_name + "/" + char_name + ".tscn"
	var spell_definition_path = "res://spells/" + spell_name + "/resources/" + spell_name + "_definition.tres"
	var spell_scene_path = "res://spells/" + spell_name + "/" + spell_name + ".tscn"
	
	if not FileAccess.file_exists(character_scene_path):
		push_error("[SpellTest] Character scene not found: %s" % character_scene_path)
		return
	
	if not FileAccess.file_exists(spell_definition_path):
		push_error("[SpellTest] Spell definition not found: %s" % spell_definition_path)
		return
	
	var test_scene_template = """[gd_scene load_steps=9 format=3]

[ext_resource type="PackedScene" path="{{CHAR_PATH}}" id="1_character"]
[ext_resource type="PackedScene" path="res://addons/quiver.beat_em_up/utilities/custom_nodes/level_camera/quiver_level_camera.tscn" id="2_camera"]
[ext_resource type="PackedScene" path="res://characters/playable/enemy/enemy.tscn" id="3_enemy"]
[ext_resource type="Script" path="res://addons/quiver.beat_em_up/combat/quiver_attack_data.gd" id="4_attack_data"]
[ext_resource type="Script" path="" id="5_test_helper"]
[ext_resource type="Script" path="res://characters/playable/enemy/enemy_hurt_handler.gd" id="6_hurt_handler"]
[ext_resource type="Script" path="res://scripts/debug_spell_test_overlay.gd" id="7_debug_overlay"]
[ext_resource type="Shader" path="res://scenes/grid_background.gdshader" id="9_grid_shader"]

[sub_resource type="Resource" id="test_attack_data"]
script = ExtResource("4_attack_data")
attack_damage = 50.0
hurt_type = 0
knockback = 3
launch_angle = 30

[sub_resource type="RectangleShape2D" id="ground_shape"]
size = Vector2(8000, 200)

[sub_resource type="ShaderMaterial" id="ShaderMaterial_grid"]
shader = ExtResource("9_grid_shader")
shader_parameter/grid_size = 100.0
shader_parameter/sub_grid_size = 25.0
shader_parameter/line_width = 1.0
shader_parameter/sub_line_width = 0.5
shader_parameter/grid_color = Color(0.2, 0.2, 0.2, 1)
shader_parameter/sub_grid_color = Color(0.12, 0.12, 0.12, 1)
shader_parameter/bg_color = Color(0.06, 0.06, 0.06, 1)
shader_parameter/ground_line_y = 500.0
shader_parameter/ground_line_width = 3.0
shader_parameter/ground_line_color = Color(0.4, 0.3, 0.2, 1)

[node name="TestSpellStage" type="Node2D"]

[node name="Background" type="ColorRect" parent="."]
offset_left = -2000.0
offset_top = -500.0
offset_right = 6000.0
offset_bottom = 2000.0
material = SubResource("ShaderMaterial_grid")
color = Color(0.06, 0.06, 0.06, 1)

[node name="GroundLine" type="ColorRect" parent="."]
offset_left = -2000.0
offset_top = 495.0
offset_right = 6000.0
offset_bottom = 505.0
color = Color(0.3, 0.25, 0.2, 1)

[node name="Ground" type="StaticBody2D" parent="."]
position = Vector2(2000, 600)
collision_layer = 16384

[node name="CollisionShape2D" type="CollisionShape2D" parent="Ground"]
shape = SubResource("ground_shape")

[node name="Character" parent="." instance=ExtResource("1_character")]
position = Vector2(200, 480)

[node name="TestSpellHelper" type="Node" parent="Character"]

[node name="LevelCamera" parent="Character" instance=ExtResource("2_camera")]
offset = Vector2(0, -80)
zoom = 0.85
limit_left = 0
limit_top = -500
limit_right = 6000
limit_bottom = 1000

[node name="Enemy" parent="." instance=ExtResource("3_enemy")]
position = Vector2(522, 480)

[node name="HurtHandler" type="Node" parent="Enemy"]
script = ExtResource("6_hurt_handler")

[node name="Attack1" parent="Enemy/EnemySkin/Attacks" index="0"]
attack_data = SubResource("test_attack_data")

[node name="DebugLabel" type="Label" parent="."]
offset_left = 10.0
offset_top = 10.0
offset_right = 600.0
offset_bottom = 200.0
text = "=== 法术测试 ===

角色: {{CHAR_NAME}}
法术: {{SPELL_NAME}}

操作:
  WASD - 移动
  Space - 跳跃
  J - 攻击
  1 - 施放法术

按 ESC 退出测试"

[node name="DebugOverlay" type="CanvasLayer" parent="."]
layer = 10
script = ExtResource("7_debug_overlay")
player_path = NodePath("../Character")
enemy_path = NodePath("../Enemy")
"""
	
	var helper_script_content = """extends Node

var _spell_manager: SpellManager
var _spell_def: SpellDefinition

func _ready():
	var char_node = get_parent()
	_spell_manager = SpellManager.new(char_node)
	_spell_def = load("{{SPELL_DEF_PATH}}")
	_spell_def.spell_scene = load("{{SPELL_SCENE_PATH}}")
	_spell_manager.learn_spell(_spell_def)

func _physics_process(delta):
	_spell_manager.tick(delta)

func _unhandled_input(event):
	if event.is_action_pressed("spell_1"):
		_spell_manager.cast_spell_by_index(0)
"""
	
	# Write helper script
	var helper_script_path = "res://scripts/_test_spell_helper_" + spell_name + ".gd"
	if not DirAccess.dir_exists_absolute("res://scripts"):
		DirAccess.make_dir_recursive_absolute("res://scripts")
	
	var script_file = FileAccess.open(helper_script_path, FileAccess.WRITE)
	if script_file == null:
		push_error("[SpellTest] Failed to write helper script: %s" % helper_script_path)
		return
	
	helper_script_content = helper_script_content\
		.replace("{{SPELL_DEF_PATH}}", spell_definition_path)\
		.replace("{{SPELL_SCENE_PATH}}", spell_scene_path)
	script_file.store_string(helper_script_content)
	script_file.close()
	
	# Replace tokens in test scene
	var test_scene_content = test_scene_template\
		.replace("{{CHAR_PATH}}", character_scene_path)\
		.replace("{{CHAR_NAME}}", char_name)\
		.replace("{{SPELL_NAME}}", spell_name)
	
	# Update the helper script ext_resource path
	test_scene_content = test_scene_content.replace(
		'[ext_resource type="Script" path="" id="5_test_helper"]',
		'[ext_resource type="Script" path="' + helper_script_path + '" id="5_test_helper"]'
	)
	
	# Attach the script to TestSpellHelper node
	test_scene_content = test_scene_content.replace(
		'[node name="TestSpellHelper" type="Node" parent="Character"]',
		'[node name="TestSpellHelper" type="Node" parent="Character"]\nscript = ExtResource("5_test_helper")'
	)
	
	# Ensure scenes directory exists
	if not DirAccess.dir_exists_absolute("res://scenes"):
		DirAccess.make_dir_recursive_absolute("res://scenes")
	
	# Write test scene
	var file = FileAccess.open(test_scene_path, FileAccess.WRITE)
	if file == null:
		push_error("[SpellTest] Failed to write test scene: %s" % test_scene_path)
		return
	file.store_string(test_scene_content)
	file.close()
	
	# Refresh filesystem and run the scene
	EditorInterface.get_resource_filesystem().scan()
	
	await EditorInterface.get_resource_filesystem().filesystem_changed
	EditorInterface.play_custom_scene(test_scene_path)
	print("[SpellTest] Testing spell '%s' with character '%s' - test scene: %s" % [spell_name, char_name, test_scene_path])

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
