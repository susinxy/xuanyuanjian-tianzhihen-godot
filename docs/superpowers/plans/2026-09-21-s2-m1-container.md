# S2-M1-B1 舞台容器（ChapterShell）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地章节容器 ChapterShell（段切换/会话状态/段级检查点/五壳件上移），以 headless 契约套 `container_contract` 全绿为完成态；单地点 BaseStage 双轨共存零扰动。

**Architecture:** 章节=ChapterShell 场景根（玩家/相机/HUD/壳永驻壳层），段=StageContent 内容件（几何+三件套+背景+可选光照）。段生命周期策略（spike E 组定案）：**未清场的段离开即丢弃、再进时全新重建**（绕开 one-shot 检测器自毁语义，插件零改动）；**已清场的段缓存复用**（is_completed 在内存=清场持久本体）。切换=90 静默帧+在场敌强清+落位+光照复位。

**Tech Stack:** Godot 4.7 GDScript；headless 契约场景（`tools/container_contract/`）；validator 文本执法扩展；无 addons 改动（T7 唯一例外见该任务）。

**Spec:** `docs/superpowers/specs/2026-09-21-s2-prologue-slice-design.md`（§3 全部、§8 B1 行、§9 风险 1/2）

## Global Constraints

- GDScript 4（Godot 4.7）；注释全中文；脚本 `snake_case.gd`、场景 `snake_case.tscn`、节点 `PascalCase`。
- 所有 bash 调用必须带 `workdir: xuanyuan-sword`（仓库根不是 git 目录）。
- `.tscn` 手写守则照 AGENTS（StringName 字典键 `&"k"`、sub_resource id 唯一、uid 可省略、复合属性完整构造式）。
- 暂存逐路径点名，禁 `git add -A`（用户 WIP：project.godot/stage0 可能被编辑器弄脏，永不代收）。
- 契约随批：本 plan 的 T1-T8 每任务收尾=对应契约断言绿+commit；批末全矩阵（23+container_contract=24 套）一次。
- 段内检测器/生成器/房配置一律沿用装配法典现配方（雷区 a/b/c、装配条 2/3/5），本 plan 不重述。
- 开局先打回滚 tag：`git tag pre-s2-m1-b1`（批末保留）。

---

### Task 1: ChapterSession 会话状态核

**Files:**
- Create: `scripts/chapter/chapter_session.gd`
- Create: `tools/container_contract/container_contract.gd`（骨架，本任务只装 S 组）
- Create: `tools/container_contract/container_contract.tscn`

**Interfaces:**
- Produces: `ChapterSession`（class_name）— 字段 `flags/chests/cleared_segments: Dictionary`、`checkpoint: Dictionary`；方法 `add_flag(id: StringName)`、`has_flag(id) -> bool`、`open_chest(id) -> bool`（首次 true）、`is_chest_open(id) -> bool`、`mark_cleared(id)`、`is_cleared(id) -> bool`、`record_checkpoint(segment: StringName, entry: StringName)`、`checkpoint_segment() -> StringName`、`checkpoint_entry() -> StringName`；信号 `flag_added(id)`、`chest_opened(id)`、`segment_cleared(id)`。T2-T5 消费。

- [ ] **Step 1: 写失败测试（S 组单元断言）**

`tools/container_contract/container_contract.gd`:

```gdscript
extends Node

## 舞台容器契约（S2-M1-B1）：ChapterSession 语义（S 组）、壳切换（E 组）、
## 段检查点（D 组）、壳件（H 组）。运行：
## godot --headless --path . res://tools/container_contract/container_contract.tscn

var _fails := 0
var _finished := false


func _ready() -> void:
	await _flow_session()
	_check(_finished, "全序列执行完成（协程静默中断防线）")
	print("════════ container-contract: %s ════════" % ("PASS" if _fails == 0 else "FAIL"))
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails += 1
	print("  %s: %s" % ["PASS" if ok else "FAIL", label])


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _flow_session() -> void:
	var s := ChapterSession.new()
	var got_flag: Array[StringName] = []
	s.flag_added.connect(func(id): got_flag.append(id))
	s.add_flag(&"key_lantern")
	s.add_flag(&"key_lantern")
	_check(s.has_flag(&"key_lantern") and got_flag.size() == 1,
			"S1 旗标幂等（信号只发一次）")
	_check(s.open_chest(&"chest_a") and not s.open_chest(&"chest_a")
			and s.is_chest_open(&"chest_a"), "S2 宝箱一次性语义")
	s.mark_cleared(&"seg_01")
	_check(s.is_cleared(&"seg_01") and not s.is_cleared(&"seg_02"),
			"S3 清场记录按段隔离")
	s.record_checkpoint(&"seg_02", &"gate")
	_check(s.checkpoint_segment() == &"seg_02" and s.checkpoint_entry() == &"gate",
			"S4 检查点记录段+入口名")
	_finished = true
```

