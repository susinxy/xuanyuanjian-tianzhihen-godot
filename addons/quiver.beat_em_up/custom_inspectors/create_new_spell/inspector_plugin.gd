@tool
extends EditorInspectorPlugin
## Inspector plugin for spell management (create and delete spells)
## 
## This plugin activates when the user selects a SpellTemplate node,
## which is located at spells/_template/spell_template.tscn
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
	add_custom_control(widget)


func _on_spell_created(spell_name: String) -> void:
	EditorInterface.get_resource_filesystem().scan()
	print("[SpellCreator] Spell '%s' created successfully!" % spell_name)


func _on_spell_deleted(spell_name: String) -> void:
	EditorInterface.get_resource_filesystem().scan()
	print("[SpellCreator] Spell '%s' deleted successfully!" % spell_name)

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
