# 2.5D 高度层战斗系统 - 设计文档

> **版本**: 4.1.0  
> **创建日期**: 2026-08-11  
> **最后更新**: 2026-08-14  
> **状态**: Phase 1-5 已完成（方案 C + 10 层配置化 + speed_X 跳跃/击飞配置）  
> **变更记录**:
> - v2.0 — 重构数据流架构，base_height 从 _skin.position.y 派生（method track 同步），移除 base_X 文件名标注，保留 Quiver _skin_velocity_y 机制
> - v2.1 — 修复 Layer 公式为 `(min, max]`（无匹配默认 ground_level）；修复 CharacterBody2D collision_layer 覆盖原有 bits（只修改 15-19）；修复 `_update_hitbox_layers` 空状态复位；补充 `_get_hurtbox/hitboxes` 实现（基于 owner group）；明确 `are_factions_equal` 放在 `quiver_hurt_box.gd`；修正测试用例；CharacterBody2D.position.y 不再固定为 0；Collision Preset 预设为 ground_level（Section 8.8）；HitLane 系统保留（Section 8.7）
> - v2.2 — HurtBox/HitBox 引用改为 Quiver 标准模式（@export_node_path + @onready）；Skin 通过 `_runtime_ready()` 填充 hitboxes 数组；QuiverCharacter 通过 `_skin.hurtbox` / `_skin.hitboxes` 缓存引用；删除基于 group 的查找方法
> - v2.3 — 移除场景 4 的"全局 Y"列（与 Layer 抽象冲突）；修正扩展计划版本号（v1.1.0/v2.0.0 → v2.3.0/v3.0.0）；重写 Phase 5 描述；强调 Phase 1.5 为必需前置任务；补充文档维护声明
> - v3.0 — **方案 C 实施**：高度层属性从 QuiverCharacter 移到 QuiverCharacterSkin；AnimationPlayer track 路径从 `../` 改为 `.:`（无前缀直接访问 Skin 属性）；注入器优化（保留原始方法、keyframe 优化）；41 个动画文件已扫描应用
> - v3.1 — `base_height` 改为计算属性（`get: return -position.y`），移除 `_sync_base_height()` method track，解决跳跃时 base_height 不实时更新的问题
> - v4.0 — **10 层配置化系统**：从 5 层扩展到 10 层（layers 15-24）；边界值从 `project.godot` 的 `standard_height` 运行时计算；每对 `*_low`/`*_high` 层区分标准跳跃能力；删除废弃的 `HeightLayerSystem.gd`
> - v4.1 — **Phase 5 完成**：跳跃和击飞动画 `speed_X` 配置实现；Inspector 扫描工具自动提取 speed 值并写入 `QuiverAttributes.jump_force`（跳跃）和 `QuiverAttributes.knockback_weight`（击飞权重）；chen_jingchou 的 jump 动画已标注 `speed_2400`，knockout 动画已标注 `speed_2`

---

## 一、系统概述

### 项目目标

为《轩辕剑叁外传：天之痕》ARPG 重制版引入真实 2.5D 高度系统，使角色可以：
- 跳跃过矮障碍物
- 从悬浮平台下方钻过
- 被高墙阻挡
- 进行多高度攻击判定

### 设计哲学

**核心理念**：概念高度 ≠ 物理高度，碰撞形状相对物理体固定（CapsuleShape2D.position.y = 0）

**关键决策**：
1. 视觉高度真实反映（base_height + physical_height）
2. 碰撞形状相对 CharacterBody2D 固定（CapsuleShape2D.position.y = 0），CharacterBody2D 的 Y 由 Quiver `ground_level` 控制
3. Layer 动态注册（跟随 base_height 变化）
4. 双层过滤机制（Layer 兼容 AND 物理形状重叠）

### 2.5D 物理碰撞约束

**核心原则**：在 2.5D 游戏中，所有物理碰撞（角色 + 障碍物）必须遵循以下约束：

1. **统一使用 CapsuleShape2D**
   - 所有物理碰撞体必须使用 CapsuleShape2D
   - `radius` 固定为 20（与角色一致）
   - 只有 `height` 可以调整（代表水平宽度，不是视觉高度）
   - CapsuleShape2D 旋转 90° 水平放置（rotation = 1.5708）

2. **地面平面概念**
   - 2.5D 中"地面"就是整个屏幕平面
   - 地面不需要物理碰撞，只有可视化参考线
   - 所有物体的底部都贴着 ground_level 线（Y=500）
   - 物体 position.y = ground_level - radius = 480

3. **"悬空"效果的实现**
   - 悬空平台不是通过 Y 坐标实现
   - 而是通过高度层（collision_layer）实现
   - 例如：平台 collision_layer=131072（layer 18），角色跳跃时 base_height 超过该层才能碰撞

**示例布局**：
```
Y=0
  │
  │  (屏幕上方)
  │
Y=480 ──── 所有物体的 position.y（因为 CapsuleShape2D radius=20）
Y=500 ════ ground_level 线（可视化 ColorRect，高度 10px）════════
  │
  │  (屏幕下方，不可见)
  │
```

**障碍物配置示例**：
| 障碍物 | position | collision_layer | 说明 |
|--------|----------|-----------------|------|
| 矮墙 (160px) | (600, 480) | 16384 (layer 15) | 跳跃可越过 |
| 高墙 (400px) | (2000, 480) | 16760832 (layers 15-24) | 始终阻挡 |
| 悬空平台 | (1300, 480) | 131072 (layer 18) | 可钻过 |

### 适用范围

- ✅ 可玩角色（玩家 + NPC）
- ✅ 敌人
- ✅ 障碍物（矮墙、悬浮平台、高墙）
- ✅ 攻击判定（普通攻击、跳跃攻击、技能）

---

## 二、高度层定义

### 2.1 十层级系统（配置化）

层级区间采用 **(min, max]**（左开右闭）约定。边界值从 `project.godot` 的 `standard_height` 运行时计算。

**配置参数**：
- `standard_height` (SH)：标准身高（默认 180px），在 `project.godot` 中配置
- 层厚度 = SH × 0.75（默认 135px）
- 每对 `*_low` / `*_high` 层区分标准跳跃能否越过

| Layer 编号 | 名称 | 高度范围（公式） | SH=180 时 | 用途 |
|-----------|------|----------------|-----------|------|
| 15 | `ground_low` | (0, SH×0.75] | (0, 135] | 标准跳跃可越过 |
| 16 | `ground_high` | (SH×0.75, SH×1.5] | (135, 270] | 标准跳跃被阻挡 |
| 17 | `low_air_low` | (SH×1.5, SH×2.25] | (270, 405] | 低空 |
| 18 | `low_air_high` | (SH×2.25, SH×3] | (405, 540] | 低空 |
| 19 | `mid_air_low` | (SH×3, SH×3.75] | (540, 675] | 中空 |
| 20 | `mid_air_high` | (SH×3.75, SH×4.5] | (675, 810] | 中空 |
| 21 | `high_air_low` | (SH×4.5, SH×5.25] | (810, 945] | 高空 |
| 22 | `high_air_high` | (SH×5.25, SH×6] | (945, 1080] | 高空 |
| 23 | `very_high_low` | (SH×6, SH×6.75] | (1080, 1215] | 超高空 |
| 24 | `very_high_high` | (SH×6.75, +∞] | (1215, +∞] | 超高空 |

**默认回退规则**：当某个高度值不匹配任何层级区间时（例如 `base_height = 0`），默认归为 `ground_low`（layer 15）。

