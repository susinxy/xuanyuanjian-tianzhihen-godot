# 8 方向动画系统设计

> **版本**: 0.1.0（初稿）
> **创建日期**: 2026-08-23
> **状态**: 设计中，待逐章细化
> **关联文档**: HEIGHT_LAYER_DESIGN.md, SPELL_SYSTEM_DESIGN.md, PLUGIN_ARCHITECTURE.md

---

## 一、系统概述

### 1.1 设计目标

将游戏视角从横版 beat-em-up 转换为**俯视角/斜 45° ARPG**（天之痕原作风格），角色的所有动作动画支持 8 方向展示。

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
| 混合节点 | 全部 `AnimationNodeBlendSpace2D`（8 个混合点） |
| blend_position | `Vector2`（如 `Vector2(1, 0)` 表示 right） |
| 动画文件数 | 19 动作 × 8 方向 = 152 个 `.tres`（移除 turn） |
| 方向判定 | `direction.normalized()` — 使用完整 2D 向量 |
| 精灵方向 | 5 套独立方向精灵 + 3 套镜像生成 |
| turn 过渡 | 移除（BlendSpace2D 方向间过渡天然平滑） |

---

## 二、架构决策

### 2.1 核心决策：统一 Vector2

**决策**：`skin_direction` 属性类型从 `SkinDirection` 枚举改为 `Vector2`。

**理由**：
- 所有状态（idle/walk/attack/jump/hurt/die/knockout）都需要 8 方向
- 统一类型消除双属性系统的复杂性
- BlendSpace2D 的 `blend_position` 原生接受 `Vector2`

**向后兼容**：
- `SkinDirection` 枚举值保留为常量 `LEFT = -1`、`RIGHT = 1`
- setter 检测 int/float 输入，自动转换为 `Vector2.LEFT` 或 `Vector2.RIGHT`

### 2.2 BlendSpace2D 选型

**决策**：使用 Godot 原生 `AnimationNodeBlendSpace2D` 替换所有 `AnimationNodeBlendSpace1D`。

**理由**：
- Godot 原生支持，无需自定义 AnimationNode
- 方向间自动平滑过渡（加权混合）
- `_update_blend_directions()` 代码逻辑不变（只变赋值类型）

**BlendSpace2D blend mode**：使用默认的 Blend 模式（连续混合），不使用 Discrete 模式。[待细化：是否某些状态需要 Discrete？]

### 2.3 Turn 动画移除

**决策**：从 Walk 状态中移除 turn 动画过渡逻辑。

**理由**：
- BlendSpace2D 在方向变化时自动平滑混合，视觉上不需要离散 turn 动画
- 简化 Walk 状态代码（移除 `_is_turning`、`_turning_speed_modifier`）
- 移除后 turn 相关的 `.tres` 文件可保留在模板中备用，但不在 AnimationTree 中使用

### 2.4 镜像策略

**决策**：美术绘制 5 个方向的精灵，剩余 3 个方向由镜像工具自动生成。

| 手绘方向 | 镜像方向 |
|---------|---------|
| right | left（水平镜像 right） |
| up_right | up_left（水平镜像 up_right） |
| down_right | down_left（水平镜像 down_right） |
| up | —（对称，不镜像） |
| down | —（对称，不镜像） |

**现有工具**：`create_mirrored_animation_button.gd` 已支持 `flip_h`、`position.x`、`polygon` 等轨迹的自动镜像。需要确认是否能正确处理新的命名约定。

---

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

**当前代码**（关键片段）：
```gdscript
func physics_process(delta: float) -> void:
    _move_state._direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    _handle_facing_direction()
    if _is_turning:
        _move_state._direction *= _turning_speed_modifier
    _move_state.physics_process(delta)
    if _move_state._direction.is_equal_approx(Vector2.ZERO):
        _state_machine.transition_to(_path_idle_state)

func _handle_facing_direction() -> void:
    var facing_direction: int = sign(_move_state._direction.x)
    if facing_direction != 0 and facing_direction != _skin.skin_direction:
        _skin.skin_direction = facing_direction
        _skin.transition_to(_turn_skin_state)
        QuiverEditorHelper.connect_between(
            _skin.skin_animation_finished, _on_skin_animation_finished
        )
        _is_turning = true

func _on_skin_animation_finished() -> void:
    _skin.transition_to(_walk_skin_state)
    _skin.skin_animation_finished.disconnect(_on_skin_animation_finished)
    _is_turning = false
```

