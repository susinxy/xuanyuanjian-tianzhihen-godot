# S2-B4.5 存档落盘 + 读档管线 + 一本账闭环 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 GameSave 账本自动落盘（影子条款：一切首记/检查点/回跳访问即触发存档，内容件零自觉调用），接通标题「继续游戏」+「新游戏覆盖确认」+ 壳端 resume 落位构成读档三通道，把回跳表与检查点双表彻底并入 GameSave（GameEvents 降纯总线），并对 `spells/_base/spell_manager.gd` 的 `learn_spell` 做基础类契约立法。

**Architecture:** 三条设计脊梁：
1. **账=事实，档=影子**——SaveSystem 作为单一监听者订阅 GameSave 的泛信号（`recorded`/`checkpoint_recorded`/`location_visited`），帧尾合并 tmp→rename 原子写 `user://save_auto.json`；写失败只 push_error 不断游戏（丢档可接受，崩游戏不可接受）。传渡件（`resume_pending`、`GameEvents.pending_jump_stage`）不入账、不入快照。
2. **一本账闭环**——回跳表数据迁入 GameSave（新增 `add_location_checkpoint/locations` + `location_visited` 信号，随 `to_dict` 入快照、随 `from_dict` 还魂）；GameEvents 只留事件（room_cleared/stage_exited）+ `pending_jump_stage` 传渡 + `reset_session`（语义收缩为"只清传渡"，回标题≠清档，清账唯一口仍是 new_profile）。
3. **读档=回检查点的硬盘孪生**——死亡重跑（现腿）/暂停回跳（现腿）/读档（新腿）共用同一份 checkpoint 数据；`resume_pending` 走"旗→壳 `_ready` 消费 first-wins→落位检查点段+入口"（与 B4 pending_jump 传渡判例同构）；满状态天然成立（读档走全新场景加载，角色出生即满，B4 裁决 R0b 零实现成本）。

**Tech Stack:** Godot 4.7；`FileAccess`/`DirAccess.rename_absolute`；JSON 直落（to_dict 已全普通类型）；契约=spell_save_contract 扩 D 流 + T2 resume 腿 + G 流补式（矩阵 24 套=25 跑口径不变，**不新增测试套、不动 run_matrix.sh**）。

**Spec:** `docs/superpowers/specs/2026-09-25-s2-b45-save-persistence-design.md`（§2-§8 全为法源；冲突以 spec 为准。T4 Step1 有一处 spec 回写义务：§3 补"locations 入快照、传渡不入账"定档句——plan 执行中先按本文件 Architecture 行事）。

## Global Constraints

- GDScript 4；注释一律中文；提交 `feat:/fix:/test:/docs:/refactor:` 中文；**逐路径点名 add，永久禁 `git add -A`**；用户 WIP（`scenes/stages/xuanyuan-chapter-1/**`、untracked dll 幽灵、根目录 mp4）不碰。
- **addons/ 零触点**（本批全部项目侧）。`spells/_base/` 是项目代码、法术线的基础类=正式设计面（B4.5 裁决 R3），改 `learn_spell` 按 spec §5 立法走。
- **`project.godot` 吞改纪律**（本月三案）：唯一触点=`[autoload]` 在 GameSave 行后加 `SaveSystem="*res://scripts/save/save_system.gd"`；改前须用户口令"编辑器已关"，先 `mkdir -p /tmp/opencode/b45_t0 && cp project.godot /tmp/opencode/b45_t0/`，改后 `git diff project.godot` 逐字核对只多这一行。
- **契约测试卫生条款**（spec §2）：一切落盘腿只吃 `slot_path` 注入的 scratch 文件（`user://b45_d_stream.json` 一类，套头 `delete_save()` 起手清场、套尾删净），**永不读写 AUTOSAVE_PATH 生产档**；帧尾合并落盘的断言前必须 `await get_tree().process_frame` 以上；headless（Linux user://）与 Windows（%APPDATA%）目录天然隔离，勿在测试里假设平台路径。
- **版本策略**：`SAVE_VERSION` 维持 1——checkpoint 子字典加第三键 `"scene"`、顶层加 `"locations"` 均为**向后兼容的形状扩展**，读端缺键给默认（`""`/`[]`）；只有破坏性变更才 bump（本批无）。
- **传渡/易失条款**：`resume_pending` 与 `pending_jump_stage` 不入账、不进 `to_dict`（一次性意图随场景消费即灭，first-wins 判例沿用）；D 流钉死此条（见 Task 0 Step 1-⑤）。
- `characters/playable/chen/chen.gd` 非 git 生产资产：**动前 tar 备份**，与 `templates/character/__NAME__.gd` **同文双写**（Task 3 补学去重）。
- 改判先红后绿留档（B4-T1 纪律沿用）；headless 判例全套：新 autoload/class_name 后 `--import` 一次；协程独立完成旗；`.tscn` 手写规则；typed 调用绕 override 判例（本批无新组挂点，留意 GameSave 信号 connect 走显式 Callable）。
- 基线：批前矩阵 24 套=25 跑 RED=0（B4 关账态 `4c8b3c1`）。**全矩阵只在 T4 批内跑一次**；分层复跑清单如下（按文件归属制）：
  - **game_save.gd 触点** → 必跑 `spell_save_contract` + `container_contract` + `interact_contract`（三套吃建壳链与四账消费面）；
  - **quiver_attributes.gd 触点**（未来批适用） → `block_parry_contract` + `knockout_contract`；
  - 菜单/title 触点 → `stage_contract`（A 组吃回跳表）；
  - 法术触点 → `spell_cast_test` + `spell_hit_test` + `hud_test` + `wp2_creation_test`。
