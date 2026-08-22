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
