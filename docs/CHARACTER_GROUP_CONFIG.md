# 角色 Group 配置参考

> **创建日期**: 2026-08-15  
> **用途**: 记录所有与 group 相关的配置项、位置和功能，供后续调整实现方式时参考

---

## 一、配置项总览

以 `chen_jingchou` 为例，完整列出所有 group 相关配置：

| 配置项 | 文件位置 | 当前值 | 功能 |
|--------|---------|--------|------|
| 根节点 group | `chen_jingchou.tscn:30` | `["players"]` | 标记角色身份（玩家/敌人） |
| CharacterBody2D collision_layer | `chen_jingchou.tscn:31` | `1` (layer 1) | 物理体所在碰撞层 |
| HurtBox group | `chen_jingchou_skin.tscn:81` | `["area2d:chen_jingchou"]` | 阵营标识 |
| HurtBox collision_layer | `chen_jingchou_skin.tscn:82` | `4096` (layer 13) | 受击区域所在层 |
| HurtBox collision_mask | `chen_jingchou_skin.tscn:83` | `2560` (layer 10+12) | 检测哪些攻击层 |
| HurtBox metadata/collision_type | `chen_jingchou_skin.tscn:86` | `"player_hurt_box"` | 碰撞预设标识 |
| HitBox group (Attack1/2/3/Air) | `chen_jingchou_skin.tscn:96,113,130,147` | `["area2d:chen_jingchou"]` | 阵营标识 |
| HitBox collision_layer | `chen_jingchou_skin.tscn:99,116,133,150` | `256` (layer 9) | 攻击区域所在层 |
| HitBox collision_mask | `chen_jingchou_skin.tscn:100,117,134,151` | `0` | 不主动检测 |
| HitBox metadata/collision_type | `chen_jingchou_skin.tscn:104,121,138,155` | `"player_hit_box"` | 碰撞预设标识 |
| HitBox character_type | 代码中（未导出） | `PLAYERS (0)` | 决定预设 + HUD 行为 |

---

## 二、三层防护机制详解

### 层级 1：碰撞层分离（物理层面）

**原理**：通过 layer/mask 配置，物理引擎层面阻止同阵营检测。

**玩家配置**：
```
HitBox:  layer 9  (256), mask 0      → 被动，被检测
HurtBox: layer 13 (4096), mask 2560  → 主动检测 layer 10+12（敌人攻击+抓取）
```

**敌人配置**（需要改成）：
```
HitBox:  layer 10 (512), mask 0      → 被动，被检测
HurtBox: layer 14 (8192), mask 1536  → 主动检测 layer 9+11（玩家攻击+抓取）
```

**检测关系**：
```
玩家 HurtBox (mask 2560) ←→ 敌人 HitBox (layer 512)  ✅ 检测到（2560 & 512 = 512）
玩家 HurtBox (mask 2560) ←→ 玩家 HitBox (layer 256)  ❌ 不检测（2560 & 256 = 0）
敌人 HurtBox (mask 1536) ←→ 玩家 HitBox (layer 256)  ✅ 检测到（1536 & 256 = 256）
敌人 HurtBox (mask 1536) ←→ 敌人 HitBox (layer 512)  ❌ 不检测（1536 & 512 = 0）
```

**位置**：
- `chen_jingchou.tscn:31` — CharacterBody2D collision_layer
- `chen_jingchou_skin.tscn:82-83` — HurtBox layer/mask
- `chen_jingchou_skin.tscn:99-100,116-117,133-134,150-151` — HitBox layer/mask

---

### 层级 2：阵营 Group（逻辑层面）

**原理**：通过 `"area2d:"` 前缀的 Godot group 标记阵营，代码层面阻止同阵营伤害。

**实现**：
- `QuiverHurtBox._faction_dict` — 缓存所有 `"area2d:"` 前缀的 group
- `QuiverHitBox._faction_dict` — 同上
- `are_factions_equal(hit_box, hurt_box)` — 检查是否有共同阵营

**代码位置**：
- `quiver_hurt_box.gd:15` — `FACTION_PREFIX = "area2d:"`
- `quiver_hurt_box.gd:86-105` — `are_factions_equal()` 静态方法
- `quiver_hurt_box.gd:170-173` — `_handle_hit_box()` 中的阵营检查
- `quiver_hit_box.gd:55` — `add_to_group()` 重写，刷新 `_faction_dict`

**当前配置**：
```
chen_jingchou 所有 Area2D: groups=["area2d:chen_jingchou"]
```

