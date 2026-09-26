# S2-B4.5 存档落盘 + 读档管线 + 一本账闭环 · 设计文档

日期：2026-09-25 ｜ 状态：待用户评审
输入：B4 spec §8 概要（本文将其升格为正式设计）+ B4 七裁决（延续有效）+
2026-09-25 设计会三裁决（见 §8）。

## 0. 定位

把 B4 的内存账本（GameSave）接上硬盘：**账=事实，档=账的快照，读档=三通道之一**。
本批后全游戏只有一本账（双检查点表合并）、存档零自觉（记账即落盘）、
法术基础类契约补洞（learn_spell 语义正式立法）。零插件（addons/）触点。

## 1. 范围

**本批做**：SaveSystem autoload（信号驱动+原子写）+ GameSave 扩展（recorded 信号/
checkpoint 三字段/chapters_done 户/resume 旗）+ 回跳表彻底合并进账本（两菜单改查账）+
标题「继续游戏」+「新游戏覆盖确认」+ 壳端 resume 落位 + SpellManager 学习契约立法 +
契约套 D 流（scratch 真盘）+ stage_contract/interact 相关腿改判 + F5 冷启动两连。
**本批不做**：多槽/手动存档/存档 UI 元数据（发售打磨批）；设置档
（volume/keybinds，另册）；云端/防篡改；存读档动画。

## 2. SaveSystem（`scripts/save/save_system.gd`，autoload，无 class_name）

- **触发=账的自动影子**（§8 裁决 A）：GameSave 新增信号
  `recorded(ns: StringName, id: StringName)`（record 门洞**首记**才发，四账兼容层
  天然经门洞故全覆盖）与 `checkpoint_recorded(checkpoint: Dictionary)`。
  SaveSystem 单监听：置脏 → `call_deferred` 帧尾合并落盘（一帧内多次记账=一次写）。
- 落盘：`to_dict → JSON.stringify → tmp 写 → DirAccess.rename(tmp, 正档)` 原子替换；
  文件 `{"version":1, ...GameSave 快照}`；**写失败 push_error 不抛不断游戏**
  （丢档=可接受灾种，崩游戏=不可接受灾种）。
- 槽：常量 `AUTOSAVE_PATH := "user://save_auto.json"`；`var slot_path` 运行时可注入
  （**契约测试只吃 scratch 名，永不读写生产档**——测试卫生条款）。
- API：`has_save() -> bool` / `save_now() -> bool`（同步强存，供退出路径/测试）/
  `load_game() -> bool`（读+校验+`GameSave.from_dict`，损坏=false 保旧账）/
  `delete_save() -> void`。
- 章终无特判：通关事实走 `record(&"chapters_done", chapter_id)`（新系统户，
  shell `_maybe_finish_chapter` 成功分支写入），落段/记账已触发落盘。

## 3. 一本账闭环（双表彻底合并，§8 裁决 B）

- GameSave.checkpoint 扩为 `{scene_path: String, segment: StringName, entry: StringName}`；
  `record_checkpoint(segment, entry, scene_path := "")` 签名扩位（既有两参调用零破坏），
  发 `checkpoint_recorded`。
- **回跳表迁账**：GameEvents `_session_checkpoints` 数据 + `add_checkpoint/get_checkpoints`
  迁入 GameSave（`add_location_checkpoint(stage_id, scene_path)` / `locations()`，
  同 stage 摘旧追新语义原样搬）；`story_checkpoint_added` 信号随迁 GameSave；
  GameEvents 降回纯事件总线（room_cleared/stage_exited 留守）。消费面改判：
  `ui/menus/death_screen.gd`、`ui/menus/pause_menu.gd`、`scenes/base/base_stage.gd`
  （其 `GameEvents.reset_session()` 语义重审：回标题≠清档——清账唯一口仍是
  new_profile，该调用改为只清传渡）。
- **易失≠账**：`pending_jump_stage`（传渡）与 `resume_pending`（读档意图旗）
  不入账、不进 to_dict——一次性意图随场景消费即灭（first-wins 判例沿用）。
- 菜单回跳行为改判：回跳**不清账**（B4"重演不碰账"延续——旧回跳=整章重载=清账
  的遗产语义随本批寿终）。
- **定档回写（T4，plan Step1；本批实施实况即此条法律）**：locations 与 checkpoint
  同族入账、入快照（`to_dict`），并随 `from_dict` 还魂（读端缺键给默认=形状扩展
  向后兼容）；`resume_pending`/`pending_jump_stage` 属**传渡**，永不入账、不进
  快照、不落盘（first-wins 消费，清传渡的收口=消费命中或 `new_profile`）。