`container_contract.tscn`（模式照 knockout_contract）:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tools/container_contract/container_contract.gd" id="1_cc"]

[node name="ContainerContract" type="Node"]
script = ExtResource("1_cc")
```

- [ ] **Step 2: 跑契约确认失败**

Run: `godot --headless --path . res://tools/container_contract/container_contract.tscn`
Expected: `Cannot find class "ChapterSession"` / FAIL。

- [ ] **Step 3: 实现 ChapterSession**

`scripts/chapter/chapter_session.gd`:

```gdscript
class_name ChapterSession
extends RefCounted

## 章节会话状态包 v1（S2-M1-B1，spec §3.3）：与 S5 存档同构的最小核——
## 角色本体状态（hp 等）不在包内（玩家永驻壳内天然延续，spike E6 实证）。

signal flag_added(id: StringName)
signal chest_opened(id: StringName)
signal segment_cleared(id: StringName)

var flags := {}
var chests := {}
var cleared_segments := {}
var checkpoint := {}


func add_flag(id: StringName) -> void:
	if flags.has(id):
		return
	flags[id] = true
	flag_added.emit(id)


func has_flag(id: StringName) -> bool:
	return flags.has(id)


## 开宝箱：首次 true（拾取方），重复 false（消费方据此决定给不给东西）
func open_chest(id: StringName) -> bool:
	if chests.has(id):
		return false
	chests[id] = true
	chest_opened.emit(id)
	return true


func is_chest_open(id: StringName) -> bool:
	return chests.has(id)


func mark_cleared(id: StringName) -> void:
	if cleared_segments.has(id):
		return
	cleared_segments[id] = true
	segment_cleared.emit(id)


func is_cleared(id: StringName) -> bool:
	return cleared_segments.has(id)


func record_checkpoint(segment: StringName, entry: StringName) -> void:
	checkpoint = {"segment": segment, "entry": entry}


func checkpoint_segment() -> StringName:
	return checkpoint.get("segment", &"")


func checkpoint_entry() -> StringName:
	return checkpoint.get("entry", &"default")
```

- [ ] **Step 4: 跑契约确认 S 组 PASS**

Run: 同 Step 2。Expected: `container-contract: PASS`（此时 `_finished=true` 只盖 S 组）。

- [ ] **Step 5: Commit**

```bash
git add scripts/chapter/chapter_session.gd tools/container_contract/
git commit -m "feat: ChapterSession 会话状态核 + container_contract 骨架（S 组）"
```

---

### Task 2: StageContent + 壳最小骨架 +  fixture 段

**Files:**
- Create: `scripts/chapter/stage_content.gd`
- Create: `scripts/chapter/chapter_shell.gd`（本任务只建"进段"半边）
- Create: `scenes/chapter/chapter_shell.tscn`（壳模板场景，章节=实例化它为根，同 BaseStage 双轨惯例）
- Create: `tools/container_contract/fixtures/seg_gate_a.tscn`、`seg_gate_b.tscn`（两个最小可战斗段）
- Modify: `tools/container_contract/container_contract.gd`（追加 E1 组）

**Interfaces:**
- Consumes: ChapterSession（T1）。
- Produces: `StageContent`（class_name）— 导出 `segment_id: StringName`、`entry_points: Dictionary`（`&"default"` 必有）、`lighting_color: Color = Color.WHITE`（段入场画布色）、`auto_complete: bool`（非战斗段）、方法 `entry_position(entry) -> Vector2`、信号 `content_ready`。`ChapterShell`（class_name）— 导出 `chapter_id: StringName`、`segment_scenes: Array[PackedScene]`（推进序=数组序）、`playable_path: NodePath = ^"Players/Chen"`；`enter_segment(id, entry)`（异步）、只读 `session`、`current_segment_id()`；信号 `segment_entered(id)`、`chapter_error(message)`。`scenes/chapter/chapter_shell.tscn` 结构：`ChapterShell(Node2D, 脚本)` + `Players/Chen(实例 chen.tscn)` + `Chen/LevelCamera(实例)` + `HudLayer(CanvasLayer, layer=2)`（子件 T5 才挂）+ `Segments(Node2D)`。

