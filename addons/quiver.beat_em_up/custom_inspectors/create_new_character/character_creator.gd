@tool
extends RefCounted
class_name CharacterCreator
## Handles character creation from template.
## Copies template directory, renames files, and replaces placeholders.

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const TEMPLATE_DIR = "res://characters/playable/_template/"
const CHARACTERS_ROOT = "res://characters/"
const BODY_GROUP_PLAYERS = "players"

# 控制方式（与 QuiverCharacter.BehaviorMode 数值一致）
enum ControlMode { PLAYER_INPUT = 0, AI_POLICY = 1, PASSIVE = 2 }

# Placeholder tokens in template files
const TOKEN_NAME = "__NAME__"
const TOKEN_CLASS = "__CLASS__"
const TOKEN_DISPLAY = "__DISPLAY_NAME__"
const TOKEN_FACTION = "__FACTION__"
const TOKEN_PKG = "__PKG__"                    # 阵营包目录（playable/enemies/allies/neutrals）
const TOKEN_BODY_GROUP = "__BODY_GROUP__"      # 根节点 body group（players/enemies/...）
const TOKEN_BEHAVIOR_MODE = "__BEHAVIOR_MODE__"  # 行为档 0/1/2
const TOKEN_MOVE_SPEED = "__MOVE_SPEED__"
const TOKEN_WALK_SPEED = "__WALK_SPEED__"
const TOKEN_HEALTH_MAX = "__HEALTH_MAX__"
const TOKEN_AIR_CONTROL = "__AIR_CONTROL__"
const TOKEN_HIT_LANE_OFFSET = "__HIT_LANE_OFFSET__"

# Template files that should NOT be copied
const EXCLUDED_FILES = [
	"character_template.tscn",
	"character_template.gd",
	"create_character.sh",
	"README.md",
]

#--- public variables - order: export > normal var & onready --------------------------------------

#--- private variables - order: export > normal var & onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## Creates a new character from template.
## Returns true on success, false on failure.
##
## 单壳架构（见 docs/PLUGIN_ARCHITECTURE.md 5.0）：控制方式决定行为档与输出目录，
## 阵营决定 body group 与阵营包目录。AI 档 v1 仅开放敌人阵营。
func create_character(
	char_name: String,
	pascal_name: String,
	display_name: String,
	faction: String = "players",
	move_speed: float = 600.0,
	walk_speed: float = 300.0,
	health_max: int = 100,
	air_control: float = 0.6,
	hit_lane_offset: int = 0,
	control_mode: int = ControlMode.PLAYER_INPUT
) -> bool:
	var layout := resolve_layout(control_mode, faction)
	if layout.is_empty():
		push_error("Invalid control_mode/faction combination: mode=%d faction=%s" % [
			control_mode, faction])
		return false
	
	var target_dir = CHARACTERS_ROOT.path_join(layout.pkg).path_join(char_name)
	
	# Check if target already exists
	if DirAccess.dir_exists_absolute(target_dir):
		push_error("Character directory already exists: %s" % target_dir)
		return false
	
	# Step 1: Create target directory
	if DirAccess.make_dir_recursive_absolute(target_dir) != OK:
		push_error("Failed to create directory: %s" % target_dir)
		return false
	
	# Step 2: Copy template directory structure (preserving __NAME__ in filenames)
	if not _copy_directory_recursive(TEMPLATE_DIR, target_dir):
		push_error("Failed to copy template files")
		return false
	
	# Step 3: Rename files containing __NAME__
	if not _rename_files_recursive(target_dir, char_name):
		push_error("Failed to rename template files")
		return false
	
	# Step 4: Replace placeholders in all files
	var tokens := {
		TOKEN_NAME: char_name,
		TOKEN_CLASS: pascal_name,
		TOKEN_DISPLAY: display_name,
		TOKEN_FACTION: faction,
		TOKEN_PKG: layout.pkg,
		TOKEN_BODY_GROUP: layout.body_group,
		TOKEN_BEHAVIOR_MODE: str(layout.behavior_mode),
		TOKEN_MOVE_SPEED: str(move_speed),
		TOKEN_WALK_SPEED: str(walk_speed),
		TOKEN_HEALTH_MAX: str(health_max),
		TOKEN_AIR_CONTROL: str(air_control),
		TOKEN_HIT_LANE_OFFSET: str(hit_lane_offset),
	}
	if not _replace_placeholders_recursive(target_dir, tokens):
		push_error("Failed to replace placeholders")
		return false
	
	# Step 5: Delete .import files to avoid UID duplication
	# Godot will regenerate them with unique UIDs on next filesystem scan
	if not _delete_import_files_recursive(target_dir):
		push_warning("Failed to delete some .import files (non-critical)")
	
	print_rich("[color=green]✓ Character created: %s (%s) at %s[/color]" % [display_name, char_name, target_dir])
	return true


## 控制方式×阵营 → 输出布局（阵营包目录 / body group / 行为档）。
## 非法组合返回空字典。玩家操控强制 players；AI 档 v1 仅敌人阵营
## （插件 AI 状态虽已退役，但策略小抄的追击目标写死"最近的玩家"，
## 友方 AI 的索敌参数化留待切片设计会立项）。
static func resolve_layout(control_mode: int, faction: String) -> Dictionary:
	var pkg := ""
	var body_group := ""
	var behavior_mode := 0
	match control_mode:
		ControlMode.PLAYER_INPUT:
			pkg = "playable"
			body_group = "players"
			behavior_mode = 0
		ControlMode.AI_POLICY:
			if faction != "enemies":
				return {}
			pkg = "enemies"
			body_group = "enemies"
			behavior_mode = 1
		ControlMode.PASSIVE:
			behavior_mode = 2
			match faction:
				"players":
					pkg = "playable"
					body_group = "players"
				"enemies", "allies", "neutrals":
					pkg = faction
					body_group = faction
				_:
					return {}
		_:
			return {}
	return {"pkg": pkg, "body_group": body_group, "behavior_mode": behavior_mode}


### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _copy_directory_recursive(source: String, destination: String) -> bool:
	var dir := DirAccess.open(source)
	if dir == null:
		push_error("Failed to open source directory: %s (error code: %d)" % [source, DirAccess.get_open_error()])
		return false
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while not file_name.is_empty():
		# Skip . and ..
		if file_name != "." and file_name != "..":
			var source_path = source.path_join(file_name)
			var dest_path = destination.path_join(file_name)
			
			if dir.current_is_dir():
				# Recursively copy subdirectory
				if DirAccess.make_dir_recursive_absolute(dest_path) != OK:
					push_error("Failed to create subdirectory: %s" % dest_path)
					return false
				if not _copy_directory_recursive(source_path, dest_path):
					return false
			else:
				# Skip excluded files and .uid sidecar files (Godot will regenerate UIDs)
				if file_name not in EXCLUDED_FILES and not file_name.ends_with(".uid"):
					# Copy file (preserve __NAME__ in filename)
					if not _copy_file(source_path, dest_path):
						return false
		
		file_name = dir.get_next()
	
	return true


func _rename_files_recursive(directory: String, char_name: String) -> bool:
	var dir := DirAccess.open(directory)
	if dir == null:
		push_error("Failed to open directory for renaming: %s" % directory)
		return false
	
	# First, rename files in this directory
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var files_to_rename := []
	
	while not file_name.is_empty():
		if file_name != "." and file_name != "..":
			if not dir.current_is_dir() and file_name.find(TOKEN_NAME) != -1:
				var new_name = file_name.replace(TOKEN_NAME, char_name)
				files_to_rename.append({"old": file_name, "new": new_name})
			elif dir.current_is_dir():
				# Recursively rename in subdirectories first
				if not _rename_files_recursive(directory.path_join(file_name), char_name):
					return false
		
		file_name = dir.get_next()
	
	# Now rename files in this directory
	for rename_data in files_to_rename:
		var old_path = directory.path_join(rename_data["old"])
		var new_path = directory.path_join(rename_data["new"])
		if dir.rename(rename_data["old"], rename_data["new"]) != OK:
			push_error("Failed to rename file: %s -> %s" % [old_path, new_path])
			return false
	
	# Rename the directory itself if it contains __NAME__
	var dir_name := directory.get_file()
	if dir_name.find(TOKEN_NAME) != -1:
		var parent_dir = directory.get_base_dir()
		var new_dir_name = dir_name.replace(TOKEN_NAME, char_name)
		var parent := DirAccess.open(parent_dir)
		if parent != null:
			if parent.rename(dir_name, new_dir_name) != OK:
				push_error("Failed to rename directory: %s -> %s" % [directory, parent_dir.path_join(new_dir_name)])
				return false
	
	return true


func _copy_file(source: String, destination: String) -> bool:
	# Check if file extension is binary (skip text processing for these)
	var ext := source.get_extension()
	var is_binary := ext in ["png", "jpg", "jpeg", "webp", "svg", "wav", "ogg", "mp3"]
	
	if is_binary:
		# Binary copy
		return _copy_file_binary(source, destination)
	else:
		# Text copy (will replace placeholders in next step)
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
	
	# Strip embedded UIDs to prevent UID duplication
	# This handles both [gd_scene/gd_resource] headers and [ext_resource] lines
	content = _strip_embedded_uid(content)
	
	var dest_file := FileAccess.open(destination, FileAccess.WRITE)
	if dest_file == null:
		push_error("Failed to open destination file (text): %s" % destination)
		return false
	
	dest_file.store_string(content)
	dest_file.close()
	return true


## Strip embedded uid="..." attributes from .tscn/.tres files.
## This prevents UID duplication when copying template files to new characters.
## Handles both [gd_scene/gd_resource] headers and [ext_resource] lines.
func _strip_embedded_uid(content: String) -> String:
	var regex := RegEx.new()
	# Match uid="..." in [gd_scene ...], [gd_resource ...], and [ext_resource ...] lines
	regex.compile("(\\[(?:gd_(?:scene|resource)|ext_resource)[^\\]]*?)\\s+uid=\"[^\"]+\"")
	return regex.sub(content, "$1", true)


func _replace_placeholders_recursive(directory: String, tokens: Dictionary) -> bool:
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
				# Recursively process subdirectory
				if not _replace_placeholders_recursive(file_path, tokens):
					return false
			else:
				# Process text files
				var ext := file_path.get_extension()
				if ext in ["gd", "tscn", "tres"]:
					if not _replace_placeholders_in_file(file_path, tokens):
						return false
		
		file_name = dir.get_next()
	
	return true


func _replace_placeholders_in_file(file_path: String, tokens: Dictionary) -> bool:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open file for placeholder replacement: %s" % file_path)
		return false
	
	var content := file.get_as_text()
	file.close()
	
	# Replace placeholders（__NAME__ 等互不为子串，插入序遍历即可）
	for token in tokens:
		content = content.replace(token, tokens[token])
	
	# Write back
	file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write back file after placeholder replacement: %s" % file_path)
		return false
	
	file.store_string(content)
	file.close()
	
	return true


## Recursively delete all .import files in a directory.
## Godot will regenerate them with new unique UIDs on next filesystem scan.
## This prevents UID duplication between the new character and the template.
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


### -----------------------------------------------------------------------------------------------