- **矩阵口径不变**：24 套=25 跑——spell_save_contract 扩流不另立套；run_matrix.sh 本批零改动。

---

## 文件总图

| 动作 | 路径 | 责任 |
|---|---|---|
| Modify | `scripts/save/game_save.gd` | 泛信号三条（recorded/checkpoint_recorded/location_visited）+ checkpoint 扩 scene 字段 + locations 迁账 + `resume_pending` 旗 + `NS_CHAPTERS_DONE` 系统户 + to_dict/from_dict 形状扩展（T0/T1/T2 分步生长） |
| Create | `scripts/save/save_system.gd` | 影子落盘监听者（autoload，无 class_name，GameSave 同形制）：帧尾合并、tmp→rename 原子写、has_save/save_now/load_game/delete_save、`slot_path` 注入口（T0） |
| Modify | `project.godot` | `[autoload]` 加 SaveSystem 一行（T0 Step 4，口令前置） |
| Modify | `scripts/game_events.gd` | 降纯总线：删 `_session_checkpoints/add_checkpoint/get_checkpoints`；`reset_session` 收缩为"只清传渡"；`story_checkpoint_added` 信号随迁 GameSave（T1） |
| Modify | `scripts/chapter/chapter_shell.gd` | `:72` add_checkpoint 改口 + `enter_segment` 记 checkpoint 带 scene + `_ready` resume 分支 + `_maybe_finish_chapter` 通关入账（T1/T2） |
| Modify | `scenes/base/base_stage.gd` | `:47` add_checkpoint 改口 + `:169` reset_session 注释改写（回标题≠清档）（T1） |
| Modify | `ui/menus/death_screen.gd`、`ui/menus/pause_menu.gd` | `get_checkpoints()`→`GameSave.locations()`（渲染逆序逻辑不动）（T1） |
| Modify | `ui/menus/title_screen.gd` | 「继续游戏」entry（has_save 才 enabled）+「开始游戏」覆盖确认框（运行时构建 ConfirmationDialog）（T2） |
| Modify | `spells/_base/spell_manager.gd` | learn_spell 立法：null 拒 + 同学科去重 + 中文 API 契约注释（T3） |
| Modify | `characters/playable/chen/chen.gd` + `templates/character/__NAME__.gd` | 补学循环按 `def.spell_id` 本地 seen 去重（消 push_warning 噪音，同文双写+备份）（T3） |
| Modify | `tools/spell_save_contract/spell_save_contract.gd` | D 流（T0）+ resume 落位腿与通关入账腿（T2）+ G 流三式（T3）+ 各改判红档 |
| Modify | `tools/stage_contract/stage_contract.gd` | A 组回跳表腿（`:160-237` 一带）切新口按新语义改判（T1） |
| Modify | `docs/superpowers/specs/2026-09-25-s2-b45-save-persistence-design.md` | §3 回写"locations 入快照/传渡不入账"定档句（T4） |
| Modify | `docs/STAGE_ASSEMBLY.md`、`docs/SPELL_SYSTEM_DESIGN.md`、`DEVELOPMENT_STATUS.md`、根 `AGENTS.md`（非 git） | 条十一注/learn_spell 契约句/交付行/影子条款+D 流描述（T4） |
| Create | `docs/superpowers/plans/2026-09-25-s2-b45-save-persistence-f5.md` | F5 冷启动两连单（T4） |

