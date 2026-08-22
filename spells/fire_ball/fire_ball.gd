@tool
extends SpellBase

## 火球术 法术
##
## 直线飞行的投射物，命中后销毁

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

## 飞行速度（像素/秒）
@export var speed: float = 400.0

#--- private variables - order: export > normal var > onready -------------------------------------

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
	# 命中后播放爆炸动画（如果存在），否则直接销毁
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