### 2.2 约束条件

**单调性约束**：边界值必须严格递增

```
0 < 135 < 270 < 405 < 540 < 675 < 810 < 945 < 1080 < 1215 < +∞
```

**理由**：
- 上层范围的宽度 ≥ 下层范围
- 高度值递增才有意义（越高层代表离地越远）

### 2.3 Layer 配置

在 `project.godot` 中配置标准身高和层名称：

```ini
[quiver]
beat_em_up/gameplay/standard_height=180.0

[layer_names]
2d_physics/layer_15="height_ground_low"
2d_physics/layer_16="height_ground_high"
2d_physics/layer_17="height_low_air_low"
2d_physics/layer_18="height_low_air_high"
2d_physics/layer_19="height_mid_air_low"
2d_physics/layer_20="height_mid_air_high"
2d_physics/layer_21="height_high_air_low"
2d_physics/layer_22="height_high_air_high"
2d_physics/layer_23="height_very_high_low"
2d_physics/layer_24="height_very_high_high"
```

层边界值由 `QuiverCharacter._build_height_definitions()` 运行时从 `standard_height` 自动计算，无需手动维护。

---

## 三、数据模型

### 3.1 三大高度参数

| 参数 | 类型 | 含义 | 存放位置 | 来源 |
|------|------|------|----------|------|
| `base_height` | float | 角色跳跃的概念高度 | **QuiverCharacterSkin** | 从 `position.y` 派生（method track） |
| `physical_height` | float | 角色的物理身高（随动作变化） | **QuiverCharacterSkin** | 动画帧文件名（Inspector 工具生成 value track） |
| `attack_heights[]` | Array（untyped） | 攻击判定的高度偏移数组 | **QuiverCharacterSkin** | 动画帧文件名（Inspector 工具生成 value track） |

**方案 C 决策**：所有高度层属性存放在 `QuiverCharacterSkin`（Node2D），而非 `QuiverCharacter`（CharacterBody2D）。原因是 AnimationPlayer 位于 Skin 节点下，使用 `.:property` 路径可以直接访问 Skin 属性，避免 `../` 路径导致的 track 解析警告。

**注意**：`attack_heights` 必须使用 untyped `Array`（而非 `Array[float]`），Godot 4 的 AnimationMixer 对 typed array 属性的 track 解析支持有限。

### 3.2 高度参数详解

#### base_height（概念跳跃高度）

- **含义**：角色当前帧的跳跃高度（概念值，用于 Layer 计算）
- **单位**：像素（px）
- **范围**：[0, +∞)
- **来源**：**从 `_skin.position.y` 实时派生**，`base_height = -_skin.position.y`
- **机制**：计算属性（getter），每次读取时自动计算 `-position.y`，无需动画 track 驱动
- **示例**：
  - 跳跃中 `_skin.position.y = -120` → `base_height = 120`
  - 地面站立 `_skin.position.y = 0` → `base_height = 0`

#### physical_height（物理身高）

- **含义**：角色当前帧的实际身高（用于 Layer 扩展计算）
- **单位**：像素（px）
- **范围**：[0, +∞)
- **可变性**：随动作变化
  - 站立：physical_height = 180
  - 蹲伏：physical_height = 120
  - 跳跃：physical_height = 180（身高不变）
- **来源**：文件名中的 `physical_Y` 标注
- **机制**：Inspector 工具生成 value track 写入 QuiverCharacter.physical_height
- **示例**：蹲伏帧 `crouch_01_physical_120.png` → `physical_height = 120`

#### attack_heights[]（攻击高度偏移）

- **含义**：攻击判定相对于角色 base_height 的高度偏移
- **单位**：像素（px）
- **范围**：可多个值（支持多高度攻击）
- **来源**：文件名中的 `attack_Z` 标注
- **机制**：Inspector 工具生成 value track 写入 QuiverCharacter.attack_heights
- **示例**：
  - 单高度攻击：`attack1_02_physical_180_attack_30.png` → `attack_heights = [30]`
  - 多高度攻击：`air_attack_01_physical_180_attack_80_120.png` → `attack_heights = [80, 120]`

### 3.3 Layer 计算公式

层级区间采用 **(min, max]**（左开右闭）约定。无匹配时默认返回 `ground_level`（bit 15）。

#### 角色/障碍物的 Layer 计算（区间查询）

```gdscript
var range_start = base_height
var range_end = base_height + physical_height

var covered_layers = []
for layer_def in LAYER_DEFINITIONS:
    if range_start <= layer_def.max and range_end > layer_def.min:
        covered_layers.append(layer_def.name)
if covered_layers.is_empty():
    covered_layers.append("ground_level")
```

**示例**：
- 站立角色：`base_height = 0, physical_height = 180`
  - 范围 = [0, 180]
  - Layer = ground_level, low_air, mid_air
- 跳跃角色：`base_height = 150, physical_height = 180`
  - 范围 = [150, 330]
  - Layer = mid_air, high_air, very_high

#### 攻击判定的 Layer 计算（点查询）

```gdscript
var attack_layers = []
for attack_h in attack_heights:
    var absolute_h = base_height + attack_h
    var h_layers = calculate_layers_for_point(absolute_h)
    attack_layers.append_array(h_layers)
attack_layers = attack_layers.deduplicate()
# 单个点的计算函数：
# for layer_def in LAYER_DEFINITIONS:
#     if absolute_h > layer_def.min and absolute_h <= layer_def.max:
#         return [layer_def.name]
# return ["ground_level"]  # 无匹配默认
```

**示例**：
- 跳跃空中踢：`base_height = 150, attack_heights = [80]`
  - 绝对攻击高度 = 150 + 80 = 230
  - 230 ∈ (200, 300] → Layer = high_air
- 地面多高度斩：`base_height = 0, attack_heights = [50, 150]`
  - 绝对攻击高度 = [50, 150]
  - 50 ∈ (30, 100] → low_air；150 ∈ (100, 200] → mid_air
  - Layer = low_air, mid_air

---

## 四、物理体设计

### 4.1 碰撞胶囊规格

| 参数 | 值 | 可变性 | 说明 |
|------|-----|--------|------|
| CapsuleShape2D.height | 30 px | 固定 | 不超过 ground 范围，避免与高物体侧面碰撞 |
| CapsuleShape2D.radius | 可配置 | Inspector 调整 | 角色宽度 |
| CapsuleShape2D.position.y | 0 px | 固定 | 相对 CharacterBody2D 的偏移 |

**注意**：CharacterBody2D.position.y **不是固定为 0**，而是跟随 Quiver 的 `ground_level` 变化（角色可以站在不同 Y 位置的地面上）。

### 4.2 物理体与视觉高度的关系

**关键设计**：
- **CharacterBody2D.position.y**：角色的地面位置（由 Quiver 原有的 `ground_level` 控制）
- **`_skin.position.y`**：皮肤相对于 CharacterBody2D 的偏移（跳跃时为负值）
- **`base_height`**：从 `_skin.position.y` 派生的概念高度，用于 Layer 动态注册

**完整视觉位置公式**：
```
实际视觉 Y = CharacterBody2D.position.y + _skin.position.y
             (地面高度)                  (跳跃偏移，负值 = 向上)
```

**好处**：
1. 避免与悬浮障碍物误碰撞（站立角色 layer=ground，悬浮平台 layer=low_air，layer 不兼容）
2. Layer 动态注册正确反映概念高度
3. 跳过矮墙、钻过悬浮平台、撞上高墙均可实现

