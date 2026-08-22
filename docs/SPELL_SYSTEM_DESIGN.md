# 法术系统设计文档

> **版本**: 1.3.0  
> **创建日期**: 2026-08-20  
> **最后更新**: 2026-08-22  
> **状态**: ✅ 已完成  
> **实施完成日期**: 2026-08-22

---

## 一、需求分析

### 1.1 法术分类

根据天之痕五行法术系统的需求，法术可分为以下类型：

| 类别 | 示例 | 物理形态 | 交互对象 | 生命周期 |
|------|------|----------|----------|----------|
| **弹道攻击** | 火球、冰箭 | 运动中的 Area2D | 敌方 HurtBox | 飞行 → 命中 → 销毁 |
| **范围攻击** | 火墙、地震 | 固定位置的 Area2D | 范围内所有敌方 | 持续存在 → 超时消失 |
| **治疗/恢复** | 回春术 | 自身或目标位置 | 友方 QuiverAttributes | 瞬发或持续 |
| **增益 Buff** | 铁壁、疾风 | 附着在目标身上 | 目标的属性/状态 | 持续 N 秒 |
| **减益 Debuff** | 冰冻、灼烧 | 附着在目标身上 | 目标的属性/状态 | 持续 N 秒 |
| **功能/辅助** | 隐身、瞬移 | 自身效果 | 施放者自身 | 瞬发或持续 |
| **召唤** | 召唤兽 | 独立实体 | 场景 | 独立生命周期 |

### 1.2 核心设计原则

1. **法术概念 ≠ 法术实例**
   - 法术概念（SpellDefinition）：角色装备的"技能"，有 CD、法力消耗，持久存在
   - 法术实例（SpellBase）：施放后的 Area2D，有运动、碰撞、生命周期，效果产生后销毁

2. **角色只负责触发**
   - 角色持有法术列表（"我学了哪些法术"）
   - 角色触发施放（"我要放第 N 个法术"）
   - 角色不关心法术的具体配置（mana_cost、cooldown 等）

3. **复用现有系统**
   - 战斗系统：复用 QuiverCombatSystem、QuiverHurtBox、QuiverHitBox
   - 轮廓转换：复用 AnimationTrackInjector.convert_attack_contours()
   - 动画管理：复用 QuiverCharacterSkinAnimTree 的 AnimationTree 管理逻辑

### 1.3 法术概念 vs 法术实例

这是法术系统最核心的区分：

| 维度 | 法术概念（SpellDefinition） | 法术实例（SpellBase） |
|------|---------------------------|---------------------|
| 本质 | Resource（配置数据） | Area2D（运行时对象） |
| 生命周期 | 持久存在，角色装备后一直持有 | 瞬态，施放后存在，效果产生后销毁 |
| 持有者 | SpellManager（角色的法术管理器） | 场景树（add_child 到场景） |
| 包含内容 | spell_id、display_name、mana_cost、cooldown、spell_scene 引用 | 运动、碰撞、动画、HitBox、生命周期状态机 |
| 数量 | 角色可装备多个（固定槽位） | 每次施放创建一个实例 |

**关键理解**："法术释放后就销毁了"指的是法术实例（SpellBase）销毁，不代表法术概念消失。
法术概念仍然存在于角色的法术槽位中，等待 CD 结束后可以再次施放。
角色可以学习和遗忘法术（操作 SpellDefinition），施放和销毁法术实例（操作 SpellBase）。

---

## 二、架构决策

### 2.1 架构位置

**决策：游戏层独立系统（方案 A）**

- 法术基类和模板系统全部放在 `xuanyuan-sword/spells/`（游戏代码）
- 不修改 Quiver 插件核心（除 QuiverAttributes 添加法力值和 Modifier 系统）
- 法术创建 Inspector 放在插件内（需要 EditorInspectorPlugin 注册机制）

**理由**：
1. 法术是游戏设计概念（五行系统），不是 beat-em-up 框架的通用功能
2. 不修改插件 = 不触发文档维护规则（除 QuiverAttributes）
3. AnimationTree 管理逻辑约 60 行，重复成本可接受

**否决方案**：
- **方案 B（插件内集成）**：法术系统放在 Quiver 插件内，可被其他项目复用。否决理由：法术是游戏特有概念（五行系统），不是 beat-em-up 框架的通用功能，放在插件中会增加插件复杂度。
- **方案 C（提取共享基类）**：从 QuiverCharacterSkin 和 QuiverCharacterSkinAnimTree 中提取通用逻辑为 QuiverAnimTreeOwner 基类。否决理由：需要重构现有角色的继承链，风险大，改动面广。

### 2.2 根节点类型

**决策：SpellBase extends Area2D**

- 法术是独立实体，通过 `_physics_process` 自定义运动
- 不使用 CharacterBody2D（不需要 move_and_slide）
- 碰撞通过 area_entered 信号检测

### 2.3 Skin 继承链

**决策：平行继承链**

```
角色（现有）:                          法术（新增）:
QuiverCharacter (CharacterBody2D)      SpellBase (Area2D)
└── $Skin                              └── $Skin
    QuiverCharacterSkin (Node2D)           SpellSkin (Node2D)
    └── QuiverCharacterSkinAnimTree        └── SpellSkinAnimTree
```

**理由**：
- QuiverCharacterSkin 假设父节点是 CharacterBody2D，法术不适用
- 平行链避免继承污染
- AnimationTree 管理逻辑约 60 行，重新实现成本低

**否决方案**：
- **复用 QuiverCharacterSkinAnimTree 继承链**：QuiverCharacterSkin 假设父节点是 CharacterBody2D，法术根节点是 Area2D，直接继承会导致 `_runtime_ready()` 中 HurtBox 引用填充失败、`_update_collision_layers()` 无法调用等问题。
- **最小化复用（只继承 Node2D）**：需要重写 AnimationTree 管理逻辑（约 60 行），与平行链方案的代码量相同，但失去了信号和朝向管理的复用。

### 2.4 AnimationPlayer 架构

**决策：单个 AnimationPlayer + 单个 AnimationTree**

- 通过多 track 控制多个 AnimatedSprite2D、多个 HitBox、多个视觉元素
- 不使用多 AnimationPlayer（过设计）

**理由**：
- 多 HitBox 独立时序：单 AnimationPlayer 多 track 足够
- 独立视觉元素：单 AnimationPlayer 多 track 足够
- 阶段式法术：AnimationTree 状态机足够
- 组合式法术：可通过动态添加子效果实现

**讨论过程**：
曾考虑多 AnimationPlayer 方案（主从 AP），讨论了 4 种需要多 AP 的场景（多 HitBox 独立时序、独立视觉元素、阶段式法术、组合式法术），以及 3 种主从划分标准（gameplay vs 视觉、独立状态管理需求、轮廓转换边界）。还尝试了"多 AnimationTree 共享一个 AnimationPlayer"方案，但发现多个 AnimationTree 共享一个 AnimationPlayer 时会争抢播放控制权，无法同时播放不同动画。最终决定：单个 AnimationPlayer 通过多 track 可以控制多个 AnimatedSprite2D、多个 HitBox、多个视觉元素，完全够用。多 AnimationPlayer 是过设计。

### 2.5 阵营系统

**决策：继承施放者 faction group**

- 法术被施放时继承施放者的 `area2d:` group
- 法术的 HitBox 与施放者同阵营，不会伤害施放者及其队友
- 通过 `QuiverHurtBox.are_factions_equal()` 自动过滤

### 2.6 轮廓转换工具

**决策：完全复用 convert_attack_contours()**

- 法术的 attack 转换与角色的 attack 转换**零区分**
- 法术 Widget 隐藏 body 转换按钮，只暴露 attack 转换
- 底层调用同一个 `AnimationTrackInjector.convert_attack_contours()`

**理由**：
- `convert_attack_contours()` 内部不检查 skin 节点类型，只检查节点结构
- 法术 skin 的 `Attacks` 节点结构与角色完全一致

---

## 三、设计缺口与决策

在详细设计过程中发现并解决了以下 6 个设计缺口：

### 3.1 HitBox 激活机制

**问题**：法术动画中 `spell_hit_active()` / `spell_hit_deactive()` 方法 track 与 CollisionShape2D 的 `disabled` track 可能同时控制同一个 HitBox。

**决策**：保留两者，职责不同：
- `disabled` track：控制碰撞物理（由轮廓转换工具自动注入）
- `spell_hit_active/deactive`：gameplay 回调，触发信号供 SpellBase 子类实现联动逻辑

两者并行不冲突。例如 `spell_hit_active()` 可以在启用碰撞的同时触发音效或粒子效果。

### 3.2 Widget 触发机制

**问题**：现有 Height Layers Widget 的 `_can_handle()` 检查 `QuiverCharacterSkinAnimTree` 类型，法术的 `SpellSkinAnimTree` 不会触发。

**分析**：`convert_attack_contours()` 内部不检查 skin 节点类型，只检查节点结构（`AnimatedSprite2D`、`AnimationPlayer`、`Attacks/` 路径）。底层完全可复用。

**决策**：独立的法术 Inspector 插件 + Widget，触发条件为 `SpellSkinAnimTree`，UI 中隐藏 body 转换按钮，底层调用同一个 `AnimationTrackInjector.convert_attack_contours()`。

### 3.3 高度层动态更新

**问题**：角色的 `_update_collision_layers()` 每帧读取 `attack_heights` 并更新 HitBox 碰撞层。法术也需要这个逻辑。

**决策**：法术的 `physical_height` 来自施放者（在 `cast()` 时获取），高度层算法与角色一致。SpellBase 在 `_physics_process()` 中调用 `_update_hitbox_layers()`。

### 3.4 physical_height / physical_width

**问题**：SpellSkin 是否需要保留这两个属性？

**决策**：不保留。法术只有 attack 转换，不注入 `physical_height` / `physical_width` tracks。高度层计算时从施放者获取 `physical_height`。SpellSkin 只需要 `attack_heights`。

### 3.5 基础场景结构

**决策**：已定义 `spell_skin_base.tscn`（AnimationPlayer + AnimationTree）和法术主场景结构。与 `quiver_character_skin_base.tscn` 结构完全一致。

### 3.6 cast() 时序保护

**问题**：`cast()` 依赖 `@onready` 变量（`_skin`、`_hitboxes`），必须在 `_ready()` 之后调用。如果 `add_child()` 和 `cast()` 在同一帧调用，`@onready` 可能还未就绪。

**决策**：`cast()` 内部加 `if not is_inside_tree(): await ready` 保护。

### 3.7 生成位置与 spawn parent

**问题**：法术作为谁的子节点？`current_scene.add_child()` 会将法术添加到场景根节点，
但角色实际在 `Level/Characters` 容器中，法术不参与 y_sort。

