# 天之痕 ARPG 重制 — MVP 实施计划

> **最后更新**: 2026-08-20
> **MVP 目标**: 序章·大雁岭，验证全要素

---

## 一、设计决策（已确认）

| 项目 | 决策 |
|---|---|
| 战斗风格 | ARPG（2.5D，镜头可上下/左右自由移动） |
| 视角 | 俯瞰/斜视，镜头跟随角色 |
| 角色控制 | 支持多角色切换，后期支持同时多角色 |
| 美术策略 | 色块占位优先，系统验证通过后再做美术 |
| MVP 范围 | 仅序章（大雁岭 + 伏魔山），做精做完整 |
| 开发节奏 | 系统先搭好，每个系统有可视化的验证点 |

---

## 二、技术挑战分析

### 2.1 镜头系统改造 ✅ 已完成（2026-08-16）

~~Quiver 的 `QuiverLevelCamera` 目前只有 **左右** 屏幕边缘碰撞墙。~~ 已添加 Top/Bottom 碰撞，实现四方向屏幕边界。使用高度层 API 动态设置碰撞层（layers 15-24 bitmask）。`PLUGIN_ARCHITECTURE.md` 已同步更新。

### 2.2 角色切换系统（优先级：中期）

Quiver 插件没有内置角色切换机制。需要自建：

- **角色管理单例**（Autoload or in-stage Node）
  - 持有队伍中所有角色引用
  - 负责切换当前操控的角色
  - 非操控角色由 AI 接管（IdleAi 或 Follow）

- **切换机制**：
  - 按快捷键（Q/E 或数字键）切换
  - 切换瞬间：当前角色进入 IdleAi / Follow，目标角色进入 Idle
  - 镜头跟随当前操控角色（Camera2D 需要支持切换目标）

- **镜头跟随目标管理**：
  - 使用一个"镜头挂载点"节点，当前操控角色作为其父节点
  - 切换时移动挂载点到新角色

### 2.3 AI 同伴系统（优先级：中期）

使用 Quiver 的 AI SM（`QuiverAiStateMachine`）为 NPC 同伴提供 AI：
- **Follow 状态**: 跟随当前操控角色
- **Combat 状态**: 自动战斗，使用预设 AI 链（简单：Chase + Attack 循环）
- 在切换时，AI 状态要平滑切换

### 2.4 法术系统（优先级：后期）

Quiver 的 `CombatSystem` 只处理物理伤害。需要自建：
- **元素标签系统**（金木水火土）
- **法术 Resource**（类型、消耗、冷却、范围、效果）
- **法术释放状态**（自定义 action state）
- **元素克制**（克制 ×1.5 / 相生 ×0.75 / 中性 ×1.0）

---

## 三、开发阶段

### Phase 0：基础框架（2-3 周）

**目标**：一个可以跑起来的"占位"战斗关卡。

#### Step 0.1 — 创建干净角色 ✅
- `chen_jingqiu/` 已重建（2026-08-16），继承 `quiver_character_base.tscn`
- 当前使用 `chenjianchou_new/` 作为开发测试角色（非正式角色）
- 完整状态机，HurtBox/HitBox 配置正确，使用高度层碰撞系统

#### Step 0.2 — 完整动作状态机 ✅
- HurtBox/HitBox 已配置（使用高度层 + faction group，不再使用碰撞预设）
- Jump/Air、Combo、Hurt、Knockout、Die 状态均已实现
- 轮廓转换工具可自动从 sprite PNG 生成碰撞形状（Polygon/Capsule/Rectangle）

#### Step 0.3 — 镜头系统改造（修改插件） ✅
- `QuiverLevelCamera` 已添加 Top/Bottom 屏幕边界碰撞（2026-08-16）
- 使用高度层 API 动态设置碰撞层
- `docs/PLUGIN_ARCHITECTURE.md` 已同步更新

#### Step 0.4 — 第一个 FightRoom 测试关卡
- 创建 `scenes/stages/prologue/` 目录
- 创建测试 stage 场景
- 一个 FightRoom + PlayerDetector + EnemySpawner
- 占位敌人（QuiverEnemyCharacter 基类 + 占位 sprite）

#### Step 0.5 — 基础 HUD
- 玩家血条（复用 QuiverLifeBar 模式）
- 测试用 DebugLabels（状态机名称、HP）

**验证点**：操控陈靖仇，在 FightRoom 中用基础攻击打败 3 个占位敌人。

---

### Phase 1：角色控制体系（2-3 周）

**目标**：支持多角色切换的 ARPG 控制。

#### Step 1.1 — 角色管理器（Autoload）
- 创建 `Party.gd` 全局单例，管理队伍成员列表
- 支持添加/移除角色
- 切换接口：`switch_to(index)`, `switch_next()`, `switch_prev()`

#### Step 1.2 — 角色切换机制
- 切换时：当前角色 → IdleAi，目标角色 → Idle
- 镜头跟随目标切换
- 快捷键绑定（Q/E 轮转，数字键直达）

