# 多方向动画系统设计

> **版本**: 0.5.1
> **创建日期**: 2026-08-23
> **最后更新**: 2026-08-23
> **状态**: Phase A 代码完成，待验证
> **关联文档**: HEIGHT_LAYER_DESIGN.md, SPELL_SYSTEM_DESIGN.md, PLUGIN_ARCHITECTURE.md
> **变更记录**:
> - v0.1.0 — 初稿（统一 8 方向方案）
> - v0.2.0 — 简化方向分配：idle/walk 8 方向、attack 4 方向、其余保持 2 方向
> - v0.3.0 — 实现级细化：新增 §2.5 外部代码断点修复、§4.1 Walk 完整目标代码、§4.5 Attack 完整 enter() 代码、附录 C 扩展、附录 D 前置验证清单
> - v0.3.1 — §4.5 攻击量化改为水平优先（`>=`），斜角方向量化为左右
> - v0.4.0 — 按"脚本变动"和"动画资源变动"重组文档结构，分为 Part A 和 Part B
> - v0.4.1 — 修复 6 处数据矛盾：动画文件数 96→56、精灵方向 2+2→3+1、新增文件 16→18、library 条目 56→58、改动文件数 6→7、load_steps 补充
> - v0.4.2 — 4 项设计决策确认：删除死代码常量、明确 resource_name/flip_h/SpriteFrames 命名规则
> - v0.4.3 — §8.2 角色创建工具确认无需改动（通用复制器）、§8.3 镜像动画工具确认无需改动（命名逻辑兼容 8 方向）
> - v0.5.0 — 附录 D 验证完成：§3.2 从零改动改为需修改 _update_blend_directions()（BlendSpace1D 运行时不接受 Vector2 赋值，必须分离 1D/2D 路径）；BlendSpace2D .tres 格式确认（name 字段会被写入，triangles/auto_triangles 默认省略）
> - v0.5.1 — §2.5 修正：GDScript 静态类型检查拒绝 int→Vector2 赋值（setter 运行时兼容无效），enemy_hurt_handler.gd 和 enemy_periodic_attack.gd 需在赋值点显式转换；改动文件数 7→10

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
| 动画文件数 | idle/walk ×8 + attack ×4 + 其余 ×2 = 56 个 `.tres`（移除 turn） |
| 方向判定 | idle/walk/attack 用 `direction.normalized()`；其余保持 `sign(direction.x)` |
| 精灵方向 | idle/walk: 5 方向手绘 + 3 方向镜像；attack: 3 方向手绘 + 1 方向镜像 |
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

**敌人代码赋值**（编译时类型检查拒绝，需要显式转换）：

| 文件 | 行 | 当前代码 | 问题 | 修复代码 |
|------|-----|---------|------|---------|
| `enemy_hurt_handler.gd` | 43 | `_skin.skin_direction = facing_direction` | `int` 赋值给 `Vector2` 属性，编译报错 | `_skin.skin_direction = Vector2.RIGHT if facing_direction > 0 else Vector2.LEFT` |
| `enemy_periodic_attack.gd` | 37 | `_skin.skin_direction = facing_direction` | 同上 | `_skin.skin_direction = Vector2.RIGHT if facing_direction > 0 else Vector2.LEFT` |

**原因**：GDScript 静态类型检查器在编译时拒绝 `int → Vector2` 的赋值。setter 的运行时兼容转换（`var raw = value`）永远不会被调用，因为赋值在编译阶段就被拒绝了。

**决策**：敌人的 `facing_direction` 保留 `@export int` 类型（Inspector 中方便设置），在赋值点显式转换为 `Vector2`。

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