---

## 五、文件命名规范

### 5.1 命名格式

```
<action_type>_<frame_num>_physical_<P>[_width_<W>][_attack_<A1>_<A2>_<A3>...].png
```

跳跃/击飞动画首帧可选：
```
<action_type>_<frame_num>_speed_<S>_physical_<P>[_width_<W>].png
```

### 5.2 各部分说明

| 部分 | 必选 | 说明 | 示例 |
|------|------|------|------|
| `<action_type>` | 是 | 动作类型 | idle, walk, jump, attack1, air_attack |
| `<frame_num>` | 是 | 帧编号（两位） | 00, 01, 02, ... |
| `physical_<P>` | 是 | 物理身高（像素） | physical_180, physical_120 |
| `width_<W>` | 否 | 角色碰撞体宽度（像素），映射到 CapsuleShape2D.height | width_204 |
| `attack_<A1>...` | 否 | 攻击高度偏移列表 | attack_30, attack_80_120 |
| `speed_<S>` | 否 | 起跳初速度（仅跳跃/击飞首帧） | speed_1200 |

### 5.3 示例文件名

| 文件类型 | 文件名示例 | 解析结果 |
|---------|-----------|---------|
| 站立 | `idle_00_physical_180_width_204.png` | physical=180, width=204 |
| 行走 | `walk_03_physical_180_width_204.png` | physical=180, width=204 |
| 蹲伏 | `crouch_01_physical_120_width_204.png` | physical=120, width=204 |
| 跳跃首帧 | `jump_00_speed_1200_physical_180_width_204.png` | speed=1200, physical=180, width=204 |
| 跳跃中 | `jump_03_physical_170_width_204.png` | physical=170, width=204 |
| 单高度攻击 | `attack1_02_physical_180_width_204_attack_30.png` | physical=180, width=204, attack=[30] |
| 多高度攻击 | `air_attack_01_physical_180_width_204_attack_80_120.png` | physical=180, width=204, attack=[80, 120] |

### 5.4 特殊规则

1. **每帧必须标注 `physical`**：未标注的文件会在扫描时报错
2. **`speed` 仅首帧**：只在跳跃/击飞动画的第一帧设置，Inspector 工具读取一次后写入 `QuiverAttributes.jump_force`
3. **`width` 映射到 CapsuleShape2D.height**：由于 CapsuleShape2D 旋转 90° 水平放置，height 属性实际上是角色的水平宽度
4. **数值单位**：`physical`、`width` 和 `attack` 为像素（px），`speed` 为像素/秒（px/s）
5. **顺序要求**：`speed` 在前（可选），`physical` 在中，`width` 在后（可选），`attack` 在最后
6. **`base_height` 不在文件名中**：从 `_skin.position.y` 实时派生，无需手工标注

---

## 六、数据流架构

### 6.1 因果关系（Source vs Derived）

```
_skin.position.y          ← SOURCE（皮肤实际位置）
  - 普通动画：无人设置，保持为 0（Quiver 原有行为）
  - 跳跃/击飞：_move_and_apply_gravity() 物理模拟写入
        ↓
base_height = -_skin_position_y  ← DERIVED（概念高度，用于 Layer 计算）

文件名标注               ← SOURCE
  - physical_Y
  - attack_Z
        ↓
value track → QuiverCharacter.physical_height / attack_heights  ← DIRECT（直接写入）
```

**核心原则**：`_skin.position.y` 是源头，`base_height` 是派生值。
永远不要用 `base_height` 反推 `_skin.position.y`，否则会产生循环依赖。

### 6.2 AnimationPlayer 轨道结构

**路径解析机制**：

AnimationPlayer 位于 Skin 节点下，其 `root_node` 默认 = `".."`（即 Skin 自身）。
所有现有动画轨道均相对于 Skin 解析（如 `AnimatedSprite2D:frame`）。

本系统新增的轨道使用 **无前缀路径**（方案 C），**直接访问 Skin 节点属性**：

| 轨道类型 | track path | 作用 |
|---------|-----------|------|
| value track | `".:physical_height"` | 写入 Skin.physical_height |
| value track | `".:attack_heights"` | 写入 Skin.attack_heights |

> **注意**：`base_height` 是计算属性（`get: return -position.y`），无需动画 track 驱动。

**路径格式说明**：
- `.:property` — 访问 root_node（Skin）自身的属性
- 这与 Quiver 原有轨道（如 `AnimatedSprite2D:frame`）使用相同的 root_node 解析机制

### 6.3 完整数据流

```
编辑器阶段（Inspector 按钮触发）
────────────────────────────────────────────────────────────
1. 遍历 AnimationPlayer 里所有动画
2. 通过 SpriteFrames 获取每帧纹理文件名
3. 解析文件名：physical_Y 和 attack_Z
4. 若文件名含 speed_S：配置到 QuiverAttributes.jump_force（首帧一次）
5. 清除旧的 height 轨道（保留原始 Quiver 方法），重新生成：
   - value track(".:physical_height")  ← discrete keyframes（只在值变化时添加）
   - value track(".:attack_heights")   ← discrete keyframes（只在值变化时添加）
6. 保存

运行时
────────────────────────────────────────────────────────────
AnimationPlayer._process（每帧）:
   - value tracks 更新 Skin.physical_height / Skin.attack_heights

QuiverCharacter._physics_process（每帧）:
   - 从 _skin 读取 base_height, physical_height, attack_heights
   - 计算占据的高度层范围 [base_height, base_height + physical_height]
   - 仅在层集合变化时更新 collision_layer（逐元素比较优化）
   - 更新 HurtBox/HitBox 的 collision layer
```

### 6.4 执行顺序与时序分析

Godot 同一帧内的处理顺序：

```
① QuiverCharacter._physics_process(delta)      ← 父节点先执行
    - 读取 physical_height / attack_heights ← 上一帧 AnimationPlayer 写入的值
    - 读取 base_height                       ← 计算属性，实时返回 -position.y
    - 计算并更新 collision layer

② Skin.AnimationPlayer._process(delta)        ← 子节点后执行
   - value track 更新 physical_height / attack_heights

③ 跳跃状态 JumpMidAir._physics_process(delta) ← 子节点后执行
   - _move_and_apply_gravity() 更新 _skin.position.y（物理模拟）
   - 下一帧步骤 ② 将同步此新值到 base_height
```

**影响评估**：

| 关注点 | 延迟 | 是否可接受 |
|-------|------|----------|
| collision layer 更新 | 滞后 1 帧（~16.67ms @60fps） | ✅ 远低于人类感知阈值 50-100ms |
| 视觉同步 | base_height 与 `_skin.position.y` 同步于同帧的步骤 ② | ✅ 实时一致 |

从动画驱动视角：碰撞层"跟随动画变化后更新"是符合预期的行为，不是 bug。

---

## 七、运行时流程（QuiverCharacter 扩展）

### 7.1 QuiverCharacterSkin 新增变量（方案 C）

