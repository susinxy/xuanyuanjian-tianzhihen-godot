@tool
extends RefCounted
class_name SpellCreator

const TEMPLATE_DIR = "res://spells/_template/"
const SPELL_DIR = "res://spells/"

const TOKEN_NAME = "__NAME__"
const TOKEN_CLASS = "__CLASS__"
const TOKEN_DISPLAY = "__DISPLAY_NAME__"

const EXCLUDED_FILES = [
    "spell_template.tscn",
    "spell_template.gd",
    "spell_template.gd.uid",
    "README.md",
]

func create_spell(spell_name: String, pascal_name: String, display_name: String) -> bool:
    var target_dir = SPELL_DIR.path_join(spell_name)
    
    if DirAccess.dir_exists_absolute(target_dir):
        push_error("Spell directory already exists: %s" % target_dir)
        return false
    
    # Step 1: Create target directory
    if DirAccess.make_dir_recursive_absolute(target_dir + "/resources/animations") != OK:
        push_error("Failed to create directory: %s" % target_dir)
        return false
    
    # Step 2: Copy template (excluding EXCLUDED_FILES)
    if not _copy_directory_recursive(TEMPLATE_DIR, target_dir):
        push_error("Failed to copy template files")
        return false
    
    # Step 3: Rename files containing __NAME__
    if not _rename_files_recursive(target_dir, spell_name):
        push_error("Failed to rename template files")
        return false
    
    # Step 4: Replace placeholders
    if not _replace_placeholders_recursive(target_dir, spell_name, pascal_name, display_name):
        push_error("Failed to replace placeholders")
        return false
    
    # Step 5: Generate animation files
    if not _generate_animation_files(target_dir, spell_name, pascal_name):
        push_error("Failed to generate animation files")
        return false
    
    # Step 6: Delete .import files to avoid UID duplication
    # Godot will regenerate them with unique UIDs on next filesystem scan
    if not _delete_import_files_recursive(target_dir):
        push_warning("Failed to delete some .import files (non-critical)")
    
    print_rich("[color=green]✓ Spell created: %s (%s) at %s[/color]" % [display_name, spell_name, target_dir])
    return true


func _copy_directory_recursive(source: String, destination: String) -> bool:
    var dir := DirAccess.open(source)
    if dir == null:
        push_error("Failed to open source directory: %s (error code: %d)" % [source, DirAccess.get_open_error()])
        return false
    
    dir.list_dir_begin()
    var file_name := dir.get_next()
    
    while not file_name.is_empty():
        if file_name != "." and file_name != "..":
            var source_path = source.path_join(file_name)
            var dest_path = destination.path_join(file_name)
            
            if dir.current_is_dir():
                if file_name == "animations":
                    # Skip animations directory (will be generated)
                    file_name = dir.get_next()
                    continue
                if DirAccess.make_dir_recursive_absolute(dest_path) != OK:
                    push_error("Failed to create subdirectory: %s" % dest_path)
                    return false
                if not _copy_directory_recursive(source_path, dest_path):
                    return false
            else:
                if file_name not in EXCLUDED_FILES and not file_name.ends_with(".uid"):
                    if not _copy_file(source_path, dest_path):
                        return false
        
        file_name = dir.get_next()
    
    return true


func _copy_file(source: String, destination: String) -> bool:
    var ext := source.get_extension()
    var is_binary := ext in ["png", "jpg", "jpeg", "webp", "svg", "wav", "ogg", "mp3"]
    if is_binary:
        return _copy_file_binary(source, destination)
    else:
        return _copy_file_text(source, destination)


func _copy_file_binary(source: String, destination: String) -> bool:
    var src_file := FileAccess.open(source, FileAccess.READ)
    if src_file == null:
        push_error("Failed to open source file (binary): %s" % source)
        return false
    
    var data := src_file.get_buffer(src_file.get_length())
    src_file.close()
    
    var dest_file := FileAccess.open(destination, FileAccess.WRITE)
    if dest_file == null:
        push_error("Failed to open destination file (binary): %s" % destination)
        return false
    
    dest_file.store_buffer(data)
    dest_file.close()
    return true


func _copy_file_text(source: String, destination: String) -> bool:
    var src_file := FileAccess.open(source, FileAccess.READ)
    if src_file == null:
        push_error("Failed to open source file (text): %s" % source)
        return false
    
    var content := src_file.get_as_text()
    src_file.close()
    
    # 剥离嵌入的 UID（避免新法术继承模板的 UID 导致冲突）
    content = _strip_embedded_uid(content)
    
    var dest_file := FileAccess.open(destination, FileAccess.WRITE)
    if dest_file == null:
        push_error("Failed to open destination file (text): %s" % destination)
        return false
    
    dest_file.store_string(content)
    dest_file.close()
    return true