- [ ] **Step 1: 写失败测试（E1 进段可玩）**

在 `container_contract.gd` 的 `_ready` 中把 `_flow_session()` 调用改挂新流程（追加，不改 S 组）：

```gdscript
const FIX_CHAPTER := "res://tools/container_contract/fixtures/chapter_fix.tscn"

# _ready 内 await _flow_session() 之后：
	await _flow_enter()


func _wait_until(pred: Callable, cap: int = 600) -> bool:
	for _i in cap:
		if pred.call():
			return true
		await get_tree().physics_frame
	return pred.call()


func _flow_enter() -> void:
	var shell: ChapterShell = (load(FIX_CHAPTER) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(shell)
	await _frames(20)
	_check(shell.current_segment_id() == &"seg_a",
			"E1a 章节就绪自动进入首段（段内锁房刷怪由 E1b 实证）")
	var chen: QuiverCharacter = shell.playable
	chen.global_position = Vector2(700, 600)
	var spawned: bool = await _wait_until(func():
			return _spar_count() == 1, 240)
	_check(spawned, "E1b 进段后三件套照常：跨线锁房+波次刷怪")
	shell.queue_free()
	await _frames(6)
```

（`_spar_count()` 照容器 spike 文件的组计数写法，本契约文件内自含一份。）

fixtures 三件：
`tools/container_contract/fixtures/seg_gate_a.tscn` — Node2D 根挂 `stage_content.gd`，
`segment_id = &"seg_a"`，内容=容器 spike `stage_a.tscn` 去掉光照子树后的同构
（GroundBody/WallL/WallR 配方 + Room1 三件套）。生成器落位路径按挂载深度定值：
spawner → `..`=Room1 → `../..`=段根 → `../../..`=Segments → `../../../..`=壳根
→ `../../../../Players`，即 **`path_spawn_parent =
NodePath("../../../../Players")`**（段永远挂壳的 Segments 容器下，深度恒定；
E1b 断言即实测钉死此值）。
`seg_gate_b.tscn` 同款 `segment_id = &"seg_b"`、房几何平移 +3000 避免同树瞬间交叠。
`chapter_fix.tscn` — 实例化 `scenes/chapter/chapter_shell.tscn` 为根，
`chapter_id = &"fix"`、`segment_scenes = [ExtResource(seg_a), ExtResource(seg_b)]`、
Players/Chen 就位（壳模板自带）。

- [ ] **Step 2: 跑契约确认 E1 红（类不存在）**

Run: 同前。Expected: 编译失败或 chapter_error。

- [ ] **Step 3: 实现 StageContent / ChapterShell(进段)/ 模板场景**

`scripts/chapter/stage_content.gd`:

```gdscript
class_name StageContent
extends Node2D

## 段内容件基类（S2-M1-B1）：一段的可玩空间=几何+三件套+背景（+可选光照子树）。
## 零壳件（spec §3.1）；生命周期归 ChapterShell（未清场丢弃重建/已清场缓存）。

signal content_ready

@export var segment_id: StringName
## 命名入口 → 段内局部坐标；&"default" 必有（spec §3.2 C4：一律放检测线前场区）
@export var entry_points: Dictionary = {&"default": Vector2(500, 600)}
## 段入场画布色（光照复位责任归壳的输入，spec §3.4 C5）
@export var lighting_color: Color = Color.WHITE
## 非战斗段（过场/尾声）标记：进段即视为清场推进
@export var auto_complete := false


func entry_position(entry: StringName) -> Vector2:
	return entry_points.get(entry, entry_points.get(&"default", Vector2.ZERO))
```

`scripts/chapter/chapter_shell.gd`（本任务版；T3/T4/T5 增量重写其余函数）:

