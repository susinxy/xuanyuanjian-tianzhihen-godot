# Godot 处理循环详解 - _process vs _physics_process

> **作者**: 黑仔 (AI 搭档)  
> **更新时间**: 2026-08-08  
> **参考**: Godot 4.7 官方文档  
> **重要性**: ⚠️ 这是 Godot 核心机制,必须理解  
> **背景**: 学习 Task 2.2 (动画系统) 时发现的常见误区,特此记录

---

## 🎯 核心概念

Godot 有**两个独立的处理循环**,它们的频率可以不同:

```
游戏循环 (每秒)
├── 渲染帧 (Render Frame) - 可变频率
│   └── 调用 _process(delta)
│
└── 物理帧 (Physics Tick) - 固定频率
    └── 调用 _physics_process(delta)
```

### 1. `_process(delta)` - 空闲处理 / 渲染帧处理

- **别名**: Idle Processing
- **调用频率**: 跟随渲染帧率 (FPS)
- **特点**:
  - 每渲染一帧调用一次
  - 频率随硬件性能和 VSync 变化
  - `delta` 不稳定(随帧率波动)
- **用途**: 纯视觉、UI 更新、非物理操作

### 2. `_physics_process(delta)` - 物理处理 / 物理帧处理

- **别名**: Physics Processing
- **调用频率**: 固定物理帧率 (TPS = Ticks Per Second)
- **特点**:
  - 固定每秒调用 N 次(默认 60)
  - **独立于渲染帧率**
  - `delta` 基本稳定(约等于 1/TPS)
- **用途**: 物理相关代码(velocity, move_and_slide, 碰撞检测)

---

## ⚠️ 关键差异对照表

| 特性 | `_process` | `_physics_process` |
|------|-----------|-------------------|
| **别名** | Idle Processing | Physics Processing |
| **帧率类型** | FPS (渲染帧率) | TPS (物理帧率) |
| **默认频率** | 随硬件 (0-数百) | **60 TPS (固定)** |
| **delta 稳定性** | ❌ 不稳定 | ✅ 基本稳定 |
| **设置位置** | - | Project Settings > Physics > Ticks per Second |
| **与 VSync 关系** | 受 VSync 影响 | 不受 VSync 影响 |
| **主要用途** | 视觉、UI | 物理、移动 |

---

## 💡 实际运行例子

### 场景 1: 显示器 144Hz, VSync 开启

```
FPS = 144 (每渲染帧 ≈ 6.94ms)
TPS = 60  (每物理帧 ≈ 16.67ms)

每秒执行:
├── _process 调用 144 次
└── _physics_process 调用 60 次

一渲染帧(约 6.94ms)内:
├── _process 调用 1 次
└── _physics_process 调用 约 0.4 次 (非整数,引擎智能调度)
```

### 场景 2: 低配机器,游戏卡顿,FPS = 30

```
FPS = 30  (每渲染帧 ≈ 33.3ms)
TPS = 60  (每物理帧 ≈ 16.67ms)

每秒执行:
├── _process 调用 30 次
└── _physics_process 调用 60 次

一渲染帧(约 33.3ms)内:
├── _process 调用 1 次
└── _physics_process 调用 2 次!  ← 重要
```

**关键洞察**: 低帧率时,引擎会在一渲染帧内**多调用几次 _physics_process**,以维持物理模拟的稳定性。否则物理效果会"变慢"。

---

## 🔧 如何选择使用哪个函数 ?

### 必须用 `_physics_process` 的代码 ✅

```gdscript
func _physics_process(delta):
    # ✅ 移动相关 - 必须
    velocity = direction * speed
    move_and_slide()  # 物理函数必须在物理帧调用
    
    # ✅ 物理查询 - 必须
    var collision = move_and_collide(velocity * delta)
    
    # ✅ 速度/加速度计算
    velocity.y += gravity * delta
```

### 推荐用 `_process` 的代码 👍

```gdscript
func _process(delta):
    # 👍 纯视觉更新
    camera.offset = lerp(camera.offset, target_offset, 0.1)
    
    # 👍 UI 更新
    health_bar.value = player.hp
    score_label.text = str(score)
    
    # 👍 非物理动画
    tween.interpolate_value(...)
```

### 两者都可以的代码 ⚠️

```gdscript
# ⚠️ 输入检测(Input 随时可读,放哪都行)
var direction = get_input_direction()

# ⚠️ 简单状态机(不涉及物理的)
if state == IDLE:
    # 做些事
```

---

## 📊 最佳实践示例

```gdscript
extends CharacterBody2D

@export var speed: float = 200.0

func _physics_process(delta):
    # ✅ 物理: 输入 → 速度 → 移动
    var direction := get_input_direction()
    velocity = direction * speed
    move_and_slide()
    
    # ✅ 物理同步: 动画状态更新(基于 velocity)
    update_animation_state()

func _process(delta):
    # ✅ 视觉: UI 更新、非物理动画
    update_ui()
    # Camera2D 的 position_smoothing 已内置处理
```

