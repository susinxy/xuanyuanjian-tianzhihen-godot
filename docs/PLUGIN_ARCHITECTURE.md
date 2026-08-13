# Quiver Beat-em-up 插件架构源码分析

> **分析日期**: 2026-08-11
> **最后更新**: 2026-08-13
> **插件版本**: 1.0 (quiver_beat_em_up_plugin.gd) + 高度层系统修改
> **用途**: 记录插件所有系统的设计、实现细节和使用方式

---

## 1. 插件目录总览

```
quiver.beat_em_up/
├── characters/                    # 角色基础类 + 动作状态机 + AI 状态机
│   ├── quiver_attributes.gd       # 角色数据 Resource（HP、速度、击退等）
│   ├── quiver_character.gd        # 角色基类（CharacterBody2D）
│   ├── quiver_character_base.tscn # 角色基础场景（继承用）
│   ├── quiver_enemy_character.gd  # 敌人基类（继承 QuiverCharacter，增加 AI 状态机引用）
│   ├── quiver_character_skin.gd   # 皮肤基类（信号、朝向、抓取配置）
│   ├── quiver_character_skin_anim_tree.gd  # AnimationTree 版皮肤（BlendSpace1D）
│   ├── quiver_character_skin_base.tscn     # 皮肤基础场景
│   ├── action_states/            # 所有动作状态脚本
│   │   ├── quiver_character_action.gd  # 动作状态基类（提供 _character, _skin, _attributes）
│   │   ├── quiver_action_ground.gd     # 地面状态基类（连接 hurt/knockout/grab 信号）
│   │   ├── quiver_action_air.gd        # 空中状态基类（重力、落地判定）
│   │   ├── quiver_action_attack.gd     # 攻击状态基类（连击、输入窗口、冲刺）
│   │   ├── quiver_action_die.gd        # 死亡状态基类（玩家发 Events.player_died，敌人 queue_free）
│   │   ├── quiver_action_die_ai.gd     # AI 敌人死亡状态
│   │   └── (子目录: ground_actions/, air_actions/)
│   └── ai/                       # AI 行为状态机
│       ├── quiver_ai_state_machine.gd  # AI 状态机核心
│       └── states/               # 所有 AI 行为状态
│
├── combat/                       # 战斗系统
│   ├── quiver_attack_data.gd     # 攻击数据 Resource（伤害、击退、发射向量）
│   ├── quiver_knockback_data.gd  # 击退数据包（RefCounted，瞬态数据）
│   └── collision_areas/          # 战斗 Area2D 类
│       ├── quiver_collision_types.gd  # 碰撞层预设系统（自动配置 layer/mask/monitoring）
│       ├── quiver_hit_box.gd     # 攻击判定框（被动，monitoring=false）
│       ├── quiver_hurt_box.gd    # 受击判定框（主动，monitoring=true，监听 area_entered）
│       ├── quiver_grab_box.gd    # 抓取判定框
│       └── quiver_wall_hit_box.gd # 墙面反弹判定框
│
└── utilities/                    # 工具节点 + 全局单例
    ├── custom_nodes/
    │   ├── state_machines/       # 通用状态机框架（QuiverStateMachine, QuiverState）
    │   ├── quiver_fight_room.gd  # 战斗区域摄像头锁定
    │   ├── quiver_fence.gd       #  Fence 装饰物
    │   ├── quiver_player_detector.gd  # 玩家触发器（锁定摄像头 + 刷怪）
    │   └── enemy_spawner/        # 敌人波次生成
    └── helpers/autoload/         # 全局单例
        ├── quiver_combat_system.gd      # CombatSystem（apply_damage/apply_knockback）
        ├── quiver_events.gd             # Events 全局事件总线
        ├── hit_freeze/                  # 命中冻结效果
        ├── background_loader/           # 异步资源加载
        ├── debug_logger/                # QuiverDebugLogger
        └── transitions/                 # ScreenTransitions

---

## 2. QuiverCharacter 角色基类

**文件**: `characters/quiver_character.gd`
**类名**: `QuiverCharacter`
**继承**: `CharacterBody2D`（`@tool`）

### 关键职责

角色脚本**只负责**：
1. 编辑器模式下禁用所有处理
2. 运行时 `attributes.reset()`（HP 从满血开始）
3. `add_to_group("player")`（敌人 AI 通过分组查找玩家）
4. F6 独立运行时加调试相机

**所有 gameplay 代码（移动、攻击、受击、跳跃）都在 StateMachine 的 action states 里，不在角色脚本里。**

### 关键属性

```gdscript
var attributes: QuiverAttributes = null  # 角色数据（HP、速度等）
var is_on_air := false                   # 空中状态

# 高度层系统（方案 C：数据在 Skin，碰撞层计算在 Character）
var _cached_height_layers: Array[int] = []  # 高度层缓存（逐元素比较优化）
var _hurtbox: QuiverHurtBox                 # 缓存的 HurtBox 引用
var _hitboxes: Array[QuiverHitBox] = []     # 缓存的 HitBox 数组