```gdscript
class_name ChapterShell
extends Node2D

## 章节壳（S2-M1-B1，spec §3.1）：段生命周期+会话状态+壳件的唯一宿主。
## 与 BaseStage 双轨（spec D10）：本类只服务章节形态，单地点形态零扰动。

signal segment_entered(id: StringName)
signal chapter_error(message: String)

@export var chapter_id: StringName
@export var segment_scenes: Array[PackedScene] = []
@export_node_path("QuiverCharacter") var playable_path := NodePath("Players/Chen")

var session := ChapterSession.new()
var _instances := {}          # segment_id -> 实例（常驻缓存，spec D12 缓存面）
var _order: Array[StringName] = []
var _current: StageContent = null


@onready var playable: QuiverCharacter = get_node_or_null(playable_path)
@onready var _segments_root: Node2D = $Segments


func _ready() -> void:
	if playable == null:
		chapter_error.emit("playable 缺席（playable_path 未指向有效角色）")
		return
	for sc in segment_scenes:
		var inst := _instantiate(sc)
		if inst == null:
			continue
		if inst.segment_id in _order:
			chapter_error.emit("segment_id 重复: %s" % inst.segment_id)
			continue
		_order.append(inst.segment_id)
	if _order.is_empty():
		chapter_error.emit("零段可进（segment_scenes 空/全坏）")
		return
	enter_segment(_order[0], &"default")


func current_segment_id() -> StringName:
	return _current.segment_id if _current != null else &""


## 未清场段=丢弃重建（清掉上一次未通关的痕迹：one-shot 检测器自毁语义下的
## 段重试正道，spec D4/D12）；已清场段=缓存复用（清场持久本体）。
func enter_segment(id: StringName, entry: StringName) -> void:
	if _current != null:
		_remove_current()
	var inst: StageContent = null
	if session.is_cleared(id):
		inst = _instances.get(id)
	if inst == null:
		inst = _instantiate(_scene_of(id))
		if inst == null:
			chapter_error.emit("段场景实例化失败: %s" % id)
			return
		_instances[id] = inst
	_current = inst
	_segments_root.add_child(_current)
	playable.global_position = _current.to_global(
			_current.entry_position(entry))
	session.record_checkpoint(id, entry)
	# C5 光照复位（画布件在段内，T3 完整实现，本版先广播入场）
	segment_entered.emit(id)
	if _current.auto_complete:
		session.mark_cleared(id)


func _instantiate(sc: PackedScene) -> StageContent:
	if sc == null:
		return null
	var n := sc.instantiate()
	return n as StageContent


func _scene_of(id: StringName) -> PackedScene:
	for i in _order.size():
		if _order[i] == id:
			return segment_scenes[i]
	return null


func _remove_current() -> void:
	# 丢弃策略下段实例不留场：清场缓存的段留在 _instances（add_child 与否由
	# 下次进入决定），未清场的连同其树下一切直接释放。
	if _current == null:
		return
	var sid := _current.segment_id
	if session.is_cleared(sid):
		_current.get_parent().remove_child(_current)   # 保活在 _instances
	else:
		_current.queue_free()
		_instances.erase(sid)
	_current = null
```

`scenes/chapter/chapter_shell.tscn`（手写，chen/cam/HUD 的 ext uid 抄 base_stage.tscn 现值；HudLayer 本任务空壳）：根 `ChapterShell` 挂脚本 + `Players/Chen(LevelCamera)` + `HudLayer(CanvasLayer layer=2)` + `Segments(Node2D)`，段数组留空（fixture 覆盖）。

- [ ] **Step 4: 契约 E1 组转绿**

Run 容器契约。Expected: S 组+E1a/E1b PASS。

- [ ] **Step 5: Commit**

```bash
git add scripts/chapter/ scenes/chapter/ tools/container_contract/
git commit -m "feat: ChapterShell 进段半边 + StageContent + 模板场景（契约 E1）"
```

---

### Task 3: 切换完整策略（静默窗/强清/推进链/光照复位）

**Files:**
- Modify: `scripts/chapter/chapter_shell.gd`
- Modify: `tools/container_contract/container_contract.gd`（E2-E5 组）
- Create: `tools/container_contract/fixtures/seg_light_c.tscn`（带光照子树的第三段）

**Interfaces:**
- Produces: `switch_segment(id := &"", entry := &"default")`（id 空=顺序推进）、
  `on_room_cleared(id)`（三件套聚合入口，T3 内信号接线）、
  `segment_cleared(id: StringName)`、`segment_advance_failed(reason)` 信号；
  消费 `StageContent.lighting_color`。

