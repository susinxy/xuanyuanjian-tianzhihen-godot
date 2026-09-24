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
│   ├── quiver_input_channel.gd   # 私有输入通道（虚拟手柄，见 5.0）
│   ├── behaviors/                # 行为脚本（玩家采集/AI 小抄基类/被动零写入，见 5.0）
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
│   │   │       ├── quiver_action_idle.gd       # Idle 状态（读通道，转到 Walk/Run）
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
var state_machine: QuiverStateMachine    # 公开只读访问器（行为脚本投递事件用）

# 输入通道与行为脚本（见 5.0）
@export var behavior_mode: BehaviorMode  # PLAYER_INPUT / AI_POLICY / PASSIVE
@export var ai_policy_script: Script     # AI 档挂载的策略小抄脚本
var channel: QuiverInputChannel          # 私有虚拟手柄（_ready 创建）
var behavior: Node                       # 行为脚本节点（宽松类型防编译期互引）
func switch_behavior(mode)               # 运行时操控权交接接口位
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
- **敌人**: 继承 `QuiverEnemyCharacter`，增加 `AiStateMachine` 引用，`_ready()` 里
  `attributes.duplicate(true)` + `reset()`——**断根级共享**（R11 裁决，机制归因
  b3 收口波实测勘误：隔离由 duplicate 调用本身完成——非导出账本变量
  `_modifier_records/_modifier_bases` 不走 storage 拷贝通道、副本由 `_init`
  重造；浅/深对本 tres 零可观测差，"浅拷账本串写"旧述系误诊，`(true)`
  仅无害保守形。判据=修饰/池/旗标的个体性，红锁=knockout_contract D9）

**attributes 实例隔离案卷（R11，2026-09-23，判例三条）**：
- **玩家档壳零隔离**：`QuiverCharacter` 及其创建器产物（含 AI 档壳）不做实例
  隔离（缺 :39 式 `duplicate()` 调用，与浅/深无关），同 `.tres` 被多实例
  按引用共享（血/池/姿态旗全是一个对象——真雷在此，b3 收口波实测确认：
  敌人壳只要保留 duplicate 调用即断根，退回共享引用则当场红）。游戏以
  `area2d:player` 身份门保证玩家档在场至多一具；确需双实例（测试替身、分身）
  时消费方自救：`duplicate(true)` 且**双写** `root.attributes`（动作状态的
  `_on_owner_ready` 缓存源）+ `skin.attributes`（战斗盒 `character_attributes`
  的 group 推送源）——只写一处=裂脑（block_parry_contract Q 流 A 方实证形制）。
- **`local_to_scene` 是反药（封死勿再试，双写判例）**：皮肤拆独立场景后
  root/skin 各自成份，上面"两引用同源"的既有契约当场破裂，且"一场景一本体"
  也满足不了；处方=显式 duplicate + 双写，隔离点唯一。
- **创建器 AI 档 × spawner 双头死结**（挂账 B5 设计会前置清单）：AI 档壳恒
  `extends QuiverCharacter`（缺 :39 式隔离调用）而 `QuiverEnemySpawner.spawn_current_wave()`
  `instantiate() as QuiverEnemyCharacter` 硬转型（非敌人壳=null）——AI 档角色
  喂 spawner 两头都死；二选一立案（创建器改产 EnemyCharacter 壳 vs
  `make_attributes_local()` 显式双写入口）属设计裁决，工程侧不私斗。

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
- `transition_to(anim_state)`: 验证状态存在；皮肤跟踪 `_brain_destination`
  （脑最近一次指挥的目的地），**自回访（身体当前节点==新目的地）仅在"脑改了
  主意"时走 `_playback.start()` 重入倒带，同目的地的每帧幂等登记一律 no-op**。
  判据是脑的意图而非身体的时钟。三案定档（`tools/attack_freeze_repro/` 五场景
  锁死）：①攻击末帧冻结——脑同栈 idle→attack1 身体从未离开、动画钉死末尾，
  新意图+原地=不同步→start 重播（travel 到自己引擎不倒带；seek/position 参数
  写入静默无效）；②腾空倒带回归——无差别倒带会把 mid_air 幂等登记变成逐帧
  重播（首帧抽搐）；③**rising/falling 播完停尾帧=悬停姿势的设计意图**，
  幂等登记永扰动（H6 双断言：钉死后幂等=0.200 保持、新意图=倒带重播）。
  法术皮肤 `SpellSkinAnimTree` 同构同修。
- `end_of_skin_animation()`: **吞信标守卫**——`get_travel_path()` 非空（转换
  挂起中）时静默丢弃本次信标（上游作者注释自陈"不记得为什么"， Combo 链
  上用于防止被替换动画的尾帧信标误结束新状态）。攻击边全 AT_INSTANT 时
  平时 path 恒空，该守卫仅在转换挂起瞬间开窗；勿在守卫外再加重试消费。
  **架构评估完整记录（守卫/名牌/边锁/看门狗三案推演与知情搁置）见
  `docs/ATTACK_BEACON_DESIGN_NOTES.md`。**
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
        ├── knockout_ground → 嵌套子状态机 { Start→knockout_landed→getting_up→End }
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
@export var knockout_resistance_max := 600.0  # 抗击打上限 R（统一模型，每角色定价）
@export var jump_force := -1200         # 起跳力（负数=向上，属性手填）
@export var knockback_weight := 1.0     # 击飞权重：起飞冲量乘数（属性手填；
                                        # 旧文档"动画 speed_X 自动设置"机制不存在，2026-09-18 诚实化）
@export var hit_lane_offset := 0        # 车道大小偏移

@export_group("Modifiers")
@export var is_invulnerable := false    # 无敌帧（apply_knock/apply_damage 直接免疫）
@export var has_superarmor := false     # 霸体（统一模型 G2 归零制：击打值完全无效）
@export var can_be_grabbed := true      # 可被抓取
@export var parry_window_frames: int = 6    # 弹反窗物理帧数（B3 盾反批；受管字段，
                                            # 入册后只准走修饰 API，见下受管名单）
@export var block_damage_ratio: float = 0.4 # 格挡伤害系数（B3；受管同上）
@export var attack_output: float = 1.0      # 自身输出全局乘数，护人态等增益以
                                            # 修饰表达而非裸写（B3；受管同上）

var health_current := health_max        # 当前 HP（setter 触发 health_changed 信号）
var mana_current := mana_max            # 当前法力值（setter 触发 mana_changed 信号）
var resistance_current := 0.0           # 运行时抗击打余量 R_current（_init 置满，
                                        # apply_knock 扣减/清零，refill_resistance 回满）
var ground_level := 0.0                 # 当前地面高度（Y 坐标）
var character_node: QuiverCharacter     # 关联的角色节点
var grabbed_offset: Marker2D            # 被抓取时的偏移标记
var is_blocking: bool = false           # 格挡旗标（运行时成对旗之一，B3；唯一生产
                                        # 写方 QuiverActionBlock enter/exit，判定缝只读）
var block_started_frame: int = 0        # 起架物理帧号（与 is_blocking 同帧成对写入，
                                        # 判定缝以此算 delta 对照弹反窗）
var _modifier_records: Array[Dictionary]  # 活跃的属性修改器记录
var _modifier_bases := {}               # 方式 B′ 账本：attribute → {value, is_int}
                                        # （base 首个修饰时捕获一次，重算永远以此为锚）
```

### 信号

```gdscript
signal health_changed          # HP 变化
signal health_depleted         # HP 归零
signal mana_changed            # 法力值变化
signal mana_depleted           # 法力值归零
signal hurt_requested(knockback: QuiverKnockbackData)     # 被击中，请求硬直动画
signal knockout_requested(knockback: QuiverKnockbackData)  # 请求击飞
signal wall_bounced(mirror_axis: Vector2)  # 撞墙反弹（携带被撞墙的镜像轴：左右墙 UP / 上下墙 RIGHT）
signal grab_requested(grabbed_character: QuiverAttributes)  # 请求抓取
signal grab_released           # 释放抓取
signal grabbed(ground_level: float)     # 被抓住
signal grab_denied             # 抓取被拒绝（boss 免疫抓取）
```

### 关键方法

```gdscript
func apply_knock(knock_value: float) -> Dictionary
    # 击飞统一结算的唯一判定点：{launched, impulse, swallow}
    # 六规则——无敌无效（判定点自守防直调者）、霸体走 swallow（2026-09-18 起
    #   交易作废语义自含，分发器不再持有 has_superarmor 条件）；死亡强飞 K+保底；
    #   空中额度视作空（K≤0 吞事件）；
    # 地面 K≥余量 破线（冲量=溢出+保底 50，余量清空）否则扣量硬直
func refill_resistance()    # 回气回满（Move.enter 与落地 _handle_landing 调用）
func is_alive() -> bool
func get_health_as_percentage() -> float
func reset() -> void              # 重置所有状态（HP、无敌、霸体、可被抓取、
                                  # in_knockout/skin_direction/格挡成对旗清零+清修饰账）

