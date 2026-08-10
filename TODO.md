# 天之痕 ARPG 学习项目 - 任务追踪

> 更新时间：2026-08-08  
> 当前阶段：Phase 1 Week 1

---

## 📊 整体进度

| 阶段 | 周次 | 里程碑 | 状态 |
|------|------|--------|------|
| Phase 0 | Week 0 | Windows F5 验证 | ✅ 已完成 |
| **Phase 1** | **Week 1-2** | **地图碰撞 + Player 抽场景 + Camera2D + 动画** | **🔄 进行中** |
| Phase 2 | Week 3-4 | 战斗系统入门 | ⏳ 待开始 |
| Phase 3 | Week 5-8 | 天之痕伏魔山序章 | ⏳ 待开始 |
| Phase 4 | Week 9-12 | 引入 Downtown Beatdown 架构 | ⏳ 待开始 |

---

## 🎯 Phase 1 Week 2：Camera2D + 动画 ✅ 已完成

### ✅ Task 2.1：Camera2D 摄像机跟随
- [x] 在 player.tscn 中添加 Camera2D
- [x] 配置 enabled、current、position_smoothing
- [x] 验证视角平滑跟随 Player
- [x] 额外：在 main.tscn 添加 Background (ColorRect) 作为移动参照物

### ✅ Task 2.2：基础行走动画
- [x] 在 player.tscn 中添加 AnimationPlayer 节点
- [x] 创建 idle 动画（静止状态）
- [x] 创建 walk 动画（Scale 变化，0.4秒循环）
- [x] 修改 player.gd 添加动画切换逻辑
- [x] 测试：行走时方块有抖动，停止时静止

### ✅ Task 2.3：朝向翻转逻辑
- [x] Sprite2D 水平翻转（向左时 flip_h = true）
- [x] 与动画系统配合测试通过

### 📚 进阶学习：正确的架构分离
- [x] 学习了 `_process` vs `_physics_process` 的本质区别
  - `_physics_process`：固定物理帧率（默认 60 TPS），处理物理相关代码
  - `_process`：随 FPS 变化的渲染帧，处理视觉相关代码
- [x] 重构 player.gd：
  - `_physics_process`：输入、速度、move_and_slide、朝向判断
  - `_process`：动画切换、sprite.flip_h
- [x] 创建学习笔记：`games/docs/GODOT_PROCESS_EXPLAINED.md`

---

## 📋 Phase 1 Week 1：地图碰撞 + Player 抽场景（已完成）

### 学习任务（1小时）

- [ ] **阅读 StaticBody2D 官方文档** (15min)
  - 链接：https://docs.godotengine.org/zh_CN/4.7/classes/class_staticbody2d.html
  - 要点：与 CharacterBody2D 的区别、collision_layer/mask 含义
  
- [ ] **阅读 CollisionShape2D 官方文档** (10min)
  - 链接：https://docs.godotengine.org/zh_CN/4.7/classes/class_collisionshape2d.html
  - 要点：Shape2D 类型（矩形、圆形、多边形）的选择
  
- [ ] **阅读物理层机制文档** (20min)
  - 链接：https://docs.godotengine.org/zh_CN/4.7/tutorials/physics/physics_introduction.html#collision-layers-and-masks
  - 要点：layer 和 mask 的区别、位掩码工作原理
  
- [ ] **阅读场景组织文档** (15min)
  - 链接：https://docs.godotengine.org/zh_CN/4.7/tutorials/scripting/scene_organization.html
  - 要点：场景继承、实例化、场景库概念

### 实践任务（1小时）

- [ ] **任务 1.1：添加地面碰撞体**
  - 操作：在 main.tscn 添加 Ground (StaticBody2D) + CollisionShape2D
  - 验证：Player 不会掉出屏幕底部
  
- [ ] **任务 1.2：添加四面围墙**
  - 操作：添加 Left/Right/Top/Bottom 四个 StaticBody2D
  - 验证：Player 不能走出屏幕边界
  
