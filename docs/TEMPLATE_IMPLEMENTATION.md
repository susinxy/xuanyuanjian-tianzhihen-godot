# template-beat-em-up 实现参考

> **分析日期**: 2026-08-11
> **用途**: 记录模板里实际角色/场景如何配置，供 xuanyuan-sword 开发时参考

---

## 1. 目录结构

```
template-beat-em-up/
├── characters/
│   ├── playable/chad/            # 玩家角色 Chad
│   │   ├── chad.gd               # 角色脚本（继承 QuiverCharacter，极薄）
│   │   ├── chad_skin.gd          # 皮肤脚本（继承 AnimTree，加 suplex/slide 信号）
│   │   ├── chad.tscn             # 角色场景
│   │   ├── chad_skin.tscn        # 皮肤场景（独立）
│   │   └── resources/
│   │       ├── chad_attributes.tres       # 角色数据 Resource
│   │       ├── punch1_attack_data.tres    # 第一拳攻击数据
│   │       ├── punch2_attack_data.tres    # 第二拳
│   │       ├── punch3_attack_data.tres    # 第三拳（终结技）
│   │       └── air_kick_attack_data.tres  # 空中踢
│   └── enemies/
│       ├── sargent/              # 基础敌人 Sarge
│       │   ├── sarge_ai.gd      # AI 状态机（Wait→Chase→Attack→Wait 循环）
│       │   ├── sarge.tscn
│       │   └── sarge_skin.tscn
│       └── tax_man/              # Boss TaxMan
│           ├── tax_man.gd        # Boss 逻辑（阶段、伤害上限、笑动画）
│           ├── tax_man_ai_state_machine.gd  # 分阶段 AI + 霸体反连击
│           ├── tax_man_state_machine.gd     # 自定义初始状态（座椅开始）
│           ├── tax_man_skin.gd
│           ├── tax_man.tscn
│           ├── tax_man_skin.tscn
│           └── resources/custom_states/     # 自定义 action states
│               ├── dash_attack_action.gd    # 冲刺攻击
│               ├── grab_reject.gd           # 拒绝抓取
│               ├── knockout_kneeled_action.gd
│               ├── seated.gd              # 坐姿状态
│               └── taxman_hurt.gd
├── stages/
│   ├── _base/
│   │   ├── base_stage.gd         # 关卡基类（HUD 绑定、player_died 监听、重载）
│   │   └── base_stage.tscn       # 关卡基础场景结构
│   └── stage_01/
│       ├── stage_01.gd           # Stage 1 实现（5 个战斗室、boss 胜利判定）
│       └── stage_01.tscn
└── ui/
    ├── _base/                    # UI 基类
    ├── gameplay_hud/             # 实时 HUD（玩家血条、敌人血条）
    ├── main_menu/                # 主菜单
    ├── pause_menu/               # 暂停菜单
    └── end_screen/               # 结束画面

---

## 2. Chad 玩家角色实现

### 2.1 角色脚本 (`chad.gd`) — 极薄封装

```gdscript
@tool
extends QuiverCharacter

func _ready():
    if Engine.is_editor_hint():
        QuiverEditorHelper.disable_all_processing(self)
        return
    super()
    if attributes != null:
        attributes.reset()
    add_to_group("players")
    if QuiverEditorHelper.is_standalone_run(self):
        QuiverEditorHelper.add_debug_camera2D_to(self, Vector2(0, -0.8))
```

**关键**:
- 完全不在角色脚本里写 gameplay 代码
- `_ready()` 只处理编辑器禁用 + 属性重置 + 加 group + F6 调试相机
- `super()` 必须在编辑器检查之后调用

### 2.2 皮肤脚本 (`chad_skin.gd`) — 自定义信号桥

```gdscript
@tool
extends QuiverCharacterSkinAnimTree

signal suplex_landed      # 抛摔落地（由动画调用 end_of_suplex()）
signal sliding_stopped    # 滑行结束（由动画调用 end_of_slide()）

