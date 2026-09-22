# S2 细案 · 序章「坠河」可玩切片 设计文档

- 日期：2026-09-21
- 状态：设计定案（设计会终审通过），待实施
- 上游文档：`2026-09-18-stage-infrastructure-master-design.md`（总纲）之 S2 子项目
- 设计输入：`story/章节关卡表_折旗.md` 序章条目（本次修订覆盖其"新机制依赖：无"）、
  `docs/SPIKE_CONTAINER.md`（容器六裂缝+四裁决全部定案）、`docs/SPIKE_DIALOGIC.md`
  （对话后移 S3 的依据）、`docs/ARPG_DESIGN_RESEARCH.md` §1.4/§5.3

---

## 1. 使命与验收定义

让玩家在**第一小时内摸到本作全部可玩动词**：移动/连段/跳跃/弹墙、盾反（格挡+弹反）、
护人状态、法术、宝箱与关键物品、互动触发（船闸/跳河 QTE）、过场与段级重跑。
序章同时是全作工程骨架的**总压力测试**：容器化章节、会话状态、段级检查点、
互动触发件这四件新机制在此落地后，第一至十章都是同构的内容生产。

**验收口径**：三个里程碑各可 F5 演示（§8）；全部新机制的契约套**随批交付**
（S1 关账教训②法典化：机制与契约不同批 = 违规）。

## 2. 已裁定决策（含被否选项，防复议）

| # | 决策 | 被否的替代 |
|---|---|---|
| D1 | 序章 = **容器化章节**（stage0 过场 + 宫廊/街市/船闸/河滩/尾声五内容段） | 单大场景 after_fight 串场（臃肿、美术混装、契约样板惯性） |
| D2 | 容器进 S2 **施工第一批** | 降级到第一章批（依据"序章无新机制依赖"的关卡表原文——已被本设计覆盖） |
| D3 | 序章给**全内容**（含法术/宝箱/关键物品），装备走**甲方案**（叙事化妆：面板+外观+信物），真装备系统（槽位/稀有度/掉落表）后移至第一、二章间独立批 | 序章砍内容守 M 规模；乙方案直接上装备系统（+40% 工期） |
| D4 | **段级检查点**：允许死，死=当前段重跑（顺带清偿 S1 backlog⑤"重试当前房"） | 章节级重来（挫败）；不允许死（与全能力展示的高压演出矛盾） |
| D5 | 盾反=**双层简版**：按住格挡减伤 + ~6 帧弹反窗（成功敌短硬直+白闪，失败吃满伤无追加惩罚）；护人态自动换挡（攻*0.3/弹反窗*2） | 硬核（小窗+破防重罚）；只有格挡无弹反（令锋都尉的盾反验收段没抓手） |
| D6 | 曹氏血崩 = **强制切段**（历史不可变，不弹失败界面）；护主简化为其隐藏血条 | 游戏失败重试（与固定悲剧叙事冲突）；真护主值系统（首现章复用不足，后批升级） |
| D7 | 纵火兵一期 = 火把投掷弹+逼走位；**地面火墙不做**（预留批次） | 一期上火墙（新地形危险件，+半天，演出不足再补是低成本迭代） |
| D8 | 演出双段：街市千人波割草（全火力展示）→ 船闸 mini-boss 令锋都尉（盾反进阶验收）→ 河滩跳河时机窗（节奏框架简版：判定窗+屏显，正式音游框架留第一章） | 只做其一；本期就建通用节奏框架（无第二用户，违反 YAGNI） |
| D9 | 褚遂愿（成年体）**chen 占位先行**，美术就绪同名替换（创建器产线） | 等美术排期（卡死关键路径） |
| D10 | 单地点场景**双轨制**：ref A/B 保持 BaseStage 法定形态（128 契约基线），新章节一律 ChapterShell 形态 | 全量迁移 ref（连坐契约基线，无内容收益） |
| D11 | 换可玩角色（褚→童年杨政道）**只留接口**，本切片不实现 | 本期做换角（无用户：序章单角色） |
| D12 | 清场离场策略 = **A 切换即强清**（spike 已验证）；段检查点记录入口+敌方清零 | B 释放重建（弃清场持久） |
| D13 | 光照复位责任归壳（进场写画布色，controller 配置随舞台内容件） | 每场景自复位（controller ready 一次性语义下不可靠，spike C5） |

## 3. 容器架构（第一章批的正主）

### 3.1 场景结构

```
scenes/stages/xuanyuan-chapter-1/chapter_01.tscn     ← 章节场景（新建，用户 WIP 的 stage0 并入为段0）
└── ChapterShell (Node2D, chapter_shell.gd)
    ├── Players/Chen (LevelCamera 挂其下——装配一条不变)     ← 永驻壳层（D4 段重跑的锚）
    ├── HudLayer (GameHUD + PauseMenu + DeathScreen + 提示层) ← 五职责自 BaseStage 上移
    ├── Segments/                                            ← 段内容件容器
    │   ├── Segment00_Cutscene (用户 stage0 改造)
    │   ├── Segment01_PalaceCorridor … Segment05_Epilogue    (StageContent)
    └── (无场景常驻背景——背景归各段内容件)
```