**检测逻辑**：
```gdscript
func _handle_hit_box(hit_box: QuiverHitBox) -> void:
    # 阵营检查：同阵营不造成伤害
    if are_factions_equal(hit_box, self):
        return
    # ... 继续处理伤害
```

**位置**：
- `chen_jingchou_skin.tscn:81` — HurtBox group
- `chen_jingchou_skin.tscn:96,113,130,147` — HitBox group

---

### 层级 3：character_type 枚举（预设 + HUD）

**原理**：`CombatSystem.CharacterTypes` 枚举决定碰撞预设和 HUD 行为。

**枚举值**：
```gdscript
enum CharacterTypes {
    PLAYERS = 0,
    ENEMIES = 1,
    BOUNCE_OBSTACLE = 2,
}
```

**功能 1：自动应用碰撞预设**

如果 `.tscn` 中未设置 `metadata/collision_type`，插件根据 `character_type` 自动应用：

| character_type | 自动应用的 preset |
|----------------|------------------|
| `PLAYERS (0)` | `"player_hit_box"` / `"player_hurt_box"` |
| `ENEMIES (1)` | `"enemy_hit_box"` / `"enemy_hurt_box"` |
| `BOUNCE_OBSTACLE (2)` | `"world_hit_box"` |

**代码位置**：
- `quiver_hit_box.gd:_handle_character_type_presets()` — HitBox 预设应用
- `quiver_hurt_box.gd:_handle_character_type_presets()` — HurtBox 预设应用

**功能 2：HUD 数据发送**

只有 `PLAYERS` 的 HitBox 击中时才触发 HUD 更新：

```gdscript
# quiver_hurt_box.gd:185-186
if hit_box.character_type == CombatSystem.CharacterTypes.PLAYERS:
    Events.enemy_data_sent.emit(character_attributes, hit_box.character_attributes)
```

**当前配置**：
- `character_type` 未在 `.tscn` 中设置（不是 `@export`）
- 默认值：`PLAYERS (0)`（在 `quiver_hit_box.gd` 中定义）

**问题**：`character_type` 不是 `@export`，无法在 `.tscn` 中直接设置，需要在代码中设置或通过 `metadata/collision_type` 间接控制。

---

## 三、根节点 Group 的特殊用途

根节点的 `groups=["players"]` 或 `groups=["enemies"]` 有以下特殊用途：

### 1. 死亡处理

**代码位置**：`quiver_action_die.gd:62-68`

