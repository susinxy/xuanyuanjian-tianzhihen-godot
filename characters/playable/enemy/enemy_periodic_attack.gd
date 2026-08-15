@tool
extends Node

## 周期性攻击脚本
##
## 挂载在 Enemy 角色上，周期性播放攻击动画。
## 攻击动画会自动处理 HitBox 的启用/禁用时机。

### Member Variables and Dependencies -------------------------------------------------------------

@export var rest_duration: float = 2.0

var _skin: QuiverCharacterSkin = null
var _timer: float = 0.0
var _is_attacking: bool = false

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_skin = get_parent().get_node_or_null("EnemySkin")
	if _skin == null:
		return
	
	_skin.skin_animation_finished.connect(_on_skin_animation_finished)
	_skin.transition_to(&"idle")
	_timer = rest_duration


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _skin == null or _is_attacking:
		return
	
	_timer -= delta
	if _timer <= 0.0:
		_start_attack()

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _start_attack() -> void:
	_is_attacking = true
	_skin.transition_to(&"attack1")


func _on_skin_animation_finished() -> void:
	if _is_attacking:
		_is_attacking = false
		_skin.transition_to(&"idle")
		_timer = rest_duration

### -----------------------------------------------------------------------------------------------