```gdscript
# quiver_character_skin.gd 新增部分

# 三大高度参数（存放在 Skin 节点）
# base_height 是计算属性，从 position.y 实时派生
var base_height: float:
    get:
        return -position.y
@export var physical_height: float = 0.0  # 由 AnimationPlayer value track 赋值
@export var attack_heights: Array = []  # 必须 untyped Array，由 AnimationPlayer value track 赋值

# 高度层系统：战斗 Area2D 引用
@export_node_path("QuiverHurtBox") var _path_hurtbox := ^"AnimatedSprite2D/HurtBox"
@export_node_path("Node2D") var _path_hitboxes_container := ^"Attacks"

var hurtbox: QuiverHurtBox = null
var hitboxes: Array[QuiverHitBox] = []


func _runtime_ready() -> void:
    super()
    # 填充 combat Area2D 引用
    hurtbox = get_node_or_null(_path_hurtbox) as QuiverHurtBox
    var hitboxes_container := get_node_or_null(_path_hitboxes_container) as Node2D
    if hitboxes_container:
        for child in hitboxes_container.get_children():
            if child is QuiverHitBox:
                hitboxes.append(child)
```

### 7.1.2 QuiverCharacter 新增变量

```gdscript
# quiver_character.gd 新增部分

# 高度层定义常量
const HEIGHT_LAYER_DEFINITIONS = [
    { "min": 0,   "max": 30,   "layer": 15 },
    { "min": 30,  "max": 100,  "layer": 16 },
    { "min": 100, "max": 200,  "layer": 17 },
    { "min": 200, "max": 300,  "layer": 18 },
    { "min": 300, "max": INF,  "layer": 19 },
]

# 高度层缓存（避免每帧重复设置 collision layer）
var _cached_height_layers: Array[int] = []

# HurtBox/HitBox 缓存引用（从 Skin 获取，在 _ready 中初始化）
var _hurtbox: QuiverHurtBox
var _hitboxes: Array[QuiverHitBox] = []


func _ready():
    # ... 现有逻辑保持不变
    
    # 从 Skin 缓存 HurtBox/HitBox 引用（Quiver 标准模式）
    if _skin:
        _hurtbox = _skin.hurtbox
        _hitboxes = _skin.hitboxes
```

### 7.1.1 Skin combat Area2D 引用

**设计要点**：
1. 在 `QuiverCharacterSkin` **基类**中声明变量（避免静态类型检查报错）
2. 在 `QuiverCharacterSkinAnimTree` **子类**的 `_runtime_ready()` 中填充引用（修改已有方法，不是新增）
3. `@export_node_path` + `@onready` 是 Quiver 的标准模式（参考 `_path_animation_tree` / `_animation_tree`）
4. 默认路径 `^"AnimatedSprite2D/HurtBox"` 和 `^"Attacks"` 对应模板中的常见结构

#### QuiverCharacterSkin 基类新增部分

```gdscript
# quiver_character_skin.gd 新增部分
# 高度层系统需要暴露 HurtBox 和 HitBox 引用给 QuiverCharacter 访问

# 节点路径配置（Inspector 中可调整）
@export_node_path("QuiverHurtBox") var _path_hurtbox := ^"AnimatedSprite2D/HurtBox"
@export_node_path("Node2D") var _path_hitboxes_container := ^"Attacks"

# 公开变量（由子类在 _runtime_ready() 中填充）
var hurtbox: QuiverHurtBox = null
var hitboxes: Array[QuiverHitBox] = []

# 内部变量（用于遍历 children）
var _hitboxes_container: Node2D = null
```

#### QuiverCharacterSkinAnimTree 子类修改 `_runtime_ready()`

QuiverCharacterSkinAnimTree 已有 `_runtime_ready()` 方法，在其中添加 hitboxes 填充逻辑：

```gdscript
# quiver_character_skin_anim_tree.gd
# 修改已有的 _runtime_ready() 方法（第 104 行附近）

func _runtime_ready() -> void:
    super()
    _animation_tree.active = true
    
    # === 高度层系统：填充 combat Area2D 引用 ===
    hurtbox = get_node_or_null(_path_hurtbox) as QuiverHurtBox
    _hitboxes_container = get_node_or_null(_path_hitboxes_container) as Node2D
    if _hitboxes_container:
        for child in _hitboxes_container.get_children():
            if child is QuiverHitBox:
                hitboxes.append(child)
```

#### QuiverCharacter 在 `_ready()` 中缓存引用

```gdscript
# quiver_character.gd 的 _ready() 方法中

# 缓存 combat Area2D 引用（基类声明的变量，由子类填充）
if _skin != null:
    _hurtbox = _skin.hurtbox
    _hitboxes = _skin.hitboxes
```

这样做的好处：
- `_skin: QuiverCharacterSkin` 可以直接访问基类声明的 `hurtbox` 和 `hitboxes`，不触发类型错误
- 不使用 `_skin` 的子类（如果有）也不会报错，只是 `hurtbox == null` 和 `hitboxes == []`

### 7.2 base_height 计算属性

```gdscript
# QuiverCharacterSkin 中的计算属性
# 从 Skin 自身的 position.y 实时派生 base_height，无需动画 track 驱动
var base_height: float:
    get:
        return -position.y
```

### 7.3 Collision Layer 更新

```gdscript
# 以下方法位于 QuiverCharacter

func _physics_process(_delta: float) -> void:
    _update_collision_layers()


func _update_collision_layers() -> void:
    # 高度层数据存放在 Skin 节点（由 AnimationPlayer track 直接写入）
    if not _skin:
        return
    
    var bh: float = _skin.base_height
    var ph: float = _skin.physical_height
    var ah: Array = _skin.attack_heights
    
    # 角色整体占据的高度层 = base_height ~ base_height + physical_height
    var current_layers := _calculate_range_layers(bh, bh + ph)

    # 只在层集合变化时更新（逐元素比较）
    if current_layers != _cached_height_layers:
        _cached_height_layers = current_layers
        # 仅设置 layer 15-19，保留原有的 bits（如 players = layer 1）
        for layer in range(15, 20):
            set_collision_layer_value(layer, layer in current_layers)
        _update_hurtbox_layers(_layers_to_bitmask(current_layers))

    _update_hitbox_layers(bh, ah)


func _update_hurtbox_layers(character_bitmask: int) -> void:
    # 使用 _ready 中缓存的 _hurtbox 引用
    if _hurtbox:
        _hurtbox.collision_layer = character_bitmask
        _hurtbox.collision_mask = _all_height_layers_bitmask()


func _update_hitbox_layers(base_h: float, attack_hs: Array) -> void:
    # 默认 HitBox layer = 角色身体当前高度层
    var body_bitmask := _layers_to_bitmask(_cached_height_layers)

    if attack_hs.is_empty():
        # 非攻击状态：HitBox 复位为身体高度层（防御性复位）
        for hitbox in _hitboxes:
            hitbox.collision_layer = body_bitmask
        return

    # 攻击状态：根据 attack_heights 计算专属高度层
    var attack_bitmask := 0
    for attack_h in attack_hs:
        var absolute_h: float = base_h + attack_h
        attack_bitmask |= (1 << (_height_to_layer(absolute_h) - 1))
    
    for hitbox in _hitboxes:
        hitbox.collision_layer = attack_bitmask


# 区间查询：角色 range [min_h, max_h] 与哪些层 (min, max] 有交集
func _calculate_range_layers(min_h: float, max_h: float) -> Array[int]:
    var result: Array[int] = []
    for def in HEIGHT_LAYER_DEFINITIONS:
        if min_h <= def["max"] and max_h > def["min"]:
            result.append(def["layer"])
    if result.is_empty():
        result.append(15)  # ground_level
    return result


# 点查询：某个高度 h 属于哪个层 (min, max]，返回单个层编号
func _height_to_layer(height: float) -> int:
    for def in HEIGHT_LAYER_DEFINITIONS:
        if height > def["min"] and height <= def["max"]:
            return def["layer"]
    return 15  # ground_level


# layer 编号转 bitmask：layer N 对应 bit (N-1)
func _layers_to_bitmask(layers: Array) -> int:
    var mask := 0
    for layer in layers:
        mask |= (1 << (layer - 1))  # layer 15 = bit 14 = 1<<14
    return mask


func _all_height_layers_bitmask() -> int:
    var mask := 0
    for def in HEIGHT_LAYER_DEFINITIONS:
        mask |= (1 << (def["layer"] - 1))
    return mask
```