@onready var _suplex_landing := $Positions/SuplexLanding as Marker2D

func get_suplex_landing_position() -> Vector2:
    return _suplex_landing.global_position

func end_of_suplex():     suplex_landed.emit()
func end_of_slide():      sliding_stopped.emit()
```

Chad 的皮肤脚本**只增加两个自定义信号**（suplex_landed / sliding_stopped），由动画的关键帧直接调用。其他所有逻辑由基类 `QuiverCharacterSkinAnimTree` 处理。

### 2.3 场景树结构

```
Chad (继承 quiver_character_base.tscn)
  groups = ["players"]
  collision_mask = 14 (layers 2+3+4: obstacles + screen_limits + ceiling_limits)
  _attributes = chad_attributes.tres
  │
  ├─ Collision (CollisionShape2D)
  │   shape = CapsuleShape2D (radius=20, height=204), rotated 90°
  │   metadata/collision_type = "default"
  │
  ├─ ChadSkin (实例 chad_skin.tscn)
  │   _has_grab = false, _has_grabbed = false
  │   └─ Sprite2D, AnimationPlayer, AnimationTree, Positions/SuplexLanding
  │
  └─ StateMachine (动作状态机)
      initial_state = "Ground/Move/Idle"
      │
      ├─ Ground (quiver_action_ground)
      │    ├─ Move (quiver_action_move)
      │    │   ├─ Walk (quiver_action_walk, _walk_skin_state="walk")
      │    │   └─ Idle (quiver_action_idle, _skin_state="idle")
      │    ├─ Hurt (_skin_state_mid="hurt_mid", _skin_state_high="hurt_high")
      │    ├─ Combo1 (_skin_state="attack1", _can_combo=true, → Combo2)
      │    ├─ Combo2 (_skin_state="attack2", _can_combo=true, → Combo3)
      │    ├─ Combo3 (_skin_state="attack3", _can_combo=false, → Idle)
      │    └─ Recovery (_skin_state="knockout_ground", → Idle)
      │
      ├─ Air
      │    ├─ Jump
      │    │   ├─ Impulse (_skin_state="jump", → MidAir)
      │    │   ├─ MidAir (_skin_state_rising="rising", _skin_state_falling="falling",
      │    │   │          _can_attack=true, → Attack)
      │    │   ├─ Landing (_skin_state="landing", → Idle 或 Walk)
      │    │   └─ Attack (_skin_state="air_attack", _end_condition=1=距离判定)
      │    └─ Knockout
      │        ├─ Launch (_skin_state_launch="knockout_launch", 死亡时减速)
      │        ├─ MidAir (_skin_state_rising="knockout_rising", _skin_state_falling="knockout_falling")
      │        └─ Bounce (_skin_state="knockout_bounce", → Recovery 或 Die)
      │
      └─ Die (_skin_state="die")