- [ ] **任务 1.3：Player 抽成独立场景**
  - 操作：创建 scenes/player.tscn，将 Player 及其子节点移入
  - 操作：在 main.tscn 中实例化 player.tscn
  - 验证：功能不变，player 成为可复用独立场景

### 验证节点

- [ ] Player 移动时有围墙阻挡
- [ ] Player 不会掉出屏幕
- [ ] player.tscn 独立存在且可被实例化
- [ ] 场景组织清晰，符合 Godot 最佳实践

---

## 📝 已完成任务

### Phase 0：Windows F5 验证 ✅

- [x] 用户在 Windows 运行 F5
- [x] 看到灰色方块（Player）
- [x] WASD 可移动
- [x] 方块不会掉出屏幕
- [x] 无报错信息

---

## 🎯 Phase 1 Week 3：攻击系统（进行中）

### ✅ Task 3.1 & 3.2：HitBox 基础 + 方向修正
- [x] 创建 AttackPivot 节点 (Node2D) 作为攻击判定容器
- [x] 创建 AttackHitBox 节点 (Area2D) 挂载攻击碰撞形状
- [x] 添加 DebugVisual (ColorRect) 半透明红色，可视化攻击范围
- [x] **Bug 修复**：使用 AttackPivot.scale.x = facing 替代直接修改 position
  - 解决了 flip_h 不影响 AttackHitBox 的位置问题
  - 学习了 Node2D Pivot 模式（Godot 设计模式，业界成熟实践）
- [x] 学习 Transform 继承：AttackPivot 的变换自动应用到 AttackHitBox

### ✅ Task 3.3：攻击动画和输入系统
**代码层（Step 4）**：
- [x] 添加 `_is_attacking` 状态变量（锁定攻击期间行为）
- [x] 添加 `_ready()` 函数连接 `animation_finished` 信号
- [x] 修改 `_physics_process()`：
  - 攻击期间跳过输入读取和方向计算
  - 检测 `attack` 输入动作（J 键）
  - 触发攻击时立即停止移动（direction = Vector2.ZERO）
- [x] 修改 `_update_animation()`：
  - 攻击期间强制保持 attack 动画
  - 提前 `return` 阻止切换到 idle/walk
- [x] 添加 `_on_animation_finished(anim_name)` 回调：
  - 检测 `anim_name == "attack"`
  - 重置 `_is_attacking = false`
  - 清空 `current_animation`，让下帧自动切换

**编辑器配置**：
- [x] **Step 1**：创建 `attack` 动画
  - 时长 0.3 秒，不循环，不自动播放
  - 轨道 1：`Sprite2D:scale`（变形效果）
  - 轨道 2：`AttackHitBox:visible`（视觉显示控制）
  - 轨道 3：`AttackHitBox:monitoring`（碰撞检测控制）
- [x] **Step 2**：配置 Input Map → 添加 `attack` 输入（J 键）
- [x] **Step 3.5**：修改 player.tscn → AttackHitBox 默认 visible = false
- [x] **Step 5**：F5 运行验证

**验证清单（全部通过 ✅）**：
- [x] 站立时按 J 键：方块变形 + HitBox 出现 0.2s → 恢复
- [x] 移动时按 J 键：立即停止 + 播放攻击动画
- [x] 攻击期间按方向键：不能移动（锁定）
- [x] 攻击结束后：自动根据当前输入状态切换到 idle 或 walk
- [x] 连续按 J 键：不能叠加攻击（必须等上次结束）
- [x] 向左移动 + J 键：HitBox 在左侧（方向跟随 facing 翻转）

---

## 🎯 Phase 2 Week 5：真实敌人 AI（进行中）

### ✅ Task 5.1：创建 Enemy 场景
- [x] 创建 `scenes/enemy.tscn`，结构：
  - Enemy (CharacterBody2D, layer=16 敌人身, mask=3 玩家+障碍物)
  - Sprite2D（红色占位方块）
  - AttackPivot (Node2D) → AttackHitBox (Area2D, layer=256 敌人攻击, mask=4096 玩家受击)
  - HurtBox (Area2D, layer=8192 敌人受击, monitorable=true)
  - HPLabel + StateLabel（调试用）
