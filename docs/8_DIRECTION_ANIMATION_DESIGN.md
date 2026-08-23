# 多方向动画系统设计

> **版本**: 0.4.0
> **创建日期**: 2026-08-23
> **最后更新**: 2026-08-23
> **状态**: 设计完成，待 Godot 前置验证（附录 D）
> **关联文档**: HEIGHT_LAYER_DESIGN.md, SPELL_SYSTEM_DESIGN.md, PLUGIN_ARCHITECTURE.md
> **变更记录**:
> - v0.1.0 — 初稿（统一 8 方向方案）
> - v0.2.0 — 简化方向分配：idle/walk 8 方向、attack 4 方向、其余保持 2 方向
> - v0.3.0 — 实现级细化：新增 §2.5 外部代码断点修复、§4.1 Walk 完整目标代码、§4.5 Attack 完整 enter() 代码、附录 C 扩展、附录 D 前置验证清单
> - v0.3.1 — §4.5 攻击量化改为水平优先（`>=`），斜角方向量化为左右
> - v0.4.0 — 按"脚本变动"和"动画资源变动"重组文档结构，分为 Part A 和 Part B

---

## 一、系统概述

### 1.1 设计目标

将游戏视角从横版 beat-em-up 转换为**俯视角/斜 45° ARPG**（天之痕原作风格），核心动作支持多方向展示。

**方向分配**：

| 方向数 | 动作 | 说明 |
|--------|------|------|
| 8 方向 | idle, walk | 站立和行走完整 8 方向 |
| 4 方向 | attack1, attack2, attack3 | 上下左右（不含斜角） |
| 2 方向 | jump, rising, falling, landing, air_attack, hurt_mid, hurt_high, die, knockout_* | 左右（保持当前） |

**8 方向**：right、up-right、up、up-left、left、down-left、down、down-right

### 1.2 当前系统（改动基线）

| 项目 | 当前值 |
|------|--------|
| 方向类型 | `SkinDirection` 枚举：`LEFT = -1, RIGHT = 1` |
| 混合节点 | 全部 `AnimationNodeBlendSpace1D`（2 个混合点） |
| blend_position | `float`：`-1`（left）或 `+1`（right） |
| 动画文件数 | 20 动作 × 2 方向 = 40 个 `.tres` |
| 方向判定 | `sign(direction.x)` — 只取水平分量 |
| 精灵方向 | 单套精灵 + `flip_h` 镜像 |
| turn 过渡 | Walk 状态中播放 turn 动画 + 0.6x 减速 |

### 1.3 目标系统

| 项目 | 目标值 |
|------|--------|
| 方向类型 | `Vector2`（归一化方向向量） |
| 混合节点 | idle/walk → BlendSpace2D（8 点），attack → BlendSpace2D（4 点），其余 → BlendSpace1D（不变） |
| blend_position | `Vector2`（如 `Vector2(1, 0)` 表示 right） |
| 动画文件数 | idle/walk ×8 + attack ×4 + 其余 ×2 = 96 个 `.tres`（移除 turn） |
| 方向判定 | idle/walk/attack 用 `direction.normalized()`；其余保持 `sign(direction.x)` |
| 精灵方向 | idle/walk: 5 方向手绘 + 3 方向镜像；attack: 2 方向手绘 + 2 方向镜像 |
| turn 过渡 | 移除（BlendSpace2D 方向间过渡天然平滑） |

---

## 二、架构决策

### 2.1 核心决策：统一 Vector2

**决策**：`skin_direction` 属性类型从 `SkinDirection` 枚举改为 `Vector2`。

**理由**：
- idle/walk/attack 需要多方向支持
- 统一类型消除双属性系统的复杂性
- BlendSpace2D 的 `blend_position` 原生接受 `Vector2`
- BlendSpace1D 的 `blend_position` 也接受 `Vector2`（Godot 会自动转换为 float）

**向后兼容**：
- `SkinDirection` 枚举值保留为常量 `LEFT = -1`、`RIGHT = 1`
- setter 检测 int/float 输入，自动转换为 `Vector2.LEFT` 或 `Vector2.RIGHT`

### 2.2 BlendSpace 混合策略

**决策**：根据动作类型使用不同的 BlendSpace：

| 动作 | BlendSpace 类型 | 混合点数 | blend_position 类型 |
|------|----------------|---------|-------------------|
| idle, walk | AnimationNodeBlendSpace2D | 8 个（8 方向） | Vector2 |
| attack1, attack2, attack3 | AnimationNodeBlendSpace2D | 4 个（上下左右） | Vector2 |
| 其余 | AnimationNodeBlendSpace1D | 2 个（左右） | float（不变） |

**理由**：
- idle/walk 需要完整 8 方向（俯视角 ARPG 的核心体验）
- attack 需要 4 方向（上下左右足以表达攻击朝向）
- jump/hurt/die 等动作方向性较弱，保持 2 方向节省美术工作量
- `_update_blend_directions()` 代码逻辑不变（只变赋值类型）

**BlendSpace2D blend mode**：使用默认的 Blend 模式（连续混合）。

### 2.3 Turn 动画移除

**决策**：从 Walk 状态中移除 turn 动画过渡逻辑。