# Modifier 系统（用于 Buff/Debuff；方式 B′ 重算回写，见下说明）
func add_modifier(mod_id: StringName, attribute: StringName, type: String, value: float, source: Node = null)
func remove_modifier(mod_id: StringName)
func remove_modifiers_from_source(source: Node)
func modifier_snapshot() -> Array[Dictionary]  # 展示用深拷贝快照（dock 账本），非第二真相
```

**Modifier 系统说明——方式 B′（2026-09-23 手术；旧"方式 B：添加即裸改、
移除恢复 base_value"描述作废，本段为权威）**：
公开签名自法术时代起逐字未动（调用方零改动=宪法），实现内核换血——

- **重算回写**：任何加/摘/清账都经唯一重算点 `_recompute(attribute)`，按
  `值 = (base + Σ加项) × Π乘项` 从锚重算回写属性，**永不读现场值做增量**。
  旧世界的叠挂踩踏（同属性两修饰互相污染 base）与乱序摘除踩踏（先摘
  乘项会把被污染现场写回）在结构上不可能。
- **base 首捕一次**：属性的 base 只在该属性**首个修饰**到来时捕获进
  `_modifier_bases`（同时锁 `is_int` 类型），此后现场值再怎么裸写都不回流
  锚——"入册即抄走当时的被污染值"的旧踩踏链从此断根。
- **同 id 再挂=替换**：`add_modifier` 先 `remove_modifier(同 id)` 再入账
  （M3 锁），重复施加是"刷新"不是"叠乘"。
- **int 类型锁**：int 型受管字段（move_speed/parry_window_frames）回写走
  `roundi`，防重算把 int 导出劣化成 float（P4a 断言 typeof 锁死）。
- **未知操作型零副作用**：非 `"add"/"multiply"` 告警拒收，不入账不改值（M4a）。
- **reset 清账**：`reset()` 调 `_clear_all_modifiers()`——全部记录作废、
  受管属性回 base（先快照账本再清，防"回写要读表"的清序陷阱）；护人/减速
  等修饰不跨死亡泄漏到下世（M5 锁）。
- **单写者纪律（数值治理法，AGENTS）**：字段入册（首个修饰捕获 base）后
  只能经修饰 API 变更，裸写=重算锚漂移。现行执行手段=代码注释+契约哨兵
  （block_parry_contract M/P 流），运行时守卫按 plan 从简未建。

**受管字段名单（B3 盾反批入册；"升格规则"=出现第二写入方的当天进名单）**：

| 字段 | 类别 | 出生默认 | 写路径纪律 |
|---|---|---|---|
| `move_speed` | 受管导出（int，locomotion 老户） | 600 | 入册后只准修饰路（护人×0.5 等） |
| `parry_window_frames` | 受管导出（int） | 6 | 只准修饰路（P4/P5 实证：每角色窗配置×加/乘全走修饰） |
| `block_damage_ratio` | 受管导出（float） | 0.4 | 只准修饰路 |
| `attack_output` | 受管导出（float） | 1.0 | 只准修饰路（护人态=×0.3 修饰表达，禁模式旗标内藏数值推导） |
| `is_blocking` | 运行时成对旗（bool） | false | **非修饰域**；唯一生产写方 `QuiverActionBlock.enter/exit` 成对括弧，判定缝只读，`reset()` 兜底清零 |
| `block_started_frame` | 运行时成对旗（int） | 0 | 同上，与 `is_blocking` **同帧**成对写入（R4 宪章） |

回归锁：`tools/block_parry_contract/`（M 流修饰核心 + P 流判定缝 + Q 流姿态链）。

### 内部类 `HitLaneLimits`

```gdscript
class HitLaneLimits:
    var upper_limit := 0
    var lower_limit := 0
    func is_value_inside_lane(value: float) -> bool
```

判定攻击是否落在同一个"受击车道"窗口内。窗口家族**对轴无感**（中心 ± lane_size ± hit_lane_offset）：
横攻以双方 `ground_level` 比"排"（`CombatSystem.is_in_same_lane_as()`），纵攻换轴以双方
碰撞盒 `global_position.x` 比"列"（`is_in_same_column_as()`，2026-09-19 车道换轴批）。
换轴判据 = `QuiverAttributes.skin_direction` 出手镜像（皮肤同名字段的快照，
`QuiverActionAttack.enter` 主轴塌缩后写入、`exit` 清零；空攻/法术/抓取恒零向量=旧 Y 语义）。
`get_hit_lane_limits(p_center = INF)` 默认以 ground_level 为中心，传 x 即得列窗口。
**受击朝向语义（2026-09-20 决策定档）**：纵向攻击命中**不改写**防守方面向——hurt/击飞
动画的 left/right 选择沿用防守方上一次水平 `facing_x`（与上下跳跃动画同源机制；全项目
facing_x 只有 locomotion/mid_air 两个写入者，受击链零触碰）。曾议"北来→强制right/
南来→left"映射方案，已否决不实现。锁：attack_lane_contract B7/B8/B9。

---

## 5. 动作状态机系统 (Action States)

### 5.0 输入通道与行为脚本（2026-09-14 单壳架构改造）

**设计**：所有角色（玩家/AI/被动）共用同一种壳与同一套动作状态，"能做什么"完全
一致；"谁发号施令"由挂在角色下的**行为脚本**决定。差异被收敛为：每具角色体内存
在一个私有输入通道，动作状态只认通道，物理键盘事件永远不会到达非玩家角色。

```
QuiverCharacter
 ├─ channel: QuiverInputChannel        # characters/quiver_input_channel.gd（私有"虚拟手柄"）
 │    ├─ axis: Vector2                 # 摇杆歪向（走路/空中控制的唯一方向来源）
 │    ├─ _held{动作名: bool}           # 按住名单（walk 持续、抓取方向键挣脱等）
 │    └─ _edge_tick{动作名: 物理帧号}   # "刚按下"边沿：盖帧戳、读一次即消费、超龄清理
 │
 └─ behavior: QuiverBehavior           # characters/behaviors/，运行时按 behavior_mode 挂载
      ├─ QuiverBehaviorPlayer           # 0 玩家操控：全场唯一 OS 听众
      │    ├─ _unhandled_input → 通道盖戳 + state_machine.deliver_event(转投)
      │    └─ pre_physics → channel.refresh_from_os()（摇杆+全量 InputMap 按住扫描）
      ├─ QuiverBehaviorAI               # 1 AI：策略小抄（角色自己的 <名字>_ai.gd 继承它）
      │    └─ pre_physics → tick()：move_towards/press_attack 等写通道、投合成事件
      └─ QuiverBehaviorIdle             # 2 被动：零写入（站桩/路人/活道具）
```

- **事件路径**：动作状态中 `event.is_action_pressed(...)` 的判读代码**零改动**——变化
  只在事件来源。玩家=转投真实 OS 事件；AI=`deliver_event(InputEventAction 合成)`。
  连段窗口机制对两者天然同构（AI 连段水平=它再按的时机）。
- **轮询路径**：`Input.get_vector/is_action_pressed` 共 10 处已改为
  `_character.channel.axis / .is_held(动作)`（涉及 Idle、Locomotion、Landing、
  MidAir、GrabIdle）。全插件运行时读物理键盘只剩通道内 `refresh_from_os` 一处。
- **输入窗口**：`QuiverStateMachine.input_window_open`（显式属性）。原先通过
  `set_process_unhandled_input(bool)` 实现的连段/空中攻击窗口已全部改用此属性。
  ⚠ **引擎陷阱**：不要用 `is_processing_unhandled_input()` 做门控——Godot 4 会按
  "脚本是否覆写 `_unhandled_input` 虚函数"**自动改写**该原生标志（本状态机已不覆写，
  该标志恒为 false）。
- **盖戳语义**（2026-09-15 定罪修正）：引擎未处理输入流只广播**带动作匹配结果的
  原始事件**（对 `event.is_action_pressed(动作)` 可判），**不会**广播合成的
  `InputEventAction`。`QuiverBehaviorPlayer._stamp_action_edges` 因此对原始事件
  逐动作做语义匹配盖戳；`InputEventAction` 分支仅服务于 AI 合成投递等直连
  `deliver_event` 的来源。旧实现"只认 InputEventAction 类"导致真实键盘法术键
  静默无效（J 攻击幸存因状态内用 is_action_pressed 匹配原始事件）。
- **泵水顺序**：`QuiverCharacter._physics_process` 首行依次
  `channel.prune_stale_edges()` → `behavior.pre_physics(delta)`。父节点先于子节点
  执行，行为脚本写入的值在本物理帧内即可被状态机读到，不依赖场景树节点顺序。
- **根脚本键**（法术 spell_1..4）：改在角色根脚本 `_physics_process` 轮询
  `channel.just_pressed("spell_X")`（chen.gd / 模板同）。角色相关脚本不再有任何
  `_unhandled_input` OS 听众。法术 Run Test 的注入脚本**不再轮询**（边沿读一次
  即消费、父先子后必抢不过），只负责 `host.learn_spell()` 教给被测角色。
- **运行时交接**：`QuiverCharacter.switch_behavior(mode)` 换挂行为（通道保留、
  旧操控者状态清零）。这是"剧情附身/队友接管"的接口位。
- **行为总开关 `QuiverBehavior.active`（产品级原语）**：false 时该类行为停止一切
  通道写入/事件投递，宿主自然回落待机，受击/死亡反应照常（碰撞信号不经输入）；
  关闭瞬间通道 reset 防残留。统一取代早期玩家侧的 `input_enabled` 提案。
  用途：过场定身、伏击待命、测试发令台等，一律由**外部驱动**，行为子类不自改。
- **多玩家提醒**：两个 PLAYER_INPUT 行为共存时 push_warning（允许共存便于双打测试）。

**退役清单（文件保留仅供考古，禁止用于新角色）**：`quiver_action_idle_ai.gd`、
`quiver_action_follow.gd`、`quiver_action_die_ai.gd`、`quiver_enemy_character.gd`、
`characters/ai/`（11 块 AI 积木状态 + QuiverAiStateMachine）。它们的动机（免键盘动作
变体、AI 专用树、受击打断接线）在通道架构下分别由"事件来源隔离 / 小抄直接驱动原树 /
QuiverBehaviorAI.on_hurt"承接。

**宿主资源等待熔断（2026-09-19 补）**：`QuiverBehaviorAI._connect_attributes`
等宿主 `attributes` 就绪采取**有限重试**（240 帧，到限 `push_error` 放弃）。
无上限 `call_deferred` 自我排队的旧形态在"资源链加载失败"场景（如 headless
缺 `--import` 产物致 attributes.tres 载不进）会打爆引擎消息队列直接 SIGSEGV
（wp2 verify 崩溃案）——配置/资源性错误必须表现为可读报错而非进程炸弹。

**皮肤方向契约（2026-09-14，两阶段事故复盘后的终态）**：
`QuiverCharacterSkin.skin_direction` 接受**任意世界方向向量**，setter 用
`snap_to_blend_basis()` 把它**量化到八向混合基**（吸附最近 45° 档、输出单位顶点
向量）。契约依据：美术只有 8 个离散朝向，**动画选择必须与美术同基**——量化后
BlendSpace2D 落点与节点位置精确重合，引擎永远单动画满权重，"对动画名字符串/
帧号做混权算术"的代码路径物理不存在。

事故两阶段（同一个病根——旗子落在了图钉之间——的两种死法，临时诊断探针取证）：
① AI 连续角度的单位向量掉出八边形凸包 → 权重全零无动画可播 → **隐形幽灵**；
② 中间态"径向投影到边"（已被本量化方案替换删除）把落点送进两边之间 → 引擎
多权重混合 `:animation` 字符串轨道触发**内存级损坏**（动画名逐帧漂移乱码，
每运行各异，控制台 `get_frame_count: Animation '<乱码>' doesn't exist`）。
玩家八键输入的角度全部是量化不动点 → **对既有手感数学零变化**（性质测试
25 项：不动点/全圆扫描恒出八顶点/角差≤22.5°/幂等/零向量）。
移动与速度使用原始连续向量，不经此量化，AI 走位依然平滑，仅贴图朝向按档跳。