- [x] 创建 `scripts/enemy.gd`，包含：
  - 简单状态机枚举（PATROL / CHASE / ATTACK）
  - `_process_patrol()`：在 patrol_range 内来回移动
  - `_process_chase()`：检测到玩家后追击
  - `_process_attack()`：接近后发动攻击（带 cooldown）
  - `_detect_player()`：通过 `get_tree().get_first_node_in_group("player")` 查找玩家
  - `_on_damage_received()`：被攻击后扣血 + 闪烁反馈
  - `_on_attack_hit()`：攻击命中玩家时调用 `take_damage`

### ✅ Task 5.2：升级 hurt_box.gd
- [x] 添加 `signal damage_received(damage: int)`
- [x] `apply_damage(amount)` 发射信号
- [x] 父节点（Enemy、TargetDummy、Player）可连接此信号接收伤害

### ✅ Task 5.3：Player 可被攻击
- [x] 在 player.tscn 添加 HurtBox (Area2D, layer=4096 player_hurt_boxes)
- [x] 附加 hurt_box.gd 脚本，发射 damage_received 信号
- [x] 在 player.gd 添加 `@onready var hurt_box: Area2D = $HurtBox`
- [x] 添加 `add_to_group("player")` 让敌人可以找到玩家
- [x] 添加 `_on_damage_received()` 方法：扣血 + 闪烁反馈 + HP 显示
- [x] 添加 `take_damage(amount)` 供敌人攻击调用
- [x] 添加 HPLabel 显示当前 HP
- [x] 添加 `_die()` 方法（淡出后 queue_free）

### ✅ Task 5.4：TargetDummy 更新
- [x] 改用信号连接而非 has_method 委托
- [x] 在 `_ready()` 中 `hurt_box.damage_received.connect(_on_damage_received)`
- [x] `_on_damage_received()` 处理扣血 + UI + 死亡

### ✅ Task 5.5：main.tscn 更新
- [x] 实例化 Enemy 在 (1000, 360)（相对 Player 远 600px）
- [x] TargetDummy 保留在 (800, 360)（用于对照测试）
- [x] Player 移动到 (400, 360)
- [x] 三者位置关系：Player --400px-- TargetDummy --200px-- Enemy

### ⏳ Task 5.6：测试验证（等待用户执行）
- [ ] 运行游戏，Enemy 开始 PATROL（左右移动 200px）
- [ ] 当 Player 靠近 Enemy 到 300px 内，Enemy 进入 CHASE
- [ ] Enemy 追到 60px 内时，发动 ATTACK
- [ ] Enemy 攻击时红色 HitBox 闪现，Player 扣血（每次 -15 HP）
- [ ] Player 攻击 Enemy 时，Enemy 扣血（每次 -10 HP）
- [ ] Enemy 被攻击后从 PATROL 强制转为 CHASE
- [ ] Player 的 StateLabel 显示 Enemy 当前状态（绿/黄/红）
- [ ] Enemy HP 归零时 queue_free() 消失
- [ ] Player HP 归零时淡出后 queue_free() 消失

### 碰撞层配置总结

```
层级配置（layer = 2^(N-1) 对应第 N 层）：
├── Layer 1  (1)     = players       [Player 身体]
├── Layer 2  (2)     = obstacles     [墙壁]
├── Layer 5  (16)    = enemies       [Enemy 身体]
├── Layer 8  (128)   = player_hit    [Player AttackHitBox]
├── Layer 9  (256)   = enemy_hit     [Enemy AttackHitBox]
├── Layer 13 (4096)  = player_hurt   [Player HurtBox]
└── Layer 14 (8192)  = enemy_hurt    [Enemy/TargetDummy HurtBox]

碰撞矩阵：
           Player.body  Enemy.body  Player.atk  Enemy.atk  Player.hurt  Enemy.hurt
Player.body    -          -            -             -          -            -
Enemy.body     -          -            -             -          -            -
Player.atk     -          -            -             -          -           ✓ (检测敌人受击)
Enemy.atk      -          -            -             -         ✓ (检测玩家受击) -
Player.hurt    -          -            -             -          -            -
Enemy.hurt     -          -            -             -          -            -
```