var _skin: QuiverCharacterSkin           # 皮肤引用（默认 "Skin" 子节点）
var _collision: Node2D                   # 碰撞体引用（默认 "Collision" 子节点）
var _state_machine: QuiverStateMachine   # 动作状态机引用（默认 $StateMachine）
```

### 高度层系统（方案 C）

**设计决策**：高度层属性（`base_height`, `physical_height`, `attack_heights`）存放在 `QuiverCharacterSkin`，而非 `QuiverCharacter`。原因是 AnimationPlayer 位于 Skin 节点下，使用 `.:property` 路径可以直接访问 Skin 属性，避免 `../` 路径导致的 track 解析警告。

**常量 `HEIGHT_LAYER_DEFINITIONS`**（5 个高度层，layer 15-19）:

| Layer | 名称 | 区间 (min, max] |
|-------|------|----------------|
| 15 | height_ground | (0, 30] |
| 16 | height_low_air | (30, 100] |
| 17 | height_mid_air | (100, 200] |
| 18 | height_high_air | (200, 300] |
| 19 | height_very_high | (300, +∞] |

**数据流**:
1. 动画 value track `.:physical_height` 写入 `Skin.physical_height`（只在值变化时添加 keyframe）
2. 动画 value track `.:attack_heights` 写入 `Skin.attack_heights`（只在值变化时添加 keyframe）
3. 动画 method track `.` 调用 `Skin._sync_base_height()`（每帧，`base_height = -position.y`）
4. `QuiverCharacter._physics_process()` 从 `_skin` 读取数据，计算角色占据的高度范围 `[base_height, base_height + physical_height]`
5. 更新 CharacterBody2D collision layer 15-19（逐元素比较，只在变化时更新）
6. HurtBox collision_layer 跟随角色 body layer，collision_mask = 所有高度层并集
7. HitBox collision_layer 根据 `attack_heights` 或 body layer 设置

**QuiverCharacter 关键方法**:
- `_physics_process(delta)`: 触发 `_update_collision_layers()`
- `_update_collision_layers()`: 从 `_skin` 读取数据，逐元素比较 + 更新
- `_calculate_range_layers(min_h, max_h)`: 区间查询
- `_height_to_layers(height)`: 点查询
- `_layers_to_bitmask(layers)`: 编号转 bitmask

**QuiverCharacterSkin 关键方法**:
- `_sync_base_height()`: 动画 method track 每帧调用，`base_height = -position.y`

**`_hurtbox` / `_hitboxes` 引用**:
- Skin 通过 `@export_node_path` + `_runtime_ready()` 填充引用
- QuiverCharacter 在 `_ready()` 中从 `_skin.hurtbox` / `_skin.hitboxes` 缓存引用
- 缓存引用避免每帧遍历 children

### 基类场景结构 (`quiver_character_base.tscn`)

```
QuiverBaseCharacter (CharacterBody2D, collision_mask=12=layer3+4)
  ├─ script: quiver_character.gd
  └─ StateMachine (Node, quiver_state_machine.gd)
```

**重要**: `collision_mask=12`（layers 3+4: screen_limits + ceiling_limits）。继承场景必须设置为 `14`（layers 2+3+4）才能与障碍物碰撞。

### 子类约定

- **玩家**: 继承 `QuiverCharacter`，角色脚本只做初始化
- **敌人**: 继承 `QuiverEnemyCharacter`，增加 `AiStateMachine` 引用，`_ready()` 里 `attributes.duplicate()`（每个敌人独立的 HP）

---

## 3. QuiverCharacterSkin 皮肤系统

**文件**: `characters/quiver_character_skin.gd` → `quiver_character_skin_anim_tree.gd`
**类名**: `QuiverCharacterSkin` → `QuiverCharacterSkinAnimTree`
**继承**: `Node2D`（`@tool`）

### 两层皮肤架构

**基类 `QuiverCharacterSkin`**:
- 信号定义: `skin_animation_finished`, `attack_input_frames_finished`, `attack_movement_started/ended`, `grab_frame_reached`
- 朝向枚举: `SkinDirection { LEFT = -1, RIGHT = 1 }`
- 导出属性: `skin_direction`, `attributes`（自动同步给 tree group）
- 抓取配置: `_path_grab_pivot`, `_path_grabbed_pivot`（Marker2D 引用）
- **高度层属性（方案 C，由 AnimationPlayer track 每帧赋值）**:
  - `@export var base_height: float = 0.0` — 概念跳跃高度（由 `_sync_base_height()` 从 `position.y` 派生）
  - `@export var physical_height: float = 0.0` — 物理身高（由 value track `.:physical_height` 赋值）
  - `@export var attack_heights: Array = []` — 攻击高度偏移（由 value track `.:attack_heights` 赋值，必须 untyped Array）
- 高度层战斗引用（由 `_runtime_ready()` 填充，QuiverCharacter 通过 `_skin.hurtbox` / `_skin.hitboxes` 访问）:
  - `@export_node_path var _path_hurtbox`（默认 `^"AnimatedSprite2D/HurtBox"`）
  - `@export_node_path var _path_hitboxes_container`（默认 `^"Attacks"`）
  - `var hurtbox: QuiverHurtBox`
  - `var hitboxes: Array[QuiverHitBox]`
- 虚函数: `transition_to()`（被子类实现）
- `_sync_base_height()`: 动画 method track 每帧调用，`base_height = -position.y`
- `_runtime_ready()` 填充 HurtBox/HitBox 引用（从配置的 node path 获取）

**子类 `QuiverCharacterSkinAnimTree`**:
- 属性: `_path_animation_tree`（默认 "AnimationTree"）, `_path_playback`（默认 "parameters/StateMachine/playback"）
- `transition_to(anim_state)`: 验证状态存在 → `_playback.travel(anim_state)`
- `_populate_animation_list()`: 递归遍历 AnimationTree 所有 AnimationNode，构建可用状态列表 `_animation_list`
- `_update_blend_directions()`: 把所有 `*_blend_position` 参数设为 `skin_direction`（-1 或 +1），驱动 BlendSpace1D 的 left/right 混合

### AnimationTree 结构约定

```
AnimationNodeBlendTree (tree_root)
  └── StateMachine (AnimationNodeStateMachine)
        ├── idle      → BlendSpace1D { idle_left @ -1, idle_right @ +1 }
        ├── walk      → BlendSpace1D { walk_left @ -1, walk_right @ +1 }
        ├── turn      → BlendSpace1D (转身动画，注意朝向取反)
        ├── attack1   → BlendSpace1D
        ├── hurt_mid  → BlendSpace1D
        ├── hurt_high → BlendSpace1D
        ├── jump, rising, falling, landing    → BlendSpace1D (跳跃链)
        ├── knockout_launch/rising/falling/bounce → BlendSpace1D (击飞链)
        └── die → BlendSpace1D
```

**关键约定**:
- **朝向**: `BlendSpace1D blend_position = -1`（左）, `+1`（右）。由 `_update_blend_directions()` 自动设置
- **转身动画 `turn`**: blend 方向**取反**（`turn_to_left` 在 blend=+1，`turn_to_right` 在 blend=-1），因为转身时角色面朝目标方向
- **所有 BlendSpace1D 命名一致**: `*_left`, `*_right`
- **攻击动画里的回调**: 动画关键帧调用 `end_of_input_frames()`（关闭连击输入窗口）、`start_attack_movement()`（开始冲刺）、`end_of_skin_animation()`（动画结束）

### 基类场景 (`quiver_character_skin_base.tscn`)

```
CharacterSkinBase (Node2D, quiver_character_skin_anim_tree.gd)
  ├─ AnimationPlayer
  └─ AnimationTree (anim_player = ../AnimationPlayer)