#### Step 1.3 — AI 同伴基础
- 非操控角色自动 Follow（跟随当前操控角色）
- 遇到敌人自动进入简单战斗循环（ChaseClosestPlayer → CallAttack → Wait）

**验证点**：操控陈靖仇 + 于小雪，按 Q 切换，两人协作打败敌人。

---

### Phase 2：对话与叙事系统（2 周）

**目标**：支持剧情展示的对话系统。

**决策**：使用 **Dialogic 2**（v2.0-Alpha-20，已安装到 `addons/dialogic/`）。

#### 为什么选 Dialogic 2
- 可视化时间线编辑器 — 非程序员也能快速编写对话
- 内置角色管理系统 — 头像、颜色、说话人管理
- 变量/条件系统 — 支持对话分支、好感度、任务状态
- 信号系统集成 — 对话中可以调用游戏代码、触发战斗
- 社区活跃，支持 Godot 4.5+

#### Step 2.1 — 创建序章对话内容
- 在 Godot 编辑器中使用 Dialogic 的 Timeline Editor 创建序章对话
- 创建角色定义：陈靖仇、陈辅、张烈（Character Editor）
- 编写序章对话时间线：
  - `prologue_01_chenfu_teaching.dtl` — 陈辅教导开场
  - `prologue_02_first_encounter.dtl` — 第一次遭遇妖物前后
  - `prologue_03_zhang_lie.dtl` — 遇张烈、组队

#### Step 2.2 — 集成到游戏流程
- 编写对话触发器：
  ```gdscript
  func _on_area_triggered():
      Dialogic.start("prologue_01_chenfu_teaching")
  ```
- 暂停游戏逻辑（对话时禁用角色输入）
- 对话结束后恢复控制
- 连接 Dialogic 信号（`timeline_started`/`timeline_ended`）到 Quiver 系统

#### Step 2.3 — 对话与游戏事件联动
- 通过 Dialogic 的 "Call Node Method" 事件触发：
  - 加入队伍（`Party.add_member()`）
  - 解锁任务状态
  - 激活 FightRoom
  - 切换场景

#### 自定义对话框样式（可选，后期美术替换时做）
- Dialogic 自带基础对话框，先用默认样式占位
- Phase 4 美术阶段再定制水墨风格对话框

**验证点**：完整演示序章开场对话，选项分支工作正常，对话结束后角色恢复正常操控。

---

### Phase 3：序章内容填充（持续）

**目标**：完整可玩的序章。

#### 内容清单（按场景）

**场景：大雁岭山道**
- 开场对话（陈辅 vs 陈靖仇）
- 教学战斗区域（移动、攻击、闪避）
- 第一次遭遇低级妖物（山贼/野兽占位）
- 到达伏魔山洞口

**场景：伏魔山洞窟**
- 探索区域（黑暗、火把）
- 中级妖物遭遇
- Boss 遭遇（魔物占位，后续替换为具体 Boss）
- 陈辅牺牲剧情
- 下山与张烈会合

#### 张烈 NPC
- 张烈 .tscn + 简单 AI（近战型）
- 加入队伍（触发角色切换系统）
- 简单对话交互

---

### Phase 4：美术替换（按需）

系统验证完功能后，分批替换：
1. 陈靖仇 sprite sheet（idle, walk, attack, hurt, jump）
2. 张烈 sprite sheet
3. 大雁岭场景背景美术
4. 伏魔山洞窟背景
5. 敌人 sprite sheet

---

## 四、占位美术规范（Phase 0-2）

为避免后续大量返工，统一占位规范：

| 对象 | 占位颜色 | 尺寸 |
|---|---|---|
| 陈靖仇 | 蓝灰色 #5B7B8A | 60×160 px |
| 于小雪 | 米白色 #F0EBE8 | 50×150 px |
| 拓跋玉儿 | 朱红色 #C83C32 | 55×155 px |
| 张烈 | 铁灰色 #808080 | 65×170 px |
| 低级敌人 | 暗绿色 #4A6A4A | 50×120 px |
| 中级敌人 | 暗棕色 #806040 | 60×140 px |
| Boss | 暗红色 #A04040 | 120×240 px |
| NPC | 黄色 #C8C880 | 50×140 px |

**占位 sprite** 统一结构：
- 身体方块 + 朝向标记（小三角形在方块左侧表示面朝左）
- 使用纯色 + 黑色 2px 描边
- 无需逐帧动画，用简单 Tween 呼吸（scale 上下浮动）

---

## 五、文件结构规划