**目标代码**：
```gdscript
func physics_process(delta: float) -> void:
    _move_state._direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if not _move_state._direction.is_equal_approx(Vector2.ZERO):
        _skin.skin_direction = _move_state._direction.normalized()
    _move_state.physics_process(delta)
    if _move_state._direction.is_equal_approx(Vector2.ZERO):
        _state_machine.transition_to(_path_idle_state)
```

**移除的内容**：
- `_handle_facing_direction()` 方法
- `_is_turning` 变量
- `_turning_speed_modifier` 变量（及对应 Inspector 配置）
- `_on_skin_animation_finished()` 方法
- `_connect_signals()` / `_disconnect_signals()` 中的 `skin_animation_finished` 连接
- `_turn_skin_state` 变量（及对应 Inspector 配置）
- `enter()` 中的 `_handle_facing_direction()` 调用

### 4.2 `quiver_action_mid_air.gd` — 空中方向

**位置**：`addons/quiver.beat_em_up/characters/action_states/air_actions/jump_actions/quiver_action_mid_air.gd`，第 130-133 行

**当前代码**：
```gdscript
func _handle_facing_direction() -> void:
    var facing_direction: int = sign(_character.velocity.x)
    if facing_direction != 0 and facing_direction != _skin.skin_direction:
        _skin.skin_direction = facing_direction
```

**目标代码**：
```gdscript
func _handle_facing_direction() -> void:
    var facing := Vector2(_character.velocity.x, _character.velocity.y).normalized()
    if not facing.is_equal_approx(Vector2.ZERO):
        _skin.skin_direction = facing
```

**待细化**：空中方向是否应该包含 Y 分量？垂直分量受重力影响可能导致方向快速变化。可能需要只取水平分量。

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

### 4.5 不需要改动的文件

| 文件 | 理由 |
|------|------|
| `quiver_action_idle.gd` | 不设置方向 |
| `quiver_action_move.gd` | 只管 velocity + move_and_slide()，不操作方向 |
| `quiver_action_attack.gd` | 不设置方向（继承 walk/idle 设置的值） |
| `quiver_action_hurt.gd` | 不设置方向 |
| `quiver_action_die.gd` | 不设置方向 |
| `quiver_action_ground.gd` | 不设置方向 |
| `quiver_action_jump.gd` | 不设置方向 |
| `quiver_action_impulse.gd` | 不设置方向 |
| `quiver_action_landing.gd` | 不设置方向 |

---

## 五、动画树结构

### 5.1 BlendSpace2D 配置

每个动画状态（idle、walk、attack1 等）从 BlendSpace1D 替换为 BlendSpace2D，包含 8 个混合点：

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

### 5.2 坐标约定

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

**坐标轴**：与 Godot 屏幕坐标系一致。X 正方向 = 右，Y 正方向 = 下。

### 5.3 AnimationNodeStateMachine 状态列表

状态名称不变，只改内部混合节点类型：

```
AnimationNodeStateMachine
├── idle              → BlendSpace2D（8 方向）
├── walk              → BlendSpace2D（8 方向）
├── turn              → [移除或保留为过渡动画备用]
├── attack1           → BlendSpace2D（8 方向）
├── attack2           → BlendSpace2D（8 方向）
├── attack3           → BlendSpace2D（8 方向）
├── air_attack        → BlendSpace2D（8 方向）
├── jump              → BlendSpace2D（8 方向）
├── rising            → BlendSpace2D（8 方向）
├── falling           → BlendSpace2D（8 方向）
├── landing           → BlendSpace2D（8 方向）
├── hurt_mid          → BlendSpace2D（8 方向）
├── hurt_high         → BlendSpace2D（8 方向）
├── die               → BlendSpace2D（8 方向）
├── knockout_launch   → BlendSpace2D（8 方向）
├── knockout_rising   → BlendSpace2D（8 方向）
├── knockout_falling  → BlendSpace2D（8 方向）
├── knockout_bounce   → BlendSpace2D（8 方向）
└── knockout_ground   → AnimationNodeStateMachine（嵌套）
    ├── knockout_landed → BlendSpace2D（8 方向）
    └── getting_up      → BlendSpace2D（8 方向）
```