**目标代码**（实际实现）：
```gdscript
@export var skin_direction: Vector2 = Vector2.RIGHT:
    set(value):
        var raw = value  # 无类型变量，绕过类型检查
        var converted_value: Vector2
        if typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT:
            converted_value = Vector2.LEFT if raw < 0 else Vector2.RIGHT
        else:
            converted_value = raw
        var has_changed := not converted_value.is_equal_approx(skin_direction)
        skin_direction = converted_value
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

**技术说明：GDScript setter 参数类型推断**

GDScript 的 setter 参数会自动推断为属性声明的类型（这里是 Vector2），直接使用 `value is int` 会触发编译错误："Cannot use 'is' operator on a parameter of type 'Vector2'"。

**解决方案**：使用 `var raw = value` 创建无类型变量，绕过编译时类型检查，在运行时使用 `typeof(raw)` 检测实际类型。这种方式在运行时正确检测传入类型，同时满足编译器的类型检查要求。

**相关提交**：
- `8326c8a` fix: setter使用无类型中间变量绕过GDScript静态类型检查
- `7125764` fix: setter参数声明为Variant解决编译时类型推断问题

### 3.2 `quiver_character_skin_anim_tree.gd` — 需修改 `_update_blend_directions()`

**位置**：`addons/quiver.beat_em_up/characters/quiver_character_skin_anim_tree.gd`

**验证发现**：运行时赋值 Vector2 给 BlendSpace1D 的 `blend_position` 属性，值会变成 Vector2 而非 float，导致 BlendSpace1D 无法正确混合。**必须分离 1D 和 2D 路径**。

**需要改动的部分**：

1. **`_blend_positions`** → 分离为 `_blend_positions_1d` 和 `_blend_positions_2d`：
   ```gdscript
   var _blend_positions_1d := []
   var _blend_positions_2d := []
   ```

2. **`_populate_animation_list()`**：需要区分 BlendSpace 类型：
   ```gdscript
   func _populate_animation_list() -> void:
       _find_all_animation_nodes_from()
       _blend_positions_1d.clear()
       _blend_positions_2d.clear()
       _categorize_blend_positions(_animation_tree.tree_root, "parameters")
   ```

3. **新增 `_categorize_blend_positions()`**：遍历 AnimationNode 树，根据节点类型分类（实际实现）：
   ```gdscript
   func _categorize_blend_positions(node: AnimationNode, path: String) -> void:
       if node == null:
           return
       for prop in node.get_property_list():
           if prop.hint_string == "AnimationNode":
               var child = node.get(prop.name)
               if child == null:
                   continue
               var parameter_name = _get_actual_parameter_name(prop.name)
               var child_path = path.path_join(parameter_name)
               if child is AnimationNodeBlendSpace1D:
                   _blend_positions_1d.append(child_path.path_join("blend_position"))
                   _categorize_blend_positions(child, child_path)
               elif child is AnimationNodeBlendSpace2D:
                   _blend_positions_2d.append(child_path.path_join("blend_position"))
                   _categorize_blend_positions(child, child_path)
               else:
                   _categorize_blend_positions(child, child_path)
   ```

   **技术说明：为什么检查条件是多余的**
   
   实际实现省略了设计中的 `if child_path.ends_with("blend_position")` 检查，原因：
   1. `_categorize_blend_positions()` 只在遇到 BlendSpace 节点时调用
   2. BlendSpace 节点的 path 必然以 "blend_position" 结尾
   3. 检查条件是防御性编程，但不是必需的
   
   **验证步骤**：
   1. 在 Godot 编辑器中打开测试角色
   2. 检查 AnimationTree 的 blend_position 参数
   3. 确认 BlendSpace1D 和 BlendSpace2D 节点都能正确分类
   4. 测试 8 方向移动和 4 方向攻击

4. **`_update_blend_directions()`** — 分离赋值：
   ```gdscript
   func _update_blend_directions() -> void:
       for path in _blend_positions_1d:
           _animation_tree[path] = skin_direction.x
       for path in _blend_positions_2d:
           _animation_tree[path] = skin_direction
   ```

**不需要改动的部分**：

1. **`_get_blend_position_paths_from()`**（第 132-139 行）：
   - BlendSpace2D 的 `blend_position` 属性仍以 `blend_position` 结尾
   - BlendSpace2D 的 `blend_position_x`/`blend_position_y` 子属性以 `_x`/`_y` 结尾，不会被误匹配
   - 但此方法需要区分类型，改为 `_categorize_blend_positions()` 替代

2. **`_handle_animation_node()`**（第 180-182 行）：
   - 已包含 `"AnimationNodeBlendSpace2D"` 匹配，无需添加

### 3.3 插件改动总结

| 文件 | 改动行数 | 复杂度 |
|------|---------|--------|
| `quiver_character_skin.gd` | ~10 行 | 低 |
| `quiver_character_skin_anim_tree.gd` | ~30 行 | 中（分离 1D/2D 路径分类与赋值） |

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
[sub_resource type="AnimationNodeBlendSpace2D" id="AnimationNodeBlendSpace2D_idle"]
blend_point_0/node = SubResource("AnimationNodeAnimation_idle_right")
blend_point_0/pos = Vector2(1, 0)
blend_point_0/name = &"0"
blend_point_1/node = SubResource("AnimationNodeAnimation_idle_up_right")
blend_point_1/pos = Vector2(0.707, -0.707)
blend_point_1/name = &"1"
blend_point_2/node = SubResource("AnimationNodeAnimation_idle_up")
blend_point_2/pos = Vector2(0, -1)
blend_point_2/name = &"2"
blend_point_3/node = SubResource("AnimationNodeAnimation_idle_up_left")
blend_point_3/pos = Vector2(-0.707, -0.707)
blend_point_3/name = &"3"
blend_point_4/node = SubResource("AnimationNodeAnimation_idle_left")
blend_point_4/pos = Vector2(-1, 0)
blend_point_4/name = &"4"
blend_point_5/node = SubResource("AnimationNodeAnimation_idle_down_left")
blend_point_5/pos = Vector2(-0.707, 0.707)
blend_point_5/name = &"5"
blend_point_6/node = SubResource("AnimationNodeAnimation_idle_down")
blend_point_6/pos = Vector2(0, 1)
blend_point_6/name = &"6"
blend_point_7/node = SubResource("AnimationNodeAnimation_idle_down_right")
blend_point_7/pos = Vector2(0.707, 0.707)
blend_point_7/name = &"7"
```