- [ ] **Step 1: 失败测试**

```gdscript
func _flow_switch() -> void:
	var shell: ChapterShell = (load(FIX_CHAPTER) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(shell)
	await _frames(20)
	# E2 主动切换：摘挂+落位+玩家留存
	var chen: QuiverCharacter = shell.playable
	await shell.switch_segment(&"seg_b", &"default")
	_check(shell.current_segment_id() == &"seg_b"
			and chen.is_inside_tree() and _spar_count() == 0,
			"E2 切段：A 摘树/B 进树/玩家永驻且场上无敌残留")
	# E3 清场持久：回 A 前先标记清场 → 缓存复用（刷怪不复出）
	shell.session.mark_cleared(&"seg_b")
	await shell.switch_segment(&"seg_a", &"default")
	await shell.switch_segment(&"seg_b", &"default")
	_check(_spar_count() == 0,
			"E3 已清场段缓存复用：零复活（清场持久本体）")
	# E4 未清场丢弃：seg_a 被踢出后再进=全新（检测器可再触发）
	await shell.switch_segment(&"seg_a", &"default")
	chen.global_position = Vector2(700, 600)
	var respawn: bool = await _wait_until(func(): return _spar_count() == 1, 240)
	_check(respawn, "E4 未清场丢弃重建：段重试可再触发（检测器自毁语义闭环）")
	# E5 光照复位：进带色段后画布色=段配置
	await shell.switch_segment(&"seg_c", &"default")
	await _frames(4)
	_check(_canvas_modulates_white_or_c(), "E5 段入场光照色由壳复位")
	shell.queue_free()
	await _frames(6)
```

（`_canvas_modulates_white_or_c()`：契约内取 `shell` 所在 viewport 生效色简化为：
断言壳写入了段色记录 `shell.applied_lighting == seg_c.lighting_color`——
壳导出只读变量，避免摸引擎画布合成，断言实现以壳记录为准。）

- [ ] **Step 2: 确认红**；**Step 3: 实装**

`chapter_shell.gd` 增补（插在 enter_segment 之后，enter_segment 的
`segment_entered.emit` 前改为调用 `_apply_lighting()`）：

```gdscript
signal segment_cleared(id: StringName)
signal segment_advance_failed(reason: String)

var applied_lighting := Color.WHITE
var _switching := false


## 顺序推进（id 空=下一段）；段清除链的出口。
func switch_segment(id: StringName = &"", entry: StringName = &"default") -> void:
	if _switching:
		return
	_switching = true
	var target := id
	if target == &"":
		var idx := _order.find(current_segment_id())
		if idx >= _order.size() - 1:
			_switching = false
			segment_advance_failed.emit("章节终点（无后继段）")
			return
		target = _order[idx + 1]
	await _settle_before_switch()
	_switching = false
	enter_segment(target, entry)


## 切换三拍（spec §3.4 C2/C3）：静默窗让在途 tween 落位；
## 在场敌强清（策略 A）并等 tree_exited 结算有界 120 帧。
func _settle_before_switch() -> void:
	await _frames(90)
	var live := _live_enemies()
	for e in live:
		e.queue_free()
	if not live.is_empty():
		var waited := 0
		while _live_enemies().size() > 0 and waited < 120:
			await get_tree().physics_frame
			waited += 1


func _live_enemies() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("area2d:spar_enemy"):
		if n is QuiverCharacter:
			out.append(n)
	return out


func _apply_lighting(seg: StageContent) -> void:
	# C5：段入场画布复位责任在壳。画布级合成色经 CanvasModulate（段内件若存在）
	# 或壳内备用 CanvasModulate 承载：壳自建，保证"每段必有其色"。
	applied_lighting = seg.lighting_color
	_shell_canvas.color = seg.lighting_color
```

壳模板场景 `chapter_shell.tscn` 补 `Ambient/CanvasModulate`（壳自建，段内不再放
CanvasModulate——**修订 T2 fixture 与法典口径：光照子树的 CanvasModulate 归壳，
KeyLight/Controller 可留段内**）；`chapter_shell.gd` 增
`@onready var _shell_canvas: CanvasModulate = $Ambient/CanvasModulate`，
`enter_segment` 尾部调用 `_apply_lighting(_current)`。