**分析**：
- 标准 stage 场景树：`BaseLevel > Level > Characters > 角色`
- `Level/Characters` 有 `y_sort=true`，角色在其中正确排序
- 法术如果在 `BaseLevel` 根节点下，不参与 `Level` 的 y_sort

**决策**：`spawn_parent = _character.get_parent()`
- 法术添加到角色的父节点（`Level/Characters`），与角色在同一容器
- 参与 y_sort，渲染层级正确
- 与 QuiverEnemySpawner 的做法一致（敌人也添加到 `Level/Characters`）
- `add_child` 后再设 `global_position`，Godot 正确计算 local position

**偏移量设计**：
- `get_spawn_offset(direction)` 是 SpellBase 的虚函数
- 默认实现从施放者的 `physical_height` / `physical_width` 动态计算
- 子类可 override 实现不同的发射位置（手掌、脚下、头顶等）

### 3.8 法术命中感知

**问题**：HitBox 是 passive（monitoring=false），不会触发 `area_entered`。
法术（攻击方）无法通过信号感知命中。SpellBase 中连接 `hitbox.area_entered` 是错误的。

**分析**：
- HurtBox 检测到 HitBox 时，已经持有 `hit_box` 引用
- HitBox 的 `owner` 属性自动指向法术实例（Godot 场景实例化时设置）
- 不需要修改 QuiverHitBox（不添加任何属性）

**决策**：在 `QuiverHurtBox._handle_hit_box()` 中，伤害应用后通过 `hit_box.owner` 找到法术实例，
调用 `SpellBase.on_hit(hurtbox)` 方法。

**优点**：
- 不修改 QuiverHitBox
- QuiverHurtBox 只加 3 行代码
- 复用 Godot 标准 `owner` 机制
- 非 SpellBase 的 HitBox（角色攻击）没有 `on_hit` 方法，自动跳过

### 3.9 高度层 bitmask 计算复用

**问题**：SpellBase 中的 `_update_hitbox_layers()` 重写了 bitmask 计算代码，
且写错了（`hitbox.collision_layer = bitmask` 覆盖了所有 bit，不只是高度层 bit）。
角色的代码是正确的：`hitbox.collision_layer = (hitbox.collision_layer & ~all_mask) | target_bits`。

**分析**：
- QuiverCharacter 的 `_height_to_layer()`、`_layers_to_bitmask()` 是 private instance 方法
- SpellBase 无法直接调用

**决策**：在 QuiverCharacter 中新增 3 个 public static 方法：
- `height_to_layer(height, height_definitions)` — 高度值转层号
- `layers_to_bitmask(layers)` — 层号数组转 bitmask
- `get_height_definitions()` — 获取高度层定义

SpellBase 的 `_update_hitbox_layers()` 调用这些 static 方法，不再自己重写。
同时添加 `_cached_hitbox_height_bits` 缓存，只在 bitmask 变化时更新。

---

## 四、核心类设计

### 4.1 SpellDefinition (Resource)

法术配置数据的唯一载体。

```gdscript
class_name SpellDefinition
extends Resource

## 法术唯一标识（用于 CD 追踪、叠加检查）
@export var spell_id: StringName

## 显示名（中文）
@export var display_name: String

## 描述文本（HUD 用）
@export var description: String

## 图标（HUD 用）
@export var icon: Texture2D

## 法术场景（SpellBase 子类）
@export var spell_scene: PackedScene

## 法力消耗（0 = 免费）
@export var mana_cost: float = 0.0

## 法术实例最大存活时间（秒，0 = 无限）
## 法术实例（SpellBase）超过此时间后自动进入 ENDING 阶段
@export var max_lifetime: float = 5.0

## 冷却时间（秒，0 = 无 CD）
## 施放后需要等待此时间才能再次施放
@export var cooldown: float = 0.0

## 允许施放的动作状态列表（白名单，为空时不做白名单检查）
@export var allowed_states: Array[StringName] = []

## 禁止施放的动作状态列表（黑名单，为空时不做黑名单检查）
## 黑名单优先于白名单：如果当前状态在黑名单中，直接拒绝
@export var disallowed_states: Array[StringName] = [&"Die", &"Knockout"]
```

**文件位置**：`spells/<spell_name>/resources/<spell_name>_definition.tres`

### 4.2 SpellSlot (RefCounted)

法术槽位，持有 SpellDefinition 引用和冷却状态。

```gdscript
class_name SpellSlot
extends RefCounted

## 法术定义引用
var definition: SpellDefinition = null

## 剩余冷却时间
var cooldown_remaining: float = 0.0

## 槽位是否为空
func is_empty() -> bool:
    return definition == null

## CD 是否就绪
func is_ready() -> bool:
    return cooldown_remaining <= 0.0

## 启动冷却
func start_cooldown() -> void:
    cooldown_remaining = definition.cooldown

## 每帧递减冷却
func tick(delta: float) -> void:
    cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
```

### 4.3 SpellManager (RefCounted)

法术管理器，负责装备/遗忘/施放/CD tick/法力检查/状态检查/召唤物管理。

```gdscript
class_name SpellManager
extends RefCounted

## 最大槽位数
const MAX_SLOTS := 4

## 法术槽位数组
var _slots: Array[SpellSlot]

## 所属角色引用
var _character: QuiverCharacter

## 已召唤的召唤物追踪（Dictionary，key 是 Node 实例，O(1) 增删）
var _active_summons: Dictionary = {}

func _init(character: QuiverCharacter) -> void:
    _character = character
    for i in MAX_SLOTS:
        _slots.append(SpellSlot.new())

## 每帧更新（由角色 _physics_process 调用）
func tick(delta: float) -> void:
    for slot in _slots:
        if not slot.is_empty():
            slot.tick(delta)

## 学习法术（找空槽位放入）
func learn_spell(spell_def: SpellDefinition) -> bool:
    for i in _slots.size():
        if _slots[i].is_empty():
            _slots[i].definition = spell_def
            return true
    return false  # 没有空槽位

## 遗忘法术（清空槽位）
func forget_spell(index: int) -> void:
    if index >= 0 and index < _slots.size():
        _slots[index].definition = null
        _slots[index].cooldown_remaining = 0.0

## 获取槽位（HUD 查询用）
func get_spell_slot(index: int) -> SpellSlot:
    if index >= 0 and index < _slots.size():
        return _slots[index]
    return null

## 按索引施放法术
func cast_spell_by_index(index: int) -> void:
    if index < 0 or index >= _slots.size():
        return
    cast_spell(_slots[index])

## 施放法术（完整流程）
func cast_spell(slot: SpellSlot) -> void:
    # 1. 检查槽位是否为空
    if slot.is_empty():
        return
    
    # 2. 检查 CD
    if not slot.is_ready():
        return
    
    # 3. 检查法力
    if _character.attributes.mana_current < slot.definition.mana_cost:
        return
    
    # 4. 检查动作状态
    if not _is_state_allowed(slot.definition):
        return
    
    # 5. 扣除法力
    _character.attributes.mana_current -= slot.definition.mana_cost
    
    # 6. 启动 CD
    slot.start_cooldown()
    
    # 7. 实例化法术
    var spell := slot.definition.spell_scene.instantiate() as SpellBase
    
    # 8. 确定施放方向（从 Skin 朝向读取）
    var dir := Vector2.RIGHT
    if _character.get_node_or_null("Skin"):
        var skin = _character.get_node("Skin")
        dir = Vector2.LEFT if skin.skin_direction == -1 else Vector2.RIGHT
    
    # 9. 添加到角色的父节点（Level/Characters 容器，与角色同一层级，参与 y_sort）
    var spawn_parent := _character.get_parent()
    spawn_parent.add_child(spell)
    
    # 10. 设置生成位置（add_child 后设 global_position，Godot 正确计算 local position）
    spell.global_position = _character.global_position + spell.get_spawn_offset(dir)
    
    # 11. 施放（位置已在上面设置，cast 不再接收 spawn_position 参数）
    spell.cast(_character, slot.definition, dir)

## 检查动作状态是否允许施放（黑名单优先于白名单）
func _is_state_allowed(spell_def: SpellDefinition) -> bool:
    var state_machine := _character.get_node_or_null("StateMachine") as QuiverStateMachine
    if state_machine == null:
        return true  # 无状态机时不限制
    var current_state_name := str(state_machine.state_name)
    
    # 黑名单优先：在黑名单中直接拒绝
    if not spell_def.disallowed_states.is_empty():
        if current_state_name in spell_def.disallowed_states:
            return false
    
    # 白名单：非空时检查是否在白名单中
    if not spell_def.allowed_states.is_empty():
        return current_state_name in spell_def.allowed_states
    
    return true  # 两个列表都为空时不限制

## 施放者死亡时解散所有召唤物
func dismiss_all_summons() -> void:
    for creature in _active_summons.keys():
        if is_instance_valid(creature):
            creature.queue_free()
    _active_summons.clear()

## 注册召唤物（由召唤法术子类调用）
func register_summon(creature: Node) -> void:
    _active_summons[creature] = true
    creature.tree_exiting.connect(_on_summon_exiting.bind(creature))

## 召唤物从场景树移除时自动清理引用
func _on_summon_exiting(creature: Node) -> void:
    _active_summons.erase(creature)
```

### 4.4 SpellBase (Area2D)

法术运行时行为基类。