**已验证格式**（附录 D Step 0）：`triangles`、`auto_triangles`、`blend_mode` 均为默认值，不写入 `.tres`。

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
| `AnimatedSprite2D:flip_h` | 水平翻转 | **保留轨迹，值固定为 `false`**。镜像工具生成的文件自动设为 `true` |
| `AnimatedSprite2D/HurtBox/HurtShape:position` | 受击框位置 | 8/4 方向各自独立 |
| `Attacks/AttackN/AttackNShape:position` | 攻击框位置 | 各方向不同 |
| `Attacks/AttackN/AttackNShape:disabled` | 攻击框启用 | 不变（与方向无关） |
| `.:physical_height` | 物理高度 | 不变 |
| `.:attack_heights` | 攻击高度 | 不变 |

**设计决策**：`flip_h` 轨迹保留而非移除，确保所有动画文件结构一致。手绘方向设为 `false`，镜像工具自动将镜像方向设为 `true`。

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

**设计决策：两套命名约定共存**
- 2 方向保持现有命名（如 `&"idle"` 共用、`&"jump"` / `&"jump_left"` 不对称），减少改动量
- 8/4 方向使用统一的方向后缀命名（如 `&"idle_right"`, `&"idle_up_right"`）
- 这是有意的权衡：虽然 2 方向命名不一致，但修改它们需要改动大量现有文件，收益不大

**Animation .tres 文件的 `resource_name` 规则**：
- 现有 `_right` 文件：保持无后缀（如 `resource_name = "idle"`），不修改
- 新增 8/4 方向文件：带完整方向后缀（如 `resource_name = "idle_up"`, `resource_name = "idle_up_right"`）
- `resource_name` 仅影响编辑器显示和日志，不影响功能（AnimationTree 通过 AnimationLibrary key 引用）

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
| `_template/resources/animations/` | 新增 18 个方向文件（idle/walk 各 +6，attack1/2/3 各 +2） |
| `_template/resources/sprites/` | 新增精灵目录（idle/walk: up_right, up, down_right；attack: up, down） |
| `_template/resources/spriteframes___NAME__.tres` | 新增 23 个 SpriteFrames 动画 |
| `_template/resources/anim_library___NAME__.tres` | 注册新动画（从 40 条目扩展到 58 条目，load_steps 从 41 改为 59） |

### 8.2 角色创建工具 `character_creator.gd` — 无需改动

**确认状态**：✅ 无需改动

角色创建器（Inspector 工具）是通用的文件复制器，复制 `_template/` 目录并替换占位符（`__NAME__` → 角色名）。多方向后：

- ✅ 动画文件复制：工具递归复制整个 `resources/animations/` 目录，自动包含新增的 18 个方向文件
- ✅ 占位符替换：`__CLASS__` 替换在 `.tres` 文件内通用，不限于方向数
- ✅ `anim_library_*.tres`：模板中已包含 58 个条目，复制后自动替换占位符

