# 伤害系统详解 - Week 4

> **创建时间**: 2026-08-09  
> **关联任务**: Task 4.1, Task 4.2, Task 4.3  
> **前置知识**: [Pivot 节点设计](./PIVOT_NODE_DESIGN.md), [处理循环详解](./GODOT_PROCESS_EXPLAINED.md)

---

## 📋 目录

1. [伤害系统的核心问题](#核心问题)
2. [碰撞层配置](#碰撞层配置)
3. [HurtBox 实现](#hurtbox-实现-hurt_boxgd)
4. [TargetDummy 实现](#targetdummy-实现-target_dummygd)
5. [AttackHitBox 信号连接](#attackhitbox-信号连接-playergd)
6. [完整触发链](#完整触发链)
7. [学到的概念](#学到的概念汇总)

---

## 🎯 核心问题

伤害系统要解决 4 个问题：

```
问题 1: 攻击何时生效？
  → 只在攻击动画的"判定窗口"内检测碰撞（Task 3.3 已实现）

问题 2: 怎么知道"打到了"？
  → 用 Area2D 的 area_entered 信号

问题 3: 打中后怎么处理？
  → 传递伤害数值，让被攻击方计算 HP

问题 4: 如何保证不误中友军？
  → 用碰撞层精确控制"谁能打到谁"
```

---

## 🔧 碰撞层配置

### project.godot 修改

```ini
[layer_names]
2d_physics/layer_1="players"           # 玩家身体
2d_physics/layer_2="obstacles"         # 墙壁/障碍物
2d_physics/layer_5="enemies"           # 敌人身体
2d_physics/layer_8="player_hit_boxes"  # 玩家攻击判定
2d_physics/layer_14="enemy_hurt_boxes" # 敌人受击判定
```

### 位掩码（bitmask）计算

Godot 用数字表示层，本质是二进制的位运算：

| Layer | 位 | 值 | 二进制 |
|-------|---|----|-------|
| layer 1 | bit 0 | 1 | `00001` |
| layer 2 | bit 1 | 2 | `00010` |
| layer 5 | bit 4 | 16 | `10000` |
| layer 8 | bit 7 | 128 | `10000000` |
| layer 14 | bit 13 | 8192 | `10000000000000` |

**mask = 多个 layer 相加**：
```
Player mask = layer 1 + layer 2 = 1 + 2 = 3
              (玩家会和 layer 1 和 layer 2 的物体碰撞)
```

### Layer vs Mask 的核心概念

| 属性 | 英文含义 | 中文比喻 |
|------|---------|---------|
| `layer` | "我在哪个频道" | 我的标签 |
| `mask` | "我看哪些频道" | 我的过滤器 |

**两个物体碰撞需要双向匹配**：
```
A 的 mask 要包含 B 的 layer（A 在找 B）
且
B 的 mask 要包含 A 的 layer（B 在找 A）
```

只要其中一条满足就能碰撞。

---

## 🛡️ HurtBox 实现 (`hurt_box.gd`)

### 核心代码

```gdscript
extends Area2D

# 受击判定区域脚本
# 配置规范（与 Downtown Beatdown 模板一致）：
#   - collision_layer = 14 (enemy_hurt_boxes) 或 13 (player_hurt_boxes)
#   - collision_mask = 0 (被动被检测，不主动检测其他)
#   - monitoring = false (不主动检测别人)
#   - monitorable = true (允许被别人的 HitBox 检测)

signal damage_received(damage: int)

func apply_damage(damage: int) -> void:
    damage_received.emit(damage)

func _ready() -> void:
    monitorable = true  # 强制开启被动检测
```

### 为什么用 signal？

**方案 A：直接调用 take_damage（强耦合）**
```gdscript
# ❌ 不推荐
func apply_damage(damage: int) -> void:
    get_parent().take_damage(damage)  # 硬编码父节点
```

**方案 B：发射信号（弱耦合）**
```gdscript
# ✅ 推荐
func apply_damage(damage: int) -> void:
    damage_received.emit(damage)
```

**信号的优势**：
- HurtBox 不需要知道"谁受伤"
- 一个 HurtBox 可以被多个系统监听（HP、音效、特效、成就等）
- 更容易扩展

### HurtBox 的 4 个关键属性

| 属性 | 值 | 原因 |
|-----|---|------|
| `collision_layer` | 14 (enemy_hurt) | 标识为"敌方受击区" |
| `collision_mask` | 0 | 被动，不主动检测 |
| `monitoring` | false | 关闭主动检测（节省 CPU） |
| `monitorable` | true | 允许被 HitBox 检测到 |

---

## 🎯 TargetDummy 实现 (`target_dummy.gd`)

### 核心代码

```gdscript
extends CharacterBody2D

@export var max_hp: int = 100  # 可在 Inspector 调整
var current_hp: int = 100

@onready var hp_label: Label = $HPLabel
@onready var hurt_box: Area2D = $HurtBox

func _ready() -> void:
    hurt_box.damage_received.connect(_on_damage_received)
    _update_hp_display()

func _on_damage_received(damage: int) -> void:
    current_hp -= damage
    current_hp = max(current_hp, 0)
    
    _play_hurt_animation()
    _update_hp_display()
    
    if current_hp <= 0:
        _die()

func _play_hurt_animation() -> void:
    var tween = create_tween()
    tween.tween_property(self, "scale", Vector2(1.2, 0.8), 0.1)
    tween.tween_property(self, "scale", Vector2.ONE, 0.1)

func _update_hp_display() -> void:
    hp_label.text = str(current_hp) + " / " + str(max_hp)

func _die() -> void:
    queue_free()
```

### @export 的作用

```gdscript
@export var max_hp: int = 100
```

在 Inspector 中可以调整这个值，无需改代码。测试不同血量时非常方便。

### Tween 动画原理

```gdscript
var tween = create_tween()
tween.tween_property(self, "scale", Vector2(1.2, 0.8), 0.1)
tween.tween_property(self, "scale", Vector2.ONE, 0.1)
```

**时间线**：
```
0.0s:  scale = (1, 1)      → 正常大小
0.1s:  scale = (1.2, 0.8)  → 变宽变矮（"挤压"）
0.2s:  scale = (1, 1)      → 恢复正常
```

Tween 会自动按顺序执行（chain 模式），产生"抖动"视觉效果。

### `queue_free()` vs `free()`

| 方法 | 说明 |
|-----|------|
| `free()` | 立即删除（危险，可能崩溃）|
| `queue_free()` | 在帧结束时删除（安全）|

**比喻**：
- `free()`：直接拔电源（程序可能正在读这个节点）
- `queue_free()`：排队等待删除（安全）

---

## ⚔️ AttackHitBox 信号连接 (`player.gd`)

### 核心代码

```gdscript
@export var attack_damage: int = 10

func _ready() -> void:
    attack_hitbox.area_entered.connect(_on_attack_hit)

func _on_attack_hit(area: Area2D) -> void:
    if area.has_method("apply_damage"):
        area.apply_damage(attack_damage)
```

### `area_entered` 信号的触发条件

```
触发条件：
1. AttackHitBox.monitoring = true（我们在 attack 动画中控制）
2. AttackHitBox.collision_mask 包含目标 Area2D 的 collision_layer
3. 目标 Area2D 是 monitorable = true
4. 两个 Area2D 的 CollisionShape 有重叠
```

### `has_method()` 防御检查

```gdscript
if area.has_method("apply_damage"):
    area.apply_damage(attack_damage)
```

**为什么需要？**
- Area2D 可能进入的不是 HurtBox（比如触发器对话框的 Area2D）
- 如果硬调用不存在的方法会崩溃
- 防御编程让攻击更健壮

---

## 🔗 完整触发链

```
用户按 J 键
  ↓
player.gd._physics_process()
  ↓
检测 Input.is_action_just_pressed("attack")
  ↓
播放 attack 动画（animation_player.play("attack")）
  ↓
动画控制 AttackHitBox.monitoring：
  0.0s - 0.05s: false
  0.05s - 0.25s: true ← 判定窗口
  0.25s - 0.3s: false
  ↓
判定窗口内，AttackHitBox (layer 8, mask 14) 持续检测
  ↓
碰到 HurtBox (layer 14, monitorable=true)
  ↓
AttackHitBox.area_entered 信号触发
  ↓
player.gd._on_attack_hit(hurt_box)
  ↓
检查 hurt_box.has_method("apply_damage") → true
  ↓
hurt_box.apply_damage(10)
  ↓
hurt_box.gd.damage_received.emit(10)
  ↓
target_dummy.gd._on_damage_received(10)
  ↓
current_hp -= 10 → 90
  ↓
_update_hp_display() → HPLabel.text = "90 / 100"
  ↓
_play_hurt_animation() → Tween 动画
  ↓
检查 current_hp <= 0 → false（还没死）

... 重复 10 次攻击后 ...

current_hp = 0
  ↓
_die()
  ↓
queue_free() → TargetDummy 从场景中删除
```

---

## 📚 学到的概念汇总

### 核心概念

| 概念 | 说明 | 应用 |
|-----|------|-----|
| **HurtBox 模式** | 独立的受击判定区域（Area2D）| TargetDummy.HurtBox |
| **HitBox 模式** | 独立的攻击判定区域（Area2D）| Player.AttackHitBox |
| **Signal 信号** | 松耦合通信机制 | damage_received |
| **Delegate 模式** | 转发伤害给父节点 | apply_damage → take_damage |
| **@export** | 编辑器可调参数 | max_hp, attack_damage |
| **Tween 动画** | create_tween() 补间动画 | Tween 闪烁 |
| **queue_free()** | 安全删除节点 | _die() |
| **双向碰撞** | Layer/Mask 双向匹配 | 攻击判定 |
| **位掩码** | 2 的 n 次方表示层 | layer 1 = 1, layer 2 = 2 |

### 常见节点的常用信号

| 节点类型 | 常用信号 |
|---------|---------|
| **Area2D** | `area_entered`, `area_exited`, `body_entered`, `body_exited` |
| **Button** | `pressed`, `toggled` |
| **Timer** | `timeout` |
| **AnimationPlayer** | `animation_finished`, `animation_started` |
| **Tween** | `finished`, `step_finished` |

### 如何查找节点的信号

1. **Inspector 面板 → Node 标签 → Signals 子标签**（最快）
2. **F1 打开帮助文档**（最深入）
3. **脚本中输入 `. ` 触发自动提示**（编码时）
4. **双击信号自动连接并生成代码**（编辑器便捷方式）

---

## 🎓 设计哲学

### 为什么 HurtBox 要单独一个节点？

**不能用 TargetDummy 的 CollisionShape 做判定吗？**

| 方案 | 优点 | 缺点 |
|-----|-----|------|
| TargetDummy 自身检测 | 节点少，简单 | HurtBox 无法独立配置 |
| 独立 HurtBox 节点 ✅ | 灵活、可扩展 | 节点稍多 |

独立的 HurtBox 可以：
- 独立配置碰撞层
- 可以有多个 HurtBox（头部、身体、四肢不同伤害倍率）
- 可以临时 disabled（无敌帧）

### 为什么用 Signal 而不是直接调用？

**直接调用**：
```gdscript
# HurtBox 需要"知道"父节点是 TargetDummy
get_parent().take_damage(damage)
```

**用 Signal**：
```gdscript
# HurtBox 只发射信号，不关心接收者
damage_received.emit(damage)
```

Signal 的优势：
- **解耦**：HurtBox 不需要知道父节点是什么
- **多监听者**：音效、特效、成就系统都可以监听同一信号
- **Godot 哲学**：官方推荐的节点间通信方式

---

## 🔗 相关文档

- [Pivot 节点设计](./PIVOT_NODE_DESIGN.md) - AttackPivot 的设计理由
- [Godot 处理循环详解](./GODOT_PROCESS_EXPLAINED.md) - _process vs _physics_process
- [ARPG 设计方法论](../docs/ARPG_DESIGN_RESEARCH.md) - 游戏设计角度

---

> **文档版本**: 1.0  
> **最后更新**: 2026-08-09  
> **作者**: 黑仔（AI 搭档）+ 新哥