段清除聚合链（同文件追加）：

```gdscript
func enter_segment(id: StringName, entry: StringName) -> void:
	...原逻辑...
	_wire_segment(_current)
	segment_entered.emit(id)
	if _current.auto_complete:
		session.mark_cleared(id)
		switch_segment.call_deferred()


func _wire_segment(seg: StageContent) -> void:
	for det in seg.find_children("*", "", true, false):
		if not (det is QuiverPlayerDetector):
			continue
		for sp_path in det.paths_enemy_spawners:
			var sp := det.get_node_or_null(sp_path) as QuiverEnemySpawner
			if sp != null and not sp.all_waves_completed.is_connected(
					_on_spawner_completed.bind(seg)):
				sp.all_waves_completed.connect(_on_spawner_completed.bind(seg))
	# 无房/无生成器的战斗空段防呆：进段即完成条件=auto_complete 已覆盖


func _on_spawner_completed(seg: StageContent) -> void:
	# 段内全部 spawner 完成才算段清（多房段聚合，spec §3.1）
	for sp in seg.find_children("*", "Marker2D", true, false):
		if sp is QuiverEnemySpawner and not sp.is_completed:
			return
	_finish_segment(seg)


func _finish_segment(seg: StageContent) -> void:
	if seg == null or session.is_cleared(seg.segment_id):
		return
	session.mark_cleared(seg.segment_id)
	for room in seg.find_children("*", "ReferenceRect", true, false):
		if room is QuiverFightRoom:
			room.setup_after_fight_room()   # 房内解锁演出保留
	segment_cleared.emit(seg.segment_id)
	if seg == _current:
		switch_segment.call_deferred()
```

（注意 `seg.find_children` 的 `QuiverEnemySpawner` 实际挂 Marker2D 型节点上，
用 `is` 过滤即可；`_current` 判等避免延迟信号打到旧段。）

- [ ] **Step 4: 契约 E 组转绿（E2-E5）**；**Step 5: Commit**
`"feat: 壳切换三拍+清场聚合推进+光照复位（契约 E2-E5）"`

---

### Task 4: 段级检查点与死亡/强制切段

**Files:**
- Modify: `scripts/chapter/chapter_shell.gd`
- Modify: `tools/container_contract/container_contract.gd`（D 组）

**Interfaces:**
- Consumes: `Events.player_died`、`session.checkpoint_*()`、`QuiverAttributes.reset()`。
- Produces: `restart_segment(why := &"death")`（公开，曹氏血崩复用）、
  `force_advance_current(reason)` 曹氏式强制切段、信号 `segment_restarted(why)`、
  `Events` 接线：死亡不再弹死亡壳（D4 段重跑），壳内转接。

- [ ] **Step 1: 失败测试**

```gdscript
func _flow_death() -> void:
	var shell: ChapterShell = (load(FIX_CHAPTER) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(shell)
	await _frames(20)
	var chen: QuiverCharacter = shell.playable
	chen.global_position = Vector2(700, 600)   # 跨线引刷
	await _wait_until(func(): return _spar_count() == 1, 240)
	chen.attributes.health_current = 1
	CombatSystem.apply_damage(_one_shot_attack(), chen.attributes)  # 真死链
	chen.attributes.health_current = 0
	var restarted := false
	shell.segment_restarted.connect(func(_w): restarted = true)
	await _wait_until(func(): return restarted, 300)
	await _frames(120)   # 死亡演出+重进段
	_check(chen.attributes.health_current == chen.attributes.health_max
			and chen.global_position.is_equal_approx(Vector2(500, 600))
			and shell.current_segment_id() == &"seg_a",
			"D1 死亡=段重跑：满血/回入口点/仍在本段")
	chen.global_position = Vector2(700, 600)   # 重进段后再跨线
	var spawn_again: bool = await _wait_until(func(): return _spar_count() == 1, 300)
	_check(spawn_again, "D2 未清场段重跑=敌复位（丢弃重建红利）")
	shell.queue_free()


func _one_shot_attack() -> QuiverAttackData:
	var a := QuiverAttackData.new()
	a.attack_damage = 50
	return a
```

- [ ] **Step 2: 红**；**Step 3: 实装**（`chapter_shell.gd` 追加；
`_ready()` 现体尾部补一行 `Events.player_died.connect(_on_player_died)`）