### 5.4 `.tscn` 默认值变更

```
# 当前（BlendSpace1D）:
parameters/state_machine/idle/blend_position = 1.0
parameters/state_machine/walk/blend_position = 1.0
...

# 目标（BlendSpace2D）:
parameters/state_machine/idle/blend_position = Vector2(1, 0)
parameters/state_machine/walk/blend_position = Vector2(1, 0)
...
```

---

## 六、动画资源

### 6.1 文件清单

每个动作 8 个方向文件，总计 19 动作 × 8 = 152 个动画 `.tres` 文件。

**以 idle 为例**：
```
idle_right.tres        # 右方
idle_up_right.tres     # 右上方
idle_up.tres           # 上方
idle_up_left.tres      # 左上方
idle_left.tres         # 左方
idle_down_left.tres    # 左下方
idle_down.tres         # 下方
idle_down_right.tres   # 右下方
```

**完整动作列表**（19 个）：
idle, walk, attack1, attack2, attack3, air_attack, jump, rising, falling, landing,
hurt_mid, hurt_high, die, knockout_launch, knockout_rising, knockout_falling,
knockout_bounce, knockout_landed, getting_up

### 6.2 每个动画文件内的轨迹

与当前 left/right 文件相同的轨迹结构，但需要适配 8 方向：

| 轨迹 | 说明 | 方向差异 |
|------|------|---------|
| `AnimatedSprite2D:animation` | SpriteFrames 动画名 | 每个方向对应不同的 SpriteFrames 动画 |
| `AnimatedSprite2D:frame` | 帧索引 | 每个方向的帧序列可能不同 |
| `AnimatedSprite2D:position` | 精灵偏移 | 各方向独立 |
| `AnimatedSprite2D:flip_h` | 水平翻转 | [待细化：8 方向独立精灵后是否还需要？] |
| `AnimatedSprite2D/HurtBox/HurtShape:position` | 受击框位置 | [待细化：各方向是否独立？] |
| `Attacks/AttackN/AttackNShape:position` | 攻击框位置 | 各方向不同 |
| `Attacks/AttackN/AttackNShape:disabled` | 攻击框启用 | 不变（与方向无关） |
| `.:physical_height` | 物理高度 | 不变 |
| `.:attack_heights` | 攻击高度 | 不变 |

### 6.3 SpriteFrames 扩展

当前 SpriteFrames 资源（`spriteframes_*.tres`）包含 18 个动画。8 方向后需要扩展为 18 × 8 = 144 个动画。

[待细化：SpriteFrames 的命名策略 — 是 `idle_right`、`idle_up_right` 等独立动画名，还是其他组织方式？]

### 6.4 镜像生成规则

5 个手绘方向 → 3 个镜像方向：

| 源方向 | 镜像方向 | 镜像操作 |
|--------|---------|---------|
| right | left | `flip_h` 反转、`position.x` 取反、`polygon.x` 取反 |
| up_right | up_left | 同上 |
| down_right | down_left | 同上 |

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
| `_template/__NAME___skin.tscn` | 所有 `blend_position = 1.0` → `Vector2(1, 0)` |
| `_template/resources/animations/animation_tree_root.tres` | 所有 BlendSpace1D → BlendSpace2D（19 个节点） |
| `_template/resources/animations/` | 新增 6 方向文件 × 19 动作 = 114 个 `.tres` |
| `_template/resources/sprites/` | 新增 3 方向精灵目录（up_right, up, down_right 各 N 帧） |
| `_template/resources/spriteframes___NAME__.tres` | 新增 8 方向 SpriteFrames 动画 |
| `_template/resources/anim_library___NAME__.tres` | 注册新动画（152 个条目） |

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
1. `animation_tree_root.tres`：所有 BlendSpace1D → BlendSpace2D
2. `chen_jingchou_skin.tscn`：所有 `blend_position = 1.0` → `Vector2(1, 0)`
3. 新增 6 方向动画文件 × 19 动作 = 114 个 `.tres`
4. 新增精灵资产（5 方向手绘 + 3 方向镜像）
5. 更新 `anim_library_chen_jingchou.tres`：注册新动画
6. 更新 `spriteframes_chen_jingchou.tres`：新增 SpriteFrames 动画

