# S2-B4 法术接入 + 存档账本体制 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 玩家在生产游戏里按 1 真能丢火球（《秘籍》拾得即学、重建节点仍会），并把"什么该记住"升级为机器执法的单账本体制（GameSave：门洞+类型闸+申报单+双向重演+装配查重）。

**Architecture:** `GameSave` autoload 吸收 ChapterSession 四账成唯一账本，场景=账本的易失投影，"回到检查点"（死亡/回跳/未来读档）共用一条腿；法术走 SpellRegistry 约定路径 + 反应件申报单 + 玩家出生补学；新契约套 `spell_save_contract` 承载执法五门的实体（含 R8 故意破坏红据）。插件核心区零改动。

**Tech Stack:** Godot 4.7 GDScript；场景 runner 契约（lane/block_parry 血统）+ headless；`run_matrix.sh` 名册 23 套=25 跑（本批 +1）；validator 文本级扫描。

**Spec:** `docs/superpowers/specs/2026-09-24-s2-b4-spells-save-ledger-design.md`（§2 宪章、§3 五门、§5 流定义、§6 迁移改判、§10 七裁决是法源；冲突以 spec 为准）。

## Global Constraints

- GDScript 4；**注释一律中文**；提交 `feat:/fix:/docs:/test:` 中文；**逐路径点名 add，永久禁 `git add -A`**。
- 用户 WIP 不碰：`scenes/stages/xuanyuan-chapter-1/**`、根目录 mp4。`characters/playable/chen/**` 非 git：**动前 tar 备份**（`/tmp/opencode/b4_t*/`），且与 `templates/character/__NAME__.gd` **同文双写**（模板入库）。
- **`project.godot` 吞改纪律（本月两案）**：改前提醒 Windows 关编辑器；改后要求重启编辑器再验收。本批唯一触点=`[autoload]` 加 `GameSave="*res://scripts/save/game_save.gd"`（紧邻 GameEvents 行后）。
- **addons/ 零改动是本批红线**；若实施中发现必须碰插件，停下来上报，不许顺手。
- 账本纪律（spec §2/§3）：入册值只收普通类型（bool/int/float/String/StringName 及上述 Array，一层嵌套内）；键一律 StringName；**flags/chests/cleared_segments 存量 API 原签名兼容，新内容一律走 `record/has_record/ids`，禁止再造四账式专用包装**。
- 隔离铁律：GameSave 是单例，一进程多壳——**一切建壳流水起点显式 `new_profile()`**；跑契约若出现跨腿串值，先查漏调，别急改判据。
- headless 判例全套：新 class_name 后 `--import` 一次；`-s` 环境无 autoload，触达 GameSave 一律 `get_node_or_null(^"/root/GameSave")` 守卫；`.tscn` 无注释、`&"…"`、load_steps=ext+sub；Vector2 类属性写完整构造式；独立完成旗防协程静默跳段；轮询已释放预存 instance id。
- 重演指纹禁采非确定源（敌人 AI 自由度）；只采账本可查观测量。
- 基线：批前矩阵 23 套=24 跑全绿（B3 关账态）；T1/T2 分层复跑 container+interact；**全矩阵只在 T3 注册后与 T4 批末各跑一次**。

---

## 文件总图

