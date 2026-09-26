extends Node

## Write your doc string for this file here

### Signals ---------------------------------------------------------------------------------------

signal characters_reseted

signal enemy_defeated

signal player_died

## 命中落地回执（B4.7 R4）：常规结算支（近战+弹体一视同仁）判定完成后广播。
## point=接触点（攻击盒与受击盒两位置的中点）、style=攻击方
## attack_data.hit_effect_style 风格路由旗、strength=knock_strength（消费者
## 可选用的强度线索）、dir=(受击盒位−攻击盒位) 归一化（零向量时发送端兜底
## Vector2.RIGHT）。免伤路（格挡/弹反）不发——它们自有白闪双档反馈件。
signal hit_landed(point: Vector2, style: StringName, strength: float, dir: Vector2)

### -----------------------------------------------------------------------------------------------