func _strip_embedded_uid(content: String) -> String:
    var regex := RegEx.new()
    regex.compile("(\\[gd_(?:scene|resource)[^\\]]*?)\\s+uid=\"[^\"]+\"")
    return regex.sub(content, "$1", true)


func _rename_files_recursive(directory: String, spell_name: String) -> bool:
    var dir := DirAccess.open(directory)
    if dir == null:
        push_error("Failed to open directory for renaming: %s" % directory)
        return false
    
    dir.list_dir_begin()
    var file_name := dir.get_next()
    var files_to_rename := []
    
    while not file_name.is_empty():
        if file_name != "." and file_name != "..":
            if not dir.current_is_dir() and file_name.find(TOKEN_NAME) != -1:
                var new_name = file_name.replace(TOKEN_NAME, spell_name)
                files_to_rename.append({"old": file_name, "new": new_name})
            elif dir.current_is_dir():
                if not _rename_files_recursive(directory.path_join(file_name), spell_name):
                    return false
        file_name = dir.get_next()
    
    for rename_data in files_to_rename:
        var old_path = directory.path_join(rename_data["old"])
        var new_path = directory.path_join(rename_data["new"])
        if dir.rename(rename_data["old"], rename_data["new"]) != OK:
            push_error("Failed to rename file: %s -> %s" % [old_path, new_path])
            return false
    
    var dir_name := directory.get_file()
    if dir_name.find(TOKEN_NAME) != -1:
        var parent_dir = directory.get_base_dir()
        var new_dir_name = dir_name.replace(TOKEN_NAME, spell_name)
        var parent := DirAccess.open(parent_dir)
        if parent != null:
            if parent.rename(dir_name, new_dir_name) != OK:
                push_error("Failed to rename directory: %s -> %s" % [directory, parent_dir.path_join(new_dir_name)])
                return false
    
    return true


func _replace_placeholders_recursive(
    directory: String,
    spell_name: String,
    pascal_name: String,
    display_name: String
) -> bool:
    var dir := DirAccess.open(directory)
    if dir == null:
        push_error("Failed to open directory for placeholder replacement: %s" % directory)
        return false
    
    dir.list_dir_begin()
    var file_name := dir.get_next()
    
    while not file_name.is_empty():
        if file_name != "." and file_name != "..":
            var file_path = directory.path_join(file_name)
            
            if dir.current_is_dir():
                if not _replace_placeholders_recursive(file_path, spell_name, pascal_name, display_name):
                    return false
            else:
                var ext := file_name.get_extension()
                if ext in ["gd", "tscn", "tres"]:
                    if not _replace_in_file(file_path, spell_name, pascal_name, display_name):
                        return false
        
        file_name = dir.get_next()
    
    return true


func _replace_in_file(file_path: String, spell_name: String, pascal_name: String, display_name: String) -> bool:
    var file := FileAccess.open(file_path, FileAccess.READ)
    if file == null:
        push_error("Failed to open file for placeholder replacement: %s" % file_path)
        return false
    var content := file.get_as_text()
    file.close()
    
    content = content.replace(TOKEN_NAME, spell_name)
    content = content.replace(TOKEN_CLASS, pascal_name)
    content = content.replace(TOKEN_DISPLAY, display_name)
    
    file = FileAccess.open(file_path, FileAccess.WRITE)
    if file == null:
        push_error("Failed to write back file after placeholder replacement: %s" % file_path)
        return false
    file.store_string(content)
    file.close()
    return true


func _generate_animation_files(target_dir: String, spell_name: String, pascal_name: String) -> bool:
    var anim_dir = target_dir.path_join("resources/animations")
    
    # Generate animation_tree_root.tres
    if not _generate_animation_tree(anim_dir, spell_name, pascal_name):
        return false
    
    # Generate RESET.tres
    if not _generate_reset_animation(anim_dir):
        return false
    
    # Generate active_right.tres
    if not _generate_active_animation(anim_dir, "right", false):
        return false
    
    # Generate active_left.tres
    if not _generate_active_animation(anim_dir, "left", true):
        return false
    
    # Generate anim_library
    if not _generate_animation_library(target_dir, spell_name):
        return false
    
    return true