| 动作 | 路径 | 责任 |
|---|---|---|
| Create | `scripts/save/game_save.gd` | 账本核心（autoload，无 class_name，GameEvents 同形制）（T0） |
| Modify | `project.godot` | `[autoload]` 入册 GameSave（T0） |
| Delete | `scripts/chapter/chapter_session.gd`(+.uid) | 退役（T1） |
| Modify | `scripts/chapter/chapter_shell.gd` | session 改指向 GameSave + 缺席兜底（T1） |
| Modify | `ui/menus/title_screen.gd` | 开始游戏=`new_profile()`；读档钮 TODO 改指 B4.5（T1） |
| Create | `spells/_base/spell_registry.gd` | id→definition 约定路径解析（T2） |
| Create | `scripts/chapter/reactions/interact_reaction.gd` | 反应件基类 + `save_claim()` 申报单（T2） |
| Modify | `scripts/chapter/reactions/interact_{chest,gate,qte}.gd` | 挂基类+补申报（T2） |
| Create | `scripts/chapter/reactions/interact_spell_book.gd` | 《秘籍》第四型（T2） |
| Modify | `characters/playable/chen/chen.gd`（非 git）+ `templates/character/__NAME__.gd` | 出生补学块（T2） |
| Create | `tools/spell_save_contract/{spell_save_contract.gd,.tscn}` + `fixtures/seg_b4_manual.tscn`(+章壳夹具) | 新套 F/R/S/M/G/E 流逐任务生长（T0-T3，矩阵第 24 套） |
| Modify | `tools/container_contract/container_contract.gd`、`tools/interact_contract/interact_contract.gd` | new_profile 隔离 + "重演=清账"腿改判（T1） |
| Modify | `tools/stage_validator/validator.gd` | R12 反应件 id 非空+全章唯一（T3） |
| Modify | `tools/matrix_runner/run_matrix.sh` | 名册+ATTEST（T3） |
| Modify | `docs/STAGE_ASSEMBLY.md`（条十一）、`DEVELOPMENT_STATUS.md`、根 `AGENTS.md`（非 git，矩阵 24/25+账本法） | T4 |
| Create | `docs/superpowers/plans/2026-09-24-s2-b4-spells-save-ledger-f5.md` | F5 单（T4） |

**Interfaces（跨任务钉名，产出即契约）：**

```gdscript
# scripts/save/game_save.gd（autoload 单例，extends Node）
record(namespace: StringName, id: StringName, value: Variant = true) -> bool   # 首记 true/重复 false；未开户 ns 拒写 push_error；类型闸
has_record(namespace: StringName, id: StringName) -> bool
ids(namespace: StringName) -> Array             # StringName 键清单
claim_namespace(namespace: StringName, owner: StringName) -> void   # 幂等开户
new_profile() -> void                            # 全账清空（含 checkpoint）
to_dict() -> Dictionary / from_dict(data: Dictionary) -> void   # JSON 兼容；from_dict 把 String 键归一化回 StringName
# 四账兼容层（原签名迁入，底层=record 门洞）：
add_flag(id)/has_flag(id)/open_chest(id)/is_chest_open(id)/mark_cleared(id)/is_cleared(id)
record_checkpoint(segment, entry)/checkpoint_segment()/checkpoint_entry()
# 信号随迁：flag_added/chest_opened/segment_cleared
# 系统户常量：NS_FLAGS=&"flags" NS_CHESTS=&"chests" NS_CLEARED=&"cleared_segments" NS_SPELLS=&"spells_known"

# spells/_base/spell_registry.gd（class_name SpellRegistry extends RefCounted）
static func definition_for(spell_id: StringName) -> SpellDefinition
# 约定路径 spells/<id>/resources/<id>_definition.tres；缺件 null+push_warning

# scripts/chapter/reactions/interact_reaction.gd（class_name InteractReaction extends Node）
func save_claim() -> Dictionary   # {&"persists": [ns...], &"resets": [ns...]}；基类默认 push_error"子类必须申报"
# InteractSpellBook：@export spell_id: StringName、@export manual_id: StringName（空则=spell_id）
```

---

### Task 0: GameSave 立户 + 契约套骨架（S 流）

**Files:**
- Create: `scripts/save/game_save.gd`
- Modify: `project.godot`（仅 `[autoload]` 一行）
- Create: `tools/spell_save_contract/spell_save_contract.gd` + `.tscn`