**Interfaces（跨任务钉名，后续任务按此消费）：**

```gdscript
# game_save.gd 新增
signal recorded(ns: StringName, id: StringName)          # 一切首记（含四账兼容层——兼容层底层走 record 门洞，天然全覆盖）
signal checkpoint_recorded(checkpoint: Dictionary)        # {scene: String, segment: StringName, entry: StringName}
signal location_visited(stage_id: StringName)             # 原 story_checkpoint_added 语义随迁（名字换新）
const NS_CHAPTERS_DONE := &"chapters_done"                # _ready 预开系统户（与 flags/chests/cleared_segments/spells_known 同列）
var resume_pending := false                               # 传渡旗：不入 to_dict、不落盘
func record_checkpoint(segment: StringName, entry: StringName, scene_path := "") -> void
                                                            # 两参旧调用零破坏；scene_path 空=不覆写已记场景（回跳传渡段间保留）
func checkpoint_scene() -> String                          # ""=未记账
func add_location_checkpoint(stage_id: StringName, scene_path: String) -> void
                                                            # 摘旧追新（原 GameEvents 语义逐位搬）；触发 location_visited
func locations() -> Array[Dictionary]                      # 拷贝返回（原 get_checkpoints；数组尾=最新访问）
# to_dict 形状：{"version":1, "ledges":{ns:{id:v}}, "checkpoint":{"scene","segment","entry"}, "locations":[{"stage_id","scene_path"}]}
#   （键一律 String 化落 JSON；locations 的 stage_id 同样 str() 化）
# from_dict：以上顶层键缺=默认（checkpoint 缺 scene 键→""；locations 缺→[]）；
#   locations 还魂直接填 _locations（String 键读回后 stage_id 转 StringName）；
#   resume_pending 永不出现在快照里（D 流腿钉死）

# save_system.gd（extends Node，无 class_name；GameSave 同形制，全仓经 /root/SaveSystem 或 get_node_or_null 访问，禁 import/preload 单例引用）
const AUTOSAVE_PATH := "user://save_auto.json"
var slot_path := AUTOSAVE_PATH           # 测试注入口（赋值后不自动回退；契约只吃 scratch）
func has_save() -> bool                  # FileAccess.file_exists(slot_path)
func save_now() -> bool                  # 同步强存：GameSave.to_dict→JSON.stringify→写 slot_path+".tmp"→DirAccess.rename_absolute 原子替换
func load_game() -> bool                 # 读+parse+形状/version 校验+GameSave.from_dict；任一坏= false 且现账一字不动
func delete_save() -> void               # 正档与 .tmp 残骸一并清
# _ready 连 GameSave 三信号（recorded/checkpoint_recorded/location_visited）→ _dirty=true
#   → 若未在途：get_tree().process_frame.once→ 调 _flush_if_dirty()（幂等合并，一帧多记=一次写）
```

---

### Task 0: GameSave 扩展 + SaveSystem 影子落盘 + D 流

**Files:**
- Modify: `scripts/save/game_save.gd`
- Create: `scripts/save/save_system.gd`
- Modify: `project.godot`（仅 `[autoload]` 一行）
- Modify: `tools/spell_save_contract/spell_save_contract.gd`（+D 流）