**理由**：
- BlendSpace2D 在方向变化时自动平滑混合，视觉上不需要离散 turn 动画
- 简化 Walk 状态代码（移除 `_is_turning`、`_turning_speed_modifier`）
- 移除后 turn 相关的 `.tres` 文件可保留在模板中备用，但不在 AnimationTree 中使用

### 2.4 镜像策略

**决策**：根据动作方向数采用不同的镜像策略。

**idle/walk（8 方向）— 5 手绘 + 3 镜像**：

| 手绘方向 | 镜像方向 |
|---------|---------|
| right | left（水平镜像 right） |
| up_right | up_left（水平镜像 up_right） |
| down_right | down_left（水平镜像 down_right） |
| up | —（对称，不镜像） |
| down | —（对称，不镜像） |

**attack（4 方向）— 3 手绘 + 1 镜像**：

| 手绘方向 | 镜像方向 |
|---------|---------|
| right | left（水平镜像 right） |
| up | —（上下不对称，需独立绘制） |
| down | —（上下不对称，需独立绘制） |

**现有工具**：`create_mirrored_animation_button.gd` 已支持 `flip_h`、`position.x`、`polygon` 等轨迹的自动镜像。需要确认是否能正确处理新的命名约定。

### 2.5 外部代码断点修复（关键）

**问题**：setter 的 int/float 兼容转换只处理**赋值**（写入），不处理**比较**（读取）。以下代码会将 `skin_direction`（现在是 Vector2）与 `int` 比较，导致逻辑错误。

**断点清单**：

| 文件 | 行 | 当前代码 | 问题 | 修复代码 |
|------|-----|---------|------|---------|
| `quiver_action_grab_idle.gd` | 71 | `_skin.skin_direction == 1` | `Vector2 == 1` 永远 false | `_skin.skin_direction.x > 0` |
| `spell_manager.gd` | 59 | `skin.skin_direction == -1` | `Vector2 == -1` 永远 false | `skin.skin_direction.x < 0` |
| `quiver_action_walk.gd` | 98 | `facing_direction != _skin.skin_direction` | `int != Vector2` 永远 true | 整段移除（见 §4.1） |

**敌人代码赋值**（setter 兼容可处理，无需改动）：

| 文件 | 行 | 代码 | 处理 |
|------|-----|------|------|
| `enemy_hurt_handler.gd` | 11, 43 | `@export var facing_direction: int = -1` → `_skin.skin_direction = facing_direction` | setter 自动转换 int → Vector2.LEFT/RIGHT |
| `enemy_periodic_attack.gd` | 14, 37 | `@export var facing_direction: int = 1` → `_skin.skin_direction = facing_direction` | 同上 |

**决策**：敌人的 `facing_direction` 保留 `@export int` 类型，只需左右方向。setter 的兼容转换自动处理 int → Vector2 转换，无需修改这些文件。

---

# Part A: 脚本变动

## 三、插件代码改动

### 3.1 `quiver_character_skin.gd` — skin_direction 类型变更

**位置**：`addons/quiver.beat_em_up/characters/quiver_character_skin.gd`，第 36 行（enum）和第 54-62 行（属性）

**当前代码**：
```gdscript
enum SkinDirection { LEFT = -1, RIGHT = 1 }

@export var skin_direction: SkinDirection = SkinDirection.RIGHT:
    set(value):
        var has_changed := value != skin_direction
        skin_direction = value
        if has_changed:
            if not is_inside_tree():
                await ready
            _skin_direction_updated()
```

**目标代码**：
```gdscript
# 保留枚举值为常量（向后兼容）
const SkinDirection_LEFT: int = -1
const SkinDirection_RIGHT: int = 1

@export var skin_direction: Vector2 = Vector2.RIGHT:
    set(value):
        if value is int or value is float:
            value = Vector2.LEFT if value < 0 else Vector2.RIGHT
        var has_changed := not value.is_equal_approx(skin_direction)
        skin_direction = value
        if has_changed:
            if not is_inside_tree():
                await ready
            _skin_direction_updated()
```

**关键改动点**：
1. 类型从 `SkinDirection` → `Vector2`
2. 默认值从 `SkinDirection.RIGHT`（int 1）→ `Vector2.RIGHT`（Vector2(1, 0)）
3. setter 增加 int/float 兼容转换
4. 变更检测用 `is_equal_approx()` 替代 `!=`（Vector2 浮点比较）

### 3.2 `quiver_character_skin_anim_tree.gd` — 零改动

**位置**：`addons/quiver.beat_em_up/characters/quiver_character_skin_anim_tree.gd`

**关键发现**：此文件**无需改动**。原因：

1. **`_get_blend_position_paths_from()`**（第 132-139 行）：
   - BlendSpace2D 在 AnimationTree 属性列表中也暴露 `blend_position` 属性（类型为 Vector2）
   - 现有过滤条件 `property.name.ends_with("blend_position")` 对 BlendSpace1D 和 BlendSpace2D 均匹配
   - BlendSpace2D 的 `blend_position_x`/`blend_position_y` 子属性以 `_x`/`_y` 结尾，不会被误匹配

2. **`_update_blend_directions()`**（第 127-129 行）：
   - `_animation_tree[path] = skin_direction` 对 BlendSpace1D 赋 float、对 BlendSpace2D 赋 Vector2
   - Godot 的 AnimationTree 自动处理类型，代码无需分支

3. **`_handle_animation_node()`**（第 180-182 行）：
   - 已包含 `"AnimationNodeBlendSpace2D"` 匹配，无需添加

