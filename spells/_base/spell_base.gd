class_name SpellBase
extends Area2D

enum SpellState { INACTIVE, ACTIVE, ENDING, DEAD }

var definition: SpellDefinition = null
var caster: Node = null
var caster_attributes: QuiverAttributes = null
var direction: Vector2 = Vector2.RIGHT
var state: SpellState = SpellState.INACTIVE
var _elapsed_time: float = 0.0
var _cached_hitbox_height_bits: int = -1

@export_node_path("SpellSkin") var _path_skin := ^"Skin"

@onready var _skin: SpellSkin = get_node_or_null(_path_skin)

signal spell_cast
signal spell_hit(target: Area2D)
signal spell_activated
signal spell_ending
signal spell_destroyed
signal spell_timeout

func _ready() -> void:
    if Engine.is_editor_hint():
        return
    
    # 添加到 fireballs 组以便调试面板追踪
    add_to_group("fireballs")
    
    if _skin:
        _skin.spell_animation_finished.connect(_on_skin_animation_finished)
        _skin.spell_hitbox_activated.connect(_on_skin_hitbox_activated)
        _skin.spell_hitbox_deactivated.connect(_on_skin_hitbox_deactivated)
        _skin.spell_effect_triggered.connect(_on_skin_effect_triggered)
        _skin.spell_spawn_requested.connect(_on_skin_spawn_requested)
        _skin.spell_ended.connect(_on_skin_spell_ended)
    
    set_physics_process(false)
    _on_ready()

func cast(p_caster: Node, p_definition: SpellDefinition, p_direction: Vector2) -> void:
    if not is_inside_tree():
        await ready
    
    caster = p_caster
    definition = p_definition
    direction = p_direction.normalized()
    
    if caster.get("attributes") != null:
        caster_attributes = caster.attributes
    
    for group in caster.get_groups():
        add_to_group(group)
    
    if _skin:
        for hitbox in _skin.hitboxes:
            for group in caster.get_groups():
                hitbox.add_to_group(group)
            hitbox.character_attributes = caster_attributes
    
    if _skin:
        _skin.skin_direction = SpellSkin.SkinDirection.RIGHT \
            if direction.x >= 0 else SpellSkin.SkinDirection.LEFT
    
    _on_cast()
    
    state = SpellState.ACTIVE
    set_physics_process(true)
    spell_cast.emit()
    spell_activated.emit()
    
    if _skin and _skin._is_valid_state(&"active"):
        _skin.transition_to(&"active")

func _physics_process(delta: float) -> void:
    if state != SpellState.ACTIVE:
        return
    
    _elapsed_time += delta
    
    if definition and definition.max_lifetime > 0.0 and _elapsed_time >= definition.max_lifetime:
        spell_timeout.emit()
        end()
        return
    
    _update_hitbox_layers()
    _on_active(delta)

func _update_hitbox_layers() -> void:
    if _skin == null or caster == null:
        return
    
    var ah: Array = _skin.attack_heights
    var all_mask := QuiverCharacter.get_all_height_layers_mask()
    
    var target_bits := 0
    if not ah.is_empty():
        var base_h: float = _skin.base_height
        var height_defs := QuiverCharacter.get_height_definitions()
        for h in ah:
            var absolute_h: float = base_h + h
            var layer := QuiverCharacter.height_to_layer(absolute_h, height_defs)
            target_bits |= (1 << (layer - 1))
    
    if target_bits != _cached_hitbox_height_bits:
        _cached_hitbox_height_bits = target_bits
        for hitbox in _skin.hitboxes:
            hitbox.collision_layer = (hitbox.collision_layer & ~all_mask) | target_bits
            hitbox.collision_mask = (hitbox.collision_mask & ~all_mask) | all_mask

func end() -> void:
    if state == SpellState.DEAD or state == SpellState.ENDING:
        return
    
    state = SpellState.ENDING
    spell_ending.emit()
    _on_ending()
    
    if _skin and _skin._is_valid_state(&"ending"):
        _skin.transition_to(&"ending")
    else:
        destroy()

func destroy() -> void:
    if state == SpellState.DEAD:
        return
    
    state = SpellState.DEAD
    set_physics_process(false)
    spell_destroyed.emit()
    queue_free()

func on_hit(hurtbox: QuiverHurtBox) -> void:
    spell_hit.emit(hurtbox)
    _on_hit(hurtbox)

func _on_hit(hurtbox: QuiverHurtBox) -> void:
    end()

func get_spawn_offset(direction: Vector2) -> Vector2:
    var char_height: float = 160.0
    var char_width: float = 40.0
    if caster and caster.get("_skin"):
        var skin = caster._skin
        if skin.get("physical_height") != null:
            char_height = skin.physical_height
        if skin.get("physical_width") != null:
            char_width = skin.physical_width
    
    var x_offset := (char_width * 0.5 + 30.0) * direction.x
    var y_offset := -char_height * 0.6
    return Vector2(x_offset, y_offset)

func _on_ready() -> void:
    pass

func _on_cast() -> void:
    pass

func _on_active(delta: float) -> void:
    position += direction * 400.0 * delta

func _on_ending() -> void:
    pass

func _on_skin_animation_finished() -> void:
    pass

func _on_skin_hitbox_activated() -> void:
    if _skin:
        for hitbox in _skin.hitboxes:
            for child in hitbox.get_children():
                if child is CollisionShape2D or child is CollisionPolygon2D:
                    child.disabled = false

func _on_skin_hitbox_deactivated() -> void:
    if _skin:
        for hitbox in _skin.hitboxes:
            for child in hitbox.get_children():
                if child is CollisionShape2D or child is CollisionPolygon2D:
                    child.disabled = true

func _on_skin_effect_triggered() -> void:
    pass

func _on_skin_spawn_requested(marker_name: String) -> void:
    pass

func _on_skin_spell_ended() -> void:
    end()
