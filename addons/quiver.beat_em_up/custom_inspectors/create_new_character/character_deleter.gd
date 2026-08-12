@tool
extends RefCounted
class_name CharacterDeleter
## Handles character deletion.
## Recursively deletes a character directory and all its contents.

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const CHARACTER_DIR = "res://characters/playable/"

#--- public variables - order: export > normal var & onready --------------------------------------

#--- private variables - order: export > normal var & onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## Deletes a character directory and all its contents.
## Returns true on success, false on failure.
func delete_character(char_name: String) -> bool:
	var target_dir = CHARACTER_DIR.path_join(char_name)
	
	# Check if directory exists
	if not DirAccess.dir_exists_absolute(target_dir):
		push_error("Character directory does not exist: %s" % target_dir)
		return false
	
	# Prevent deleting special directories
	if char_name in ["_template", ".", ".."]:
		push_error("Cannot delete special directory: %s" % char_name)
		return false
	
	# Recursively delete directory
	if not _delete_directory_recursive(target_dir):
		push_error("Failed to delete character directory: %s" % target_dir)
		return false
	
	# Remove the now-empty directory
	if DirAccess.remove_absolute(target_dir) != OK:
		push_error("Failed to remove directory after deleting contents: %s" % target_dir)
		return false
	
	print_rich("[color=green]✓ Character deleted: %s[/color]" % char_name)
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
				# Recursively delete subdirectory
				if not _delete_directory_recursive(file_path):
					return false
				# Remove the now-empty subdirectory
				if dir.remove(file_name) != OK:
					push_error("Failed to remove subdirectory: %s" % file_path)
					return false
			else:
				# Delete file
				if dir.remove(file_name) != OK:
					push_error("Failed to delete file: %s" % file_path)
					return false
		
		file_name = dir.get_next()
	
	return true

### -----------------------------------------------------------------------------------------------
