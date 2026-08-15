# 角色 Group 配置参考

> **创建日期**: 2026-08-15  
> **最后更新**: 2026-08-15  
> **用途**: 记录所有与 group 相关的配置项和功能

---

## 一、阵营 Group（`area2d:` 前缀）

### 原理

通过 `"area2d:"` 前缀的 Godot group 标记阵营，代码层面阻止同阵营伤害。

### 配置方式

在 `.tscn` 中为角色的所有战斗 Area2D（HitBox、HurtBox、GrabBox）添加相同的 `area2d:` group：

```
玩家 HitBox:  groups=["area2d:chen_jingchou"]
玩家 HurtBox: groups=["area2d:chen_jingchou"]
敌人 HitBox:  groups=["area2d:enemy"]
敌人 HurtBox: groups=["area2d:enemy"]
```

### 实现代码

**常量定义**：`quiver_hurt_box.gd:15`
```gdscript
const FACTION_PREFIX = "area2d:"
```

**阵营检查**：`quiver_hurt_box.gd:74-93`
```gdscript
static func are_factions_equal(hit_box: Area2D, hurt_box: Area2D) -> bool:
    var hit_dict := _get_faction_dict(hit_box)
    var hurt_dict := _get_faction_dict(hurt_box)
    
    if hit_dict.is_empty() or hurt_dict.is_empty():
        return false
    
    # 遍历小集合，查找大集合（优化性能）
    if hit_dict.size() <= hurt_dict.size():
        for faction in hit_dict:
            if hurt_dict.has(faction):
                return true
    else:
        for faction in hurt_dict:
            if hit_dict.has(faction):
                return true
    
    return false
```

**伤害处理中的阵营检查**：`quiver_hurt_box.gd:158-161`
```gdscript
func _handle_hit_box(hit_box: QuiverHitBox) -> void:
    if are_factions_equal(hit_box, self):
        return
    # ... 继续处理伤害
```

**缓存刷新**：`quiver_hit_box.gd:48-52`、`quiver_hurt_box.gd:45-48`
```gdscript
func add_to_group(group: StringName, persistent: bool = false) -> void:
    super(group, persistent)
    if str(group).begins_with(QuiverHurtBox.FACTION_PREFIX):
        _refresh_faction_cache()
```

### 检测逻辑

1. `_ready()` 时初始化 `_faction_dict`，缓存所有 `area2d:` 前缀的 group
2. 重写 `add_to_group()` / `remove_from_group()`，捕获运行时的 group 变更
3. `_handle_hit_box()` 调用 `are_factions_equal()` 检查阵营
4. 同阵营双方的 HitBox/HurtBox 不会互相造成伤害/抓取

---

## 二、根节点 Group（`players` / `enemies`）

根节点的 `groups=["players"]` 或 `groups=["enemies"]` 有以下特殊用途：

### 1. 死亡处理

**代码位置**：`quiver_action_die.gd:62-68`

```gdscript
func _on_skin_animation_finished() -> void:
    if _character.is_in_group("players"):
        Engine.time_scale = 1.0
        Events.player_died.emit()
    else:
        _character.queue_free()
```

**影响**：
- `"players"` → 触发慢动作 + 游戏结束事件
- `"enemies"` → 直接销毁 + `Events.enemy_defeated`

### 2. 慢动作死亡效果

**代码位置**：`quiver_action_launch.gd:110-114`

```gdscript
func _should_slow_motion() -> bool:
    var is_player := _character.is_in_group("players")
    var is_normal_time := Engine.time_scale == 1.0 
    var is_dead := _attributes.health_current <= 0
    return is_player and is_dead and is_normal_time
```

**影响**：只有玩家死亡时触发 `Engine.time_scale = 0.2`（慢动作）。

### 3. 玩家检测器

**代码位置**：`quiver_player_detector.gd:98`

```gdscript
func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("players"):
        player_detected.emit()
```

**影响**：只有 `"players"` 组的角色进入检测区域才触发战斗。

### 4. AI 追击目标

**代码位置**：`quiver_character_helper.gd:29`

```gdscript
static func find_closest_player_to(node: Node2D) -> Node2D:
    var players := node.get_tree().get_nodes_in_group("players")
    # ... 寻找最近的玩家
```

**影响**：AI 只追击 `"players"` 组的角色。

---

## 三、配置检查清单

创建新角色时，需要配置的 group：

### 根节点 Group

- [ ] 玩家：`groups=["players"]`
- [ ] 敌人：`groups=["enemies"]`

### 阵营 Group（所有 Area2D）

- [ ] HurtBox：`groups=["area2d:<角色名>"]`
- [ ] HitBox (Attack1/2/3/Air)：`groups=["area2d:<角色名>"]`
- [ ] GrabBox（如果有）：`groups=["area2d:<角色名>"]`

**注意**：同一角色的所有 Area2D 必须使用相同的 `area2d:` group，否则会被视为不同阵营。

---

## 四、相关文件索引

### 插件代码

- `addons/quiver.beat_em_up/combat/collision_areas/quiver_hit_box.gd` — HitBox 实现
- `addons/quiver.beat_em_up/combat/collision_areas/quiver_hurt_box.gd` — HurtBox 实现 + 阵营检查
- `addons/quiver.beat_em_up/combat/collision_areas/quiver_grab_box.gd` — GrabBox 实现
- `addons/quiver.beat_em_up/characters/action_states/quiver_action_die.gd` — 死亡处理
- `addons/quiver.beat_em_up/characters/action_states/air_actions/knockout_actions/quiver_action_launch.gd` — 慢动作
- `addons/quiver.beat_em_up/utilities/custom_nodes/quiver_player_detector.gd` — 玩家检测
- `addons/quiver.beat_em_up/utilities/helpers/quiver_character_helper.gd` — AI 追击

---

## 五、后续调整方向

### 中期（优化插件）

1. 考虑是否需要更灵活的阵营系统（多阵营、动态阵营）

### 长期（重构可能）

1. 考虑将碰撞配置集中到一个资源文件，而非分散在 .tscn
2. 考虑是否需要可视化编辑器来管理阵营

---

**维护者**: 开发团队
