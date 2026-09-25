# S2-B4.5 存档落盘 + 读档管线 + 一本账闭环 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 账本自动落盘（记账=存档，零自觉调用）、标题「继续/新游戏覆盖确认」接通读档三通道、双检查点表彻底并入 GameSave（GameEvents 降纯总线）、learn_spell 基础类契约正式立法。

**Architecture:** SaveSystem 单监听者吃 GameSave 的 `recorded/checkpoint_recorded/location_visited` 泛信号，置脏帧尾合并 tmp→rename 原子写 `user://save_auto.json`；读档=load→from_dict→`resume_pending` 传渡→壳 `_ready` 消费落位检查点段（与死亡重跑/暂停回跳共腿）；回跳表数据与通关事实（chapters_done 新户）全部入同一快照——**账=事实，档=影子，传渡旗不入账**。

**Tech Stack:** Godot 4.7；`FileAccess`/`DirAccess.rename`；JSON（roundtrip 键 String→StringName 归一化沿用 B4 判例）；契约=spell_save_contract 扩 D 流（矩阵 24 套=25 跑口径不变）。

**Spec:** `docs/superpowers/specs/2026-09-25-s2-b45-save-persistence-design.md`（§2-§6 全为法源；冲突以 spec 为准）。

## Global Constraints

- GDScript 4；注释一律中文；`feat:/fix:/test:/docs:` 中文提交；**逐路径点名 add，永久禁 `git add -A`**；用户 WIP（`scenes/stages/xuanyuan-chapter-1/**`、untracked dll 幽灵）不碰。
- **addons/ 零触点**（本批全部项目侧）。`spells/_base/` 是法术基础类=正式设计面（B4.5 裁决 R3），改 `learn_spell` 按 §5 立法走。
- **`project.godot` 吞改纪律**：唯一触点=`[autoload]` 在 GameSave 行后加 `SaveSystem="*res://scripts/save/save_system.gd"`；改前须用户口令"编辑器已关"，先 `cp` 备份到 `/tmp/opencode/b45_t0/`，`git diff` 逐字只多一行。
- `characters/playable/chen/chen.gd` 非 git 生产资产：**动前 tar 备份**，与 `templates/character/__NAME__.gd` **同文双写**（T3 补学去重）。
- 契约测试卫生条款（spec §2）：**一切落盘腿只吃 `slot_path` 注入的 scratch 文件**（`user://b45_test_<流名>.json`，套头删尾删），**永不读写 AUTOSAVE_PATH 生产档**；帧尾合并落盘断言前必须 `await get_tree().process_frame` 以上。
- 版本策略：`SAVE_VERSION` 维持 1——形状向后兼容扩展（checkpoint 第三键/locations 键），读端缺键给默认；只有破坏性变更才 bump（本批无）。
- **locations 入快照定档**（spec §3 的执行细则）：回跳表=已发生事实，随 to_dict 走、随 from_dict 还魂；`resume_pending` 与 `pending_jump_stage` 属传渡，**不入 to_dict**（D 流钉死此条）。
- headless 判例全套（B4 同款）：新 autoload/新 class_name 后 `--import`；独立完成旗；`.tscn` 手写规则；改判先红后绿留档。
- 基线：批前矩阵 24 套=25 跑 RED=0（B4 关账态 4c8b3c1）。全矩阵在 T4 批内跑；分层复跑清单见各任务。

---

## 文件总图

