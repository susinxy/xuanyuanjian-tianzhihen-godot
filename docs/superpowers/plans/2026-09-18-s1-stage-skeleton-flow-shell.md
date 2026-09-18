# S1 地点制关卡骨架与流程壳 · 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 装配本项目第一个可 F5 走通完整流程环的关卡体系：地点制 base_stage 骨架 + 标题/暂停/死亡三壳 + 检查点会话机制 + 装配校验器 + 两个参考地点 + 全流程契约测试。

**Architecture:** base_stage 父场景立四段式节点树与通用胶水（波次聚合、死亡转交、检查点注册），参考地点只做装配不做逻辑；流程壳是三个独立 Control 场景（三层节点+open/close 信号+add_entry 数据驱动），经 GameEvents autoload 与关卡互相发现；校验器把装配规范机械化，先于一切 F5。

**Tech Stack:** Godot 4.7 / GDScript 2 / 自研 Quiver 插件（quiver.beat_em_up）/ headless 契约测试（场景 runner + `-s` 脚本）。

**Spec:** `docs/superpowers/specs/2026-09-18-s1-stage-skeleton-flow-shell-design.md`（连同总纲 `2026-09-18-stage-infrastructure-master-design.md` 一起读）

## Global Constraints

- Godot 4.7，`config_version=5`；GDScript 全部注释用中文（`#`/`##`）。
- 命名：脚本/场景文件 `snake_case`，节点 `PascalCase`；提交信息中文 `feat: …`/`fix: …`/`test: …`/`docs: …`。
- 本机无法运行 Godot 窗口：一切机器验证走 headless：`timeout 300 /home/susinxy/bin/godot/godot --headless --path . <场景.tscn 或 -s 脚本>`；**任何"能玩"结论只能由用户 Windows F5 给出，禁止代宣**。
- headless 纪律（AGENTS 在案）：runner 末尾 `_finished` 防跳段旗；端到端输入用 `Input.parse_input_event(原始按键)` 走全链路；`-s` 脚本无 autoload 场景树语境时引用项目类用 `preload`（class_name 登记盲区）；`-s` 里 `add_child` 后同帧断言是假现场，运行期逻辑用场景 runner。
- 手写 .tscn 雷区（AGENTS 在案）：`&"名字"` 带引号；Vector2/Rect2 必须完整构造式；SubResource id 文件内唯一；uid 冲突宁可不写；`[connection]` 逐条核对。装配时**逐段抄上游 pattern**：`/home/susinxy/code/games/xuanyuan/template-beat-em-up/stages/stage_01/stage_01.tscn`（行号见 spec 调研报告），旧碰撞预设（layer 2/3/4 手配）与 `metadata/collision_type` **禁抄**。
- 全高度层掩码常量（墙体配层用）：`bit14..bit23 = 16760832`（即 `(1<<24)-(1<<14)`）。
- `project.godot` 改动（T1、T6）受编辑器回写纪律约束：施工前请用户 Windows 端关闭编辑器，完成后重启编辑器验证。
- 测试矩阵只增不减：完工后全矩阵（20+本计划两新套=22 项）批末一次、全绿是提交前置。
- 本计划全部文件在项目 git 内；**不触碰** `characters/playable/*`（只读引用 chen/spar 的 tscn 路径）。

## 对 Spec 的一处已批准改良（执行者需知）

spec §5-7 的多生成器聚合原设计"spawner 打组 `<房名>_spawners`"。**改良**：直接读检测器的 `paths_enemy_spawners` 导出（本就要求列全），聚合器无需手工组名——机制同源、装配少一步、漏填由校验器兜底。spec 该行同步修订（T3 内附）。

---

### Task 1: GameEvents 项目总线 + project.godot 接线

**Files:**
- Create: `scripts/game_events.gd`
- Modify: `project.godot`（[autoload] 增 `GameEvents`；[input] 增 `pause`、`debug_restart` 两动作——若 pause 已存在则只补缺项）
- Test: `tools/game_events_check/check.gd`（临时 -s 冒烟，任务内自删，不新增矩阵项）

**Interfaces:**
- Produces: 单例 `/root/GameEvents`，信号 `room_cleared(room_id: StringName)`、`story_checkpoint_added(stage_id: StringName)`、`stage_exited(stage_id: StringName)`；方法 `add_checkpoint(stage_id: StringName, scene_path: String)`、`get_checkpoints() -> Array[Dictionary]`（元素 `{stage_id, scene_path}`）、`reset_session()`。
- Consumes: 无（最底层）。

- [ ] **Step 1: 请用户关闭 Windows 编辑器**（回写纪律；未确认前不动 project.godot）