**chenjianchou_new**：同上步骤。

### 9.2 SkinDirection 兼容

代码中使用 `SkinDirection.LEFT` / `SkinDirection.RIGHT` 的地方：
- 改为 `SkinDirection_LEFT` / `SkinDirection_RIGHT` 常量引用
- 或直接改为 `Vector2.LEFT` / `Vector2.RIGHT`

### 9.3 外部引用兼容

任何外部代码设置 `skin_direction = -1` 或 `skin_direction = 1` 的地方，setter 的 int/float 兼容转换会自动处理。无需立即修改所有调用点。

---

## 十、待细化清单

| # | 章节 | 问题 | 优先级 |
|---|------|------|--------|
| 1 | §4.2 | Mid-air 方向是否包含 Y 分量？还是只取水平分量？ | 高 |
| 2 | §5.1 | BlendSpace2D 的 blend mode 选择（Blend/Discrete/Custom） | 高 |
| 3 | §6.2 | 8 方向独立精灵后 `flip_h` 轨迹是否还需要？ | 中 |
| 4 | §6.3 | SpriteFrames 8 方向的命名和组织策略 | 高 |
| 5 | §6.2 | HurtShape 各方向位置是否需要不同？ | 中 |
| 6 | §8.2 | 角色创建工具的具体代码改动 | 中 |
| 7 | §4 | 攻击时方向锁定策略：锁定在攻击开始时，还是可随输入改变？ | 高 |
| 8 | §4 | 受击方向由什么决定？面朝攻击者？面朝被击飞方向？ | 中 |
| 9 | §5.3 | turn 状态是移除还是保留（作为备用或特殊过渡动画）？ | 低 |
| 10 | §8 | 轮廓转换工具是否需要适配 8 方向（collision shape 各方向不同？） | 低 |

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
| `quiver_action_mid_air.gd` | 修改（~5 行） | 空中方向 |
| `quiver_action_follow.gd` | 修改（~5 行） | AI 跟随方向 |
| `quiver_action_idle_ai.gd` | 修改（~3 行） | AI 闲置朝向 |
| `animation_tree_root.tres` | 重写 | 每个角色各一份 |
| `*_skin.tscn` | 修改默认值 | 每个角色各一份 |
| 动画 `.tres` × 152 | 新增/重写 | 每个角色各一套 |
| `spriteframes_*.tres` | 扩展 | 每个角色各一份 |
| `anim_library_*.tres` | 扩展 | 每个角色各一份 |

## 附录 C：当前所有设置 `skin_direction` 的代码位置

| 文件 | 行 | 上下文 | 当前值 | 目标值 |
|------|------|--------|--------|--------|
| `quiver_action_walk.gd` | 97-99 | Walk 朝向 | `sign(dir.x)` → int | `dir.normalized()` → Vector2 |
| `quiver_action_follow.gd` | 141-143 | AI 跟随 | `sign(delta.x)` → int | `direction_to()` → Vector2 |
| `quiver_action_idle_ai.gd` | 47-48 | AI 闲置 | `1 if x>=0 else -1` | `direction_to()` → Vector2 |
| `quiver_action_mid_air.gd` | 130-133 | 空中朝向 | `sign(vel.x)` → int | `vel.normalized()` → Vector2 |
| `quiver_action_grab_idle.gd` | 71 | Grab 释放 | 读取（不设置） | 不变 |
| `enemy_hurt_handler.gd` | 43 | 敌人初始化 | `facing_direction` (int) | setter 兼容转换 |
| `enemy_periodic_attack.gd` | 37 | 敌人攻击 | `facing_direction` (int) | setter 兼容转换 |
| `spell_base.gd` | 61 | 法术施放 | SpellSkin（独立） | 不改 |
