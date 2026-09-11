# Quiver Beat-em-up 插件架构源码分析

> **分析日期**: 2026-08-11
> **最后更新**: 2026-08-27
> **插件版本**: 1.0 (quiver_beat_em_up_plugin.gd) + 高度层系统 + 碰撞系统重构 + 轮廓转换工具 + Walk/Run 移动系统
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
│   │   ├── ground_actions/
│   │   │   ├── quiver_action_move.gd       # 地面移动基类（apply velocity + move_and_slide）
│   │   │   └── move_actions/
│   │   │       ├── quiver_action_idle.gd       # Idle 状态（读输入，转到 Walk/Run）
│   │   │       └── quiver_action_locomotion.gd # Walk/Run 通用移动状态（单类，实例配置区分）
│   │   └── (子目录: air_actions/)
│   └── ai/                       # AI 行为状态机
│       ├── quiver_ai_state_machine.gd  # AI 状态机核心
│       └── states/               # 所有 AI 行为状态
│
├── combat/                       # 战斗系统
│   ├── quiver_attack_data.gd     # 攻击数据 Resource（伤害、击退、发射向量）
│   ├── quiver_knockback_data.gd  # 击退数据包（RefCounted，瞬态数据）
│   └── collision_areas/          # 战斗 Area2D 类
│       ├── quiver_wall_hit_box.gd     # 墙壁反弹判定（WallHitBox）
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

**设计决策**：高度层属性（`base_height`, `physical_height`, `physical_width`, `attack_heights`）存放在 `QuiverCharacterSkin`，而非 `QuiverCharacter`。原因是 AnimationPlayer 位于 Skin 节点下，使用 `.:property` 路径可以直接访问 Skin 属性，避免 `../` 路径导致的 track 解析警告。

**配置化 10 层高度系统**（layer 15-24）:

层定义从 `project.godot` 的 `standard_height` 运行时构建：
- `standard_height` (SH)：标准身高（默认 180px）
- 层厚度 = SH × 0.75（默认 135px）
- 每对 `*_low` / `*_high` 层区分标准跳跃能否越过

| Layer | 名称 | 区间 (min, max] | SH=180 时 |
|-------|------|----------------|-----------|
| 15 | height_ground_low | (0, SH×0.75] | (0, 135] |
| 16 | height_ground_high | (SH×0.75, SH×1.5] | (135, 270] |
| 17 | height_low_air_low | (SH×1.5, SH×2.25] | (270, 405] |
| 18 | height_low_air_high | (SH×2.25, SH×3] | (405, 540] |
| 19 | height_mid_air_low | (SH×3, SH×3.75] | (540, 675] |
| 20 | height_mid_air_high | (SH×3.75, SH×4.5] | (675, 810] |
| 21 | height_high_air_low | (SH×4.5, SH×5.25] | (810, 945] |
| 22 | height_high_air_high | (SH×5.25, SH×6] | (945, 1080] |
| 23 | height_very_high_low | (SH×6, SH×6.75] | (1080, 1215] |
| 24 | height_very_high_high | (SH×6.75, +∞] | (1215, +∞] |

**数据流**:
1. 动画 value track `.:physical_height` 写入 `Skin.physical_height`（只在值变化时添加 keyframe）
2. 动画 value track `.:physical_width` 写入 `Skin.physical_width`（只在值变化时添加 keyframe）
3. 动画 value track `.:attack_heights` 写入 `Skin.attack_heights`（只在值变化时添加 keyframe）
4. `Skin.base_height` 是计算属性（getter），从 `position.y` 实时派生：`base_height = -position.y`
5. `QuiverCharacter._physics_process()` 从 `_skin` 读取数据，计算角色占据的高度范围 `[base_height, base_height + physical_height]`
6. `QuiverCharacter._update_collision_layers()` 读取 `_skin.physical_width`，设置物理体碰撞胶囊的 `CapsuleShape2D.height`
7. 更新 CharacterBody2D collision layer 15-24（逐元素比较，只在变化时更新）
8. 同步更新 CharacterBody2D collision_mask（保留 layers 1-14，添加当前高度层）
9. HurtBox collision_layer 跟随角色 body layer，collision_mask = 所有高度层并集
10. HitBox collision_layer 根据 `attack_heights` 或 body layer 设置

**QuiverCharacter 关键方法**:
- `_physics_process(delta)`: 触发 `_update_collision_layers()`
- `_update_collision_layers()`: 从 `_skin` 读取数据，逐元素比较 + 更新 collision_layer 和 collision_mask
- `_update_hurtbox_layers(character_bitmask)`: 使用 masked read-modify-write 更新 HurtBox 的 collision_layer 和 collision_mask（只修改高度层位，保留其他配置）
- `_update_hitbox_layers(base_h, attack_hs, body_bitmask)`: 使用 `_cached_hitbox_height_bits` 缓存，只在目标值变化时执行 masked read-modify-write 更新 HitBox 的 collision_layer（攻击时仅攻击层，非攻击时复位为身体层）
- `_calculate_range_layers(min_h, max_h)`: 区间查询
- `_height_to_layer(height)`: 点查询，返回单个层编号（int）
- `_layers_to_bitmask(layers)`: 编号转 bitmask
- `static func get_all_height_layers_mask() -> int`: 计算全高度层 bitmask（layers 15-24），可在任何地方调用，供 QuiverLevelCamera 等外部组件获取高度层掩码

**QuiverCharacterSkin 关键属性**:
- `base_height`（计算属性）: `get: return -position.y`，无需动画 track 驱动，永远与 `position.y` 同步

**`_hurtbox` / `_hitboxes` 引用**:
- Skin 通过 `@export_node_path` + `_runtime_ready()` 填充引用
- QuiverCharacter 在 `_ready()` 中从 `_skin.hurtbox` / `_skin.hitboxes` 缓存引用
- 缓存引用避免每帧遍历 children

### 基类场景结构 (`quiver_character_base.tscn`)

```
QuiverBaseCharacter (CharacterBody2D)
  ├─ script: quiver_character.gd
  └─ StateMachine (Node, quiver_state_machine.gd)
```

**重要**: 基类场景**显式设置** `collision_layer = 0` 和 `collision_mask = 0`，不使用 Godot 默认值 1。所有碰撞层由运行时 `_update_collision_layers()` 动态管理：
- 高度层 bits (15-24) 根据角色的 `base_height` + `physical_height` 动态设置
- 非高度层 bits (1-14) 保持为 0，不做修改
- 继承场景也不需要手动设置 collision_mask，高度层系统会自动处理

**碰撞检测原则**：所有物理碰撞和 Area2D 检测都通过高度层交集触发，faction group (`area2d:` 前缀) 负责逻辑过滤。不再使用固定的 combat layer (9-14) 区分 player/enemy。

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
- **高度层属性（方案 C）**:
  - `var base_height: float`（计算属性）— 概念跳跃高度，`get: return -position.y`，无需动画 track 驱动
  - `@export var physical_height: float = 0.0` — 物理身高（由 value track `.:physical_height` 赋值）
  - `@export var physical_width: float = 0.0` — 物理宽度（由 value track `.:physical_width` 赋值，QuiverCharacter 读取后设置 CapsuleShape2D.height）
  - `@export var attack_heights: Array = []` — 攻击高度偏移（由 value track `.:attack_heights` 赋值，必须 untyped Array）