### 3.3 插件改动总结

| 文件 | 改动行数 | 复杂度 |
|------|---------|--------|
| `quiver_character_skin.gd` | ~10 行 | 低 |
| `quiver_character_skin_anim_tree.gd` | 0 行 | 零改动 |

---

## 四、Action State 改动

### 4.1 `quiver_action_walk.gd` — 核心改动

**位置**：`addons/quiver.beat_em_up/characters/action_states/ground_actions/move_actions/quiver_action_walk.gd`

**完整目标代码**（展示所有需要改动的方法）：

```gdscript
# --- 变量声明区 ---
# 移除以下变量：
#   var _is_turning := false
#   var _turning_speed_modifier := 0.6
# 保留以下变量（不变）：
var _walk_skin_state := &"walk"
var _path_idle_state := "Ground/Move/Idle"
var _path_grabbing_state := "Ground/Grab/Grabbing"

@onready var _move_state := get_parent() as QuiverActionGroundMove

# --- enter() ---
func enter(msg: = {}) -> void:
    _move_state._direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    super(msg)
    _move_state.enter(msg)
    _skin.transition_to(_walk_skin_state)
    # 移除：_handle_facing_direction()

# --- physics_process() ---
func physics_process(delta: float) -> void:
    _move_state._direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if not _move_state._direction.is_equal_approx(Vector2.ZERO):
        _skin.skin_direction = _move_state._direction.normalized()
    _move_state.physics_process(delta)
    if _move_state._direction.is_equal_approx(Vector2.ZERO):
        _state_machine.transition_to(_path_idle_state)

# --- exit() ---
func exit() -> void:
    super()
    _move_state.exit()
    # 移除：_is_turning = false

# --- _connect_signals() ---
func _connect_signals() -> void:
    super()
    QuiverEditorHelper.connect_between(_attributes.grab_requested, _on_grab_requested)
    # 移除：QuiverEditorHelper.connect_between(_skin.skin_animation_finished, _on_skin_animation_finished)

# --- _disconnect_signals() ---
func _disconnect_signals() -> void:
    super()
    if _attributes != null and _state_machine.has_node(_path_grabbing_state):
        QuiverEditorHelper.disconnect_between(_attributes.grab_requested, _on_grab_requested)
    # 移除：_skin 的 skin_animation_finished 断开
    # if _skin != null:
    #     QuiverEditorHelper.disconnect_between(
    #         _skin.skin_animation_finished, _on_skin_animation_finished
    #     )

# --- _get_custom_properties() ---
func _get_custom_properties() -> Dictionary:
    return {
        "_walk_skin_state": {
            default_value = &"walk",
            type = TYPE_STRING,
            usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
            hint = PROPERTY_HINT_ENUM,
            hint_string = 'ExternalEnum{"property": "_skin", "property_name": "_animation_list"}'
        },
        # 移除：_turn_skin_state 配置项
        # 移除：_turning_speed_modifier 配置项
        "_path_idle_state": { ... },   # 不变
        "_path_grabbing_state": { ... },  # 不变
    }
```

**完全移除的方法**：
- `_handle_facing_direction()` — 整个方法
- `_on_skin_animation_finished()` — 整个方法
- `_on_grab_requested()` — 不变，保留

### 4.2 `quiver_action_mid_air.gd` — 空中方向（不变）

**位置**：`addons/quiver.beat_em_up/characters/action_states/air_actions/jump_actions/quiver_action_mid_air.gd`，第 130-133 行

**决策**：跳跃保持 2 方向（左右），空中方向代码无需改动。

**当前代码**（保持不变）：
```gdscript
func _handle_facing_direction() -> void:
    var facing_direction: int = sign(_character.velocity.x)
    if facing_direction != 0 and facing_direction != _skin.skin_direction:
        _skin.skin_direction = facing_direction
```

**说明**：
- `skin_direction` 类型改为 `Vector2` 后，setter 会自动将 int `-1/1` 转换为 `Vector2.LEFT/RIGHT`
- BlendSpace1D 的 `blend_position` 接受 `Vector2`（Godot 自动提取 x 分量）
- 无需修改代码，向后兼容自动处理

### 4.3 `quiver_action_follow.gd` — AI 跟随

**位置**：`addons/quiver.beat_em_up/characters/action_states/ground_actions/move_actions/quiver_action_follow.gd`，第 141-143 行

**当前代码**：
```gdscript
func _handle_facing_target_node() -> void:
    var facing: int = sign((_target_node.global_position - _character.global_position).x)
    if facing != 0:
        _skin.skin_direction = facing
```

**目标代码**：
```gdscript
func _handle_facing_target_node() -> void:
    var dir := _character.global_position.direction_to(_target_node.global_position)
    if not dir.is_equal_approx(Vector2.ZERO):
        _skin.skin_direction = dir
```

### 4.4 `quiver_action_idle_ai.gd` — AI 闲置朝向

**位置**：`addons/quiver.beat_em_up/characters/action_states/ground_actions/move_actions/quiver_action_idle_ai.gd`，第 44-48 行

**当前代码**：
```gdscript
var facing: int = 1 if (_character.global_position - player.global_position).x >= 0 else -1
_skin.skin_direction = facing
```

**目标代码**：
```gdscript
var dir := _character.global_position.direction_to(player.global_position)
_skin.skin_direction = dir
```