- [ ] **Step 0: 前置探针（引擎 API 零信任）**——一次性 `-s` 脚本问齐本轮全部不确定点，结论写进报告：①`DirAccess.rename_absolute` 在 4.7.1 存在且对 `user://` 相对路径可行（签名 `static func rename_absolute(from_path: String, to_path: String) -> Error`，跑一次 tmp→正式改名往返）；②`FileAccess.file_exists("user://不存在的.json")==false`；③**autoload 启动序探针（关键）**：`/root/GameSave` 的 `_ready` 与场景根 `_ready` 的先后（GameSave 无信号发射故从未暴露；**SaveSystem 发射不了没关系，但它必须在 GameSave 之后入树，否则 `_ready` 里 `get_node("/root/GameSave")` 取空=影子失明**。一次性夹具双标记打点实锤）；④若③答案为"按注册序"（大概率，Godot 4 即如此），plan 采用 `get_node("/root/SaveSystem")` 追加序（与 B4 一致）；若答案反直觉，改在 `load_from` 首用兜底接线并记判例。
- [ ] **Step 1: 向用户要口令"关了"**——T0 动 `project.godot`，B4 先例流程：口令不到不派本任务（或派单时先跑 Step 2/3 不碰 project.godot，Step 4 挂起等口令——按派单时点实况决定）。
- [ ] **Step 2: D 流失败腿先写**（红=SaveSystem 不存在，红档 `/tmp/opencode/b45_t0/red_d.log`）——八组：①scratch 注入 `slot_path="user://b45_d_stream.json"` + `delete_save()` 起手清场 → `has_save()==false`；②`GameSave.new_profile()` → `claim_namespace(&"b45_probe", &"D流") + record` → `await get_tree().process_frame`（两帧以上）→ 文件存在、`JSON.parse_string` 可读、`version==1`、`ledges.b45_probe` 含该键、**无 `.tmp` 残骸**；③**影子自动触发腿**：不直接调 `save_now()`——先 `save_now()` 落一份基线，然后 `new_profile()`、清 scratch 文件，仅经 GameSave 信号路径（record/add_location_checkpoint/record_checkpoint 各来一发，一帧内连发=合并成一次写）→ 等帧 → 文件回来且内容含三笔（自动影子的存在性证明，本批宪法腿）；④roundtrip：记若干 + `record_checkpoint(seg, entry, "res://fake.tscn")` + `add_location_checkpoint` → `save_now()` → `new_profile()` → `load_game()==true` → 逐键 `has_record` + `checkpoint_scene()=="res://fake.tscn"` + `locations().size()` 还原（R 流"还原真写账"判例沿用）；⑤传渡条款腿：`GameSave.resume_pending=true` → `to_dict()` 顶层 `has("resume_pending")==false` 且 `JSON.stringify(to_dict())` 串中不含 `"resume_pending"` 子串；⑥坏文件腿：scratch 写 `"{{{垃圾"` → `load_game()==false` 且现账一字不动（前后逐键快照比对等）；⑦形状兼容腿：手写 `{"version":1,"ledges":{},"checkpoint":{"segment":"s","entry":"e"}}`（缺 scene/缺 locations）→ `load_game()==true` 且 `checkpoint_scene()==""`、`locations()==[]`——版本 1 形状扩展读端兜底钉死；⑧信号纪律腿：`recorded` 首记一发/重记零发（connect 计数、用完 disconnect，M3 示范形制）。跑套收红档即收工本步。
- [ ] **Step 3:** game_save.gd 增量（一次到位，T1 不再动其结构只动 GameEvents）：三信号声明 + `NS_CHAPTERS_DONE` 随 `_ensure_system_ledges` 预开（中文注"通关事实户，写入方=壳 `_maybe_finish_chapter`（T2）"）+ `var resume_pending := false`（中文注"传渡旗，与 pending_jump_stage 同族——易失，不入 to_dict（D 流⑤钉）"）+ checkpoint 第三字段 `_checkpoint_scene: String`（`record_checkpoint(segment, entry, scene_path := "")` 扩位：入参空且已记账时**保留已记 scene**——中文注理由：回跳传渡段间/两参旧调用不得丢坐标；两行都记则覆写；`checkpoint_recorded.emit` 发三键拷贝）+ `_locations: Array[Dictionary]` + `add_location_checkpoint`（摘旧追新逐位从 GameEvents 搬，发 `location_visited`）+ `locations()`（duplicate 拷贝）+ `to_dict/from_dict` 形状扩展（String 化/还魂/缺键默认）。头注更新指针 spec §2 + 本批三裁决。
- [ ] **Step 4:** save_system.gd 实现（~50 行，无 class_name）：`_ready` 取 `get_node(^"/root/GameSave")`（按 Step 0 ③结论定接线时机；取空=push_error 响亮）连三信号；`_dirty` 标志 + `call_deferred(_flush_if_dirty)` 幂等合并（`if not _dirty or _queued: return` 形制，具体按 Step 0 ④）；`save_now()`：`FileAccess.open(slot_path + ".tmp", WRITE)` 失败 push_error+false → `store_string(JSON.stringify(...))` → close → `DirAccess.rename_absolute(tmp, slot_path)`（失败再 push_error+false+顺手清 tmp）；`load_game()`：`FileAccess.get_file_as_string` → parse → Dictionary 形状/version==SAVE_VERSION/ledges.checkpoint.locations 子形状逐项校验（坏各 push_warning+false）→ `GameSave.from_dict`；`delete_save()` 清正+tmp。project.godot 加行（先备份）→ `git diff project.godot` 逐字核 → `--import` 一次。
- [ ] **Step 5:** D 流全绿；**生产槽零污染总断腿**（裁决形制）：D 流末尾 `FileAccess.file_exists(SaveSystem.AUTOSAVE_PATH)==false`（headless 全程 scratch 纪律的机器锁，破=红）+ 既有消费套**单行 scratch 重定向**：`container_contract._ready` 与 `block_parry_contract._ready` 首行各加 `get_node(^"/root/SaveSystem").slot_path = "user://b45_<套名>_scratch.json"`（一行零逻辑侵入，报告列行号）+ `spell_save_contract` 自身套头 `delete_save()` 清 scratch。分层复跑三套全绿。提交 `feat: SaveSystem 影子落盘——recorded/checkpoint/location 泛信号+帧尾合并+原子写，D 流入册`；报告置顶 **Windows 须重启编辑器认 autoload**；红绿档 `/tmp/opencode/b45_t0/`。