- 高度层战斗引用（由 `_runtime_ready()` 填充，QuiverCharacter 通过 `_skin.hurtbox` / `_skin.hitboxes` 访问）:
  - `@export_node_path var _path_hurtbox`（默认 `^"AnimatedSprite2D/HurtBox"`）
  - `@export_node_path var _path_hitboxes_container`（默认 `^"Attacks"`）
  - `var hurtbox: QuiverHurtBox`
  - `var hitboxes: Array[QuiverHitBox]`
- 虚函数: `transition_to()`（被子类实现）
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
@export var mana_max := 100              # 最大法力值（range 0-1, or_greater）
@export var move_speed := 600            # 跑步速度（Run 状态）
@export var walk_speed := 300            # 步行速度（Walk 状态，按住 Shift）
@export var air_control := 0.6          # 空中操控系数 (0.0-1.0)
@export var jump_force := -1200         # 起跳力（负数=向上，由 jump 动画 speed_X 设置）
@export var knockback_weight := 1.0     # 击飞权重（由 knockout 动画 speed_X 设置）
@export var hit_lane_offset := 0        # 车道大小偏移

@export_group("Modifiers")
@export var is_invulnerable := false    # 无敌帧（setter 自动 reset_knockback）
@export var has_superarmor := false     # 霸体（setter 自动 reset_knockback）
@export var can_be_grabbed := true      # 可被抓取

var health_current := health_max        # 当前 HP（setter 触发 health_changed 信号）
var mana_current := mana_max            # 当前法力值（setter 触发 mana_changed 信号）
var knockback_amount := 0               # 累积击退量
var ground_level := 0.0                 # 当前地面高度（Y 坐标）
var character_node: QuiverCharacter     # 关联的角色节点
var grabbed_offset: Marker2D            # 被抓取时的偏移标记
var _modifier_records: Array[Dictionary]  # 活跃的属性修改器记录
```

### 信号

```gdscript
signal health_changed          # HP 变化
signal health_depleted         # HP 归零
signal mana_changed            # 法力值变化
signal mana_depleted           # 法力值归零
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

# Modifier 系统（用于 Buff/Debuff）
func add_modifier(mod_id: StringName, attribute: StringName, type: String, value: float, source: Node = null)
func remove_modifier(mod_id: StringName)
func remove_modifiers_from_source(source: Node)
```

**Modifier 系统说明**：
- `add_modifier()`: 记录 base_value，然后直接修改属性值（type="add" 加法，type="multiply" 乘法）
- `remove_modifier()`: 按 ID 查找并移除，恢复 base_value
- `remove_modifiers_from_source()`: 按来源节点批量移除所有相关 modifier
- 实现方式：方式 B（直接修改属性值，记录 base_value 用于恢复）

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
| Walk (Locomotion, _is_walk_mode=true) | Walk→Move→Ground（enter 加 modifier 降速） | Walk(读输入+转身) → Move → Ground |
| Run (Locomotion, _is_walk_mode=false) | Run→Move→Ground（enter 无 modifier） | Run(读输入+转身) → Move → Ground |
| Attack (Combo1/2/3) | Attack→Ground | Attack(maybe apply damage during animation) → Ground |
| Hurt | Hurt → explicitly call _ground_state.enter() | — |
| Jump/Impulse | ...→Ground.exit() | Air(gravity + move_and_slide) |

**Exit 调用顺序**：与 enter **完全相反**，`super()` 在**最末**调用。

### 5.5.1 Locomotion 状态 (`quiver_action_locomotion.gd`)

**类名**: `QuiverActionLocomotion`（`@tool`）

**文件**: `characters/action_states/ground_actions/move_actions/quiver_action_locomotion.gd`

**设计哲学**: Walk 和 Run 是同一概念的两种表现（地面位移），仅速度和动画不同。使用**单类 + 实例配置**而非继承，避免代码重复。

**状态机结构**:

```
StateMachine
└── Ground
    └── Move (QuiverActionGroundMove)
        ├── Idle (QuiverActionMoveIdle)
        ├── Walk (QuiverActionLocomotion, _is_walk_mode=true, _move_skin_state=&"walk")
        └── Run  (QuiverActionLocomotion, _is_walk_mode=false, _move_skin_state=&"run")
```

**速度控制机制**: 通过 `QuiverAttributes.add_modifier()` 在 enter/exit 时切换速度：

```gdscript
func enter(msg: = {}) -> void:
    _move_state._direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    super(msg)
    _move_state.enter(msg)
    if _is_walk_mode and _attributes.move_speed > 0:
        var multiplier: float = float(_attributes.walk_speed) / float(_attributes.move_speed)
        _attributes.add_modifier(&"locomotion_speed", &"move_speed", "multiply", multiplier)
    _character.velocity = _attributes.move_speed * _move_state._direction
    _skin.transition_to(_move_skin_state)

func exit() -> void:
    if _is_walk_mode:
        _attributes.remove_modifier(&"locomotion_speed")
    super()
    _move_state.exit()
```

**Inspector 属性**:

| 属性 | 类型 | Walk 值 | Run 值 | 说明 |
|---|---|---|---|---|
| `_move_skin_state` | StringName | `&"walk"` | `&"run"` | 皮肤动画状态名 |
| `_is_walk_mode` | bool | `true` | `false` | 是否启用 walk 减速 modifier |
| `_path_idle_state` | String | `"Ground/Move/Idle"` | `"Ground/Move/Idle"` | 无输入时回到的状态 |
| `_path_other_state` | String | `"Ground/Move/Run"` | `"Ground/Move/Walk"` | 切换到的另一个移动状态 |
| `_path_grabbing_state` | String | `"Ground/Grab/Grabbing"` | `"Ground/Grab/Grabbing"` | 抓取状态路径 |

**状态转换逻辑**:

```gdscript
func physics_process(delta: float) -> void:
    _move_state._direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if not _move_state._direction.is_equal_approx(Vector2.ZERO):
        _skin.skin_direction = _move_state._direction.normalized()
    _move_state.physics_process(delta)  # Move 层 apply velocity + move_and_slide
    if _move_state._direction.is_equal_approx(Vector2.ZERO):
        _state_machine.transition_to(_path_idle_state)
        return
    if _path_other_state != "" and Input.is_action_pressed("walk") != _is_walk_mode:
        _state_machine.transition_to(_path_other_state)