```

### 2.4 碰撞配置

| 节点 | Type | Layer | Mask | collision_type |
|---|---|---|---|---|
| Chad (body) | CharacterBody2D | 1 (players) | 14 (obstacles+limits) | default |
| Collision | CapsuleShape2D | — | — | default |
| HurtBox | Area2D | 4096 (layer 13 = player_hurt_boxes) | 2560 (layers 10+12 = enemy_hit+grab) | player_hurt_box |
| Attack1 (punch1) | Area2D | 256 (layer 9 = player_hit_boxes) | 0 | player_hit_box |
| Attack2 (punch2) | Area2D | 同上 | 0 | player_hit_box |
| Attack3 (punch3) | Area2D | 同上 | 0 | player_hit_box |
| AttackAir (air kick) | Area2D | 同上 | 0 | player_hit_box |

**注意**: HitBox 默认 `monitoring=false`，由皮肤动画的关键帧调用开启。

### 2.5 数据 Resource

**chad_attributes.tres**:
```
display_name = "Chad"
health_max = 100
speed_max = 500.0
air_control = 0.6
jump_force = -1200
hit_lane_offset = 0
is_invulnerable = false
has_superarmor = false
can_be_grabbed = true
```

**punch1/2/3_attack_data.tres**（每拳不同）:
- damage, hurt_type (HIGH/MID), knockback (NONE/WEAK/MEDIUM/STRONG/MASSIVE), launch_angle

### 2.6 AnimationTree 结构

```
BlendTree (tree_root)
  └─ TimeScale
     └─ StateMachine
        ├─ idle        → BlendSpace1D { idle_left @ -0.1, idle_right @ 0.1 }
        ├─ walk        → BlendSpace1D { walk_left @ -0.1, walk_right @ 0.1 }
        ├─ turn        → BlendSpace1D { turn_to_left @ 0.1, turn_to_right @ -0.1 } ← 取反
        ├─ attack1     → BlendSpace1D
        ├─ attack2     → BlendSpace1D
        ├─ attack3     → BlendSpace1D
        ├─ hurt_mid    → BlendSpace1D
        ├─ hurt_high   → BlendSpace1D
        ├─ jump        → BlendSpace1D
        ├─ rising / falling / landing     → BlendSpace1D
        ├─ air_attack  → BlendSpace1D
        ├─ knockout_launch / rising / falling / bounce → BlendSpace1D
        ├─ knockout_ground → 嵌套的 AnimationNodeStateMachine
        │   ├─ knockout_landed (BlendSpace1D)
        │   └─ getting_up (BlendSpace1D)
        └─ die → BlendSpace1D
```

**Blend position 细节**: 所有常规动画 left=-0.1 / right=0.1。`turn` 动画取反（left=0.1 / right=-0.1），因为转身时面朝相反方向。

---

## 3. Sarge 基础敌人实现

### 3.1 无角色脚本

Sarge 没有 `.gd` 角色脚本，直接用 `QuiverEnemyCharacter` 基类（继承时自动注册 AI 信号）。

### 3.2 AI 状态机 (`sarge_ai.gd`)

```gdscript
@tool
extends QuiverAiStateMachine

func _decide_next_behavior(last_state: StringName) -> void:
    match last_state:
        "Wait":          transition_to("Chase")
        "Chase":         transition_to("Attack")
        "Attack":        transition_to("Wait")
        "WaitTillIdle":  transition_to(_state_to_resume if _state_to_resume else "Wait")
        "GoToPosition":  transition_to("Wait")
```

**AI 树**:
```
AiStateMachine (initial_state="Wait", _ai_state_hurt="WaitTillIdle")
  ├─ Wait (QuiverAiWait, 1-3 秒随机)
  ├─ Chase (QuiverStateSequence)
  │    ├─ ChaseClosestPlayer (QuiverAiChaseClosestPlayer, max_chase_time=5)
  │    └─ Wait (QuiverAiWait, 0.2 秒)
  ├─ Attack (QuiverStateSequence)
  │    ├─ CallCombo (QuiverAiCallAttack, combo_hits=1: 单拳试探)
  │    ├─ Wait (QuiverAiWait, 0.5 秒间隔)
  │    └─ CallCombo2 (QuiverAiCallAttack, combo_hits=3: 三连拳)
  ├─ GoToPosition (QuiverAiGoToPosition, 用于生成时走向场景)
  └─ WaitTillIdle (QuiverAiWaitForState, 等待动作 SM 回到 Ground/Move/IdleAi)
```

### 3.3 动作状态机

与 Chad 相似，但:
- **IdleAi 替代 Idle**（不接受玩家输入，等待 AI 信号）
- **Follow 替代 Walk**（追踪 `_actions.transitioned` 消息里的 `target_node`）
- **没有空中 Attack**
- **DieAi 替代 Die**（敌人死亡版）

```
StateMachine (initial_state="Ground/Move/IdleAi")
  ├─ Ground
  │    ├─ Move
  │    │   ├─ Follow (quiver_action_follow, 接受 target_node/target_position)
  │    │   └─ IdleAi (quiver_action_idle_ai, 被动等待)
  │    ├─ Hurt (hurt_mid / hurt_high)
  │    ├─ Attack1, Attack2, Attack3
  │    └─ Recovery
  ├─ Air / Jump / Knockout
  └─ DieAi
