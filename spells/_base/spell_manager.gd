class_name SpellManager
extends RefCounted

const MAX_SLOTS := 4

var _slots: Array[SpellSlot]
var _character: QuiverCharacter
var _active_summons: Dictionary = {}

func _init(character: QuiverCharacter) -> void:
    _character = character
    for i in MAX_SLOTS:
        _slots.append(SpellSlot.new())

func tick(delta: float) -> void:
    for slot in _slots:
        if not slot.is_empty():
            slot.tick(delta)

func learn_spell(spell_def: SpellDefinition) -> bool:
    for i in _slots.size():
        if _slots[i].is_empty():
            _slots[i].definition = spell_def
            return true
    return false

func forget_spell(index: int) -> void:
    if index >= 0 and index < _slots.size():
        _slots[index].definition = null
        _slots[index].cooldown_remaining = 0.0

func get_spell_slot(index: int) -> SpellSlot:
    if index >= 0 and index < _slots.size():
        return _slots[index]
    return null

func cast_spell_by_index(index: int) -> void:
    if index < 0 or index >= _slots.size():
        return
    cast_spell(_slots[index])

func cast_spell(slot: SpellSlot) -> void:
    if slot.is_empty():
        return
    if not slot.is_ready():
        return
    if _character.attributes.mana_current < slot.definition.mana_cost:
        return
    if not _is_state_allowed(slot.definition):
        return
    
    _character.attributes.mana_current -= slot.definition.mana_cost
    slot.start_cooldown()
    
    var spell := slot.definition.spell_scene.instantiate() as SpellBase
    var dir := Vector2.RIGHT
    if _character.get_node_or_null("Skin"):
        var skin = _character.get_node("Skin")
        dir = Vector2.LEFT if skin.skin_direction.x < 0 else Vector2.RIGHT
    
    var spawn_parent := _character.get_parent()
    spawn_parent.add_child(spell)
    spell.global_position = _character.global_position + spell.get_spawn_offset(dir)
    spell.cast(_character, slot.definition, dir)

func _is_state_allowed(spell_def: SpellDefinition) -> bool:
    var state_machine := _character.get_node_or_null("StateMachine") as QuiverStateMachine
    if state_machine == null:
        return true
    var current_state_name := str(state_machine.state_name)
    
    if not spell_def.disallowed_states.is_empty():
        if current_state_name in spell_def.disallowed_states:
            return false
    
    if not spell_def.allowed_states.is_empty():
        return current_state_name in spell_def.allowed_states
    
    return true

func dismiss_all_summons() -> void:
    for creature in _active_summons.keys():
        if is_instance_valid(creature):
            creature.queue_free()
    _active_summons.clear()

func register_summon(creature: Node) -> void:
    _active_summons[creature] = true
    creature.tree_exiting.connect(_on_summon_exiting.bind(creature))

func _on_summon_exiting(creature: Node) -> void:
    _active_summons.erase(creature)