- [ ] **Step 2: 写 `scripts/game_events.gd`**（完整）

```gdscript
extends Node
## 项目侧事件总线（S1 立法）：一切"项目概念"（房间/检查点/切场）的事件与
## 会话状态住这里；插件 Events 保持上游三信号不动，职责互不侵入。
## 后续子项目只往本文件加信号（S2 flag、S3 item_picked、S4 xp_gained……
## 用到才加，YAGNI）。

## 某战斗房的全部波次清场（载荷=房节点名 StringName）
signal room_cleared(room_id: StringName)
## 检查点注册完成（S5 的自动存档触发源；S1 消费方=DeathScreen 重建列表）
signal story_checkpoint_added(stage_id: StringName)
## 玩家触发地点出口（切场前发；S2 对话/S5 存档挂点）
signal stage_exited(stage_id: StringName)

## 会话检查点表：[{stage_id, scene_path}]，新进入追加；同 stage_id 重入时
## 摘旧追新（保持"新→旧"渲染顺序稳定）
var _session_checkpoints: Array[Dictionary] = []


func add_checkpoint(stage_id: StringName, scene_path: String) -> void:
	if stage_id == &"" or scene_path.is_empty():
		push_warning("GameEvents: 检查点参数不全，忽略 (id=%s path=%s)" % [stage_id, scene_path])
		return
	for i in _session_checkpoints.size():
		if _session_checkpoints[i].stage_id == stage_id:
			_session_checkpoints.remove_at(i)
			break
	_session_checkpoints.append({stage_id = stage_id, scene_path = scene_path})
	story_checkpoint_added.emit(stage_id)


func get_checkpoints() -> Array[Dictionary]:
	return _session_checkpoints.duplicate()


## 清会话（回标题时调用；"重走一遍"同）
func reset_session() -> void:
	_session_checkpoints.clear()
```

- [ ] **Step 3: project.godot 增配置**（`[autoload]` 段尾加一行 `GameEvents="*res://scripts/game_events.gd"`；`[input]` 段按 Godot 序列化格式增 `pause`（ESC+手柄Start）与 `debug_restart`（R）两动作——事件字面量格式抄上游 template-beat-em-up/project.godot 的对应条目，键码 ESC=4194305、R=82、Start button_index=6）

- [ ] **Step 4: 冒烟验证**——写 `tools/game_events_check/check.gd`（`extends SceneTree`，`-s` 跑）：`root.get_node_or_null("GameEvents")` 存在、`add_checkpoint(&"t","p")×2`+重入替换、`get_checkpoints().size()==1`、`reset_session()` 后为 0，全 PASS 打印 `RESULT: n PASS / 0 FAIL`。
Run: `timeout 200 /home/susinxy/bin/godot/godot --headless --path . -s tools/game_events_check/check.gd 2>&1 | grep -E "RESULT|SCRIPT ERROR"`
Expected: `RESULT: 4 PASS / 0 FAIL`
（注意 `-s` 模式下 autoload 是否实例化有版本差异：若 `/root/GameEvents` 为 null，改为 `load()` 直载脚本单元断言，并把"场景 runner 才有 autoload"记进注释——现有 hud_test 等**场景** runner 均可见 autoload，故正式契约不受影响。）

- [ ] **Step 5: 回归既有套**（新 autoload 参与每次启动编译）：跑 `res://tools/hud_test/hud_test.tscn` 与 `res://tools/tree_connectivity_test/connectivity.tscn`，Expected: 双 PASS 零 SCRIPT ERROR。

- [ ] **Step 6: 删临时冒烟，提交**

```bash
git rm -r tools/game_events_check
git add scripts/game_events.gd project.godot
git commit -m "feat: GameEvents 项目事件总线 autoload——room_cleared/story_checkpoint/stage_exited 信号 + 会话检查点注册表（同 id 摘旧追新/回标题清空）；project.godot 补 pause(ESC/Start) 与 debug_restart(R) 输入动作（S1-T1）"
```

---

### Task 2: 流程壳三件套（标题/暂停/死亡）+ 壳契约

**Files:**
- Create: `ui/menus/menu_theme.tres`、`ui/menus/title_screen.tscn|.gd`、`ui/menus/pause_menu.tscn|.gd`、`ui/menus/death_screen.tscn|.gd`
- Create: `tools/stage_contract/stage_contract.tscn|.gd`（本任务的壳段；T3/T5 续加）