**回归验证**：`tools/input_channel_test/test_runner.tscn`（headless 17 断言：通道单元
语义、玩家移动/攻击链路、被动角色不被物理键盘劫持、窗口门控、AI 注入链路）与
`tools/blend_domain_test/project_test.gd`（25 项几何性质断言：玩家八向/键盘原始形态
不动点、全圆扫描恒出八顶点且角差≤22.5°、AI 连续方向吸附、零向量、幂等）。

#### 5.0.1 生产线接线（WP2，2026-09-14）

- **模板 token 扩展**（`tools/sync_template_from_chen.py` 注入 + `character_creator.gd` 替换）：
  `__PKG__`（阵营包目录 playable/enemies/allies/neutrals）、`area2d:__FACTION__`（根节点阵营
  标签唯一存放点）、`__BEHAVIOR_MODE__`（主场景根属性行）。主 tscn 注入由同步脚本做正向断言保护。
- **默认策略小抄**：模板自带 `__NAME___ai.gd`（`class_name __CLASS__AI`，QuiverBehaviorAI
  子类：歇→追→Combo 跟进三段→受击定身 0.8s），sync 工具 KEEP_IN_DST 豁免。玩家档角色
  该文件闲置无害。
- **约定加载**：AI 档 `ai_policy_script` 导出未配置时，`QuiverCharacter`
  自动加载同目录 `<场景文件名>_ai.gd`（FileAccess 判定，不依赖导入扫描）——创建器因此
  只需替换一个整数 token，无需 ext_resource 手术。
- **创建器**：`CharacterCreator.ControlMode` + `resolve_layout(mode, faction)` 统一裁决
  目录/档位（阵营标签与目录解耦：玩家→playable+player、AI→enemies+enemy、
  被动→neutrals+自名，标签可自由改/多选；索敌按 area2d:player 组查询）；
  `CharacterDeleter.delete_character(name, pkg)`。面板新增"控制方式"下拉与阵营联动。
- **Run Test 生成**：纯逻辑抽出为 `QuiverRunTestSceneBuilder`（RefCounted 静态类，
  headless 可测）`compose()` 统一编排：读 behavior_mode → 玩家档=被测者当主角、
  注入正式对手 `spar_enemy`（缺失则空场，优雅降级）；非玩家档=主角换 chen（操作锚）、
  被测者作为对手实例注入（AI 自动追打 chen = 天然验收），并把两个调试数据窗口
  "显示谁"的设置改指被测者——**测谁看谁**。生成物模板已不含任何敌人引用；
  旧 enemy 块剥离逻辑保留为保险丝。角色/法术两个 Run Test 模板同此。
  （镜头不跟随被测者：它挂在主角下，测怪时 chen 才是可操作视角锚。）
- **调试窗口的角色指向（2026-09-15 教训）**：窗口脚本用
  `@export var character_path: NodePath` + `_ready` 时 `get_node_or_null()` 解析。
  曾经的 `@export var character: CharacterBody2D` 节点对象引用型导出在**文本赋值
  NodePath 时引擎不转换为节点引用（恒 null）**，窗口一直靠"自动找场上第一个角色"
  的兜底运行——所以"改配置指向被测怪"不生效、测怪物永远显示 chen 的数据。
  端到端断言 `tools/wp2_creation_test/overlay_e2e.tscn` 锁定该行为（真实帧验证）。
- **AI 发令台 `TestSceneAIConductor`**（由 `QuiverRunTestSceneBuilder.compose()` 统一
  注入，角色/法术两类 Run Test 场景皆有——早期只挂角色模板，法术场景的 chen 曾被
  陪练白打死，2026-09-15 迁入编排器根治）：场景就绪把
  场上所有 AI 档行为置 `active=false` 待命，**Enter** 开始/暂停（可反复，便于
  "摆位→再战"式复测）。它是 `active` 原语的第一个驱动者，测试台专属、正式关卡不挂。
  **底版统一（2026-09-15）**：角色/法术测试场景共用 `QuiverRunTestSceneBuilder.base_scene_text()`
  唯一模板，法术差异全部经 `add_spell_test_kit()` 注入（改 Run Test 布局=只改底版一处；
  2026-09-16 批2/批3 追加：底版统一注入 `DebugDockOpen`（调试坞入场自开声明组节点）
  与 `GameHUD`（正式 HUD 实例，跟 players 组）；kit 不再注入文字诊断面板（已迁 DebugDock[诊断]页），
  kit 的 load_steps 增量由 +2 改 +1；详见 docs/HUD_DESIGN.md）
  数据窗口在法术场景被挤到右列 x=845 避让法术面板）。
  键位避让备忘：1-4=法术（InputMap spell_1..4），5-8=昼夜相位调试（原 1-4，2026-09 让位），O=光照覆盖，T=阴影区域，L=软边，J/Space/WASD=战斗，Enter=AI 发令台。
- **正式验证角色（内容资产，进 git）**：`characters/enemies/spar_enemy/`（AI 档，
  默认小抄：歇→追→三连段；Run Test 玩家场景的常驻陪练——删除它会改变测试场景编排，
  建议保留）、`characters/neutrals/street_vendor/`（被动档站桩样板）。
- **旧 enemy 魔法替身已退役**（2026-09-14）：`characters/playable/enemy/`（含
  enemy_periodic_attack / enemy_hurt_handler 拨皮肤 hack）整目录删除，gitignore
  例外同步移除；其历史职责由 AI 档正式角色承接。
- **阵营包目录**：`characters/enemies|allies|neutrals/` 纳入 git（.gitkeep 占位）。

**回归验证**：`tools/wp2_creation_test/`（create 30 断言 + verify 6 断言，两阶段夹
一次 `--import`；scene-gen 15 断言）、`tools/wp3_formal/`（spawn 幂等生成正式角色 +
verify 5 断言：小抄约定加载、逼近、伤害、站桩）与 `tools/conductor_test/`
（发令台 9 断言：待命/零位移/Enter 开令/逼近/再按暂停/通道清零）。

### 5.1 通用状态机框架

**基类**: `utilities/custom_nodes/state_machines/quiver_state_machine.gd`
**类名**: `QuiverStateMachine`（继承 Node，`@tool`）

```gdscript
signal transitioned(state_path)      # 每次状态切换时发射

@export var initial_state: NodePath  # 初始状态路径
@export var should_process_input := true   # 总闸（长期屏蔽输入时用）
var input_window_open := true               # 连段/空攻窗口（见 5.0 引擎陷阱）

var state: QuiverState               # 当前激活的状态
var state_name: NodePath             # 当前状态路径
```

**生命周期与输入管道**:
- `deliver_event(event)` → 三重门控（`should_process_input` → `input_window_open` →
  state 有效）后 → `state.unhandled_input(event)`。**本节点不再监听物理键盘**
  （旧 `_unhandled_input` OS 管道已拆除，串台漏洞自源头消灭，见 5.0）
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
| Idle | Idle→Move→Ground | Idle(读通道) → Move(apply velocity + move_and_slide) → Ground(track ground_level) |
| Walk (Locomotion, _is_walk_mode=true) | Walk→Move→Ground（enter 加 modifier 降速） | Walk(读通道+转身) → Move → Ground |
| Run (Locomotion, _is_walk_mode=false) | Run→Move→Ground（enter 无 modifier） | Run(读通道+转身) → Move → Ground |
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

### 5.7.1 击飞链父状态 (`quiver_action_knockout.gd`, `QuiverActionAirKnockout`)

子状态 `Launch / MidAir / Bounce`（装配于 `Air/Knockout/`）：起飞→空弹按 vy 切
rising/falling→触地 Bounce→（活）`Ground/Recovery` 或（死）`Die`。家长职责：

- **委托枢纽**：子状态 enter 回头喊 `parent.enter`（`_launch_count` 区分首次
  launch 动画与再起飞 rising 动画）；链唯一收口在 `Bounce.exit` 的条件喊
  （`_has_landed` 或已死）→ `parent.exit()` 归零 `_launch_count`
- **`in_knockout` 弹墙旗唯一写入者**：`enter()` 置真（幂等，空中再击/弹墙复飞
  重复喊无副作用）、`exit()` 归零——弹墙结算与死亡分支泄漏的闭环全在此，详见
  7.3 墙壁反弹机制
- 监听 `hurt_requested / knockout_requested / wall_bounced` 三信号做链内再起飞/
  反弹（`wall_bounced(mirror_axis)` → `transition_to(Launch, {is_wall_bounce, mirror_axis})`
  → Launch 对速度做**真镜像** `velocity.reflect(axis)`；镜像输入=完整撞击速度这一
  时序前提由"带内墙外"几何保证（见 8.4 带墙分离摆位），不靠任何注入或记存）
- `_handle_bounce()`：触地即 `velocity.x=0`（A3 甲案落地即停）+ 转 Bounce

**皮肤侧配套（审计教训 2026-09-19）**：AnimTree 的 `knockout_ground` 节点**不是**
单动画而是**嵌套子状态机**（`Start→knockout_landed→getting_up→End` 自动转换，
倒地+起身两拍）。对账"动画轨道/状态覆盖"时只查状态机装配会漏判此层（本批曾
因此险些把在工作的 landed 轨道误判死轨道）。

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

### 5.10 Cast 施法状态（游戏层自定义示范 `_beat_em_up/action_states/quiver_action_cast.gd`）

"攻击的同款骨架去掉连段"：`QuiverCharacterAction` 子类，挂在角色场景
`StateMachine/Ground` 下（chen.tscn 与模板 `__NAME__.tscn` 均已挂，`_skin_state=&"spell"`）。

