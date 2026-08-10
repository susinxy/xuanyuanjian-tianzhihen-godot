extends StaticBody2D

# 测试目标脚本（Task 4.1 + 更新）
# 
# TargetDummy 是用于测试攻击判定的静态目标
# 包含 HP 系统和简单的受击反馈

# 最大血量（可在编辑器中调整）
@export var max_hp: int = 100

# 当前血量
var current_hp: int

# 节点引用
@onready var sprite: Sprite2D = $Sprite2D
@onready var hp_label: Label = $HPLabel
@onready var hurt_box: Area2D = $HurtBox

# 初始化
func _ready() -> void:
	current_hp = max_hp
	_update_hp_display()
	
	# 连接 HurtBox 的 damage_received 信号
	hurt_box.damage_received.connect(_on_damage_received)

# 受伤回调（被 HurtBox 信号触发）
func _on_damage_received(damage: int) -> void:
	current_hp -= damage
	current_hp = max(current_hp, 0)  # 不低于 0
	
	_update_hp_display()
	_play_hurt_flash()
	
	if current_hp <= 0:
		_die()

# 更新 HP 显示
func _update_hp_display() -> void:
	if hp_label:
		hp_label.text = str(current_hp) + " / " + str(max_hp)

# 受击闪烁效果
func _play_hurt_flash() -> void:
	if not sprite:
		return
	
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.3, 0.8), 0.05)
	tween.tween_property(sprite, "scale", Vector2(1, 1), 0.1)

# 死亡处理（暂时用简单消失，Week 6 再学死亡动画）
func _die() -> void:
	queue_free()