```

**条件解读**: `Input.is_action_pressed("walk") != _is_walk_mode`

| 当前状态 | walk 按下 | 条件结果 | 动作 |
|---|---|---|---|
| Walk (true) | 是 | true != true = false | 继续 Walk |
| Walk (true) | 否 | false != true = true | → Run |
| Run (false) | 否 | false != false = false | 继续 Run |
| Run (false) | 是 | true != false = true | → Walk |

**Idle 和 Landing 的适配**:

`quiver_action_idle.gd` 和 `quiver_action_landing.gd` 都新增了 `_path_run_state` / `_path_run` 属性。当有方向输入时：
- walk 按下 → 转到 Walk
- walk 未按下 → 转到 Run（如果 Run 节点存在，通过 `has_node()` 检查）
- 无 Run 节点 → 回退到 Walk（兼容旧角色）

**输入映射**: `project.godot` 的 `[input]` 部分需添加 `walk` 动作（推荐绑定 Left Shift）。

**现有角色兼容性**: 旧角色的 Walk 节点 `_path_other_state` 默认为 `""`（空字符串），此时 Locomotion 不会尝试切换状态，行为与原版 Walk 完全一致。

**动画 xfade_time 注意事项**: 所有动画状态过渡（idle↔walk, idle↔run, walk↔run）的 `xfade_time` 必须为 `0`（瞬间切换）。非零 xfade_time 会导致 `AnimatedSprite2D:animation`（StringName 类型）被线性插值，产生闪烁和调试器乱码。详见 `docs/RUN_WALK_DESIGN.md`。

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

### 7.2 QuiverHitBox（攻击判定框）

**文件**: `combat/collision_areas/quiver_hit_box.gd`
**类名**: `QuiverHitBox`（Area2D，被动监听者）

**被动**: `monitoring=false, monitorable=true`
- 不主动扫描任何东西
- 只是承载 `character_attributes` 和 `attack_data`，等对方 HurtBox 来"捡"
- `collision_layer` 和 `collision_mask` 由 `QuiverCharacter._update_hitbox_layers()` 动态管理（高度层）

**阵营 group 缓存**:
- `var _faction_dict: Dictionary` — 缓存 `area2d:` 前缀的 group，用于 O(1) 阵营检查
- `_ready()` 时初始化缓存
- 重写 `add_to_group()` / `remove_from_group()`，捕获运行时 group 变更并刷新缓存
- 供 `QuiverHurtBox.are_factions_equal()` 使用

### 7.3 QuiverHurtBox（受击判定框）

**文件**: `combat/collision_areas/quiver_hurt_box.gd`
**类名**: `QuiverHurtBox`（Area2D，主动监听者）

**主动**: `monitoring=true, monitorable=false`。`collision_layer` 和 `collision_mask` 由 `QuiverCharacter._update_hurtbox_layers()` 动态管理（高度层）。

**`_on_area_entered()` 分发**:

| 进入的 Area | 方法 | 后续 |
|---|---|---|
| `WallHitBox` | `_handle_wall_hit_box()` | `wall_bounced` 信号 |
| `QuiverHitBox` | `_handle_hit_box()` | `apply_damage` + `apply_knockback` |
| `QuiverGrabBox` | `_handle_grab_box()` | `grab_requested` 信号 |

**注意**: 阵营检查 `are_factions_equal()` 在 `_on_area_entered()` 入口处统一执行，同阵营直接 return，不再在各个 `_handle_*()` 方法中单独检查。

**`_handle_hit_box()` 完整流程**:
1. `_can_be_attacked_by(hit_box)` 检查：非无敌 + 同一车道
2. `CombatSystem.apply_damage(hit_box.attack_data, character_attributes)`
3. 构造 `QuiverKnockbackData`（包含 treated launch_vector：根据攻击方向翻转，让角色**始终向后飞**）
4. `CombatSystem.apply_knockback(knockback_data, character_attributes)`

**阵营过滤机制**（`area2d:` group）:
- 常量 `FACTION_PREFIX = "area2d:"`（定义在 QuiverHurtBox）
- 缓存机制：`_faction_dict: Dictionary` 只缓存 `area2d:` 前缀的 group，使用 Dictionary 实现 O(1) 查找
- `_ready()` 时初始化缓存，捕获 `.tscn` 中声明的 groups
- 重写 `add_to_group()`/`remove_from_group()`，捕获运行时的 group 变更
- 静态函数 `are_factions_equal(hit_box, hurt_box)`：两侧都使用 Dictionary 缓存，自动选择小集合遍历，回退到实时构建 Dictionary
- 同阵营双方的 HitBox/HurtBox 不会互相造成伤害/抓取
- 配置方式：在 .tscn 中为角色的所有战斗 Area2D 添加 `groups = ["area2d:角色名"]`
- `_handle_grab_box()` 同样使用此检查
- QuiverHitBox 和 QuiverHurtBox 都实现了相同的缓存机制

**墙壁反弹机制**（`area2d:wall` group）:
- HurtBox 默认加入 `area2d:wall` group（在 .tscn 中配置）
- WallHitBox 也加入 `area2d:wall` group（在 `quiver_wall_hit_box.gd` 的 `_ready()` 中）
- 默认状态下，HurtBox 和 WallHitBox 同属 `area2d:wall` → `are_factions_equal()` 返回 true → 碰撞被跳过
- 动画关键帧调用 `_enable_wall_bounce_collisions()` → `remove_from_group("area2d:wall")` → 阵营不再匹配 → 碰撞生效
- 动画关键帧调用 `_disable_wall_bounce_collisions()` → `add_to_group("area2d:wall")` → 恢复同阵营 → 碰撞跳过
- 这种设计让墙壁反弹完全由动画控制，无需修改碰撞层

### 7.4 QuiverAttackData（攻击数据）

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

### 7.5 QuiverKnockbackData

**文件**: `combat/quiver_knockback_data.gd`
**类名**: `QuiverKnockbackData`（RefCounted，瞬态数据，不持久化）

```gdscript
var strength: CombatSystem.KnockbackStrength
var hurt_type: CombatSystem.HurtTypes
var launch_vector: Vector2
```

### 7.6 碰撞检测原则

**核心设计**：高度层是唯一的物理检测通道，faction group 是唯一的逻辑过滤机制。

```
高度层交集 → 物理检测触发（Godot 引擎要求 layer/mask 匹配）
  → faction group 过滤（area2d: 前缀匹配 = 同阵营，跳过）
    → 行为执行（伤害、击飞、抓取、反弹）
```

- **不再使用**固定的 combat layer (9-14) 区分 player/enemy/wall
- **不再使用** `character_type` 枚举和 `QuiverCollisionTypes` 碰撞预设系统
- 所有战斗 Area2D 的 `collision_layer` / `collision_mask` 由 `QuiverCharacter` 动态管理（高度层 15-24）
- 阵营区分完全通过 `area2d:` 前缀的 group 实现

### 7.7 完整战斗流程（玩家攻击敌人）

```
玩家按 J 键
  ↓
Idle.unhandled_input() → Move.attack() → transition_to("Ground/Combo1")
  ↓
Combo1.enter() → _skin.transition_to("attack1") → 播放攻击动画
  ↓
动画关键帧：攻击动画中某帧禁用 HitBox CollisionShape2D.disabled（通过动画 value track）
  ↓
Player HitBox (高度层 = 攻击高度层, monitorable=true, 携带 attack_data)
  与敌人 HurtBox (高度层 = 敌人身体高度层, monitoring=true) 发生区域重叠
  （前提：两者的攻击高度层和身体高度层有交集，Godot 引擎触发 area_entered 信号）
  ↓
HurtBox._on_area_entered()
  ↓
are_factions_equal() 检查：
  Player HitBox groups: ["area2d:chen_jingchou"]
  Enemy HurtBox groups: ["area2d:enemy", "area2d:wall"]
  无交集 → 不同阵营 → 继续处理
  ↓
_handle_hit_box()
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