| 动作 | 路径 | 责任 |
|---|---|---|
| Modify | `scripts/save/game_save.gd` | 泛信号三条+checkpoint 扩 scene+locations 迁账+resume_pending+NS_CHAPTERS_DONE（T0） |
| Create | `scripts/save/save_system.gd` | 落盘监听者（autoload，无 class_name，GameSave 同形制）（T0） |
| Modify | `project.godot` | `[autoload]` 加 SaveSystem 一行（T0，口令前置） |
| Modify | `tools/spell_save_contract/spell_save_contract.gd` | D 流（T0）+ resume 落位腿（T2）+ G 流三式（T3） |
| Modify | `scripts/game_events.gd` | 瘦身为纯总线：数据与 add/get/reset 语义迁出（T1） |
| Modify | `scripts/chapter/chapter_shell.gd` | add_checkpoint 改口+resume 分支+chapters_done+record_checkpoint 带 scene（T1/T2） |
| Modify | `scenes/base/base_stage.gd` | `:47/:169` 改口（T1） |
| Modify | `ui/menus/death_screen.gd`、`ui/menus/pause_menu.gd` | get_checkpoints→GameSave.locations()（T1） |
| Modify | `ui/menus/title_screen.gd` | 继续钮+覆盖确认框（T2） |
| Modify | `spells/_base/spell_manager.gd` | learn_spell 立法（T3） |
| Modify | `characters/playable/chen/chen.gd` + `templates/character/__NAME__.gd` | 补学循环 spell_id 去重（T3，同文双写+备份） |
| Modify | `tools/stage_contract/stage_contract.gd` | A 组回跳表腿改判（T1） |
| Modify | spec 一处回写 + `docs/STAGE_ASSEMBLY.md` 条十一注 + `docs/SPELL_SYSTEM_DESIGN.md` learn_spell 契约句 + `DEVELOPMENT_STATUS.md` + 根 `AGENTS.md`（非 git）；Create F5 单 | T4 |

**Interfaces（跨任务钉名）：**

```gdscript
# game_save.gd 新增
signal recorded(ns: StringName, id: StringName)          # 一切首记（含四账兼容层）
signal checkpoint_recorded(checkpoint: Dictionary)        # {scene, segment, entry}
signal location_visited(stage_id: StringName)             # 回跳表新增/追新时（原 story 信号语义随迁）
const NS_CHAPTERS_DONE := &"chapters_done"                # _ready 预开系统户
var resume_pending := false                                # 传渡旗（不入 to_dict）
func record_checkpoint(segment: StringName, entry: StringName, scene_path := "") -> void
func checkpoint_scene() -> String                          # ""=未记账
func add_location_checkpoint(stage_id: StringName, scene_path: String) -> void  # 摘旧追新迁入
func locations() -> Array[Dictionary]                      # 原 get_checkpoints（新→尾）
# to_dict 形状：checkpoint 子字典加 "scene" 键；顶层加 "locations":[{stage_id,scene_path}]（String 化）
# from_dict：以上缺键=容忍默认（版本 1 兼容）；locations 还魂进 _locations

# save_system.gd（autoload 单例）
const AUTOSAVE_PATH := "user://save_auto.json"
var slot_path := AUTOSAVE_PATH          # 测试注入口（置后不自动回退）
func has_save() -> bool
func save_now() -> bool                 # 同步强存：to_dict→stringify→tmp→rename
func load_game() -> bool                # 读+parse+GameSave.from_dict；坏=false 保旧账
func delete_save() -> void              # 正档与 tmp 残骸一并清
# _ready 连 GameSave 三信号→_dirty 置位→call_deferred(_flush_if_dirty)（幂等）
```

---

### Task 0: GameSave 扩展 + SaveSystem 落盘 + D 流

**Files:** game_save.gd、save_system.gd、project.godot、spell_save_contract.gd