**注意**：模板中的 `anim_library___NAME__.tres` 需要预先包含所有 58 个动画条目（包括新增的 18 个方向动画），创建工具会原样复制并替换占位符。

### 8.3 镜像动画工具 `create_mirrored_animation_button.gd` — 无需改动

**确认状态**：✅ 无需改动

工具的命名逻辑（`_get_mirrored_name` 函数，第 147-154 行）：

```gdscript
if anim_name.ends_with("left"):
    new_name = anim_name.replace("left", "right")
elif anim_name.ends_with("right"):
    new_name = anim_name.replace("right", "left")
```

**8 方向的兼容性**：
- ✅ `idle_up_right` 以 "right" 结尾 → `idle_up_left`
- ✅ `idle_down_right` 以 "right" 结尾 → `idle_down_left`
- ✅ `walk_up_right` 以 "right" 结尾 → `walk_up_left`

**镜像内容**（无需改动）：
- ✅ `flip_h` 轨迹：`false` → `true`
- ✅ `position.x`：取反
- ✅ `polygon.x`：取反

**使用方式**：美术完成手绘方向后，在 Inspector 中选择动画，点击"生成镜像动画"按钮，工具自动生成镜像文件。

---

## 九、向后兼容与迁移

### 9.1 已有角色迁移步骤

**chen_jingchou**：
1. `animation_tree_root.tres`：5 个 BlendSpace1D → BlendSpace2D（idle, walk, attack1, attack2, attack3）
2. `chen_jingchou_skin.tscn`：5 个 `blend_position = 1.0` → `Vector2(1, 0)`
3. 新增 18 个方向动画文件（idle/walk 各 +6，attack1/2/3 各 +2）
4. 新增精灵资产（idle/walk: 3 方向手绘 + 3 方向镜像；attack: 3 方向手绘 + 1 方向镜像）
5. 更新 `anim_library_chen_jingchou.tres`：注册新动画（40 → 58 条目，load_steps 从 41 改为 59）
6. 更新 `spriteframes_chen_jingchou.tres`：新增 SpriteFrames 动画（18 → 41）

**chenjianchou_new**：同上步骤。

### 9.2 SkinDirection 兼容

代码中使用 `SkinDirection.LEFT` / `SkinDirection.RIGHT` 的地方：
- 直接改为 `Vector2.LEFT` / `Vector2.RIGHT`
- `SkinDirection` 枚举已删除（§3.1），无兼容常量

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
| `quiver_character_skin_anim_tree.gd` | 修改（~30 行） | 分离 1D/2D blend_position 路径分类与赋值 |
| `quiver_action_walk.gd` | 重写（~100 行） | Walk 状态行为，移除 turn 动画 |
| `quiver_action_attack.gd` | 修改（~5 行） | 攻击方向量化锁定 |
| `quiver_action_mid_air.gd` | 修改（~3 行） | 空中朝向比较修复 |
| `quiver_action_follow.gd` | 重写（~50 行） | AI 跟随方向，移除 turn 动画 |
| `quiver_action_idle_ai.gd` | 修改（~3 行） | AI 闲置朝向 |
| `quiver_action_grab_idle.gd` | 修改（~1 行） | Grab 释放方向比较修复 |
| `spell_manager.gd` | 修改（~1 行） | 法术方向比较修复 |
| `enemy_hurt_handler.gd` | 修改（~1 行） | 敌人朝向显式转换 |
| `enemy_periodic_attack.gd` | 修改（~1 行） | 敌人朝向显式转换 |
| `animation_tree_root.tres` | 修改 5 个节点 | 每个角色各一份 |
| `*_skin.tscn` | 修改 5 个默认值 | 每个角色各一份 |
| 动画 `.tres` × 18 新增 | 新增 | 每个角色各一套 |
| `spriteframes_*.tres` | 扩展（+23 动画） | 每个角色各一份 |
| `anim_library_*.tres` | 扩展（+18 条目） | 每个角色各一份 |

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
| `enemy_hurt_handler.gd` | 11, 43 | 敌人 facing | `@export int` → 赋值 | 显式转换为 Vector2 | **是**（赋值修复） |
| `enemy_periodic_attack.gd` | 14, 37 | 敌人 facing | `@export int` → 赋值 | 显式转换为 Vector2 | **是**（赋值修复） |
| `spell_base.gd` | 61 | 法术施放 | SpellSkin（独立） | 不改 | **否** |
| `spell_manager.gd` | 59 | 法术方向比较 | `skin_direction == -1` | `skin_direction.x < 0` | **是**（比较修复） |