**Interfaces:**
- Consumes: T1 `GameEvents.get_checkpoints()`、`ScreenTransitions.transition_to_scene(path)`、`BackgroundLoader.load_resource(path)`。
- Produces（T3/T5 依赖）：`PauseMenu.open_menu()/close_menu()`、信号 `menu_opened/menu_closed`、`add_entry(label: String, callback: Callable) -> Button`；`DeathScreen.open_screen()/close_screen()`；三壳根节点类型 Control、`process_mode=3 (ALWAYS)`、三层子节点命名 `BgLayer/DecoLayer/ContentLayer`；标题场景路径常量 `res://ui/menus/title_screen.tscn`。

- [ ] **Step 1: 壳通用底座**——`ui/menus/menu_entry_list.gd`（挂 ContentLayer 的 VBoxContainer）：

```gdscript
extends VBoxContainer
## 菜单数据驱动条目：add_entry 唯一入口，未来"设置/玩法说明"=加一行数据；
## 焦点样式归 theme，脚本不碰视觉。

func add_entry(label: String, callback: Callable, enabled := true) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.disabled = not enabled
	if callback.is_valid():
		btn.pressed.connect(callback)
	add_child(btn)
	if enabled:
		btn.grab_focus()
	return btn
```

`menu_theme.tres`：Theme 资源，只设 `default_font_size=20`、Button 前景/悬停两色（占位色板），供三壳 `theme` 属性引用。

- [ ] **Step 2: `pause_menu.gd`**（完整逻辑，场景文件含 AnimationPlayer 占位"open/close"零帧动画 + 三层节点，根 process_mode=3、visible=false）：

```gdscript
extends Control
## 暂停壳：ESC toggle；树冻结的置位/解冻全部收口本文件（三解冻路径：
## 继续/跳转类操作前/重载后）。时序铁律（上游教训）：**任何 transition 或
## reload 之前必须先 unpause**，否则转场 tween 在冻结树下永久挂起。

signal menu_opened
signal menu_closed

const TITLE_PATH := "res://ui/menus/title_screen.tscn"

var _entries: VBoxContainer

@onready var _anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_entries = $ContentLayer
	add_entry("继续", close_menu)
	add_entry("回本地点入口", _jump_latest_checkpoint)
	add_entry("返回标题", _goto_title)
	add_entry("退出游戏", _quit)


func add_entry(label: String, callback: Callable, enabled := true) -> Button:
	return _entries.add_entry(label, callback, enabled)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			close_menu()
		else:
			open_menu()
		get_viewport().set_input_as_handled()


func open_menu() -> void:
	if visible:
		return
	visible = true
	get_tree().paused = true
	if _anim.has_animation("open") and _anim.get_animation("open").length > 0.0:
		_anim.play("open")
	menu_opened.emit()


func close_menu() -> void:
	if not visible:
		return
	visible = false
	if _anim.has_animation("close") and _anim.get_animation("close").length > 0.0:
		_anim.play("close")
		# 动画末尾 method track 应调用 unpause_now()；无动画则立即执行
		if not _anim.is_playing():
			unpause_now()
	else:
		unpause_now()
	menu_closed.emit()


## 供动画 method-track 回调（占位批无动画时由 close_menu 直接调）
func unpause_now() -> void:
	get_tree().paused = false


func _jump_latest_checkpoint() -> void:
	var cps: Array[Dictionary] = GameEvents.get_checkpoints()
	unpause_now()
	if cps.is_empty():
		_goto_title()
		return
	GameEvents.pending_jump_stage = cps[0].scene_path
	ScreenTransitions.transition_to_scene(cps[0].scene_path)


func _goto_title() -> void:
	unpause_now()
	GameEvents.pending_jump_stage = ""
	ScreenTransitions.transition_to_scene(TITLE_PATH)


func _quit() -> void:
	get_tree().quit()
```

（`GameEvents.pending_jump_stage: String` 导出跳转意图给重载场景——T3 在 game_events.gd 补该字段与本文件同批改。）

- [ ] **Step 3: `death_screen.gd`**：同底座；`open_screen()` 时从 `GameEvents.get_checkpoints()` **清空重建** ContentLayer 按钮（新→旧，label=stage_id，回调=`_jump_to(cp)`，先 unpause 再 transition）+ 固定末条"返回标题"；订阅 `menu_closed` 无需。**不自行监听 player_died**（T3 base_stage 转交，保持壳被动）。

- [ ] **Step 4: `title_screen.gd`**：`_ready` → `GameEvents.reset_session()` + `GameEvents.pending_jump_stage=""` + `ScreenTransitions.fade_out_transition(0.6)`（淡入标题）+ `BackgroundLoader.load_resource(GAMEPLAY_SCENE)`；条目：开始游戏（`transition_to_scene`）、读取存档（disabled 占位，注释 `TODO(S5)`）、退出游戏。`GAMEPLAY_SCENE := "res://scenes/stages/ref/stage_ref_a.tscn"`（文件 T5 才存在——本任务验证不点击进关，T5 契约段真验）。