---

### Task 1: 双表彻底合并（GameEvents 降纯总线）

**Files:**
- Modify: `scripts/game_events.gd`
- Modify: `scripts/chapter/chapter_shell.gd:72`、`scenes/base/base_stage.gd:47,169`
- Modify: `ui/menus/death_screen.gd:54`、`ui/menus/pause_menu.gd:76`
- Modify: `tools/stage_contract/stage_contract.gd`（A 组）

- [ ] **Step 1: 改判前红档**——stage_contract A 组探针腿（`:160-191,237` 一带：A5 收尾自洁、A 组摘旧追新/渲染序）先整体切到 `GameSave.add_location_checkpoint/locations()` 新口 + 收尾 `new_profile()`（表随档案：清账=清表），跑 → 旧表（GameEvents）仍被生产写入（改口未拆），菜单读表语义分裂点显形，红档存 `/tmp/opencode/b45_t1/red_pre.log`；报告登记将改判的腿清单。
- [ ] **Step 2:** 生产侧改口三处：`chapter_shell.gd:72`、`base_stage.gd:47` → `GameSave.add_location_checkpoint(...)`；`death_screen.gd:54`/`pause_menu.gd:76` → `GameSave.locations()`（逆序渲染逻辑零动）。
- [ ] **Step 3:** GameEvents 拆除：删 `_session_checkpoints/add_checkpoint/get_checkpoints` + `story_checkpoint_added` 信号（**先 grep 全仓该信号 `.connect(` 消费点=0 再拆**，有消费则随迁 GameSave `location_visited` 并改口处申报）；`reset_session()` 改体为只清 `pending_jump_stage`（头注改写："回标题=清传渡，不清账——清账唯一口 GameSave.new_profile（spec §3）"；调用点 base_stage:169/title:15 不改）；文件头注 S1 立法句里"会话状态"四字出历史注记（数据已迁账）。
- [ ] **Step 4:** stage_contract A 组按新语义逐腿改判（判据变更点写中文注引 spec §3；摘旧追新/尾=最新渲染取逆语义不变——只换主体与清表方式），全绿；分层复跑 `interact_contract` + `container_contract` + `spell_save_contract`（三套都吃建壳链与影子写）。提交 `refactor: 回跳表并入 GameSave 快照——GameEvents 降纯总线，菜单/base_stage 改口，stage_contract A 组改判`。

