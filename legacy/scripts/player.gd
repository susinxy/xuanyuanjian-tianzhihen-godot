extends CharacterBody2D

# 移动速度（像素/秒）
@export var speed: float = 200.0

# 角色朝向：1 = 右，-1 = 左
@export var facing: int = 1

# 生命值（Week 5 新增）
@export var max_hp: int = 100
var current_hp: int

# 攻击伤害（Task 4.2）
@export var attack_damage: int = 10

# 节点引用
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var attack_pivot: Node2D = $AttackPivot
@onready var attack_hitbox: Area2D = $AttackPivot/AttackHitBox
@onready var hp_label: Label = $HPLabel
@onready var hurt_box: Area2D = $HurtBox

# 当前播放的动画（用于优化，避免重复调用 play）
var current_animation: String = ""

# 攻击状态（Task 3.3）
# _is_attacking = true 时：
#   - 不允许移动和改变朝向
#   - 保持 attack 动画播放
#   - 直到动画结束才恢复
var _is_attacking: bool = false

func _ready() -> void:
	# 加入"player"分组（让敌人能通过分组找到玩家）
	add_to_group("player")
	
	# 初始化 HP
	current_hp = max_hp
	_update_hp_display()
	
	# 连接 HurtBox 信号（Week 5）
	hurt_box.damage_received.connect(_on_damage_received)
	
	# 监听动画完成信号，用于识别攻击动画结束
	anim_player.animation_finished.connect(_on_animation_finished)
	# 监听攻击判定区域碰撞（Task 4.2）
	# 注意：只有 AttackHitBox.monitoring=true 时才会触发
	# 在 attack 动画的 0.05-0.25 秒区间 monitoring 为 true
	attack_hitbox.area_entered.connect(_on_attack_hit)

func _physics_process(_delta: float) -> void:
	# 物理帧：读取输入、计算速度、执行移动（与物理引擎同步）
	var direction := Vector2.ZERO
	
	# 攻击期间：锁定移动和朝向，只维持零速度
	if not _is_attacking:
		direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		direction.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
		
		if direction.length() > 0:
			direction = direction.normalized()
			# 更新朝向（仅在有水平移动时）
			if direction.x != 0:
				facing = 1 if direction.x > 0 else -1
		
		# 检测攻击输入（J 键）
		if Input.is_action_just_pressed("attack"):
			_is_attacking = true
			direction = Vector2.ZERO  # 立即停止移动（不让惯性滑动）
	
	# 设置速度并移动（必须在物理帧）
	velocity = direction * speed
	move_and_slide()

func _process(_delta: float) -> void:
	# 渲染帧：所有纯视觉更新
	
	# 第一步：应用朝向翻转（先决定方向）
	sprite.flip_h = (facing == -1)
	attack_pivot.scale.x = facing
	
	# 第二步：更新动画（再决定动作）
	_update_animation()

func _update_animation() -> void:
	# 攻击期间：强制保持 attack 动画，不切换到 idle/walk
	if _is_attacking:
		if current_animation != "attack":
			current_animation = "attack"
			anim_player.play("attack")
		return
	
	# 非攻击状态：根据最近一次物理帧计算的 velocity 决定动画
	# velocity 在 _physics_process 中更新，_process 读取其最新值
	var target_anim: String

	if velocity.length() > 0:
		target_anim = "walk"
	else:
		target_anim = "idle"

	# 只在动画变化时才调用 play（避免每帧重置动画进度）
	if current_animation != target_anim:
		current_animation = target_anim
		anim_player.play(target_anim)

func _on_animation_finished(anim_name: String) -> void:
	# 攻击动画结束时，重置攻击状态
	if anim_name == "attack":
		_is_attacking = false
		# 清空 current_animation，让 _update_animation 重新根据 velocity 选择
		current_animation = ""

func _on_attack_hit(area: Area2D) -> void:
	# Task 4.2：攻击判定区域触碰到对方的 HurtBox 时调用
	# 
	# 调用对方的 apply_damage(amount) 方法
	# 这要求对方（如 TargetDummy）的 HurtBox 脚本有 apply_damage 方法
	# apply_damage 内部会把伤害转发给父节点（TargetDummy）的 take_damage
	if area.has_method("apply_damage"):
		area.apply_damage(attack_damage)
		# 可选：打印命中信息
		print("命中！对 %s 造成 %d 点伤害" % [area.get_parent().name, attack_damage])

# ========================================
# 受伤处理（Week 5 新增）
# ========================================
func _on_damage_received(damage: int) -> void:
	current_hp -= damage
	current_hp = max(current_hp, 0)
	_update_hp_display()
	_play_hurt_flash()
	
	# 受击时如果正在攻击，不强制打断（简单处理）
	# 如果希望被打断攻击，可以加：_is_attacking = false
	
	if current_hp <= 0:
		_die()

func _update_hp_display() -> void:
	hp_label.text = "HP: " + str(current_hp) + " / " + str(max_hp)

func _play_hurt_flash() -> void:
	if not sprite:
		return
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 0.5, 0.5, 1), 0.05)
	var base_color := Color(1, 1, 1, 1)
	tween.tween_property(sprite, "modulate", base_color, 0.1)

func _die() -> void:
	# 简单的死亡效果：淡出后删除
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

# ========================================
# 供外部调用的受伤接口（被 enemy.gd 使用）
# ========================================
func take_damage(amount: int) -> void:
	_on_damage_received(amount)