- [ ] **Step 5: 壳契约测试段（新建 `tools/stage_contract/stage_contract.gd` 场景 runner，A 段）**：
  - A1 三壳可实例化，根 `process_mode==PROCESS_MODE_ALWAYS`、三层子节点齐、visible=false（title 除外）。
  - A2 pause：`open_menu()` → 断 `get_tree().paused` 为真 + `menu_opened` 计数 1；`close_menu()` → paused 假 + `menu_closed`。
  - A3 ESC 全链路：`Input.parse_input_event(ESC 按下 InputEventKey)` → 注入两拍 physics_frame 后断 toggle 生效（仓库头则：动作匹配原始事件）。
  - A4 `add_entry` 计数与 disabled 态（title 读档钮）。
  - 末尾 `_finished` 旗 + `════════ stage-contract: PASS/FAIL ════════` 汇总（矩阵第 22 项自此登记；**运行命令**同场景 runner 模板）。

- [ ] **Step 6: 跑 A 段**
Run: `timeout 300 /home/susinxy/bin/godot/godot --headless --path . res://tools/stage_contract/stage_contract.tscn 2>&1 | grep -E "stage-contract|FAIL|SCRIPT ERROR"`
Expected: `stage-contract: PASS`（此时套内只有 A 段）

- [ ] **Step 7: game_events.gd 补 `pending_jump_stage: String = ""`；提交**

```bash
git add ui/menus tools/stage_contract scripts/game_events.gd
git commit -m "feat: 流程壳三件套（标题/暂停/死亡结算）——三层节点+open/close 信号+add_entry 数据驱动+theme 单点的视觉替换契约落地（S1 §4.6）；暂停三解冻路径收口、transition 前置 unpause 铁律入注释；stage-contract A 段入矩阵（S1-T2）"
```

---

### Task 3: base_stage 骨架与通用胶水

**Files:**
- Create: `scenes/base/base_stage.tscn|.gd`
- Modify: `docs/superpowers/specs/2026-09-18-s1-stage-skeleton-flow-shell-design.md`（§5-7 聚合行按"已批准改良"修订）
- Test: `tools/stage_contract/stage_contract.gd` 追加 B 段

**Interfaces:**
- Consumes: T1 全部；T2 的 PauseMenu/DeathScreen/GameHUD 场景。
- Produces（T4/T5 依赖）：`BaseStage`（class_name，`extends Node2D`）导出 `stage_id: StringName`、`ends_after_last_room := false`；约定子树路径 `Level/Characters`、`Level/Collisions`、`FightRooms`、`HudLayer/{GameHUD,PauseLayer/PauseMenu,PauseLayer/DeathScreen,StageEndPanel}`、`Ambient`；`find_child("PlayerDetector...", recursive)` 兼容任意房名。

- [ ] **Step 1: `base_stage.gd`**（完整）：

```gdscript
extends Node2D
class_name BaseStage
## 地点制关卡父骨架（S1）：四段式节点树 + 三件通用胶水——
## ①进地点注册检查点；②波次聚合解锁（读检测器 paths_enemy_spawners 导出，
## 全 is_completed 才 setup_after_fight_room + room_cleared——上游逐关手写
## 胶水在此机制化）；③player_died 转交 DeathScreen。
## 参考关两处以后要换的口子以 TODO 挂子项目编号。

@export var stage_id: StringName
@export var ends_after_last_room := false

## room(NodePath) -> {room: QuiverFightRoom, spawners: Array[QuiverEnemySpawner]}
var _rooms := {}
var _cleared_count := 0

@onready var _pause_menu: Control = $HudLayer/PauseLayer/PauseMenu
@onready var _death_screen: Control = $HudLayer/PauseLayer/DeathScreen
@onready var _end_panel: Control = $HudLayer/StageEndPanel


func _ready() -> void:
	randomize()
	GameEvents.add_checkpoint(stage_id, scene_file_path_to_resource())
	# player_died → 死亡界面（S1 唯一流程订阅者；角色自我清理订阅各自在壳脚本）
	Events.player_died.connect(_on_player_died)
	# R 键 debug 重开（上游惯例，仅 debug 构建）
	_collect_rooms()
	if GameEvents.pending_jump_stage == resource_path:
		GameEvents.pending_jump_stage = ""  # 检查点回跳落位，一次性消费


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed("debug_restart"):
		reload_prototype()


func reload_prototype() -> void:
	Events.characters_reseted.emit()
	get_tree().call_deferred("reload_current_scene")


func scene_file_path_to_resource() -> String:
	return "res://" + scene_file_path_from_tree()  # 见 Step 注意


## scene_file_path_from_tree(): 取本场景 resource_path 去 :: 前缀（实例化根
## 场景直接用自身 resource_path）
```