- **StageContent**（新脚本，`scripts/chapter/stage_content.gd`）：`extends Node2D`，
  承载一段的全部：几何（Collisions 配方不变）、FightRoom 三件套、背景/前景、可选
  光照子树（CanvasModulate+KeyLight+Controller）。导出：`segment_id: StringName`、
  `entry_points: Dictionary`（命名入口→局部坐标）、`exit_hint`、`clear_target`
  （本段完成条件：房全清/触发件到达/自动）。
- **ChapterShell**（新脚本 `scripts/chapter/chapter_shell.gd`）职责清单：
  段注册与懒实例化（常驻内存，策略 A/D12）、`switch_segment(id, entry)`
  （90 帧静默窗→在场敌人强清→摘挂→落位→光照复位 D13）、段级检查点
  （进入段时记录 `{segment_id, entry}`，死亡/曹氏血崩→`restart_segment()`）、
  波次聚合（读当前段全部检测器的 `paths_enemy_spawners`，全清→`segment_cleared`）、
  会话状态包（§3.3）、五壳件（ESC/死亡转交/HUD 绑定）、`playable` 接口位（D11）。

### 3.2 迁移与双轨

- `BaseStage` 与 `ChapterShell` **并存**（D10）：五职责代码上移时把可共享部分
  （波次聚合、路径解析、壳接线）抽 `scripts/chapter/session_rules.gd` 静态库，
  BaseStage 改为薄消费方——重构而非复制，防双实现漂移；
- validator：R1 扩为"根实例 = base_stage.tscn **或** chapter_shell.tscn"；
  R2（stage_id）只对 base 形态强制，shell 形态检查 `chapter_id` 非空（R2'）；
  新增 **R11：段内容件（StageContent 子树）内的 Area2D 交互必须走白名单脚本**
  （检测器/生成器/出口/触发件模板），禁手写信号胶水。

### 3.3 会话状态包 v1（与 S5 存档同构的最小核）

```gdscript
class_name ChapterSession extends RefCounted
var flags := {}            # 关键物品旗标 item_id -> true
var chests := {}           # 宝箱/物件 一次性拾取记录
var cleared_segments := {} # segment_id -> true（D12 清场持久）
var checkpoint := {}       # {segment, entry}（D4 段级重跑锚）
# 角色本体状态在角色身上（hp 等），不入包——"玩家永驻壳内"天然延续（spike E6）
```
信号：`flag_added / chest_opened / segment_cleared / segment_restarted`。
消费方：触发件（宝箱查重拾取标记）、壳（段完成推进/重跑）、尾声（物品栏展示）。

### 3.4 spike 六裂缝的对策定版

| 裂缝 | 定版方案 |
|---|---|
| C1 五职责 | 全部上移壳（§3.1），StageContent 零壳件 |
| C2 tween 孤儿 | 切换九十字静默窗（90 物理帧）+ FightRoom 收口回调补 `is_inside_tree()` 守卫（双保险，插件侧 3 行） |
| C3 尸体滞留 | 策略 A：强清 + 等 `tree_exited` 落定再摘树（spike 已验流程） |
| C4 传送误触 | 段入口点一律放检测线**前场区**（法典雷区 i 的容器化改写）；`switch_segment` 落位后 2 帧内临时屏蔽检测器（防既成重叠误判为"跨线"） |
| C5 画布色残留 | 壳负责：进场时把该段 controller 的 default_phase 色写画布（无 controller 段回中性白） |
| C6 落位路径 | 生成器 `path_spawn_parent` 改指 `../../Players`（段根→壳→Players），validator R5 白名单同步两种合法形态 |

## 4. 互动触发件（第二章批）

- 标准场景 `scenes/chapter/interact_trigger.tscn`：Area2D（interact_trigger.gd）
  + 提示 Label + 碰撞形状。导出：`prompt_text`、`action := &"interact"`（新输入
  动作，默认键 **E**）、`repeatable := false`、`cooldown := 0.0`、
  `requires_flag := &""`。信号：`interacted`。
- 三用户 + 一预备：**船闸**（触发→闸门动画+限时窗口→未及=强制切段 D6/D4 复用）、
  **宝箱**（`chest_opened`→`session.chests` 查重→`flag_added` 关键物品）、
  **跳河 QTE**（时机窗内按 interact→成功段终；失败吃伤害不死、窗口再来——固定悲剧
  只延迟不否决）、对话（S3 原样复用件）。
- 法典第十条 + R11 执法 + `container/interact` 契约套（触发一次性/冷却/旗标门）。