- [ ] **Step 0:** 向用户要"编辑器已关"口令后方可动 project.godot；`mkdir -p /tmp/opencode/b45_t0 && cp project.godot /tmp/opencode/b45_t0/`。其余 Step 不依赖口令，先行。
- [ ] **Step 1: D 流失败腿先写**（红=SaveSystem 不存在）：①注入 `slot_path="user://b45_d_stream.json"`，`delete_save()` 起手清场→`has_save()==false`；②`GameSave.new_profile()`→`claim+record(&"b45_probe", id)` → `await process_frame` → 文件存在且 `JSON.parse_string` 可读、`version==1`、`ledges.b45_probe` 含该键、**正档路径外无 tmp 残骸**；③roundtrip：记若干+record_checkpoint(三参) → `save_now()` → `new_profile()` → `load_game()==true` → 逐键 has_record+`checkpoint_scene()` 还原（R 流"还原真写账"判例沿用）；④坏文件：手写 `"{{{垃圾"` 到 scratch → `load_game()==false` 且现账一字不动；⑤传渡条款：`GameSave.resume_pending=true` → `to_dict()` 全文 `has("resume_pending")==false` 且 JSON 串不含该词；⑥`recorded` 信号首记一发/重记零发（connect 计数，M3 示范 disconnect 纪律）；⑦`location_visited` 与 `locations()` 摘旧追新（自 GameEvents 原语义逐位搬）。跑套存红档 `/tmp/opencode/b45_t0/red_d.log`。
- [ ] **Step 2:** game_save.gd 按 Interfaces 增量（信号三、常量、resume 旗、checkpoint 第三字段+兼容两参调用、locations 迁账+入快照；头注更新"账=事实档=影子"指针到 spec §2）。**本步 GameEvents 原表不动**（双活在 T1 收口，避免原子断档；to_dict 先行含 locations——GameSave 表空时输出 []，无害）。
- [ ] **Step 3:** save_system.gd 实现（~40 行）：_ready 连三信号；`_dirty` + call_deferred 帧尾合并；save_now 内部 `FileAccess.open(slot_path+".tmp", WRITE)`→失败 push_error return false→`DirAccess.rename_absolute(tmp, slot_path)`（**注意**：rename 是引擎 API，写前先探针 `DirAccess` 方法名实义，零信任判例）；load_game 含 parse 失败/非 Dictionary/version≠1/坏形状→false+push_warning。
- [ ] **Step 4:** project.godot 一行上轴 → `--import` → D 流全绿 → 分层复跑 `spell_save_contract` 全套 + `container_contract`（signal 增量不扰其消费）。提交 `feat: SaveSystem 影子落盘——recorded/checkpoint/location 泛信号+帧尾合并+原子写，D 流入册`。报告置顶：Windows 重启编辑器认 autoload。

---

### Task 1: 双表彻底合并（GameEvents 降纯总线）

**Files:** game_events.gd、chapter_shell.gd、base_stage.gd、death_screen.gd、pause_menu.gd、stage_contract.gd

- [ ] **Step 1:** 改判前红档：把 stage_contract A 组探针腿（`:160-237` 一带）先切到 `GameSave.add_location_checkpoint/locations()` 新口（GameSave 侧 T0 已备）→ 旧表仍被生产写入（改口未拆）→ A5 收尾"空表"类腿必红 → 存 `/tmp/opencode/b45_t1/red_pre.log`。
- [ ] **Step 2:** 生产侧改口三处：`chapter_shell.gd:72`、`base_stage.gd:47` → `GameSave.add_location_checkpoint(...)`；death_screen:54/pause_menu:76 → `GameSave.locations()`（渲染逆序逻辑不动）。
- [ ] **Step 3:** GameEvents 拆数据：删 `_session_checkpoints/add_checkpoint/get_checkpoints` + `story_checkpoint_added` 信号定义（**先 grep 全仓该信号 `.connect(` 消费点=0 再拆**，有则随迁 GameSave 名 `location_visited`）；`reset_session()` 语义改"只清 `pending_jump_stage` 传渡"（base_stage:169/title:15 调用点保留不改，注释改写原因：回标题≠清档，清账唯一口 new_profile）；文件头注更新职责句（S1 立法句里"会话状态"四字出历史注记）。
- [ ] **Step 4:** stage_contract A 组腿按新语义逐腿改判（判据变更点写中文注引 spec §3），全绿；`interact_contract`+`container_contract`+`spell_save_contract` 分层复跑（三套都吃建壳链）。提交 `refactor: 回跳表并入 GameSave 快照——GameEvents 降纯总线，菜单/base_stage 改口，stage_contract A 组改判`。

---

### Task 2: 读档管线（继续/覆盖确认/resume 落位/通关入账）

**Files:** title_screen.gd、chapter_shell.gd、spell_save_contract.gd（resume 腿）