**注意（计划执行者）**：`resource_path` 在被 `change_scene_to_file` 加载后即为 `res://scenes/stages/ref/stage_ref_a.tscn`，上两函数合并简化为 `_ready()` 里 `GameEvents.add_checkpoint(stage_id, scene_file_path)`（Node 属性，Godot 4.2+ 提供；**执行时探针验证**，不存在则回落 `get_tree().current_scene.scene_file_path`）。

```gdscript
func _collect_rooms() -> void:
	for room in $FightRooms.get_children():
		if not (room is QuiverFightRoom):
			continue
		var spawners: Array[QuiverEnemySpawner] = []
		for detector in _room_detectors(room):
			for p in detector.paths_enemy_spawners:
				var sp := room.get_node_or_null(p)
				if sp is QuiverEnemySpawner and not spawners.has(sp):
					spawners.append(sp)
		if spawners.is_empty():
			continue  # 手动开房（代码 setup_fight_room 类）不参与聚合
		_rooms[room.get_path()] = {room = room, spawners = spawners}
		for sp in spawners:
			sp.all_waves_completed.connect(_on_room_wave_completed.bind(room))


func _room_detectors(room: Node) -> Array:
	var out: Array = []
	for c in room.get_children():
		if c is QuiverPlayerDetector:
			out.append(c)
	return out


func _on_room_wave_completed(room: QuiverFightRoom) -> void:
	var entry: Dictionary = _rooms[room.get_path()]
	for sp in entry.spawners:
		if not sp.is_completed:
			return
	room.setup_after_fight_room()
	_cleared_count += 1
	GameEvents.room_cleared.emit(room.name)
	if ends_after_last_room and _cleared_count == _rooms.size():
		_show_end_panel()  # TODO(S2)：剧情批换演出


func _show_end_panel() -> void:
	get_tree().paused = true
	_end_panel.visible = true  # 面板两钮：返回标题/重走一遍（T5 装配时铺按钮）


func _on_player_died() -> void:
	get_tree().paused = true
	_death_screen.open_screen()
```

- [ ] **Step 2: `base_stage.tscn`** 按 spec §4.1 节点表手建：HudLayer(layer=2) 下 GameHUD=实例 `ui/game_hud.tscn`，PauseLayer(Control, process_mode=3) 含 PauseMenu/DeathScreen 两实例，StageEndPanel（PanelContainer+VBox 两按钮：`_on_back_title`→暂停钮同款 unpause+transition；`_on_replay`→`GameEvents.reset_session()`+转场 A 路径常量），Ambient 空 Node2D（CanvasModulate 白色占位），Background 挂 `scripts/debug_background.gd`（现成件）+ ColorRect 地面条 (0,600)-(6000,660) 深色，Level/Characters/Objects/Collisions 空容器（玩家由地点场景自摆）。**无 [connection]**（全部代码接线，防编辑器双路）。

- [ ] **Step 3: 契约 B 段**（stage_contract.gd 追加）：内存搭一个临时 BaseLevel 场景不可取（需真实 base）——直接 `load("res://scenes/base/base_stage.tscn").instantiate()`：
  - B1 结构齐：`Level/Characters`、`FightRooms`、`HudLayer/PauseLayer/PauseMenu` 可寻址；pause/death 隐藏。
  - B2 检查点：add_child 后等两拍，`GameEvents.get_checkpoints()` 含 stage_id（临时实例 export 设 `"t_base"`）。
  - B3 聚合机制：`_rooms` 对空 FightRooms = 空；`_on_room_wave_completed` 对"另一 spawner 未完成"的假数据不解锁（构造 2 个 QuiverEnemySpawner 纯对象挂房下、`is_completed` 手设，断 `room.setup_after_fight_room` 调用计数——相机缺席时该方法 push_error 是已知噪音，用 `_rooms[...].room` 桩替换为计数替身类 `extends QuiverFightRoom` 覆盖方法记录调用）。
  - B4 死亡转交：`Events.player_died.emit()` → 等两拍 → death_screen.visible==true 且树 paused==true。
- [ ] **Step 4: 跑 stage_contract（A+B）** Expected: PASS。
- [ ] **Step 5: spec §5-7 修订行 + 提交**