```gdscript
func _on_skin_animation_finished() -> void:
    if _character.is_in_group("players"):
        Engine.time_scale = 1.0  # 恢复时间
        Events.player_died.emit()  # 游戏结束
    else:
        _character.queue_free()  # 销毁敌人
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

**位置**：
- `chen_jingchou.tscn:30` — `groups=["players"]`

---

## 四、碰撞层分配表

完整的碰撞层分配（来自 `project.godot`）：

| Layer | 名称 | 用途 | 当前使用 |
|-------|------|------|---------|
| 1 | players | 玩家物理体 | ✅ chen_jingchou |
| 2 | obstacles | 墙壁、地形 | ✅ test_stage |
| 3 | screen_limits | 关卡边缘 | ✅ test_stage |
| 4 | ceiling_limits | 垂直边界 | ✅ test_stage |
| 5 | enemies | 敌人物理体 | ❌ 未使用 |
| 8 | world_hit_boxes | 反弹墙 | ❌ 未使用 |
| 9 | player_hit_boxes | 玩家攻击区域 | ✅ chen_jingchou |
| 10 | enemy_hit_boxes | 敌人攻击区域 | ❌ 未使用 |
| 11 | player_grab_boxes | 玩家抓取区域 | ❌ 未使用 |
| 12 | enemy_grab_boxes | 敌人抓取区域 | ❌ 未使用 |
| 13 | player_hurt_boxes | 玩家受击区域 | ✅ chen_jingchou |
| 14 | enemy_hurt_boxes | 敌人受击区域 | ❌ 未使用 |
| 15-24 | height_* | 高度层系统 | ✅ 动态使用 |

**位置**：`project.godot:[layer_names]` 部分

---

## 五、待决问题

### 1. character_type 如何设置？

**现状**：`character_type` 不是 `@export`，无法在 `.tscn` 中设置。

**选项**：
- A. 在角色脚本的 `_ready()` 中设置（需要修改所有角色脚本）
- B. 通过 `metadata/collision_type` 间接推断（当前实现）
- C. 将 `character_type` 改为 `@export`（需要修改插件）

### 2. 是否需要三层防护？

**现状**：碰撞层 + 阵营 group + character_type 三层机制。

**问题**：
- 碰撞层已经能防止同阵营检测，阵营 group 是否多余？
- character_type 的 HUD 功能是否可以合并到其他机制？

**建议**：
- 保留碰撞层（物理层面，性能最好）
- 保留阵营 group（逻辑层面，支持复杂阵营关系）
- 简化 character_type（仅用于 HUD，或完全移除）

### 3. 敌人创建流程如何简化？

**现状**：Inspector 工具生成的角色默认是玩家配置，需要手动修改 10+ 个配置项。

**选项**：
- A. Inspector 工具增加"角色类型"选项（玩家/敌人），自动生成对应配置
- B. 创建 `enemy_base.tscn` 模板，敌人继承此模板
- C. 提供脚本工具，一键转换玩家→敌人

### 4. 碰撞预设系统是否保留？

**现状**：`metadata/collision_type` + `_handle_character_type_presets()` 自动应用预设。

**问题**：
- 如果 `.tscn` 中已设置 `metadata/collision_type`，插件不会覆盖
- 但如果未设置，插件会根据 `character_type` 自动应用
- 这导致配置分散在两处（metadata + character_type），容易混淆

**建议**：
- 统一为一种方式：要么全部用 metadata，要么全部用 character_type
- 或者移除自动预设，要求所有配置在 `.tscn` 中显式设置

---

## 六、修改检查清单

创建敌人角色时，需要修改的配置项：

### 必须修改（物理层面）

- [ ] 根节点 group: `["players"]` → `["enemies"]`
- [ ] CharacterBody2D collision_layer: `1` → `16` (layer 5)
- [ ] HitBox collision_layer: `256` → `512` (layer 10)
- [ ] HurtBox collision_layer: `4096` → `8192` (layer 14)
- [ ] HurtBox collision_mask: `2560` → `1536` (layer 9+11)

### 必须修改（逻辑层面）

- [ ] HitBox group: `["area2d:chen_jingchou"]` → `["area2d:enemy"]`（不同阵营）
- [ ] HurtBox group: `["area2d:chen_jingchou"]` → `["area2d:enemy"]`（不同阵营）

### 必须修改（预设标识）

- [ ] HitBox metadata/collision_type: `"player_hit_box"` → `"enemy_hit_box"`
- [ ] HurtBox metadata/collision_type: `"player_hurt_box"` → `"enemy_hurt_box"`

### 可能需要修改（代码层面）

- [ ] HitBox character_type: `PLAYERS (0)` → `ENEMIES (1)`（如果改为 @export）
- [ ] HurtBox character_type: `PLAYERS (0)` → `ENEMIES (1)`（如果改为 @export）

---

## 七、相关文件索引

### 场景文件

- `characters/playable/chen_jingchou/chen_jingchou.tscn` — 角色主场景
- `characters/playable/chen_jingchou/chen_jingchou_skin.tscn` — 皮肤 + Area2D 配置

### 插件代码

- `addons/quiver.beat_em_up/combat/collision_areas/quiver_hit_box.gd` — HitBox 实现
- `addons/quiver.beat_em_up/combat/collision_areas/quiver_hurt_box.gd` — HurtBox 实现
- `addons/quiver.beat_em_up/combat/quiver_collision_types.gd` — 碰撞预设定义
- `addons/quiver.beat_em_up/characters/action_states/quiver_action_die.gd` — 死亡处理
- `addons/quiver.beat_em_up/characters/action_states/air_actions/knockout_actions/quiver_action_launch.gd` — 慢动作
- `addons/quiver.beat_em_up/utilities/helpers/quiver_player_detector.gd` — 玩家检测
- `addons/quiver.beat_em_up/utilities/helpers/quiver_character_helper.gd` — AI 追击

### 项目配置

- `project.godot:[layer_names]` — 碰撞层名称定义

---

## 八、后续调整方向

### 短期（创建 enemy 时）

1. 确认 character_type 的设置方式（代码 vs metadata）
2. 决定是否简化配置流程（Inspector 工具 vs 手动修改）
3. 验证三层防护机制是否都必要

### 中期（优化插件）

1. 考虑将 character_type 改为 @export，简化配置
2. 考虑统一碰撞预设系统（metadata vs character_type）
3. 考虑是否需要更灵活的阵营系统（多阵营、动态阵营）

### 长期（重构可能）

1. 评估是否需要保留三层防护，或简化为两层
2. 考虑将碰撞配置集中到一个资源文件，而非分散在 .tscn
3. 考虑是否需要可视化编辑器来管理碰撞层和阵营

---

**最后更新**: 2026-08-15  
**维护者**: 开发团队
