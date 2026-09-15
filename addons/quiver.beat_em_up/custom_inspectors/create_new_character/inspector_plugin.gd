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
	# 刷新文件系统，让新角色在编辑器中可见
	# 注：用户已在 widget 中看到 1-2 秒的创建过程和成功反馈
	EditorInterface.get_resource_filesystem().scan()
	print("[CharacterCreator] Character '%s' created successfully!" % char_name)


func _on_character_deleted(char_name: String) -> void:
	# 刷新文件系统，移除已删除的角色
	# 注：用户已在 widget 中看到删除过程和成功反馈
	EditorInterface.get_resource_filesystem().scan()
	print("[CharacterCreator] Character '%s' deleted successfully!" % char_name)


func _on_character_test_requested(char_name: String, pkg: String = "playable") -> void:
	var test_scene_path = "res://test_scenes/_test_" + char_name + ".tscn"
	var character_scene_path = "res://characters/%s/%s/%s.tscn" % [pkg, char_name, char_name]
	
	# Check if character scene exists
	if not FileAccess.file_exists(character_scene_path):
		push_error("[CharacterCreator] Character scene not found: %s" % character_scene_path)
		return
	
	# Build test scene content using {{TOKEN}} replace pattern
	# (avoids GDScript `%` operator issues with multiline strings written to .tscn files)
	# 
	# 场景底版模板与布局约束见 QuiverRunTestSceneBuilder.base_scene_text()（2026-09-15 产线统一）
	
	# 被测角色是玩家档（behavior_mode=0）时：它是主角，敌人位保留旧 enemy 占位
	# （旧敌人退役时另行处理）；非玩家档时：主角固定 chen，被测角色作为对手
	# 加入（AI 档会自动追打 chen，被动档站桩挨打），并移除旧 enemy 块。
	# 纯逻辑在 QuiverRunTestSceneBuilder（headless 可测）。
	var subject_mode := QuiverRunTestSceneBuilder.scene_behavior_mode(character_scene_path)
	var hero_path: String = QuiverRunTestSceneBuilder.hero_path_for(
			character_scene_path, subject_mode)
	var test_scene_content := QuiverRunTestSceneBuilder.base_scene_text().replace("{{CHAR_NAME}}", char_name)
	test_scene_content = test_scene_content.replace("{{CHAR_PATH}}", hero_path)
	test_scene_content = QuiverRunTestSceneBuilder.compose(
			test_scene_content, character_scene_path, subject_mode)
	
	# Ensure test_scenes directory exists
	if not DirAccess.dir_exists_absolute("res://test_scenes"):
		DirAccess.make_dir_recursive_absolute("res://test_scenes")
	
	# Write test scene（幂等：内容未变则完全不写盘/不扫描/不等待——
	# 避免编辑器对打开中的场景弹"硬盘变动请重载"；且 scan 无事发生时
	# filesystem_changed 可能永不触发，await 会卡死）
	var existing := ""
	if FileAccess.file_exists(test_scene_path):
		existing = FileAccess.get_file_as_string(test_scene_path)
	if existing == test_scene_content:
		EditorInterface.play_custom_scene(test_scene_path)
		print("[CharacterCreator] Testing character '%s' - test scene unchanged, launched directly." % char_name)
		return
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