func _generate_animation_tree(anim_dir: String, spell_name: String, pascal_name: String) -> bool:
    var lib_prefix = pascal_name
    var content = """[gd_resource type="AnimationNodeBlendTree" format=3]

[sub_resource type="AnimationNodeAnimation" id="AnimNode_active_right"]
animation = &"{lib}/active_right"

[sub_resource type="AnimationNodeAnimation" id="AnimNode_active_left"]
animation = &"{lib}/active_left"

[sub_resource type="AnimationNodeBlendSpace1D" id="BlendSpace_active"]
blend_point_0/node = SubResource("AnimNode_active_right")
blend_point_0/pos = 0.1
blend_point_0/name = &"0"
blend_point_1/node = SubResource("AnimNode_active_left")
blend_point_1/pos = -0.1
blend_point_1/name = &"1"

[sub_resource type="AnimationNodeStateMachineTransition" id="Transition_start_active"]
advance_mode = 1

[sub_resource type="AnimationNodeStateMachine" id="StateMachine"]
states/Start/position = Vector2(100, 100)
states/active/node = SubResource("BlendSpace_active")
states/active/position = Vector2(300, 100)
transitions = ["Start", "active", SubResource("Transition_start_active")]

[sub_resource type="AnimationNodeTimeScale" id="TimeScale"]

[resource]
graph_offset = Vector2(-200, -50)
nodes/output/position = Vector2(500, 100)
nodes/state_machine/node = SubResource("StateMachine")
nodes/state_machine/position = Vector2(0, 100)
nodes/time_scale/node = SubResource("TimeScale")
nodes/time_scale/position = Vector2(250, 100)
node_connections = [&"output", 0, &"time_scale", &"time_scale", 0, &"state_machine"]
""".replace("{lib}", lib_prefix)
    
    var file_path = anim_dir.path_join("animation_tree_root.tres")
    var file := FileAccess.open(file_path, FileAccess.WRITE)
    if file == null:
        push_error("Failed to create animation_tree_root.tres")
        return false
    file.store_string(content)
    file.close()
    return true


func _generate_reset_animation(anim_dir: String) -> bool:
    var content = """[gd_resource type="Animation" format=3]

[resource]
resource_name = "RESET"
length = 0.001
tracks/0/type = "value"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath("AnimatedSprite2D:frame")
tracks/0/interp = 1
tracks/0/loop_wrap = true
tracks/0/keys = {
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"update": 0,
"values": [0]
}
tracks/1/type = "value"
tracks/1/imported = false
tracks/1/enabled = true
tracks/1/path = NodePath("AnimatedSprite2D:animation")
tracks/1/interp = 1
tracks/1/loop_wrap = true
tracks/1/keys = {
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"update": 1,
"values": [&"active"]
}
tracks/2/type = "value"
tracks/2/imported = false
tracks/2/enabled = true
tracks/2/path = NodePath("AnimatedSprite2D:flip_h")
tracks/2/interp = 1
tracks/2/loop_wrap = true
tracks/2/keys = {
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"update": 0,
"values": [false]
}
tracks/3/type = "value"
tracks/3/imported = false
tracks/3/enabled = true
tracks/3/path = NodePath("AnimatedSprite2D:modulate")
tracks/3/interp = 1
tracks/3/loop_wrap = true
tracks/3/keys = {
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"update": 0,
"values": [Color(1, 1, 1, 1)]
}
tracks/4/type = "value"
tracks/4/imported = false
tracks/4/enabled = true
tracks/4/path = NodePath("Attacks/Attack1:visible")
tracks/4/interp = 1
tracks/4/loop_wrap = true
tracks/4/keys = {
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"update": 1,
"values": [false]
}
tracks/5/type = "value"
tracks/5/imported = false
tracks/5/enabled = true
tracks/5/path = NodePath("Attacks/Attack1/Attack1Shape:disabled")
tracks/5/interp = 1
tracks/5/loop_wrap = true
tracks/5/keys = {
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"update": 1,
"values": [true]
}
"""
    var file_path = anim_dir.path_join("RESET.tres")
    var file := FileAccess.open(file_path, FileAccess.WRITE)
    if file == null:
        push_error("Failed to create RESET.tres")
        return false
    file.store_string(content)
    file.close()
    return true


