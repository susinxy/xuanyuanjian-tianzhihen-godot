@tool
extends Node

## 周期性攻击脚本
##
## 挂载在 Enemy 角色上，周期性启用/禁用所有 HitBox 的 CollisionShape2D。
## 攻击阶段：启用所有 HitBox shape → 玩家走过去就受击
## 休息阶段：禁用所有 HitBox shape

### Member Variables and Dependencies -------------------------------------------------------------

@export var attack_duration: float = 0.5
@export var rest_duration: float = 2.0

var _shapes: Array[CollisionShape2D] = []
var _timer: float = 0.0
var _is_attacking: bool = false

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_collect_hitbox_shapes()
	_set_shapes_enabled(false)
	_timer = rest_duration


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	_timer -= delta
	if _timer <= 0.0:
		_is_attacking = not _is_attacking
		_set_shapes_enabled(_is_attacking)
		_timer = attack_duration if _is_attacking else rest_duration

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _collect_hitbox_shapes() -> void:
	var skin := get_parent().get_node_or_null("EnemySkin")
	if skin == null:
		return
	
	var attacks := skin.get_node_or_null("Attacks")
	if attacks == null:
		return
	
	for attack_node in attacks.get_children():
		if attack_node is Area2D:
			for child in attack_node.get_children():
				if child is CollisionShape2D:
					_shapes.append(child)


func _set_shapes_enabled(enabled: bool) -> void:
	for shape in _shapes:
		shape.disabled = not enabled

### -----------------------------------------------------------------------------------------------