**需要改动的文件总计**：10 个
- `quiver_character_skin.gd`
- `quiver_character_skin_anim_tree.gd`
- `quiver_action_walk.gd`
- `quiver_action_follow.gd`
- `quiver_action_idle_ai.gd`
- `quiver_action_grab_idle.gd`
- `quiver_action_attack.gd`
- `quiver_action_mid_air.gd`
- `spell_manager.gd`
- `enemy_hurt_handler.gd`
- `enemy_periodic_attack.gd`

---

## 附录 D：实现前置验证结果（已完成）

### Step 0：BlendSpace2D `.tres` 格式验证 ✅

**验证方式**：在 Godot 编辑器中创建 BlendSpace2D 节点并保存，读取生成的 `.tres` 文件。

**验证结果**：

| 项目 | 结论 |
|------|------|
| `triangles` 属性 | **不写入**（`auto_triangles=true` 默认时，引擎源码 `PROPERTY_USAGE_NONE` 跳过序列化） |
| `pos` 精度 | `Vector2(x, y)` 格式，使用引擎默认浮点精度 |
| `blend_point_<N>/name` | **会写入**，格式为 `&"名称"`（如 `&"BlendSpace2D"`） |
| `auto_triangles` | **不写入**（默认 `true` 省略） |
| `blend_mode` | **不写入**（默认 0 = Interpolated 省略） |
| `min_space` / `max_space` / `snap` | **不写入**（默认值省略） |

**BlendSpace2D `.tres` 精确格式**：
```
[sub_resource type="AnimationNodeBlendSpace2D" id="AnimationNodeBlendSpace2D_xxxxx"]
blend_point_0/node = SubResource("AnimationNodeAnimation_xxxxx")
blend_point_0/pos = Vector2(1, 0)
blend_point_0/name = &"0"
blend_point_1/node = SubResource("AnimationNodeAnimation_yyyyy")
blend_point_1/pos = Vector2(0.707, -0.707)
blend_point_1/name = &"1"
...
```

### Step 0b：BlendSpace1D 赋值 Vector2 验证 ✅

**验证方式**：在 chen_jingchou 场景运行时，通过代码赋值 Vector2 给 BlendSpace1D 的 `blend_position`。

**验证结果**：

| 赋值方式 | 结果 |
|---------|------|
| `.tscn` 文件中写 `Vector2(1, 0)` | ✅ Godot 接受，无报错 |
| 运行时 `_animation_tree[path] = Vector2(1, 0)` | ❌ 值变成 Vector2 而非 float，BlendSpace1D 无法正确混合 |

**结论**：必须在 `_update_blend_directions()` 中分离 1D 和 2D 路径（见 §3.2）。

### Step 0c：.tscn 中 Vector2 值格式验证 ✅

**验证方式**：修改 `_template/__NAME___skin.tscn` 的 `blend_position` 为 `Vector2(1, 0)`，在 Godot 编辑器中加载。

**验证结果**：格式 `parameters/state_machine/idle/blend_position = Vector2(1, 0)` 正确，Godot 无报错。

### 已更新的章节

- §3.2：从"零改动"改为"需修改 `_update_blend_directions()`"
- §5.1：BlendSpace2D 精确 `.tres` 格式已确认
- §5.4：`.tscn` 中 Vector2 格式已确认
- 附录 B：`quiver_character_skin_anim_tree.gd` 从"无改动"改为"修改 ~30 行"

---

## 附录 E：PNG 资源清单

### 目录结构

所有 PNG 文件放在 `characters/playable/{角色名}/resources/sprites/` 下，按动画类型分子目录：

```
sprites/
├── idle/          ← idle 动画
├── walk/          ← walk 动画
├── punches/       ← attack1/2/3 动画
├── air_attack/    ← 空中攻击
├── jump/          ← 跳跃相关（rising, falling, landing）
├── hurt/          ← 受击
├── knock_out/     ← 击飞/倒地
└── turn_around/   ← 转身（已移除，保留备用）
```

### 图例