- **与攻击的机制差异——两段式**（契约详见 docs/SPELL_SYSTEM_DESIGN.md 17.1）：起手槽
  `_start_state`（spell_start，非循环，尾帧 end_of_skin_animation 方法轨道宣告完成，
  时长=角色资产自然长、必完整播放）→ 收到信号切引导槽 `_loop_state`（spelling，
  循环保持姿势，时长=`SpellDefinition.caster_cast_time` 由本状态倒计时）→ 归零调用
  SpellManager 投递的 `release` 出手并转 `_path_next_state`。缺槽降级不改计时。
- **承诺制**：法力/冷却由 SpellManager 在**起手瞬间**扣除；咏唱中被打断
  （Ground 现成 hurt/knockout 信号链）法术作废、不退还。
- **输入窗口**：enter 关闭（`input_window_open=false`，攻击键无法把施法切走），
  exit 重开；`transition_to` 程序转换不受窗口影响，打断照常。
- **动画槽**：`spell` 槽已入模板（四点混合暂指单一动画，新角色出生即有）；**降级**
  分支（不播动画但锁满时长、单皮肤一次性告警）保留给缺槽皮肤（spar/street_vendor
  等历史资产与外部改皮），见 docs/SPELL_SYSTEM_DESIGN.md 17.1。
- **闸口**（SpellManager 侧）：咏唱中拒绝再起手；空中（Air 子树）拒绝起手；
  `caster_cast_time=0` 或未挂 Cast 节点的角色维持旧瞬发行为（向后兼容）。

### 5.11 姿态状态（Block 格挡，游戏层 `_beat_em_up/action_states/quiver_action_block.gd`；2026-09-23 S2-B3）

**仓库新判例：状态"不在场"也能自选进场——引擎虚函数自武装**。状态机只把
`physics_process/unhandled_input` 转发给**当前激活状态**（§5.2），但节点自身的
**引擎虚 `_physics_process` 无论在场/不在场每帧都跑**（`quiver_state` 仅编辑器
hint 下关处理；2026-09-23 全仓状态节点零第二覆写者实锤）。姿态类状态
（格挡/架枪/蓄力一类"条件成立即自动进、条件消失即自动出"的站桩态）据此
零插件核心手术完成闭环：

```gdscript
func _physics_process(_delta):
	# 在场管出（松键回 Idle）；不在场管进（按住 + 当前态在白名单）
	if sm.state == self:
		if not _character.channel.is_held(&"block"):
			sm.transition_to(_path_idle_state)
	elif _character.channel.is_held(&"block") \
			and StringName(str(sm.state.name)) in _entry_whitelist:
		sm.transition_to(sm.get_path_to(self))
```

- **输入只认私有通道**（`channel.is_held`，§5.0）——OS 链端到端由
  block_parry_contract Q 流（raw 键直投）锁死；`StringName` 显式转换是
  类型陷阱防线（`sm.state.name` 转回 StringName 再入白名单比较，裸 `in` 恒假）。
- **进入白名单**：转移图=代码约定（AGENTS 状态机章口径），默认
  `Idle/Walk/Run` 三个 locomotion 节点；白名单外（攻击/受击/击飞子树）
  持键也不得自入（P11c 全录像锁：击飞→恢复途中逐帧零 Block，落地回
  Move 后回流起架属设计语义）。
- **单写者纪律**：格挡成对旗 `is_blocking`/`block_started_frame` 的唯一生产
  写方=本状态 enter/exit（同帧成对，R4 宪章）；判定缝只读；打断走 Ground
  挂线（hurt/knockout 信号链在姿态下仍武装）→ exit 照跑注销旗=闭环
  （P11 活体：键仍按住时白名单拒回流）。
- **姿态期间**：输入窗关闭（`input_window_open=false`，Space 跳跃不劫持，
  Cast 同款）；`velocity` 逐帧钉死=站桩；伤害结算**不在本状态**——全在
  QuiverHurtBox 判定缝读成对旗（§7.3），本状态零数值。
- **缺槽降级**：`_skin_state` 动画槽缺失=单皮肤告警一次+姿态逻辑照常
  （Cast 阶梯同款精神；真防御动画到货仅改导出、同名替换纪律）。

回归锁：`tools/block_parry_contract/` Q 流（P7/P10/P11）；数值委托 API
（`apply_damage_value`）与其上三分支见 §7.1/§7.3。

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
# KnockbackStrength 五档枚举已退役（2026-09-18 统一模型，见下）

func is_in_same_lane_as(defender, attacker) -> bool      # 横攻：比"排"(Y)
func is_in_same_column_as(defender, attacker, defender_x, attacker_x) -> bool  # 纵攻：比"列"(X)
func apply_damage(attack: QuiverAttackData, target: QuiverAttributes)
    # 薄委托（2026-09-23 判定缝批）：既有签名逐字保留，转调 apply_damage_value；
    # 弹墙等"整包 attack_data"调用方零感知
func apply_damage_value(p_damage: float, target: QuiverAttributes)
    # **数值伤害唯一入口**（spec §6.2）：无敌免疫 → 扣血 → HitFreeze 默认 3 帧。
    # p_damage 是 float 且**本层不取整**（判定缝的输出/格挡乘算全程浮点，
    # health_current 为 int 存储、整值 float 无声吞收——探针 D 实锤）；
    # 攻击数据是共享导出资源严禁 mutate，一切缩放由调用方算好后走本入口
    # （防 emit_changed 判例；这也是姿态/弹反等"改伤害数值不改 attack_data"
    # 类规则的统一委托 API）