```

皮肤场景通常被继承，在继承的基础上添加 `Sprite2D`、`Positions/GrabPivot` 等子节点。

---

## 4. QuiverAttributes 角色数据

**文件**: `characters/quiver_attributes.gd`
**类名**: `QuiverAttributes`
**继承**: `Resource`（`@tool`）

### 数据职责

角色数据 Resource 负责存储所有**数据**，与**行为**（状态机里的代码）分离：

```gdscript
@export_group("Display")
@export var display_name := ""
@export var profile_texture: Texture2D = null
@export var life_bar_gradient := GradientTexture1D.new()

@export_group("Base Stats")
@export var health_max := 100           # 最大 HP（range 0-1, or_greater）
@export var speed_max := 600            # 最大移动速度
@export var air_control := 0.6          # 空中操控系数 (0.0-1.0)
@export var jump_force := -1200         # 起跳力（负数=向上）
@export var hit_lane_offset := 0        # 车道大小偏移

@export_group("Modifiers")
@export var is_invulnerable := false    # 无敌帧（setter 自动 reset_knockback）
@export var has_superarmor := false     # 霸体（setter 自动 reset_knockback）
@export var can_be_grabbed := true      # 可被抓取

var health_current := health_max        # 当前 HP（setter 触发 health_changed 信号）
var knockback_amount := 0               # 累积击退量
var ground_level := 0.0                 # 当前地面高度（Y 坐标）
var character_node: QuiverCharacter     # 关联的角色节点
var grabbed_offset: Marker2D            # 被抓取时的偏移标记
```

### 信号

```gdscript
signal health_changed          # HP 变化
signal health_depleted         # HP 归零
signal hurt_requested(knockback: QuiverKnockbackData)     # 被击中，请求硬直动画
signal knockout_requested(knockback: QuiverKnockbackData)  # 请求击飞
signal wall_bounced            # 撞墙反弹
signal grab_requested(grabbed_character: QuiverAttributes)  # 请求抓取
signal grab_released           # 释放抓取
signal grabbed(ground_level: float)     # 被抓住
signal grab_denied             # 抓取被拒绝（boss 免疫抓取）
```

### 关键方法

```gdscript
func add_knockback(strength: CombatSystem.KnockbackStrength)
func reset_knockback()
func should_knockout() -> bool    # 击退量达到 MEDIUM 或已死亡
func is_alive() -> bool
func get_health_as_percentage() -> float
func reset() -> void              # 重置所有状态（HP、无敌、霸体、可被抓取）
```

### 内部类 `HitLaneLimits`

```gdscript
class HitLaneLimits:
    var upper_limit := 0
    var lower_limit := 0
    func is_value_inside_lane(y_position: float) -> bool
```

用于判定攻击是否在同一个"车道"内（Y 轴上的同一深度平面）。`CombatSystem.is_in_same_lane_as()` 调用此方法。

---

## 5. 动作状态机系统 (Action States)

### 5.1 通用状态机框架

**基类**: `utilities/custom_nodes/state_machines/quiver_state_machine.gd`
**类名**: `QuiverStateMachine`（继承 Node，`@tool`）

```gdscript
signal transitioned(state_path)      # 每次状态切换时发射

@export var initial_state: NodePath  # 初始状态路径
@export var should_process_input := true

var state: QuiverState               # 当前激活的状态
var state_name: NodePath             # 当前状态路径
```

**生命周期委托**:
- `_unhandled_input(event)` → `state.unhandled_input(event)`
- `_process(delta)` → `state.process(delta)`
- `_physics_process(delta)` → `state.physics_process(delta)`

**`transition_to(target, msg={})` 流程**:
1. 验证目标路径存在
2. 获取目标 `QuiverState` 节点
3. `state.exit()`（断开信号，清理）
4. `state = target`
5. `state.enter(msg)`（连接信号，初始化）
6. `transitioned.emit()`

### 5.2 QuiverState 基类

**文件**: `utilities/custom_nodes/state_machines/quiver_state.gd`
**类名**: `QuiverState`（`@tool`，通用，不局限于角色）

```gdscript
signal state_finished                 # 状态完成时发射（用于顺序状态机）

var _incoming_connections: Array      # 编辑器里接的信号快照
var _state_machine: QuiverStateMachine
```

**信号自动管理流程**:
1. `_ready()` → `_register_incoming_connections()`：用 `get_incoming_connections()` 快照所有编辑器里的信号连接 → 立即断开（休眠）
2. `enter(msg)` → `_connect_signals()`：重新连接（激活）
3. `exit()` → `_disconnect_signals()`：断开（休眠）

**关键**: 任何子类的 `_connect_signals()` / `_disconnect_signals()` 必须调 `super()` 才能保持自动管理。

### 5.3 QuiverStateSequence 顺序状态

**文件**: `utilities/custom_nodes/state_machines/quiver_state_sequence.gd`
**类名**: `QuiverStateSequence`（继承 QuiverState）

按子节点顺序执行（场景树里的 child order），每个子状态发射 `state_finished` 后自动进入下一个。全部完成后序列自身发射 `state_finished`。

典型用法（敌人连招）:
```
AttackSequence (QuiverStateSequence)
  ├─ WindUp (蓄力)
  ├─ Swing (伤害判定)
  └─ Recovery (收招)
```

提供 `interrupt_state()` 强制中断整个序列。

### 5.4 QuiverCharacterAction（动作状态基类）

**文件**: `characters/action_states/quiver_character_action.gd`
**类名**: `QuiverCharacterAction`
**继承**: `QuiverState`

为所有动作状态提供:
```gdscript
var _character: QuiverCharacter   # 拥有者角色（owner）
var _skin: QuiverCharacterSkin    # 皮肤引用
var _attributes: QuiverAttributes # 属性数据
```

`_ready()` → `await owner.ready` → `_on_owner_ready()` 赋值这三个引用。

### 5.5 状态层级与委托链

插件使用**层级化状态树**，`enter(msg)` 采用**父级委托**:

```
Ground/Move/Idle/ (QuiverActionMoveIdle)
  └─ enter() 流程:
      1. super()                    # 连接编辑器接的信号
      2. get_parent().enter(msg)    # Move 状态进入
          └─ get_parent().enter(msg)  # Ground 状态进入（连接 hurt/knockout/grab 信号）
      3. _skin.transition_to("idle")
