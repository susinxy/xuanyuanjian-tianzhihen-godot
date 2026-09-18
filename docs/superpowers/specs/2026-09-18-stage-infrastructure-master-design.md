# 正式关卡基础设施补齐计划 · 总纲

- 日期：2026-09-18
- 状态：待终审
- 性质：**总纲**——只钉六个子项目的边界、相互契约与施工顺序；
  每个子项目开工前各自召开自己的细案设计会（两级结构，用户已确认）
- 基线裁定：正式关卡以"**全体验**"为验收基线（战斗+剧情+掉落+成长+存档+音频），
  实施分期，但每项都必须在册

---

## 1. 命题与验收定义

**命题**：本项目尚无一个能按 F5 进去打的正式关卡。关卡是"内容装配"，
装配前必须把基础设施验收齐备。本总纲回答：以正式关卡为目标，基础设施缺什么、
按什么顺序补、子项目之间以什么契约互相咬合。

**最终验收态**（全部 S 完工后的画面）：

> 标题画面开场 → 进入第一章正式关卡（真背景、昼夜光照、开场对话）→
> 走进战斗房镜头锁定、波次敌人刷新（种类成编制）→ 全灭解锁、掉落实体可拾取
> （回血道具/装备/剧情道具）→ 经验入袋、关键剧情点自动存档 → 出关转场；
> 中途 ESC 可暂停、音乐音效全在位；玩家死亡出结算画面，可重开或回标题，
> 可从存档历史的任意备份恢复游戏。

**硬缺口盘点依据**（2026-09-18 双路调查实录）：插件关卡四件套
（FightRoom/PlayerDetector/EnemySpawner/LevelCamera）与 BackgroundLoader、
ScreenTransitions 原生齐备且**内部接线自愈**（检测器 `_ready` 自连"锁相机→刷怪"）；
项目侧 `scenes/` 为空、`run/main_scene` 不存在、暂停零实现、
`player_died` 仅有自我清理型订阅者、`transition_to_scene` 零调用方、
Dialogic 仅注册 autoload 零接线、项目侧音频资产计数为 0、
game_hud/昼夜控制器为"功能完好但从未进过正式场景"的孤儿件。

---

## 2. 全局公共设施与目录标准（S1 立法，其余沿用）

### 2.1 GameEvents（项目侧事件总线，新建 autoload）

插件 `Events` 保持上游原貌（仅 player_died / enemy_defeated / characters_reseted）。
一切**项目概念**的事件走新的 `scripts/game_events.gd`：

- `room_cleared(room_id)` ——房间全部波次清场
- `flag_set(key, value)` ——剧情旗标变化（S3 定义存储，S5 消费）
- `item_picked(item_id, count)`、`xp_gained(amount)`、`level_up(new_level)`
- `story_checkpoint_added(stage_id)` ——`add_checkpoint` 直写注册表后发射；
  自动存档触发源（S5 唯一订阅义务方）
- 音频钩子约定：S6 只订阅事件，不要求任何系统主动调用它（零侵入原则）

### 2.2 目录标准

```
scenes/base/base_stage.tscn (+ base_stage.gd)   关卡父场景：骨架+流程壳挂接点
scenes/stages/ch01/stage_*.tscn                 正式关卡，继承 base_stage
ui/menus/                                        标题/暂停/结算 三件套（S1）
dialogue/                                        Dialogic timeline 等资源
                                                 （填掉 project.godot [dialogic] 三个空目录配置）
items/                                           ItemDefinition tres + ItemPickup 场景（S3）
saves/  (user://，仓库外)                         history/ 与 backups/ 两区（S5）
scripts/game_events.gd                           项目事件总线
```

---

## 3. 子项目册页

### S1 关卡骨架与流程壳（地基，先行）

**状态**：（2026-09-18 交付，F5 待验）

**边界**：base_stage 父场景、流程壳（标题→进关→暂停→死亡结算→重开/回标题）、
切场链路首次接通、装配件入场规范、波次策划工作流（校验器）。
**不含**：真背景美术、对话、掉落、成长、存档、音频（只留挂点）。

关键契约与装配规范：

1. 节点树照上游四段式：`Background(CanvasLayer，占位批=debug_background 渐变+
   全屏 ColorRect 地面条) / Level(Characters|Objects|Collisions) /
   Foreground / FightRooms / HudLayer`，增设 `Ambient`（CanvasModulate+光源，
   DayNightController 入场位）、`GameHUD`（实例化 ui/game_hud.tscn）、`PauseLayer`。