```gdscript
class_name SpellBase
extends Area2D

## 生命周期状态
enum SpellState { INACTIVE, ACTIVE, ENDING, DEAD }

## 法术定义引用（cast 时传入）
var definition: SpellDefinition = null

## 施放者引用
var caster: Node = null

## 施放者属性
var caster_attributes: QuiverAttributes = null

## 飞行方向
var direction: Vector2 = Vector2.RIGHT

## 当前状态
var state: SpellState = SpellState.INACTIVE

## 已存活时间
var _elapsed_time: float = 0.0

## HitBox 高度层缓存（避免每帧重复更新）
var _cached_hitbox_height_bits: int = -1

## 节点引用
@export_node_path("SpellSkin") var _path_skin := ^"Skin"
@export_node_path("Node2D") var _path_hitboxes_container := ^"Attacks"

@onready var _skin: SpellSkin = get_node_or_null(_path_skin)
@onready var _hitboxes: Array[QuiverHitBox] = []

## 信号
signal spell_cast
signal spell_hit(target: Area2D)
signal spell_activated
signal spell_ending
signal spell_destroyed
signal spell_timeout

func _ready() -> void:
    if Engine.is_editor_hint():
        return
    
    # 收集 HitBox 引用
    var hitboxes_container := get_node_or_null(_path_hitboxes_container) as Node2D
    if hitboxes_container:
        for child in hitboxes_container.get_children():
            if child is QuiverHitBox:
                _hitboxes.append(child)
    
    # 连接 SpellSkin 信号
    if _skin:
        _skin.spell_animation_finished.connect(_on_skin_animation_finished)
        _skin.spell_hitbox_activated.connect(_on_skin_hitbox_activated)
        _skin.spell_hitbox_deactivated.connect(_on_skin_hitbox_deactivated)
        _skin.spell_effect_triggered.connect(_on_skin_effect_triggered)
        _skin.spell_spawn_requested.connect(_on_skin_spawn_requested)
        _skin.spell_ended.connect(_on_skin_spell_ended)
    
    # 暂停，等待 cast()
    # 注意：HitBox 是 passive（monitoring=false），不连接 area_entered
    # 命中检测由敌方 HurtBox 完成，通过 hit_box.owner 找到法术并调用 on_hit()
    set_physics_process(false)
    
    _on_ready()

## 施放法术（由 SpellManager 调用）
## 注意：global_position 已由 SpellManager 在 add_child 后设置，cast 不再接收位置参数
func cast(p_caster: Node, p_definition: SpellDefinition, p_direction: Vector2) -> void:
    # 保护 @onready 就绪
    if not is_inside_tree():
        await ready
    
    caster = p_caster
    definition = p_definition
    direction = p_direction.normalized()
    
    # 获取施放者属性
    if caster.get("attributes") != null:
        caster_attributes = caster.attributes
    
    # 继承施放者 faction group
    for group in caster.get_groups():
        if group.begins_with("area2d:"):
            add_to_group(group)
    
    # 传播 faction 到所有 HitBox
    for hitbox in _hitboxes:
        for group in caster.get_groups():
            if group.begins_with("area2d:"):
                hitbox.add_to_group(group)
        hitbox.character_attributes = caster_attributes
        # attack_data 已在 HitBox 节点的 .tscn 中配置，无需额外传递
    
    # 设置 Skin 朝向
    if _skin:
        _skin.skin_direction = SpellSkin.SkinDirection.RIGHT \
            if direction.x >= 0 else SpellSkin.SkinDirection.LEFT
    
    # 子类钩子
    _on_cast()
    
    # 注意：HitBox 高度层由 _physics_process 中的 _update_hitbox_layers() 每帧更新
    
    # 激活
    state = SpellState.ACTIVE
    set_physics_process(true)
    spell_cast.emit()
    spell_activated.emit()
    
    # 触发初始动画
    if _skin and _skin._is_valid_state(&"active"):
        _skin.transition_to(&"active")

func _physics_process(delta: float) -> void:
    if state != SpellState.ACTIVE:
        return
    
    # 1. 时间累加
    _elapsed_time += delta
    
    # 2. 超时检查（使用 max_lifetime，不是 cooldown）
    if definition and definition.max_lifetime > 0.0 and _elapsed_time >= definition.max_lifetime:
        spell_timeout.emit()
        end()
        return
    
    # 3. 高度层更新
    _update_hitbox_layers()
    
    # 4. 子类行为
    _on_active(delta)

## 进入结束阶段
func end() -> void:
    if state == SpellState.DEAD or state == SpellState.ENDING:
        return
    
    state = SpellState.ENDING
    spell_ending.emit()
    _on_ending()
    
    # 如果有结束动画，等待完成（子类在 _on_skin_animation_finished 中调用 destroy()）
    if _skin and _skin._is_valid_state(&"ending"):
        _skin.transition_to(&"ending")
    else:
        destroy()

## 销毁法术
func destroy() -> void:
    if state == SpellState.DEAD:
        return
    
    state = SpellState.DEAD
    set_physics_process(false)
    spell_destroyed.emit()
    queue_free()

## 更新 HitBox 高度层（复用 QuiverCharacter 的 public static 方法）
func _update_hitbox_layers() -> void:
    if _skin == null or caster == null:
        return
    
    var ah: Array = _skin.attack_heights
    if ah.is_empty():
        return
    
    var base_h: float = _skin.base_height
    var height_defs := QuiverCharacter.get_height_definitions()
    var all_mask := QuiverCharacter.get_all_height_layers_mask()
    
    var target_bits := 0
    for h in ah:
        var absolute_h: float = base_h + h
        var layer := QuiverCharacter.height_to_layer(absolute_h, height_defs)
        target_bits |= (1 << (layer - 1))
    
    # 只在 bitmask 变化时更新（缓存优化，与 QuiverCharacter._update_hitbox_layers 一致）
    if target_bits != _cached_hitbox_height_bits:
        _cached_hitbox_height_bits = target_bits
        for hitbox in _hitboxes:
            # 保留非高度层 bit，只修改高度层 bit
            hitbox.collision_layer = (hitbox.collision_layer & ~all_mask) | target_bits
            hitbox.collision_mask = all_mask

## --- 子类钩子（虚函数）---

func _on_ready() -> void:
    pass

func _on_cast() -> void:
    pass

func _on_active(delta: float) -> void:
    # 默认：直线飞行
    position += direction * 400.0 * delta

func _on_ending() -> void:
    pass

## 命中通知（由 QuiverHurtBox 通过 hit_box.owner 找到法术并调用）
## 子类 override 实现命中后的行为（爆炸、穿透计数等）
func on_hit(hurtbox: QuiverHurtBox) -> void:
    spell_hit.emit(hurtbox)
    _on_hit(hurtbox)

func _on_hit(hurtbox: QuiverHurtBox) -> void:
    # 默认：进入结束阶段
    end()

## 计算法术生成位置偏移（相对于施放者 global_position）
## 子类 override 实现不同的发射位置（手掌、脚下、头顶等）
## 可查询施放者的 physical_height / physical_width 来适配不同体型的角色
func get_spawn_offset(direction: Vector2) -> Vector2:
    var char_height: float = 160.0  # 默认身高
    var char_width: float = 40.0    # 默认宽度
    if caster:
        var skin = caster.get_node_or_null("Skin")
        if skin:
            if skin.get("physical_height") != null:
                char_height = skin.physical_height
            if skin.get("physical_width") != null:
                char_width = skin.physical_width
    
    # 默认从角色前方 + 胸部高度发射
    var x_offset := (char_width * 0.5 + 30.0) * direction.x
    var y_offset := -char_height * 0.6  # 胸部高度（身高的 60%）
    
    return Vector2(x_offset, y_offset)

## --- SpellSkin 信号处理器（子类可 override）---

func _on_skin_animation_finished() -> void:
    pass

func _on_skin_hitbox_activated() -> void:
    for hitbox in _hitboxes:
        for child in hitbox.get_children():
            if child is CollisionShape2D or child is CollisionPolygon2D:
                child.disabled = false

func _on_skin_hitbox_deactivated() -> void:
    for hitbox in _hitboxes:
        for child in hitbox.get_children():
            if child is CollisionShape2D or child is CollisionPolygon2D:
                child.disabled = true

func _on_skin_effect_triggered() -> void:
    pass

func _on_skin_spawn_requested(marker_name: String) -> void:
    pass

func _on_skin_spell_ended() -> void:
    end()

## 注意：_setup_hitbox_layers() 已删除
## HitBox 高度层由 _update_hitbox_layers() 在 _physics_process 中每帧处理
## 使用 QuiverCharacter 的 public static 方法复用高度层计算逻辑
```

### 4.5 SpellSkin (Node2D)

法术皮肤基类，提供信号、朝向、高度层属性、HitBox 引用。

```gdscript
class_name SpellSkin
extends Node2D

## 朝向枚举
enum SkinDirection { LEFT = -1, RIGHT = 1 }

## 朝向
@export var skin_direction: SkinDirection = SkinDirection.RIGHT:
    set(value):
        var has_changed := value != skin_direction
        skin_direction = value
        if has_changed:
            if not is_inside_tree():
                await ready
            _skin_direction_updated()

## 高度层属性（接收动画 track 值）
var base_height: float:
    get: return -position.y

## 攻击高度层数据（由动画 track 写入）
@export var attack_heights: Array = []

## HitBox 引用
@export_node_path("Node2D") var _path_hitboxes_container := ^"Attacks"
var hitboxes: Array[QuiverHitBox] = []

## 动画列表
var _animation_list: Array[StringName] = []

## 信号（供 SpellBase 连接）
signal spell_animation_finished
signal spell_hitbox_activated
signal spell_hitbox_deactivated
signal spell_effect_triggered
signal spell_spawn_requested(marker_name: String)
signal spell_ended

func _ready() -> void:
    _populate_animation_list()
    
    if Engine.is_editor_hint():
        _in_editor_ready()
    else:
        _runtime_ready()

func _runtime_ready() -> void:
    _skin_direction_updated()
    
    var hitboxes_container := get_node_or_null(_path_hitboxes_container) as Node2D
    if hitboxes_container:
        for child in hitboxes_container.get_children():
            if child is QuiverHitBox:
                hitboxes.append(child)

func _in_editor_ready() -> void:
    set_process(false)
    set_physics_process(false)

## --- 动画可调用方法（method track 目标）---

func end_of_spell_animation(_animation_name := "") -> void:
    spell_animation_finished.emit()

func spell_hit_active() -> void:
    spell_hitbox_activated.emit()

func spell_hit_deactive() -> void:
    spell_hitbox_deactivated.emit()

func apply_spell_effect() -> void:
    spell_effect_triggered.emit()

func spawn_at_frame(marker_name: String) -> void:
    spell_spawn_requested.emit(marker_name)

func end_of_spell() -> void:
    spell_ended.emit()

## --- 虚函数 ---

func _populate_animation_list() -> void:
    pass

func _skin_direction_updated() -> void:
    pass

func _is_valid_state(anim_state: StringName) -> bool:
    var value = anim_state in _animation_list
    if not value:
        push_error("SpellSkin: %s | %s is not a valid animation state." % [name, anim_state])
    return value
```

### 4.6 SpellSkinAnimTree (extends SpellSkin)

AnimationTree 管理，复用 QuiverCharacterSkinAnimTree 的逻辑（约 60 行）。

#### AnimationTree 管理功能对照表

以下是从 QuiverCharacterSkin / QuiverCharacterSkinAnimTree 中复用的功能，以及法术系统中排除的功能：

| 功能 | 角色 | 法术 | 说明 |
|------|------|------|------|
| `transition_to()` | ✅ | ✅ | 核心：状态转换 |
| `_populate_animation_list()` | ✅ | ✅ | 递归发现动画节点 |
| `_find_all_animation_nodes_from()` | ✅ | ✅ | 递归遍历 AnimationNode 树 |
| `_handle_animation_node()` | ✅ | ✅ | 节点类型分派 |
| `_filter_main_playback_path()` | ✅ | ✅ | 路径过滤 |
| BlendSpace1D 朝向混合 | ✅ | ✅ | 法术有左右朝向 |
| `skin_direction` | ✅ | ✅ | 法术有朝向 |
| `attack_heights` | ✅ | ✅ | 法术有攻击高度层 |
| `hurtbox` 引用 | ✅ | ❌ | 法术无 HurtBox |
| `hitboxes` 引用 | ✅ | ✅ | 法术有 HitBox |
| Grab 系统 | ✅ | ❌ | 法术无抓取 |
| Custom Inspector（Grab Options） | ✅ | ❌ | 法术无抓取 |
| `physical_height` / `physical_width` | ✅ | ❌ | 法术不需要 body 碰撞 |
| `end_of_skin_animation` 防重复保护 | ✅ | ✅ | AnimationTree travel path 检查 |
| `_in_editor_ready` 编辑器保护 | ✅ | ✅ | 禁用处理 + 关闭 AnimationTree |
| `_runtime_ready` 运行时激活 | ✅ | ✅ | 激活 AnimationTree |
| `_notification(EDITOR_POST_SAVE)` | ✅ | ✅ | 编辑器保存后重新填充动画列表 |