### 7.4 关键设计说明

**方案 C 决策（属性在 Skin）**：
- 高度层属性（`base_height`, `physical_height`, `attack_heights`）存放在 `QuiverCharacterSkin`
- AnimationPlayer track 使用 `.:property` 路径直接访问 Skin 属性
- 避免了 `../` 路径导致的 track 解析警告（"couldn't resolve track"）
- `QuiverCharacter._physics_process()` 从 `_skin` 读取数据进行碰撞层计算

**QuiverCharacter 不写 `_skin.position.y`**：
- `_skin.position.y` 由 Quiver 原有逻辑管理（跳跃/击飞时由 `_move_and_apply_gravity()` 修改，普通状态保持 0）
- Skin 的 `base_height` 是计算属性（`get: return -position.y`），从自身 `position.y` 实时派生
- 因果方向：`Skin.position.y` → `Skin.base_height`（不是反过来）

**HurtBox/HitBox 引用遵循 Quiver 标准模式**：
- Skin 通过 `@export_node_path` + `_runtime_ready()` 直接持有 HurtBox 和 HitBox 引用
- QuiverCharacter 在 `_ready()` 中从 `_skin.hurtbox` / `_skin.hitboxes` 缓存引用
- 运行时 `physics_process` 直接访问缓存的成员变量，无 group 遍历开销
- 节点结构在运行时固定，缓存引用永远有效

**Layer 更新性能**：
- `_cached_height_layers` 与当前层集合逐元素比较，`!=` 是 O(n)，n ≤ 5
- 大多数帧层集合不变，碰撞层不会被反复设置
- `_update_hitbox_layers()` 每帧都执行（因为 `attack_heights` 可能每帧变化），但只做简单赋值，开销极低

**防御性复位**：非攻击状态下 HitBox layer 复位为 body layer，虽然 Quiver 的 CollisionShape2D disabled 机制已保证碰撞安全，但多一层防御保证 layer 状态干净

---

## 八、碰撞判定机制（方案 A）

### 8.1 两套独立的 Layer/Mask 系统

**核心认知**：CharacterBody2D 和 Area2D 的 collision_layer / collision_mask 完全独立，互不干扰。
高度层（15-19）在两个领域使用**相同的机制**，但作用于不同的节点类型。

| 节点类型 | 用途 | Layer 15-19 的作用 |
|---------|------|-------------------|
| CharacterBody2D + StaticBody2D | 物理移动碰撞 | 决定"角色是否会撞上障碍物" |
| Area2D (HitBox/HurtBox/GrabBox) | 攻击检测 | 决定"攻击是否能打到对方" |

两套 Layer/Mask 各自独立，物理碰撞的 Layer 变化不影响 Area2D 检测，反之亦然。

### 8.2 各节点的 Layer/Mask 配置

| 节点 | collision_layer（身份） | collision_mask（监听） | 动态性 |
|------|------------------------|----------------------|-------|
| 主角 CharacterBody2D | 主角高度层（动态，每帧根据 base+physical 计算） | obstacles+screen_limits+ceiling（层 2/3/4，固定） | 每帧更新 layer |
| 矮墙 StaticBody2D | bit 15 = ground（固定） | 0 | 不变 |
| 悬浮平台 StaticBody2D | bit 16 = low_air（固定） | 0 | 不变 |
| 高墙 StaticBody2D | bit 15+16+17 = ground+low+mid（固定） | 0 | 不变 |
| 主角 HitBox | 攻击高度层（动态） | 0（被动标记） | 每帧更新 layer |
| 敌人 HitBox | 攻击高度层（动态） | 0（被动标记） | 每帧更新 layer |
| 主角 HurtBox | 主角高度层（动态） | bits 15+16+17+18+19 = 所有高度层（固定） | layer 每帧更新，mask 不变 |
| 敌人 HurtBox | 敌人高度层（动态） | bits 15+16+17+18+19 = 所有高度层（固定） | 同上 |

**设计逻辑**：
- HitBox 是被动标记（`monitoring=false, monitorable=true`），只发出自己当前高度的信号
- HurtBox 是主动检测（`monitoring=true, monitorable=false`），监听所有高度的攻击信号
- 高度过滤 + 物理形状重叠 保证只有高度兼容的攻击才能触发

### 8.3 判定条件

**物理碰撞（跳过/钻过/撞上障碍物）：**
```
碰撞发生 = (Layer 兼容) AND (物理形状重叠)
```

**攻击检测（HitBox → HurtBox）：**
```
触发 _on_area_entered 必须满足：
  1. HurtBox.monitoring = true
  2. (HurtBox.mask & HitBox.layer ≠ 0)   ← 高度层兼容（引擎过滤）
  3. HurtBox.shape ∩ HitBox.shape ≠ 空集  ← 形状重叠（引擎过滤）
  4. are_factions_equal(HitBox, HurtBox) == false  ← 阵营检查（代码过滤）
```

### 8.4 阵营过滤机制（`area2d:` Group）

用 Godot group + `"area2d:"` 前缀表达阵营关系。碰撞层需要在 `.tscn` 中手动配置。

**配置方式（编辑器）：**
```
主角 HitBox 加入 group: "area2d:chen_jingchou"
主角 HurtBox 加入 group: "area2d:chen_jingchou"
敌方小兵 HitBox 加入 group: "area2d:enemy_squad_1"
敌方小兵 HurtBox 加入 group: "area2d:enemy_squad_1"
```

**同一 `area2d:` 组的双方视为同阵营，攻击不造成伤害。**

此函数放在 `quiver_hurt_box.gd` 内，作为 `static function`，因为 HurtBox 是检测入口。
QuiverHitBox 和 QuiverHurtBox 都实现了相同的缓存机制：

```gdscript
# quiver_hurt_box.gd / quiver_hit_box.gd
const FACTION_PREFIX = "area2d:"  # 仅定义在 QuiverHurtBox

# 缓存机制（使用 Dictionary 实现 O(1) 查找）
var _faction_dict: Dictionary = {}

func _ready():
    # ... 其他初始化 ...
    _refresh_faction_cache()

func add_to_group(group: StringName, persistent: bool = false) -> void:
    super(group, persistent)
    if str(group).begins_with(FACTION_PREFIX):
        _refresh_faction_cache()

func remove_from_group(group: StringName) -> void:
    super(group)
    if str(group).begins_with(FACTION_PREFIX):
        _refresh_faction_cache()

func _refresh_faction_cache() -> void:
    _faction_dict.clear()
    for group in get_groups():
        if str(group).begins_with(FACTION_PREFIX):
            _faction_dict[group] = true

static func are_factions_equal(hit_box: Area2D, hurt_box: Area2D) -> bool:
    # 获取两侧的 faction Dictionary
    var hit_dict := _get_faction_dict(hit_box)
    var hurt_dict := _get_faction_dict(hurt_box)
    
    # 快速路径：任一方无 faction group，直接返回 false
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

static func _get_faction_dict(node: Area2D) -> Dictionary:
    if node is QuiverHitBox:
        return node._faction_dict
    elif node is QuiverHurtBox:
        return node._faction_dict
    else:
        # 回退：非 Quiver 类型，实时构建 Dictionary
        var dict := {}
        for group in node.get_groups():
            if str(group).begins_with(FACTION_PREFIX):
                dict[group] = true
        return dict
```