| 标记 | 含义 |
|------|------|
| ✅ 已有 | PNG 文件已存在 |
| 🔄 镜像 | 由镜像工具自动生成，无需手绘 |
| ⚠️ 需制作 | 需要手绘新的 PNG |

### 8 方向动画

#### 1. IDLE — 8 方向 × 4 帧（BlendSpace2D）

**目录**: `sprites/idle/`  
**SpriteFrames 动画名**: `idle`, `idle_up`, `idle_up_right`, `idle_up_left`, `idle_down`, `idle_down_right`, `idle_down_left`  
**Loop**: 是 | **FPS**: 8

| 方向 | 帧0 | 帧1 | 帧2 | 帧3 | 状态 |
|------|-----|-----|-----|-----|------|
| **right** | `idle_00.png` | `idle_01.png` | `idle_02.png` | `idle_03.png` | ✅ 已有 |
| **left** | 镜像 right | 镜像 right | 镜像 right | 镜像 right | 🔄 镜像 |
| **up** | `idle_up_00.png` | `idle_up_01.png` | `idle_up_02.png` | `idle_up_03.png` | ⚠️ 需制作 |
| **up_right** | `idle_up_right_00.png` | `idle_up_right_01.png` | `idle_up_right_02.png` | `idle_up_right_03.png` | ⚠️ 需制作 |
| **up_left** | 镜像 up_right | 镜像 up_right | 镜像 up_right | 镜像 up_right | 🔄 镜像 |
| **down** | `idle_down_00.png` | `idle_down_01.png` | `idle_down_02.png` | `idle_down_03.png` | ⚠️ 需制作 |
| **down_right** | `idle_down_right_00.png` | `idle_down_right_01.png` | `idle_down_right_02.png` | `idle_down_right_03.png` | ⚠️ 需制作 |
| **down_left** | 镜像 down_right | 镜像 down_right | 镜像 down_right | 镜像 down_right | 🔄 镜像 |

**需制作**: 16 张 PNG | **镜像生成**: 12 张

#### 2. WALK — 8 方向 × 30 帧（BlendSpace2D）

**目录**: `sprites/walk/`  
**SpriteFrames 动画名**: `walk`, `walk_up`, `walk_up_right`, `walk_up_left`, `walk_down`, `walk_down_right`, `walk_down_left`  
**Loop**: 是 | **FPS**: 24

| 方向 | 基础帧（12张） | 动画帧数 | 状态 |
|------|---------------|---------|------|
| **right** | `walk_00.png` ~ `walk_11.png` | 30帧（重复使用12张） | ✅ 已有 |
| **left** | 镜像 right | 30帧 | 🔄 镜像 |
| **up** | `walk_up_00.png` ~ `walk_up_11.png` | 30帧（需12张基础帧） | ⚠️ 需制作 |
| **up_right** | `walk_up_right_00.png` ~ `walk_up_right_11.png` | 30帧（需12张基础帧） | ⚠️ 需制作 |
| **up_left** | 镜像 up_right | 30帧 | 🔄 镜像 |
| **down** | `walk_down_00.png` ~ `walk_down_11.png` | 30帧（需12张基础帧） | ⚠️ 需制作 |
| **down_right** | `walk_down_right_00.png` ~ `walk_down_right_11.png` | 30帧（需12张基础帧） | ⚠️ 需制作 |
| **down_left** | 镜像 down_right | 30帧 | 🔄 镜像 |

**需制作**: 48 张 PNG（4方向 × 12基础帧）| **镜像生成**: 36 张

#### 3. ATTACK1 — 4 方向 × 6 帧（BlendSpace2D）

**目录**: `sprites/punches/`  
**SpriteFrames 动画名**: `attack_1`, `attack_1_up`, `attack_1_down`  
**Loop**: 否 | **FPS**: 24

| 方向 | 帧0~3 | 帧4~5 | 状态 |
|------|-------|-------|------|
| **right** | `punch1_00.png` (×4) | `punch1_01.png` (×2) | ✅ 已有 |
| **left** | 镜像 right | 镜像 right | 🔄 镜像 |
| **up** | `punch1_up_00.png` (×4) | `punch1_up_01.png` (×2) | ⚠️ 需制作 |
| **down** | `punch1_down_00.png` (×4) | `punch1_down_01.png` (×2) | ⚠️ 需制作 |