---

### Task 2: 读档管线（继续/覆盖确认/resume 落位/通关入账）

**Files:**
- Modify: `scripts/chapter/chapter_shell.gd`（scene 缓存+record_checkpoint 传 scene+resume 分支+chapters_done 入账）
- Modify: `ui/menus/title_screen.gd`
- Modify: `tools/spell_save_contract/spell_save_contract.gd`（resume 落位腿+通关入账腿）

- [ ] **Step 1: 失败腿先行**（红档留档）——①resume 落位腿：夹具壳测试内 `new_profile()` → 走段使 `record_checkpoint(段b, 入口e, 场景)` → `resume_pending=true` → queue_free 重建壳实例同场景 → `_ready` 后 `current_segment_id()==段b` 且 `playable.global_position` ≈ 段b 入口位（对照腿：旗 false 时重建→落 `_order[0]`）；②旗消费腿：重建后 `GameSave.resume_pending==false`（first-wins）；③通关入账腿：驱动 `_maybe_finish_chapter` 成功分支 → `has_record(NS_CHAPTERS_DONE, chapter_id)==true` 且 `recorded` 泛信号被影子带出落盘（scratch 重定向下查文件含该户）。
- [ ] **Step 2:** chapter_shell：`_scene_path()` 结果缓存 `_scene_file`；`enter_segment` 内 `session.record_checkpoint(id, entry, _scene_file)`；`_ready` 在 `enter_segment(_order[0], &"default")` 前加 resume 分支（`resume_pending` 且 `checkpoint_scene()==_scene_file` → 消费旗 + `enter_segment(checkpoint_segment(), checkpoint_entry())`，段不在 `_order` 时 push_error 回退首段不炸；否则原逻辑）。
- [ ] **Step 3:** title_screen：`_ready` 在「开始游戏」后加 `add_entry("继续游戏", _continue_game, SaveSystem.has_save())`；`_continue_game()`=`SaveSystem.load_game()` 成功 → `GameSave.resume_pending = true` → `ScreenTransitions.transition_to_scene(GameSave.checkpoint_scene())`（空串=push_error 不转）；「开始游戏」有档时（`SaveSystem.has_save()`）先弹运行时构建 ConfirmationDialog（PROCESS_MODE 随标题壳，dialog 文案"进度将被清除，确定重新开始？"，confirmed=`new_profile()+delete_save()+原转场`，cancel 不转；无档直进=B4 行为零变）。
- [ ] **Step 4:** 分层复跑 spell_save 全套 + container + interact + stage_contract 全绿；提交 `feat: 读档三通道合一——标题继续/新游戏覆盖确认，壳端 resume 落位，通关事实入账 chapters_done`。

---

### Task 3: SpellManager 契约立法 + 补学去重

**Files:**
- Modify: `spells/_base/spell_manager.gd`
- Modify: `characters/playable/chen/chen.gd` + `templates/character/__NAME__.gd`（同文双写，chen 动前 tar 备份至 `/tmp/opencode/b45_t3/`）
- Modify: `tools/spell_save_contract/spell_save_contract.gd`（G 流三式腿）

- [ ] **Step 1:** G 流三式失败腿：`learn_spell(null)==false`（现实现 `is_empty()` 判空槽、definition=null 落槽"成功"——真红主体）；同一 def 连学两次第二次==false（同学科去重未立=第二真红）；正常 def==true 且 `get_spell_slot(0).definition==def`。
- [ ] **Step 2:** spell_manager.gd 立法（中文 API 注释明写契约：`true=新学会占槽；null/同学科重复均 false（push_warning 报警良性违规）`；`def==null` 早退；循环查已有槽 `definition.spell_id == def.spell_id` 拒收——**只按 spell_id 判学科，不按资源同引用**，中文注明防"同 tres 双引用幻影"家族判例的镜像误伤）。
  **已知撞法预裁决（controller 实读定档）**：`tools/spell_cast_test/cast_contract.gd:117/:119` 故意同学两变体占双槽（`_make_def` 复制 fire_ball 同 spell_id）——立法后第二次 learn 必 false。处理=**保法改测试**：该套自造 def 时给第二变体换学科名（如 `def_h.spell_id = &"fire_ball_direct"`，一行+中文注"B4.5 立法改判：异课异槽语义，变体本即不同科目"），勿反向放宽基础类（真语义：同课拒收是防多入口叠槽的宪法，不是防测试）。