**性能**：
- `_ready()` 时初始化缓存，捕获 `.tscn` 中声明的 groups
- 重写 `add_to_group()`/`remove_from_group()`，捕获运行时的 group 变更
- `are_factions_equal()` 两侧都使用 Dictionary 缓存，自动选择小集合遍历，使用 `Dictionary.has()` 实现 O(1) 查找
- 消除重复的类型检查分支，代码更简洁
- 支持运行时动态修改 groups，缓存自动更新

### 8.5 自己打自己为什么不会触发

**空间位置决定 HitBox 形状与自己的 HurtBox 形状永远不会相交：**

| 节点 | 相对角色位置 | 大小 |
|------|------------|------|
| HurtBox | (5, 0.5)，覆盖角色身体 | 149×329 |
| Attack1 HitBox | (202, -303)，角色前方 | 144×52 |
| Attack2 HitBox | (231, -274)，角色前方更远 | 222×73 |
| Attack3 HitBox | (96, -389)，身前大范围 | 161×329 |

HitBox 全部布置在角色**前方**，HurtBox 覆盖角色**身体**。两者形状无空间交集。
即使 Layer 兼容（mask & layer ≠ 0），Godot 也不会触发 `_on_area_entered`，
因为物理形状重叠条件失败。**这是纯几何事实，无需 Layer 过滤。**

因此 HurtBox 的 mask 设为所有高度层并集，既不会误伤友军（阵营过滤），
也不会自己打自己（形状不重叠）。`_on_area_entered` 的调用次数与原方案几乎相同。

### 8.6 典型场景分析

#### 场景 1：角色从矮墙（30px）上方跳过

| 对象 | base_height | physical_height | Layer | 节点 |
|------|-------------|-----------------|-------|------|
| 矮墙 | 0 | 30 | [15] | CharacterBody2D |
| 跳跃中角色 | 50 | 180 | [16, 17] | CharacterBody2D |

- Layer：[16,17] & [15] = 空集 → ❌ 不兼容
- 结果：**不碰撞** ✓（角色跳过矮墙）

#### 场景 2：角色从悬浮平台（base=100）下方钻过

| 对象 | base_height | physical_height | Layer | 节点 |
|------|-------------|-----------------|-------|------|
| 悬浮平台 | 100 | 30 | [16] | CharacterBody2D |
| 站立角色 | 0 | 180 | [15, 16, 17] | CharacterBody2D |

- Layer：[15,16,17] & [16] = [16] → ✅ 兼容
- 物理形状：平台 Y 范围（概念）与角色 Y 范围（0-30）在 2D 平面上重叠
  - 但因为矮墙和平台的 StaticBody2D 在物理空间上实际有高度差，`move_and_slide` 不会误判
- 结果：**不碰撞** ✓

#### 场景 3：跳跃角色攻击地面敌人（高度过滤）

| 对象 | base_height | physical_height | attack_heights | Layer | 节点 |
|------|-------------|-----------------|---------------|-------|------|
| 跳跃攻击者 HitBox | 150 | 180 | [80] | [18] (150+80=230→high) | Area2D |
| 地面被攻者 HurtBox | 0 | 180 | — | layer=[15,16,17], mask=[15,16,17,18,19] | Area2D |

- HurtBox.mask & HitBox.layer = [15,16,17,18,19] & [18] = [18] → ✅ 高度兼容
- 但攻击者 HurtBox shape 与地面被攻者 HurtBox shape 在物理平面重叠
- 结果：**触发碰撞** → 代码检查阵营 → 不同阵营 → 扣血 ✓

#### 场景 4：地面攻击无法命中跳跃角色

| 对象 | base_height | physical_height | Layer |
|------|-------------|-----------------|-------|
| 地面攻击者 HitBox | 0 | 180 | low_air (16)，因为 attack_h=50，0+50=50 落在 (30,100] 区间 |
| 跳跃中被攻者 HurtBox | 150 | 180 | high_air (18)，因为 150 落在 (150,250] 区间 |

- HurtBox.mask & HitBox.layer = [15-19] & [16] = [16] → ✅ Layer 兼容
- 但跳跃时 `_skin.position.y` 被 `_move_and_apply_gravity()` 修改，皮肤子节点整体上移
- 跳跃角色的 HurtBox 与地面攻击的 HitBox 在空间上完全分离 → ❌ **形状无重叠**
- 结果：**不触发 `_on_area_entered`** ✓

- **高度过滤实际通过形状不重叠实现**，无需依赖 Layer mask 屏蔽（HurtBox mask 包含所有高度层也不影响正确性）
- 注意：这里假设两个角色站在同一个 `ground_level` 上，仅靠 `_skin.position.y` 的差异产生垂直分离

### 8.7 与 Quiver HitLane 系统的关系

Quiver 原有 `is_in_same_lane_as()` 机制：
```gdscript
func is_in_same_lane_as(defender: QuiverAttributes, attacker: QuiverAttributes) -> bool:
    var lane_limits = defender.get_hit_lane_limits()  # ground_level ± 60px
    return lane_limits.is_value_inside_lane(attacker.ground_level)
```

**关键纠正**：`CharacterBody2D.position.y` **不是固定为 0**，而是跟随 `ground_level` 变化。角色可以站在不同高度的地面上。因此 `_attributes.ground_level` 反映角色实际的地面 Y 坐标，**HitLane 始终有意义**。

**两者的职责分工**：

| 机制 | 检查维度 | 语义 |
|------|---------|------|
| HitLane (`ground_level` ± 60px) | CharacterBody2D Y 坐标差 | 两人站的位置是否足够近（同一"战线"） |
| 高度 Layer 系统 | base_height / attack_heights | 攻击在"垂直维度"上是否能打到目标 |

**它们是互补关系**：
- HitLane 管"你们是不是在同一个 2D 区域打架"
- Height Layer 管"你的攻击在高度上能不能到我"

**结论：保留 Quiver 原有 HitLane 系统，不改不动**。它与高度 Layer 系统正交，没有冲突。

### 8.8 Collision Preset 系统已移除

Quiver 原有的 `QuiverCollisionTypes` 碰撞预设系统已完全移除（包括 `quiver_collision_types.gd`、`collision_shape_types/` Inspector 工具）。

**碰撞层配置**：完全手动在 `.tscn` 中设置，运行时由 `_physics_process` 根据 `physical_height` 动态更新高度层。

**阵营过滤**：统一通过 `area2d:` faction group 实现：
- 角色 HurtBox 和 HitBox 加入 `area2d:<角色名>` group
- 墙壁反弹通过 `area2d:wall` group 控制（击飞时移除，落地时恢复）

#### 玩家/敌人碰撞层配置

玩家和敌人的 HitBox/HurtBox/GrabBox 碰撞层需要在 `.tscn` 中手动配置：

- **HurtBox**: collision_layer 设为角色所在高度层，collision_mask 设为需要检测的高度层
- **HitBox**: collision_layer 设为角色所在高度层，collision_mask 设为空（被动标记）
- **GrabBox**: collision_layer 设为角色所在高度层，collision_mask 设为空（被动标记）

运行时 `_physics_process` 会根据 `physical_height` 动态更新 collision_layer 和 collision_mask。

---