### 学到的新知识点

1. **简单状态机**：用 enum + match 实现 PATROL/CHASE/ATTACK
2. **get_tree().get_first_node_in_group()**：通过分组查找节点
3. **add_to_group()**：把节点加入到分组
4. **信号解耦升级**：从 has_method() delegate 升级到真正的 GDScript signal
5. **is_instance_valid()**：检查节点是否仍然有效（防止已删除节点报空引用）

---

## 🎯 Phase 1 Week 4：伤害系统 ✅ 已完成（2026-08-09）

### ✅ Task 4.1：创建 TargetDummy 目标和 HurtBox
**新增文件**：
- [x] `scripts/hurt_box.gd`：HurtBox 脚本，发射 damage_received 信号
- [x] `scripts/target_dummy.gd`：测试目标脚本，包含 HP 系统、Tween 闪烁、死亡处理
- [x] `scenes/target_dummy.tscn`：完整场景，含 Sprite、CollisionShape、HPLabel、HurtBox

**碰撞配置**：
- [x] TargetDummy 配置：collision_layer=5 (enemies), collision_mask=3 (player+obstacles)
- [x] HurtBox 配置：collision_layer=14, collision_mask=0, monitorable=true
- [x] HurtBoxShape：80×60 矩形（稍微大于 TargetDummy 身体，提高容错）

**脚本功能**：
- [x] `@export var max_hp: int = 100`：可在编辑器调整血量
- [x] `signal damage_received`：弱耦合信号通信
- [x] `_update_hp_display()`：Label 显示 "当前HP / 最大HP"
- [x] `_play_hurt_animation()`：Tween 缩放动画 (0.1s × 2)
- [x] `_die()`：queue_free() 安全删除节点

### ✅ Task 4.2：AttackHitBox 信号连接
**player.gd 修改**：
- [x] 添加 `@export var attack_damage: int = 10`
- [x] 在 `_ready()` 中连接 `attack_hitbox.area_entered.connect(_on_attack_hit)`
- [x] 实现 `_on_attack_hit(area)` 方法，含 has_method() 防御检查
- [x] 调用 `area.apply_damage(attack_damage)`

**main.tscn 配置**：
- [x] 实例化 TargetDummy 在 (100, 0)（AttackHitBox 右边界 80px 碰 TargetDummy 左边界 80px）
- [x] 调整位置确保 Player 攻击能正好碰到 TargetDummy

### ✅ Task 4.3：验证测试（全部通过）
- [x] Player 旁有红色 TargetDummy，顶部显示 "100 / 100"
- [x] Player 移动能被 TargetDummy 挡住（物理碰撞正常）
- [x] 按 J 键攻击：红色 HitBox 出现 + 方块变形
- [x] HitBox 进入 HurtBox 时触发 area_entered 信号
- [x] TargetDummy HP 从 100 → 90 → 80... 逐级减少
- [x] 每次受击播放 Tween 缩放闪烁动画
- [x] HP = 0 时 TargetDummy 消失（queue_free）
- [x] 向左攻击（AttackPivot.scale.x = -1）也能命中

---

## 🔜 Phase 2 Week 5：状态机入门（待定）

### 学习目标
- 理解 FSM（有限状态机）的核心概念
- 用 Godot 实现简单的 Idle / Walk / Attack 状态机
- 对比当前的 "if 判断" 写法和状态机写法的优劣

### 可能的方向（待讨论）

**选项 A：标准教程式学习**
- 阅读状态机官方文档
- 从零写一个简单的 FSM 类
- 应用到现有 player.gd 上