```

**委托链汇总**:

| 状态 | enter() 链 | physics_process() 链 |
|---|---|---|
| Idle | Idle→Move→Ground | Idle(读输入) → Move(apply velocity + move_and_slide) → Ground(track ground_level) |
| Walk | Walk→Move→Ground | Walk(读输入+转身) → Move → Ground |
| Attack (Combo1/2/3) | Attack→Ground | Attack(maybe apply damage during animation) → Ground |
| Hurt | Hurt → explicitly call _ground_state.enter() | — |
| Jump/Impulse | ...→Ground.exit() | Air(gravity + move_and_slide) |

**Exit 调用顺序**：与 enter **完全相反**，`super()` 在**最末**调用。

### 5.6 Ground 状态 (`quiver_action_ground.gd`)

**类名**: `QuiverActionGround`（`@tool`）

**进入**:
- `ground_level` 设为 `msg.ground_level` 或当前 Y
- `is_on_air = false`
- 连接信号：`hurt_requested` → `_on_hurt_requested`，`knockout_requested` → `_on_knockout_requested`，`grabbed` → `_on_grabbed`

**每帧**: 更新 `ground_level = _character.global_position.y`（ground-level 跟随角色移动）

**退出**: `is_on_air = true`

**可配置的状态路径（编辑器里可改）**:
- `_path_hurt`: "Ground/Hurt"
- `_path_knockout`: "Air/Knockout/Launch"
- `_path_grabbed`: "Ground/Grabbed"

### 5.7 Air 状态 (`quiver_action_air.gd`)

**类名**: `QuiverActionAir`（`@tool`）

**关键机制 — 跳跃是视觉错觉**:
- 角色 Body（CharacterBody2D）在 2D 平面上移动
- Skin（Node2D）在局部坐标系里上下移动，制造"跳跃"错觉
- `_skin_velocity_y` 控制皮肤 Y 速度
- `_gravity` + `_fall_modifier`（下落阶段加速，手感更脆）

**落地判定**: `_has_reached_ground()`: `_skin.position.y >= 0`

### 5.8 Attack 状态 (`quiver_action_attack.gd`)

**类名**: `QuiverActionAttack`（`@tool`）

**连击输入窗口**:
1. 进入 attack → 播放攻击动画 → **输入窗口开启**
2. 监听 `attack` 输入 → 设置 `_should_combo = true`
3. 动画帧调用 `_skin.end_of_input_frames()` → **输入窗口关闭**，发射 `attack_input_frames_finished`
4. `_on_attack_input_frames_finished()`: 若 `_should_combo` 为 true → 切换到下一个 combo 状态，否则返回 idle

**冲刺机制**: 攻击动画可以调用 `_skin.start_attack_movement(direction, speed)` → 角色在攻击时冲刺（如冲刺猛击）。

**关键信号**:
- `attack_input_frames_finished` — 连击输入窗口关闭
- `attack_movement_started` / `ended` — 冲刺开始/结束
- `skin_animation_finished` — 攻击动画完成 → 转到 idle

### 5.9 Hurt 状态 (`quiver_action_hurt.gd`)

**类名**: `QuiverActionGroundHurt`（`@tool`）

硬直动画播放后返回 idle。支持两种硬直类型（HIGH 和 MID），通过 `_skin_state_high` / `_skin_state_mid` 配置。

---

## 6. AI 状态机系统 (`characters/ai/`)

### 6.1 QuiverAiStateMachine（AI 状态机核心）

**类名**: `QuiverAiStateMachine`
**继承**: `QuiverStateMachine`（`@tool`）

```gdscript
@export var disabled: bool            # 全局禁用/启用 AI 决策
var character_attributes: QuiverAttributes  # 自动连接 hurt/knockout/grab 信号

# 受击时的 AI 状态（默认 "WaitForIdle"）
var _ai_state_hurt: String = "WaitForIdle"
# 站起来之后的 AI 状态（默认 "Wait"）
var _ai_state_after_reset: String = "Wait"
var _state_to_resume: NodePath        # 被中断前正在干嘛的状态（用于恢复）
```

**`_decide_next_behavior(last_state)` — 虚函数，子类必须实现**:
- 任何子 AI 状态发 `state_finished` → `_decide_next_behavior` 被调用 → 子类决定下一个状态

**伤害中断流程**:
1. 角色 `hurt_requested` → `_interrupt_current_state()` → 保存 `_state_to_resume` → 转到 `_ai_state_hurt`
2. 角色 `knockout_requested` → `_ai_reset()` → 转到 `_ai_state_after_reset`
3. 中断后 `_state_to_resume` 里存着被打之前的状态，下次可以继续

### 6.2 内置 AI 行为状态

**文件**: `characters/ai/states/`
**基类**: `QuiverAiState`（继承 QuiverState）

所有 AI 状态都通过 `_character`（拥有者）、`_actions`（角色的动作状态机）引用与角色交互。

| 状态 | 职责 | 关键属性 |
|---|---|---|
| **Wait** | 等待 N 秒 | `_wait_time`（固定）或 `_min_wait/_max_wait`（随机） |
| **WaitForState** | 等待角色状态变为某个值 | `_path_ready_state`（默认 "Ground/Move/Idle"），用于受击恢复 |
| **ChaseClosestPlayer** | 追踪最近玩家 | `max_chase_time`, `_path_follow_state`（默认 "Ground/Move/Follow"） |
| **AlignToClosestPlayer** | Y 轴对齐到玩家 | 继承 ChaseClosestPlayer，只对齐 Y（车道） |
| **CallAction** | 触发一个非攻击动作 | `_state_path`（动作状态路径）, `_message` |
| **CallAttack** | 触发连击序列 | `_combo_hits_amount`, `_attack_state_path`, `_fallback_state_path` |
| **GoToPosition** | 移动到指定位置 | `_path_follow_state`, `_fallback_position`, `_fallback_node_path` |
| **GoToClosestPosition** | 移动到候选位置中最近的一个 | 继承 GoToPosition，加 `pool_positions/pool_nodes` |
| **ChooseRandomBehavior** | 随机选择一个行为 | `_use_weights`（加权随机）, `_allow_repeated` |
| **StateGroup** | 状态分组（仅组织用，不是状态） | 无状态逻辑，仅用于 `_connect_child_ai_states` 递归进入 |
| **StateSequence** | 顺序执行多个状态 | 子节点按顺序执行，每个发 `state_finished` 后进入下一个 |

### 6.3 典型 AI 行为链（sarge_ai.gd 示例）

```gdscript
func _decide_next_behavior(last_state: StringName):
    match last_state:
        "Wait":        transition_to("Chase")
        "Chase":       transition_to("Attack")
        "Attack":      transition_to("Wait")
        "WaitForIdle": transition_to(_state_to_resume)  # 受击恢复
        "GoToPosition":transition_to("Wait")