```gdscript
class_name SpellSkinAnimTree
extends SpellSkin

@export_node_path("AnimationTree") var _path_animation_tree := ^"AnimationTree"
@export var _path_playback := "parameters/StateMachine/playback"

var _blend_positions := []

@onready var _animation_tree := get_node(_path_animation_tree) as AnimationTree
@onready var _playback := _animation_tree.get(_path_playback) as AnimationNodeStateMachinePlayback

## 状态转换
func transition_to(anim_state: StringName) -> void:
    if _is_valid_state(anim_state):
        _playback.travel(anim_state)

## 动画结束（AnimTree 防重复保护）
func end_of_spell_animation(_animation_name := "") -> void:
    if not _playback.get_travel_path().is_empty():
        return
    super()

func _populate_animation_list() -> void:
    _find_all_animation_nodes_from()
    _blend_positions = _get_blend_position_paths_from(_animation_tree)

func _skin_direction_updated() -> void:
    _update_blend_directions()

func _runtime_ready() -> void:
    super()
    _animation_tree.active = true

func _in_editor_ready() -> void:
    super()
    _animation_tree.set_deferred("active", false)

## 以下方法从 QuiverCharacterSkinAnimTree 复制（~60 行）

func _update_blend_directions() -> void:
    for path in _blend_positions:
        _animation_tree[path] = skin_direction

func _get_blend_position_paths_from(animation_tree: AnimationTree) -> Array:
    var blend_positions = []
    for property in animation_tree.get_property_list():
        if property.usage >= PROPERTY_USAGE_DEFAULT and property.name.ends_with("blend_position"):
            blend_positions.append(property.name)
    return blend_positions

func _find_all_animation_nodes_from(
        animation_node: AnimationNode = null, 
        property_path := "parameters"
) -> void:
    if property_path == "parameters":
        animation_node = _animation_tree.tree_root
    
    if animation_node == null:
        return
    
    var should_ignore_child_state_machines := true
    if animation_node is AnimationNodeStateMachine:
        should_ignore_child_state_machines = false
    
    var properties := animation_node.get_property_list()
    for property_dict in properties:
        match property_dict:
            {"hint_string": "AnimationNode", ..}:
                _handle_animation_node(
                        animation_node.get(property_dict.name), 
                        property_dict.name,
                        property_path,
                        should_ignore_child_state_machines
                )

func _handle_animation_node(
        node: AnimationNode, 
        property_name: String, 
        property_path: String,
        ignore_groups := false
) -> void:
    if node == null:
        if property_name.find("Start") == -1 and property_name.find("End") == -1:
            push_warning("%s is null" % [property_name])
        return
    
    var node_class := node.get_class()
    match node_class:
        "AnimationNodeAnimation", "AnimationNodeBlendSpace1D", \
        "AnimationNodeBlendSpace2D", "AnimationNodeBlendTree":
            var animation_name := _filter_main_playback_path(property_name, property_path) 
            _animation_list.append(animation_name)
        "AnimationNodeStateMachine":
            if not ignore_groups:
                var animation_name := _filter_main_playback_path(property_name, property_path) 
                _animation_list.append(animation_name)
            
            var parameter_name = _get_actual_parameter_name(property_name)
            property_path = property_path.path_join(parameter_name)
            _find_all_animation_nodes_from(node, property_path)
        _:
            if node is AnimationRootNode:
                push_error("Unknown animation node: %s" % [node_class])

func _filter_main_playback_path(animation_name: String, path: String) -> StringName:
    var parameter_name = _get_actual_parameter_name(animation_name)
    var full_path = path.path_join(parameter_name)
    var path_to_main_playback = _path_playback.replace("playback", "")
    var value = full_path.replace(path_to_main_playback, "") as StringName
    return value

func _get_actual_parameter_name(property_name: String) -> String:
    var parameter_name = property_name.split("/")[1]
    return parameter_name
```

---

## 五、角色集成

### 5.1 角色脚本中的法术管理

角色脚本（如 `chenjianchou.gd`）通过持有 `SpellManager` 实例来管理法术。

```gdscript
extends QuiverCharacter

var _spell_manager: SpellManager

func _ready() -> void:
    super()
    _spell_manager = SpellManager.new(self)

func _physics_process(delta: float) -> void:
    super()
    _spell_manager.tick(delta)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("spell_1"):
        _spell_manager.cast_spell_by_index(0)
    elif event.is_action_pressed("spell_2"):
        _spell_manager.cast_spell_by_index(1)
    elif event.is_action_pressed("spell_3"):
        _spell_manager.cast_spell_by_index(2)
    elif event.is_action_pressed("spell_4"):
        _spell_manager.cast_spell_by_index(3)

## 施放者死亡时解散所有召唤物
func _die() -> void:
    _spell_manager.dismiss_all_summons()

## 外部接口：学习法术
func learn_spell(spell_def: SpellDefinition) -> bool:
    return _spell_manager.learn_spell(spell_def)

## 外部接口：遗忘法术
func forget_spell(index: int) -> void:
    _spell_manager.forget_spell(index)

## 外部接口：获取法术管理器（供召唤法术子类注册召唤物）
func get_spell_manager() -> SpellManager:
    return _spell_manager
```

### 5.2 完整施放链路

```
玩家按 "1" 键
    ↓
_unhandled_input() → _spell_manager.cast_spell_by_index(0)
    ↓
SpellManager.cast_spell(slot):
    ① slot.is_empty()? → 空，return
    ② slot.is_ready()? → CD 中，return
    ③ mana_current >= mana_cost? → 不足，return
    ④ _is_state_allowed()? → 状态不允许，return
       - 黑名单检查（disallowed_states）：在列表中 → return
       - 白名单检查（allowed_states）：非空且不在列表中 → return
    ⑤ mana_current -= mana_cost
    ⑥ slot.start_cooldown()
    ⑦ spell_scene.instantiate() → SpellBase
    ⑧ _character.get_parent().add_child(spell)  ← 添加到角色的父节点（Level/Characters）
    ⑨ spell.global_position = character.global_position + spell.get_spawn_offset(dir)
    ⑩ spell.cast(caster, definition, direction)
        ↓
    SpellBase.cast():
        ① await ready（保护 @onready）
        ② 设置 caster, definition, direction
        ③ 继承 faction group → 传播到 HitBox
        ④ 设置 HitBox.character_attributes
        ⑤ 设置 Skin 朝向
        ⑥ _on_cast()（子类钩子）
        ⑦ state = ACTIVE
        ⑧ transition_to(initial_anim_state)
            ↓
    SpellBase._physics_process(delta):
        ① _elapsed_time += delta
        ② _elapsed_time >= max_lifetime → end()
        ③ _update_hitbox_layers()（复用 QuiverCharacter static 方法）
        ④ _on_active(delta)（子类钩子：运动等）
            ↓
    敌方 HurtBox 检测到法术 HitBox:
        ① _on_area_entered() → _handle_hit_box()
        ② CombatSystem.apply_damage()
        ③ CombatSystem.apply_knockback()
        ④ hit_box.owner.on_hit(self)  ← 命中通知
            ↓
    SpellBase.on_hit(hurtbox):
        ① spell_hit.emit(hurtbox)
        ② _on_hit(hurtbox)（子类钩子：爆炸/穿透计数等）
            ↓
    动画 method track 驱动:
        spell_hit_active() → gameplay 联动
        spell_hit_deactive() → gameplay 联动
        apply_spell_effect() → 子类实现效果
        end_of_spell() → end() → destroy()
```

### 5.3 法力值集成

角色的 `QuiverAttributes` 扩展了 `mana_max` / `mana_current`。
SpellManager 在施放时检查并扣除法力。法力恢复由游戏逻辑（如回蓝 Buff）单独处理。

---

## 六、动画交互设计

### 6.1 动画可调用方法（method track 目标）

| SpellSkin 方法 | 信号 | 用途 |
|---------------|------|------|
| `end_of_spell_animation()` | `spell_animation_finished` | 单个动画播放完毕 |
| `spell_hit_active()` | `spell_hitbox_activated` | 动画触发 HitBox 激活（gameplay 联动） |
| `spell_hit_deactive()` | `spell_hitbox_deactivated` | 动画触发 HitBox 停用 |
| `apply_spell_effect()` | `spell_effect_triggered` | 动画触发法术效果 |
| `spawn_at_frame(marker)` | `spell_spawn_requested` | 动画触发生成子效果 |
| `end_of_spell()` | `spell_ended` | 动画请求结束整个法术 |

### 6.2 信号流向

```
AnimationPlayer method track
    ↓
SpellSkin 方法调用
    ↓
SpellSkin 信号 emit
    ↓
SpellBase 信号处理器
    ↓
SpellBase 行为响应
```

### 6.3 角色动画交互参考（对比分析）

角色系统中动画驱动行为的完整链路（以 attack1_right.tres 为例）：

```
AnimationPlayer method track (path=".")
    ↓ t=0.208s
Skin.end_of_input_frames()
    ↓ emit signal
attack_input_frames_finished
    ↓ connected in QuiverActionAttack._connect_signals()
_on_attack_input_frames_finished()
    ↓
_state_machine.transition_to(next_state)
```

| 时间 | Method | 效果 |
|------|--------|------|
| 0.208s | `end_of_input_frames()` | 关闭连击输入窗口 |
| 0.333s | `end_of_skin_animation()` | 动画结束，触发状态转换 |

HitBox 碰撞时序（Attack1Shape:disabled track）：

| 时间 | disabled | 含义 |
|------|----------|------|
| 0.000s | true | 未激活 |
| 0.042s | false | 激活（伤害窗口开始） |
| 0.125s | true | 停用（伤害窗口结束） |

法术系统采用完全相同的模式：method track → SpellSkin 方法 → 信号 → SpellBase 响应。

### 6.4 各类型法术的动画交互示例

#### 弹道攻击法术（fire_ball）

