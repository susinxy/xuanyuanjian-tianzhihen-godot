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
	# 法术出生补学（S2-B4 spec §4：节点会重建——换章/回跳/测试接缝/读档，
	# 账不重建——《秘籍》增量记在 GameSave.spells_known，新实例在此查账回填）。
	# get_node_or_null 守卫：-s 无 autoload 环境静默跳过（判例全套同款）
	var ledger := get_node_or_null(^"/root/GameSave")
	if ledger != null:
		for sid in ledger.ids(ledger.NS_SPELLS):
			var def := SpellRegistry.definition_for(sid)
			if def != null:
				_spell_manager.learn_spell(def)
	Events.player_died.connect(_on_player_died)
	
	if QuiverEditorHelper.is_standalone_run(self):
		QuiverEditorHelper.add_debug_camera2D_to(self, Vector2(0,-0.8))

func _physics_process(delta: float) -> void:
	super(delta)
	if Engine.is_editor_hint():
		return
	_spell_manager.tick(delta)
	# 法术键改读私有输入通道（帧戳边沿，读一次即消费）：
	# 根脚本不再监听物理键盘，非玩家角色由模板出生即无按键劫持
	if channel.just_pressed("spell_1"):
		_spell_manager.cast_spell_by_index(0)
	elif channel.just_pressed("spell_2"):
		_spell_manager.cast_spell_by_index(1)
	elif channel.just_pressed("spell_3"):
		_spell_manager.cast_spell_by_index(2)
	elif channel.just_pressed("spell_4"):
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
