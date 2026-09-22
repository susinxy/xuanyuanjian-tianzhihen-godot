# S2-M1-B2.5 测试主权批 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 回归矩阵不再绑定任何生产角色——每轮通跑从 Inspector 创建产线全量生成一次 `test_actor`、跑完即删，同时把"按拳等待"这类魔法帧预算改为观察式/数据驱动，治愈 input_channel 红灯。

**Architecture:** `TestActorKit`（静态 ensure/destroy，ensure 走 `CharacterCreator` 真实管线=每轮顺带体检创建产线）+ `run_matrix.sh`（通跑编排：ensure→`--import`→23 跑→destroy→汇总）+ `playable_override` 导出缝（base_stage/chapter_shell 各一，默认 null=正式场景零影响，仅测试夹具填）。

**Tech Stack:** Godot 4.7 headless；bash 编排；契约流沿用完成旗+逐帧 await 判例。

**Spec:** 无独立 spec 文件——需求由用户 2026-09-22 两项裁决定档：①形态="每次通跑建一次、跑完删，任何依赖角色的地方都这样，验证过程中不得反复增删"；②插位=并入通跑生命周期而非独立静态替身。账本将复制此裁决。**本 plan 即该裁决的论证**；冲突时以用户裁决语义为准。

## Global Constraints

- GDScript 4；注释一律中文；提交中文 `feat:/fix:/docs:/test:`；**逐路径点名 add，永久禁 `git add -A`**（用户 WIP：`project.godot`、`scenes/stages/xuanyuan-chapter-1/**`、`characters/playable/chen/**`——chen 现况：**用户有意调过打击感（attack1=0.1s 定案），其资产本批一律只读不写不 git 化**）。
- **`characters/playable/*` 不入 git（仓库既有规则）**：test_actor 落 `characters/playable/test_actor/` 天然零 git 噪音；destroy=删目录；任何任务不得 `git add -f` 该目录（备份义务在操作方，判例 2026-09-14）。
- **addons/ 触点红线**：`character_creator.gd` 在插件目录内——**T1 探针若证明必须改插件本体才能 headless 跑通创建管线 → 立即 BLOCKED 上报控制器，不得顺手改**（控制器将向用户专项请示；目前证据指向无需改动：三阶段全用 DirAccess/FileAccess 文本手术）。
- 新 class_name 落地后先跑一次 `godot --headless --path . --import`。协程判例全套沿用（独立完成旗、raw 键注入、instance-id 预存、await-self 禁用——本轮无新壳代码）。
- 分层回归：每任务只跑受影响套；全矩阵 23 跑只在收口任务经**新 runner**跑一次。
- `stage_contract` 128 断言与 `container_contract` 57 断言是双轨基线哨兵：接缝任务后必须逐数复绿，任何"为保绿改断言"按 B1 终审标准回炉。

---

### Task 1: TestActorKit（ensure/destroy）+ CharacterCreator headless 探针

**Files:**
- Create: `tools/matrix_runner/test_actor_kit.gd`（class_name TestActorKit, extends RefCounted）
- Create: `tools/matrix_runner/test_actor_ensure.gd`（`extends SceneTree`，`-s` 入口：调 ensure 并打印三态退出码）
- Test: 一次性探针脚本（用完即删，不入库）

**Interfaces:**
- Produces:
  - `TestActorKit.ACTOR_DIR := "res://characters/playable/test_actor"`；`ACTOR_SCENE := ACTOR_DIR + "/test_actor.tscn"`
  - `static func exists() -> bool`（目录+主场景存在）
  - `static func ensure() -> int`：`OK`=已就绪；`ERR_NEEDS_IMPORT`=本进程刚创建完文件（资源未导入，调用方须重开进程/先跑 --import）；`ERR_CANCELED`=创建失败（诊断信息已打印）。创建**必须走 `CharacterCreator` 真实管线**（三参数按创建面板语义：英文 `test_actor`、类名 `TestActor`、显示名 `测试替身`、玩家档）。
  - `static func destroy() -> int`：递归删 `ACTOR_DIR`；返回 OK。幂等（不存在=OK）。
  - 常量 `NEEDS_IMPORT := 42`（shell 侧识别用退出码）。
- Consumes: `addons/quiver.beat_em_up/custom_inspectors/create_new_character/character_creator.gd`（只读调用，签名以实文件为准——Step 1 探明）。