### 4.5 攻击方向锁定策略

**决策**：攻击开始时锁定方向，取最近的四方向（上/下/左/右），攻击期间方向不变。

**位置**：`addons/quiver.beat_em_up/characters/action_states/quiver_action_attack.gd`，第 77-89 行

**当前 `enter()` 方法**：
```gdscript
func enter(msg: = {}) -> void:
    super(msg)
    if _should_enter_parent:
        get_parent().enter(msg)
    
    if msg.has("auto_combo") and msg.auto_combo > 0 and _can_combo:
        _should_combo = true
        _auto_combo_amount = msg.auto_combo
    else:
        _should_combo = false
        _state_machine.set_process_unhandled_input(_can_combo)
    
    _skin.transition_to(_skin_state)
```

**目标 `enter()` 方法**（量化代码插入位置精确标注）：
```gdscript
func enter(msg: = {}) -> void:
    super(msg)
    if _should_enter_parent:
        get_parent().enter(msg)
    
    if msg.has("auto_combo") and msg.auto_combo > 0 and _can_combo:
        _should_combo = true
        _auto_combo_amount = msg.auto_combo
    else:
        _should_combo = false
        _state_machine.set_process_unhandled_input(_can_combo)
    
    # ===== 新增：将当前 8 方向量化为最近的 4 方向（水平优先） =====
    var dir := _skin.skin_direction
    if abs(dir.x) >= abs(dir.y):
        _skin.skin_direction = Vector2(sign(dir.x), 0)
    else:
        _skin.skin_direction = Vector2(0, sign(dir.y))
    # ===== 新增结束 =====
    
    _skin.transition_to(_skin_state)
```

**量化规则**（水平优先：`>=` 使斜角偏向水平）：
- 输入 `(1, 0)` → `(1, 0)` right
- 输入 `(0.707, -0.707)` up-right → `(1, 0)` right（|x| >= |y| 时取水平分量）
- 输入 `(0, -1)` → `(0, -1)` up
- 输入 `(-0.707, 0.707)` down-left → `(-1, 0)` left
- 输入 `(0, 0)` → `(0, 0)`（极端情况：idle 时攻击，BlendSpace2D 选最近动画点）

**设计决策**：
- **水平优先**：斜角方向（|x| == |y|）量化为左右方向，符合大多数 ARPG 的习惯
- **方向锁定**：攻击过程中不响应输入变化，`physics_process()` 中不更新 `skin_direction`
- `quiver_action_attack.gd` 原本不操作 `skin_direction`（方向继承 walk），现在需要在 enter() 中主动量化
- 此文件还有其他代码（combo、attack movement），但方向相关的改动仅限 enter()

### 4.6 不需要改动的文件

| 文件 | 理由 |
|------|------|
| `quiver_action_idle.gd` | 不设置方向 |
| `quiver_action_move.gd` | 只管 velocity + move_and_slide()，不操作方向 |
| `quiver_action_hurt.gd` | 不设置方向（hurt 保持 2 方向） |
| `quiver_action_die.gd` | 不设置方向 |
| `quiver_action_ground.gd` | 不设置方向 |
| `quiver_action_jump.gd` | 不设置方向（jump 保持 2 方向） |
| `quiver_action_impulse.gd` | 不设置方向 |
| `quiver_action_landing.gd` | 不设置方向 |

---

# Part B: 动画资源变动

## 五、动画树结构

### 5.1 BlendSpace 配置

**idle/walk（8 方向）— BlendSpace2D（8 个混合点）**：

```
AnimationNodeBlendSpace2D (idle)
  blend_space_mode: 0  (BlendSpace2D 标准 Blend 模式)
  blend_point_0: idle_right      @ Vector2(1, 0)
  blend_point_1: idle_up_right   @ Vector2(0.707, -0.707)
  blend_point_2: idle_up         @ Vector2(0, -1)
  blend_point_3: idle_up_left    @ Vector2(-0.707, -0.707)
  blend_point_4: idle_left       @ Vector2(-1, 0)
  blend_point_5: idle_down_left  @ Vector2(-0.707, 0.707)
  blend_point_6: idle_down       @ Vector2(0, 1)
  blend_point_7: idle_down_right @ Vector2(0.707, 0.707)
```

**attack1/2/3（4 方向）— BlendSpace2D（4 个混合点）**：

```
AnimationNodeBlendSpace2D (attack1)
  blend_space_mode: 0
  blend_point_0: attack1_right   @ Vector2(1, 0)
  blend_point_1: attack1_up      @ Vector2(0, -1)
  blend_point_2: attack1_left    @ Vector2(-1, 0)
  blend_point_3: attack1_down    @ Vector2(0, 1)
```

**其余动作（2 方向）— BlendSpace1D（不变）**：

```
AnimationNodeBlendSpace1D (jump)
  blend_point_0: jump_right  @ 0.1
  blend_point_1: jump_left   @ -0.1
```

### 5.2 坐标约定

**8 方向（idle/walk）**：