```

**典型循环**: Wait → Chase → Attack → Wait → ...

---

## 7. 战斗系统

### 7.1 CombatSystem（全局单例）

**文件**: `utilities/helpers/autoload/quiver_combat_system.gd`
**全局变量名**: `CombatSystem`

```gdscript
enum CharacterTypes { PLAYERS, ENEMIES, BOUNCE_OBSTACLE }
enum HurtTypes { MID, HIGH }
enum KnockbackStrength { NONE, WEAK, MEDIUM, STRONG, MASSIVE }

func is_in_same_lane_as(defender, attacker) -> bool
func apply_damage(attack: QuiverAttackData, target: QuiverAttributes)
func apply_knockback(knockback: QuiverKnockbackData, target: QuiverAttributes)
```

**攻击流程**:
1. `apply_damage` → 扣血 → 触发 `HitFreeze`（命中的顿感）
2. `apply_knockback` → 累积击退量
3. 若击退量达到上限（≥MEDIUM 或已死亡）→ `knockout_requested` 信号
4. 若未达到上限且无霸体 → `hurt_requested` 信号

### 7.2 QuiverCollisionTypes 碰撞层预设

**文件**: `combat/collision_areas/quiver_collision_types.gd`

**核心机制**: 通过 `metadata/collision_type` 字符串在编辑器里配置 Area2D 的碰撞类型，插件自动设置 layer/mask/monitoring/monitorable。

| 预设 | Layer | Mask | monitoring | monitorable | 用途 |
|---|---|---|---|---|---|
| `player_hit_box` | 9 (256) | 0 | false | true | 玩家攻击区域 |
| `player_hurt_box` | 13 (4096) | 256+1024 (layers 10,12) | true | false | 玩家受击区域 |
| `player_grab_box` | 11 (1024) | 0 | false | true | 玩家抓取区域 |
| `enemy_hit_box` | 10 (512) | 0 | false | true | 敌人攻击区域 |
| `enemy_hurt_box` | 14 (8192) | 256+1024 (layers 9,11) | true | false | 敌人受击区域 |
| `enemy_grab_box` | 12 (2048) | 0 | false | true | 敌人抓取区域 |
| `world_hit_box` | 8 (128) | 0 | false | true | 反弹墙 |
| `default` | 1 | 1 | true | true | 角色 Body 碰撞 |

### 7.3 QuiverHitBox（攻击判定框）

**文件**: `combat/collision_areas/quiver_hit_box.gd`
**类名**: `QuiverHitBox`（Area2D，被动监听者）

**被动**: `monitoring=false, monitorable=true`
- 不主动扫描任何东西
- 只是承载 `character_attributes` 和 `attack_data`，等对方 HurtBox 来"捡"

### 7.4 QuiverHurtBox（受击判定框）

**文件**: `combat/collision_areas/quiver_hurt_box.gd`
**类名**: `QuiverHurtBox`（Area2D，主动监听者）

**主动**: `monitoring=true, monitorable=false`，mask 对应敌人的 hit/grab 层。

**`_on_area_entered()` 分发**:

| 进入的 Area | 方法 | 后续 |
|---|---|---|
| `QuiverHitBox` | `_handle_hit_box()` | `apply_damage` + `apply_knockback` |
| `QuiverGrabBox` | `_handle_grab_box()` | `grab_requested` 信号 |
| `WallHitBox` | `_handle_wall_hit_box()` | `wall_bounced` 信号 |

**`_handle_hit_box()` 完整流程**:
1. **阵营检查** `are_factions_equal(hit_box, self)`：同阵营直接 return（`area2d:` group 前缀匹配）
2. `_can_be_attacked_by(hit_box)` 检查：非无敌 + 同一车道
3. `CombatSystem.apply_damage(hit_box.attack_data, character_attributes)`
4. 构造 `QuiverKnockbackData`（包含 treated launch_vector：根据攻击方向翻转，让角色**始终向后飞**）
5. `CombatSystem.apply_knockback(knockback_data, character_attributes)`
6. 发射 `Events.enemy_data_sent`（攻击者=玩家时，用于 HUD 显示）

**阵营过滤机制**（`area2d:` group）:
- 常量 `FACTION_PREFIX = "area2d:"`
- 静态函数 `are_factions_equal(hit_box, hurt_box)`：遍历 hit_box 的 groups，找到 `area2d:` 前缀的 group，检查 hurt_box 是否也在同一 group
- 同阵营双方的 HitBox/HurtBox 不会互相造成伤害/抓取
- 配置方式：在 .tscn 中为角色的所有战斗 Area2D 添加 `groups = ["area2d:角色名"]`
- `_handle_grab_box()` 同样使用此检查

### 7.5 QuiverAttackData（攻击数据）

**文件**: `combat/quiver_attack_data.gd`
**类名**: `QuiverAttackData`（Resource，`@tool`）

```gdscript
@export var attack_damage: int          # 基础伤害
@export var hurt_type: CombatSystem.HurtTypes     # HIGH 或 MID（硬直动画类型）
@export var knockback: CombatSystem.KnockbackStrength  # 击退强度
@export var launch_angle: float         # 发射角度（degree, 0-360）
var launch_vector: Vector2              # 自动从角度计算
```

每次修改 `launch_angle`，setter 自动计算 `launch_vector`。

### 7.6 QuiverKnockbackData

**文件**: `combat/quiver_knockback_data.gd`
**类名**: `QuiverKnockbackData`（RefCounted，瞬态数据，不持久化）

```gdscript
var strength: CombatSystem.KnockbackStrength
var hurt_type: CombatSystem.HurtTypes
var launch_vector: Vector2
```

### 7.7 完整战斗流程（玩家攻击敌人）

```
玩家按 J 键
  ↓
Idle.unhandled_input() → Move.attack() → transition_to("Ground/Combo1")
  ↓
Combo1.enter() → _skin.transition_to("attack1") → 播放攻击动画
  ↓
动画关键帧：攻击动画中某帧激活 HitBox.monitoring=true（通过动画 call_method track）
  ↓
