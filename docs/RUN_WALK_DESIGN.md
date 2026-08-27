# Run/Walk 地面位移系统设计文档

> **创建日期**: 2026-08-27
> **最后更新**: 2026-08-27
> **状态**: 已实现并验证通过

---

## 1. 设计目标

- 默认移动 = **Run**（快速，`move_speed = 600 px/s`）
- 按住 Shift = **Walk**（慢速，`walk_speed = 300 px/s`）
- 两种速度独立配置，每个角色可在 Inspector 或角色创建器中单独设置
- 所有状态过渡无闪烁（xfade_time = 0）
- Run/Walk 状态下攻击、跳跃、抓取全部允许

---

## 2. 核心架构：单类 + 实例配置

### 2.1 设计决策

Walk 和 Run 的本质是同一概念——**地面位移（ground locomotion）**。它们共享：
- 读输入方向
- 设置 skin_direction（BlendSpace2D blend_position）
- 调用 `_move_state.physics_process()` 应用速度
- 无输入时返回 Idle
- 连接 grab_requested 信号

唯一的区别是：**速度值**和**动画名**。

**最终方案**：使用 `QuiverActionLocomotion` 单类，Walk 和 Run 是两个配置不同的实例。

**否决的方案**：
- ~~三文件继承（RunBase → Walk / Run）~~：代码重复，enter/exit 的 modifier 设置需要绕过 super() 调用
- ~~在 Walk 内部检测 shift 切换速度~~：职责不清，Walk 脚本变重
- ~~用 Thread 异步创建角色~~：角色创建 1-2 秒，不需要多线程

### 2.2 状态机结构

```
StateMachine (initial_state = "Ground/Move/Idle")
└── Ground (QuiverActionGround)
    └── Move (QuiverActionGroundMove)
        ├── Idle  (QuiverActionMoveIdle)
        ├── Walk  (QuiverActionLocomotion, _is_walk_mode=true,  _move_skin_state=&"walk")
        └── Run   (QuiverActionLocomotion, _is_walk_mode=false, _move_skin_state=&"run")
```

### 2.3 实例配置对比

| Inspector 属性 | Walk 实例 | Run 实例 |
|---|---|---|
| `_move_skin_state` | `&"walk"` | `&"run"` |
| `_is_walk_mode` | `true` | `false` |
| `_path_idle_state` | `"Ground/Move/Idle"` | `"Ground/Move/Idle"` |
| `_path_other_state` | `"Ground/Move/Run"` | `"Ground/Move/Walk"` |
| `_path_grabbing_state` | `"Ground/Grab/Grabbing"` | `"Ground/Grab/Grabbing"` |

---

## 3. 速度系统

### 3.1 Modifier 机制

Walk 和 Run 共享 `_move_state.physics_process(delta)`，速度差异通过 `QuiverAttributes.add_modifier()` 控制：

```gdscript
# Walk.enter()
if _is_walk_mode and _attributes.move_speed > 0:
    var multiplier: float = float(_attributes.walk_speed) / float(_attributes.move_speed)
    # multiplier = 300/600 = 0.5
    _attributes.add_modifier(&"locomotion_speed", &"move_speed", "multiply", multiplier)

# Walk.exit()
if _is_walk_mode:
    _attributes.remove_modifier(&"locomotion_speed")
```

**速度切换流程**：

```
Walk → Run:
  Walk.exit()  → remove modifier → move_speed 恢复 600
  Run.enter()  → 不设 modifier → move_speed = 600 ✓

Run → Walk:
  Run.exit()   → 无 modifier 需清理
  Walk.enter() → add modifier → move_speed = 600 × 0.5 = 300 ✓
```

### 3.2 首帧速度修正

`Move.enter()` 内部会设置 `_character.velocity = _attributes.move_speed * _direction`，此时 modifier 尚未生效。因此 `Locomotion.enter()` 在 `_move_state.enter(msg)` 之后、`_skin.transition_to()` 之前，再次覆盖速度：

```gdscript
func enter(msg: = {}) -> void:
    ...
    _move_state.enter(msg)         # Move 设置 velocity = move_speed * dir（未修改的值）
    if _is_walk_mode ...:
        add_modifier(...)          # modifier 生效，move_speed 变为 walk_speed
    _character.velocity = _attributes.move_speed * _move_state._direction  # 覆盖，用修改后的值
    _skin.transition_to(...)
```

---

## 4. 状态转换矩阵