| 方向 | blend_position | 动画名后缀 | 屏幕方向 |
|------|---------------|-----------|---------|
| Right | `(1, 0)` | `_right` | 屏幕右方 |
| Up-Right | `(0.707, -0.707)` | `_up_right` | 屏幕右上方 |
| Up | `(0, -1)` | `_up` | 屏幕上方（远离镜头） |
| Up-Left | `(-0.707, -0.707)` | `_up_left` | 屏幕左上方 |
| Left | `(-1, 0)` | `_left` | 屏幕左方 |
| Down-Left | `(-0.707, 0.707)` | `_down_left` | 屏幕左下方 |
| Down | `(0, 1)` | `_down` | 屏幕下方（朝向镜头） |
| Down-Right | `(0.707, 0.707)` | `_down_right` | 屏幕右下方 |

**4 方向（attack）**：

| 方向 | blend_position | 动画名后缀 |
|------|---------------|-----------|
| Right | `(1, 0)` | `_right` |
| Up | `(0, -1)` | `_up` |
| Left | `(-1, 0)` | `_left` |
| Down | `(0, 1)` | `_down` |

**2 方向（其余）— 不变**：

| 方向 | blend_position | 动画名后缀 |
|------|---------------|-----------|
| Right | `1.0` | `_right` |
| Left | `-1.0` | `_left` |

**坐标轴**：与 Godot 屏幕坐标系一致。X 正方向 = 右，Y 正方向 = 下。

### 5.3 AnimationNodeStateMachine 状态列表

```
AnimationNodeStateMachine
├── idle              → BlendSpace2D（8 方向）  [改动]
├── walk              → BlendSpace2D（8 方向）  [改动]
├── turn              → [移除或保留为过渡动画备用]
├── attack1           → BlendSpace2D（4 方向）  [改动]
├── attack2           → BlendSpace2D（4 方向）  [改动]
├── attack3           → BlendSpace2D（4 方向）  [改动]
├── air_attack        → BlendSpace1D（2 方向）  [不变]
├── jump              → BlendSpace1D（2 方向）  [不变]
├── rising            → BlendSpace1D（2 方向）  [不变]
├── falling           → BlendSpace1D（2 方向）  [不变]
├── landing           → BlendSpace1D（2 方向）  [不变]
├── hurt_mid          → BlendSpace1D（2 方向）  [不变]
├── hurt_high         → BlendSpace1D（2 方向）  [不变]
├── die               → BlendSpace1D（2 方向）  [不变]
├── knockout_launch   → BlendSpace1D（2 方向）  [不变]
├── knockout_rising   → BlendSpace1D（2 方向）  [不变]
├── knockout_falling  → BlendSpace1D（2 方向）  [不变]
├── knockout_bounce   → BlendSpace1D（2 方向）  [不变]
└── knockout_ground   → AnimationNodeStateMachine（嵌套） [不变]
    ├── knockout_landed → BlendSpace1D（2 方向）
    └── getting_up      → BlendSpace1D（2 方向）
```

**改动统计**：5 个状态改为 BlendSpace2D（idle, walk, attack1, attack2, attack3），15 个状态保持 BlendSpace1D。

### 5.4 `.tscn` 默认值变更

```
# BlendSpace2D 状态（idle, walk, attack1, attack2, attack3）:
parameters/state_machine/idle/blend_position = Vector2(1, 0)
parameters/state_machine/walk/blend_position = Vector2(1, 0)
parameters/state_machine/attack1/blend_position = Vector2(1, 0)
parameters/state_machine/attack2/blend_position = Vector2(1, 0)
parameters/state_machine/attack3/blend_position = Vector2(1, 0)

# BlendSpace1D 状态（不变）:
parameters/state_machine/jump/blend_position = 1.0
parameters/state_machine/hurt_mid/blend_position = 1.0
...
```

---

## 六、动画资源

### 6.1 文件清单

| 方向数 | 动作 | 文件数 |
|--------|------|--------|
| 8 方向 | idle, walk | 2 × 8 = 16 |
| 4 方向 | attack1, attack2, attack3 | 3 × 4 = 12 |
| 2 方向 | air_attack, jump, rising, falling, landing, hurt_mid, hurt_high, die, knockout_launch, knockout_rising, knockout_falling, knockout_bounce, knockout_landed, getting_up | 14 × 2 = 28 |
| **总计** | **19 动作** | **56 个 `.tres`** |

**8 方向文件示例（idle）**：
```
idle_right.tres        idle_up_right.tres     idle_up.tres
idle_up_left.tres      idle_left.tres         idle_down_left.tres
idle_down.tres         idle_down_right.tres
```

**4 方向文件示例（attack1）**：
```
attack1_right.tres     attack1_up.tres
attack1_left.tres      attack1_down.tres
```

**2 方向文件（不变）**：
```
jump_left.tres         jump_right.tres
```

### 6.2 每个动画文件内的轨迹

与当前 left/right 文件相同的轨迹结构。各方向动画文件共享相同的轨迹类型：

| 轨迹 | 说明 | 方向差异 |
|------|------|---------|
| `AnimatedSprite2D:animation` | SpriteFrames 动画名 | 每个方向对应不同的 SpriteFrames 动画 |
| `AnimatedSprite2D:frame` | 帧索引 | 每个方向的帧序列可能不同 |
| `AnimatedSprite2D:position` | 精灵偏移 | 各方向独立 |
| `AnimatedSprite2D:flip_h` | 水平翻转 | 8/4 方向独立精灵后不再需要（每方向直接绘制正确朝向） |
| `AnimatedSprite2D/HurtBox/HurtShape:position` | 受击框位置 | 8/4 方向各自独立 |
| `Attacks/AttackN/AttackNShape:position` | 攻击框位置 | 各方向不同 |
| `Attacks/AttackN/AttackNShape:disabled` | 攻击框启用 | 不变（与方向无关） |
| `.:physical_height` | 物理高度 | 不变 |
| `.:attack_heights` | 攻击高度 | 不变 |

