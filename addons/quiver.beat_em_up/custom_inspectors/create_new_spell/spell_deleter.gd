@tool
extends RefCounted
class_name SpellDeleter
## Handles spell deletion.
## Recursively deletes a spell directory and all its contents.

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const SPELL_DIR = "res://spells/"

#--- public variables - order: export > normal var & onready --------------------------------------

#--- private variables - order: export > normal var & onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## Deletes a spell directory and all its contents.
## Returns true on success, false on failure.
func delete_spell(spell_name: String) -> bool:
    var target_dir = SPELL_DIR.path_join(spell_name)
    
    if not DirAccess.dir_exists_absolute(target_dir):
        push_error("Spell directory does not exist: %s" % target_dir)
        return false
    
    if spell_name in ["_template", "_base", ".", ".."]:
        push_error("Cannot delete special directory: %s" % spell_name)
        return false
    
    if not _delete_directory_recursive(target_dir):
        push_error("Failed to delete spell directory: %s" % target_dir)
        return false
    
    if DirAccess.remove_absolute(target_dir) != OK:
        push_error("Failed to remove directory after deleting contents: %s" % target_dir)
        return false
    
    print_rich("[color=green]✓ Spell deleted: %s[/color]" % spell_name)
    return true


### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _delete_directory_recursive(directory: String) -> bool:
    var dir := DirAccess.open(directory)
    if dir == null:
        push_error("Failed to open directory for deletion: %s (error code: %d)" % [directory, DirAccess.get_open_error()])
        return false
    
    dir.list_dir_begin()
    var file_name := dir.get_next()
    
    while not file_name.is_empty():
        if file_name != "." and file_name != "..":
            var file_path = directory.path_join(file_name)
            
            if dir.current_is_dir():
                if not _delete_directory_recursive(file_path):
                    return false
                if dir.remove(file_name) != OK:
                    push_error("Failed to remove subdirectory: %s" % file_path)
                    return false
            else:
                if dir.remove(file_name) != OK:
                    push_error("Failed to delete file: %s" % file_path)
                    return false
        
        file_name = dir.get_next()
    
    return true

### -----------------------------------------------------------------------------------------------