```

### 3.4 碰撞配置

| 节点 | Type | Layer | Mask |
|---|---|---|---|
| Sarge (body) | CharacterBody2D | 16 (layer 5 = enemies) | 14 |
| HurtBox | Area2D | 8192 (layer 14 = enemy_hurt_boxes) | 256+1024 (layers 9+11) = player_hit+grab |
| HitBoxes (Attack*) | Area2D | 512 (layer 10 = enemy_hit_boxes) | 0 |

---

## 4. TaxMan Boss 实现

### 4.1 阶段系统

```gdscript
@tool
extends QuiverEnemyCharacter
class_name TaxManBoss

signal phase_changed_to(phase: int)
signal tax_man_revealed, tax_man_laughed, tax_man_engaged

enum TaxManPhases { PHASE_ONE, PHASE_TWO, PHASE_THREE, PHASE_DIE }

@export var should_start_seated := false  # 开场坐椅子

# 每个阶段的 HP 阈值（百分比）
var _phases_health_thresholds: Dictionary = {
    TaxManPhases.PHASE_ONE: 1.0,    # 100%
    TaxManPhases.PHASE_TWO: 0.5,    # 50%
    TaxManPhases.PHASE_THREE: 0.15, # 15%
    TaxManPhases.PHASE_DIE: 0.0,    # 0%
}

# 单次连击最大扣血百分比（防止无限晕眩）
var _max_damage_in_one_combo: float = 0.1
```

`can_deny_grabs() → true` 让 boss 拒绝抓取。

### 4.2 AI 状态机 (`tax_man_ai_state_machine.gd`)

**核心创新**: 多阶段 + 霸体反连击

```gdscript
@tool
extends QuiverAiStateMachine

@export var _max_consecutive_hits: int = 10  # 被打多少下就强制反击
var _consecutive_hits: int = 0
var _phase_path: String = "Phase1"  # 状态树路径前缀

func _decide_next_behavior(last_state):
    if _phase_path == "Dead": return
    match last_state:
        "Wait":
            transition_to("{_phase_path}/ChooseRandomAttack")
        "ChooseRandomAttack":
            _consecutive_hits = 0
            transition_to("{_phase_path}/Wait")
        "GoToPosition":
            transition_to("{_phase_path}/Wait")
        "WaitForIdle":
            transition_to(_state_to_resume if _state_to_resume else "{_phase_path}/Wait")
            character_attributes.is_invulnerable = false
```

**伤害中断覆盖** (`_interrupt_current_state`):

```gdscript
func _interrupt_current_state(p_next_path):
    _consecutive_hits += 1
    if _consecutive_hits > _max_consecutive_hits:
        character_attributes.is_invulnerable = true  # 霸体
        transition_to("{_phase_path}/ChooseRandomAttack")  # 强制反击
    else:
        super(p_next_path)  # 正常受击
```

**阶段切换**（监听 `phase_changed_to`）:

```gdscript
func _on_tax_man_phase_changed_to(phase):
    match phase:
        2: _phase_path = "Phase2"; transition_to("Phase2/ChooseRandomAttack", {chosen_state: "AreaAttack"})
        3: _phase_path = "Phase3"; transition_to("Phase3/ChooseRandomAttack", {chosen_state: "AreaAttack"})
        4: _phase_path = "Dead"; transition_to("WaitForIdle")
```

### 4.3 自定义 Action State 示例

**`dash_attack_action.gd`**（冲刺攻击，直接继承 QuiverCharacterAction）:

```gdscript
@tool
extends QuiverCharacterAction

