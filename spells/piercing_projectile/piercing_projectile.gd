@tool
extends SpellBase

## 穿透弹 法术
##
## 直线飞行的投射物，可穿透多个目标后销毁

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

## 飞行速度（像素/秒）
@export var speed: float = 600.0

## 最大穿透次数
@export var max_hits: int = 3

#--- private variables - order: export > normal var > onready -------------------------------------

var _hit_count: int = 0

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _on_ready() -> void:
	pass

func _on_cast() -> void:
	pass

func _on_active(delta: float) -> void:
	# 直线飞行
	position += direction * speed * delta

func _on_ending() -> void:
	pass

func _on_hit(hurtbox: QuiverHurtBox) -> void:
	_hit_count += 1
	# 穿透次数用完才销毁
	if _hit_count >= max_hits:
		if _skin and _skin._is_valid_state(&"hit"):
			_skin.transition_to(&"hit")
		else:
			destroy()

func _on_skin_animation_finished() -> void:
	pass

func _on_skin_effect_triggered() -> void:
	# 爆炸效果（由 hit 动画的 apply_spell_effect method track 触发）
	pass

func _on_skin_spell_ended() -> void:
	# 爆炸动画播完后销毁
	destroy()

func _on_skin_spawn_requested(marker_name: String) -> void:
	pass

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
