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
                if file_name not in EXCLUDED_FILES:
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
    
    var dest_file := FileAccess.open(destination, FileAccess.WRITE)
    if dest_file == null:
        push_error("Failed to open destination file (text): %s" % destination)
        return false
    
    dest_file.store_string(content)
    dest_file.close()
    return true


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