- [ ] **Step 1（探针先行，引擎零信任）**：一次性脚本 introspect `CharacterCreator`：公开方法/签名、`_ready`/EditorInterface 依赖度（headless 会炸什么）、创建产物文件清单（主 tscn/skin tscn/两个 .gd/tres 族）。**若发现 editor-only 硬依赖 → BLOCKED 上报（附行号与证据），不要改插件。**
- [ ] **Step 2**：实现 `test_actor_kit.gd`（ensure 内先 `exists()` 短路；创建后逐文件断言 `FileAccess.file_exists`，缺=ERR）。destroy 用 DirAccess 递归删（返回 Error 语义按 `!= OK` 判，判例入库）。
- [ ] **Step 3**：验收序列（bash 层，三条真跑，全部贴进报告）：
  ```bash
  godot --headless --path . -s tools/matrix_runner/test_actor_ensure.gd          # 首跑：退出码 42（NEEDS_IMPORT）
  godot --headless --path . --import >/dev/null 2>&1; echo $?
  godot --headless --path . -s tools/matrix_runner/test_actor_ensure.gd          # 二跑：退出码 0（已就绪，幂等）
  godot --headless --path . --import >/dev/null 2>&1
  # 再验：场景真可加载+身份正确（一次性 SceneTree 脚本：load(ACTOR_SCENE).instantiate()
  #   → add_child → 两物理帧 → 断言 is_in_group("area2d:player")、skin 的 sprite_frames 非空、
  #   state_machine 非空。断言失败=ERR）
  godot --headless --path . -s tools/matrix_runner/test_actor_destroy.gd 或经 kit 的等价一次性入口  # destroy → 目录零残余（ls 断言）
  ```
  探针/一次性脚本删除；ensure/destroy 两个 SceneTree 入口文件**保留**（runner 与手动都要用）。
- [ ] **Step 4**：`git status` 确认 `characters/playable/` 无任何可暂存项（被忽略规则覆盖），提交点名 2-3 个 `tools/matrix_runner/` 文件：`feat: TestActorKit——通跑期测试替身全量创建/销毁走真实产线`。

---

### Task 2: run_matrix.sh 通跑编排 + 主权契约流

**Files:**
- Create: `tools/matrix_runner/run_matrix.sh`
- Modify: `tools/interact_contract/interact_contract.gd`（追加 S 流——主权契约）
- Create: `tools/matrix_runner/fixtures/sovereignty_probe.gd`（一次性身份探针的常驻化，S 流用）

**Interfaces:**
- Consumes: Task 1 的 kit 与两个入口。
- Produces: `run_matrix.sh [--only SUITE] [--ensure-only]`：
  1. ensure（退出码 42→`--import`→再 ensure；非 0 红字终止）
  2. 顺序跑全套（名册内嵌脚本=22 套名册与 B2 收口一致；validator 双模）收集 rc/日志至 `/tmp/opencode/matrix/<ts>/`
  3. 末行汇总表 + 退出码=红套数
  4. `--only` 模式跳过 destroy 并打印"test_actor 残留中，下次通跑将强制重建"。

- [ ] **Step 1**：写 S 组失败断言（interact_contract 新流 `_flow_sovereignty`，在 Q 流后）：S1 `TestActorKit.exists()` 假时 `ensure()` 返 NEEDS_IMPORT 且**不半途留残目录**（或存在时幂等 OK——两分支都要锁）；S2 destroy→exists 假→再 ensure 成功（产线可重入，跨进程 import 语义由 runner 承担，S 流只测本进程可见面：destroy 幂等×2）；S3 身份探针常驻化：`load(ACTOR_SCENE)` 失败=本进程未导入且 exists 真 → 断言给出**可操作错误消息**（含 `run_matrix.sh` 字样）而非静默跳段。
- [ ] **Step 2**：红跑（S 流对无 kit 状态=天然红/或 kit 分支缺失——按 Step1 设计取真红据）。
- [ ] **Step 3**：写 run_matrix.sh（名册硬编码+注释注明"以 tools/ 实存 runner 为准，AGENTS 同步"；spike 两套不入册）。
- [ ] **Step 4**：绿跑 interact_contract（85+新增 S 全绿；**注意** S 流在 runner 外单跑时 exists 可能真/假两态，断言写成两态都成立的形状，防 flake）。再 `bash tools/matrix_runner/run_matrix.sh --only container_contract` 局部通道自证（ensure+单套+残留提示），全量 23 跑留给收口任务。
- [ ] **Step 5**：提交点名：`feat: run_matrix.sh 通跑编排+主权契约流——每轮真建真删产线活体验证`。

---

### Task 3: input_channel 迁替身 + 帧预算去魔法（治红）

**Files:**
- Modify: `tools/input_channel_test/test_runner.gd`
- Modify: `tools/input_channel_test/test_policy.gd`（仅当预算改造需要它暴露按压时刻时）

- [ ] **Step 1**：`CHEN_SCENE` → `TestActorKit.ACTOR_SCENE`；三处"固定等待后查 Attack"改**观察式**：`_wait_until(_in_attack_flow(...), 90帧帽)`（入口即真、不看拳速），并加断言"按压后曾进过 Attack"用信号/上升沿记录而非抽查瞬时态（6 帧拳也可能被瞬时抽查漏——上升沿锁是数据驱动的正解）。泄漏/门控各腿同构迁移。
- [ ] **Step 2**：本套件头部三态守卫：`exists()` 假 → 打印"请先 bash tools/matrix_runner/run_matrix.sh --ensure-only" 并 FAIL（可读红>裸崩）。
- [ ] **Step 3**：绿跑（此前唯一红的 AI 腿转绿；16+全绿）；再 `destroy→exists 假→裸跑`验一次可读红路径，随后 `--ensure-only` 复原。
- [ ] **Step 4**：提交 `fix: input_channel 迁测试替身+攻击断言上升沿化——治愈打击感调优引发的帧预算过期红`。