```
动画: fire_ball_active (3 帧, 0.125s)
  帧 0 (t=0.000): AnimatedSprite2D:animation = "fire_ball"
  帧 1 (t=0.042): METHOD: spell_hit_active()     ← HitBox 激活
  帧 2 (t=0.083): METHOD: spell_hit_deactive()   ← HitBox 停用
  帧 2 (t=0.125): METHOD: end_of_spell_animation() ← 动画结束

动画: fire_ball_hit (2 帧, 0.083s)  ← 命中后播放
  帧 0 (t=0.000): AnimatedSprite2D:animation = "fire_ball_explode"
  帧 1 (t=0.042): METHOD: apply_spell_effect()   ← 爆炸效果
  帧 1 (t=0.083): METHOD: end_of_spell()          ← 法术结束 → destroy()
```

#### 范围持续法术（fire_wall）

```
动画: fire_wall_loop (6 帧, 0.25s, loop=true)
  帧 0 (t=0.000): METHOD: spell_hit_active()      ← 每循环开始激活
  帧 3 (t=0.125): METHOD: spell_hit_deactive()     ← 每循环中间停用
  帧 5 (t=0.250): METHOD: end_of_spell_animation() ← 循环结束

动画: fire_wall_end (2 帧, 0.083s)  ← 持续时间到后播放
  帧 1 (t=0.083): METHOD: end_of_spell()
```

#### 治疗法术（heal）

```
动画: heal_cast (4 帧, 0.167s)
  帧 0 (t=0.000): AnimatedSprite2D:animation = "heal"
  帧 2 (t=0.083): METHOD: apply_spell_effect()    ← 此刻回血
  帧 3 (t=0.167): METHOD: end_of_spell()           ← 法术结束
```

---

## 七、战斗系统集成

### 7.1 标准 Quiver 战斗管道

法术参与战斗的方式与角色完全一致：

```
法术 HitBox (monitoring=false, monitorable=true)
    ↓ 物理引擎检测
敌人 HurtBox (monitoring=true, monitorable=false)
    ↓ _on_area_entered()
    ↓ are_factions_equal() → 不同阵营
    ↓ _handle_hit_box()
    ↓ CombatSystem.apply_damage(attack_data, target_attributes)
    ↓ CombatSystem.apply_knockback(knockback_data, target_attributes)
    ↓ 目标 hurt_requested / knockout_requested 信号
```

### 7.2 阵营过滤

- 法术继承施放者的 `area2d:` group
- `QuiverHurtBox.are_factions_equal()` 自动过滤同阵营

### 7.3 命中通知（hit notification）

标准 Quiver 战斗流程中，HitBox 是 passive（monitoring=false, monitorable=true），
碰撞检测由敌方 HurtBox 完成。法术（攻击方）通过以下机制感知命中：

**机制**：QuiverHurtBox 在 `_handle_hit_box()` 中完成伤害计算后，
通过 `hit_box.owner` 找到法术实例，调用 `on_hit()` 方法。

**修改点**（QuiverHurtBox._handle_hit_box，新增 3 行）：

```gdscript
func _handle_hit_box(hit_box: QuiverHitBox) -> void:
    if _can_be_attacked_by(hit_box.character_attributes):
        CombatSystem.apply_damage(hit_box.attack_data, character_attributes)
        var knockback = QuiverKnockbackData.new(...)
        CombatSystem.apply_knockback(knockback, character_attributes)
        
        # 新增：通过 owner 通知法术命中
        var spell = hit_box.owner
        if spell and spell is SpellBase and spell.has_method("on_hit"):
            spell.on_hit(self)
```

**为什么使用 `hit_box.owner`**：
- Godot 场景实例化时自动设置 `owner` 为场景根节点
- 法术 .tscn 的根节点就是 SpellBase，所以 `hit_box.owner` = SpellBase 实例
- 不需要修改 QuiverHitBox（不添加任何属性）
- 不需要信号机制（直接方法调用）
- 非 SpellBase 的 HitBox（如角色攻击）没有 `on_hit` 方法，自动跳过

**完整命中流程**：

```
法术 HitBox (monitoring=false, monitorable=true)
    ↓ 物理引擎检测
敌人 HurtBox (monitoring=true, monitorable=false)
    ↓ _on_area_entered()
    ↓ are_factions_equal() → 不同阵营
    ↓ _handle_hit_box()
    ↓ CombatSystem.apply_damage()     # HP 已扣
    ↓ CombatSystem.apply_knockback()  # 击退已应用
    ↓ hit_box.owner.on_hit(self)      # 通知法术命中
        ↓
    SpellBase.on_hit(hurtbox)
        ↓ spell_hit.emit(hurtbox)     # 信号（可选监听）
        ↓ _on_hit(hurtbox)            # 子类钩子
            → fire_ball: 播放爆炸动画 → end() → destroy()
            → piercing_projectile: 计数，达到上限才销毁
```

**queue_free 安全性**：`queue_free()` 是延迟删除（当前帧结束时），不会中断当前信号链。
`apply_knockback` 操作的是目标的 attributes，不依赖 HitBox 存在，
所以 HitBox 在同一帧被删除是安全的。

---

## 八、轮廓转换工具集成

### 8.1 复用策略

- 法术 Widget 调用 `AnimationTrackInjector.convert_attack_contours()`
- 与角色 attack 转换**零区分**
- 法术 Widget 隐藏 body 转换按钮

### 8.2 技术分析：为什么可以零修改复用

通过分析 `AnimationTrackInjector` 源码确认：

1. **`convert_attack_contours()` 不检查 skin 节点类型**
   - 方法签名：`func convert_attack_contours(skin_node: Node, ...)` — 参数类型是 `Node`，不是 `QuiverCharacterSkinAnimTree`
   - 内部调用 `_convert_contours_common()`，同样接受 `Node` 类型

2. **`_discover_from_scene_tree()` 使用硬编码路径**
   - Body 通道：`skin_node.get_node_or_null("AnimatedSprite2D/HurtBox")` — 法术无此节点，返回 null，跳过
   - Attack 通道：`skin_node.get_node_or_null("Attacks")` — 法术有此节点，正常工作

3. **子节点类型检查使用 Godot 基础类**
   - `child is Area2D` — 不依赖 Quiver 特定类
   - `child is CollisionShape2D or child is CollisionPolygon2D` — 标准 Godot 类

4. **`_validate_and_set_root_node()` 只在 `run()` / `run_incremental()` 中调用**
   - 这是文件名扫描管道的验证，检查 `QuiverCharacterSkin` 类型
   - `convert_attack_contours()` 不调用此方法

**结论**：`convert_attack_contours()` 与 `QuiverCharacterSkinAnimTree` 完全解耦，只要场景树结构匹配（有 `AnimatedSprite2D`、`AnimationPlayer`、`Attacks/` 节点），任何 Node 都可以作为 skin_node 传入。

### 8.3 法术 Widget 触发机制

```gdscript
# spell_contour/inspector_plugin.gd
func _can_handle(object: Object) -> bool:
    if object is Node and object.get_script():
        var script = object.get_script()
        if script and script.get_global_name() == "SpellSkinAnimTree":
            return true
    if object is SpellSkinAnimTree:
        return true
    return false
```

### 8.4 注入的 tracks

法术 attack 转换注入的 tracks（与角色 attack 一致）：

| Track 路径 | 类型 | 说明 |
|-----------|------|------|
| `Attacks/Attack1/Attack1Shape:polygon` | value | 碰撞形状（Polygon 模式） |
| `Attacks/Attack1/Attack1Shape:shape:radius` | value | 碰撞形状（Capsule 模式） |
| `Attacks/Attack1/Attack1Shape:shape:height` | value | 碰撞形状（Capsule 模式） |
| `Attacks/Attack1/Attack1Shape:position` | value | HitBox 位置 |
| `Attacks/Attack1/Attack1Shape:rotation` | value | HitBox 旋转 |
| `Attacks/Attack1:visible` | value | HitBox Area2D 可见性 |
| `.:attack_heights` | value | 攻击高度层 |

**不注入**：`physical_height` / `physical_width`（法术不需要）

---

## 九、模板创建系统

### 9.1 法术模板目录结构

模板中只包含**静态文件**。动画相关文件（animation_tree_root.tres、各动画 .tres）
由 `spell_creator.gd` 在创建法术时**程序化生成**，不放入模板。

**原因**：动画 .tres 文件中的 `ext_resource` 引用路径包含 `__CLASS__`（PascalCase 类名），
而 AnimationNodeBlendTree 内部使用 `&"__CLASS__/active_right"` 格式引用动画。
如果在模板中硬编码这些引用，占位符替换时需要处理 .tres 文件内部的嵌套字符串，
容易出错。程序化生成可以在创建时直接写入正确的路径，避免替换错误。

```
spells/_template/
├── spell_template.tscn          # Inspector 触发器（class_name SpellTemplate）
├── spell_template.gd            # @tool extends Node, class_name SpellTemplate
├── __NAME__.tscn                # 法术主场景（Area2D 根节点，详见 9.4）
├── __NAME__.gd                  # extends SpellBase
├── __NAME___skin.tscn           # 法术 skin（继承 spell_skin_base.tscn，详见 9.5）
├── __NAME___skin.gd             # extends SpellSkinAnimTree
├── README.md                    # 模板使用说明
└── resources/
    ├── __NAME___definition.tres # SpellDefinition 占位（详见 9.6）
    ├── spriteframes___NAME__.tres # SpriteFrames（1 个 active 动画，详见 9.8）
    ├── anim_library___NAME__.tres # AnimationLibrary 占位（详见 9.9）
    ├── attacks/
    │   └── __NAME___attack_data.tres # QuiverAttackData 占位（详见 9.7）
    ├── sprites/
    │   └── placeholder.png      # 占位 PNG
    └── animations/
        ├── animation_tree_root.tres # AnimationNodeBlendTree（详见 9.9）
        ├── RESET.tres               # 重置动画
        ├── active_right.tres        # active 右朝向动画
        └── active_left.tres         # active 左朝向动画
```

#### 9.1.1 EXCLUDED_FILES 列表

`spell_creator.gd` 复制模板时排除以下文件（不复制到新法术目录）：

```gdscript
const EXCLUDED_FILES = [
    "spell_template.tscn",
    "spell_template.gd",
    "spell_template.gd.uid",
    "README.md",
]
```

**排除理由**：
- `spell_template.tscn/gd`：Inspector 触发器，只在模板目录中有意义
- `.uid` 文件：Godot 自动生成 UID 缓存文件，复制会导致 UID 重复警告
- `README.md`：模板文档，不属于新法术

#### 9.1.2 程序化生成的文件

以下文件在模板中包含**有效的占位符版本**（确保 Godot 可以加载模板场景不报错），
但 `spell_creator.gd` 在创建新法术时会**覆盖**这些文件，生成与法术名称匹配的最终版本：

