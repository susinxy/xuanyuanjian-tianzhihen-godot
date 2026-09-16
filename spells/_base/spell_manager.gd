class_name SpellManager
extends RefCounted

const MAX_SLOTS := 4
## 施法状态路径（角色场景 Ground 下挂载，见 _beat_em_up/action_states/quiver_action_cast.gd）
const CAST_STATE_PATH := "Ground/Cast"

var _slots: Array[SpellSlot]
var _character: QuiverCharacter
var _active_summons: Dictionary = {}
static var _warned_no_cast_state: Dictionary = {}

## 把八向倾向归一化为四正方向（上/下/左/右），与攻击/施法状态同款语义。
## 施法者与法术体共用此唯一实现，防止两处口径漂移。
static func snap_to_four_direction(direction: Vector2) -> Vector2:
    if direction == Vector2.ZERO:
        return Vector2.RIGHT
    if abs(direction.x) >= abs(direction.y):
        return Vector2(signf(direction.x), 0.0)
    return Vector2(0.0, signf(direction.y))

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
    if _is_casting():
        return
    if _is_in_air():
        return

    # 承诺制：法力与冷却在起手瞬间扣掉；此后被打断不退还
    _character.attributes.mana_current -= slot.definition.mana_cost
    slot.start_cooldown()

    # caster_cast_time 语义=引导段时长（起手段由角色动画自带）
    var cast_time := slot.definition.caster_cast_time
    if cast_time > 0.0:
        if _has_cast_state():
            var release := Callable(self, "_spawn_spell_now").bind(slot)
            _character.state_machine.transition_to(
                    CAST_STATE_PATH, {cast_time = cast_time, release = release})
            return
        _warn_missing_cast_state(slot.definition)

    _spawn_spell_now(slot)

## 法术体真正上场（瞬发路径与施法状态到点释放共用）。
## 出手方向在释放瞬间读皮肤朝向，四方向归一化与攻击/施法状态同款。
## 修复：旧实现硬走 get_node("Skin") 路径——角色皮肤实名各异（如 ChenSkin），
## 解析失败时方向永远默认右（2026-09-15 契约测试牵出）。
func _spawn_spell_now(slot: SpellSlot) -> void:
    var spell := slot.definition.spell_scene.instantiate() as SpellBase
    var dir := Vector2.RIGHT
    var skin := _character._skin
    if skin != null:
        dir = snap_to_four_direction(skin.skin_direction)

    var spawn_parent := _character.get_parent()
    spawn_parent.add_child(spell)
    spell.global_position = _character.global_position + spell.get_spawn_offset(dir, slot.definition)
    spell.cast(_character, slot.definition, dir)

func _current_state_path() -> String:
    var machine := _character.state_machine
    if machine == null:
        return ""
    return str(machine.state_name)

## 白/黑名单按状态路径的"任意一段名"匹配（如 "Air/Knockout/Launch" 命中 Knockout）。
## 修复：旧实现拿全路径字符串与名单里的短名比较，永远不相等，禁令形同虚设。
func _is_state_allowed(spell_def: SpellDefinition) -> bool:
    var path := _current_state_path()
    if path.is_empty():
        return true
    var segments := path.split("/")

    for seg in segments:
        if spell_def.disallowed_states.has(StringName(seg)):
            return false

    if not spell_def.allowed_states.is_empty():
        for seg in segments:
            if spell_def.allowed_states.has(StringName(seg)):
                return true
        return false

    return true

func _is_casting() -> bool:
    return _current_state_path().get_file() == "Cast"

func _is_in_air() -> bool:
    var path := _current_state_path()
    return path != "" and path.split("/")[0] == "Air"

func _has_cast_state() -> bool:
    var machine := _character.state_machine
    return machine != null and machine.get_node_or_null(CAST_STATE_PATH) != null

func _warn_missing_cast_state(spell_def: SpellDefinition) -> void:
    var key := str(_character.name) + ":" + str(spell_def.spell_id)
    if _warned_no_cast_state.has(key):
        return
    _warned_no_cast_state[key] = true
    push_warning("法术 %s 配置了施法时长，但角色 %s 未挂 Ground/Cast 施法状态，已按瞬发处理" % [
            spell_def.spell_id, _character.name])

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