2. **装配契约**（血泪雷区成文）：
   - 关卡相机实例挂在**玩家角色节点之下**（插件相机零跟随代码，靠父子变换）；
   - 检测器+生成器作为 FightRoom 矩形子节点摆位；检测器 `path_fight_room` /
     `paths_enemy_spawners` 由 `_ready` 自愈接线，锁相机先于刷怪（插件已保证）；
   - Spawner 的 `path_spawn_parent` **每房间必须显式改写**（默认值在标准层级下是错的）；
   - 屏限层 3/4 由高度层体系运行时接管，装配勿手配掩码；
   - `all_waves_completed → setup_after_fight_room` 的解锁胶水归 `base_stage.gd`
     （多生成器聚合判定，参照上游 stage_01.gd 模式）。
3. 暂停：`get_tree().paused` + 菜单 `process_mode=WHEN_PAUSED`（Godot 官方范式）；
   战斗冻结与行为档 `active` 开关语义对齐（S2 对话同样依赖此门）。
4. 死亡：`Events.player_died` 的第一任**流程**订阅者在结算层——
   重试=发 `Events.characters_reseted` 并重载本关；回标题=走 ScreenTransitions。
5. 波次工作流：维持插件波次数据形态（spawn_waves），新增 **headless 关卡校验器**
   （无出口房间/生成器指向缺失/波次空表/Spawner 忘记改写 path_spawn_parent →
   报错清单），与 stage_contract 一并入测试矩阵（矩阵 20 → 22 项）。

**验收**：`stage_contract` 测试套（进房→锁相机→刷怪→全灭→解锁→出关全自动断言）+
F5 走通"标题↔关卡↔死亡↔重开↔暂停"闭环。画面允许全程占位美术。

### S2 对话接入竖切

**边界**：立"对话触发契约"，不写正文剧情。
- `DialogicTrigger` 场景节点：三类挂点（进房触发/物件触发/room_cleared 触发），
  引用 timeline 资源；
- 对话⇄战斗互斥实测：Dialogic 树暂停 + 全体行为档 `active=false` 联动；
- `dialogue/` 目录配置落地；一条冒烟 timeline（内容无意义，纯链路证明）。

**验收**：对话触发契约测试（触发→战斗冻结→对话结束→恢复）+ F5 冒烟。
**降级预案**（在案）：Dialogic 为 alpha-20，若实测阻断，先以简化自研气泡对话
跑通同一触发契约，接口不变，Dialogic 后补。

### S3 掉落与拾取

**边界**：
- `ItemDefinition` 资源（图标/类型/效果/是否剧情道具）；
- 掉落表：敌人死亡（订阅 `enemy_defeated` 或 spawner 通知）→ 按权重生成本作场景道具；
- `ItemPickup` 场景：参与高度层，可被拾取（回血/回蓝即时生效或入袋，细案定）；
- **道具袋 API**：`Inventory.add/has/count`；
- **旗标 API**：`GameEvents.set_flag/get_flag`——剧情推进的唯一原语，
  剧情道具=旗标写入方。

**验收**：drop_contract（权重分布抽样、拾取入袋、剧情道具→旗标→触发器响应）。

### S4 成长系统（自带数值设计会）

**边界登记（总纲不预设数值）**：
- 经验/等级/装备槽（weapon/armor/accessory 经典三槽为候选）/属性曲线；
- **两条硬事实入册**：
  1. 伤害公式改造点在 `CombatSystem.apply_damage`
     （现为裸减法 `health_current -= attack_damage`），
     成长落地时改为 `f(攻,防,等级修正)`——对战斗层的唯一合法侵入位，
     届时走插件修改流程（PLUGIN_ARCHITECTURE/PLUGIN_CHANGES 同批）；
  2. 属性扩展建议走 QuiverAttributes 增导出字段（与血量同家，
     数据与判定点同层——统一模型先例），装备 schema 独立资源。
- 法术习得双轨：升级曲线习得 + 剧情节点授予（S2/S3 已有旗标通道）。

**前置**：S3（装备经掉落供给）、S1（关卡内经验结算宿主）。
**验收**：growth_contract（经验入账、升级属性重算、装备穿脱即时生效、
伤害公式新旧回归对照）。

### S5 存档系统（天然最后）

**用户规格原样入册**：关键剧情节点自动存档；**不提供手动存档**；
保留存档历史（可浏览）；任意历史可**转正为备份**；随时可从对应存档开局。

- `SaveGame` autoload + user:// JSON 两区（history/、backups/）；
- **存档内容=各子系统自报序列化**：约定 `serialize()/deserialize()` 接口，
  S2 旗标、S3 道具袋、S4 成长快照、玩家位置/当前房间 id——
  S5 只编排不发明数据（此即其必须最后施工的原因）；
- 触发源= `GameEvents.story_checkpoint`；
- 版本号字段 + 迁移策略（业界成熟做法）。