- [ ] **Step 1: 失败腿先行**：①夹具壳测试：`GameSave.new_profile()` → 走段记 checkpoint（三参）→ `resume_pending=true` → 重建壳实例（queue_free+重 instantiate 同场景）→ 断言 `_ready` 后 `current_segment_id()==checkpoint 段` 且旗已被消费（false）；对照腿：旗 false 时重建→落 `_order[0]`；红档存证（resume 分支未实现必红）。②通关入账腿：驱动 `_maybe_finish_chapter` 成功分支→`has_record(NS_CHAPTERS_DONE, chapter_id)==true`。
- [ ] **Step 2:** chapter_shell：`_scene_path()` 结果缓存 `_scene_file`；`enter_segment` 内 `session.record_checkpoint(id, entry, _scene_file)`（两参兼容签名仍可用）；`_ready` 加 resume 分支（消费 first-wins，落位段+入口，失败=该段不在 _order 时 push_error 回退 _order[0] 不炸）；`_maybe_finish_chapter` 成功闩后 `session.record(NS_CHAPTERS_DONE, chapter_id)`。
- [ ] **Step 3:** title_screen：`_ready` 加「继续游戏」entry（enabled=SaveSystem.has_save()）；回调=`SaveSystem.load_game()` 成功→`GameSave.resume_pending=true`→转场 `GameSave.checkpoint_scene()`（空=push_error 不转）；「开始游戏」有档时弹运行时构建 ConfirmationDialog（PROCESS_MODE 随标题壳；文案"进度将被清除，确定重新开始？"；确认=`new_profile()+delete_save()` 再走现流程；取消不动），无档直进（B4 行为零变）。
- [ ] **Step 4:** 分层复跑 spell_save 全套 + container + interact + stage_contract 全绿；提交 `feat: 读档三通道合一——标题继续/新游戏覆盖确认，壳端 resume 落位，通关事实入账 chapters_done`。

---

### Task 3: SpellManager 契约立法 + 补学去重

**Files:** spell_manager.gd、chen.gd+模板、spell_save_contract.gd（G 流）

- [ ] **Step 1:** G 流三式失败腿：`learn_spell(null)==false`（现实现会把 null 塞进空槽"成功"——真红）；同一 def 连学两次第二次==false（同学科去重未立=第二真红主体）；正常 def==true。
- [ ] **Step 2:** spell_manager.gd 立法（含中文 API 注释：true=新学会占槽；null/重复 id 均 push_warning+false；循环查重 definition!=null 的槽）；补学块（chen+模板**同文双写**，chen 先 tar 备份到 `/tmp/opencode/b45_t3/`）：循环加本地 `seen: Array[StringName]` 按 `def.spell_id` 去重后再 learn（消多键同学科的 push_warning 噪音——基础类报警留给真违规，不报良性重提）。
- [ ] **Step 3:** 秘籍件回归确认（G4 腿语义不回归：账本幂等在前，去重在后不互踩）；分层复跑 spell_save + hud_test（槽面消费）+ wp2（模板镜像链）；提交 `feat: learn_spell 基础类契约立法——null 拒学+同学科去重，补学按 id 去重消噪`。

---

### Task 4: 终核 + 文档 + F5 + tag

**Files:** spec 回写、STAGE_ASSEMBLY、SPELL_SYSTEM_DESIGN、DEVELOPMENT_STATUS、AGENTS（非 git）、F5 单

- [ ] **Step 1:** spec 回写一处：§3 补"locations 入快照、from_dict 还魂、resume/pending 属传渡"定档句（本 plan 已执行，文档跟齐）。
- [ ] **Step 2:** 全矩阵 **24 套=25 跑** 终核 RED=0；AGENTS 更新：矩阵名册 spell_save_contract 描述加 D 流、账本纪律法尾部补"记账即落盘（SaveSystem 影子条款）+ 传渡不入账"两行。
- [ ] **Step 3:** F5 单（`docs/superpowers/plans/2026-09-25-s2-b45-save-persistence-f5.md`）头部=编辑器关闭口令流程+autoload 表认 SaveSystem+首开重存指纹勿慌；冷启动两连眼：①chapter_b4 夹具 E 拾书→走深→ESC 回标题→「继续游戏」→**回拾书后那段、满状态、书不复活、按 1 仍响**；②「开始游戏」→**覆盖确认框弹出**→确认后书回原处按 1 无反应；③（附）Windows 存档真实路径可见性：`%APPDATA%/Godot/app_userdata/<项目名>/save_auto.json` 存在且为合法 JSON。
- [ ] **Step 4:** DEVELOPMENT_STATUS B4.5 交付行；提交 `docs: B4.5 收口——spec 定档回写、法典/法术文档契约句、状态单、冷启动 F5`；tag `s2-b45-done` 推送。批报告发用户（含 R1 影子条款兑现度自评与遗留）。