**需制作**: 4 张 PNG | **镜像生成**: 2 张

#### 4. ATTACK2 — 4 方向 × 11 帧（BlendSpace2D）

**目录**: `sprites/punches/`  
**SpriteFrames 动画名**: `attack_2`, `attack_2_up`, `attack_2_down`  
**Loop**: 是 | **FPS**: 24

| 方向 | 帧0~2 | 帧3~7 | 帧8~10 | 状态 |
|------|-------|-------|--------|------|
| **right** | `punch2_00.png` (×3) | `punch2_01.png` (×5) | `punch1_01.png` (×3) | ✅ 已有 |
| **left** | 镜像 right | 镜像 right | 镜像 right | 🔄 镜像 |
| **up** | `punch2_up_00.png` (×3) | `punch2_up_01.png` (×5) | `punch1_up_01.png` (×3) | ⚠️ 需制作 |
| **down** | `punch2_down_00.png` (×3) | `punch2_down_01.png` (×5) | `punch1_down_01.png` (×3) | ⚠️ 需制作 |

**需制作**: 4 张 PNG | **镜像生成**: 2 张

#### 5. ATTACK3 — 4 方向 × 17 帧（BlendSpace2D）

**目录**: `sprites/punches/`  
**SpriteFrames 动画名**: `attack_3`, `attack_3_up`, `attack_3_down`  
**Loop**: 是 | **FPS**: 24

| 方向 | 帧0~4 | 帧5~7 | 帧8~9 | 帧10~13 | 帧14~16 | 状态 |
|------|-------|-------|-------|---------|---------|------|
| **right** | `punch3_00.png` (×5) | `punch3_01.png` (×3) | `punch3_02.png` (×2) | `punch3_04.png` (×4) | `punch1_01.png` (×3) | ✅ 已有 |
| **left** | 镜像 right | 镜像 right | 镜像 right | 镜像 right | 镜像 right | 🔄 镜像 |
| **up** | `punch3_up_00.png` (×5) | `punch3_up_01.png` (×3) | `punch3_up_02.png` (×2) | `punch3_up_04.png` (×4) | `punch1_up_01.png` (×3) | ⚠️ 需制作 |
| **down** | `punch3_down_00.png` (×5) | `punch3_down_01.png` (×3) | `punch3_down_02.png` (×2) | `punch3_down_04.png` (×4) | `punch1_down_01.png` (×3) | ⚠️ 需制作 |

**需制作**: 8 张 PNG | **镜像生成**: 4 张

### 2 方向动画（无需新 PNG）

#### 6. AIR_ATTACK — 2 方向 × 4 帧

**目录**: `sprites/air_attack/`  
**Loop**: 否 | **FPS**: 24

| 方向 | 帧0~2 | 帧3 | 状态 |
|------|-------|-----|------|
| **right** | `air_attack_00.png` (×3) | `air_attack_01.png` | ✅ 已有 |
| **left** | 镜像 right | 镜像 right | 🔄 镜像 |

#### 7. JUMP — 2 方向 × 7 帧

**目录**: `sprites/jump/`  
**Loop**: 否 | **FPS**: 24

| 方向 | 帧0~1 | 帧2~6 | 状态 |
|------|-------|-------|------|
| **right** | `jump_01.png` (×2) | `jump_02.png` (×5) | ✅ 已有 |
| **left** | 镜像 right | 镜像 right | 🔄 镜像 |

#### 8. RISING — 2 方向 × 1 帧

**目录**: `sprites/jump/`

| 方向 | PNG | 状态 |
|------|-----|------|
| **right** | `jump_03.png` | ✅ 已有 |
| **left** | 镜像 | 🔄 镜像 |

#### 9. FALLING — 2 方向 × 1 帧

**目录**: `sprites/jump/`

| 方向 | PNG | 状态 |
|------|-----|------|
| **right** | `jump_04.png` | ✅ 已有 |
| **left** | 镜像 | 🔄 镜像 |

#### 10. LANDING — 2 方向 × 5 帧

**目录**: `sprites/jump/`  
**Loop**: 是 | **FPS**: 24

| 方向 | 帧0~2 | 帧3~4 | 状态 |
|------|-------|-------|------|
| **right** | `jump_02.png` (×3) | `jump_01.png` (×2) | ✅ 已有 |
| **left** | 镜像 right | 镜像 right | 🔄 镜像 |