---

## ⚙️ 调整物理帧率

### Project Settings 位置

`Project` → `Project Settings` → 搜索: `physics_ticks_per_second`

**完整路径**: `Physics` > `Common` > `Physics Ticks per Second`  
**默认值**: 60

### 推荐值参考

| 游戏类型 | 推荐 TPS | 原因 |
|---------|---------|------|
| **平台跳跃** | 60 | 平衡性能和精度 |
| **2D 俯视 ARPG** | 60 | 默认值足够 |
| **快节奏 FPS** | 90-120 | 高精度碰撞 |
| **简单休闲游戏** | 30-45 | 节省 CPU |
| **赛车游戏** | 120+ | 高速精确物理 |

**我们天之痕项目**: 使用默认 60 即可。

---

## 🎯 move_and_slide 特别说明

### 自动处理 delta,无需手动乘

```gdscript
# ❌ 错误: 手动乘 delta
velocity = direction * speed * delta  # 错!
move_and_slide()

# ✅ 正确: 直接用 velocity
velocity = direction * speed  # 对!
move_and_slide()  # 它内部自动乘 delta
```

### 对比 move_and_collide

```gdscript
# move_and_collide 需要手动乘 delta
var collision = move_and_collide(velocity * delta)  # 需要 * delta

# move_and_slide 不需要
velocity = direction * speed
move_and_slide()  # 不需要 * delta
```

**原理**: `move_and_slide` 是更高级的 API,内部封装了 delta、碰撞滑动等一系列复杂逻辑。

---

## 🌐 高级概念: Physics Interpolation (物理插值)

Godot 4.6+ 支持 **Physics Interpolation**,解决低 TPS 视觉卡顿问题。

### 工作原理

```
TPS = 60, FPS = 144

不用插值:
- 渲染帧 1: 物理帧位置 A
- 渲染帧 2: 还是位置 A (因为物理帧还没更新) ← 卡顿!
- 渲染帧 3: 物理帧位置 B

用插值:
- 渲染帧 1: 位置 A
- 渲染帧 1.5: 引擎自动插值到 A 和 B 之间 ← 平滑!
- 渲染帧 2: 位置 B
```

### 启用方法

`Project Settings` > `Physics` > `Common` > `Physics Interpolation` 勾选启用

**适用场景**: 当物理帧率低于显示器刷新率时(如 TPS=60, FPS=144)

---

## 💡 记住

| 记住 | 说明 |
|------|------|
| "FPS ≠ TPS" | 两种独立的循环 |
| "物理代码 → _physics_process" | 保持一致性 |
| "move_and_slide 自动用 delta" | 不要手动乘 |
| "低帧率时 physics 会补调用" | 维持物理稳定性 |
| "delta 单位是秒" | 0.016 = 1/60 秒 |

---

## 🐛 常见错误

### 错误 1: 混淆"帧"

❌ 之前我说"每帧调用一次" → 容易误导  
✅ 应该说"每物理帧调用一次" → 与渲染帧区分

### 错误 2: 把动画放在 _process, 物理放在 _physics_process

```gdscript
# ⚠️ 可能导致不同步
func _physics_process(delta):
    velocity = direction * speed
    move_and_slide()

func _process(delta):
    anim_player.play("walk")  # 可能比物理状态更新慢
```

✅ 推荐: 如果动画基于速度/物理状态,放同一个函数

### 错误 3: 物理代码手动乘 delta

```gdscript
# ❌ 错误: move_and_slide 会自动处理
velocity = direction * speed * delta
move_and_slide()
```

---

## 🔢 节点执行顺序

### 树序（Tree Order）

同一类型的回调（如 `_physics_process`），**按场景树的深度优先、先序遍历**执行：

```
场景树:
  Root
  ├── Player
  │   ├── Skin
  │   │   └── AnimationPlayer
  │   └── StateMachine
  │       └── Ground
  └── Enemy
      └── StateMachine

_physics_process 执行顺序:
  1. Root._physics_process()
  2. Player._physics_process()        ← 父节点先执行
  3. Skin._physics_process()          ← 子节点后执行
  4. AnimationPlayer._physics_process()
  5. StateMachine._physics_process()
  6. Ground._physics_process()
  7. Enemy._physics_process()
  8. Enemy/StateMachine._physics_process()
```

**关键规则**：
- **父节点先于子节点**执行同类型回调
- **同级节点按场景树中的顺序**（先添加的先执行）
- 可通过 `process_priority` 属性覆盖（数值小的先执行）
- 也可通过 `process_physics_order` 设置为 `PARENT_FIRST`（默认）或 `PARENT_LAST`

### 一帧内的完整执行顺序