var _dash_skin_state := &"attack_dash_begin"
var _attack_skin_state := &"attack_dash_end"
var _path_next_state := "Ground/Move/IdleAi"

# 冲刺移动
var _movement_is_enabled: bool
var _movement_speed: float
var _movement_direction: Vector2

func enter(msg):
    get_parent().enter(msg)  # 手动激活 Ground 父状态
    super(msg)
    _skin.transition_to(_dash_skin_state)

func physics_process(delta):
    if _movement_is_enabled and _movement_direction:
        _character.velocity = _movement_direction * _movement_speed
        _character.move_and_slide()

func _connect_signals():
    get_parent()._connect_signals()  # 继承 Ground 的 hurt/knockout 信号
    super()
    _skin.attack_movement_started.connect(_on_skin_attack_movement_started)
    _skin.attack_movement_ended.connect(_on_skin_attack_movement_ended)
    _skin.skin_animation_finished.connect(_on_skin_animation_finished)
    _skin.dash_attack_succeeded.connect(_on_skin_dash_attack_succeeded)
    _skin.dash_attack_failed.connect(_on_skin_dash_attack_failed)

func _on_skin_dash_attack_succeeded():
    _skin.transition_to(_attack_skin_state)

func _on_skin_dash_attack_failed():
    _state_machine.transition_to(_path_next_state)
```

**`grab_reject.gd`**（拒绝抓取，直接继承 QuiverCharacterAction）:

```gdscript
@tool
extends QuiverCharacterAction

var _skin_state := &"grab_reject"
var _path_next_state := "Ground/Move/IdleAi"

func enter(msg):
    _attributes.grab_denied.emit()   # 通知战斗系统抓取被拒
    super(msg)
    _ground_state.enter(msg)         # 手动激活 Ground
    _skin.transition_to(_skin_state)

func _on_skin_skin_animation_finished():
    _state_machine.transition_to(_path_next_state)

# 自定义 inspector: _path_next_state 用 HINT_NOT_ATTACK_STATE_LIST
# 确保只能选非攻击状态作为返回
```

**关键规则**:
- 继承 `QuiverCharacterAction` 而非具体子类时，必须**手动管理父状态的 enter/exit**
- 自定义皮肤的 signal 在 `_connect_signals()` 里连接，必须在 `_disconnect_signals()` 里断开（或 super 会自动处理）

### 4.4 TaxMan 场景树（简略）

```
TaxMan (tax_man.gd, groups=["enemies"])
  ├─ Collision (sarge_collision.gd 类似的碰撞脚本)
  ├─ TaxManSkin
  │   ├─ Sprite2D, AnimationPlayer, AnimationTree
  │   ├─ HurtBox (enemy_hurt_box preset)
  │   └─ Attack (包含多个 HitBox, 每个带独立的 attack_data.tres)
  │       ├─ AreaAttack
  │       ├─ DashAttack
  │       └─ StandardAttack
  ├─ StateMachine (tax_man_state_machine.gd, seated_initial_state="Seated")
  │    ├─ Seated (custom seated.gd, 坐椅子)
  │    ├─ Ground
  │    │    ├─ Move (IdleAi + Follow)
  │    │    ├─ Hurt (taxman_hurt.gd, 自定义受击 + 伤害上限)
  │    │    ├─ GrabReject (grab_reject.gd)
  │    │    ├─ AreaAttack, DashAttack, StandardAttack
  │    │    └─ Recovery
  │    ├─ Air
  │    └─ DieAi
  └─ AiStateMachine (tax_man_ai_state_machine.gd)
       ├─ WaitForIdle
       ├─ Phase1
       │    ├─ Wait
       │    ├─ ChooseRandomAttack (Weighted Random: AreaAttack / DashAttack / StandardAttack)
       │    └─ GoToPosition
       ├─ Phase2
       │    ├─ Wait
       │    ├─ ChooseRandomAttack (更多选项 + 更高权重给 AreaAttack)
       │    └─ GoToPosition (用 pool_nodes 指向舞台标记点)
       ├─ Phase3
       │    └─ (更多攻击选择)
       └─ Dead (什么都不做)
