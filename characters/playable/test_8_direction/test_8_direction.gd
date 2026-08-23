@tool
extends QuiverCharacter

## Write your doc string for this file here

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

var _spell_manager: SpellManager

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		QuiverEditorHelper.disable_all_processing(self)
		return
	
	if attributes != null:
		attributes.reset()
	
	_spell_manager = SpellManager.new(self)
	Events.player_died.connect(_on_player_died)
	
	if QuiverEditorHelper.is_standalone_run(self):
		QuiverEditorHelper.add_debug_camera2D_to(self, Vector2(0,-0.8))

func _physics_process(delta: float) -> void:
	super(delta)
	if Engine.is_editor_hint():
		return
	_spell_manager.tick(delta)

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event.is_action_pressed("spell_1"):
		_spell_manager.cast_spell_by_index(0)
	elif event.is_action_pressed("spell_2"):
		_spell_manager.cast_spell_by_index(1)
	elif event.is_action_pressed("spell_3"):
		_spell_manager.cast_spell_by_index(2)
	elif event.is_action_pressed("spell_4"):
		_spell_manager.cast_spell_by_index(3)

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func learn_spell(spell_def: SpellDefinition) -> bool:
	return _spell_manager.learn_spell(spell_def)

func forget_spell(index: int) -> void:
	_spell_manager.forget_spell(index)

func get_spell_manager() -> SpellManager:
	return _spell_manager

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _on_player_died() -> void:
	if _state_machine and _state_machine.state_name == ^"Die":
		_spell_manager.dismiss_all_summons()

### -----------------------------------------------------------------------------------------------