```
┌─ 物理帧 (Physics Tick, 固定 60 TPS) ─────────────────────┐
│                                                            │
│  ① _input(event)          ← 所有节点（树序）              │
│  ② _shortcut_input(event) ← 所有节点（树序）              │
│  ③ _unhandled_input(event)← 所有节点（树序）              │
│  ④ _physics_process(delta) ← 所有节点（树序）             │
│  ⑤ 物理引擎步进             ← 碰撞检测、Area2D 信号触发    │
│  ⑥ _process(delta)         ← 所有节点（树序）             │
│                                                            │
└────────────────────────────────────────────────────────────┘
         ↓
┌─ 渲染帧 (Render Frame, 随 FPS) ──────────────────────────┐
│                                                            │
│  ⑦ 渲染                                                    │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

**注意**：一个渲染帧内可能包含多个物理帧（低帧率时），也可能 0 个物理帧（高帧率时）。

### 对项目的影响（高度层系统）

```
同一物理帧内：

① QuiverCharacter._physics_process()     ← 父节点先
   - 读取 _skin.base_height（计算属性）/ physical_height / attack_heights
   - 计算高度层 → 更新 collision layer

② Skin.AnimationPlayer._process()        ← 子节点后
   - value track 更新 physical_height / attack_heights

③ JumpMidAir._physics_process()          ← 更深的子节点
   - _move_and_apply_gravity() 更新 _skin.position.y
```

**结果**：collision layer 更新总是**滞后 1 帧**读取上一帧的动画数据。这是可接受的（16.67ms 远低于人类感知阈值 50-100ms）。

---

## 📡 信号（Signal）执行顺序

### 直接 emit（同步）

```gdscript
signal my_signal

func _physics_process(delta):
    my_signal.emit()  # ← 立即执行所有连接的回调
    print("B")        # ← 回调执行完后才到这里

func _on_my_signal():
    print("A")        # ← 在 emit() 调用处同步执行

# 输出: A, B
```

**信号回调在 `emit()` 的位置同步执行**，就像直接调用函数一样。

### 延迟 emit（call_deferred）

```gdscript
func _physics_process(delta):
    my_signal.emit.call_deferred()  # ← 推迟到帧末
    print("B")

func _on_my_signal():
    print("A")

# 输出: B, A
```

### 多个回调的连接顺序

同一个信号连接了多个回调时，**按连接顺序执行**：

```gdscript
my_signal.connect(callback_a)  # 先连接
my_signal.connect(callback_b)  # 后连接

my_signal.emit()
# 执行顺序: callback_a → callback_b
```

### Area2D 信号的特殊性

`area_entered` / `body_entered` 等物理信号**不是立即触发的**：

```
物理帧流程：
  ④ _physics_process()  ← 所有节点执行 move_and_slide()
  ⑤ 物理引擎步进        ← 碰撞检测在这里发生
     ↓
     area_entered 信号触发  ← 在 _physics_process 之后
     ↓
     _on_area_entered() 回调执行
```

**这意味着**：
- `_on_area_entered()` 在物理引擎步进后触发
- 回调内的代码（如 `CombatSystem.apply_damage()`）在**当前物理帧的末尾**执行
- 伤害结果要到**下一帧**的 `_physics_process` 才能被状态机感知

### 完整的一帧时序（项目实例）

```
物理帧 N:
  ① Input: 玩家按 J 键
  ② _unhandled_input(): Idle 状态接收 → transition_to("Ground/Combo1")
   ③ _physics_process():
      a. QuiverCharacter: 读取 Skin 的 base_height（计算属性）/physical_height → 更新 collision layer
      b. AnimationPlayer: value track 更新 Skin.physical_height
      c. Combo1 状态: 设置 HitBox 为 active
  ④ 物理引擎步进:
     - Player HitBox 与 Enemy HurtBox 形状重叠检测
     - area_entered 信号触发
     - HurtBox._on_area_entered() → _handle_hit_box()
       → are_factions_equal() 检查
       → CombatSystem.apply_damage()
       → CombatSystem.apply_knockback()

物理帧 N+1:
  ③ _physics_process():
     a. QuiverCharacter: 读取新的碰撞层数据
     b. Enemy 状态机: 检测到 hurt_requested 信号 → transition_to("Hurt")
```

---

## 📖 参考链接

- [Godot 官方: Idle and Physics Processing](https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html)
- [Godot 官方: Physics Introduction](https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html)
- [Godot 官方: Physics Interpolation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_introduction.html)
- [GDQuest: Process Function Glossary](https://school.gdquest.com/glossary/function_process)

---

## 🎓 总结

| 函数 | 频率 | delta 稳定性 | 用途 |
|------|------|-------------|------|
| `_process` | 随 FPS 变化 | ❌ 不稳定 | 视觉、UI、非物理 |
| `_physics_process` | 固定 TPS (默认60) | ✅ 稳定 | 物理、移动、碰撞 |

**核心原则**:
- 物理相关代码 → `_physics_process`
- 纯视觉代码 → `_process`
- 两者都涉及 → 放 `_physics_process` (优先物理正确性)

---

*这是 ARPG 开发必须掌握的核心机制。后续设计战斗、移动、物理交互时会反复用到。*