```

---

## 5. Stage 场景结构

### 5.1 base_stage.tscn 结构

```
BaseLevel (Node2D, base_stage.gd)
├── Background      (Node2D, z_index=5)
│    └── SkyboxLayer (ParallaxBackground, layer=-1)
├── Level           (Node2D, z_index=15, y_sort=true)
│   ├── Characters  (Node2D, y_sort=true)
│   │    └── Chad (实例玩家场景)
│   │         └── LevelCamera (QuiverLevelCamera, 跟随玩家)
│   ├── Objects     (Node2D, y_sort=true, 装饰物)
│   └── Collisions  (Node2D, visible=false in editor)
│        └── StaticBody2Ds (ceiling limits, floor limits, world hit boxes)
├── Foreground      (Node2D, z_index=25, 前景遮罩图层)
├── FightRooms      (Node2D, z_index=30, invisible at runtime)
│    └── FightRoom1, FightRoom2, ... (QuiverFightRoom nodes)
└── HudLayer        (CanvasLayer, layer=2)
     ├── QuiverVersionLabel
     ├── PlayerHud (player_hud.tscn)
     ├── PauseMenu (pause_menu.tscn)
     └── EndScreen (end_screen.tscn)
```

### 5.2 base_stage.gd

```gdscript
extends Node2D
class_name BaseStage

@export var _path_main_player := NodePath("Level/Characters/Chad")

@onready var _main_player := get_node(_path_main_player) as QuiverCharacter
@onready var _player_hud := $HudLayer/PlayerHud
@onready var _end_screen := $HudLayer/EndScreen

func _ready():
    randomize()
    _player_hud.set_player_attributes(_main_player.attributes)
    Events.player_died.connect(_end_screen.open_end_screen)
```

**`reload_prototype()`** — 开发时快捷重载场景（绑定到快捷键）:
```gdscript
func reload_prototype():
    Events.characters_reseted.emit()
    get_tree().reload_current_scene()
```

### 5.3 stage_01 实现

继承 `base_stage.tscn`，在实例里填充:
- **Background** — 丰富的美术（parallax skybox、建筑、灯杆、招牌）
- **Level/Characters** — TaxMan boss 实例
- **Level/Objects** — Tori gate、throne、brick gate 等场景物件
- **Level/Collisions** — ceiling_limits（layer 4）、floor_limits、ThroneBounce（world hit box）
- **FightRooms** — 5 个 QuiverFightRoom 节点（每个带 Detector + Spawner 组合）

### 5.4 FightRoom 完整流程

以 FightRoom1 为例:

```
FightRooms
└─ FightRoom1 (QuiverFightRoom, ReferenceRect)
   ├─ Fight area: (267, -280) → (2526, 1191), zoom=0.85
   ├─ After fight area: (267, -280) → (5775, 1190)  # 战后扩大
   │
   ├─ QuiverEnemySpawner (位置: 2045, 1074)
   │    _spawn_waves = [[SpawnData(Sarge, IN_PLACE, at spawner)]]
   │
   └─ PlayerDetector (位置: 786, 548, CollisionShape=竖线 1080px)
        path_fight_room = ".."
        paths_enemy_spawners = ["../QuiverEnemySpawner"]
        # auto-connect player_detected → setup_fight_room, spawn_current_wave
```

**stage_01.gd 的 FightRoom2 处理**（多 spawner 必须手动检查完成）:

```gdscript
func _ready():
    super()
    # FightRoom2 有两个 spawner，必须都完成才算过关
    var fight_room_2 = $FightRooms/FightRoom2
    for spawner in get_tree().get_nodes_in_group("fight_2_spawner"):
        spawner.all_waves_completed.connect(_on_fight_2_spawner_completed)

