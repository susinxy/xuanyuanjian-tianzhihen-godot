extends Area2D

# 受击判定区域脚本（Task 4.1 + Week 5 升级）
# 
# HurtBox 是"被攻击"的区域，挂在可以被伤害的角色身上（TargetDummy、敌人、玩家等）
# 当 HitBox 进入 HurtBox 时，通过 area_entered 信号触发 apply_damage
# 
# 配置规范（与 Downtown Beatdown 模板一致）：
#   - collision_layer = 14 (enemy_hurt_boxes=8192) 或 13 (player_hurt_boxes=4096)
#   - collision_mask = 0 (被动被检测，不主动检测其他)
#   - monitoring = false
#   - monitorable = true

# 伤害接收信号（父节点可连接此信号）
signal damage_received(damage: int)

# 伤害接收方法（被 HitBox 调用）
func apply_damage(amount: int) -> void:
	damage_received.emit(amount)