| 文件 | 生成方式 | 说明 |
|------|---------|------|
| `resources/animations/animation_tree_root.tres` | `_generate_animation_tree()` | AnimationNodeBlendTree + AnimationNodeStateMachine |
| `resources/animations/RESET.tres` | `_generate_reset_animation()` | 重置动画（恢复默认状态） |
| `resources/animations/active_right.tres` | `_generate_active_animation()` | active 状态动画（右朝向） |
| `resources/animations/active_left.tres` | `_generate_active_animation()` | active 状态动画（左朝向，metadata 镜像） |
| `resources/anim_library___NAME__.tres` | `_generate_animation_library()` | AnimationLibrary，引用上述动画文件 |

### 9.2 占位符

| Token | 替换为 | 出现位置 |
|-------|--------|---------|
| `__NAME__` | spell_name (snake_case) | 文件路径、group 名、资源路径 |
| `__CLASS__` | PascalName (PascalCase) | 节点名、脚本 class 引用 |
| `__DISPLAY_NAME__` | 中文显示名 | SpellDefinition.display_name |

**为什么只有 3 个 token（角色模板有 8 个）**：
- 角色模板的 `__FACTION__`、`__MOVE_SPEED__` 等 token 用于 QuiverAttributes 的初始值
- 法术的 SpellDefinition 不需要这些属性，`mana_cost`/`cooldown`/`max_lifetime` 使用默认值（0.0/0.0/5.0），用户在 Inspector 中调整
- `icon` 和 `spell_scene` 初始为 null，用户在 Inspector 中手动设置

### 9.3 法术创建 Inspector

```
插件层（addons/quiver.beat_em_up/custom_inspectors/create_new_spell/）:
  inspector_plugin.gd          — _can_handle: SpellTemplate class_name
  create_new_spell_widget.gd   — UI（创建/删除/测试）
  create_new_spell_widget.tscn
  spell_creator.gd             — 5 步管道（复制→重命名→替换→生成动画→扫描）
  spell_deleter.gd             — 递归删除
```

#### spell_creator.gd 5 步管道

与角色创建器（CharacterCreator）的 4 步管道相比，新增第 5 步动画生成：

```
Step 1: DirAccess.make_dir_recursive_absolute(target_dir)
  → 创建 res://spells/<spell_name>/

Step 2: _copy_directory_recursive(TEMPLATE_DIR, target_dir)
  → 复制模板目录（排除 EXCLUDED_FILES）
  → 二进制文件（.png）: 原始字节复制
  → 文本文件（.gd, .tscn, .tres）: 文本复制

Step 3: _rename_files_recursive(target_dir, spell_name)
  → 将文件名中的 __NAME__ 替换为 spell_name
  → 例：__NAME__.tscn → fire_ball.tscn

Step 4: _replace_placeholders_recursive(target_dir, spell_name, pascal_name, display_name)
  → 在所有 .gd/.tscn/.tres 文件中替换 3 个 token
  → __NAME__ → fire_ball, __CLASS__ → FireBall, __DISPLAY_NAME__ → 火球术

Step 5: _generate_animation_files(target_dir, pascal_name)
  → 程序化生成动画相关文件（详见 9.9）
  → 生成 animation_tree_root.tres, RESET.tres, active_right.tres, active_left.tres, anim_library.tres
```

#### spell_deleter.gd

与 CharacterDeleter 逻辑一致：
- 拒绝删除 `_template`、`.`、`..`
- 递归删除法术目录及其所有文件
- 返回 true/false

### 9.4 法术主场景 __NAME__.tscn（精确格式）

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://spells/__NAME__/__NAME__.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://spells/__NAME__/__NAME___skin.tscn" id="2_skin"]

[node name="__CLASS__" type="Area2D"]
script = ExtResource("1_script")
_path_skin = NodePath("__CLASS__Skin")

[node name="__CLASS__Skin" parent="." index="0" instance=ExtResource("2_skin")]
```

**与角色模板 __NAME__.tscn 的关键差异**：
- 根节点是 `Area2D`（角色模板继承 `quiver_character_base.tscn` 的 CharacterBody2D）
- 无 StateMachine（法术生命周期由 SpellBase 代码管理，不是 Quiver 状态机）
- 无 Collision 子节点（法术本身不需要物理碰撞体）
- 只有 2 个 ext_resource（极简）
- 不设置 `_attributes`（SpellBase 通过 cast() 接收施放者属性）
- 不设置 `_path_hitboxes_container`（HitBox 通过 `_skin.hitboxes` 访问，遵循角色系统模式）

### 9.5 法术 skin 场景 __NAME___skin.tscn（精确格式）

```
[gd_scene load_steps=8 format=3]

[ext_resource type="PackedScene" path="res://spells/_base/spell_skin_base.tscn" id="1_base"]
[ext_resource type="AnimationLibrary" path="res://spells/__NAME__/resources/anim_library___NAME__.tres" id="2_animlib"]
[ext_resource type="AnimationNodeBlendTree" path="res://spells/__NAME__/resources/animations/animation_tree_root.tres" id="3_tree"]
[ext_resource type="SpriteFrames" path="res://spells/__NAME__/resources/spriteframes___NAME__.tres" id="4_sprites"]
[ext_resource type="Script" path="res://addons/quiver.beat_em_up/combat/collision_areas/quiver_hit_box.gd" id="5_hitbox"]
[ext_resource type="Resource" path="res://spells/__NAME__/resources/attacks/__NAME___attack_data.tres" id="6_attack"]
[ext_resource type="Animation" path="res://spells/__NAME__/resources/animations/RESET.tres" id="7_reset"]
[ext_resource type="Script" path="res://spells/__NAME__/__NAME___skin.gd" id="8_script"]

[sub_resource type="AnimationLibrary" id="AnimationLibrary_reset"]
_data = {
&"RESET": ExtResource("7_reset")
}

[sub_resource type="RectangleShape2D" id="RectShape_attack1"]
size = Vector2(80, 80)

[node name="__CLASS__Skin" instance=ExtResource("1_base")]
script = ExtResource("8_script")
_path_playback = "parameters/state_machine/playback"

[node name="AnimationPlayer" parent="." index="0"]
callback_mode_process = 0
libraries/ = SubResource("AnimationLibrary_reset")
libraries/__CLASS__ = ExtResource("2_animlib")

[node name="AnimationTree" parent="." index="1"]
active = false
callback_mode_process = 0
tree_root = ExtResource("3_tree")
parameters/state_machine/active/blend_position = 1.0

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="." index="2"]
position = Vector2(0, -80)
sprite_frames = ExtResource("4_sprites")
animation = &"active"

[node name="Attack1" type="Area2D" parent="Attacks" index="0" groups=["area2d:__NAME__"]]
visible = false
modulate = Color(1, 0.2, 0.101961, 1)
monitoring = false
script = ExtResource("5_hitbox")
attack_data = ExtResource("6_attack")

[node name="Attack1Shape" type="CollisionShape2D" parent="Attacks/Attack1" index="0"]
modulate = Color(1, 0.2, 0.101961, 1)
shape = SubResource("RectShape_attack1")
disabled = true
```

**与角色模板 __NAME___skin.tscn 的关键差异**：
- 继承 `spell_skin_base.tscn`（不是 `quiver_character_skin_base.tscn`）
- `Attacks` 节点由 base 场景提供，不在此文件中重新定义（否则会创建 `Attacks2` 重复节点）
- 无 `attributes` 属性（SpellSkin 不继承 QuiverCharacterSkin，无此 export）
- 无 `_has_grab` / `_has_grabbed` 属性
- 无 `HurtBox` 节点（法术不被攻击）
- 只有 1 个 Attack（Attack1），不是 4 个
- `_path_playback` 覆盖为小写 `"parameters/state_machine/playback"`（与动画树内部节点名一致）
- 无 `metadata/_edit_*_guides_`（编辑器辅助线，用户自行添加）
- 无 `unique_id`（Godot 编辑器自动生成）

### 9.6 SpellDefinition 占位资源 __NAME___definition.tres（精确格式）

```
[gd_resource type="Resource" script_class="SpellDefinition" load_steps=2 format=3]