```gdscript
signal segment_restarted(why: StringName)


func _on_player_died() -> void:
	# spec D4：段级重跑取代地点死亡壳（地点级回跳仍归暂停壳/检查点表）
	restart_segment(&"death")


func restart_segment(why: StringName = &"manual") -> void:
	if playable == null:
		return
	playable.attributes.reset()
	await _settle_before_switch()
	enter_segment(session.checkpoint_segment(), session.checkpoint_entry())
	segment_restarted.emit(why)


## 曹氏血崩等"历史不可变强制推进"（spec D6）：当前段判清+前进
func force_advance_current(reason: StringName) -> void:
	if _current == null:
		return
	session.mark_cleared(_current.segment_id)
	switch_segment.call_deferred()
	segment_restarted.emit(reason)
```

（`Events.player_died` 现有订阅者是 BaseStage——**双轨同场风险**：fixture 章无
BaseStage 不受扰；正式章节场景内不得再混挂 base_stage（validator R1 单根已天然
保证）。BaseStage._on_player_died 不动，两形态各自订阅各的树。）

- [ ] **Step 4: D 组绿**；**Step 5: Commit**
`"feat: 段级检查点+死亡段重跑+强制推进 API（契约 D1-D2）"`

---

### Task 5: 壳五职责齐平 +  playable 接口位

**Files:**
- Modify: `scripts/chapter/chapter_shell.gd`
- Modify: `scenes/chapter/chapter_shell.tscn`
- Modify: `tools/container_contract/container_contract.gd`（H 组）

**Interfaces:**
- Consumes: `ui/menus/pause_menu.tscn`、`death_screen.tscn`、`ui/game_hud.tscn`
  （实例引用同 base_stage.tscn 的 ext 值）。
- Produces: 壳内 `HudLayer/GameHUD + PauseLayer/PauseMenu/DeathScreen + StageEndPanel`
  等价件与 ESC 冻结纪律（照 BaseStage `_ready` 行为：pause 监听、冻结态防叠开 B7
  锁语义的容器版）；`playable: QuiverCharacter` 换角接口位（D11：`set_playable()`
  仅换引用+重绑 `area2d:player` 组校验，实现留 D2 批）；`chapter_finished`
  信号（终点段清且无后继=发射，B7 过场批消费）。

- [ ] **Step 1-5**: H 组断言：`shell.get_node("HudLayer/PauseLayer/PauseMenu")`
  在位；raw ESC 注入 → `get_tree().paused` 翻转、再按还原；
  `segment_advance_failed` 在终点段触发后 `chapter_finished` 发射一次。
  实装=从 BaseStage 平移五段胶水进壳（**平移后 BaseStage 改调
  `scripts/chapter/session_rules.gd` 新静态库共享波次收集与转场检查逻辑——
  spec D10"重构而非复制"的落点**）：

```gdscript
# scripts/chapter/session_rules.gd
class_name SessionRules
extends RefCounted

## 壳与单地点骨架共享的会话规则（S2-M1-B1/D10）：防两份实现漂移。

## 从任意根收集 {room: QuiverFightRoom, spawners: Array} —— 房聚合的单一采集器。
static func collect_rooms(root: Node) -> Dictionary:
	var rooms := {}
	for n in root.find_children("*", "", true, false):
		if not (n is QuiverFightRoom):
			continue
		var entry := {"room": n, "spawners": []}
		rooms[n.name] = entry
	return rooms


## 地点回跳消费（pending_jump_stage 与场景路径的既有一致逻辑，从 BaseStage 抽出）。
static func consume_pending_jump(root: BaseStage, scene_path: String) -> void:
	if GameEvents.pending_jump_stage == scene_path:
		GameEvents.pending_jump_stage = ""
```

（BaseStage 内联调用点改造保持行为逐位等价——stage_contract 128 条是本任务
最硬回归闸。）

Commit: `"feat: 壳件齐平（HUD/ESC/终点）+ SessionRules 共享库抽取（契约 H 组）"`

---

### Task 6: 插件最小补丁——收口回调树守卫（C2 双保险第二层）

**Files:**
- Modify: `addons/quiver.beat_em_up/utilities/custom_nodes/quiver_fight_room.gd:202`
  附近（`_clamp_players_into_room`）