```bash
git add scenes/base tools/stage_contract docs/superpowers/specs/
git commit -m "feat: base_stage 父骨架——stage_id/ends_after_last_room 导出、进地点注册检查点、波次聚合解锁机制化（读检测器 paths_enemy_spawners，批准改良替代手工组约定，spec §5-7 同步修订）、player_died→DeathScreen 流程首位订阅者、内置 StageEndPanel 两个 TODO 口子（S2 演出/S5 存档）；stage-contract B 段四断言（S1-T3）"
```

---

### Task 4: StageExit 出口件 + 关卡校验器（矩阵第 21 项）

**Files:**
- Create: `scripts/stage_exit.gd`
- Create: `tools/stage_validator/validator.gd`、`tools/stage_validator/fixtures/*.tscn`（6 个违例样本）
- Test: validator 自跑 fixtures + 空 `scenes/stages/`

**Interfaces:**
- Consumes: T1 GameEvents、ScreenTransitions。
- Produces: `StageExit extends Area2D`（export `next_stage_path: String`）；校验器 `-s` 可执行，规则表 R1-R8 对应 spec §5/§6。

- [ ] **Step 1: `stage_exit.gd`**：

```gdscript
extends Area2D
## 跨地点出口触发件（地点制契约）：玩家（area2d:player）进入即发
## stage_exited 并转场到 next_stage_path；防重入旗（转场 await 期间可再次
## 交叠）。collision_mask=0、monitoring=true、检测 body。

@export_file("*.tscn") var next_stage_path := ""

var _triggered := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _triggered or not body.is_in_group("area2d:player"):
		return
	if next_stage_path.is_empty():
		push_error("StageExit 未配置 next_stage_path: %s" % get_path())
		return
	_triggered = true
	GameEvents.stage_exited.emit(body.get_parent().get_parent().name)
	ScreenTransitions.transition_to_scene(next_stage_path)
```

- [ ] **Step 2: 校验器 `validator.gd`**（`extends SceneTree`，`-s` 跑）：目标=遍历 `scenes/stages/**/*.tscn` 文本（DirAccess 递归+FileAccess），规则（R# → 违例样例 fixture 同名）：
  - R1 根 `instance=ExtResource` 指向 base_stage.tscn（地点必须继承骨架）；
  - R2 存在 `stage_id = &"..."` 非空行；
  - R3 每个 `QuiverFightRoom`（按 ext 路径识别+`type="ReferenceRect"`）子树含 ≥1 `QuiverPlayerDetector`（`type="Area2D"`，parent 前缀匹配）与 ≥1 `QuiverEnemySpawner`；
  - R4 检测器行 `path_fight_room = NodePath("..")` 非空、`paths_enemy_spawners = [...]` 至少一路径；
  - R5 spawner `path_spawn_parent` ≠ `NodePath("../../Characters")`（默认值=红）；
  - R6 波次：文件含 `spawn_waves` 且每个引用 SubResource 有 `enemy_scene = ExtResource(...)`，且该 ExtResource path 指向的 .tscn 在盘上存在；
  - R7 `Level/Collisions` 下 StaticBody 的 `collision_layer` 若出现且 `(layer & 0b111)==0` 且 `(layer & 16760832)>0`——旧低位掩码违例（允许 0/纯高度层/0x2 障碍位视违规：S1 收紧为"必须 ⊇全高度层且无 bit1-2 旧屏限顶限位"）；
  - R8 地点含 `StageExit` 子树（script 识别）或 `ends_after_last_room = true`。
  违例逐条 print `FAIL R#: 文件:线索`；结尾 `RESULT: 校验 x 关 / 违例 y`；fixtures 断言模式 `-- --fixtures` 时改跑 `tools/stage_validator/fixtures/` 并期望**恰**触发对应规则（fixture 文件头注释标 `# expect: R5`）。
- [ ] **Step 3: 写 6 个 fixture**（最小假场景文本：无基类 R1 / 无 stage_id R2 / 房无 spawner R3 / 检测器空路径 R4 / 默认 spawn_parent R5 / 旧掩码 R7）
- [ ] **Step 4: 跑校验器双模式**
Run: `... -s tools/stage_validator/validator.gd -- --fixtures 2>&1 | grep -E "RESULT|SCRIPT ERROR"` Expected: fixtures 模式 6/6 规则命中；默认模式空目录 `违例 0`。
- [ ] **Step 5: 提交**

```bash
git add scripts/stage_exit.gd tools/stage_validator
git commit -m "feat: StageExit 跨地点出口件（防重入+stage_exited+转场）与 stage_validator 装配校验器（R1-R8 机械执法 spec §5，矩阵第 21 项；六 fixture 自检规则命中）（S1-T4）"
```

---

### Task 5: 参考地点 A/B 装配 + 全流程契约（C 段）