Player HitBox (layer 9, monitoring=true, 携带 attack_data)
  进入敌人 HurtBox (layer 14, monitoring=true, mask=256+1024)
  ↓
HurtBox._on_area_entered() → _handle_hit_box()
  ↓
CombatSystem.apply_damage() → HP 扣减 → HitFreeze（顿感）
CombatSystem.apply_knockback() → 累积击退 → hurt_requested 或 knockout_requested
  ↓
地面状态 QuiverActionGround 收到 signal:
  hurt_requested  → transition_to("Ground/Hurt")
  knockout_requested → transition_to("Air/Knockout/Launch")
  ↓
敌人死亡（HP=0）:
  Die.enter() → _skin.transition_to("die")
  Die._on_animation_finished():
    玩家 → Events.player_died.emit()（HUD 监听，显示 Game Over）
    敌人 → _character.queue_free()（场景里移除）
```

---

## 8. Stage 场景工具节点

### 8.1 QuiverFightRoom（战斗区域摄像头锁定）

**文件**: `utilities/custom_nodes/quiver_fight_room.gd`
**类名**: `QuiverFightRoom`（继承 ReferenceRect，`@tool`）

**职责**: 定义战斗区域的摄像头边界，在战斗开始时锁定摄像头到此区域，战斗结束后解锁或切换到"战后"区域。

```gdscript
# 战斗区域边界（编辑器可视化）
@export var limit_left, limit_top, limit_right, limit_bottom: int
@export var zoom: float = 1.0          # 战斗区域的缩放
@export var transition_duration: float = 0.8  # 摄像头过渡动画时长

# 战后区域（可选，战斗结束后切换到此区域）
@export var after_fight_limit_*, after_fight_zoom, after_fight_transition_duration
@export var after_fight_use_new_room: bool

func setup_fight_room()       # 战斗开始 → 锁定摄像头
func setup_after_fight_room() # 战斗结束 → 切换到战后区域
```

内部调用 `_level_camera.delimitate_room(left, top, right, bottom, zoom, duration)`。

### 8.2 QuiverPlayerDetector（玩家触发器）

**文件**: `utilities/custom_nodes/quiver_player_detector.gd`
**类名**: `QuiverPlayerDetector`（Area2D，`@tool`）

```gdscript
@export var is_one_shot := true        # 一次性触发（触发后 queue_free 自身）
@export var path_fight_room: NodePath  # 指向 FightRoom
@export var paths_enemy_spawners: Array[NodePath]  # 指向 EnemySpawner 列表

signal player_detected              # 玩家进入区域时发射
```

**`_ready()` 自动连接**:
- `player_detected` → `fight_room.setup_fight_room()`
- `player_detected` → 每个 `enemy_spawner.spawn_current_wave()`

**`_on_body_entered(body)`**: 若 body 在 "players" 分组 → 发射 `player_detected`。

### 8.3 QuiverEnemySpawner（敌人波次生成）

**文件**: `utilities/custom_nodes/enemy_spawner/quiver_enemy_spawner.gd`
**类名**: `QuiverEnemySpawner`（Marker2D，`@tool`）

```gdscript
signal wave_started(index)         # 一波开始
signal wave_ended(index)           # 一波结束
signal all_waves_completed         # 所有波次完成

@export var path_spawn_parent: NodePath = "../../Characters"  # 敌人放到哪里

var _spawn_waves: Array            # Array[Array[QuiverSpawnData]]
```

**`QuiverSpawnData`**（Resource）:
```gdscript
enum SpawnMode { WALK_TO_POSITION, IN_PLACE }
@export var enemy_scene: PackedScene
@export var spawn_mode: SpawnMode
@export var target_node_path: NodePath  # 目标位置（Marker2D）
@export var target_position: Vector2    # 或使用 Vector2
```

`WALK_TO_POSITION`: 在 spawner 位置生成，然后调用 `spawn_ground_to_position()` 走向目标。
`IN_PLACE`: 直接在目标位置生成。

### 8.4 QuiverLevelCamera（游戏摄像机）

**文件**: `utilities/custom_nodes/level_camera/quiver_level_camera.gd`
**类名**: `QuiverLevelCamera`（继承 Camera2D）

**两个核心职责**:
1. **屏幕边缘碰撞墙**: 每帧更新两个 CollisionShape2D（角色无法走出屏幕边缘）
2. **`delimitate_room()`**: 平滑过渡摄像头边界到指定区域（用 Tween）

```gdscript
func delimitate_room(p_limit_left, p_limit_top, p_limit_right, p_limit_bottom, p_zoom, p_duration):
    # Tween 过渡到战斗区域边界
```

---

## 9. 全局事件总线 (Events)

**文件**: `utilities/helpers/autoload/quiver_events.gd`
**全局变量名**: `Events`

```gdscript
signal characters_reseted       # 角色重置（重载场景时）
signal enemy_data_sent(enemy: QuiverAttributes, player: QuiverAttributes)  # 玩家打中敌人（用于 HUD）
signal enemy_defeated           # 敌人被击败
signal player_died              # 玩家死亡
```

`Events` 是全局单例，任何脚本都可以 `Events.player_died.connect(my_handler)`，无需节点引用。

---

## 10. 其他全局单例

| 名称 | 职责 |
|---|---|
| `CombatSystem` | 战斗判定权威（apply_damage/apply_knockback） |
| `Events` | 全局事件总线 |
| `BackgroundLoader` | 异步资源/场景加载 |
| `ScreenTransitions` | 屏幕过渡动画（Shader 遮罩） |
| `HitFreeze` | 命中暂停效果（提升打击感） |
| `QuiverDebugLogger` | 调试日志（可在 project settings 里开关） |

---

## 11. 项目设置 (project.godot `[quiver]` 部分)

```ini
quiver/beat_em_up/gameplay/default_hit_lane_size = 60    # 车道大小（Y 轴像素）
quiver/beat_em_up/gameplay/fall_gravity_modifier = 2.5   # 下落阶段重力倍率
quiver/beat_em_up/debug/logging_enabled = true           # 调试日志开关
quiver/beat_em_up/debug/disable_player_detector_on_editor = false
quiver/beat_em_up/paths/custom_actions_folder = "res://_beat_em_up/action_states/"
quiver/beat_em_up/paths/custom_ai_folder = "res://_beat_em_up/ai_states/"
```

---

## 12. 自定义 Action State 开发指南

### 何时需要自定义 Action State?

- 需要完全不同于内置 Attack/Hurt/Die 的行为逻辑
- 需要 boss 特殊技能（如 dash attack、area attack）
- 需要自定义的 knockdown 动画

### 开发规范

1. 放在 `xuanyuan-sword/_beat_em_up/action_states/` 目录
2. 继承 `QuiverCharacterAction`（最灵活）或具体子类如 `QuiverActionAttack`
3. `@tool` 标记，确保可在编辑器预览
4. `_connect_signals()` / `_disconnect_signals()` 必须调 `super()`
5. 若父状态是 `QuiverActionGround`，必须**手动调用** `get_parent().enter(msg)` / `get_parent().exit()`

### 示例：tax_man 的 dash_attack_action.gd

```gdscript
@tool
extends QuiverCharacterAction  # 直接继承基类（不用 QuiverActionAttack）