- Test: `tools/container_contract/container_contract.gd`（E6 迟到回调不炸）

- [ ] **Step 1**: 契约 E6：段战斗中（收口 tween 在途）立刻 `remove_child(room.get_parent())`…实装以壳切换窗口内人工制造"摘段时 tween 未落地"：进段→跨线（锁房 tween 0.8s）→45 帧内强制 `switch_segment` → 断言 stderr 无该函数 SCRIPT ERROR（契约以 `shell.applied_lighting` 正常到达+进程不崩为绿）。
- [ ] **Step 2**: 红（现网 spike C2 已实锤此炸点路径）。
- [ ] **Step 3**: 插件 3 行守卫：

```gdscript
	# 容器切换判例（2026-09-21 spike C2）：tween.finished 迟到时本节点可能
	# 已摘树（段丢弃），get_tree() 为空——守卫先行
	if not is_inside_tree():
		return
```

- [ ] **Step 4**: E6 绿 + **全矩阵含 stage_contract**（插件改动批必跑全量）。
- [ ] **Step 5**: Commit（**同批文档义务**：`docs/PLUGIN_ARCHITECTURE.md` 收口节
  补守卫句 + 根 `PLUGIN_CHANGES.md` 案卷段——addons 改动规矩）。

---

### Task 7: 法典/validator/文档双轨扩

**Files:**
- Modify: `tools/stage_validator/validator.gd`（R1 双形态/R2 条件化+R2'/R5 白名单）
- Create: `tools/stage_validator/fixtures/r1_shell_ok.tscn`（expect none 型双轨正例）、`r1_bad_root.tscn` 既有不动
- Modify: `docs/STAGE_ASSEMBLY.md`（〇章加"章节形态"小节：壳模板用法+段内容件字段卡）
- Modify: `DEVELOPMENT_STATUS.md`、`../AGENTS.md`（矩阵计数、里程碑行）

- [ ] **Step 1**: validator 规则改写：R1 允许根 instance ∈ {base_stage.tscn,
  chapter_shell.tscn}；根为壳形态时 R2 检查 `chapter_id = &"..."` 非空（R2'
  并表 R2 同码报告 hint 区分）；R5 追加合法 spawn 父形态 `../../../../Players`（壳形态段挂 Segments 下恒 4 级）；
- [ ] **Step 2**: 新 fixture（实例化 chapter_shell.tscn + 一个 StageContent 子段，
  stage_id 缺席但 chapter_id 在位→0 违例）+ 反例（两 id 皆缺→R2 红）跑 `--fixtures` 全绿；
- [ ] **Step 3**: 法典：〇章 0.2 前插"路线 C——新章节用壳形态"三行；0.3 追加
  StageContent 字段卡；"装配八条"→九条已有先例，本次不动条号只加口径注；
- [ ] **Step 4**: 全绿后 Commit `"docs+tools: 法典双轨扩（R1/R2'/R5）+ validator 壳形态 fixture"`

---

### Task 8: 批收口——全矩阵 + F5 移交单

- [ ] 全矩阵 **24 套**（23 存量 + container_contract），一次；任何红回修不回滚。
- [ ] 文档计数三处同步（AGENTS/DEVELOPMENT_STATUS/契约头注释）。
- [ ] Commit + push；tag：`s2-m1-b1-done`。
- [ ] 产出用户 F5 移交单：`res://tools/container_contract/fixtures/chapter_fix.tscn`
  F6 单跑 → 跨线刷怪、被杀自动回段首、按序进 B 段再回 A 验证持久/丢弃手感；
  以及"壳模板场景可拖新段"的 30 秒演示。

---

## 契约清单 ↔ spec 映射（自检锚）

| spec 条目 | 断言 |
|---|---|
| §3.4 C1 五职责 | T5 H 组 |
| §3.4 C2 tween | T6 E6 + T3 静默窗 |
| §3.4 C3 强清 | T3 E2 |
| §3.4 C4 入口纪律 | T2 E1b（default 入口=线西实证）|
| §3.4 C5 光照复位 | T3 E5 |
| §3.2 双轨 | T7 validator fixture |
| §3.3 状态包 | T1 S 组 |
| D4 段重跑 | T4 D1/D2 |
| D12 缓存/丢弃 | T3 E3/E4 |