**选项 B：直接学习 Downtown Beatdown 的状态机**
- 阅读模板 `addons/quiver.beat_em_up/characters/quiver_character.gd`
- 理解它的 State 节点模式
- 在自己的项目中模仿核心思路

**选项 C：先升级 TargetDummy 为真实敌人**
- 添加简单的 AI（巡逻 + 追击）
- 给敌人加上攻击能力
- 实现互相伤害的对战

---

## 🎓 Week 4 学到的核心概念

| 概念 | 应用 |
|-----|------|
| **HurtBox 模式** | 独立的受击判定区域，与物理碰撞分离 |
| **Signal 松耦合** | HurtBox → damage_received → TargetDummy，无需硬编码引用 |
| **Delegate 模式** | HurtBox.apply_damage() 转发给父节点 take_damage() |
| **@export 可调参数** | max_hp、attack_damage 可在 Inspector 调整 |
| **Tween 补间动画** | create_tween() + tween_property() 实现简单视觉效果 |
| **queue_free()** | 安全删除节点（延迟到帧末执行）|
| **双向碰撞匹配** | Area A 的 mask 含 B 的 layer 或反之 |

---

## 📊 整体进度总结

```
Phase 1（基础学习） - 全部完成 ✅
├── ✅ Week 1：地图碰撞 + Player 抽场景
├── ✅ Week 2：Camera2D + 动画
├── ✅ Week 3：攻击系统（HitBox + AttackPivot + 攻击动画）
└── ✅ Week 4：伤害系统（TargetDummy + 伤害传递）

Phase 2（进阶内容） - 即将开始
├── ⏳ Week 5：状态机入门（待决定方向）
├── ⏳ Week 6：敌人 AI
├── ⏳ Week 7-8：Downtown Beatdown 模板学习
└── ⏳ Week 9-12：天之痕伏魔山序章
```

**已实现的功能清单**：
- [x] 玩家移动（WASD）
- [x] 摄像机跟随（Camera2D）
- [x] Idle / Walk 动画切换
- [x] 朝向翻转（AttackPivot.scale.x）
- [x] 攻击动画（Sprite2D 缩放变形）
- [x] 攻击判定窗口（AttackHitBox monitoring = true 的 0.05-0.25s）
- [x] 伤害传递（HitBox → HurtBox → damage_received 信号）
- [x] HP 系统（max_hp、current_hp、HPLabel）
- [x] 受击反馈（Tween 闪烁动画）
- [x] 死亡处理（queue_free）

---

## 📚 相关文档

- [学习资源](docs/learning_resources.md)
- [ARPG 设计方法论](../docs/ARPG_DESIGN_RESEARCH.md)
- [**Godot 处理循环详解**](../docs/GODOT_PROCESS_EXPLAINED.md) ⚠️ _process vs _physics_process
- [**Pivot 节点设计详解**](../docs/PIVOT_NODE_DESIGN.md) 🎯 AttackPivot 的设计理由
- [**伤害系统详解**](../docs/DAMAGE_SYSTEM.md) 🆕 Week 4 完整讲解（2026-08-09）

---

> **下一步**：讨论 Week 5 的重点方向（选项 A / B / C）

## 🔜 后续阶段预览

**Phase 2 Week 5：状态机入门**
- 学习 FSM（有限状态机）概念
- 实现简单状态机：Idle / Walk / Attack / Hurt
- 使用信号触发状态转换
- 对比 AnimationPlayer 状态 vs 节点级状态机

**Phase 2 Week 6：敌人基础**
- 创建 Enemy 场景（复用 Player 结构）
- 敌人 AI：巡逻 + 追击 + 攻击
- 实现敌人死亡效果（动画 + 清除）

---

## 📚 相关文档

- [学习资源](docs/learning_resources.md)
- [项目说明](docs/README.md)
- [天之痕剧情圣经](../story/bible.md)
- [ARPG 设计方法论](../docs/ARPG_DESIGN_RESEARCH.md)
- [**Godot 处理循环详解**](../docs/GODOT_PROCESS_EXPLAINED.md) ⚠️ **必读** - _process vs _physics_process
