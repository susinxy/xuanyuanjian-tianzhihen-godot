class_name SpellSkin
extends Node2D

## 法术体朝向：四正方向单位向量（上/下/左/右），直接作为混合空间坐标。
## 由 SpellBase.cast 用 SpellManager.snap_to_four_direction 量化后写入；
## 混合空间四点与角色攻击同款（(1,0)/(0,-1)/(-1,0)/(0,1)）。
## 旧版是 LEFT/RIGHT 两态枚举——上下飞行的法术只能侧身（2026-09 契约升级）。
@export var skin_direction: Vector2 = Vector2.RIGHT:
	set(value):
		var has_changed := not value.is_equal_approx(skin_direction)
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

## 静默存在性查询（可选状态门禁专用；角色线同名先例）。
## _is_valid_state 的 push_error 留给"真去 transition 一个不存在状态"的错误路径，
## 用探针语义时不该报警（2026-09-16：火球无 ending 属合法形态，超时释放每发刷一条）。
func has_anim_state(anim_state: StringName) -> bool:
	return anim_state in _animation_list


func _is_valid_state(anim_state: StringName) -> bool:
	var value = anim_state in _animation_list
	if not value:
		push_error("SpellSkin: %s | %s is not a valid animation state." % [name, anim_state])
	return value
