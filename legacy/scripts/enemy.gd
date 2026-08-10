extends CharacterBody2D

# 敌人 AI 脚本（Week 5）
# 
# 简单状态机：PATROL → CHASE → ATTACK → PATROL
# 
# PATROL：在两个巡逻点之间移动
# CHASE：检测到玩家后追击
# ATTACK：接近玩家后攻击
# 
# 使用信号与 HurtBox 配合处理伤害

# ========================================
# 导出变量（可在 Inspector 调整）
# ========================================
@export var max_hp: int = 80
@export var move_speed: float = 120.0
@export var chase_speed: float = 180.0
@export var attack_damage: int = 15
@export var patrol_range: float = 200.0
@export var detection_range: float = 300.0
@export var attack_range: float = 60.0
@export var attack_cooldown: float = 1.0

# ========================================
# 状态机枚举
# ========================================
enum State { PATROL, CHASE, ATTACK }
var current_state: State = State.PATROL

# ========================================
# 节点引用
# ========================================
@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_pivot: Node2D = $AttackPivot
@onready var attack_hitbox: Area2D = $AttackPivot/AttackHitBox
@onready var hp_label: Label = $HPLabel
@onready var state_label: Label = $StateLabel
@onready var hurt_box: Area2D = $HurtBox

# ========================================
# 状态变量
# ========================================
var current_hp: int
var patrol_start: Vector2  # 巡逻起点
var patrol_target: Vector2  # 巡逻目标点
var facing: int = 1  # 1=右, -1=左
var player_ref: CharacterBody2D = null
var attack_timer: float = 0.0
var is_attacking: bool = false

# ========================================
# 生命周期
# ========================================
func _ready() -> void:
	current_hp = max_hp
	patrol_start = global_position
	patrol_target = patrol_start + Vector2(patrol_range, 0)
	
	# 连接 HurtBox 的 damage_received 信号
	hurt_box.damage_received.connect(_on_damage_received)
	
	# 连接 AttackHitBox：检测到玩家的 HurtBox 时触发
	attack_hitbox.area_entered.connect(_on_attack_hit)
	
	_update_hp_display()
	_update_state_display()

func _physics_process(delta: float) -> void:
	# 更新攻击冷却
	if attack_timer > 0:
		attack_timer -= delta
	
	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)
	
	# 应用朝向翻转
	sprite.flip_h = (facing == -1)
	attack_pivot.scale.x = facing

# ========================================
# 状态：PATROL
# ========================================
func _process_patrol(_delta: float) -> void:
	# 检测玩家
	if _detect_player():
		_change_state(State.CHASE)
		return
	
	# 向巡逻目标移动
	var direction = (patrol_target - global_position).normalized()
	var distance = global_position.distance_to(patrol_target)
	
	if distance < 10.0:
		# 到达巡逻点，切换目标
		if global_position.distance_to(patrol_start) < 10.0:
			patrol_target = patrol_start + Vector2(patrol_range, 0)
		else:
			patrol_target = patrol_start
		return
	
	velocity = direction * move_speed
	move_and_slide()
	
	# 更新朝向
	if direction.x != 0:
		facing = 1 if direction.x > 0 else -1

# ========================================
# 状态：CHASE
# ========================================
func _process_chase(_delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		_change_state(State.PATROL)
		return
	
	var distance = global_position.distance_to(player_ref.global_position)
	
	# 失去目标（距离太远）
	if distance > detection_range * 1.5:
		_change_state(State.PATROL)
		return
	
	# 进入攻击范围
	if distance <= attack_range:
		_change_state(State.ATTACK)
		return
	
	# 追击玩家
	var direction = (player_ref.global_position - global_position).normalized()
	velocity = direction * chase_speed
	move_and_slide()
	
	# 更新朝向
	if direction.x != 0:
		facing = 1 if direction.x > 0 else -1

# ========================================
# 状态：ATTACK
# ========================================
func _process_attack(_delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		_change_state(State.PATROL)
		return
	
	var distance = global_position.distance_to(player_ref.global_position)
	
	# 玩家脱离攻击范围
	if distance > attack_range * 1.2:
		_change_state(State.CHASE)
		return
	
	# 保持面向玩家
	var direction = (player_ref.global_position - global_position).normalized()
	if direction.x != 0:
		facing = 1 if direction.x > 0 else -1
	
	# 攻击冷却结束，发动攻击
	if attack_timer <= 0 and not is_attacking:
		_perform_attack()

# ========================================
# 攻击逻辑
# ========================================
func _perform_attack() -> void:
	is_attacking = true
	attack_timer = attack_cooldown
	
	# 激活 AttackHitBox（简化版，不用动画）
	attack_hitbox.visible = true
	attack_hitbox.monitoring = true
	
	# 等待一小段时间后关闭
	await get_tree().create_timer(0.2).timeout
	
	attack_hitbox.visible = false
	attack_hitbox.monitoring = false
	is_attacking = false

# ========================================
# 检测玩家
# ========================================
func _detect_player() -> bool:
	# 简单实现：在场景中找到 Player 节点
	if player_ref and is_instance_valid(player_ref):
		var distance = global_position.distance_to(player_ref.global_position)
		return distance <= detection_range
	
	# 尝试找到 Player
	if not player_ref:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player_ref = player
			var distance = global_position.distance_to(player_ref.global_position)
			return distance <= detection_range
	
	return false

# ========================================
# 伤害处理
# ========================================
func _on_damage_received(damage: int) -> void:
	current_hp -= damage
	current_hp = max(current_hp, 0)
	
	_update_hp_display()
	_play_hurt_animation()
	
	# 被攻击后强制进入 CHASE 状态
	if current_hp > 0 and current_state == State.PATROL:
		_change_state(State.CHASE)
	
	if current_hp <= 0:
		_die()

# ========================================
# 受击反馈
# ========================================
func _play_hurt_animation() -> void:
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 0.5, 0.5, 1), 0.05)
	tween.tween_property(sprite, "modulate", Color(0.8, 0.2, 0.2, 1), 0.1)

# ========================================
# 死亡
# ========================================
func _die() -> void:
	# 简单处理：直接删除
	queue_free()

# ========================================
# 攻击伤害判定（AttackHitBox 检测到 HurtBox 时触发）
# ========================================
func _on_attack_hit(area: Area2D) -> void:
	# 只对玩家的 HurtBox 产生伤害
	if area.is_in_group("player_hurt_box") or area.collision_layer == 4096:
		# 通过 HurtBox 的 parent 调用 take_damage
		var target = area.get_parent()
		if target and target.has_method("take_damage"):
			target.take_damage(attack_damage)
			print("Enemy 命中 %s, 造成 %d 伤害" % [target.name, attack_damage])

# ========================================
# 状态切换
# ========================================
func _change_state(new_state: State) -> void:
	current_state = new_state
	_update_state_display()

# ========================================
# UI 更新
# ========================================
func _update_hp_display() -> void:
	hp_label.text = str(current_hp) + " / " + str(max_hp)

func _update_state_display() -> void:
	match current_state:
		State.PATROL:
			state_label.text = "PATROL"
			state_label.modulate = Color(0.5, 1, 0.5, 1)  # 绿色
		State.CHASE:
			state_label.text = "CHASE"
			state_label.modulate = Color(1, 1, 0.5, 1)  # 黄色
		State.ATTACK:
			state_label.text = "ATTACK"
			state_label.modulate = Color(1, 0.5, 0.5, 1)  # 红色

# ========================================
# 供外部调用的受伤接口（被 player.gd 的 AttackHitBox 调用）
# ========================================
func take_damage(amount: int) -> void:
	_on_damage_received(amount)