## 5. 战斗接入（第三、四批）

### 5.1 盾反/格挡/护人态

- 新输入动作 `block`（默认键 K，可改）；
- `QuiverAttributes` 增 `is_blocking := false`（**动画关键帧轨道驱动**，与
  `is_invulnerable` 同族纪律：防御姿势动画键开）+ `block_started_at`（角色侧记录
  按下时刻）+ `guard_mode := false`（褚遂愿护人阶段脚本开关）；
- 判定改在 `QuiverHurtBox._handle_hit_box` 最前：防守方 `is_blocking` 且
  `Time.get_ticks_msec() - block_started_at <= 100ms`（护人态 200ms）→
  **弹反**：攻击方吃 `hurt_requested`（短硬直 K=60 不带飞）+ 白闪（HitFreeze 现件
  加强 1 拍）+ 防守免伤免退；仅 `is_blocking` → **格挡**：伤害 ×0.4，不击退；
  否则现行不变。死亡结算路径不动。
- 数值档全部走常量+attributes 导出，进契约：格挡减伤/弹反窗/护人换挡/普通回归
  四断言（headless 复用 lane 套的 chen×小贩靶场）。

### 5.2 法术接入

零新代码：SpellCreator 产线配 2 门（火球模板必上，第二门视美术），褚遂愿面板开
spell 键权（1-4 InputMap 已在），正式场景实测 cast 命中（cast_contract 已有单元，
本批补"正式壳场景内施法命中"1 条 E2E——教训②）。mana 条 HUD 已有。

### 5.3 兵种与 mini-boss

刀手=小抄换参（快攻无盾，`street_...` 产线新角色皮占位）；纵火兵=
`_beat_em_up/ai_states/` 开张首件（保持距离状态机：距>240 接近 / 150-240 投火把
（复用弹体）/ <150 后跳）；令锋都尉=R 池 1500 高抗击 + 盾常驻（正面受击减伤 0.7，
逼弹反教学）+ 两招循环，全部吃既有机制（spike E1/E2 证明内容件形态可承载）。

## 6. 内容与美术替换位

五段内容表（宫廊护送教学/街市双波+割草/船闸 mini-boss+限时/河滩跳河/尾声演出）；
用户素材目录（`assets/stage0/` 帧序列+mp4）由内容批正式接线，**占位纪律**：
角色全用 chen 皮，背景图缺时 ColorRect+参考线（debug_background 现件），
任何美术到货=同名替换不返工（角色产线判例推广到场景件）。

## 7. 过场衔接

stage0（VideoStreamPlayer+native_video）**改造为 Segment00 内容件**：视频播完/
跳过（interact 任意键）→ 壳推进到宫廊。降级契约（AGENTS 已备案）：视频缺失/
平台不支持 → 静帧+文字板直进，永不卡死。

## 8. 里程碑与批次验收

| 里程碑 | 批次 | 交付与契约 | F5 演示口径 |
|---|---|---|---|
| **M1 骨架可玩** | B1 容器批；B2 触发件批 | `container_contract` 套（spike E1-E7 转正+段重跑+光照复位+R2'/R11 validator）；`interact_contract`；法典第九（容器双轨）/十条；食谱新章 | 五段能切、死=段重跑、宝箱/船闸可交互 |
| **M2 战斗完整** | B3 手感批；B4 法术批；B5 兵种批 | 盾反四断言套；正式场景施法 E2E；纵火兵/都尉行为契约（ai_states 首套） | 割草爽点成立、都尉逼出弹反、法术在壳场景可用 |
| **M3 序章闭环** | B6 内容装配批；B7 过场衔接批 | validator 全绿+`stage_contract` 不受双轨扰动；过场降级 1 断言；全链路 E2E（过场→五段→尾声） | 完整序章一命到底可玩，出"想不想玩第一章"的判断素材 |

每批收尾：全矩阵（23+新增套）+ 文档同步（法典/食谱/PLUGIN_ARCHITECTURE 涉插件处
同批）+ PLUGIN_CHANGES 案卷。

## 9. 风险登记

1. **B1 是本仓最大单次手术**（骨架五职责上移+契约 128 条基线双轨）：plan 步骤级
   拆解、BaseStage 消费方改薄但**公共行为逐条契约护航**、批内设回滚 tag；
2. 段检查点与既有 `pending_jump_stage`（地点级）分层：段在章节内，跳地点仍是
   重载——两套语义在壳内明确互斥边界（段重跑不重载场景）；
3. 护人阶段切换（攻守换挡）是演出+数值复合，若手感别扭降级为纯数值档（去掉
   攻击换招动画，留减伤+弹反窗放大）；
4. 用户并行 WIP（stage0/章节素材）与批次冲突：`.wip` 豁免继续有效直到 B7 转正，
   素材文件暂存逐路径纪律不变。