func _on_fight_2_spawner_completed():
    var all_done = get_tree().get_nodes_in_group("fight_2_spawner")\
        .all(func(s): return s.is_completed)
    if all_done:
        $FightRooms/FightRoom2.setup_after_fight_room()
```

### 5.5 HUD 数据流

```
Stage._ready():
    player_hud.set_player_attributes(main_player.attributes)
         │
         └─> player_life_bar.attributes = attrs
              ├─ connect: attrs.health_changed → _on_health_changed()
              └─ connect: attrs.health_depleted → _on_health_depleted()

Player hits enemy → CombatSystem emits Events.enemy_data_sent(enemy, player)
         │
         └─> enemy_health_bar.attributes = enemy_attrs
              ├─ 血条显示
              ├─ connect: attrs.health_changed/depleted
              └─ 敌人死亡 → 隐藏血条
```

**QuiverLifeBar** (`heath_bar.gd`): TextureRect + TextureProgressBar。绑定 attributes 时连接信号，`_update_lifebar_visuals()` 读 `profile_texture` / `life_bar_gradient` / `get_health_as_percentage()`。

---

## 6. 关键差异：玩家 vs 敌人配置

| 方面 | 玩家 (Chad) | 基础敌人 (Sarge) | Boss (TaxMan) |
|---|---|---|---|
| 继承类 | `QuiverCharacter` | `QuiverEnemyCharacter` | `QuiverEnemyCharacter` |
| groups 成员 | `["players"]` | `["enemies"]` | `["enemies"]` + `"tax_man_dash_positions"` |
| body collision_layer | 1 | 16 (layer 5) | 16 |
| body collision_mask | 14 | 14 | 14 |
| 状态机 | 动作 SM（输入驱动） | 动作 SM + AI SM | 动作 SM（自定义 state_machine.gd）+ AI SM（自定义） |
| `should_process_input` | true（默认） | false（AI 驱动） | false（AI 驱动） |
| `_ai_state_hurt` | — | `WaitTillIdle` | `WaitForIdle`（自定义版） |
| Idle 状态 | `Idle`（读输入） | `IdleAi`（等 AI） | `IdleAi` |
| Walk 状态 | `Walk`（读输入） | `Follow`（接受 target） | `Follow` + 冲刺 |
| 空中攻击 | 有（air kick） | 无 | 有（AreaAttack） |
| 死亡状态 | `Die` | `DieAi` | `DieAi` |
| HurtBox | `player_hurt_box` preset | `enemy_hurt_box` preset | `enemy_hurt_box` preset |
| HitBox | `player_hit_box` preset | `enemy_hit_box` preset | `enemy_hit_box` preset |
| 特殊机制 | 3 连击 + 空中踢 | 简单循环 | 多阶段 + 霸体反连击 + 伤害上限 + 抓取拒绝 |

---

## 7. 自定义 Action State 开发清单（从 template 总结）

创建自定义 Action State 时必须：

1. **路径**: `xuanyuan-sword/_beat_em_up/action_states/<name>.gd`
2. **继承**: 通常继承 `QuiverCharacterAction`（最灵活），也可继承具体子类
3. **`@tool`** 必须
4. **手动管理父状态（如果跳过内置基类）**:
   ```gdscript
   @onready var _ground_state := get_parent() as QuiverActionGround
   func enter(msg):
       _ground_state.enter(msg)  # Ground 的 hurt/knockout 信号
       super(msg)                # CharacterAction 的信号
   func exit():
       super()
       _ground_state.exit()
   ```
5. **信号连接**: `_connect_signals()` 里 `get_parent()._connect_signals()` + `super()` + 自定义
6. **自定义 inspector** (可选): `_get_property_list()` 暴露状态路径下拉框

创建自定义 AI State 时类似，放在 `_beat_em_up/ai_states/`，继承 `QuiverAiState`。