**文件**: `utilities/custom_nodes/level_camera/quiver_level_camera.gd` + `.tscn`
**类名**: `QuiverLevelCamera`（继承 Camera2D）

**四个核心职责**:
1. **屏幕边缘碰撞墙（四方向）**: 每帧更新四个 CollisionShape2D（角色无法走出屏幕边缘）
2. **墙壁反弹检测**: LeftBounce/RightBounce Area2D，通过 RemoteTransform2D 与屏幕边缘同步
3. **`delimitate_room()`**: 平滑过渡摄像头边界到指定区域（用 Tween）
4. **高度层碰撞初始化**: `_ready()` 时调用 `QuiverCharacter.get_all_height_layers_mask()` 设置碰撞层

#### 场景树结构

```
LevelCamera (Camera2D)
├── ScreenLimits (StaticBody2D, visible=false)
│   ├── Left (CollisionShape2D, 竖直长条, one_way_collision, rotation=90°)
│   │   └── RemoteTransform2D → LeftBounce/LeftBounceShape
│   ├── Right (CollisionShape2D, 竖直长条, one_way_collision, rotation=-90°)
│   │   └── RemoteTransform2D → RightBounce/RightBounceShape
│   ├── Top (CollisionShape2D, 水平长条, one_way_collision, rotation=180°)
│   └── Bottom (CollisionShape2D, 水平长条, one_way_collision, rotation=0°)
├── LeftBounce (Area2D, WallHitBox, groups=["area2d:wall"])
│   └── LeftBounceShape (CollisionShape2D)
└── RightBounce (Area2D, WallHitBox, groups=["area2d:wall"])
    └── RightBounceShape (CollisionShape2D)
```

#### 屏幕边缘碰撞墙（ScreenLimits）

四个 StaticBody2D 子节点（Left/Right/Top/Bottom）组成隐形墙壁，阻止角色走出屏幕。

**`_process()` 每帧定位逻辑**:
- Left: `x = min(limit_left - 半宽, 相机中心x - 半视口宽)`
- Right: `x = max(limit_right + 半宽, 相机中心x + 半视口宽)`
- Top: `y = min(limit_top - 半高, 相机中心y - 半视口高)`
- Bottom: `y = max(limit_bottom + 半高, 相机中心y + 半视口高)`

`min/max` 确保墙壁不会超出相机的硬边界（limit_left/right/top/bottom）。

**`one_way_collision` 方向**:
- Left: rotation=90°，法线朝右 → 阻挡向左（出屏幕），允许向右（回屏幕）
- Right: rotation=-90°，法线朝左 → 阻挡向右（出屏幕），允许向左（回屏幕）
- Top: rotation=180°，法线朝下 → 阻挡向上（出屏幕），允许向下（回屏幕）
- Bottom: rotation=0°，法线朝上 → 阻挡向下（出屏幕），允许向上（回屏幕）

**碰撞层**: 不使用固定 layer，由 `_setup_height_layer_collisions()` 在 `_ready()` 时设置为全高度层 bitmask（通过 `QuiverCharacter.get_all_height_layers_mask()` 获取）。角色的 collision_mask 动态包含当前高度层，因此能自动与屏幕边缘碰撞。

**形状尺寸动态更新**:
- `_update_collision_limits_length()`: 左右墙壁的长度 = 视口高度/zoom + collision_width；上下墙壁的长度 = 视口宽度/zoom + collision_width
- `_update_collision_limits_width()`: 所有墙壁的厚度 = collision_width（默认 80px）
- 视口大小变化时自动更新（`size_changed` 信号）
- Tween 过渡期间也持续更新

#### 墙壁反弹检测（LeftBounce/RightBounce）

两个 Area2D（WallHitBox 脚本），位于屏幕左右边缘，检测角色被击飞后撞墙。

**位置同步**: 通过 `RemoteTransform2D` 将 ScreenLimits/Left(Right) 的位置复制给 LeftBounce/RightBounce 的 CollisionShape2D。ScreenLimits 每帧移动 → RemoteTransform2D 自动同步 → 反弹检测始终在屏幕边缘。

**碰撞层**: 同 ScreenLimits，使用全高度层 bitmask。

**反弹流程**:
1. 角色被击飞 → knockout_launch 动画播放
2. 动画关键帧调用 `_enable_wall_bounce_collisions()` → HurtBox 移除 `area2d:wall` group
3. 角色 HurtBox 进入 LeftBounce/RightBounce 检测范围
4. `_on_area_entered()` → `are_factions_equal()` 返回 false（HurtBox 已无 `area2d:wall`）
5. `_handle_wall_hit_box()` → 造成伤害 + `wall_bounced` 信号
6. 状态机收到信号 → 角色速度反转 → 反弹
7. knockout_landed 动画播放 → `_disable_wall_bounce_collisions()` → HurtBox 重新加入 `area2d:wall` group

#### `delimitate_room()` — 战斗区域锁定

用 Tween 平滑过渡相机的 limits 和 zoom，用于战斗开始时锁定摄像机到战斗区域。

```gdscript
func delimitate_room(p_limit_left, p_limit_top, p_limit_right, p_limit_bottom, p_zoom, p_duration):
    # Tween 过渡到战斗区域边界（TRANS_QUAD + EASE_IN_OUT）
```

**典型使用场景**: 玩家走进 FightRoom → `QuiverFightRoom.setup_fight_room()` → 调用 `delimitate_room()` → 相机平滑锁定到战斗区域。战斗结束后 `setup_after_fight_room()` 恢复或切换到新区域。

**注意**: 如果 limits 范围小于视口可见范围（视口大小/zoom），limits 实际上不起作用，因为相机无法将可见区域缩小到比视口更小。正式关卡中 FightRoom 的区域大小通常设计为接近视口可见大小。

---

## 9. 全局事件总线 (Events)

**文件**: `utilities/helpers/autoload/quiver_events.gd`
**全局变量名**: `Events`