var _dash_skin_state := &"attack_dash_begin"
var _attack_skin_state := &"attack_dash_end"
var _path_next_state := "Ground/Move/IdleAi"

func enter(msg):
    get_parent().enter(msg)  # 手动激活 Ground 父状态（连接 hurt/knockout 信号）
    super(msg)
    _skin.transition_to(_dash_skin_state)

func physics_process(delta):
    # 冲刺移动：direction * speed → move_and_slide()
    ...

func _connect_signals():
    get_parent()._connect_signals()  # 继承 Ground 的信号
    super()                          # 继承 CharacterAction 的信号
    _skin.dash_attack_succeeded.connect(_on_skin_dash_attack_succeeded)
    _skin.skin_animation_finished.connect(_on_skin_animation_finished)
```

---

## 13. 关键信号汇总

### QuiverCharacterSkin 信号

| 信号 | 由谁发射 | 什么时候 |
|---|---|---|
| `skin_animation_finished` | 皮肤（动画结束帧调用 `end_of_skin_animation()`） | 任何动画播放完毕 |
| `attack_input_frames_finished` | 皮肤（动画中调用 `end_of_input_frames()`） | 攻击"输入窗口"关闭 |
| `attack_movement_started(direction, speed)` | 皮肤（动画中调用 `start_attack_movement()`） | 冲刺攻击开始 |
| `attack_movement_ended` | 皮肤（动画中调用 `stop_attack_movement()`） | 冲刺攻击结束 |
| `grab_frame_reached(marker)` | 皮肤（动画中调用 `grab_notify()`） | 抓取动画中的"命中帧" |

### QuiverAttributes 信号（由 CombatSystem 和状态机共同操纵）

| 信号 | 触发条件 |
|---|---|
| `health_changed` | HP 变化 |
| `health_depleted` | HP 归零 |
| `hurt_requested(knockback_data)` | 被击中且未达到击飞阈值 |
| `knockout_requested(knockback_data)` | 被击中且达到击飞阈值 |
| `grab_requested(grabbed_character)` | 想抓住某人 |
| `grab_released` | 释放抓取 |
| `grabbed(ground_level)` | 被抓住 |
| `grab_denied` | 抓取被拒绝（boss） |
| `wall_bounced` | 撞墙反弹 |

## 14. 自定义 Inspector 插件 (`custom_inspectors/`)

插件通过 `EditorInspectorPlugin` 子类在编辑器 Inspector 面板注入自定义 UI。由主插件 `quiver_beat_em_up_plugin.gd` 在 `_enter_tree()` 时扫描 `PATH_CUSTOM_INSPECTORS` 目录自动加载。

### 加载机制

每个 Inspector 子目录必须包含 `inspector_plugin.gd` 文件（继承 `EditorInspectorPlugin`）：

```gdscript
extends EditorInspectorPlugin

func _can_handle(object) -> bool:
    return object is SomeSpecificClass  # 判断是否在 Inspector 显示

func _parse_begin(object: Object) -> void:
    var widget = SCENE_WIDGET.instantiate()
    add_custom_control(widget)
```

主插件通过 `add_inspector_plugin(custom_inspector)` 注册，退出时通过 `remove_inspector_plugin()` 清理。

### 已实现的 Inspector 插件

| 目录 | 激活条件 | 功能 |
|---|---|---|
| `create_new_action/` | `QuiverStateMachine` / `QuiverState` 节点（属于 `QuiverCharacter` 的） | 从列表中选择 action state 添加到状态机 |
| `create_new_ai_state/` | `QuiverAiStateMachine` / `QuiverAiState` 节点 | 创建新的 AI 行为状态 |
| `create_mirrored_animation/` | 动画节点 | 创建镜像动画（left/right） |
| `states_dropdown/` | `QuiverActionAttack` 等需要选择其他状态的脚本 | 提供状态下拉列表 |
| `ai_states_dropdown/` | AI 状态脚本 | 提供 AI 状态下拉列表 |
| `external_enum/` | 需要选择脚本内枚举的字段 | 解析外部枚举提供下拉 |
| `collision_shape_types/` | Area2D 的 `collision_type` 元数据字段 | 提供碰撞预设下拉 |
| **`create_new_character/`** | **`CharacterTemplate` 节点**（`characters/playable/_template/character_template.tscn`） | **创建/删除角色** |
| **`height_layers/`** | **`QuiverCharacterSkinAnimTree` 节点** | **扫描动画帧文件名，注入高度层轨道** |

### Height Layers Inspector（新增）

**触发方式**：
1. 打开角色皮肤场景（如 `chen_jingchou_skin.tscn`）
2. 选中根节点 `ChenJingchouSkin`（QuiverCharacterSkinAnimTree）
3. Inspector 面板显示 "Height Layers Scanner" 区域

**文件结构**：
```
custom_inspectors/height_layers/
├── inspector_plugin.gd              # EditorInspectorPlugin 入口
├── height_layers_widget.gd          # UI 组件（VBoxContainer, @tool）
├── height_layers_widget.tscn        # Widget 场景
├── animation_track_injector.gd      # 轨道注入核心（extends RefCounted）
└── character_height_data.gd         # 帧高度数据解析（extends RefCounted）
```

**工作流程**：
```
用户点击 Scan / Scan (Dry Run)
  ↓
AnimationTrackInjector.run(skin_node, dry_run)
  ↓