- [ ] **Step 0:** `cp project.godot /tmp/opencode/b4_t0/project.godot.bak`；确认 Windows 编辑器已关（派单前向用户要口令，未确认前此步挂起——其余 Step 可先行）。
- [ ] **Step 1: 失败测试先行**——契约套骨架（scene runner，抄 block_parry 头形制：`_finished` 旗+`_check` 汇总+横幅）S 流断言：未开户 ns 写入返回 false 且账本无此键；`record(NS_SPELLS,&"x")` 首 true 再 false；`has_record/ids` 行为；类型闸：塞 `Node.new()` 值拒写；`to_dict→from_dict` 逐键相等 **且 from_dict 后键仍是 StringName**（`is StringName` 断言——JSON 归一化判例点）；`new_profile` 清零一切。跑 `godot --headless --path . res://tools/spell_save_contract/spell_save_contract.tscn` 必红（GameSave 不存在）→ 记红档。
- [ ] **Step 2:** 实现 game_save.gd：内部 `_ledges := {ns: {id: value}}` + `_checkpoints`（Array[StringName] 两段，兼容 checkpoint 语义）；按 Interfaces 全量实现；四账兼容层+三信号+`_ready` 自开系统户（NS_FLAGS/NS_CHESTS/NS_CLEARED；NS_SPELLS 由 InteractSpellBook claim，但为 T0 先行可用亦列入系统户——注释申报此决定并留 T2 复查）。类型闸用 `typeof` 白名单，Dictionary/Array 递归一层。
- [ ] **Step 3:** `project.godot` `[autoload]` 在 GameEvents 行后加 `GameSave="*res://scripts/save/game_save.gd"`；`--import` 一次；S 流全绿。
- [ ] **Step 4:** 哨兵复跑 `block_parry_contract` + `stage_contract`（后者吃 GameEvents/reset 链）绿；提交：`feat: GameSave 单账本立户——门洞+类型闸+申报开户+JSON 兼容快照，契约 S 流入册`。报告标注 Windows 重启编辑器核验 autoload。

---

### Task 1: 壳迁移 + 契约改判（重演→新档语义）（M 流）

**Files:**
- Modify: `scripts/chapter/chapter_shell.gd`（`:32` session 改指向）
- Delete: `scripts/chapter/chapter_session.gd`(+.uid)
- Modify: `ui/menus/title_screen.gd`
- Modify: `tools/container_contract/container_contract.gd`、`tools/interact_contract/interact_contract.gd`（new_profile + 改判）
- Modify: `tools/spell_save_contract/`（+M 流）

**Interfaces:**
- Consumes: T0 GameSave 全 API。
- Produces: `shell.session`（类型 Node，指向 `/root/GameSave` 或兜底实例）——**所有既有消费点零改动**；"每流水起点 new_profile"隔离规约（T3 夹具沿用）。

- [ ] **Step 1: 先出改判前红档**——在 container/interact 两契约各找"新壳=新账"依赖点（`grep -n 'ChapterSession\|session' tools/container_contract/*.gd tools/interact_contract/*.gd` + 跑现状留绿基线），在报告登记将改判的腿清单（预期集中在：重演语义组、多壳互不污染组、E7/SEAM 腿）。
- [ ] **Step 2:** 壳迁移：`var session: Node = null`；`_ready` 首段（换人接缝前）`session = get_node_or_null(^"/root/GameSave")`，null 则 `session = load("res://scripts/save/game_save.gd").new()` 并 `add_child` 兜底（独立夹具场境注释申报）；**chapter_session.gd 删除**（先 `grep -rn 'ChapterSession' --include='*.gd' --include='*.tscn' .` 确认零残留引用）。
- [ ] **Step 3:** 契约隔离改造：两契约所有"新建壳并驱动"的 helper/流水起点统一插 `GameSave.new_profile()`（-s 场景不存在此问题——两都是 scene runner，autoload 在场）；按 Step 1 清单把"重跑/换壳=清账"语义腿**改判**为"new_profile=清账、还原/换段=保账"；跑两套直到绿（改判期允许先红，红→绿过程记报告）。
- [ ] **Step 4:** M 流新腿：两壳先后建、A 壳开宝箱后 B 壳不 new_profile 仍见旧账（单例本性显式钉死）+ new_profile 后互不污染（隔离规约）。
- [ ] **Step 5:** title_screen：`_start_game()` 首行 `GameSave.new_profile()`；`读取存档` 钮注释 TODO(S5)→TODO(B4.5)（仍置灰）。
- [ ] **Step 6:** 分层复跑 container+interact+spell_save 三套全绿；提交：`feat: ChapterSession 退役并入 GameSave 单例——契约改判"新档=清账"，单例隔离规约+M 流入册`。