```
xuanyuan-sword/
├── project.godot
├── addons/quiver.beat_em_up/     # 插件（尽量不改，必要时改并同步文档）
│
├── _beat_em_up/                  # 自定义 action states / AI states
│   ├── action_states/
│   │   ├── chen_jingqiu_attack_1.gd
│   │   ├── chen_jingqiu_attack_2.gd
│   │   └── chen_jingqiu_attack_3.gd
│   └── ai_states/
│       └── follow_player.gd
│
├── autoloads/                    # 全局单例
│   ├── party.gd                  # 队伍管理器
│   └── dialogue.gd               # 对话管理器（可选，也可用节点）
│
├── characters/
│   ├── _base/
│   │   └── character_base.tscn   # 自定义的角色基础场景（继承 quiver_character_base）
│   ├── playable/
│   │   ├── chen_jingqiu/
│   │   │   ├── chen_jingqiu.gd
│   │   │   ├── chen_jingqiu_skin.gd
│   │   │   ├── chen_jingqiu.tscn
│   │   │   ├── chen_jingqiu_skin.tscn
│   │   │   └── resources/
│   │   │       ├── chen_jingqiu_attributes.tres
│   │   │       └── attacks/
│   │   │           ├── basic_attack.tres
│   │   │           └── combo2_attack.tres
│   │   └── zhang_lie/            # 张烈
│   └── enemies/
│       └── mountain_bandit/      # 山贼（第一个敌人占位）
│
├── scenes/
│   ├── stages/
│   │   ├── _base/
│   │   │   ├── base_stage.gd
│   │   │   └── base_stage.tscn
│   │   └── prologue/
│   │       ├── dayan_ling.gd     # 大雁岭关卡
│   │       └── dayan_ling.tscn
│   └── test_stage.tscn           # 临时测试关卡（Phase 0 用）
│
├── systems/
│   ├── dialogue/
│   │   ├── dialogue_resource.gd
│   │   └── dialogue_box.tscn
│   ├── magic/                    # 五行法术系统（后期）
│   └── save/                     # 存档系统（后期）
│
├── ui/
│   ├── gameplay_hud/
│   │   ├── player_health_bar.gd
│   │   ├── player_health_bar.tscn
│   │   ├── party_switcher.gd   # 角色切换 UI
│   │   └── party_switcher.tscn
│   └── menus/
│
└── docs/
    └── README.md
```

---

## 六、验证点汇总

每个阶段的明确可玩验证：

| 阶段 | 验证点 | 验收标准 |
|---|---|---|
| Phase 0 | 战斗关卡原型 | 操控角色在 FightRoom 打败 3 个敌人，镜头正常移动 |
| Phase 1 | 角色切换 | 按 Q/E 切换角色，AI 同伴正确 Follow/战斗 |
| Phase 2 | 对话系统 | 完整演示开场剧情对话树 |
| Phase 3 | 序章完整 | 可从开头玩到张烈加入 + 第一个 Boss |

---

## 七、技术债务与后续优化

- **插件修改记录**：任何对 `addons/quiver.beat_em_up/` 的改动必须同步 `docs/PLUGIN_ARCHITECTURE.md`
- **占位美术替换清单**：Phase 4 时统一替换，避免零散替换导致风格不一致
- **性能基线**：Phase 0 完成后记录帧率基线，后续优化参考
- **多角色场景数据**：队伍中所有角色的数据（位置、状态）需要在切换时持久化到 Party 单例

---

## 附录 A：序章详细剧本（来自 story/bible.md）

### 序章：大雁岭

**场景 1：大雁岭山道（教学区）**
- 陈辅带着陈靖仇在山上修炼
- 陈辅教导靖仇：复国 vs 苍生的矛盾
- 靖仇练习剑法（教学：移动、攻击）

**场景 2：山中密林（第一次战斗）**
- 遇到山中野兽（妖物占位）
- 陈辅在旁指导（教学：闪避、使用基础技能）

**场景 3：伏魔山洞窟外**
- 陈辅决定带靖仇进入洞窟
- 关键对话：陈辅的最后教导

**场景 4：伏魔山洞窟内**
- 洞窟探索 + 妖物战斗
- 在深处遭遇强大魔物
- 陈辅拼死保护靖仇，重伤/冰封

**场景 5：下山途中**
- 靖仇带着师父的遗志独自下山
- 遇到张烈，两人结伴

**关键元素**：
- 陈辅遗愿：集齐十大神器
- 靖仇内心矛盾起点：师父复国期望 vs 善良天性
- 张烈：第一个伙伴，近战型，教靖仇"外面的世界"

---

## 附录 B：插件修改申请流程

任何对 `addons/quiver.beat_em_up/` 的修改必须：

1. 在 `PLUGIN_CHANGES.md`（项目根目录）记录变更：
   - 修改的类名/文件名
   - 修改原因（为什么不能在外面实现，必须改插件）
   - 修改内容
   - 日期

2. 同步更新 `docs/PLUGIN_ARCHITECTURE.md` 对应章节

3. 提交信息格式：`feat: 修改 quiver 插件的 XXX（功能说明）`

**优先原则**：能不改插件就不改。只有当 Quiver 框架无法满足需求才考虑修改。