**Files:**
- Create: `scenes/stages/ref/stage_ref_a.tscn`、`scenes/stages/ref/stage_ref_b.tscn`
- Modify: `tools/stage_contract/stage_contract.gd`（追加 C 段）
- Test: validator 真目录 + stage_contract C 段

**Interfaces:**
- Consumes: T1-T4 全部产物；`res://characters/playable/chen/chen.tscn`、`res://characters/enemies/spar_enemy/spar_enemy.tscn`（只读）；插件 `quiver_level_camera.tscn`。
- Produces: 两地点场景（T6 的 main_scene 指向标题后进 A）。

- [ ] **Step 1: 装配 A**（手写 .tscn；上游 stage_01.tscn 为语法模板，SubResource 波表照其 :150-263 形态）：
  - 根 `StageRefA instance=ExtResource(base)`，`stage_id = &"stage_ref_a"`、`script` 不覆写。
  - `Level/Characters/Chen(instance chen.tscn) @ (300,600)`，其子 `LevelCamera(instance 插件相机)`：`limit_top=-280, limit_bottom=1200, limit_left=0, limit_right=6000`。
  - `Level/Collisions`：Ground（StaticBody2D，RectangleShape 6000×200 中心 (3000,700)，`collision_layer=16760832`）+ WallEndL(0 高墙 x=-50)/WallEndR(x=6050) 同配层。
  - `FightRooms/Room1`：limit_left=380, limit_top=-280, limit_right=1500, limit_bottom=1200, zoom=1.0, `after_fight_use_new_room=true, after_fight_limit_right=2200`（其余 after_* 同基值）；子 `PlayerDetector`（段形 `SegmentShape2D` 端点 (0,±600) 放 x≈520，`collision_layer=0`，detector 组身份检测靠 body 组非掩码，monitorable=false）+ `EnemySpawner1`（@ (900,650)，`path_spawn_parent=NodePath("../../../Level/Characters")`，1 波 1 spar IN_PLACE）；Detector `path_fight_room=NodePath("..")`、`paths_enemy_spawners=[NodePath("../EnemySpawner1")]`。
  - `FightRooms/Room2`：limit_left=1800,right=3000；after right=3800；`PlayerDetector` @x≈1900；**双 spawner** `EnemySpawner1`（2 波：1+1）+`EnemySpawner2`（1 波：1），detector 列两条路径；spar 挂点 Marker 若干。
  - `StageExit` @ (3650,600)：矩形 CollisionShape 100×300，`next_stage_path="res://scenes/stages/ref/stage_ref_b.tscn"`，`collision_layer=0, collision_mask=高度层∪players 位?`——**探针先行**：`body_entered` 需 body 在 mask 匹配层；执行前跑一次性探针脚本取 chen CharacterBody2D 运行时 collision_layer 后回填（引擎零信任），默认 `collision_mask=1|16760832` 起步。
  - Background/Ambient 继承基骨架即可，地面条随骨架已备。
- [ ] **Step 2: 装配 B**：单房 Room1（limit 380-1800，after 同值=无扩区也行）+1 spawner 1 波 2 spar；`ends_after_last_room = true`；无 StageExit；玩家+相机同 A 形态；背景换色区分（ColorRect 微调，占位级）。
- [ ] **Step 3: 校验器过真目录**
Run: validator 默认模式。Expected: `校验 2 关 / 违例 0`。违例即修装配。
- [ ] **Step 4: 契约 C 段**（stage_contract.gd 追加，`change_scene_to_file(A)` 起步）：
  - C1 进场景两拍：GameEvents 含 checkpoint `stage_ref_a`；GameHUD 可见（跟到 chen）。
  - C2 锁房：`chen.global_position.x = 560` → 两拍 → 断 `get_tree().current_scene` 内相机 limit_right==1500（tween 0.8s：等 60 拍）+ EnemySpawner1 敌人已入树（`get_nodes_in_group("area2d:spar_enemy")` ≥1）。
  - C3 聚合：kill 房 1 全部（health_current=0）→ 等待 die 流程 → 断 `room_cleared` 信号 1 次 + tween 后 limit_right==2200。
  - C4 房 2 双 spawner：走到 x=1950 → 全灭（分波 kill，波间隙用 `spawn_current_wave` 自然推进）→ `room_cleared` 第 2 次。
  - C5 切场：传送 x=3650 → `stage_exited` + await 场景变更（轮询 `current_scene.scene_file_path` 含 b，上限 600 拍）。
  - C6 B 清场 → StageEndPanel visible + paused。
  - C7 死亡链：回 A（直接 change_scene）→ `chen.attributes.health_current = 0` 触发玩家侧死亡路径（die 状态需真实攻击？——`player_died` 发射在 die 动画尾帧信标，直调 `Events.player_died.emit()` 亦验转交链；两者都测：直发+`health=0` 走真实 die 流程超时容忍 300 拍）→ death_screen.visible → 其第一检查点钮 `pressed.emit()` → 断转场回 stage_ref_a、paused==false（**回归 §4.5 unpause 铁律**）。