---

### Task 2: 法术接入（registry+申报单+秘籍+补学）（G 流）

**Files:**
- Create: `spells/_base/spell_registry.gd`
- Create: `scripts/chapter/reactions/interact_reaction.gd`
- Modify: `scripts/chapter/reactions/interact_{chest,gate,qte}.gd`（挂基类+申报）
- Create: `scripts/chapter/reactions/interact_spell_book.gd`
- Modify: `characters/playable/chen/chen.gd`（先 tar 备份）+ `templates/character/__NAME__.gd`（补学块同文）
- Modify: `tools/spell_save_contract/`（+G 流）

- [ ] **Step 1:** SpellRegistry + `--import`；G 流先写失败腿：`definition_for(&"fire_ball")` 返回非 null 且 `spell_id==&"fire_ball"`；`definition_for(&"no_such")` 返回 null 不崩。
- [ ] **Step 2:** InteractReaction 基类（save_claim 默认 push_error）；三存量件挂基类并如实申报（chest: persists=[NS_CHESTS,可选 NS_FLAGS]、resets=[]；gate/qte 按现有 session 足迹实读申报——**实施者逐件过三连问，申报理由写进各件头注**）。
- [ ] **Step 3:** InteractSpellBook（chest 同门形制）：E→`record(NS_SPELLS, manual_id 或 spell_id)`→首学 `shell.playable.learn_spell(def)`（def 缺件=push_error 不炸链）；再触发不重发（has_record 短路学习但**仍走 consume+消失演出**，与 chest 判例⑤同法）。
- [ ] **Step 4:** 补学块（两文件同文）：`_ready` 尾（`_spell_manager` 创建之后）`var ledger := get_node_or_null(^"/root/GameSave"); if ledger: for sid in ledger.ids(ledger.NS_SPELLS): var def := SpellRegistry.definition_for(sid); if def: _spell_manager.learn_spell(def)`；**chen 动前 tar 备份**；G 流腿=账本预记 fire_ball→ instantiate chen 入树→`get_spell_manager()` 槽 0 非空；再验无 autoload 的 `-s` 环境 load 脚本不炸（blend_domain 式 `load().new()` 轻腿）。
- [ ] **Step 5:** 键权现状钉腿：G 流断言 AI/被动模板壳出生**无** spell 键劫持（channel 缺席或空转，实读现状据实写）；G 流全绿。
- [ ] **Step 6:** 分层复跑 spell_save+container+interact+wp3_formal（模板双写镜像检查）全绿；提交：`feat: 法术生产链开张——SpellRegistry+反应件申报单+《秘籍》+出生补学（chen/模板同文双写）`。

---

### Task 3: 执法闭环（R/E 流+validator+入册+R8 红据）

**Files:**
- Modify: `tools/spell_save_contract/`（+R 流重演等价、+X 流静态清点、+E 流正式壳 E2E、fixtures/）
- Create: `tools/spell_save_contract/fixtures/seg_b4_manual.tscn`（+ 章壳夹具 `chapter_b4.tscn`，抄 interact fixtures 形制，playable_override=test_actor）
- Modify: `tools/stage_validator/validator.gd`（R12）
- Modify: `tools/matrix_runner/run_matrix.sh`（第 24 套+ATTEST）
- Modify: 根 `AGENTS.md`（非 git：矩阵计数 24 套=25 跑+名册+账本法一行）

