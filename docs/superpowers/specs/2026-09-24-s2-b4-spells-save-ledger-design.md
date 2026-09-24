# S2-B4 法术接入 + 存档账本体制 · 设计文档

日期：2026-09-24 ｜ 状态：已批准（裁决记录见 §10）
输入：S2 切片设计案 §5.2（本文件对其"零新代码"有**显式改案**，见 §9 差异）；
2026-09-24 用户长讨论七项裁决（§10）；B3 关账后的 F5 修复链（白闪判例等）。

## 0. 定位

本批交付玩家侧法术的**生产可用性**（现在按 1-4 全游戏无反应：法术零件全绿，但
`learn_spell` 生产调用点=0），并借此契机把"游戏什么该记住"从口头约定升级为
**机器执法的单账本体制**（GameSave）——后续物品、装备、剧情状态全部沿用此门。
插件核心区（addons/）**零手术**；B4.5 存档批（落盘+标题续档）紧随本批。

## 1. 范围

**本批做**：GameSave autoload 立户（吸收 ChapterSession 四账+新户 spells_known）、
执法五门+申报单、契约"重演=清账"语义改判、《秘籍》反应件、玩家出生补学、
SpellRegistry 约定路径解析、正式壳场景 E2E 新套（矩阵 23 套=25 跑）、
validator 装配查重、标题"新游戏"=建档清账、文档收口。
**本批不做**（各归其批）：落盘/读档 UI/槽位（B4.5，§8 概要）；褚遂愿建角
（占位纪律=chen 皮即序章皮，人物等美术，B6）；第二门法术（美术无图）；
双检查点表合并（GameEvents 地点级 vs 段级，B4.5）；多手动槽。

## 2. 状态模型宪章（单账本）

```
GameSave（autoload，内存账本，随进程活）
 ├─ flags / chests / cleared_segments / checkpoint   ← ChapterSession 四账搬家
 ├─ spells_known（本批新户）及后续一切持久事实
 ├─ 硬盘 = 账本快照（B4.5 落地；本批交付 to_dict/from_dict + roundtrip 锁）
 └─ 场景实例 = 账本的易失投影（重建时查账决定外观，如宝箱已开不再吐宝）
```

- **存档生命周期**：开局只有两种——**新开局**（`new_profile()` 清账建档，
  唯一重置口）/ **读档**（B4.5；本批=内存快照还原）。废除"重跑/回跳/换章=清账"
  的会话概念：这些动作全部**不碰账**；无存档导致的丢失=正常（用户裁决）。
- **读档/回检查点=满状态复活**：生命/法力/池/冷却一律不入账——它们可由
  "检查点段入口落位+满状态"规则推导（与现行死亡段重跑 D4 同一条腿；
  `_revive_playable` 已是这条腿的内存版，B4.5 读档复用它）。
- **入册纪律**：账本值只收普通类型（bool/int/String/StringName 及上述数组），
  API 运行时校验拒收 Object 类值——S5 落盘日=一个字典写盘，不许有格式惊喜。
- **入册键命名空间**：`StringName` 键带章前缀惯例（如 `ch0_manual_fireball`），
  同章内由 validator 查重（§3 门五）。

### 2.1 判定三连问（人填申报单时的思考工具）

1. 游玩中会变吗？不变→内容，永不入册；
2. 不存能推导吗？能（段内敌人=场景自带；复活血量=满状态规则自带）→不入册；
3. 不可推导时，"重演一遍"玩家能接受吗？能（敌人重打）→豁免申报；
   不能（宝箱吐钱/秘籍重捡/剧情重播）→入册。

判项表（哪些存哪些不存的总表）由全部申报单**自动汇总生成**——文档是报表不是公约。

## 3. 执法体制（五门+申报单，全部机器检查）