```gdscript
signal characters_reseted       # 角色重置（重载场景时）
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
| `create_mirrored_animation/` | 动画节点 | 创建镜像动画（left/right），支持 flip_h、position、rotation、polygon 属性镜像 |
| `states_dropdown/` | `QuiverActionAttack` 等需要选择其他状态的脚本 | 提供状态下拉列表 |
| `ai_states_dropdown/` | AI 状态脚本 | 提供 AI 状态下拉列表 |
| `external_enum/` | 需要选择脚本内枚举的字段 | 解析外部枚举提供下拉 |
| **`create_new_character/`** | **`CharacterTemplate` 节点**（`characters/playable/_template/character_template.tscn`） | **创建/删除角色** |
| **`height_layers/`** | **`QuiverCharacterSkinAnimTree` 节点** | **扫描动画帧文件名注入高度层轨道 + 轮廓转换工具（Polygon/Capsule/Rectangle）** |

### Height Layers Inspector（新增）

**触发方式**：
1. 打开角色皮肤场景（如 `chen_jingchou_skin.tscn`）
2. 选中根节点 `ChenJingchouSkin`（QuiverCharacterSkinAnimTree）
3. Inspector 面板显示 "Height Layers Scanner" 区域

**文件结构**：
```
custom_inspectors/height_layers/
├── inspector_plugin.gd              # EditorInspectorPlugin 入口
├── height_layers_widget.gd          # Inspector UI 组件（VBoxContainer, @tool，纯视图、可弃）
├── height_layers_widget.tscn        # Widget 场景
├── contour_conversion_runner.gd     # 轮廓转换运行器（extends Node, @tool, class_name ContourConversionRunner，常驻编辑器树）
├── animation_track_injector.gd      # 轨道注入核心 + 轮廓转换管道（extends RefCounted, @tool）
├── contour_tracer.gd                # 轮廓提取 + 几何计算（extends RefCounted, 全静态方法, @tool）
└── mask_editor_dialog.gd            # 交互式蒙版绘制工具（extends AcceptDialog, @tool）
```

**Widget 生命周期契约（重要，4.7 源码实证）**：

`EditorInspector::_clear()` 在每次重解析（切换选中节点、场景保存刷新等）时用 **memdelete 立即销毁** Inspector 内的自定义控件——widget 是"每次重生"的易碎视图，任何存在 widget 实例上的状态（文字、正在跑的协程）都会丢。因此：

- **长任务协程必须挂在 `ContourConversionRunner`**（`get_or_create()` 单例，add_child 到 `EditorInterface.get_base_control()`，编辑器会话内常驻），widget 只负责 `start()` 与订阅 `progress_updated` / `run_finished` 后 `_refresh_from_runner()` 回放状态快照 → 切页不再丢失进度文字，帧让出宿主恒有效（不再假死）
- widget 死亡时其对 runner 信号的连接由 Godot 自动断开，无需手动清理
- runner 转换完成后**自行**调用 `EditorInterface.get_resource_filesystem().scan()`（旧 widget `scan_completed` 信号 → plugin 中转链已废除，widget 半路死亡会断链）
- 转换期间关闭目标场景页签：runner 在下一次进度回调检测 `is_instance_valid(_active_skin)` 失败 → `_session+1` 作废旧协程收尾权 → 立即 `_finalize` 报错并复位 `is_running`（不会永久卡运行态）
- 防 class_name 缓存时序问题：widget 经 `const preload` 引用 runner 与 injector（新文件同步到另一台机器后首启即编译，不依赖全局类注册时机）

**工作流程（轮廓转换）**：
```
用户点击 Body 轮廓转换 / Attack 轮廓转换
  ↓
HeightLayersWidget._start_conversion() → 参数持久化 + ContourConversionRunner.start()
  ↓
Runner._execute() → AnimationTrackInjector.convert_body_contours() / convert_attack_contours()
                    （callback_obj = runner：进度回调 + get_tree() 帧让出）
  ↓
1. 扫描 PNG 图像，提取轮廓（_scan_frames_contours + ContourTracer）
2. 后处理：计算 MABR、胶囊体参数、物理高度、攻击高度
3. 修改场景树节点类型（_modify_scene_tree_node）
4. 注入碰撞形状 tracks 到每个 Animation（_inject_all_tracks）
5. 保存修改后的 Animation 资源（ResourceSaver.save）
  ↓
显示结果（处理帧数/错误列表）
```

---

## 15. 轮廓转换工具系统

Inspector 面板中的轮廓转换工具，从角色 sprite PNG 图像自动提取轮廓多边形，生成碰撞形状（Polygon/Capsule/Rectangle）并注入逐帧动画轨道。与 Height Layers Inspector 共享同一个 Inspector Widget（选中 `QuiverCharacterSkinAnimTree` 节点时激活）。

### 15.1 系统概述

**触发方式**：
1. 打开角色皮肤场景（如 `chenjianchou_new_skin.tscn`）
2. 选中根节点（QuiverCharacterSkinAnimTree）
3. Inspector 面板显示 "Contour Preview & Mask Editor" 和 "Contour Polygon Conversion" 区域

**组件依赖图**：
```
inspector_plugin.gd (EditorInspectorPlugin)
    └── height_layers_widget.gd (VBoxContainer, Inspector UI，纯视图)
            └── contour_conversion_runner.gd (Node 单例，常驻 base_control，长任务宿主)
                    └── animation_track_injector.gd (RefCounted, 转换管道编排)
                            └── contour_tracer.gd (RefCounted, 静态几何计算)
            └── mask_editor_dialog.gd (AcceptDialog, 蒙版绘制)
                    └── contour_tracer.gd (预览用)
```

**数据流**：
```
PNG 文件 → ContourTracer.trace_contours() → 轮廓多边形（末尾对每条轮廓做自交规整 _make_simple_largest）
    ↓
AnimationTrackInjector._convert_contours_common()
    ├── ContourTracer.calc_mabr() → MABR
    ├── ContourTracer.calc_capsule_from_mabr() → Capsule 参数
    ├── ContourTracer.pixels_to_shape_local() → 局部坐标
    ├── ContourTracer.calc_physical_height() → 物理高度
    └── ContourTracer.calc_attack_heights() → 攻击高度
    ↓