#### 11. HURT_HIGH — 2 方向 × 1 帧

**目录**: `sprites/hurt/`

| 方向 | PNG | 状态 |
|------|-----|------|
| **right** | `hurt_high.png` | ✅ 已有 |
| **left** | 镜像 | 🔄 镜像 |

#### 12. HURT_MID — 2 方向 × 1 帧

**目录**: `sprites/hurt/`

| 方向 | PNG | 状态 |
|------|-----|------|
| **right** | `hurt_mid.png` | ✅ 已有 |
| **left** | 镜像 | 🔄 镜像 |

#### 13. KNOCKOUT_LAUNCH — 2 方向 × 1 帧

**目录**: `sprites/knock_out/`

| 方向 | PNG | 状态 |
|------|-----|------|
| **right** | `knockout_00.png` | ✅ 已有 |
| **left** | 镜像 | 🔄 镜像 |

#### 14. KNOCKOUT_RISING — 2 方向 × 1 帧

**目录**: `sprites/knock_out/`

| 方向 | PNG | 状态 |
|------|-----|------|
| **right** | `knockout_01.png` | ✅ 已有 |
| **left** | 镜像 | 🔄 镜像 |

#### 15. KNOCKOUT_FALLING — 2 方向 × 1 帧

**目录**: `sprites/knock_out/`

| 方向 | PNG | 状态 |
|------|-----|------|
| **right** | `knockout_02.png` | ✅ 已有 |
| **left** | 镜像 | 🔄 镜像 |

#### 16. KNOCKOUT_BOUNCE — 2 方向 × 2 帧

**目录**: `sprites/knock_out/`

| 方向 | 帧0 | 帧1 | 状态 |
|------|-----|-----|------|
| **right** | `knockout_03.png` | `knockout_04.png` | ✅ 已有 |
| **left** | 镜像 | 镜像 | 🔄 镜像 |

#### 17. KNOCKOUT_LANDED — 2 方向 × 1 帧

**目录**: `sprites/knock_out/`

| 方向 | PNG | 状态 |
|------|-----|------|
| **right** | `knockout_05.png` | ✅ 已有 |
| **left** | 镜像 | 🔄 镜像 |

### 统计数据

#### 需制作 PNG 汇总

| 动画 | 需手绘的方向 | 基础帧数/方向 | 需制作 PNG 数 |
|------|-------------|-------------|--------------|
| idle | up, up_right, down, down_right | 4 | **16 张** |
| walk | up, up_right, down, down_right | 12 | **48 张** |
| attack1 | up, down | 2 | **4 张** |
| attack2 | up, down | 2 | **4 张** |
| attack3 | up, down | 4 | **8 张** |
| **合计** | | | **80 张** |

#### 镜像生成汇总

| 来源方向 | 生成方向 | 数量 |
|---------|---------|------|
| right → left | idle, walk, attack1, attack2, attack3, 及所有 2 方向动画 | 每个动画 1 个 |
| up_right → up_left | idle, walk | 2 个 |
| down_right → down_left | idle, walk | 2 个 |

#### 已有 PNG（无需变动）

| 目录 | 文件数 | 文件列表 |
|------|--------|---------|
| `sprites/idle/` | 4 | `idle_00.png` ~ `idle_03.png` |
| `sprites/walk/` | 12 | `walk_00.png` ~ `walk_11.png` |
| `sprites/punches/` | 8 | `punch1_00~01`, `punch2_00~01`, `punch3_00~02,04` |
| `sprites/air_attack/` | 2 | `air_attack_00~01.png` |
| `sprites/jump/` | 4 | `jump_01~04.png` |
| `sprites/hurt/` | 2 | `hurt_high.png`, `hurt_mid.png` |
| `sprites/knock_out/` | 6 | `knockout_00~05.png` |
| `sprites/turn_around/` | 3 | `turnaround_00~02.png`（已移除，保留备用） |
| **合计** | **41 张** | |

### 工作优先级

| 优先级 | 内容 | PNG 数 | 说明 |
|--------|------|--------|------|
| 🔴 P0 | idle 4 方向 | 16 张 | 最基础，角色站立必须 |
| 🟡 P1 | walk 4 方向 | 48 张 | 移动必须 |
| 🟢 P2 | attack1/2/3 上下方向 | 16 张 | 4 方向攻击 |