## 九、皮肤位置处理与 `_skin_velocity_y`

### 9.1 因果方向（关键认知）

```
_skin.position.y     ← SOURCE（皮肤的物理位置）
  由 Quiver 原有机制管理：
  - 普通状态：无人修改，保持为 0
  - 跳跃/击飞：_move_and_apply_gravity() 物理模拟修改
        ↓
base_height          ← DERIVED（计算属性，从皮肤位置实时派生，用于 Layer 计算）
  var base_height: float: get: return -position.y
```

**绝对不能用 `base_height` 反推 `_skin.position.y`**。否则：
- 跳跃时两者互相更新，产生循环依赖
- Quiver 的 `_move_and_apply_gravity()` 物理逻辑会与我们的 system 冲突

### 9.2 Quiver `_skin_velocity_y` 的处理策略

Quiver 的跳跃系统（`_skin_velocity_y + gravity`）**保留不动**。这是物理模拟，是跳跃视觉轨迹的正确实现方式。

**`_move_and_apply_gravity()` 调用范围：**
- 只有 Air 子状态调用（Jump、Knockout），不是所有状态
- 地面状态（Idle/Walk/Attack/Hurt/Die）不调用

**我们新增的机制：**
- `base_height` 计算属性（`get: return -position.y`），实时感知当前高度
- 这使 Layer 系统能感知当前高度，而无需修改 Quiver 的任何文件

**Quiver 原有文件无需修改**——`_skin_velocity_y` 在跳跃/击飞状态中正常工作，
我们只是"旁路"读取了它的结果（通过 `_skin.position.y`）来驱动 Layer 系统。

---

## 十、性能优化

### 10.1 Layer 更新优化

**问题**：每帧都更新 Layer 可能影响性能

**解决方案**：在 `_update_collision_layers()` 中做逐元素比较，仅在层集合变化时更新：

```gdscript
if current_layers != _cached_height_layers:
    _cached_height_layers = current_layers
    # layer 编号（1-indexed）
    for layer in range(15, 20):
        set_collision_layer_value(layer, layer in current_layers)
    _update_hurtbox_layers(...)
```

**性能开销**：
- 逐元素比较：O(n)，n ≤ 5（最多 5 个 Layer）
- 实际执行频率：仅在 Layer 集合变化时（跳跃、蹲伏等）

**注意**：`_update_hitbox_layers()` 每帧都会执行（因为 `attack_heights` 可能每帧变化），但只做简单赋值，开销极低。

### 10.2 base_height 计算属性开销

**问题**：每次读取 `base_height` 都执行 getter 是否有性能影响？

**结论**：可忽略。getter 仅做 `return -position.y`，一次取反操作，开销 < 1μs。且 `_update_collision_layers()` 每帧只读取一次。

### 10.3 AnimationPlayer Track 开销

**问题**：每个动画额外 2 条轨道是否影响性能？

**结论**：可忽略。AnimationPlayer 的 track 更新是引擎层 C++ 实现的高效操作。
每条 value track 每帧仅写入一个变量。

---

## 十一、Inspector 辅助工具

### 11.1 高度数据预览

为 Inspector 工具增加高度数据预览面板，显示：
- 动画列表
- 每帧的物理身高和攻击高度（从已生成的 value track 中读取）
- 未标注帧的错误提示

### 11.2 Layer 预览

为 `QuiverCharacter` 节点添加 Inspector 插件，显示：
- 当前 base_height
- 当前 physical_height
- 当前 Layer 集合
- 与相邻物体的 Layer 交互

### 11.3 批量重命名工具

提供工具，帮助动画师批量重命名动画文件：
- 读取帧图像尺寸，自动猜测 physical_height
- 批量添加 `physical_Y` 后缀（可选 `speed_S` 用于跳跃首帧）
- 人工检查和调整

---

## 十二、测试计划

### 12.1 单元测试

1. **解析器测试**
   - 正确解析带完整标注的文件名
   - 正确解析带攻击标注的文件名
   - 报错未标注的文件名

2. **Layer 计算测试**（区间 `(min, max]`，默认 ground_level）
   - 站立（base=0, physical=180）→ ground, low_air, mid_air
   - 跳跃（base=150, physical=180）→ mid_air, high_air, very_high
   - 蹲伏（base=0, physical=100）→ ground, low_air
   - 超高点攻击（base=300, attack=[50]）→ very_high
   - 攻击点=0（base=0, attack=[0]）→ ground_level（默认回退）

3. **碰撞判定测试**
   - 跳过矮墙（base_height > 矮墙范围）
   - 钻过悬浮平台（platform 与 ground 不同层）
   - 撞上高墙（高墙覆盖多层，与角色层兼容）

### 12.2 功能测试

1. **跳跃测试**
   - 跳跃高度正确
   - 落地时间正确
   - Layer 实时更新

2. **攻击测试**
   - 单高度攻击命中目标
   - 多高度攻击命中多层目标
   - 跳跃攻击仅命中同高度目标

3. **障碍物测试**
   - 跳过矮墙
   - 钻过悬浮平台
   - 被高墙阻挡

---

## 十三、实施计划

### Phase 1：编辑器工具 ✅ 已完成

1. ✅ 创建 `character_height_data.gd`（Resource）
   - 解析后的帧高度数据字典结构
   - `parse_height_from_filename()` 方法

2. ✅ 创建 Inspector 扫描工具（按钮触发）
   - 遍历 AnimationPlayer 所有动画
   - 通过 SpriteFrames 获取每帧纹理文件名
   - 解析高度数据
   - 调用 `_inject_height_tracks()` 写入 discrete keyframes
   - 错误汇总显示
   - 支持增量扫描（异步，不阻塞编辑器）

3. ✅ 验证：扫描后检查 `.tres` 内容和 AnimationPlayer 轨道

### Phase 1.5：动画资源命名准备 ✅ 已完成

- ✅ 动画帧文件名已按规范命名（`physical_Y`, `attack_Z`）
- ✅ 运行 Inspector 扫描工具批量生成轨道
- ✅ 41 个动画文件已扫描应用高度层轨道

### Phase 2：QuiverCharacter/Skin 扩展 ✅ 已完成（方案 C）

1. ✅ 修改 `quiver_character_skin.gd`
   - 添加 `base_height`（计算属性，`get: return -position.y`）
   - 添加 `@export var physical_height / attack_heights`
   - 添加 combat Area2D 引用（hurtbox/hitboxes）

2. ✅ 修改 `quiver_character.gd`
   - 添加 `HEIGHT_LAYER_DEFINITIONS` 常量和辅助方法
   - 添加 `_physics_process()` 从 `_skin` 读取数据并更新 collision layer
   - 在 `_ready()` 中缓存 HurtBox/HitBox 引用

3. ✅ 记录到 PLUGIN_CHANGES.md

### Phase 3：碰撞层更新 ✅ 已完成 / 阵营过滤 ⏳ 待实施

**已完成**：
1. ✅ 角色高度层计算（base_height + physical_height 范围）
2. ✅ CharacterBody2D collision_layer 动态更新
3. ✅ HurtBox collision_layer + collision_mask 动态更新
4. ✅ HitBox collision_layer 动态更新（基于 attack_heights）
5. ✅ Layer 缓存与逐元素比较优化
6. ✅ 在 `project.godot` 中注册 layer 15-19

**已完成**：
1. ✅ 添加 `are_factions_equal()` 静态辅助函数（`area2d:` group 阵营过滤）
2. ✅ 修改 `quiver_hurt_box.gd` 调用阵营检查（`_handle_hit_box` + `_handle_grab_box`）

