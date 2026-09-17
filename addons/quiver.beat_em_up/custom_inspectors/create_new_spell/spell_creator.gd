@tool
extends RefCounted
class_name SpellCreator

const TEMPLATE_DIR = "res://templates/spell/"
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

## 法术创建器：纯"模板复制+改名+token 替换"（2026-09-15 单权威化改造）。
## 动画树/动画文件/动画库与角色产线同构——真相全部物化在 templates/spell/，
## 不再有代码内嵌字符串（历史上双作者已漂移：模板停在双向、内嵌串升级了四向）。
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
    
    # Step 5: Delete .import files to avoid UID duplication
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
    # 必须同时覆盖 ext_resource 行的 uid（对齐角色侧）：否则一旦有人在 Godot 编辑器
    # 里保存过法术模板 .tscn（编辑器会给 ext_resource 自动补 uid），复制出的新法术
    # 就原样继承模板 UID → 与模板 UID 撞车（2026-09-15 审计 L5）
    regex.compile("(\\[(?:gd_(?:scene|resource)|ext_resource)[^\\]]*?)\\s+uid=\"[^\"]+\"")
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