[ext_resource type="Script" path="res://spells/_base/spell_definition.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
spell_id = &"__NAME__"
display_name = "__DISPLAY_NAME__"
description = ""
mana_cost = 0.0
max_lifetime = 5.0
cooldown = 0.0
```

**说明**：
- `icon`（Texture2D）和 `spell_scene`（PackedScene）初始为 null，用户在 Godot Inspector 中手动设置
- `mana_cost` / `cooldown` 默认 0.0（免费、无 CD），用户在 Inspector 中调整
- `allowed_states` 和 `disallowed_states` 使用 GDScript 代码中的默认值，不在 .tres 中显式设置

### 9.7 QuiverAttackData 占位资源 __NAME___attack_data.tres（精确格式）

```
[gd_resource type="Resource" load_steps=2 format=3]

[ext_resource type="Script" path="res://addons/quiver.beat_em_up/combat/quiver_attack_data.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
attack_damage = 10.0
hurt_type = 1
knockback = 1
launch_angle = 15
```

与角色模板的 `punch1_attack_data.tres` 格式一致。用户在 Inspector 中调整伤害值。

### 9.8 SpriteFrames 占位资源 spriteframes___NAME__.tres（精确格式）

1 个动画类别（`active`），2 帧，使用同一个占位 PNG：

```
[gd_resource type="SpriteFrames" load_steps=2 format=3]

[ext_resource type="Texture2D" path="res://spells/__NAME__/resources/sprites/placeholder.png" id="1_placeholder"]

[resource]
animations = [{
"frames": [{
"duration": 1.0,
"texture": ExtResource("1_placeholder")
}, {
"duration": 1.0,
"texture": ExtResource("1_placeholder")
}],
"loop": false,
"name": &"active",
"speed": 24.0
}]
```

**说明**：
- 只有 1 个动画 `active`（用户后续添加更多动画类别）
- 2 帧使用同一个 `placeholder.png`（64×64 纯色方块）
- `speed = 24.0`（与角色模板一致，24fps）
- 用户替换 sprite PNG 后，在 SpriteFrames 编辑器中重新配置帧

### 9.9 程序化生成动画文件

`spell_creator.gd` 的 `_generate_animation_files(target_dir, pascal_name)` 方法生成以下 5 个文件：

#### animation_tree_root.tres

最简 AnimationNodeBlendTree 结构：

```
AnimationNodeBlendTree (root)
├── time_scale (AnimationNodeTimeScale)
└── state_machine (AnimationNodeStateMachine)
    ├── Start → active (transition)
    └── active → BlendSpace1D
        ├── active_right (AnimationNodeAnimation, blend=+0.1)
        └── active_left (AnimationNodeAnimation, blend=-0.1)
```

生成的 .tres 包含：
- 2 个 `AnimationNodeAnimation` sub_resource（引用 `&"<pascal_name>/active_right"` 和 `&"<pascal_name>/active_left"`）
- 1 个 `AnimationNodeBlendSpace1D` sub_resource（active 状态）
- 1 个 `AnimationNodeStateMachineTransition` sub_resource（Start → active）
- 1 个 `AnimationNodeStateMachine` sub_resource（包含 active 状态和 Start → active 转换）
- 1 个 `AnimationNodeTimeScale` sub_resource
- root resource 连接 output → time_scale → state_machine

#### RESET.tres

重置动画（恢复默认状态），tracks：
- `AnimatedSprite2D:frame` → 0
- `AnimatedSprite2D:animation` → `&"active"`
- `AnimatedSprite2D:flip_h` → false
- `AnimatedSprite2D:modulate` → Color(1,1,1,1)
- `Attacks/Attack1:visible` → false
- `Attacks/Attack1/Attack1Shape:disabled` → true

#### active_right.tres

active 状态动画（右朝向），tracks：
- `AnimatedSprite2D:position` → Vector2(0, -80)
- `AnimatedSprite2D:frame` → 0（第 1 帧）
- `AnimatedSprite2D:animation` → `&"active"`
- `AnimatedSprite2D:flip_h` → false
- **method track** (path="."):
  - t=0.083s: `end_of_spell_animation()`
- `Attacks/Attack1/Attack1Shape:disabled` → true（默认关闭，用户修改为实际时序）
- `Attacks/Attack1:visible` → false（默认隐藏）

末尾 metadata：
```
metadata/mirrored_name = "active_left.tres"
metadata/should_overwrite = true
```

#### active_left.tres

与 active_right.tres 结构一致，差异：
- `AnimatedSprite2D:flip_h` → true
- `metadata/mirrored_name = "active_right.tres"`

#### anim_library___NAME__.tres

AnimationLibrary，引用上述 4 个动画文件 + RESET：

```
[gd_resource type="AnimationLibrary" load_steps=5 format=3]

[ext_resource type="Animation" path="res://spells/<name>/resources/animations/active_right.tres" id="1"]
[ext_resource type="Animation" path="res://spells/<name>/resources/animations/active_left.tres" id="2"]

[resource]
_data = {
"active_left": ExtResource("2"),
"active_right": ExtResource("1")
}
```

注意：RESET 动画不在 AnimationLibrary 中，而是通过 `__NAME___skin.tscn` 的
`AnimationPlayer.libraries/` 内联 AnimationLibrary sub_resource 引用。

---

## 十、基础场景结构

### 10.1 spell_skin_base.tscn（精确格式）

与 `quiver_character_skin_base.tscn` 结构一致，提供 AnimationPlayer + AnimationTree 基础节点：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://spells/_base/spell_skin_anim_tree.gd" id="1_script"]

[node name="SpellSkinBase" type="Node2D"]
script = ExtResource("1_script")

[node name="AnimationPlayer" type="AnimationPlayer" parent="."]

[node name="AnimationTree" type="AnimationTree" parent="."]
anim_player = NodePath("../AnimationPlayer")
```

**与 quiver_character_skin_base.tscn 的差异**：
- 脚本路径指向 `spells/_base/spell_skin_anim_tree.gd`（不是插件内的 `quiver_character_skin_anim_tree.gd`）
- 无 `has_grab` / `has_grabbed` 属性（SpellSkin 不需要抓取系统）
- 根节点名为 `SpellSkinBase`（不是 `CharacterSkinBase`）
- 无 `uid`（Godot 自动生成）

### 10.2 法术主场景（__NAME__.tscn）

树形结构概览：

```
__CLASS__ (Area2D)  ← script: __NAME__.gd
├── __CLASS__Skin (Node2D)  ← instance of __NAME___skin.tscn
│   ├── AnimationPlayer
│   ├── AnimationTree
│   ├── AnimatedSprite2D
│   └── Attacks (Node2D)
│       └── Attack1 (Area2D)  ← QuiverHitBox script
│           └── Attack1Shape (CollisionShape2D)
```

精确 .tscn 格式详见 9.4 节。

---

## 十一、修改插件清单

### 11.1 QuiverAttributes 扩展

**文件**：`addons/quiver.beat_em_up/characters/quiver_attributes.gd`

**新增属性**：

```gdscript
## 法力值上限
@export var mana_max: float = 100.0

## 当前法力值
var mana_current: float = 100.0:
    set(value):
        mana_current = clampf(value, 0.0, mana_max)
        mana_changed.emit()
        if mana_current <= 0.0:
            mana_depleted.emit()

signal mana_changed
signal mana_depleted
```

**新增 Modifier 系统**：

Modifier 系统允许 Buff/Debuff 法术动态修改角色属性。采用方式 B：添加/移除时直接修改属性值。

```gdscript
## Modifier 记录（内部使用）
## 每个 modifier 记录：id、属性名、修改类型、修改值、来源、修改前的 base_value
var _modifier_records: Array[Dictionary] = []

## 添加属性修改器
func add_modifier(mod_id: StringName, attribute: StringName, type: String, value: float, source: Node = null) -> void:
    # 记录修改前的 base_value
    var base_value: float = get(attribute)
    _modifier_records.append({
        "id": mod_id,
        "attribute": attribute,
        "type": type,
        "value": value,
        "source": source,
        "base_value": base_value,
    })
    # 直接修改属性值
    if type == "add":
        set(attribute, base_value + value)
    elif type == "multiply":
        set(attribute, base_value * value)

## 移除指定 id 的属性修改器（恢复 base_value）
func remove_modifier(mod_id: StringName) -> void:
    for i in range(_modifier_records.size() - 1, -1, -1):
        if _modifier_records[i]["id"] == mod_id:
            var record: Dictionary = _modifier_records[i]
            set(record["attribute"], record["base_value"])
            _modifier_records.remove_at(i)
            break  # 只移除最后一个匹配的

## 移除指定来源的所有修改器
func remove_modifiers_from_source(source: Node) -> void:
    for i in range(_modifier_records.size() - 1, -1, -1):
        if _modifier_records[i]["source"] == source:
            var record: Dictionary = _modifier_records[i]
            set(record["attribute"], record["base_value"])
            _modifier_records.remove_at(i)
```

**安全属性列表**（可直接通过 Modifier 修改，无副作用）：

| 属性 | 类型 | 说明 |
|------|------|------|
| `move_speed` | int | 移动速度 |
| `air_control` | float | 空中控制 |
| `jump_force` | int | 跳跃力 |
| `knockback_weight` | float | 击退权重 |
| `hit_lane_offset` | int | 攻击范围偏移 |
| `health_max` | int | 最大生命值 |
| `can_be_grabbed` | bool | 是否可被抓取 |

**需谨慎使用的属性**：

| 属性 | 风险 | 建议 |
|------|------|------|
| `health_current` | setter 有 clamp + 信号发射 + 死亡触发 | 不要直接修改，改用 `health_max` |
| `is_invulnerable` | setter 会 reset_knockback | 可接受，文档说明副作用 |
| `has_superarmor` | setter 会 reset_knockback | 可接受，文档说明副作用 |

### 11.2 QuiverCharacter 新增 public static 方法

**文件**：`addons/quiver.beat_em_up/characters/quiver_character.gd`

**新增 3 个 public static 方法**（供 SpellBase 复用高度层计算）：

```gdscript
## 高度值转层号（public static，供外部调用）
static func height_to_layer(height: float, height_definitions: Array) -> int:
    for def in height_definitions:
        if height > def["min"] and height <= def["max"]:
            return def["layer"]
    return HEIGHT_LAYER_FIRST

## 层号数组转 bitmask（public static，供外部调用）
static func layers_to_bitmask(layers: Array) -> int:
    var mask := 0
    for layer in layers:
        mask |= (1 << (layer - 1))
    return mask

## 获取高度层定义（public static，供外部调用）
static func get_height_definitions() -> Array:
    return _build_height_definitions()
```

**理由**：SpellBase 需要计算 HitBox 高度层碰撞。原 `_height_to_layer()` 和 `_layers_to_bitmask()` 
是 private instance 方法，SpellBase 无法调用。通过新增 public static 方法复用，
避免在 SpellBase 中重写 bitmask 计算逻辑（之前重写出过 bug）。

### 11.3 QuiverHurtBox 命中通知

**文件**：`addons/quiver.beat_em_up/combat/collision_areas/quiver_hurt_box.gd`

**修改 `_handle_hit_box()`**，在 `CombatSystem.apply_knockback()` 后新增 3 行：

```gdscript
# 新增：通过 owner 通知法术命中
var spell = hit_box.owner
if spell and spell is SpellBase and spell.has_method("on_hit"):
    spell.on_hit(self)
```

**理由**：标准战斗流程中 HitBox 是 passive，不会触发 area_entered。
法术（攻击方）无法通过信号感知命中。通过 `hit_box.owner` 找到法术实例并调用 `on_hit()`，
是最小化修改方案（不修改 QuiverHitBox，HurtBox 只加 3 行代码）。

### 11.4 法术创建 Inspector（新增）

```
addons/quiver.beat_em_up/custom_inspectors/create_new_spell/
├── inspector_plugin.gd
├── create_new_spell_widget.gd
├── create_new_spell_widget.tscn
├── spell_creator.gd
└── spell_deleter.gd
```

### 11.5 法术轮廓 Widget（新增）

```
addons/quiver.beat_em_up/custom_inspectors/spell_contour/
├── inspector_plugin.gd
├── spell_contour_widget.gd
└── spell_contour_widget.tscn
```

---

## 十二、法术子类示例

### 12.1 弹道攻击法术（fire_ball.gd）

```gdscript
extends SpellBase

## 飞行速度（像素/秒）
@export var speed: float = 400.0

func _on_active(delta: float) -> void:
    # 直线飞行
    position += direction * speed * delta

func _on_hit(hurtbox: QuiverHurtBox) -> void:
    # 命中后播放爆炸动画（由 HurtBox 通过 hit_box.owner 调用）
    if _skin and _skin._is_valid_state(&"hit"):
        _skin.transition_to(&"hit")
    else:
        destroy()

func _on_skin_effect_triggered() -> void:
    # 爆炸效果（由 hit 动画的 apply_spell_effect method track 触发）
    # 例如：生成范围伤害、粒子效果
    pass

func _on_skin_spell_ended() -> void:
    # 爆炸动画播完后销毁
    destroy()
```

### 12.2 范围持续法术（fire_wall.gd）

```gdscript
extends SpellBase

func _on_active(delta: float) -> void:
    # 不移动，固定位置
    pass

func _on_skin_hitbox_activated() -> void:
    # 启用 HitBox（由动画 method track 周期性触发）
    super()  # 默认行为：启用 CollisionShape

func _on_skin_hitbox_deactivated() -> void:
    # 禁用 HitBox
    super()  # 默认行为：禁用 CollisionShape
```

### 12.3 治疗法术（heal.gd）

```gdscript
extends SpellBase

## 治疗量
@export var heal_amount: int = 30

## 治疗目标（施放时设定）
var target: Node = null

func _on_cast() -> void:
    # 治疗法术不飞行，附着在目标身上
    if target:
        target.add_child(self)
        position = Vector2.ZERO

func _on_active(delta: float) -> void:
    # 不移动
    pass

func _on_skin_effect_triggered() -> void:
    # 回血（由动画 method track 在指定帧触发）
    if target and target.get("attributes"):
        target.attributes.health_current += heal_amount

func _on_skin_spell_ended() -> void:
    destroy()
```

### 12.4 Buff 法术（iron_wall.gd）

```gdscript
extends SpellBase

## 防御力加成倍数
@export var defense_bonus: float = 1.5

## 目标
var target: Node = null

func _on_cast() -> void:
    # 附着在目标身上
    if target:
        target.add_child(self)
        position = Vector2(0, -50)  # 头顶偏移

func _on_active(delta: float) -> void:
    # 跟随目标（add_child 自动跟随，无需手动）
    pass

func _on_skin_effect_triggered() -> void:
    # Buff 生效（由动画 method track 触发）
    if target and target.get("attributes"):
        target.attributes.add_modifier(
            &"iron_wall",         # modifier id
            &"move_speed",        # 目标属性
            "multiply",           # 修改类型
            defense_bonus,        # 修改值
            self                  # 来源
        )

func _on_ending() -> void:
    # Buff 失效，移除 modifier
    if target and target.get("attributes"):
        target.attributes.remove_modifiers_from_source(self)
```

### 12.5 功能法术（invisibility.gd）

```gdscript
extends SpellBase

func _on_cast() -> void:
    # 附着在施放者身上
    if caster:
        caster.add_child(self)
        position = Vector2.ZERO
    # 设置隐身效果
    if caster and caster.get_node_or_null("Skin"):
        caster.get_node("Skin").modulate.a = 0.3

func _on_active(delta: float) -> void:
    # 跟随施放者（add_child 自动跟随）
    pass

func _on_ending() -> void:
    # 恢复可见性
    if caster and caster.get_node_or_null("Skin"):
        caster.get_node("Skin").modulate.a = 1.0
```

### 12.6 召唤法术（summon_beast.gd）

```gdscript
extends SpellBase

## 召唤物场景
@export var creature_scene: PackedScene

var _summoned_creature: Node = null

func _on_active(delta: float) -> void:
    # 不移动，停留在施放位置
    pass

func _on_skin_effect_triggered() -> void:
    # 创建召唤物（由动画 method track 在指定帧触发）
    if creature_scene == null:
        return
    
    _summoned_creature = creature_scene.instantiate()
    _summoned_creature.global_position = global_position
    
    # 继承阵营
    if caster:
        for group in caster.get_groups():
            if group.begins_with("area2d:"):
                _summoned_creature.add_to_group(group)
    
    # 召唤物添加到施放者的父节点（Level/Characters），与角色同一层级
    if caster:
        caster.get_parent().add_child(_summoned_creature)
    else:
        get_tree().current_scene.add_child(_summoned_creature)
    
    # 注册到施放者的 SpellManager（施放者死亡时自动解散）
    if caster and caster.has_method("get_spell_manager"):
        caster.get_spell_manager().register_summon(_summoned_creature)
```

**召唤物脚本**（summoned_creature.gd）：

```gdscript
extends QuiverEnemyCharacter

## 召唤物存活时间（秒，0 = 永久）
@export var summon_duration: float = 30.0

var _elapsed: float = 0.0

func _physics_process(delta: float) -> void:
    super(delta)
    if summon_duration > 0:
        _elapsed += delta
        if _elapsed >= summon_duration:
            queue_free()
```

### 12.7 穿透弹道法术（piercing_projectile.gd）

```gdscript
extends SpellBase

## 飞行速度
@export var speed: float = 600.0

## 最大穿透次数
@export var max_hits: int = 3

var _hit_count: int = 0

func _on_active(delta: float) -> void:
    position += direction * speed * delta

func _on_hit(hurtbox: QuiverHurtBox) -> void:
    _hit_count += 1
    if _hit_count >= max_hits:
        end()  # 穿透次数用完，销毁

func get_spawn_offset(direction: Vector2) -> Vector2:
    # 从施放者前方较远处发射
    var base := super.get_spawn_offset(direction)
    return base + Vector2(20.0 * direction.x, 0.0)
```

---

## 十三、Buff/Debuff 附着机制

### 13.1 附着方式

Buff 法术的 SpellBase 通过 `target.add_child(self)` 附着到目标身上。

**选择 add_child 的理由**：
- 自动跟随目标移动（无需手动更新 position）
- 目标销毁时 Buff 自动销毁（目标消失则 Buff 无意义）
- 场景树结构清晰（Buff 是目标的子节点）

### 13.2 Modifier 系统

Buff 通过 QuiverAttributes 的 Modifier 系统修改目标属性。

**方式 B（直接修改属性值）**：
- 添加 modifier 时：记录 base_value，直接 `set(attribute, computed_value)`
- 移除 modifier 时：恢复 base_value

**Modifier 记录结构**：

```gdscript
{
    "id": &"iron_wall",        # 唯一标识
    "attribute": &"move_speed", # 目标属性名
    "type": "multiply",         # "add" 或 "multiply"
    "value": 1.5,               # 修改值
    "source": spell_instance,   # 来源 SpellBase 引用
    "base_value": 600.0,        # 修改前的原始值
}
```

### 13.3 Buff 效果施加与移除

**施加**（`apply_spell_effect` method track 触发时）：

```gdscript
func _on_skin_effect_triggered() -> void:
    target.attributes.add_modifier(&"iron_wall", &"move_speed", "multiply", 1.5, self)
```

**移除**（Buff 进入 ENDING 阶段时）：

```gdscript
func _on_ending() -> void:
    target.attributes.remove_modifiers_from_source(self)
```

### 13.4 叠加层数规则

同名 Buff（相同 `modifier id`）重复施放时：
- 检查已有层数
- 不超过 max_stacks 时添加新层
- 达到 max_stacks 时移除最旧的一层，添加新层

叠加逻辑由 Buff 子类在 `_on_skin_effect_triggered()` 中实现，QuiverAttributes 的 `add_modifier()` / `remove_modifier()` 提供基础操作。

### 13.5 Buff 视觉表现

Buff 有自己的 SpellSkin + AnimationTree + 动画：
- 施放动画（spell_cast）
- 持续动画（spell_idle，循环播放）
- 消散动画（spell_fade）
- 通过 AnimatedSprite2D 显示视觉效果（如护盾光环、火焰环绕）

---

## 十四、召唤类法术

### 14.1 概述

召唤类法术与其他法术共享 SpellBase 基类，但有以下特点：
- 不使用 HitBox（召唤法术本身不造成伤害）
- 在 `apply_spell_effect()` 中创建独立的 CharacterBody2D 实体
- 召唤物有自己的 AI 状态机和生命周期
- SpellBase 的生命周期（召唤动画）和召唤物的生命周期是独立的

### 14.2 两个独立生命周期

```
SpellBase（法术实例）:
  cast → 播放召唤动画 → apply_spell_effect（创建召唤物）→ 动画结束 → end → destroy
  生命周期：几秒（召唤动画播完就结束）

召唤物（CharacterBody2D）:
  被创建 → 独立存在（AI 控制）→ 超时/死亡 → queue_free
  生命周期：可能几十秒甚至几分钟
```

### 14.3 召唤物自管理超时

`summon_duration` 放在召唤物自己的脚本中，不污染 SpellDefinition：

```gdscript
# summoned_creature.gd
extends QuiverEnemyCharacter

@export var summon_duration: float = 30.0  # 存活时间
var _elapsed: float = 0.0

func _physics_process(delta: float) -> void:
    super(delta)
    if summon_duration > 0:
        _elapsed += delta
        if _elapsed >= summon_duration:
            queue_free()
```

### 14.4 SpellManager 追踪召唤物

召唤法术子类在创建召唤物后，主动注册到施放者的 SpellManager：

```gdscript
# summon_beast.gd 的 _on_skin_effect_triggered()
if caster and caster.has_method("get_spell_manager"):
    caster.get_spell_manager().register_summon(_summoned_creature)
```

SpellManager 使用 Dictionary 追踪（O(1) 增删）：
- `register_summon()` — 添加引用 + 连接 `tree_exiting` 信号自动清理
- `dismiss_all_summons()` — 施放者死亡时调用，清理所有召唤物
- 召唤物自行超时 `queue_free()` 时，`tree_exiting` 信号自动从 Dictionary 中移除

### 14.5 施放者死亡处理

施放者死亡时调用 `_spell_manager.dismiss_all_summons()`，遍历所有已注册的召唤物并 `queue_free()`。

---

## 十五、输入映射

### 15.1 project.godot 配置

```ini
[input]
spell_1={
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":49,"physical_keycode":0,"key_label":0,"unicode":49,"location":0,"echo":false,"script":null)]
}
spell_2={
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":50,"physical_keycode":0,"key_label":0,"unicode":50,"location":0,"echo":false,"script":null)]
}
spell_3={
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":51,"physical_keycode":0,"key_label":0,"unicode":51,"location":0,"echo":false,"script":null)]
}
spell_4={
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":52,"physical_keycode":0,"key_label":0,"unicode":52,"location":0,"echo":false,"script":null)]
}
```

### 15.2 按键映射

| 按键 | Action | 对应槽位 |
|------|--------|---------|
| 1 | spell_1 | 槽位 0 |
| 2 | spell_2 | 槽位 1 |
| 3 | spell_3 | 槽位 2 |
| 4 | spell_4 | 槽位 3 |

### 15.3 可扩展性

- 手柄支持：添加 `InputEventJoypadButton` 到 action 中
- 自定义按键：通过 Input Map 编辑器修改
- 更多槽位：增加 spell_5/6/... action 和对应按键

---

## 十六、待讨论

1. **HUD 集成**：法力条、法术图标、CD 显示的 UI 设计。属于后续 UI 设计阶段，需要与 Phase 0 Step 0.5（基础 HUD）一起设计。

2. **Buff 叠加规则的具体策略细节**：max_stacks 是全局配置还是每个 Buff 独立配置？刷新最旧层还是刷新最新层？需要在实际实现 Buff 法术时确定。

---

**文档维护**：任何后续修改都必须更新以下文件，保持一致性
- `docs/SPELL_SYSTEM_DESIGN.md` — 本设计文档
- `docs/PLUGIN_ARCHITECTURE.md` — Quiver 插件架构文档（如修改 Quiver 源码）
- `PLUGIN_CHANGES.md`（项目根目录）— Quiver 插件修改记录