func apply_knockback(knockback: QuiverKnockbackData, target: QuiverAttributes)
```

**攻击流程**:
1. `apply_damage_value`（或经 `apply_damage` 薄委托）→ 扣血 → 触发 `HitFreeze`
   （命中的顿感；免伤路不经过此处——弹反支必须自发拍定格，见 §7.3 判定缝）
2. `apply_knockback` → 转交 `QuiverAttributes.apply_knock`（**唯一判定点**），按裁决分发：
   `launched` → 写入 `impulse` 后发 `knockout_requested`；`swallow` → 静默（含霸体
   与空中零击打值）；否则 `hurt_requested`——分发器为纯三向开关，无战斗政策

**击飞统一模型（2026-09-18 重构定档，五档计分表/阈值线全退役）**：
- 货币：招式击打值 K（`QuiverAttackData.knock_strength`，浮点）× 角色抗击打额度 R（`knockout_resistance_max`，默认 600）
- 地面：K ≥ 余量 → 起飞，**冲量 =（K − 余量）+ 保底 50**（`LAUNCH_MIN_IMPULSE`），余量清空；
  K < 余量 → 硬直扣量。保底语义=破线最弱表现是"绊倒"（完整走完起飞→弹地→起身链）
- 死亡：绕过额度强制起飞，冲量 = K + 保底；**空中**（含弹跳段 is_on_air）：额度视作已空，
  K>0 即再起飞（连空即时，不等弹跳动画播完——旧 bounce 末尾补飞分支因此退役）；
  K≤0 吞事件（零击打值弹体不打断弹道）
- 霸体=击打值完全无效（G2 归零制，经 swallow 裁决自含表达；旧"憋霸体攒计数器"通道取消）
- 回气：`Move.enter` 与 `_handle_landing`（落地瞬间）→ `refill_resistance()` 回满
- 落地即停（A3 甲案）：`_handle_bounce` 显式 `velocity.x = 0`——飞行水平速度全程无
  衰减（无人写它、落地非物理碰撞），不清零会以僵尸残值叠进下次起飞（连抽越抽越快）
- 起飞 `_launch_charater(impulse, launch_vector)` 改收结算冲量，不再读计数器；
  权重与封顶（2000）语义不变
- 契约测试：`tools/knockout_contract/`（26 断言，含弹道打表观察）

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

**命中回执注入 `var on_target_hit: Callable`**（2026-09-16 调研定档新增）:
- 持有者（如法术本体）在装配时机注入 `Callable(自己, "on_hit")`；受击盒结算完
  伤害后**同步** `call(目标受击盒)`。留空=不通知（近战角色现状，零影响）
- 契约：必须同步送达，**严禁**改 `call_deferred`/延迟信号（帧末真删除，延迟窗
  口会撞上已释放对象）
- 决策记录：旧式 `hit_box.owner.has_method("on_hit")` 反射被废除——`owner` 只认
  一道场景边界（弹体攻击盒的 owner 是皮肤非弹体本体），字符串方法名无类型检查
  且失配静默跳过，导致法术命中通知"从诞生即断"全程无报错（GDQuest 正典的
  duck-typing 前提是"组件直挂被通知者场景根"，皮肤嵌套令前提失效）。
  Godot 4 决策表对应项："节点需外部行为 → 依赖注入"；Callable 一等公民、
  绑定点编辑器可查错。防回归：`tools/spell_hit_test/`（命中即灭/双弹配对/
  僵尸回执三组断言）。

### 7.3 QuiverHurtBox（受击判定框）

**文件**: `combat/collision_areas/quiver_hurt_box.gd`
**类名**: `QuiverHurtBox`（Area2D，主动监听者）

**主动**: `monitoring=true, monitorable=false`。`collision_layer` 和 `collision_mask` 由 `QuiverCharacter._update_hurtbox_layers()` 动态管理（高度层）。

**`_on_area_entered()` 分发**:

| 进入的 Area | 方法 | 后续 |
|---|---|---|
| `WallHitBox` | `_handle_wall_hit_box()` | **先过 `in_knockout` 状态门**（链外静默免结算）→ 放行时 `apply_damage(墙 attack_data)` + `wall_bounced(墙.mirror_axis)` |
| `QuiverHitBox` | `_handle_hit_box()` | 判定缝三分支（弹反/格挡/常规，见下；不防时= `apply_damage_value` + `apply_knockback` 原样） |
| `QuiverGrabBox` | `_handle_grab_box()` | `grab_requested` 信号 |

**注意**: 阵营检查 `are_factions_equal()` 在 `_on_area_entered()` 入口处统一执行，同阵营直接 return，不再在各个 `_handle_*()` 方法中单独检查。

**`_handle_hit_box()` 判定缝三分支**（S2-B3 spec §2.3，2026-09-23；唯一插入点
= `_can_be_attacked_by` 门后，门本体不变：非无敌 + 车道命中，横攻比排/纵攻比列，
选轴读 `attacker.skin_direction` 出手镜像，见 §4 车道家族）:

1. 读输出乘数 `out_mult = hit_box.character_attributes.attack_output`——弹体的
   `character_attributes` 绑**施法者**属性（spell_base.gd:74 探针实锤）⇒
   输出缩放天然走施法者侧读取；null 仅防御性兜底。
2. 防守方 `defender_attrs.is_blocking`？（成对旗读值，`delta =
   Engine.get_physics_frames() − block_started_frame`，窗读**受管字段**
   `parry_window_frames` 当前合成值——重算回写使判定代码零感知修饰存在）
   - **弹反支**（`delta < 窗`，严格 `<`：按下帧 delta=0 起算共窗帧数，
     delta==窗 归格挡）：**免伤免退**——零伤害、防守方池一分不扣、不进受击态；
     `HitFreeze.start(_PARRY_FREEZE_FRAMES=6)` **自发拍**（免伤路不经
     apply_damage_value，遗忘本拍=静默无反馈假绿族）；双方白闪同拍（防守强档+
     攻击弱档；形制=运行时混白 shader 换挂皮肤精灵 `material` 摘回原底材——
     LDR-2D 下 modulate>1 被钳制不可见，2026-09-24 修订，见 spec §2.4 注记）；
     `apply_knockback(K=_PARRY_STUN_KNOCK=60)` 反顶**攻击者本人**的
     池——统一模型判则不偏袒攻守（攻击者余池将破则自动升格 knockout，
     P9 实证；霸体鼠洞知情条款：apply_knock 归零制吞 K 不发信号=对护甲敌
     弹反空转，B5 都尉若发护甲须正式裁决，届时改规则不改这里）。
   - **格挡支**（超窗按住）：`apply_damage_value(原伤害 × out_mult ×
     block_damage_ratio)`；**该击击退值整颗作废**（不回池、不派发、不换算——
     "重击变轻拳、飞天变站桩"的全部真相，P10 活体）；防守方弱白闪。
   - **常规支**（未防）：`apply_damage_value(原伤害 × out_mult)`
     （out_mult==1.0 时与改造前逐字等价——lane 契约 P1 哨兵锁）；构造
     `QuiverKnockbackData`（treated launch_vector 让角色**始终向后飞**）→
     `apply_knockback` 照旧。
3. **公共义务（三分支一律）**：`hit_box.on_target_hit.is_valid()` 时同步
   `call(self)`（见 7.2 注入契约；旧 owner 反射已废除）——弹体靠它回执离场，
   任何分支绕过=穿体飞到超时判例同族（回归锁 P6c/P8e：命中帧起 ≤15 帧离场护栏，
   堵 max_lifetime=300f 与采样窗同缘的假绿边角）。
4. 规则常量单一出处（数值治理法第 2 档）：`_PARRY_STUN_KNOCK/_PARRY_FREEZE_FRAMES/
   _FLASH_*` 全部定义在 quiver_hurt_box.gd 常量区，禁散落魔数。

**时基判例（Step0 探针 2026-09-23 实锤）**：定格期间 physics_frame 信号照响、
全局物理帧号照走 ⇒ 在途 HitFreeze 真会蚕食弹反窗帧——Block.enter 写
`block_started_frame`=按下瞬间读数，蚕食属规则本意（spec §10 帧计数定案），
手感疑案先疑此勿疑缝。

**阵营过滤机制**（`area2d:` group；2026-09-17 单一存放点体系）:
- **数据只存角色根节点**（`groups=["area2d:<标签>", …]`，创建表单写入）；
  `QuiverCharacter._ready → _distribute_factions()` 运行时经 `add_faction_group`
  下发到 HurtBox/HitBox——皮肤场景不存阵营数据；配置警告：根无标签=会自伤
- 身份查询（HUD/AI/检测器）也按 `area2d:player` 组，但**必须过滤
  `is QuiverCharacter`**——组里同时有下发后的战斗盒
- **法术体根节点保持阵营中立**：`add_to_group` 只挂战斗盒，混入身份组=查询污染
- （历史坑，2026-09-19 已灭绝）旧 `area2d:wall` 伪阵营时期：两只 HurtBox 互比会
  因共享 wall 假判同阵营，取样必须用"攻击盒×受击盒"真实配对。现墙已退出阵营
  系统（弹墙改为 `in_knockout` 状态门，见 7.3 弹墙节），该污染源头不复存在
- 常量 `FACTION_PREFIX = "area2d:"`（定义在 QuiverHurtBox）
- 缓存机制：`_faction_dict: Dictionary` 只缓存 `area2d:` 前缀的 group，使用 Dictionary 实现 O(1) 查找
- **运行时动态加阵营组必须走 `add_faction_group(group)`**（HitBox/HurtBox 公开）：
  引擎陷阱（2026-09-15 实测）——GDScript 对静态类型变量调用 Node 内建方法时直连
  原生绑定，**绕过**脚本层的 `add_to_group` override，只靠 override 刷新缓存会让
  typed 调用点静默失效（法术继承施法者阵营时踩中，表现为法术自伤施法者）。
  **脚本内裸自调用同罪**（2026-09-19 实证补案）：`WallHitBox._ready` 里
  `add_to_group("area2d:wall")` 正是隐式 self 的 typed 直调，绕过 override 令
  缓存恒空 → 走路贴相机弹墙带每次 -5（F5 定罪案）。经 Variant 变量调用才会
  触发 override。规则：**触碰 `area2d:` 组只许走 `add_faction_group`**
  （其内部"裸调用 + 显式 `_refresh_faction_cache()`"对两种派发路径都正确）。
- `_ready()` 时初始化缓存，捕获 `.tscn` 中声明的 groups
- 重写 `add_to_group()`/`remove_from_group()`，捕获运行时的 group 变更
- 静态函数 `are_factions_equal(hit_box, hurt_box)`：两侧都使用 Dictionary 缓存，自动选择小集合遍历，回退到实时构建 Dictionary
- 同阵营双方的 HitBox/HurtBox 不会互相造成伤害/抓取
- 配置方式：在 .tscn 中为角色的所有战斗 Area2D 添加 `groups = ["area2d:角色名"]`
- `_handle_grab_box()` 同样使用此检查
- QuiverHitBox 和 QuiverHurtBox 都实现了相同的缓存机制

**墙壁反弹机制**（`in_knockout` 门 + 带墙分离 + 真镜像，2026-09-19 终案）:
- **墙不是阵营**：角色盒子与墙盒都不挂任何 `area2d:` 组（旧 `area2d:wall`
  伪阵营机制全链退役——它因缓存失同步导致"走路贴墙掉血"F5 案，且三处溃伤在案）
- `QuiverAttributes.in_knockout`：击飞链生命周期旗，**唯一写入者**是击飞链父
  状态 `QuiverActionAirKnockout` 的 `enter()`（置真）/`exit()`（归零），与
  `_launch_count` 归零同括弧；链唯一出口在 Bounce（落地恢复/死亡两分支），
  无泄漏路径；实例重建天然为假
- `QuiverHurtBox._handle_wall_hit_box()` 进门先过这道门：链外（走路/受击/起身）
  贴相机弹墙带**静默免结算**；链内撞墙才结算 `apply_damage(墙 attack_data)` +
  `wall_bounced.emit(墙.mirror_axis)`（击飞状态监听 → 真镜像复飞）
- 前置条件归处理器自持（与本文件 `_can_be_attacked_by` 家族同款分工），
  `_on_area_entered` 保持纯类型路由
- **reflect 语义真值表**（引擎源码 `2(v·n)n−v`，knockout_contract D7 断言在引擎里
  钉死）：`reflect(UP)` 以竖轴为镜像→翻水平分量（左右墙用）；`reflect(RIGHT)` 以横轴
  为镜像→翻竖直分量（上下墙用）。镜像轴是**墙自带数据**（WallHitBox.mirror_axis
  导出），判定端零几何发明——上游原行 `reflect(Vector2.UP)` 对竖墙本就正确
- 回归锁：`knockout_contract` D 段（真实 Area2D 物理重叠级：链外免伤/链内
  扣血反弹/出链复位/旁观者零误伤/组纯度哨兵/reflect 真值表(D7)/带墙分离几何锁(D8)），
  fixture `tools/knockout_contract/wall_band.tscn`；端到端弹回：stage_contract C3.5

### 7.4 QuiverAttackData（攻击数据）

**文件**: `combat/quiver_attack_data.gd`
**类名**: `QuiverAttackData`（Resource，`@tool`）

```gdscript
@export var attack_damage: int          # 基础伤害
@export var hurt_type: CombatSystem.HurtTypes     # HIGH 或 MID（硬直动画类型）
@export var knock_strength: float     # 击打值 K（连续量；0=纯伤害不碰额度）
@export var launch_angle: float         # 发射角度（degree, 0-360）
var launch_vector: Vector2              # 自动从角度计算
```

每次修改 `launch_angle`，setter 自动计算 `launch_vector`。

### 7.5 QuiverKnockbackData

**文件**: `combat/quiver_knockback_data.gd`
**类名**: `QuiverKnockbackData`（RefCounted，瞬态数据，不持久化）

```gdscript
var knock_value := 0.0   # 输入：本击击打值 K
var impulse := 0.0       # 输出：apply_knock 裁决的起飞冲量（未破线=0）
var hurt_type: CombatSystem.HurtTypes   # 仅地面硬直分支消费（选动画）
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
  Player HitBox groups: ["area2d:player"]  ← 运行时自根节点下发
  Enemy HurtBox groups: ["area2d:enemy"]
  无交集 → 不同阵营 → 继续处理
  ↓
_handle_hit_box() 判定缝三分支（§7.3；敌未防时走常规支）
  ↓
常规支：CombatSystem.apply_damage_value() → HP 扣减 → HitFreeze（顿感）
CombatSystem.apply_knockback() → apply_knock 唯一判定 → hurt_requested 或 knockout_requested
（格挡支=乘算扣血+击退值整颗作废；弹反支=免伤+反顶攻击者池+自发定格——均无下列派发）
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

内部调用 `_level_camera.delimitate_room(left, top, right, bottom, zoom, duration)`——
该方法现**返回本次 Tween**，战斗房借此挂 `finished` 做**落位收口**（2026-09-19 契约）：

