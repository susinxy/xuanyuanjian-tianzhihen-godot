@tool
extends EditorInspectorPlugin
## Inspector plugin for spell management (create and delete spells)
## 
## This plugin activates when the user selects a SpellTemplate node,
## which is located at templates/spell/spell_template.tscn
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
	var test_scene_path = "res://test_scenes/_test_spell_" + spell_name + ".tscn"
	var character_scene_path = "res://characters/playable/" + char_name + "/" + char_name + ".tscn"
	var spell_definition_path = "res://spells/" + spell_name + "/resources/" + spell_name + "_definition.tres"
	var spell_scene_path = "res://spells/" + spell_name + "/" + spell_name + ".tscn"
	
	if not FileAccess.file_exists(character_scene_path):
		push_error("[SpellTest] Character scene not found: %s" % character_scene_path)
		return
	
	if not FileAccess.file_exists(spell_definition_path):
		push_error("[SpellTest] Spell definition not found: %s" % spell_definition_path)
		return
	
	# 测试场景 = 角色底版 + 法术套件（单一底版，见 QuiverRunTestSceneBuilder）
	# 2026-09-17 自愈改造：装配逻辑整体迁入 ensure_spell_run_test 静态入口，
	# 与 headless 测试共用同一生成路径，杜绝双份模板漂移。
	var result := QuiverRunTestSceneBuilder.ensure_spell_run_test(spell_name, char_name)
	if not result.changed:
		EditorInterface.play_custom_scene(test_scene_path)
		print("[SpellTest] Testing spell '%s' with character '%s' - test scene unchanged, launched directly." % [spell_name, char_name])
		return
	
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