### 6.3 SpriteFrames 扩展

当前 SpriteFrames 资源（`spriteframes_*.tres`）包含 18 个动画。多方向后需要扩展：

| 动作 | 当前动画数 | 目标动画数 | 新增 |
|------|----------|----------|------|
| idle | 1 | 8 | +7 |
| walk | 1 | 8 | +7 |
| attack_1, attack_2, attack_3 | 3 | 12 (3×4) | +9 |
| 其余 | 13 | 13 | 0 |
| **总计** | **18** | **41** | **+23** |

**SpriteFrames 命名策略**：

| 方向数 | 命名格式 | 示例 |
|--------|---------|------|
| 8 方向 | `<base>_<dir>` | `idle_right`, `idle_up_right`, `idle_up`, `idle_up_left`, `idle_left`, `idle_down_left`, `idle_down`, `idle_down_right` |
| 4 方向 | `<base>_<dir>` | `attack_1_right`, `attack_1_up`, `attack_1_left`, `attack_1_down` |
| 2 方向 | `<base>` (right), `<base>_left` | `jump`, `jump_left` |

**说明**：
- 8 方向和 4 方向使用方向后缀明确标识
- 2 方向保持当前命名约定（right 为默认名，left 加 `_left` 后缀）
- 方向后缀：`right`, `up_right`, `up`, `up_left`, `left`, `down_left`, `down`, `down_right`

### 6.4 镜像生成规则

**8 方向（idle/walk）— 5 手绘 + 3 镜像**：

| 源方向 | 镜像方向 | 镜像操作 |
|--------|---------|---------|
| right | left | `flip_h` 反转、`position.x` 取反、`polygon.x` 取反 |
| up_right | up_left | 同上 |
| down_right | down_left | 同上 |

**4 方向（attack）— 3 手绘 + 1 镜像**：

| 源方向 | 镜像方向 | 镜像操作 |
|--------|---------|---------|
| right | left | 同上 |
| up | — | 独立绘制（上下不对称） |
| down | — | 独立绘制（上下不对称） |

**现有工具**：`create_mirrored_animation_button.gd` 已实现完整的镜像逻辑，可直接复用。需要确认命名映射（`_right` → `_left`，`_up_right` → `_up_left`，`_down_right` → `_down_left`）。

---

## 七、法术系统影响

### 7.1 法术方向

**决策**：法术暂不改动，保持当前 2 方向（left/right）。

**理由**：
- 法术的 `SpellSkin` 有独立的 `skin_direction` 属性（不继承 `QuiverCharacterSkin`）
- 投射物方向由 cast 参数控制，不依赖 AnimationTree 的 BlendSpace
- 后续如有需要，可按相同模式改为 BlendSpace2D

### 7.2 `spell_base.gd` 影响

`spell_base.gd` 的 `cast()` 方法设置 `_skin.skin_direction`（SpellSkin 的，不是 QuiverCharacterSkin 的）。由于 SpellSkin 不改类型，此处不受影响。

---

## 八、模板与角色创建工具

### 8.1 模板文件更新

| 文件 | 改动 |
|------|------|
| `_template/__NAME___skin.tscn` | 5 个 BlendSpace2D 状态的 `blend_position = 1.0` → `Vector2(1, 0)` |
| `_template/resources/animations/animation_tree_root.tres` | 5 个节点从 BlendSpace1D → BlendSpace2D（idle, walk, attack1, attack2, attack3） |
| `_template/resources/animations/` | 新增 16 个方向文件（idle/walk 各 +6，attack1/2/3 各 +2） |
| `_template/resources/sprites/` | 新增精灵目录（idle/walk: up_right, up, down_right；attack: up, down） |
| `_template/resources/spriteframes___NAME__.tres` | 新增 23 个 SpriteFrames 动画 |
| `_template/resources/anim_library___NAME__.tres` | 注册新动画（从 40 条目扩展到 56 条目） |

### 8.2 角色创建工具 `character_creator.gd`

角色创建器（Inspector 工具）复制模板文件并替换占位符。需要更新：

- 复制 8 方向动画文件（不只是 left/right）
- 替换动画文件中的库前缀（`__CLASS__/` → `CharacterName/`）
- 更新 `anim_library_*.tres` 中的条目数

[待细化：具体代码改动细节]

### 8.3 镜像动画工具 `create_mirrored_animation_button.gd`

需要确认：
- 是否正确处理 8 方向的命名（`_right` → `_left`，`_up_right` → `_up_left`）
- 是否正确处理 BlendSpace2D 的镜像点位置

---

## 九、向后兼容与迁移

### 9.1 已有角色迁移步骤