- **`_clamp_players_into_room`**：过渡完成后，任何中心落在
  `[limit+m, limit−m]`（**m=−40 外扩**，2026-09-19 调档随墙外挪：矩形须包含
  合法贴墙位 线−25，只抓真被扫掠落在墙外的人）钳回（只改位置
  不清速度）。背景：相机隐形墙随推近 Tween 扫掠，0.8s 过渡里退到缝隙后方的
  玩家会被落在实体墙背面（扫掠吞人 F5 案）——语义="锁房动作不许把任何人留在
  墙外"；参考实现与回归锁见 stage_contract C2.5。
  **树守卫（2026-09-21，S2 容器批）**：函数首行 `is_inside_tree()` 早退——
  tween.finished 迟到时本房间可能已被章节壳摘树（清场缓存段走 `remove_child`
  保活腿：房间出树不死），`get_tree()` 为空即炸（spike C2 实锤）；与壳切换
  90 帧静默窗构成双保险，回归锁 container_contract E7（子进程指纹判分）。
- **`_fit_zoom`（夹紧纯函数）**：战斗 `zoom` 走属性 setter、`after_fight_zoom`
  在 setup 时消费，两路共用同一式（zoom ≥ 主轴"房间收进视口"比）。此前 after
  路径裸值消费不夹——after 房一旦宽过视口即把墙推出镜头=无条件出屏。

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

**`_on_body_entered(body)`**: 若 body 持 `area2d:player` 标签 → 发射
`player_detected`（2026-09-17 阵营体系定档后不再是 "players" 组）。

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

**一波多兵的安全性**：靠 `QuiverEnemyCharacter._ready` 的 attributes
`duplicate(true)` **断根级共享**（R11，§2 案卷；b3 收口波实测：隔离由
duplicate 调用本身完成，浅/深零可观测差）——同场景实例化 N 只各自独立血/池/
修饰账本；
转型 `as QuiverEnemyCharacter` 意味着喂进 spawner 的必须是敌人壳（创建器
AI 档死结挂 B5，见 §2）。

### 8.4 QuiverLevelCamera（游戏摄像机）

**文件**: `utilities/custom_nodes/level_camera/quiver_level_camera.gd` + `.tscn`
**类名**: `QuiverLevelCamera`（继承 Camera2D）

**四个核心职责**:
1. **屏幕边缘碰撞墙（四方向）**: 每帧更新四个 CollisionShape2D——墙面=
   min/max(房界, 视口沿) 取紧者再**外挪 WALL_OUTSET_*（横 60 / 竖 30）**：贴横墙
   出界约 3/4 身位、贴上下墙约 2/3（深度轴出界更抢画面故收紧；用户 2026-09-19
   两档定档），场内空间完整
2. **墙壁反弹检测（四带环）**: Left/Right/Top/BottomBounce 四枚 WallHitBox Area2D，
   `_place_collision_limits()` 统一摆位："带内墙外"分摊提前量（BAND_REACH_LR/TB =
   20/45）——定和 b+O 横 80 竖 75，触发余量 = b+O−8 ≥ 67px ≥ 2 物理帧@最大弹速
   2000px/s，命中必先于撞墙清零，镜像输入永远完整
3. **`delimitate_room()`**: 平滑过渡摄像头边界到指定区域（用 Tween）
4. **高度层碰撞初始化**: `_ready()` 时调用 `QuiverCharacter.get_all_height_layers_mask()` 设置碰撞层

#### 场景树结构

```
LevelCamera (Camera2D)
├── ScreenLimits (StaticBody2D, visible=false, layer+mask=全高度层)
│   ├── Left  (CollisionShape2D, 竖直实体墙, rotation=90°)       ← 无 one_way（4.7.1 实测纵向单向墙不挡人）
│   ├── Right (CollisionShape2D, 竖直实体墙, rotation=-90°)      ← 同上
│   ├── Top   (CollisionShape2D, 水平墙, one_way, rotation=180°) ← 横墙是 one_way 标准场景，保留
│   └── Bottom(CollisionShape2D, 水平墙, one_way, rotation=0°)
├── LeftBounce  (Area2D, WallHitBox, mirror_axis=UP,    attack_damage=5) ┐
├── RightBounce (Area2D, WallHitBox, mirror_axis=UP,    attack_damage=5) │ 四带环：脚本摆位
├── TopBounce   (Area2D, WallHitBox, mirror_axis=RIGHT, attack_damage=5) │ = 对应墙心向场内
└── BottomBounce(Area2D, WallHitBox, mirror_axis=RIGHT, attack_damage=5) ┘   80px（带内墙外，定和≥74）
```

#### 屏幕边缘碰撞墙（ScreenLimits）

四个 StaticBody2D 子节点（Left/Right/Top/Bottom）组成隐形墙壁，阻止角色走出屏幕。

**`_process()` 每帧定位逻辑**:
- Left: `x = min(limit_left - 半宽, 相机中心x - 半视口宽)`
- Right: `x = max(limit_right + 半宽, 相机中心x + 半视口宽)`
- Top: `y = min(limit_top - 半高, 相机中心y - 半视口高)`
- Bottom: `y = max(limit_bottom + 半高, 相机中心y + 半视口高)`

`min/max` 确保墙壁不会超出相机的硬边界（limit_left/right/top/bottom）。

**出生帧定位铁律（`_ready` 先摆一次）**: 墙在场景文件里的默认摆位是**相对相机的旧坐标**，而相机是角色的子节点——不先定位，首物理帧 Spawn 点正压在墙体内，实体墙（见下"单向实测裁决"）的穿透弹出会把角色瞬移十几像素起步（stage_contract C7 出生位漂移 + C4/C6 清场 flaky 同源于此）。`_place_collision_limits()` 在 `_ready()` 与 `_process()` 各调一次，`_ready` 先于任何物理帧。

**`one_way_collision` 实测裁决（2026-09-19）**: **左/右墙 one_way 已移除（实体双向）**。Godot 4.7.1 headless 实证：纵向旋转的单向墙对"从场内顶向墙面"的角色**不产生阻挡**（推进方向与法线关系判定与文档预期相反），即"隐形墙"三缺陷（mask 恒 0 互检、单向不挡、初帧压体）叠加下从未真正挡过人。上下两墙保留原配置（其"跳跃不钩顶"语义与横向出屏无关）。

**碰撞层与掩码**: 不使用固定 layer，由 `_setup_height_layer_collisions()` 在 `_ready()` 时把 layer **与 mask 一并**设为全高度层 bitmask。教训：body↔body（CharacterBody↔StaticBody）碰撞要求**双方 mask/layer 互叠**，高度层重构后角色 body 的 layer 只剩高度位（bit1 players 退役），墙 mask 若停留默认 1 即恒互不可见——隐形墙形同虚设数月无感（弹墙 Area 是单侧检测照常扣血，制造"有伤害没阻挡"的迷惑现场）。

**形状尺寸动态更新**:
- `_update_collision_limits_length()`: 左右墙壁的长度 = 视口高度/zoom + collision_width；上下墙壁的长度 = 视口宽度/zoom + collision_width
- `_update_collision_limits_width()`: 所有墙壁的厚度 = collision_width（默认 80px）
- 视口大小变化时自动更新（`size_changed` 信号）
- Tween 过渡期间也持续更新

#### 墙壁反弹检测（四弹墙带环，2026-09-19 终案）

四枚 Area2D（WallHitBox 脚本）沿屏幕四边缘闭合成环，检测角色被击飞后撞墙。
每枚自带 `attack_data`（`attack_damage=5`）= **击飞撞墙的扣血定价（设计保留）**，
并自带 `mirror_axis`（左右带=UP、上下带=RIGHT）= **该面墙把速度镜像哪个分量**。

**带墙分离摆位（治本）**: 旧形态用 RemoteTransform2D 把带钉死在墙心（带墙同心），
身体撞实体墙被引擎清零速度的那一瞬，同帧才派发带命中事件 → 镜像拿到的输入恒为 0。
（案卷：上游模板的带在纯 one_way 假墙世界里恰好永远拿得到完整速度，其
`reflect(Vector2.UP)` 本就正确；本仓库实体化后才暴露时序矛盾——期间曾被误诊为
"上游恒等变换缺陷"并做过"注入记存速度"的弯路，均已由几何治本取代。）现已删 RT2D，
由 `_place_collision_limits()` 统一摆位（"线"=房界与视口沿的取紧者），
横竖两档：**左右墙外挪 60/带探入 20（定和 80），上下墙外挪 30/带探入 45
（定和 75——竖直向弹速低且深度轴出界观感强，双向收紧）**。触发余量 =
b+O−受击盒内缩(8) ≥ 67px ≥ 2 物理帧@最大弹速 2000px/s（33px/帧）——
**命中永远先于碰撞，镜像输入完整**；贴横墙停位=线−25（3/4 出镜，定档）。
定和底线 b+O ≥ 74 写死在常数注释，几何锁实测区间 [74, 90)：knockout_contract D8。

**碰撞层**: 同 ScreenLimits，使用全高度层 bitmask（四带由 `_setup_height_layer_collisions()` 归置）。

**反弹流程**（状态生命周期驱动，2026-09-19 改版）:
1. 角色被击飞 → `CombatSystem` 分发 → transition 到 `Air/Knockout/Launch`
2. 击飞链父状态 `QuiverActionAirKnockout.enter()` → `attributes.in_knockout = true`
   （动画关键帧不再参与开关；旧 `_enable/_disable_wall_bounce_collisions` 方法与其
   launch/landed 动画轨道已退役删除）
3. 角色 HurtBox 进入 LeftBounce/RightBounce 检测范围（墙挂全高度层，被动可测）
4. `_on_area_entered()` 类型分派 → `_handle_wall_hit_box()` → `in_knockout` 门放行
5. 结算：`apply_damage(5)` + `wall_bounced.emit(墙.mirror_axis)`
6. 击飞链监听 → transition 回 Launch（`is_wall_bounce`+`mirror_axis`）→
   `velocity.reflect(axis)` **真镜像**复飞（左右墙翻水平/上下墙翻竖直；幅值守恒=
   恢复系数 1，上游原语义）；弹跳/再受击期间旗恒开（父 enter 幂等）。
   端到端锁：stage_contract C3.5（向西击飞→触带→镜像向东→弹回场心落地）
