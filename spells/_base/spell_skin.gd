class_name SpellSkin
extends Node2D

enum SkinDirection { LEFT = -1, RIGHT = 1 }

@export var skin_direction: SkinDirection = SkinDirection.RIGHT:
    set(value):
        var has_changed := value != skin_direction
        skin_direction = value
        if has_changed:
            if not is_inside_tree():
                await ready
            _skin_direction_updated()

var base_height: float:
    get: return -position.y

@export var attack_heights: Array = []

@export_node_path("Node2D") var _path_hitboxes_container := ^"Attacks"
var hitboxes: Array[QuiverHitBox] = []

var _animation_list: Array[StringName] = []

signal spell_animation_finished
signal spell_hitbox_activated
signal spell_hitbox_deactivated
signal spell_effect_triggered
signal spell_spawn_requested(marker_name: String)
signal spell_ended

func _ready() -> void:
    _populate_animation_list()
    if Engine.is_editor_hint():
        _in_editor_ready()
    else:
        _runtime_ready()

func _runtime_ready() -> void:
    _skin_direction_updated()
    var hitboxes_container := get_node_or_null(_path_hitboxes_container) as Node2D
    if hitboxes_container:
        for child in hitboxes_container.get_children():
            if child is QuiverHitBox:
                hitboxes.append(child)

func _in_editor_ready() -> void:
    set_process(false)
    set_physics_process(false)

func end_of_spell_animation(_animation_name := "") -> void:
    spell_animation_finished.emit()

func spell_hit_active() -> void:
    spell_hitbox_activated.emit()

func spell_hit_deactive() -> void:
    spell_hitbox_deactivated.emit()

func apply_spell_effect() -> void:
    spell_effect_triggered.emit()

func spawn_at_frame(marker_name: String) -> void:
    spell_spawn_requested.emit(marker_name)

func end_of_spell() -> void:
    spell_ended.emit()

func _populate_animation_list() -> void:
    pass

func _skin_direction_updated() -> void:
    pass

func _is_valid_state(anim_state: StringName) -> bool:
    var value = anim_state in _animation_list
    if not value:
        push_error("SpellSkin: %s | %s is not a valid animation state." % [name, anim_state])
    return value