---

### Task 4: 直载类套件全迁移 + AGENTS 新法

**Files:**（审计后取实际子集）Modify: `tools/{conductor_test,hud_test,tree_connectivity_test,attack_freeze_repro,spell_cast_test/*2,attack_lane_contract,wp3_formal}/…` 等所有"只是需要一个角色"处；Modify 根 `AGENTS.md`（非 git）。

- [ ] **Step 1**：逐文件审计 14 处引用（清单在 plan 附页=账本预扫描），三分：①直载 chen → 迁 ACTOR_SCENE；②经场景内嵌 chen（stage/container 系）→ 留给 Task 5 接缝；③**确实验证 chen 本体**者保留+套件头中文豁免注释（新法要求申报）。
- [ ] **Step 2**：迁移逐个绿（受影响套复跑）。lane 靶场迁移需核模板快照含 chen 四向攻击资产（templates/README 口径），不足则该腿留 chen+豁免注释。
- [ ] **Step 3**：根 AGENTS 落新法一段：回归矩阵禁绑生产角色（test_actor 由 run_matrix.sh 每轮真建真删）；豁免须套件头申报；**通跑唯一入口=run_matrix.sh**（分层复跑仍可单套，但须先 `--ensure-only`）。
- [ ] **Step 4**：提交（点名各套件文件；AGENTS 不入库）。

---

### Task 5: playable_override 接缝（模板内嵌场景解绑）

**Files:**
- Modify: `scenes/base/base_stage.gd`、`scripts/chapter/chapter_shell.gd`（各加一导出+换人腿）
- Modify: `tools/container_contract/fixtures/chapter_fix.tscn`、`tools/interact_contract/fixtures/chapter_it*.tscn`、stage_contract 所用夹具（实审计为准）

- [ ] **Step 1**：`@export var playable_override: PackedScene`——`_ready` 最前（`_scene_path` 回跳消费之后、进段之前）：非空→free 内嵌 Chen→instantiate 替身挂回原节点位→`playable_path` 指过去（shell 走既有 `set_playable` 身份校验链，缺 `area2d:player` 即 chapter_error）。
- [ ] **Step 2**：夹具先红（override 未实现时 S/E/D/H 与 stage 流行为不变=此步红据是"接缝不生效"断言：替身在树且 `playable is 替身` 新断言）。
- [ ] **Step 3**：container_contract 57/57 **逐数不漂移**、stage_contract 128/128 逐数复绿（双轨基线哨兵）。HUD 跟手/死亡链/输入通道若经此路，红即回炉。
- [ ] **Step 4**：正式场景零影响自证：`scenes/stages/ref/*.tscn` 未写该导出→默认 null 路径代码审读+stage_contract 内既有"chen 在位"断言仍绿即为证。提交 `feat: playable_override 接缝——测试夹具与生产内嵌角色解绑（默认 null 零影响）`。

---

### Task 6: 收口——首通全矩阵 + 文档 + 关账

- [ ] **Step 1**：`bash tools/matrix_runner/run_matrix.sh` 全量首通：23 跑全绿（含转治的 input_channel）+ destroy 零残余；汇总表贴报告。
- [ ] **Step 2**：DEVELOPMENT_STATUS 加 B2.5 行（含打击感定案备案：chen attack1=0.1s 为用户有意创作，矩阵已免疫）；F5 单追加一眼"游乐场在替身下手感无异"（合入 B2 单成附录或新小单，控制器定）。
- [ ] **Step 3**：tag `s2-m1-b25-done`、push。终审（whole-branch 视角同样适用：本批虽小但动了基线接缝）→ 一波修 → 关账。

---

## 预扫描表（Task 边界/冲突自查）

| 交叠对 | 内容 | 结论 |
|---|---|---|
| T1→T2/T3/T4/T5 | 全部消费 `TestActorKit` 常量与三态语义 | T1 的接口卡是唯一法源；三态（OK/NEEDS_IMPORT/ERR）契约在 T1 Step2 注释锁定 |
| T2 改 interact_contract vs T3-T5 改各套 | 不同文件 | 无冲突 |
| T5 改 shell/base_stage vs B1 双轨基线 | 新导出默认 null=旧行为逐位；两基线数逐数复绿硬门 | 已列 Step3 为回炉判据 |
| T4 审计 14 处引用 vs 用户 chen WIP | 只读 chen，不改、不 git 化 | 红线已在 Global Constraints |
| 单跑 flake 面 | S 流/三态守卫在两态（存在/缺失）下都必须成立 | T2 Step4 明文 |