**chen_jingchou**：
1. `animation_tree_root.tres`：5 个 BlendSpace1D → BlendSpace2D（idle, walk, attack1, attack2, attack3）
2. `chen_jingchou_skin.tscn`：5 个 `blend_position = 1.0` → `Vector2(1, 0)`
3. 新增 16 个方向动画文件（idle/walk 各 +6，attack1/2/3 各 +2）
4. 新增精灵资产（idle/walk: 3 方向手绘 + 3 方向镜像；attack: 2 方向手绘 + 1 方向镜像）
5. 更新 `anim_library_chen_jingchou.tres`：注册新动画（40 → 56 条目）
6. 更新 `spriteframes_chen_jingchou.tres`：新增 SpriteFrames 动画（18 → 41）

**chenjianchou_new**：同上步骤。

### 9.2 SkinDirection 兼容

代码中使用 `SkinDirection.LEFT` / `SkinDirection.RIGHT` 的地方：
- 改为 `SkinDirection_LEFT` / `SkinDirection_RIGHT` 常量引用
- 或直接改为 `Vector2.LEFT` / `Vector2.RIGHT`

### 9.3 外部引用兼容

任何外部代码设置 `skin_direction = -1` 或 `skin_direction = 1` 的地方，setter 的 int/float 兼容转换会自动处理。无需立即修改所有调用点。

---

## 十、待细化清单

| # | 章节 | 问题 | 优先级 | 状态 |
|---|------|------|--------|------|
| 1 | §4.2 | Mid-air 方向是否包含 Y 分量？ | 高 | ✅ 已解决：jump 保持 2 方向，代码不变 |
| 2 | §5.1 | BlendSpace2D 的 blend mode 选择 | 高 | ✅ 已解决：使用默认 Blend 模式 |
| 3 | §6.2 | 多方向独立精灵后 `flip_h` 轨迹是否还需要？ | 中 | ✅ 已解决：8/4 方向不再需要 flip_h；2 方向保持现状 |
| 4 | §6.3 | SpriteFrames 多方向的命名和组织策略 | 高 | ✅ 已解决：见 §6.3 命名策略 |
| 5 | §6.2 | HurtShape 各方向位置是否需要不同？ | 中 | ✅ 已解决：hurt 保持 2 方向，暂不需要 |
| 6 | §8.2 | 角色创建工具的具体代码改动 | 中 | ✅ 已解决：创建工具无需改动（方向无关的通用复制器） |
| 7 | §4 | 攻击时方向锁定策略 | 高 | ✅ 已解决：攻击开始时量化为最近 4 方向并锁定，见 §4.5 |
| 8 | §4 | 受击方向由什么决定？ | 中 | ✅ 已解决：hurt 保持 2 方向，暂不需要 |
| 9 | §5.3 | turn 状态是移除还是保留？ | 低 | ✅ 已解决：从 AnimationTree 移除，`.tres` 文件保留备用 |
| 10 | §8 | 轮廓转换工具是否需要适配多方向？ | 低 | ✅ 已解决：无需改动，工具已按动画文件独立处理 |

**所有待细化项已解决。**

---

## 附录 A：BlendSpace2D 在 Godot 4 中的属性路径

通过 `AnimationTree.get_property_list()` 获取的属性：

```
parameters/state_machine/idle/blend_position      (Vector2)  ← 匹配 ends_with("blend_position")
parameters/state_machine/walk/blend_position       (Vector2)  ← 匹配
parameters/state_machine/attack1/blend_position    (Vector2)  ← 匹配
...
parameters/state_machine/idle/blend_position_x     (float)    ← 不匹配（以 _x 结尾）
parameters/state_machine/idle/blend_position_y     (float)    ← 不匹配（以 _y 结尾）
```

`_get_blend_position_paths_from()` 的过滤条件 `ends_with("blend_position")` 只匹配主属性（Vector2），不匹配 `_x`/`_y` 子属性。

## 附录 B：文件改动影响矩阵

| 文件 | 改动类型 | 影响范围 |
|------|---------|---------|
| `quiver_character_skin.gd` | 修改（~10 行） | 所有角色 |
| `quiver_character_skin_anim_tree.gd` | 无改动 | — |
| `quiver_action_walk.gd` | 修改（~20 行） | Walk 状态行为 |
| `quiver_action_attack.gd` | 修改（~5 行） | 攻击方向量化锁定 |
| `quiver_action_mid_air.gd` | 无改动 | jump 保持 2 方向，向后兼容 |
| `quiver_action_follow.gd` | 修改（~5 行） | AI 跟随方向 |
| `quiver_action_idle_ai.gd` | 修改（~3 行） | AI 闲置朝向 |
| `animation_tree_root.tres` | 修改 5 个节点 | 每个角色各一份 |
| `*_skin.tscn` | 修改 5 个默认值 | 每个角色各一份 |
| 动画 `.tres` × 16 新增 | 新增 | 每个角色各一套 |
| `spriteframes_*.tres` | 扩展（+23 动画） | 每个角色各一份 |
| `anim_library_*.tres` | 扩展（+16 条目） | 每个角色各一份 |

## 附录 C：当前所有设置/读取 `skin_direction` 的代码位置