| 门 | 机制 | 拦截形态 |
|---|---|---|
| 一门·单一门洞 | 账本只经 `record(ns,id)` / `has_record(ns,id)` / `ids(ns)` 读写；namespace 须先经 `claim_namespace(ns, owner)` 开户，未开户写入=push_error+拒写。flags/chests/cleared 为系统户（GameSave 自开） | 绕门私存 |
| 二门·类型闸 | `record()` 校验值域（§2 入册纪律），违规拒写报错 | 存了存不了的东西 |
| 三门·申报单+清点 | 反应件基类 `InteractReaction.save_claim() -> Dictionary`（`{&"persists": [ns...], &"resets": [ns...]}`）三件齐报；静态扫描契约腿：①账本内部结构私有（`_ledges`），门洞之外直戳内部者=0（白名单自证）②`reactions/` 每个子类必须实存 `save_claim` ③每个反应件类名必须出现在重演套名册（每类型至少一腿） | 新件不填表/零重演腿/绕门直改内部 |
| 四门·重演等价（主力） | 脚本化操作序列跑两遍：第一遍记行为流指纹；账本 `to_dict→new_profile→from_dict` 假存档还原后重跑同序列；**双向断言**=入册项必须不变（还会/不再吐宝）+豁免项必须重置（敌人复活）。忘注册的持久态在第二遍必然分叉 | "它觉得不用记，直到玩家发现" |
| 五门·装配防呆 | validator 新规则（R12）：章节段内反应件实例 id 非空、同账本户 id 全章唯一（两件争一笔账=红） | 配置撞号互踩 |

**注册即验门（R8）**：新套入册前先故意造两种真实劣化（秘籍件删 record→四门红；
注入一处裸下标写→三门红），红档贴报告后再复原证全绿——无红据不入册。

## 4. 法术机制

- **《秘籍》反应件 `InteractSpellBook`**（家族第四型，chest 同门形制）：
  `@export spell_id`（要学的法术）、`@export manual_id`（账本键，默认=spell_id）。
  E 触发→`record(&"spells_known", manual_id)` 首开=即时对 `shell.playable`
  执行学习→无论首开与否 consume+消失演出（再出现也不吐第二份，与 chests 同法）。
  申报单：persists=[spells_known]。
- **出生补学**：玩家壳 `chen.gd` / 模板 `__NAME__.gd` `_ready` 尾，经
  `get_node_or_null(^"/root/GameSave")` 守卫取账（`-s` 无 autoload 环境静默跳过），
  对 `ids(&"spells_known")` 逐个 `learn_spell(SpellRegistry.definition_for(id))`。
  节点会重建（换章/回跳/测试接缝/读档）、账不重建——补学就是两者的胶水。
- **SpellRegistry**（`spells/_base/spell_registry.gd`）：
  `static func definition_for(spell_id) -> SpellDefinition`，约定路径
  `spells/<id>/resources/<id>_definition.tres`，缺件=null+push_warning。
- **键权现状**：模板壳法术键走私有输入通道（AI/被动出生即无劫持，B 前批已解）；
  本批仅加验证腿钉住"AI 档按 1-4 无反应"现状，不新建机制。
- **数值面**：零新 attributes 字段；火球数值全部现件（def tres）。

## 5. 契约套设计（`tools/spell_save_contract/`，矩阵第 24 套）

场景 runner 套（lane/block_parry 血统），流=F 按任务生长：
- **S 流（T0）**：门洞（未开户 ns 拒写）、类型闸（Object 值拒收）、幂等
  （record 首 true 再 false）、to_dict/from_dict roundtrip 逐键相等、
  new_profile 清零。
- **M 流（T1）**：迁移回归——壳消费四账行为逐位等价（flag/chest/cleared/
  checkpoint 语义不变仅主体换）；`new_profile` 后旧壳新壳互不污染（隔离纪律）。
- **G 流（T2）**：秘籍（E→学会→再 E 不重发）、补学（学会→清节点→重建实例→
  仍会；无 autoload 环境不炸）、SpellRegistry 缺件降级。
- **E 流（T3）**：正式壳 fixture（chapter_shell+秘籍+spar 敌）按 spell_1 →
  Cast 状态 → 弹体出现 → 敌血下降（生产链端到端）。
- **R 流（T3）**：重演等价双跑+双向断言（§3 门四）+申报单名册腿+静态清点腿。