7. 链自然走完（Bounce 落地→Recovery 或死亡→Die）→ `Knockout.exit()` → 旗归零，
   恢复"贴墙免结算"。**空中死亡泄漏洞**（旧机制 die 分支无人关窗）由第 7 步封死。

#### `delimitate_room()` — 战斗区域锁定

用 Tween 平滑过渡相机的 limits 和 zoom，用于战斗开始时锁定摄像机到战斗区域。

```gdscript
func delimitate_room(..., p_duration) -> Tween:
    # Tween 过渡到战斗区域边界（TRANS_QUAD + EASE_IN_OUT）
    # 返回本次 Tween：调用方（战斗房）挂 finished 做落位收口，见 8.1
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
quiver/beat_em_up/gameplay/default_hit_lane_size = 60    # 车道半窗（垂直于攻向的轴：横攻Y/纵攻X）
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
| **`create_new_character/`** | **`CharacterTemplate` 节点**（`templates/character/character_template.tscn`） | **创建/删除角色** |
| **`height_layers/`** | **`QuiverCharacterSkinAnimTree` 节点** | **扫描动画帧文件名注入高度层轨道 + 轮廓转换工具（Polygon/Capsule/Rectangle）+ PNG 缩放与备份工具** |

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
├── png_scale_tool.gd                # PNG 批量缩放+备份核心（extends RefCounted, 静态方法, @tool, 纯文件操作）
├── mask_editor_dialog.gd            # 交互式蒙版绘制工具（extends AcceptDialog, @tool；通用/Body/Attack/Shadow 四类）
└── sprite_browser_scan.gd           # 蒙版编辑器左侧图片列表的纯数据层（extends RefCounted, 全静态, @tool；不依赖编辑器单例/注入器→headless 可测）
```

**Widget 生命周期契约（重要，4.7 源码实证）**：

`EditorInspector::_clear()` 在每次重解析（切换选中节点、场景保存刷新等）时用 **memdelete 立即销毁** Inspector 内的自定义控件——widget 是"每次重生"的易碎视图，任何存在 widget 实例上的状态（文字、正在跑的协程）都会丢。因此：

- **长任务协程必须挂在 `ContourConversionRunner`**（`get_or_create()` 单例，add_child 到 `EditorInterface.get_base_control()`，编辑器会话内常驻），widget 只负责 `start()` 与订阅 `progress_updated` / `run_finished` 后 `_refresh_from_runner()` 回放状态快照 → 切页不再丢失进度文字，帧让出宿主恒有效（不再假死）
- widget 死亡时其对 runner 信号的连接由 Godot 自动断开，无需手动清理
- runner 转换完成后**自行**调用 `EditorInterface.get_resource_filesystem().scan()`（旧 widget `scan_completed` 信号 → plugin 中转链已废除，widget 半路死亡会断链）
- 转换期间关闭目标场景页签：runner 在下一次进度回调检测 `is_instance_valid(_active_skin)` 失败 → `_session+1` 作废旧协程收尾权 → 立即 `_finalize` 报错并复位 `is_running`（不会永久卡运行态）
- 防 class_name 缓存时序问题：widget 经 `const preload` 引用 runner 与 injector（新文件同步到另一台机器后首启即编译，不依赖全局类注册时机）