| 文件 | 行 | 上下文 | 当前值 | 目标值 | 需要改动 |
|------|------|--------|--------|--------|---------|
| `quiver_character_skin.gd` | 36, 54-62 | 声明 + setter | `enum SkinDirection` | `Vector2` + 兼容转换 | **是** |
| `quiver_character_skin_anim_tree.gd` | 127-129 | 赋值 blend_position | `skin_direction`（int） | `skin_direction`（Vector2） | **否**（类型透明） |
| `quiver_action_walk.gd` | 73-83 | Walk physics_process | `sign(dir.x)` → int | `dir.normalized()` → Vector2 | **是**（完整重写） |
| `quiver_action_walk.gd` | 98 | Walk 方向比较 | `int != skin_direction` | 整段移除 | **是**（移除） |
| `quiver_action_follow.gd` | 141-143 | AI 跟随 | `sign(delta.x)` → int | `direction_to()` → Vector2 | **是** |
| `quiver_action_idle_ai.gd` | 44-48 | AI 闲置 | `1 if x>=0 else -1` | `direction_to()` → Vector2 | **是** |
| `quiver_action_mid_air.gd` | 130-133 | 空中朝向 | `sign(vel.x)` → int | 不变（setter 自动兼容） | **否** |
| `quiver_action_grab_idle.gd` | 71 | Grab 释放方向比较 | `skin_direction == 1` | `skin_direction.x > 0` | **是**（比较修复） |
| `quiver_action_attack.gd` | 77-89 | 攻击 enter() | 不操作方向 | 新增 4 方向量化 | **是**（新增代码） |
| `enemy_hurt_handler.gd` | 11, 43 | 敌人 facing | `@export int` → 赋值 | setter 兼容转换 | **否** |
| `enemy_periodic_attack.gd` | 14, 37 | 敌人 facing | `@export int` → 赋值 | setter 兼容转换 | **否** |
| `spell_base.gd` | 61 | 法术施放 | SpellSkin（独立） | 不改 | **否** |
| `spell_manager.gd` | 59 | 法术方向比较 | `skin_direction == -1` | `skin_direction.x < 0` | **是**（比较修复） |

**需要改动的文件总计**：6 个
- `quiver_character_skin.gd`
- `quiver_action_walk.gd`
- `quiver_action_follow.gd`
- `quiver_action_idle_ai.gd`
- `quiver_action_grab_idle.gd`
- `quiver_action_attack.gd`
- `spell_manager.gd`

---

## 附录 D：实现前置验证清单

以下步骤需要用户在 Windows Godot 编辑器中完成。

### Step 0：BlendSpace2D `.tres` 格式验证

**目标**：确认手编 `.tres` 文件的精确格式。

**操作步骤**：

1. 在 Godot 编辑器中打开 chen_jingchou 的 `_skin.tscn`
2. 选中 `AnimationTree` 节点
3. 在 Inspector 中打开 `tree_root`（`animation_tree_root.tres`）
4. 将 `idle` 状态的 `AnimationNodeBlendSpace1D` 替换为 `AnimationNodeBlendSpace2D`
5. 添加 8 个混合点（可先用占位动画），设置对应的 `pos` 值
6. **保存场景**（Ctrl+S）
7. 打开 `animation_tree_root.tres` 文件，复制 idle 节点的完整 `.tres` 文本

**需要确认的项目**：

| 项目 | 问题 | 影响 |
|------|------|------|
| `triangles` 属性 | 是否需要手写？`auto_triangles=true` 时 Godot 是否自动生成？ | 决定 .tres 是否需要 PackedInt32Array |
| `pos` 精度 | 是否需要 `0.707107` 还是 `0.707` 够用？ | 决定坐标值格式 |
| `blend_point_<N>/name` | 字符串值是什么？`"0"` 到 `"7"` 还是方向名？ | 决定 name 字段 |
| 其他属性 | 除 `blend_point_*` 和 `triangles` 外，是否有其他非默认属性被写入？ | 确保格式完整 |
| `auto_triangles` | 是否需要显式写入 `auto_triangles = true`？ | 决定是否需要此行 |

### Step 0b：BlendSpace1D 赋值 Vector2 验证

**目标**：确认 BlendSpace1D 的 `blend_position` 接受 Vector2 赋值。

**操作步骤**：

1. 创建一个最小测试场景：CharacterBody2D + AnimationTree（包含一个 BlendSpace1D）
2. 在 GDScript 中运行：
   ```gdscript
   $AnimationTree["parameters/blend_position"] = Vector2(1, 0)
   print($AnimationTree["parameters/blend_position"])
   ```
3. 观察输出：是 `1.0`（自动提取 x）还是报错？

**如果报错**：需要在 `_update_blend_directions()` 中分离 1D 和 2D 路径：
```gdscript
func _update_blend_directions() -> void:
    for path in _blend_positions_1d:
        _animation_tree[path] = skin_direction.x  # float
    for path in _blend_positions_2d:
        _animation_tree[path] = skin_direction    # Vector2
```

### Step 0c：.tscn 中 Vector2 值格式验证

**目标**：确认 `.tscn` 文件中 Vector2 属性的写法。

**操作步骤**：

1. 在 Godot 中修改 `__NAME___skin.tscn` 的某个 BlendSpace2D `blend_position` 为 `Vector2(1, 0)`
2. 保存后读取 `.tscn` 文件，确认格式
3. 预期格式：`parameters/state_machine/idle/blend_position = Vector2(1, 0)`

### 验证完成后更新文档

完成 Step 0/0b/0c 后，将结果更新到以下章节：
- §5.1：BlendSpace2D 精确 `.tres` 格式
- §3.2：BlendSpace1D + Vector2 兼容性结论
- §5.4：`.tscn` 中 Vector2 的精确写法
- §6.1：新动画文件的占位符 `.tres` 模板