### Phase 4：测试场景 ✅ 已完成

1. ✅ 创建测试关卡
   - 矮墙 StaticBody2D（height=30，layer=bit 15 = 16384）
   - 悬浮平台 StaticBody2D（height=100，layer=bit 16 = 32768）
   - 高墙 StaticBody2D（height=200，layer=bits 15+16+17 = 114688）

2. ✅ 实现调试覆盖层
   - `scripts/debug_height_overlay.gd`：运行时调试面板
   - 可视化 base_height、physical_height、attack_heights
   - 可视化当前占据的高度层
   - 可视化高度阈值线（30, 100, 200, 300）

3. ✅ 动态 collision_mask 更新
   - `QuiverCharacter._update_collision_layers()` 同步更新 collision_mask
   - 保留 layers 1-14，添加当前高度层 (15-19)
   - 使角色能够与高度层障碍物发生物理碰撞

### Phase 5：跳跃/击飞动画的 `speed_X` 配置 ✅ 已完成

#### 5.1 目标

为跳跃和击飞动画的首帧配置 `speed_X` 标注，使 Inspector 扫描工具能自动提取：
- 跳跃动画 → `QuiverAttributes.jump_force`
- 击飞动画 → `QuiverAttributes.knockback_weight`

#### 5.2 为什么需要

- **跳跃**：`speed_X` 决定跳跃的**初始冲量**（`_skin_velocity_y` 的初值）
- **击飞**：`speed_X` 作为**击飞权重**，影响被击飞时的速度（`knockback_amount * knockback_weight * launch_vector`）
- Inspector 工具会自动处理映射，无需手动编辑 `.tres` 文件

#### 5.3 实现机制

**文件名约定**：
```
jump_01_speed_2400_physical_180.png
         ↑
    speed_X（正数，表示跳跃力度）

knockout_00_speed_2_physical_180.png
           ↑
    speed_X（正数，表示击飞权重）
```

**映射规则**：
- `speed_X` 使用正数（与 `physical_X`、`attack_X` 保持一致）
- **跳跃**：`jump_force = -speed`（正数 speed → 负数 jump_force，因为向上为负）
- **击飞**：`knockback_weight = speed`（直接作为权重，默认 1.0）

**执行流程**：
```
扫描时：
  1. 解析文件名 → 提取 speed 值
  2. 找到跳跃动画（名称含 "jump"，排除 "knockout"）或击飞动画（名称含 "knockout"）
  3. 读取首帧（frame 0）的 speed 值
  4. 导航到 QuiverCharacter.attributes
  5. 跳跃：设置 jump_force = -speed
     击飞：设置 knockback_weight = speed
  6. 保存 QuiverAttributes 资源
```

#### 5.4 验收标准

- [x] 跳跃动画首帧有 `speed_X` 标注（chen_jingchou: `jump_01_speed_2400_physical_180.png`）
- [x] 击飞动画首帧有 `speed_X` 标注（chen_jingchou: `knockout_00_speed_2_physical_180.png`）
- [x] Inspector 工具能正确解析并生成 jump_force 和 knockback_weight
- [x] UI 显示跳跃力度和击飞权重映射（预览和扫描结果）
- [x] 在测试场景中验证跳跃高度和击飞距离是否符合设计

---

## 十四、验证清单

### 功能验证

- [ ] 站立时 base_height = 0，layer = ground + low_air + mid_air
- [ ] 跳跃时 base_height > 0，layer 随高度变化
- [ ] 跳过矮墙（base_height > 30）
- [ ] 钻过悬浮平台（base_height = 0）
- [ ] 撞上高墙（layer 兼容且形状重叠）
- [ ] 多高度攻击命中多层敌人

### 性能验证

- [x] Layer 更新只在层集合变化时发生（已实现逐元素比较优化）
- [ ] 每 `physics_process` 开销 < 1ms（待 Phase 4 测试场景验证）

### 错误处理验证

- [x] 未标注帧 → 扫描时报告错误（已实现）
- [x] 文件名格式错误 → 扫描时报告错误（已实现）
- [ ] 跳跃动画首帧无 `speed` → 扫描时警告（待 Phase 5 实现）

### 已完成验证

- [x] 注入器正确生成 `.:property` 路径轨道
- [x] 注入器保留原始 Quiver 方法（end_of_input_frames 等）
- [x] value tracks 只在值变化时添加 keyframe（优化）
- [x] 41 个动画文件成功扫描应用
- [x] 转身/攻击/跳跃动画正常播放（无 track 解析警告）

---

## 十五、风险与对策

| 风险 | 概率 | 影响 | 对策 |
|------|------|------|------|
| Quiver 插件修改后不稳定 | 中 | 高 | 完整测试 + 回滚计划 |
| 动画师工作量增加（每帧标注） | 高 | 中 | 提供批量重命名工具 |
| Layer 更新性能开销 | 低 | 低 | 逐元素比较 + 缓存 |
| 文件命名复杂度高 | 中 | 中 | 提供 Inspector UI 辅助 |

---

## 十六、扩展计划

**当前设计版本**：v2.2

### 近期扩展（v2.3）

1. **Inspector 辅助工具**
   - 高度数据预览
   - Layer 实时预览（显示当前占据哪些高度层）
   - 批量重命名工具（自动从文件名提取高度参数）

2. **动画混合**
   - 支持 Lerp 过渡（可选）
   - 支持动画混合时的 Layer 计算（取最高层）

3. **抓取（Grab）高度支持**
   - GrabBox 应用相同的高度 Layer 机制
   - 验证 HitBox 方案后再统一实施

### 远期扩展（v3.0）

1. **多层级攻击**
   - 支持更细粒度的 Layer 划分（如 8-10 层）
   - 支持自定义 Layer 配置（每角色独立配置）

2. **物理体动态高度**
   - 支持角色实际 Y 轴位移（攀爬、飞行）
   - 支持更真实的物理交互（抛体运动）

---

## 十七、总结

本设计文档定义了一个完整、可实施的 2.5D 高度层战斗系统。核心理念是：

1. **因果关系清晰**：`_skin.position.y` 是源头，`base_height` 是派生值
2. **碰撞形状相对 CharacterBody2D 固定**（CapsuleShape2D.position.y = 0），CharacterBody2D.position.y 由 Quiver `ground_level` 控制
3. **Layer 动态注册**（跟随 base_height 变化）
4. **双层过滤机制**（Layer 兼容 AND 物理形状重叠）
5. **Quiver 原有跳跃系统保持不动**，通过 method track 旁路获取高度数据

该系统能够支持：
- ✅ 跳过矮墙
- ✅ 钻过悬浮平台
- ✅ 被高墙阻挡
- ✅ 多高度攻击判定
- ✅ 阵营过滤（`area2d:` group）

**实施优先级**：Phase 1-5 全部完成

**当前状态**：Phase 1-5 已完成（方案 C + 10 层配置化 + speed_X 跳跃/击飞配置）

---

**文档维护**：任何后续修改都必须更新以下文件，保持一致性
- `docs/HEIGHT_LAYER_DESIGN.md` — 本设计文档
- `docs/PLUGIN_ARCHITECTURE.md` — Quiver 插件架构文档（如修改 Quiver 源码）
- `PLUGIN_CHANGES.md`（项目根目录）— Quiver 插件修改记录
- `xuanyuan-sword/AGENTS.md` — Agent 开发指南（如影响开发流程）