**待 S5 设计会裁决的体验题（届时给三选一，不开开放题）**：历史保留份数与滚动策略。
**验收**：save_contract（写入→读回→全系统状态一致；备份→恢复→一致；版本迁移）。

### S6 音频管线（半独立，S1 后随时并行）

- `AudioManager` autoload + 三总线 BGM/SFX/UI（Godot 原生 AudioServer；
  **明确不上 FMOD/Wwise**——对本项目是过度工程）；
- 挂点全部事件订阅（命中、受击、room_cleared、对话开始/结束……），零侵入产品代码；
- 占位素材走公共领域源；正式音频纯美术排期，不卡工程。

**验收**：F5 听感清单（占位素材版）+ 总线音量设置留存（与 S5 设置项对接）。

### C 抓取契约测试（在册小件，任意时点插队）

抓取机制插件内完整存在但零测试。纯测试批不动产品代码：
grab（起手→抓取→追击→伤害/投技→释放/挣脱）全链断言入矩阵。

---

## 4. 施工顺序与依赖

```
S1 ──→ S2 ──→ S3 ──→ S4 ──→ S5         （串行主线；箭头=前置依赖）
 │
 └───────────→ S6                       （S1 完成后即可并行）
 C                                    任意时点插队
```

理由链：S1 不立，其余各项连"在哪里被验收"都没有；S5 存的是各系统数据形状，
先做等于给移动靶刻章；S4 数值设计会须等 S3 掉落形态已知（装备表才谈得实）。

每个 S 的统一完成判据（三条缺一不可）：
1. 自己的契约测试进矩阵（裸输出零失败）；
2. F5 人工清单勾验；
3. 文档同批（碰插件必同步 PLUGIN_ARCHITECTURE + PLUGIN_CHANGES；
   目录/流程标准变更同步 AGENTS.md 与相关 README）。

---

## 5. 对标锚点与研究义务（用户裁定：业界成熟形态优先，不发明轮子）

**制度**：每个子项目设计会的第一项议程固定为"对标研究呈报"——
工程侧（AI）预先把该领域成熟方案调研完，带对标表与推荐来；
用户只从玩家体验角度裁决取舍，不担任技术裁判。

| 子项目 | 主要对标源 |
|---|---|
| S1 | Godot 官方暂停/场景管理范式；上游 template-beat-em-up 的 base_stage/stage_01 装配形态 |
| S2 | Dialogic 2 官方推荐模式（Area2D 触发 + timeline——工具自身即业界标准件） |
| S3 | 清版动作游戏掉落惯例（快打旋风系当场拾取回血）；冒险游戏 key item + flag 标准模式 |
| S4 | **轩辕剑原作《天之痕》系统**（属性构成/法术按级习得/物品体系）为第一参照；公开 XP 曲线公式族与装备槽 schema 为第二参照 |
| S5 | 动作游戏主流 checkpoint + auto-save + 槽位备份形态；Godot 社区 JSON 存档+版本迁移惯例 |
| S6 | 三总线结构与事件订阅挂点（Godot 原生能力内）；打击感"顿帧+音效"双层反馈 |

已识别的"业界有标准答案，直接照抄"清单：暂停冻结、事件驱动音频、
掉落表加权、存档版本号迁移、旗标系统。
两处"体验题留给用户届时拍板"：S4 等级上限与数值跨度（原作怀旧手感 vs 现代曲线）、
S5 历史份数与滚动策略。

---

## 6. 风险登记

1. **Dialogic alpha-20 稳定性**：S2 首验即知深浅；降级预案在案（§S2），
   触发契约先行保证无论哪套对话实现，关卡侧接口不变。
2. **S4 战斗公式改造**侵入插件核心：影响面=全部既有战斗测试，
   需新旧公式回归对照测试先行（growth_contract 内建）。
3. **project.godot 变更**（主场景/autoload/dialogic 目录）受"编辑器回写"纪律约束：
   改动窗口须 Windows 端关闭编辑器，改后重启验证。
4. **playable 角色资产非 git 管理**：S3/S4 若动 chen 出生数据需按纪律先出回滚包。
5. 波次校验器与装配契约依赖"文档即法律"：装配规范若不入 README/AGENTS
   即视同未交付。

---

## 7. 本总纲的出口

总纲通过后，本设计会解散，产出移交：

1. 本文档入库（git）；
2. **S1 细案设计会**立即排期（工程侧先完成 §5 所列 S1 对标调研）；
3. S2-S6、C 各自排队，开会前重复"调研→澄清→细案→计划"同构流程；
4. 既有近期挂账顺带并入：`_beat_em_up/` 目录已建的 AGENTS 陈旧句修正、
   实验田 `characters/playable/testme/`、`test/` 清理（随 S1 装配批处置）。