- [ ] **Step 2b:** 撞法改判先红后绿：改判前 cast_contract 在新立法下必红（:119 腿）——红档存 `/tmp/opencode/b45_t3/red_cast.log`，换 id 后全绿。
- [ ] **Step 3:** 补学块去噪（chen+模板同文双写）：循环内本地 `var seen: Array[StringName] = []`，`def.spell_id` 重复则 `continue` 后再 learn（基础类报警留给真违规，不报良性重提——spec §5）。
- [ ] **Step 4:** 分层复跑 spell_save 全套 + `hud_test`（槽面消费）+ **`spell_cast_test`（Step 2b 改判主体）** + `spell_hit_test` + `wp2_creation_test`（模板镜像链）+ `test_scene_parity`；提交 `feat: learn_spell 基础类契约立法——null 拒学+同学科去重，补学按 id 去重消噪，cast 变体改判异课`。

---

### Task 4: 终核 + 文档 + F5 + tag

**Files:**
- Modify: spec §3 回写 / `docs/STAGE_ASSEMBLY.md` / `docs/SPELL_SYSTEM_DESIGN.md` / `DEVELOPMENT_STATUS.md` / 根 `AGENTS.md`（非 git）
- Create: `docs/superpowers/plans/2026-09-25-s2-b45-save-persistence-f5.md`

- [ ] **Step 1:** spec §3 补定档句："locations 与 checkpoint 同族入账入快照，from_dict 还魂；resume_pending/pending_jump_stage 属传渡永不入账"（本 plan 执行中定档，文档跟齐）。
- [ ] **Step 2:** **全矩阵 24 套=25 跑终核 RED=0**（含各 scratch 重定向后无生产档污染断言）；AGENTS 更新两处：矩阵名册 spell_save_contract 行描述加"D 流落盘"、账本纪律法尾部补两行——**影子条款**（"记账即落盘，新内容件零自觉调用；存档范围问题在入账那一刻已经回答"）+ **传渡条款**（"一次性意图不入账；回跳/继续/重跑共用检查点，清账唯一口=new_profile"）。
- [ ] **Step 3:** 法典条十一补注（装配者视角：读档=回检查点第三通道，段内入口标记 `entry_position` 的装配义务不变）；SPELL_SYSTEM_DESIGN 补 learn_spell 契约句（null/重复拒收语义+账本幂等分工：账本管"拾得"，基础类管"占槽"，两层双保险互不替代）。
- [ ] **Step 4:** F5 单 `…-b45-save-persistence-f5.md`：头部纪律（关编辑器口令→同步认 `[autoload]` SaveSystem 行→重开 Autoload 列表核→首开补 uid 重存指纹勿慌）；冷启动两连眼：①F6 跑 `chapter_b4.tscn`→E 拾书→按 1 确认会→ESC 回标题→**「继续游戏」亮**→点进→回拾书那段、满状态、书不复活、按 1 仍响（=读档三通道实机证明）；②标题「开始游戏」→**覆盖确认框弹出**→确认→书回原处、按 1 无反应（新档清账+删盘）；③（附）Windows 资源管理器开 `%APPDATA%/Godot/app_userdata/<项目名>/` 看 `save_auto.json` 存在且记事本打开为合法 JSON（影子落盘实机证明）。
- [ ] **Step 5:** DEVELOPMENT_STATUS B4.5 交付行（三裁决 R1-R3+承继 B4 七裁决+红绿档路径）；提交 `docs: B4.5 收口——spec 定档回写、法典/法术文档契约句、影子/传渡条款入 AGENTS、冷启动 F5 单`；`git tag s2-b45-done && git push origin s2-b45-done`。批报告发用户（含：影子触发对生产档的读写实况、测试卫生重定向清单、遗留移交：手动槽/存档元数据 UI→发售打磨批；learn(def) 不校验 def 内容合法性=知情窄口）。