func _generate_active_animation(anim_dir: String, side: String, is_left: bool) -> bool:
    var flip_h = "true" if is_left else "false"
    var mirror_name = "active_left.tres" if not is_left else "active_right.tres"
    
    var content = """[gd_resource type="Animation" format=3]

[resource]
resource_name = "active"
length = 0.0833334
step = 0.0416667
tracks/0/type = "value"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath("AnimatedSprite2D:position")
tracks/0/interp = 1
tracks/0/loop_wrap = true
tracks/0/keys = {
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"update": 1,
"values": [Vector2(0, -80)]
}
tracks/1/type = "value"
tracks/1/imported = false
tracks/1/enabled = true
tracks/1/path = NodePath("AnimatedSprite2D:frame")
tracks/1/interp = 1
tracks/1/loop_wrap = true
tracks/1/keys = {
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"update": 0,
"values": [0]
}
tracks/2/type = "value"
tracks/2/imported = false
tracks/2/enabled = true
tracks/2/path = NodePath("AnimatedSprite2D:animation")
tracks/2/interp = 1
tracks/2/loop_wrap = true
tracks/2/keys = {
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"update": 1,
"values": [&"active"]
}
tracks/3/type = "value"
tracks/3/imported = false
tracks/3/enabled = true
tracks/3/path = NodePath("AnimatedSprite2D:flip_h")
tracks/3/interp = 1
tracks/3/loop_wrap = true
tracks/3/keys = {
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"update": 0,
"values": [{flip}]
}
tracks/4/type = "method"
tracks/4/imported = false
tracks/4/enabled = true
tracks/4/path = NodePath(".")
tracks/4/interp = 1
tracks/4/loop_wrap = true
tracks/4/keys = {
"times": PackedFloat32Array(0.0833334),
"transitions": PackedFloat32Array(1),
"values": [{
"args": [],
"method": &"end_of_spell_animation"
}]
}
tracks/5/type = "value"
tracks/5/imported = false
tracks/5/enabled = true
tracks/5/path = NodePath("Attacks/Attack1/Attack1Shape:disabled")
tracks/5/interp = 1
tracks/5/loop_wrap = true
tracks/5/keys = {
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"update": 1,
"values": [false]
}
tracks/6/type = "value"
tracks/6/imported = false
tracks/6/enabled = true
tracks/6/path = NodePath("Attacks/Attack1:visible")
tracks/6/interp = 1
tracks/6/loop_wrap = true
tracks/6/keys = {
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"update": 1,
"values": [true]
}
metadata/mirrored_name = "{mirror}"
metadata/should_overwrite = true
""".replace("{flip}", flip_h).replace("{mirror}", mirror_name)
    
    var file_name = "active_%s.tres" % side
    var file_path = anim_dir.path_join(file_name)
    var file := FileAccess.open(file_path, FileAccess.WRITE)
    if file == null:
        push_error("Failed to create %s" % file_name)
        return false
    file.store_string(content)
    file.close()
    return true


func _generate_animation_library(target_dir: String, spell_name: String) -> bool:
    var anim_dir_rel = "resources/animations"
    var content = """[gd_resource type="AnimationLibrary" load_steps=3 format=3]

[ext_resource type="Animation" path="res://spells/{name}/{anim_dir}/active_right.tres" id="1_right"]
[ext_resource type="Animation" path="res://spells/{name}/{anim_dir}/active_left.tres" id="2_left"]

[resource]
_data = {
"active_left": ExtResource("2_left"),
"active_right": ExtResource("1_right")
}
""".replace("{name}", spell_name).replace("{anim_dir}", anim_dir_rel)
    
    var file_path = target_dir.path_join("resources/anim_library_%s.tres" % spell_name)
    var file := FileAccess.open(file_path, FileAccess.WRITE)
    if file == null:
        push_error("Failed to create anim_library_%s.tres" % spell_name)
        return false
    file.store_string(content)
    file.close()
    return true


## Recursively delete all .import files in a directory.
## Godot will regenerate them with new unique UIDs on next filesystem scan.
## This prevents UID duplication between the new spell and the template.
func _delete_import_files_recursive(directory: String) -> bool:
    var dir := DirAccess.open(directory)
    if dir == null:
        push_error("Failed to open directory for .import cleanup: %s" % directory)
        return false
    
    dir.list_dir_begin()
    var file_name := dir.get_next()
    
    while not file_name.is_empty():
        if file_name != "." and file_name != "..":
            var file_path = directory.path_join(file_name)
            
            if dir.current_is_dir():
                # Recursively clean subdirectory
                _delete_import_files_recursive(file_path)
            elif file_name.ends_with(".import"):
                # Delete .import file
                var err := dir.remove(file_name)
                if err != OK:
                    push_warning("Failed to delete .import file: %s" % file_path)
        
        file_name = dir.get_next()
    
    return true