_modify_scene_tree_node() → 场景树节点替换（CollisionPolygon2D / CollisionShape2D）
_inject_all_tracks() → Animation 资源轨道注入 + emit_changed() + ResourceSaver.save()
```

### 15.2 ShapeType 枚举与 SHAPE_CONFIGS

`AnimationTrackInjector` 定义了三种碰撞形状类型：

```gdscript
enum ShapeType {
    POLYGON = 0,    # CollisionPolygon2D + :polygon track（精确轮廓）
    CAPSULE = 1,    # CollisionShape2D + CapsuleShape2D（MABR 推导）
    RECTANGLE = 2   # CollisionShape2D + RectangleShape2D（MABR 推导）
}
```

**SHAPE_CONFIGS 数据驱动配置**：

每种 ShapeType 对应一组轨道配置，定义节点类型和需要注入的 track 属性列表：

| ShapeType | 场景节点类型 | Track 属性 | 数据来源 |
|-----------|-------------|-----------|---------|
| POLYGON | `CollisionPolygon2D` | `:polygon`, `:position`(0,0), `:rotation`(0) | `trace_contours()` 规整后轮廓（自交已洗为简单多边形） |
| CAPSULE | `CollisionShape2D` + `CapsuleShape2D` | `:shape:radius`, `:shape:height`, `:position`, `:rotation` | MABR 短边=直径，长边=总高度 |
| RECTANGLE | `CollisionShape2D` + `RectangleShape2D` | `:shape:size`, `:position`, `:rotation` | MABR 尺寸和角度 |

### 15.3 ContourTracer — 轮廓提取与几何计算

`class_name ContourTracer`，extends `RefCounted`，`@tool`。全静态方法，无实例状态。

**核心算法**：使用 Godot 内置 `BitMap` API（实现 Marching Squares）+ `opaque_to_polygons()`（Ramer-Douglas-Peucker 简化）。**返回前对每条轮廓调用 `_make_simple_largest()` 做自交规整**：`opaque_to_polygons` 输出的轮廓可能自交/退化（引擎已知缺陷），这类多边形会让 `Geometry2D.triangulate_polygon` 返回空 → 运行时 Polygon2D（阴影）与 CollisionPolygon2D（碰撞/攻击）三角剖分失败（"该帧没影"/坏碰撞）。`_make_simple_largest()` 用 `Geometry2D.merge_polygons(poly, [])`（Clipper 布尔并）把自交轮廓拆成简单多边形，取「面积最大且可三角剖分」的一块；简单多边形原样返回（幂等无损）；全部剖不出时退回最大块/原样兜底（规避 issue #99745）。**该处理在烘焙期一次性完成，运行时零成本**；同时覆盖 body 碰撞、攻击判定、阴影三类轮廓（均产自本函数）。

#### 15.3.1 公共 API

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `trace_contours()` | `image, mask, alpha_threshold, simplify_tolerance, max_size, min_area_ratio, erosion_radius` | `Array[PackedVector2Array]` | 主入口：从 PNG 提取轮廓多边形。处理缩放、蒙版叠加、腐蚀、自适应容差重试 |
| `calc_physical_height()` | `contours, image_height` | `float` | 轮廓最高点（min Y）到图像底边的距离 |
| `calc_contour_width()` | `contours` | `float` | 所有轮廓的水平跨度（max X - min X） |
| `calc_attack_heights()` | `contours, image_height, height_definitions` | `Array` | 每个轮廓中点高度，按高度层分组去重 |
| `pixels_to_shape_local()` | `vertices, img_w, img_h, shape_pos` | `PackedVector2Array` | 像素坐标 → CollisionPolygon2D 局部坐标（中心原点） |
| `format_polygon_array()` | `vertices` | `String` | 格式化为 `.tscn` 文本 `PackedVector2Array(x, y, ...)` |
| `calc_mabr()` | `points` | `Dictionary` | **最小面积外接矩形**（O(n²) 凸包投影，Freeman & Shapira 1975）。返回 `{center, size, angle, area, corners}` |
| `calc_aabb()` | `points` | `Dictionary` | 轴对齐包围盒。返回 `{center, size, area}` |
| `is_point_in_mabr()` | `point, mabr, tolerance` | `bool` | 点在旋转矩形内判定 |
| `calc_capsule_from_mabr()` | `mabr` | `Dictionary` | 从 MABR 推导 CapsuleShape2D 参数：短边=直径，长边=总高度。返回 `{center, radius, height, angle}` |
| `generate_capsule_polygon()` | `center, radius, total_height, angle, segments` | `PackedVector2Array` | 生成约 32 顶点的近似胶囊多边形（预览渲染用） |
| `run_mabr_tests()` | — | `Array[String]` | 内置 MABR 单元测试（9 个用例：正方形、菱形、矩形、单点、两点、共线、三角形、空集、不规则） |

#### 15.3.2 关键设计决策

**自适应容差重试**：如果 `opaque_to_polygons()` 产生退化输出（无有效多边形满足 min_area），容差减半重试直到 0.5。

**形态学腐蚀**：使用 `BitMap.grow_mask(-radius, rect)`（Godot C++ 实现，O(W×H)）在轮廓提取前收缩不透明区域，去除武器、披风、头发等细长突出。仅用于 MABR 形状（Capsule/Rectangle），Polygon 模式腐蚀半径固定为 0。

**蒙版优先级**：`{name}.{category}.mask.png`（特定类别）> `{name}.mask.png`（通用）> 无蒙版（全图 alpha 扫描）。

**最大尺寸保护**：超过 `max_size`（默认 512px）的图像先缩小再处理，结果按比例放大还原。

### 15.4 MaskEditorDialog — 交互式蒙版绘制

extends `AcceptDialog`，`@tool`。无 `class_name`（通过 `preload` 加载）。

**功能**：在 sprite PNG 上绘制/擦除蒙版覆盖层，控制轮廓提取的区域范围。蒙版保存为 `.mask.png` 文件。

**UI 结构**：
```
AcceptDialog (title: "Mask Editor")
└── HSplitContainer
    ├── 左侧：画布区域
    │   └── SubViewportContainer → SubViewport
    │       ├── TextureRect（背景：原始 PNG）
    │       ├── TextureRect（蒙版覆盖：红色半透明）
    │       └── Node2D（画笔预览圆圈）
    └── 右侧：工具面板
        ├── 文件名标签
        ├── 蒙版类型选择（Generic / Body / Attack）
        ├── 画笔 / 橡皮擦切换按钮
        ├── 画笔大小（5-100px）
        ├── "Preview Contour" 按钮 + 预览图
        ├── "Save Mask" / "Clear Mask" 按钮
        └── 状态标签