| 当前 → 目标 | 触发条件 |
|---|---|
| Idle → Walk | 方向输入 + walk 按下 |
| Idle → Run | 方向输入 + 无 walk |
| Walk → Idle | 方向归零 |
| Walk → Run | walk 松开 |
| Run → Idle | 方向归零 |
| Run → Walk | walk 按下 |
| Landing → Idle | 动画结束 + 无输入 |
| Landing → Walk | 动画结束 + 有输入 + walk |
| Landing → Run | 动画结束 + 有输入 + 无 walk |
| Attack/Hurt/Recovery → Idle | 动画结束（不变） |

### 4.1 统一切换条件

Locomotion.physics_process() 中的核心条件：

```gdscript
if _path_other_state != "" and Input.is_action_pressed("walk") != _is_walk_mode:
    _state_machine.transition_to(_path_other_state)
```

| 当前状态 | walk 按下 | `is_pressed != _is_walk_mode` | 结果 |
|---|---|---|---|
| Walk (true) | 是 | true != true = false | 继续 Walk |
| Walk (true) | 否 | false != true = true | → Run |
| Run (false) | 否 | false != false = false | 继续 Run |
| Run (false) | 是 | true != false = true | → Walk |

---

## 5. 动画系统

### 5.1 占位符动画

Run 状态使用 8 个占位符动画（`run_right.tres` 等），内部引用 walk 的 SpriteFrames 动画：

```
run_right.tres → tracks/2/values = [&"walk_right"]   # 使用 walk 的帧动画作为占位
run_left.tres  → tracks/2/values = [&"walk_left"]
run_up.tres    → tracks/2/values = [&"walk_up"]
...
```

有实际 run 动画后，只需修改 `tracks/2/values` 指向新的 SpriteFrames 动画名。

### 5.2 xfade_time 问题（关键教训）

**问题**：当两个 BlendSpace2D 状态的过渡设置了非零 `xfade_time` 时，Godot 在交叉淡入期间同时求值两个动画。`AnimatedSprite2D:animation` 是 StringName 类型，Godot 尝试对其线性插值 → 产生无效内存地址 → 调试器显示乱码动画名 + 视觉闪烁。

**解决**：所有动画状态过渡的 `xfade_time` 设为 `0`（瞬间切换）。

**受影响的过渡**：
- idle ↔ walk（原 0.15s → 改为 0）
- idle ↔ run（原 0.12s → 改为 0）
- walk ↔ run（原 0.25s → 改为 0）

**不受影响**：BlendSpace2D **内部**的方向混合（如 walk_right 和 walk_up 之间的 blend）不会触发此问题，因为 BlendSpace2D 只选择一个最接近的 blend point 动画，不会同时播放多个。

### 5.3 AnimationNodeStateMachineTransition 共享 bug

**问题**：`animation_tree_root.tres` 中 `AnimationNodeStateMachineTransition_b5vsc` 被两个不相关的过渡共享（`knockout_ground → idle` 和 `walk → attack1`）。一个 SubResource 同时服务两个过渡可能导致 crossfade 参数污染。

**解决**：新增 `AnimationNodeStateMachineTransition_walk_atk1` 作为 `walk → attack1` 的独立过渡资源。

---

## 6. 现有角色兼容性

### 6.1 旧角色行为不变

旧角色（chenjianchou_new、test_8_direction、enemy）的 Walk 节点 `_path_other_state = ""`（空字符串）。空字符串时 Locomotion 的切换检查被跳过：

```gdscript
if _path_other_state != "" and ...:   # 空字符串 → 跳过
    _state_machine.transition_to(_path_other_state)
```

Idle 和 Landing 通过 `has_node("Ground/Move/Run")` 检查 Run 节点是否存在，不存在则回退到 Walk。

### 6.2 需要更新的 .tscn

删除 `quiver_action_walk.gd` 后，所有引用它的 .tscn 需将 ext_resource 路径改为 `quiver_action_locomotion.gd`，并添加新属性：

```
[node name="Walk" type="Node" parent="StateMachine/Ground/Move" index="0"]
script = ExtResource("locomotion_script")
_move_skin_state = &"walk"
_is_walk_mode = true
_path_idle_state = "Ground/Move/Idle"
_path_other_state = ""
_path_grabbing_state = "Ground/Grab/Grabbing"
```

### 6.3 默认动画名修正