- [ ] **Step 5: 跑 stage_contract 全段 + 全矩阵**
Run: C 段套 + 批末 22 项全矩阵。Expected: 全绿（C 段装配类失败按 AGENTS 先例可豁免项列明后报用户）。
- [ ] **Step 6: 提交**

```bash
git add scenes/stages tools/stage_contract
git commit -m "feat: 参考地点 A/B 装配（A 双房含双生成器聚合+StageExit 切场、B 单房 ends_after_last_room 终点）过校验器零违例；stage-contract C 段全流程环（锁房→波次→聚合解锁→切场→终点→死亡检查点回跳+unpause 铁律回归）（S1-T5）"
```

---

### Task 6: main_scene 落定 + 文档收尾 + 移交 F5

**Files:**
- Modify: `project.godot`（`run/main_scene="res://ui/menus/title_screen.tscn"`）
- Create: `docs/STAGE_ASSEMBLY.md`（spec §5 八条规范全文+雷区+上游禁抄项）
- Modify: `AGENTS.md`（目录节补 `scenes/stages|ui/menus|scripts/game_events` + 装配规范引用；矩阵数 20→22；修正 `_beat_em_up 未建` 陈旧句）、`DEVELOPMENT_STATUS.md`（S1 划线+新里程碑行）、总纲文档 §3-S1 标"已交付待 F5"

- [ ] **Step 1: 用户配合窗口期改 main_scene**（编辑器关闭状态下）并跑一次 `--import` 确认无解析错。
- [ ] **Step 2: 文档四件**（STAGE_ASSEMBLY 内容=spec §5 全文照抄+§6 规则对照表；AGENTS 增行"装配规范见 docs/STAGE_ASSEMBLY.md，新关卡必过 stage_validator"）。
- [ ] **Step 3: 全矩阵 22 项终跑**（含 stage_validator fixtures 模式）全绿。
- [ ] **Step 4: 提交并推送**

```bash
# 注意：AGENTS.md 位于仓库上层（/home/susinxy/code/games/xuanyuan/AGENTS.md，非 git 管理），
# 其修订照常执行但**不进本提交**；git 内改动如下：
git add project.godot docs
git commit -m "docs+config: S1 收尾——main_scene 落标题壳、装配指南成文（STAGE_ASSEMBLY+AGENTS 上层文档引用挂链[非git]+陈旧句修正）、路线图状态更新；全矩阵 22 项绿（S1-T6）"
git push
```
- [ ] **Step 5: 请用户 Windows 重启编辑器后 F5 清单验收**：①开机进标题、三钮焦点正常；②开始→淡入 A；③走过 520 触发锁相机、三波木桩陆续倒下、解锁扩右；④房 2 双刷齐落；⑤走到 3650 淡出切 B；⑥B 清场出终点面板、"重走一遍"回 A；⑦ESC 暂停四钮（继续/回本地点/回标题/退出），暂停中无输入漏进战斗；⑧站桩挨打死→死亡界面列两检查点、点回跳落位正确且**不卡半速**；⑨R 键重开。逐项打钩才算 S1 关账。

---

## Self-Review 记录（计划自检）

1. **Spec 覆盖**：§3 文件表逐件有归属任务✓；§4.1-4.5 契约分布 T2/T3/T5✓；§5 八条=R1-R8✓；§6/§7 两新矩阵项✓；§8 风险一（T1/T6 窗口期）、三（pending_jump 单点传渡）、四（C7 双路测死亡）落进任务步骤✓；§4.6 视觉契约：T2 三层节点+信号+theme 实现，校验器结构警告规则**未入**（降级为壳测试 A1 断言，YAGNI，理由记录）——与 spec 差异：spec 写"可选规则"，A1 更强，取 A1。
2. **占位扫描**：无 TBD 型空转；两处"执行时探针先行"（C5 StageExit mask 取值、B3 替身法）是引擎零信任动作，含明确回退值，非占位。
3. **类型一致**：`add_checkpoint/get_checkpoints/reset_session/pending_jump_stage`（T1 定义、T2/T3/T5 消费）签名一致；`open_menu/close_menu/open_screen/add_entry` 跨任务引用同 T2 产出✓；`16760832` 常量全文统一。