```

**蒙版类型系统**：

| 类型 | 文件名格式 | 使用场景 |
|------|-----------|---------|
| Generic (id=0) | `{name}.mask.png` | Body 和 Attack 扫描均使用 |
| Body (id=1) | `{name}.body.mask.png` | 仅 Body 轮廓扫描使用 |
| Attack (id=2) | `{name}.attack.mask.png` | 仅 Attack 轮廓扫描使用 |

**绘制机制**：
- 左键：绘制（白色不透明）或擦除（透明），取决于当前工具
- 右键：临时橡皮擦（松开恢复）
- 鼠标滚轮：缩放（0.25x ~ 4x）
- 画笔为圆形，半径由 SpinBox 控制，鼠标移动时插值画线

**预览功能**："Preview Contour" 按钮调用 `ContourTracer.trace_contours()` 提取当前蒙版下的轮廓，在右侧 TextureRect 中显示红色轮廓线叠加在原始图像上。

### 15.5 AnimationTrackInjector 轮廓转换管道

`class_name AnimationTrackInjector`，extends `RefCounted`，`@tool`。

#### 15.5.1 公共入口

| 方法 | 说明 |
|------|------|
| `convert_body_contours(skin_node, alpha_threshold, simplify_tolerance, min_area_ratio, erosion_radius, shape_type, dry_run, callback_obj, shadow_simplify_tolerance=-1, shadow_min_area_ratio=-1)` | Body 轮廓转换（异步），返回 `{frame_count, errors, frames_info, png_renames}`。shadow 参数均 >= 0 时启用 ShadowBox 双扫描 |
| `convert_attack_contours(...)` | Attack 轮廓转换（异步），参数同 Body（不含 shadow 参数） |
| `preview_single_file(file_path, alpha_threshold, simplify_tolerance, min_area_ratio, erosion_radius)` | 单文件轮廓预览（不修改任何文件），返回轮廓、MABR、Capsule、Rectangle、physical_height、attack_heights、image |

#### 15.5.2 `_convert_contours_common()` — 统一转换管道（13 步）

Body 和 Attack 共享同一个核心管道，通过 Callable 回调实现类别特定行为：

1. 从 `AnimatedSprite2D` 子节点获取 `SpriteFrames`
2. 从 `AnimationPlayer` 子节点获取动画库
3. 从场景树发现 shape 节点（`_discover_shape_nodes()`）— Body: HurtBox 子节点；Attack: Attacks 下 Area2D 的子节点
4. 构建统一帧过滤（`_build_unified_frame_filter()`）+ 找出所有相关动画
5. **单次扫描**：`_scan_frames_contours()` — 遍历帧，加载 PNG，检查蒙版（specific > generic > none），调用 `ContourTracer.trace_contours()`
   - **5b. ShadowBox 第二次独立扫描**（仅 Body 且 shadow 参数启用时）：使用 `shadow_simplify_tolerance` / `shadow_min_area_ratio`，`erosion_radius = 0`，结果合并到 `frame["shadow_raw_contours"]`。不执行 MABR/Capsule/Rectangle 转换，不计算 physical_height/width
6. 前处理回调（Body: 无操作；Attack: 构建 sprite_anim → attack_node 映射）
7. 后处理每帧：类别特定字段 + 坐标变换 + MABR + Capsule + Rectangle 计算
   - **7d. ShadowBox 轮廓坐标变换**：`shadow_raw_contours` → `pixels_to_shape_local()` → `frame["shadow_contours"]`
8. 如果 `dry_run`：返回 frames_data 不做修改
9. 预计算 shape 类型变更状态（检测当前 vs 目标类型）
10. 修改场景树节点（仅当类型不匹配时，`_modify_scene_tree_node()`）
     - **10b. `_ensure_shadow_occluder_exists(skin_node, errors)`**（仅 shadow 扫描启用时）：确保 AnimatedSprite2D 下存在 ShadowBox (LightOccluder2D，`sdf_collision = false`)，不存在则自动创建；**已存在但 `position != (0,0)` 时强制归零并向 errors 追加警告**（注入的 occluder:polygon 以 sprite 中心为原点，节点偏移=影子整体错位，编辑器误触移动是常见事故源）
       - 阴影方案已从旧 SDF ray-march 改为 **polygon 投影**：ShadowBox 不再写入 SDF 纹理（故 `sdf_collision = false`），其 `occluder.polygon` 仅作为逐帧轮廓数据源，由项目侧 `scripts/character_shadow_controller.gd` 读取并做仿射投影到地面
       - 配套：`quiver_character.gd` 的 `_create_shadow_renderer()` 现创建 **Node2D**（`z_index = -1`）并挂 `character_shadow_controller.gd`，控制器内部再建 Polygon2D 子节点渲染；不再是旧的 `Sprite2D` + 平行四边形 vertex 变形方案
11. 构建 per-shape 过滤映射
12. 统一轨道注入（`_inject_all_tracks()`）
    - **关键帧时间真源**：所有注入/解析时刻来自 `AnimationTrackInjector.build_frame_transitions()`——用引擎 `Animation.value_track_interpolate()` 探测 `AnimatedSprite2D:frame` 轨道的"帧号→开始显示时刻"过渡表（Nearest/Linear/Cubic、easing、越界钳制由引擎本人回答，注入器不重实现曲线语义）。**不再假设"帧均匀分布在 帧号÷SpriteFrames速度"**（该假设在动画拉长/压缩时长或非均匀键位时导致注入轨道与画面错位）。无有效 :frame 轨道时回退均匀节奏（=旧行为）并向结果 errors 追加警告；`_parse_disabled_track` 的 enabled 帧采样亦用同一时间表，flip 镜像判定随之自然对齐
    - **静态默认值回写**（`_collect_static_defaults()` + `_apply_static_defaults()`）：注入完成后把各动画 **t=0 键值**写回场景树节点/内嵌资源的静态属性（`CollisionPolygon2D.polygon/position/rotation`、`ShadowBox.occluder.polygon`），使编辑器视口**不播放动画时**显示真实数据而非陈旧残留值。优先级：首个未 flip 动画 > 首个 flip 动画；不回写 `.:` 根属性（physical_* 为运行时状态）与 `shape:*` 资源属性（可能跨节点复用）。落盘随用户 Ctrl+S（与 `_modify_scene_tree_node` 同生命周期）
13. 返回结果

#### 15.5.3 场景树操作

**`_modify_scene_tree_node(skin_node, shape_info, shape_type, first_frame_data, errors)`**：

替换场景树中的碰撞形状节点：

1. 获取父节点（`skin_node.get_node_or_null(parent_path)`）
2. 获取旧节点（`parent.get_node_or_null(shape_name)`）
3. **先 `parent.remove_child(old_node)` 再 `old_node.queue_free()`** — 立即从父节点移除避免命名冲突
4. 根据 `ShapeType` 创建新节点：
   - `POLYGON` → `CollisionPolygon2D`，设置首帧轮廓为初始 polygon
   - `CAPSULE` → `CollisionShape2D` + `CapsuleShape2D`，设置首帧参数（默认 r=40, h=160 body / h=120 attack）
   - `RECTANGLE` → `CollisionShape2D` + `RectangleShape2D`，设置首帧 MABR 尺寸
5. 设置颜色（Body: 蓝色，Attack: 橙色）
6. Attack 形状默认 `disabled = true`
7. `parent.add_child(new_node)` + `new_node.owner = skin_node.owner`（确保 Ctrl+S 时保存）

**`_detect_shape_type_from_node(shape_node)`**：

从场景树节点类型检测当前 ShapeType：
- `CollisionPolygon2D` → `POLYGON`
- `CollisionShape2D` + `CapsuleShape2D` → `CAPSULE`
- `CollisionShape2D` + `RectangleShape2D` → `RECTANGLE`
- 其他 → `POLYGON`（默认）

**保存机制**：不直接写文件。修改场景树节点后调用 `anim.emit_changed()` 标记修改，编辑器自动标记场景为"已修改"，用户 Ctrl+S 统一保存。

#### 15.5.4 轨道注入架构

**Per-shape tracks**（每个 shape 节点独立写入）：

| ShapeType | Track 路径 | 值类型 | 说明 |
|-----------|-----------|--------|------|
| POLYGON | `shape_path:polygon` | `PackedVector2Array` | 逐帧轮廓多边形 |
| POLYGON | `shape_path:position` | `Vector2` | 固定 (0,0) |
| POLYGON | `shape_path:rotation` | `float` | 固定 0 |
| CAPSULE | `shape_path:shape:radius` | `float` | 胶囊半径 |
| CAPSULE | `shape_path:shape:height` | `float` | 胶囊总高度 |
| CAPSULE | `shape_path:position` | `Vector2` | 位置偏移 |
| CAPSULE | `shape_path:rotation` | `float` | 旋转角度 |
| RECTANGLE | `shape_path:shape:size` | `Vector2` | 矩形尺寸 |
| RECTANGLE | `shape_path:position` | `Vector2` | 位置偏移 |
| RECTANGLE | `shape_path:rotation` | `float` | 旋转角度 |

**Shared tracks**（每个动画写入一次）：

| 类别 | Track 路径 | 说明 |
|------|-----------|------|
| Body | `.:physical_height` | Skin 物理高度 |
| Body | `.:physical_width` | Skin 物理宽度（CapsuleShape2D.height 代理） |
| Body | `AnimatedSprite2D/ShadowBox:occluder:polygon` | ShadowBox 阴影轮廓 polygon（仅 shadow 扫描启用时注入，`_inject_occluder_polygon_tracks()`） |
| Attack | `.:attack_heights` | Skin 攻击高度数组 |

**ShadowBox track 说明**：无论 Body 选择 Polygon / Capsule / Rectangle，ShadowBox 始终使用独立扫描的原始 polygon 顶点（`shadow_contours[0]`）。`OccluderPolygon2D.polygon` 只支持单一 `PackedVector2Array`（与 `CollisionPolygon2D.polygon` 同限制），多分离部分时只取第一个轮廓（最大面积）。flip_h 时复用已提取的 `flip_track_data` 做 X 镜像。

**Auxiliary tracks**（辅助轨道）：

| 类别 | Track 路径 | 说明 |
|------|-----------|------|
| Attack | `parent_path:position` | 复制 `AnimatedSprite2D:position` 到攻击 Area2D |
| Attack | `parent_path:visible` | 反转 `:disabled` 轨道（Attack 可见性） |

**轨道属性**：所有 value track 使用 `INTERPOLATION_NEAREST` + `UPDATE_DISCRETE`。

**flip_h 镜像支持**：读取 `AnimatedSprite2D:flip_h` 轨道，当 `flip_h = true` 时：
- `:polygon` — 所有 X 坐标取反
- `:position` — X 坐标取反
- `:rotation` — 角度取反

**优化**：keyframe 仅在值与前一帧不同时插入。

**Track 清理策略**：
- Shape 类型变更时：通过 `_remove_tracks_by_path_prefix()` **删除**旧类型的所有 tracks
- Shape 类型不变时：通过 `_clear_tracks_by_path_prefix()` **清除** keyframes 但保留 tracks（维持 track 顺序稳定）
- 清理操作在 Phase 0（`frames_data` 检查之前）执行，防止残留旧类型的 tracks

#### 15.5.5 帧过滤机制

**`_build_unified_frame_filter()`**：合并所有 shape 节点的 disabled track 数据，确定每个动画需要处理哪些帧。

**`_build_frame_filter_for_node()`**：解析单个 shape 节点的 `:disabled` 轨道离散 keyframe，采样每帧的 disabled 状态，返回 enabled 帧列表。

**`_find_all_relevant_anims()`**：遍历所有动画，找出引用了任何 shape 节点的 sprite 动画名。

**设计原则**：只处理引用了 shape_node 的动画。如果某个动画没有引用某个 shape 节点的 tracks，说明该动画不打算修改该节点，不处理。

### 15.6 Height Layers Widget — Inspector UI

`height_layers_widget.gd`，extends `VBoxContainer`，`@tool`。无 `class_name`。

**UI 结构**：
```
VBoxContainer (this widget)
├── [轮廓预览区]
│   ├── 文件选择（LineEdit + Browse 按钮，过滤 *.png）
│   ├── 预览参数（独立于转换参数）
│   │   ├── Alpha threshold (0-1)
│   │   ├── Simplify tolerance (0-256px)
│   │   ├── Min area ratio (0.1-0.8)
│   │   └── Erosion radius (0-100px)
│   ├── 操作按钮（Preview Contour / Edit Mask / MABR Test）
│   ├── RichTextLabel（结果输出）
│   └── TextureRect（预览图像）
│
├── [轮廓转换区]
│   ├── 转换参数（独立于预览参数）
│   │   ├── Alpha threshold
│   │   ├── Simplify tolerance
│   │   ├── Min area ratio
│   │   ├── Shape type（Polygon / Capsule / Rectangle）
│   │   ├── Erosion radius（仅 MABR 形状生效）
│   │   ├── 阴影简化容差（默认 20，比 body 更小 = 更精细阴影轮廓）
│   │   └── 阴影最小面积（默认 0.2，比 body 更小 = 保留更多小碎片）
│   ├── 转换按钮（Body Contour Conversion / Attack Contour Conversion）
│   ├── 状态标签
│   └── RichTextLabel（转换结果）
```

**双参数集设计**：预览参数和转换参数独立控制，允许用户在单文件上调参实验而不影响批量转换设置。

**静态持久化**：所有参数和选中文件路径存储为 `static` 变量，跨 widget 重建存活（Inspector 每次选择变化时重建自定义控件）。

**异步执行**：所有转换操作使用 `await` 避免阻塞编辑器 UI。进度回调 `_on_contour_progress()` 逐帧更新状态标签。

**SubViewport 渲染预览**：预览图像使用临时 SubViewport + Node2D 覆盖层绘制轮廓（绿色填充 + 红色边线）、MABR（蓝色半透明）、胶囊（品红色），捕获为 ImageTexture 后释放 SubViewport。

**Shape 类型默认参数**：切换 ShapeType 时自动设置合理默认值：
- Polygon: erosion=0, tolerance=100（精确轮廓）
- Capsule/Rectangle: erosion=20, tolerance=5（紧凑 MABR）

### 15.7 CreateMirroredAnimation 多边形镜像支持

`create_mirrored_animation_button.gd` 的镜像动画功能扩展了对 `:polygon` 属性的支持：

**`_is_mirrorable_property(property_name)`**：除 `flip_h`、`position`、`rotation` 外，现在也匹配以 `:polygon` 结尾的属性路径。

**`_mirror_track_values(anim, track_index, subpath)`**：对 `PackedVector2Array` 类型的 polygon 值，逐顶点取反 X 坐标实现水平镜像。

---

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
InspectorPlugin 生成 test_scenes/_test_<char_name>.tscn（使用 .replace() 替换 {{CHAR_PATH}} 和 {{CHAR_NAME}}）
  ↓
调用 EditorInterface.play_custom_scene() 运行测试
  ↓
 用户按 F8 退出测试
```