1. 从 AnimatedSprite2D 获取 SpriteFrames
2. 从 AnimationPlayer 获取 AnimationLibrary
3. 验证场景树结构（AnimationPlayer 父节点必须是 QuiverCharacterSkin）
4. 解析 SpriteFrames 每帧文件名（physical_Y, attack_Z, speed_X）
5. 对每个 Animation：
   a. 找到引用的 SpriteFrames 子动画名
   b. 移除旧的 height tracks（保留原始 Quiver 方法）
   c. 添加新 tracks（.:physical_height, .:attack_heights, . method）
   d. 逐帧插入 keyframes（value tracks 只在值变化时添加）
   e. 保存 Animation 资源
  ↓
显示结果（成功/失败/错误列表）
```

**轨道路径（方案 C）**：
- `.:physical_height` — value track，写入 Skin.physical_height
- `.:attack_heights` — value track，写入 Skin.attack_heights
- `.` — method track，调用 Skin._sync_base_height()

**关键特性**：
- 保留原始 Quiver 方法（end_of_input_frames, end_of_skin_animation 等）
- value tracks 只在值变化时添加 keyframe（优化冗余数据）
- method track 每帧调用（与动画 FPS 同步）
- 支持增量扫描（异步，不阻塞编辑器）

### Character Creator Inspector（新增）

**触发方式**：
1. 打开 `characters/playable/_template/character_template.tscn`
2. 选中根节点 `CharacterTemplate`
3. Inspector 面板显示 "Create New Character"、"Delete Character" 和 "**Test Character**" 区域

**文件结构**：
```
custom_inspectors/create_new_character/
├── inspector_plugin.gd                 # EditorInspectorPlugin 入口
├── create_new_character_widget.gd      # UI 组件（VBoxContainer, @tool）
├── create_new_character_widget.tscn    # Widget 场景（VBoxContainer 根）
├── character_creator.gd                # 文件创建核心（extends RefCounted）
└── character_deleter.gd                # 文件删除核心（extends RefCounted）
```

**信号流程**：
```
用户点击 Create/Delete
  ↓
Widget 验证输入 / 显示确认对话框
  ↓
CharacterCreator.create_character(char_name, pascal_name, display_name)
  或 CharacterDeleter.delete_character(char_name)
  ↓
发出 character_created / character_deleted 信号
  ↓
InspectorPlugin 调用 EditorInterface.get_resource_filesystem().scan()
  ↓
Widget 监听 filesystem_changed 信号自动刷新角色列表
```

```
用户点击 Test
  ↓
Widget 发出 character_test_requested(char_name)
  ↓
InspectorPlugin 生成 scenes/_test_<char_name>.tscn（使用 .replace() 替换 {{CHAR_PATH}} 和 {{CHAR_NAME}}）
  ↓
调用 EditorInterface.play_custom_scene() 运行测试
  ↓
用户按 F8 退出测试
```

**为什么用 `.replace()` 而不是 `%` 运算符**：生成的测试场景中 `text = "...{{CHAR_NAME}}..."` 需要在 GDScript 里完成替换再写入磁盘。如果写成 `text = "...%s..." % char_name`，在 `.tscn` 文件里会被当成 GDScript 表达式在加载时再求值，但 `char_name` 变量在 `.tscn` 作用域里不存在，导致 `%s` 字面量被保留到 Label 文本中显示。使用 `.replace()` 模式彻底规避这个问题。

**占位符替换**：
- `__NAME__` → 角色英文名（snake_case）
- `__CLASS__` → 类名（PascalCase）
- `__DISPLAY_NAME__` → 中文显示名

**注意**：
- `character_creator.gd` / `character_deleter.gd` 必须有 `@tool` 注解才能在编辑器中运行
- `CharacterCreator` / `CharacterDeleter` 类名使用 `class_name` 声明，可在 Widget 中直接 `CharacterCreator.new()`
- Widget 的 UI 在 `_ready()` 中动态创建（不依赖 .tscn 布局），便于扩展

---

## 15. UID 管理最佳实践

### UID 是什么

Godot 为每个 `.tscn` 文件生成唯一的 `uid://` 标识符（如 `uid://abc123xyz`）。UID 用于：
- 跨文件引用场景资源（比路径更可靠）
- 文件系统快速查找
- 编辑器内部资源管理

### 常见 UID 问题

**问题1：复制 .tscn 文件后忘记更新 UID**

当你复制 `character_template.tscn` 创建新角色时，UID 也会被复制。如果两个文件有相同 UID，Godot 会警告：

```
WARNING: UID duplicate detected between 
  res://characters/playable/_template/character_template.tscn 
  and res://characters/playable/yu_xiaoxue/yu_xiaoxue.tscn
```

**后果**：
- 资源加载时可能指向错误的文件
- 文件系统扫描混乱
- 可能影响依赖 UID 的插件功能

### 解决方案

**方案1：删除 UID（推荐）**

直接移除 `uid="..."` 字段，让 Godot 在下次加载时自动生成新 UID：

```
# 修改前
[gd_scene load_steps=2 format=3 uid="uid://abc123xyz"]

# 修改后
[gd_scene load_steps=2 format=3]
```

**方案2：手动生成新 UID**

如果要保留显式 UID，可以手动生成一个新的（格式：`uid://` + 随机字母数字字符串）：

```
[gd_scene load_steps=2 format=3 uid="uid://def456uvw"]
```

生成工具：https://www.random.org/strings/ 或类似的随机字符串生成器。

### 自动化处理（角色创建工具）

`CharacterCreator` 在创建新角色时会自动移除所有 `.tscn` 和 `.tres` 文件的 UID，让 Godot 自动生成。无需手动操作。

### 检查 UID 重复

```bash
# 查找重复的 UID
grep -r "uid=\"uid://" xuanyuan-sword/ --include="*.tscn" --include="*.tres" | sort | uniq -d

# 查找特定 UID 出现在哪些文件
grep -r "uid://abc123xyz" xuanyuan-sword/ --include="*.tscn" --include="*.tres"
```

### 实际案例

**2026-08-14**: 修复了 Quiver 插件内部两个 `.tscn` 文件的 UID 重复问题。详见 `PLUGIN_CHANGES.md`。

修复前：
- `create_new_action_widget.tscn` 和 `create_new_ai_state_widget.tscn` 共用 `uid://co7qc6m4h7en4`

修复后：
- 移除了 `create_new_ai_state_widget.tscn` 的 UID，Godot 自动生成新 UID
- 编辑器启动警告消失