所有角色的 `_skin.tscn` 中 `AnimatedSprite2D` 的 `animation` 属性从 `&"idle"` 改为 `&"idle_right"`，匹配独立命名方案后的 SpriteFrames 动画名。

---

## 7. 输入配置

`project.godot` 的 `[input]` 部分新增：

```
walk={
"deadzone": 0.5,
"events": [Object(InputEventKey,...,"physical_keycode":4194325,...)]
}
```

physical_keycode 4194325 = Left Shift。

---

## 8. 角色创建器集成

### 8.1 character_creator.gd

新增 `TOKEN_WALK_SPEED = "__WALK_SPEED__"`，在 4 个方法签名中添加 `walk_speed` 参数：
- `create_character()`
- `_replace_placeholders_recursive()`（含递归调用）
- `_replace_placeholders_in_file()`

### 8.2 create_new_character_widget.gd

新增"步行速度"SpinBox（范围 0-2000，步长 10，默认 300），放在"移动速度"下方。

---

## 9. 实施记录

| 步骤 | Commit | 说明 |
|---|---|---|
| Step 1: 基础设施 | `f91165f` | walk 输入 + walk_speed 属性 + locomotion.gd |
| Step 2: 状态切换 | `baa319d` | 删除 walk.gd + 修改 idle/landing + 更新现有 .tscn |
| Step 3: 模板 Run 节点 | `1db3e7b` | __NAME__.tscn + __NAME___attributes.tres |
| Step 4: 动画资源 | `ec349da` | 8 个 run 占位符 + anim_library + animation_tree + skin.tscn |
| Step 5: 角色创建器 | `0c3c79a` | character_creator.gd + widget |
| Fix: 重复过渡 | `acf12de` | 删除重复 attack1→attack2 + idle 默认动画名修正 |
| Fix: run 占位符动画 | `e27aa4f` | run_*.tres 引用 walk_* 动画 |
| Fix: run 过渡 xfade | `c628aab` | 移除 run 过渡 xfade_time + 拆分共享 SubResource |
| Fix: 全部 xfade 移除 | `3f83500` | 移除所有过渡 xfade_time + walk_right resource_name 统一 |

### 9.1 遇到的关键问题

| 问题 | 根因 | 解决 |
|---|---|---|
| Syncthing 不同步 | Godot 编辑器锁定 .gd/.tscn 文件 | 关闭 Godot 后 Syncthing 自动同步 |
| `__WALK_SPEED__` 未替换 | 角色创建器 .gd 未同步到 Maxhub | 重启系统解决锁定 |
| Animation 'idle' doesn't exist | _skin.tscn 引用旧动画名 | 改为 `&"idle_right"` |
| transitions 重复 | attack1→attack2 出现两次 | 删除重复条目 |
| Run 状态无动画 | run_*.tres 引用不存在的 run_* SpriteFrames 动画 | 改为引用 walk_* |
| idle↔run 闪烁 | xfade_time 非零导致 StringName 线性插值 | xfade_time 改为 0 |
| Walk 也闪烁 | idle↔walk 的 xfade_time 未移除 | 全部过渡 xfade_time 改为 0 |
| 乱码动画名 | StringName 线性插值产生无效指针 | xfade_time = 0 后消失 |

---

## 10. 文件清单

### 新建文件
- `addons/.../quiver_action_locomotion.gd` — Walk/Run 通用移动状态
- `characters/playable/_template/resources/animations/run_*.tres` × 8 — Run 动画占位符

### 修改文件
- `addons/.../quiver_attributes.gd` — +`walk_speed` 属性
- `addons/.../quiver_action_idle.gd` — +`_path_run_state`，physics_process 加 Run 分支
- `addons/.../quiver_action_landing.gd` — +`_path_run`，三选一逻辑
- `characters/playable/_template/__NAME__.tscn` — +Run 节点
- `characters/playable/_template/__NAME___attributes.tres` — +`walk_speed` token
- `characters/playable/_template/__NAME___skin.tscn` — +run blend_position + idle→idle_right
- `characters/playable/_template/resources/anim_library___NAME__.tres` — +8 run 动画注册
- `characters/playable/_template/resources/animations/animation_tree_root.tres` — +run 状态 + 过渡 + xfade 修正
- `addons/.../character_creator.gd` — +walk_speed 参数链
- `addons/.../create_new_character_widget.gd` — +walk_speed UI
- `project.godot` — +walk 输入动作

### 删除文件
- `addons/.../quiver_action_walk.gd` — 被 locomotion.gd 替代
