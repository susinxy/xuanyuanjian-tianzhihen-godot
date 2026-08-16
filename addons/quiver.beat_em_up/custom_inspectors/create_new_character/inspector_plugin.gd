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
	# 
	# 2.5D 碰撞约束:
	# - 所有物理碰撞使用 CapsuleShape2D (radius=20, height 可调)
	# - CapsuleShape2D 旋转 90° 水平放置
	# - 所有物体底部贴着 ground_level 线 (Y=500)
	# - 物体 position.y = 480 (因为 radius=20)
	# - 地面不需要物理碰撞，只有可视化
	var test_scene_template = """[gd_scene load_steps=12 format=3]

[ext_resource type="PackedScene" path="{{CHAR_PATH}}" id="1_character"]
[ext_resource type="PackedScene" path="res://addons/quiver.beat_em_up/utilities/custom_nodes/level_camera/quiver_level_camera.tscn" id="2_camera"]
[ext_resource type="Script" path="res://scripts/debug_height_overlay.gd" id="3_debug_overlay"]
[ext_resource type="PackedScene" path="res://characters/playable/enemy/enemy.tscn" id="4_enemy"]
[ext_resource type="Script" path="res://characters/playable/enemy/enemy_periodic_attack.gd" id="5_periodic_attack"]
[ext_resource type="Script" path="res://scripts/debug_knockout_overlay.gd" id="6_knockout_overlay"]
[ext_resource type="Script" path="res://scripts/test_wall_bounce_setup.gd" id="7_test_setup"]

[sub_resource type="CapsuleShape2D" id="short_wall_shape"]
radius = 20.0
height = 60.0

[sub_resource type="CapsuleShape2D" id="tall_wall_shape"]
radius = 20.0
height = 60.0

[sub_resource type="CapsuleShape2D" id="platform_shape"]
radius = 20.0
height = 300.0

[sub_resource type="RectangleShape2D" id="ground_shape"]
size = Vector2(8000, 200)

[node name="TestStage" type="Node2D"]

[node name="TestSetup" type="Node" parent="."]
script = ExtResource("7_test_setup")

[node name="Background" type="ColorRect" parent="."]
offset_left = -2000.0
offset_top = -500.0
offset_right = 6000.0
offset_bottom = 2000.0
color = Color(0.15, 0.18, 0.22, 1)

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

[node name="LevelCamera" parent="Character" instance=ExtResource("2_camera")]
offset = Vector2(0, -80)
zoom = 0.85
limit_left = -2000
limit_top = -500
limit_right = 6000
limit_bottom = 1000

[node name="Enemy" parent="." instance=ExtResource("4_enemy")]
position = Vector2(350, 480)

[node name="PeriodicAttack" type="Node" parent="Enemy"]
script = ExtResource("5_periodic_attack")
facing_direction = -1
use_combo = true
rest_duration = 1.5

[node name="ShortWall" type="StaticBody2D" parent="."]
position = Vector2(600, 480)
collision_layer = 16384

[node name="CollisionShape2D" type="CollisionShape2D" parent="ShortWall"]
rotation = 1.5708
shape = SubResource("short_wall_shape")

[node name="Visual" type="ColorRect" parent="ShortWall"]
offset_left = -30.0
offset_top = -140.0
offset_right = 30.0
offset_bottom = 20.0
color = Color(0.8, 0.6, 0.3, 1)

[node name="Label" type="Label" parent="ShortWall"]
offset_left = -40.0
offset_top = -100.0
offset_right = 40.0
offset_bottom = -80.0
text = "矮墙 160px"
horizontal_alignment = 1

[node name="TallWall" type="StaticBody2D" parent="."]
position = Vector2(2000, 480)
collision_layer = 16760832

[node name="CollisionShape2D" type="CollisionShape2D" parent="TallWall"]
rotation = 1.5708
shape = SubResource("tall_wall_shape")

[node name="Visual" type="ColorRect" parent="TallWall"]
offset_left = -30.0
offset_top = -380.0
offset_right = 30.0
offset_bottom = 20.0
color = Color(0.7, 0.3, 0.3, 1)

[node name="Label" type="Label" parent="TallWall"]
offset_left = -40.0
offset_top = -220.0
offset_right = 40.0
offset_bottom = -200.0
text = "高墙 400px"
horizontal_alignment = 1

[node name="Platform" type="StaticBody2D" parent="."]
position = Vector2(1300, 480)
collision_layer = 262144

[node name="CollisionShape2D" type="CollisionShape2D" parent="Platform"]
rotation = 1.5708
shape = SubResource("platform_shape")

[node name="Visual" type="ColorRect" parent="Platform"]
offset_left = -150.0
offset_top = -20.0
offset_right = 150.0
offset_bottom = 20.0
color = Color(0.3, 0.7, 0.5, 1)

[node name="Label" type="Label" parent="Platform"]
offset_left = -60.0
offset_top = -40.0
offset_right = 60.0
offset_bottom = -20.0
text = "悬空平台"
horizontal_alignment = 1

[node name="DebugLabel" type="Label" parent="."]
offset_left = 10.0
offset_top = 270.0
offset_right = 500.0
offset_bottom = 510.0
text = "=== 2.5D 高度层碰撞测试 ===

操作: WASD 移动, Space 跳跃, J 攻击

测试项目:
1. 跳跃穿过矮墙 (160px) - 跳跃时 base_height > 160 可通过
2. 钻过悬空平台 - 从平台下方通过
3. 撞击高墙 (400px) - 应该被阻挡
4. 攻击敌人 - 验证 player→enemy 伤害
5. 被敌人攻击 - 验证 enemy→player 伤害和击飞

观察右上角调试面板查看实时高度层信息"

[node name="DebugHeightOverlay" type="CanvasLayer" parent="."]
script = ExtResource("3_debug_overlay")
character = NodePath("../Character")

[node name="DebugKnockoutOverlay" type="CanvasLayer" parent="."]
script = ExtResource("6_knockout_overlay")
character = NodePath("../Character")
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