夹具：`fixtures/seg_b4_manual.tscn`（秘籍段）、复用 fixture 章壳形制
（playable_override=test_actor，ATTEST 登记 ACTOR-GATE）。

## 6. 迁移与改判

- `chapter_session.gd` **退役删除**；`ChapterShell.session` 属性保留但改指向
  `/root/GameSave`（消费方 `shell.session.xxx` 零改动）。API 全兼容：
  `add_flag/has_flag/open_chest/is_chest_open/mark_cleared/is_cleared/
  record_checkpoint/checkpoint_segment/checkpoint_entry` 原签名迁入 GameSave，
  底层统一走 record 门洞；三信号（flag_added/chest_opened/segment_cleared）随迁。
- **单例隔离纪律（最大雷）**：一进程多壳的契约套（container/interact 数十壳）
  旧语义=每壳新账，新语义=账随进程。**每条建壳流水的起点显式
  `GameSave.new_profile()`**；"重演=清账"判据的存量腿全部改判为
  "新档=清账/还原=保账"，改前先出红档留证。
- `title_screen._start_game()` 前置 `GameSave.new_profile()`（开始游戏=建档）；
  "读取存档"钮维持置灰，TODO 注释改指 B4.5。
- project.godot `[autoload]` 增 `GameSave="*res://scripts/save/game_save.gd"`
  （列 GameEvents 之后）——吞改判例序列：Windows 端关编辑器→改→同步→重开验。

## 7. 风险与对策

1. **隔离泄漏**（某流水忘 new_profile→串账）：泄漏表现=跨腿串值响亮红，
   好诊断；S 流加"两壳互不清账"显式腿兜语义。
2. ** chen.gd 非 git + 模板双写漂移**：动前 tar 备份；补丁两处同文；
   test_scene_parity/wp3 既有镜像检查复跑。
3. **project.godot 回写吞改**（本月两案）：编辑器关闭时序纪律写进 F5 单头部。
4. **补学时序**：autoload 先于场景 _ready 入树（引擎保证）；`-s` 环境经
   get_node_or_null 守卫静默；契约腿覆盖两形态。
5. **重演指纹非确定性**：指纹只采账本可查的确定观测量（血降/布尔/计数），
   禁止采集敌人 AI 自由度。

## 8. B4.5 存档批概要（防漂移占位，另立 spec）

SaveSystem autoload：`to_dict()` JSON 写 `user://save_auto.json`（tmp→rename
原子写+version 字段+失败 push_error 不扰 gameplay）；触发=落段
`record_checkpoint` 处+事实写入处+`chapter_finished`；标题「继续」=
from_dict+回检查点段入口+满状态（复用 `_revive_playable` 同一条腿=
"回到检查点"三通道合一）；双检查点表合并；重演套的假存档源换成真盘（套零改动）；
真端到端新套（写盘→清内存→还原，杀进程级冷启动归 F5 眼）。

## 9. 与切片案 §5.2 差异表

| 切片案原句 | 本批实际 | 理由 |
|---|---|---|
| "零新代码" | 新增 GameSave/申报单/秘籍件/registry/新契约套 | 讨论实锤：learn 通路=0 是生产缺口；单账本体制是用户裁决的还债 |
| "褚遂愿面板开 spell 键权" | chen 占位验证+键权现状钉腿；褚遂愿缓建 | 占位纪律（§6 切片案自己定的） |
| "mana HUD 已有" | 成立，零动 | 实查一致 |

## 10. 裁决记录（2026-09-24，全部用户签字）

1. 单账本模型，废除会话/重演清账概念；开局=新开局/读档二选一；无存档丢失=正常。
2. 读档/回检查点=满状态复活（生命法力不入账）。
3. 槽位=单自动档+新游戏覆盖确认（多槽缓建）。
4. B4.5 存档批紧随 B4（B5 前齐装）。
5. 法术获得=剧情道具《秘籍》；第二门不做。
6. 扩展保障必须机制化，不靠文档约定。
7. "什么该存档"的决定权归人但必须显式申报+双向重演钉死，变更=改申报单留痕。