- [ ] **Step 1: E 流**——章壳夹具（秘籍段+spar 敌段）：E 拾→`Input.parse_input_event` raw 数字键 1（判例：raw 直投，物理键匹配）→ Cast 状态→弹体出现（group 查询）→敌血下降。**端到端唯一真键盘腿走原始事件**，禁直改内部状态。
- [ ] **Step 2: R 流双跑重演**——脚本序列（走图→开宝箱→E 秘籍→换段→回跳）录指纹向量 v1（只采：chest 有/无、`has_record(NS_SPELLS)`、可施法布尔、flags 计数、cleared 计数）；`to_dict→new_profile→from_dict`；重跑同序列得 v2；断言逐位等。**豁免向断言同跑**：未清段敌人清账重建数>0（重演必须重置面）。
- [ ] **Step 3: X 流静态清点**——读文本扫描（账本内部 `_ledges` 私有，公共面只有 `record/has_record/ids/claim` 与四账兼容方法；故"裸写"=绕过这些方法）：①game_save.gd 之外全仓 grep `_ledges` 命中=0（唯一合法持有者例外白名单自证）+ 任何 `\.flags *\[` / `\.chests *\[` 形态（旧 ChapterSession 公共字典残留假设）=0；②`reactions/*.gd` 每含 `class_name` 的文件必有 `func save_claim`；③申报名册打印（判项表=报表）：每反应件类→persists/resets 两列，并断言每类在 R/G/E 流至少被一根腿点名。
- [ ] **Step 4: validator R12**——章轨段场景文本级：InteractSpellBook/InteractChest 实例 export id 非空、同章 id 无重复；配 validator fixtures（坏例+好例）跑双模绿。
- [ ] **Step 5: R8 入册红据（本批最硬证据）**——a) 临时删 InteractSpellBook 的 record 一行→R 流+E 流必须响红（红档存 `/tmp/opencode/b4_t3/red_a.log`）；b) 临时在某反应件注入绕过门 `session._ledges[session.NS_CHESTS] = {}` 直戳内部→X 流①响红（`red_b.log`）；c) 复原→全绿（`green.log`）。三档路径写进批报告与本单。
- [ ] **Step 6:** run_matrix.sh 名册+ATTEST（`spell_save_contract|ACTOR-GATE`）；**全矩阵 25 跑一次**全绿；AGENTS.md 计数行更新；提交：`test: spell_save_contract 入册（矩阵第 24 套=25 跑）——双向重演+静态清点+E2E 施法，R8 红据双劣化实抓`。

---

### Task 4: 文档收口 + F5 单

**Files:**
- Modify: `docs/STAGE_ASSEMBLY.md`（条十一：装配查账+id 唯一+新件三连问申报规程）
- Modify: `DEVELOPMENT_STATUS.md`（B4 交付行+B4.5 预告行）
- Create: `docs/superpowers/plans/2026-09-24-s2-b4-spells-save-ledger-f5.md`
- Modify: 根 `AGENTS.md`（非 git：账本纪律判例条目，若无新雷则仅矩阵计数已在 T3 动过）

- [ ] **Step 1:** 法典条十一体例（装配者视角三步：选账本户→填申报→validator 自查）；判项表引用=指向 X 流打印，**不手抄**（防漂移）。
- [ ] **Step 2:** F5 单（头部=吞改纪律：先关编辑器→同步认账→重开验 autoload 列表；场地=**F6 直跑 `tools/spell_save_contract/fixtures/chapter_b4.tscn`**，机器看不到的是观感）五眼：①E 拾秘籍→消失演出+学会提示（如有）→按 1 火球出手命中小练、蓝条扣回；②走出该段再回→仍会（秘籍不再出现/不重发）；③死亡→段重跑后仍会；④debug_restart 原型重载后**仍会**（新档语义：重载不清账）；⑤另开一次从标题"开始游戏"进 ref_a→按 1 无反应（新档=清账）。尾部贴 X 流判项表打印。
- [ ] **Step 3:** DEVELOPMENT_STATUS B4 行（含七裁决引用与 R8 三档红据路径）；提交：`docs: B4 收口——法典条十一、状态单、F5 单（五眼+吞改纪律头部）`。
- [ ] **Step 4:** 批末**全矩阵 25 跑终核**+报告；tag `s2-b4-done`；发用户 F5。