**PNG 缩放与备份工具 v2（`png_scale_tool.gd`，widget 底部区块）**：资产层角色缩放方案——体型差异通过缩小精灵图实现（"两个体型=两个角色"工作流），系统运行时对缩放零认知。
- **目录语义**：`source_dir`（如 `characters/<c>/resources/sprites/`）=派生物+用户投稿箱；`backup_dir`（`resources/sprites_master/`）=原画唯一真理。备份目录纳入 git（双机 Syncthing 下防"缩小图被误采为原底"）
- **journal 内容裁判**（`_journal.log` 在备份根，append-only `rel\tmd5` 行）：逐文件规则 R0 无备份/reclaim→收底/换底（源必须可解码，否则跳过且不碰备份）；R1 源==备份字节→原画未动→印；R2 源==账本记录的上次输出字节→印品未动→从备份重印；R3 其余=内容被改→**自动换底再印**。尺寸仅在**迁移模式**（无账本首跑，一次性兜底）参与：尺寸≠备份→当旧印品重印（保守），同尺寸异内容→当换画收底。运行末尾账本**压实**（只留本次所见文件，删除的美术不留死条目）；"恢复原图"后**清账**（源==备份由 R1 接管）
- **用户日常操作**：在 sprites/ 里增删改原画（新图放原尺寸）→ 点"执行缩放"即可，逐文件自动识别（新增/换画/同尺寸换画/**尺寸恰好撞上旧印品的换画**均由哈希裁判）；删除的文件留孤儿原画做后悔药（汇总报孤儿数；恢复会复活它们，>0 时弹确认）
- **逃生门**（"重新采集原底"复选框）：忽略账本，把源目录当前内容整体立为原底（不可逆）；勾选执行前**干跑预览弹确认**并显示"疑似印品 N 个"计数（`preview_actions`）。三用途：尺寸+内容双重撞车的极端投稿、以印品为稿的手工修图、修复被污染的备份。日常不需要
- **执行形态**：走 `ContourConversionRunner` 同款宿主（逐文件 await 分帧、进度/互斥/session/切页安全），完成时 fs.scan + 汇总"图/掩码/新收底/换底/孤儿/（迁移建账）"，提醒重跑 Body+Attack 两类轮廓转换
- 掩码三型（`.mask/.body.mask/.attack.mask.png`）仅 resize alpha；精灵图 `fix_alpha_edges` → Lanczos（4.7 无 `depremultiply_alpha`，premultiply 不可逆路线弃用）
- **蒙版母版体系（v3 关键规则）**：蒙版的"原画"永远是母版目录那份（由蒙版编辑器在母版画布上写入，`PngScaleTool.write_mask_pair()` 双写核心），源目录蒙版只是印品。缩放处理蒙版时**永不走 R0/R3 收底/换底**——`process_pair()` 蒙版专用分支置于所有判定之前：有母版 → 从母版重印（随底图换系数同步）；无母版 → 判为历史孤儿，**告警跳过**（不污染母版、绝不二次缩小成"印品的印品"）。`*.no.png` 跳过标记是纯布尔旗标只需存在于源目录，`_collect_pngs_in()` 将其整体排除在缩放配对之外（恢复原图/孤儿统计同样不碰）
- headless 测试矩阵 16 项（收底/幂等/换系数/换画/同尺寸换画/尺寸撞车/删除→孤儿→恢复→清账/迁移两式/逃生门/损坏源护栏/预览只读/递归目录）全通过（`/tmp/opencode/scale_v2_tests.gd`，2026-09-12）
- headless 测试矩阵 v3 蒙版保护 13 项（孤儿告警不收底/母版不被污染/源孤儿蒙版不被缩小/有母版蒙版随系数重印同步/.no 全链路不碰/双写核心两份两尺寸…）+ 删除核心 11 项（母版双份删净/sidecar 清走/不误伤底图与其它档/幂等重删/非母版单删/删后缩放不复活）全通过（2026-09-13）；内嵌浏览器数据层 9 项（目录分组/伴生与备份及母版目录排除/字母序/🎭⛔ 与注入器链一致/类型映射）全通过（2026-09-13）；跳过标记共用静态函数 8 项（四档命名链/合法落盘/幂等/专属不跨类/通用全类可见/删除连伴生/缺失幂等/底图无恙）全通过（2026-09-13）；UI-API 引擎自省断言（蒙版浏览器用到的每个 TreeItem/Tree/Dialog 方法与信号逐一经 ClassDB 向引擎本体核实存在，含 set_expanded/popup_hide 两条"不存在"反向结论）全通过（2026-09-13）。教训固化：浏览器目录行展开用 `TreeItem.set_collapsed(false)`（4.7 无 set_expanded）；蒙版窗口回收监听 `CanvasItem.visibility_changed` 判不可见后 queue_free（AcceptDialog 无 closed/popup_hide 信号，历史 `dialog.closed` 调用一直报错且泄漏窗口实例，已修）

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
   - **帧级标记系统（三类别 body/attack/shadow × 两族，类别间无继承、互不平移。UI 术语对照：界面称「跳过检测」= 本族的 `.no.png` 文件；「蒙版编辑」= `.mask.png` 族）**：
     - 蒙版族 `{name}{.类别}.mask.png → {name}.mask.png → 无`：常量表 `SCAN_MASK_CHAINS`，首个存在即用（`resolve_mask_path()`）
     - 豁免族 `{name}{.类别}.no.png` 或 `{name}.no.png`：任一命中 → **整帧不检测**（`find_no_marker()`，预统计 pass 过滤、进度 total 不含、结果 `skipped_no` 计数）；被跳帧在注入端因 `frame_dict.has()` 守卫**不写任何键**（polygon/physical_height/width/attack_heights/occluder 全部保持上一键值，与 `:disabled` 窗口同机制）
     - shadow 与 body 完全平级：`.body.mask.png`/`.body.no.png` **不影响** shadow（各有专属档 + 通用档）；shadow 扫描以 `mask_suffix="shadow"` 独立解析
     - 跨扫描 `shared_image_cache` 值为 `{image, masks:{suffix→Image|null}}`——蒙版按后缀分键缓存，杜绝"先跑类别吞掉后跑类别蒙版"（v1 单键缺陷）
     - 标记文件必须是合法 PNG（0 字节会触发导入器报错）；widget 预览区有"豁免标记"创建/删除辅助（2×2 合法图代生成，实时显示现有标记）。**v3.2：标记创建/删除下沉为注入器静态函数（`no_marker_path/create_no_marker/delete_no_marker_by_path`，删除连带 `.import/.uid` 伴生），widget 预览区按钮与蒙版编辑器新增「⏭ 设为跳过检测 / ↩ 取消跳过」切换按钮共用同一实现——编辑器内按钮跟随当前类型（通用=一开关停三类，专属=只停本类），切换后列表 ⛔ 徽标即时重算；标记只存在于游戏目录，不进母版、不参与缩放**
     - 蒙版编辑器类型下拉含 通用/Body/Attack/Shadow 四档（`mask_editor_dialog.gd`）
     - **蒙版编辑器母版模式（v3）**：面板把缩放区的源/备份目录传入 `set_master_context()`；该图在母版目录存在原画 → 画布自动切换为母版大图（笔刷半径按倍率补偿），保存经 `write_mask_pair()` 双写：权威版入母版 + 缩印版随成品底图尺寸入 `sprites/`；无母版体系的角色（如 run_test/模板）自动落回旧单写行为，完全无感。加载优先级：母版蒙版 → 成品旧蒙版（升采样当起点并提示"保存即转正"）→ 新建
     - **蒙版删除（v3）**：编辑器三按钮语义严格区分——💾 保存（母版双写）/ 🧹 涂空 Mask（画布转透明、保留文件、保存后＝空蒙版＝检测区域清空）/ 🗑 删除 Mask 文件（真删）。删除作用于**当前所选档位**（通用/Body/Attack/Shadow），经确认弹窗列出待删文件后调用 `PngScaleTool.delete_mask_pair()`：母版模式一次清掉 母版+成品 两份及各自 `.import/.uid` 伴生（杜绝缩放从残留母版复活、杜绝孤儿 import 报错），非母版模式删单份；不存在的目标幂等跳过。删除后画布复位＝该图恢复整图检测。`*.no.png` 跳过标记的创建/删除仍由 widget 预览区独立管理，不在此列
     - **内嵌图片浏览器（v3，`sprite_browser_scan.gd` + 对话框 `_build_file_browser()/_populate_tree()`）**：编辑器据 `_source_dir`/`/sprites/` 锚点解析浏览根，左列以 `Tree` 目录分组列出全部主图（伴生 `.mask/.no` 家族、`.import`、`png_scale_backup/`、`sprites_master/`、隐藏目录均不入列），文件名前 48px 缩略图（`Image` 直解 + `_thumb_cache` 去重；**整棵树同步一次性建完，严禁 await 帧信号**——编辑器默认低处理器模式空闲不刷帧，await 会让构建无限期停摆，v3.1 事故与修复）。行尾 **🎭/⛔ 标记跟随类型下拉实时重算**：`🎭`＝该图在**当前所选类别**下有生效蒙版（复用注入器 `resolve_mask_path` 链：专属→通用回退）、`⛔`＝该类别被跳过（`find_no_marker`），切类型即 `_refresh_badges()`。点选换图：`_mask_dirty`（`_draw_at`/涂空置真、存/读置假）为真时弹"未保存将丢失"确认，否则 `_do_switch_to()` 直接重走 `_update_mask_path`+`_load_images`，并发 `file_changed` 信号让面板预览区跟随最后一张。扫描/伴生/类别映射三函数为无状态静态，headless 9 项断言覆盖
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

**轮廓顺序契约（2026-09-16 火球针帧事故定档）**：`trace_contours()` 返回前按
面积**降序**排序，主体轮廓恒在 `[0]`。下游四线拟合消费端（polygon 轨道、
MABR→胶囊/矩形、腐蚀后 MABR、阴影遮挡体）全部只取 `[0]`——多分量美术
（火焰、飘落碎片）的扫描返回序不定，历史上"第一条≈主体"只是碰巧成立。
防回归桩：`tools/contour_sort_test/`。同批修复：`_audit_attack_animations`
的 `Array[String]` 三目赋值在运行期抛错致体检静默瘫痪（角色/法术两产线），
且按帧名前缀受理会误伤 RESET（其精灵帧名恒指向循环动画）→ 类型注解降为
`Array` + RESET 豁免。

**信标循环感知（2026-09-16 火球死线信标定档）**：`_validate_attack_animation_structure`
按 `anim.loop_mode` 分岔——**非循环**攻击/active 动画必须带结束信标（状态机唯一出口，
角色 `end_of_skin_animation` / 法术 `end_of_spell_animation`）；**循环动画禁止携带**
信标（方法轨道按时刻触发，循环每掠过一圈响一次，对"一次性结束"语义是每圈误触发源；
循环法弹的生死由命中/超时两个战斗事件决定）。工具只报错不自动删（节奏属创作者），
fire_ball 的存量死线由 `tools/reconvert_fireball/` 的摘除步骤一次性清偿。

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
        ├── 蒙版类型选择（Generic / Body / Attack / Shadow）
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
| Shadow (id=3) | `{name}.shadow.mask.png` | 仅 Body 转换内的 Shadow 第二次扫描使用（独立链，不继承 body 蒙版） |

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
   - **5b. ShadowBox 第二次独立扫描**（仅 Body 且 shadow 参数启用时）：使用 `shadow_simplify_tolerance` / `shadow_min_area_ratio`，`erosion_radius = 0`，`mask_suffix="shadow"`（独立 `.shadow.mask.png`/`.shadow.no.png` 解析链，与 body 互不继承），结果合并到 `frame["shadow_raw_contours"]`。不执行 MABR/Capsule/Rectangle 转换，不计算 physical_height/width
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
    - **Attack 参与判定与审计（v3）**：某攻击形状参与某动画 ⇔ 该动画为该形状写了 `:disabled` 轨道**且含 false 键（开盒窗）**；无轨道或全 true = 未声明参与 = 不扫描、不注入、不处理。attack 类不再读节点 disabled 初值（初值可被节点重建/误触污染，旧兜底曾使 falling_left 型动画被注入并自我维持，2026-09-13 治愈；body 类保留初值兜底——受击框无开关窗概念）。审计 `_audit_attack_animations()` 在注入后独立执行：按动画名受理（`attack*`/`air_attack*` 前缀），无开盒窗 → 报"缺窗口声明"（模板旧 down/up 病正形于此）；有窗 → 结构检查（缺 `end_of_skin_animation` 方法轨道或攻击盒恒关 → 报障；`air_*` 豁免电话检查，空中出口由 `_end_condition` 决定）。非攻击名动画永不误报。配套一次性/常驻清理 `cleanup_illegal_attack_data()`（面板 🧹 按钮，dry 预览确认后落盘）：删除未参与形状的注入专有轨道（shape:polygon/position/rotation/shape:*、容器:position、含 true 键的容器:visible），全动画无参与再删 `.:attack_heights`；手写 :disabled 与全 false 防御性 visible 不碰；幂等
    - **`:animation` 字符串轨道自检免疫**（`_fix_animation_string_track_discrete()`）：注入前发现 `AnimatedSprite2D:animation` 为连续更新模式 → 强制离散并向 errors 追加"已自动修正"。背景：新建值轨道默认连续，而 String 轨道连续会触发 AnimationMixer 实验性字符串混合警告（"blends String types"）；chen 曾因早期批处理带入 65 个连续实例（2026-09-12 一次性脚本治愈并经行免疫化）
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
│   ├── RichTextLabel（结果输出，Body/Attack 两节）
│   └── HBox：TextureRect × 2（左 Body 检测预览 / 右 Attack 检测预览+高度带）
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

**预览双栏（v3）**："Preview Contour" 对同一张图按 `body`、`attack` 两种类别规则各算一遍（`preview_single_file(..., mask_suffix)`）：左图=Body 检测四层叠加（红轮廓/蓝 MABR/品红胶囊/黄心），右图=Attack 同套画法 + **攻击高度带**（`attack_heights` 命中的整个高度层区间画半透明绿带、代表高度画亮绿线，离底=脚底起算）。两栏解析链与转换**完全同源**：蒙版 `resolve_mask_path()` 链式、跳过标记 `find_no_marker()`（旧版预览只认通用蒙版、不看跳过、且 attack_heights 依赖 punch1 旧文件名对 UUID 资产恒失效——均已废除，attack_heights 恒计算）。文字报告分 Body/Attack 两节，各节首行标明所用蒙版文件或"⛔已跳过（标记文件名）"；被跳过的栏只显示干净原图。

**静态持久化**：所有参数和选中文件路径存储为 `static` 变量，跨 widget 重建存活（Inspector 每次选择变化时重建自定义控件）。

**异步执行**：转换/缩放长任务全部跑在常驻 `ContourConversionRunner` 上（逐文件 await 让出，切页不中断、进度实时恢复，见上文 Widget 生命周期契约）；注入器内部进度回调 `_on_contour_progress()` 由 runner 实现并广播。

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
1. 打开 `templates/character/character_template.tscn`
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

**测试场景是生成物（重要）**：`test_scenes/_test_<char_name>.tscn`（**整个 `test_scenes/` 目录已 gitignore，不纳入版本控制**，随时可由模板再生）每次点击 Run Test 都由 `inspector_plugin.gd` 内置模板字符串**整体重写**——对该文件的任何手工修改都会在下次点击时被覆盖；要改测试场景内容 = 改模板字符串。**写入是幂等的**：生成内容与磁盘一致时跳过写盘/扫描直接运行（编辑器打开着该场景也不会弹"硬盘变动"）；只有模板真正变化才落盘一次（此时编辑器会提示重载一次，Reload 后恢复安静）。测试背景由 `res://scripts/debug_background.gd`（**CanvasLayer + 屏幕空间纵向双色灰渐变**（`draw_polygon` 顶点色插值）+ **世界锚定地面参考线**（`ground_line_y=500`，经视口 `get_canvas_transform()` 映射设备像素吸附，每帧重绘跟随相机）；零网格线、零 shader、零贴图。演进备注：曾有 shader 版 `grid_background.gdshader` 与设备像素吸附的 `debug_grid.gd` 网格版，均按需求移除；若未来需要世界锚定参考线，注意世界→屏幕须用**视口 `get_canvas_transform()`** 而非 Node2D 的 `get_screen_transform()`（后者是相机自身摆放、恒为常量）。模板当前包含 `ShadowRegion`（`res://scripts/shadow_region.gd`，游戏侧脚本）节点：`position=(50,400) size=(900,300) debug_preview=true`，用于演示"阴影可生成区域"裁剪与软边缓冲收缩（详见 `docs/SHADOW_SOFT_EDGE_DESIGN.md` §9）；`debug_preview` 仅测试场景开启，正式关卡的区域节点应保持 false（运行时零绘制）。

> **目录约定**：`scenes/` 仅存放正式游戏场景（未来 `scenes/stages/` 等）；所有 Run Test 生成物（角色测试场景、法术测试场景及其 helper 脚本 `_test_spell_helper_*.gd`）统一输出到 `test_scenes/`（gitignore）。`create_new_spell/inspector_plugin.gd` 同样遵循幂等写盘 + `test_scenes/` 路径 + `debug_background.gd` 背景。

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
  res://templates/character/character_template.tscn 
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
