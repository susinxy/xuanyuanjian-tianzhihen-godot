@tool
extends Node

## 敌人受击处理脚本
##
## 挂载在测试场景的 enemy 节点上，监听 hurt_requested 信号并播放受伤动画。
## 用于提供测试时的受击反馈，不影响键盘输入。

### Member Variables and Dependencies -------------------------------------------------------------

@export var facing_direction: int = -1  # -1 = 朝左, 1 = 朝右

var _skin: QuiverCharacterSkin = null
var _is_hurt: bool = false

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	var enemy = get_parent()
	if enemy == null or enemy.attributes == null:
		push_warning("HurtHandler: parent or attributes is null")
		return
	
	_skin = enemy.get_node_or_null("EnemySkin")
	if _skin == null:
		push_warning("HurtHandler: EnemySkin not found")
		return
	
	# 移除 enemy 与 player 的物理碰撞（保留高度层碰撞）
	enemy.set_collision_layer_value(1, false)
	enemy.set_collision_mask_value(1, false)
	
	# 手动设置 physical_height（动画轨道没有更新它）
	_skin.physical_height = 180.0
	
	# 设置朝向
	_skin.skin_direction = facing_direction
	
	# 连接信号
	_skin.skin_animation_finished.connect(_on_animation_finished)
	enemy.attributes.hurt_requested.connect(_on_hurt_requested)
	enemy.attributes.knockout_requested.connect(_on_knockout_requested)
	
	# 初始状态
	_skin.transition_to(&"idle")


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	# 持续更新 ground_level（因为 StateMachine 被移除了）
	var enemy = get_parent()
	if enemy != null and enemy.attributes != null:
		enemy.attributes.ground_level = enemy.global_position.y

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _on_hurt_requested(knockback_data: QuiverKnockbackData) -> void:
	if _is_hurt or _skin == null:
		return
	
	_is_hurt = true
	
	# 根据 knockback 强度选择动画
	if knockback_data.strength >= CombatSystem.KnockbackStrength.MEDIUM:
		_skin.transition_to(&"hurt_high")
	else:
		_skin.transition_to(&"hurt_mid")


func _on_knockout_requested(knockback_data: QuiverKnockbackData) -> void:
	if _skin == null:
		return
	
	_is_hurt = true
	_skin.transition_to(&"knockout_launch")


func _on_animation_finished() -> void:
	if _is_hurt and _skin != null:
		_is_hurt = false
		_skin.transition_to(&"idle")

### -----------------------------------------------------------------------------------------------