**测试场景是生成物（重要）**：`test_scenes/_test_<char_name>.tscn`（**整个 `test_scenes/` 目录已 gitignore，不纳入版本控制**，随时可由模板再生）每次点击 Run Test 都由 `inspector_plugin.gd` 内置模板字符串**整体重写**——对该文件的任何手工修改都会在下次点击时被覆盖；要改测试场景内容 = 改模板字符串。**写入是幂等的**：生成内容与磁盘一致时跳过写盘/扫描直接运行（编辑器打开着该场景也不会弹"硬盘变动"）；只有模板真正变化才落盘一次（此时编辑器会提示重载一次，Reload 后恢复安静）。背景网格由 `res://scripts/debug_grid.gd`（**CanvasLayer + 屏幕空间 `_draw` + 设备像素吸附**：每根线经相机 `get_screen_transform()` 映射到屏幕后取整，线宽按 `max(1, round(世界宽×zoom))` 量化，消除世界空间 1px 线在分数相机坐标下的亚像素抗锯齿蠕动；零 shader、零贴图，替代旧 `grid_background.gdshader`，颜色经导出属性覆盖；模板中节点类型为 CanvasLayer）。模板当前包含 `ShadowRegion`（`res://scripts/shadow_region.gd`，游戏侧脚本）节点：`position=(50,400) size=(900,300) debug_preview=true`，用于演示"阴影可生成区域"裁剪与软边缓冲收缩（详见 `docs/SHADOW_SOFT_EDGE_DESIGN.md` §9）；`debug_preview` 仅测试场景开启，正式关卡的区域节点应保持 false（运行时零绘制）。

> **目录约定**：`scenes/` 仅存放正式游戏场景（未来 `scenes/stages/` 等）；所有 Run Test 生成物（角色测试场景、法术测试场景及其 helper 脚本 `_test_spell_helper_*.gd`）统一输出到 `test_scenes/`（gitignore）。`create_new_spell/inspector_plugin.gd` 同样遵循幂等写盘 + `test_scenes/` 路径 + `debug_grid.gd` 背景。

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

## 16. UID 管理最佳实践

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