## 4. 读档管线（三通道合一）

标题壳：
- 「继续游戏」：`has_save()` 才 enabled；点击=`load_game()` → 成功则
  `GameSave.resume_pending = true` → 转场 `checkpoint.scene_path`；
- 「开始游戏」：`has_save()` 时拉 **ConfirmationDialog**（运行时构建，无新 .tscn，
  debug 面板先例）"进度将被清除，确定重新开始？"；确认=`new_profile()+delete_save()`
  再进关卡；无档直进（B4 行为不变）；
- 壳 `_ready`：`resume_pending 且 checkpoint.scene_path==本场景路径` →
  消费旗 + `enter_segment(checkpoint.segment, checkpoint.entry)`；
  否则原逻辑 `_order[0]`。死亡重跑/暂停回跳=另两条腿，共用同一 checkpoint 数据。
- 满状态天然成立：读档走全新场景加载，角色出生即满（裁决 B4-R0b 零实现成本）。
- 实况补记（T4）：标题壳 `_ready` 的 `reset_session()` **只清传渡**（pending_jump_stage）
  ——回标题≠清档；连带裁决（T2 Concern-1，controller 认账派单错误）：标题端任何
  "顺手清账/删档"均被否决——回标题即删档=「继续游戏」永死，违 T1"档随档案"宪法。

## 5. SpellManager 学习契约（§8 裁决 C：基础类正式立法，非"顺手"）

`spells/_base/spell_manager.gd::learn_spell`：
- `def == null` → `push_warning` + **return false**（API 文档注释明写契约）；
- **同学科去重**：任一槽已存 `definition.spell_id == def.spell_id` → push_warning +
  return false（防多入口叠槽；《秘籍》/补学本就靠账本幂等，双保险不冲突）；
- 返回语义入 spec 即法：`true=新学会占槽`。

## 6. 契约与验收

- **D 流**（spell_save_contract 扩流，24 套=25 跑口径不变）：
  scratch 注入→record→帧尾后文件存在且 JSON version:1、与账本逐键一致；
  `new_profile→load_game` 还原真写账（R 流同款"还原真写"判例沿用）；
  写垃圾→`load_game()==false` 且现账无损；无档 `has_save()==false`；
  resume_pending 置真后 `to_dict` 不含它（易失条款钉死）；无 tmp 残骸。
- **G 流补腿**：learn(null)==false / 重复同学科==false / 正常==true 三式。
- **改判腿**：stage_contract 与 container/interact 中触到回跳表/reset_session 的腿，
  按 §3 新语义改判（先红后绿留痕，B4-T1 纪律沿用）。
- **R8 不适用**（不新增测试套）；D 流新腿对旧代码天然红（SaveSystem 不存在），
  红档照贴。
- **F5 冷启动两连**（Windows 独占面，机器做不了）：①深处落段→杀进程→重开→
  「继续游戏」→回该段该入口、满状态、已拾书不出现、按 1 仍会；②「开始游戏」
  弹覆盖确认框，确认后一切归零。

## 7. 风险

1. **回跳表迁移波及 base_stage**（非章节轨）：改判面=stage_contract 若干腿——
   T 内先红清点后逐腿改判，勿静默删腿。
2. **帧尾合并落盘的时序**：`call_deferred` 在同帧多次信号下幂等（脏位）；
   契约断言一律 `await get_tree().process_frame` 后再查文件。
3. **user:// 平台差异**：Linux headless 与 Windows 各自独立目录，测试永不碰
   生产槽名（§2 条款），互不污染。
4. **编辑器吞改**：project.godot 加 SaveSystem autoload 一行——Windows 关编辑器
   口令流程沿用（本月三案，纪律已成熟）。
5. `recorded` 信号新增后，既有三兼容信号（flag_added 等）保留不删（消费面在用），
   但**文档注明新监听一律吃 recorded 泛信号**，防信号面漂移。

## 8. 裁决记录（2026-09-25 设计会）

- R1 触发机制：**"账=事实，档=影子"**——所有记账变化（首记）+检查点更新自动触发
  存档事件，内容件零自觉调用；用户口径"开宝箱/学秘籍/落段都是事件的一类，
  后续改变触发存档事件即可"。
- R2 双检查点表**彻底合并**入 GameSave，GameEvents 降纯总线。
- R3 法术基础类（spells/_base）是核心考虑面，learn_spell 契约**正式立法**
  （null 拒+同学科去重+返回语义），撤销 B4 账本"插件红线/顺手改"误标。
- 承继 B4 七裁决：单自动档、满状态复活、读档=回检查点第三通道等全部有效。
