class_name SessionRules
extends RefCounted

## 壳与单地点骨架共享的会话规则（S2-M1-B1/D10"重构而非复制"）：
## BaseStage 与 ChapterShell 双轨并存，本库存放两者逐位同源的真实重复面
## （路径解析/回跳消费/检测器→生成器采集/终点面板接线/回标题/原型重载），
## 防两份实现漂移。抽取口径=读 base_stage.gd 实况后仅取真实共享件，
## brief 草图的 collect_rooms 与实况房聚合形态不符，裁决弃用（见任务报告）。

## 回标题落点（Minor-2 知情注记）：现状三处并存——本库（base/壳共用腿）+
## pause_menu.gd 与 death_screen.gd 的各自私有常数（菜单件在本批抽取域外，
## 未连坐）；单一存放点合并挂 S5 会话整合批，防漂移靠本行注记。
const TITLE_PATH := "res://ui/menus/title_screen.tscn"


## 场景文件路径两形态解析（4.7 探针实证判例，原 BaseStage._scene_path 本体）：
## - current_scene（change_scene 直载）→ scene_file_path 即外层文件；
## - scene_file_path 异于骨架锚点且非空 → 外层文件（场景内实例化根形态）；
## - 其余（骨架本体直挂测试树/"包裹层同名"，探针实证不可判=引擎限制）
##   → get_path() 去 "::" 前缀切片。
## skeleton_file：调用方骨架模板文件（BaseStage 传 base_stage.tscn，
## ChapterShell 传 chapter_shell.tscn——壳根非 BaseStage 实例，锚点各自持有）。
static func resolve_scene_path(node: Node, skeleton_file: String) -> String:
	if node.get_tree().current_scene == node:
		return node.scene_file_path
	if node.scene_file_path != skeleton_file and not node.scene_file_path.is_empty():
		return node.scene_file_path
	var path := str(node.get_path())
	return path.get_slice("::", 0)


## 地点回跳一次性消费（原 BaseStage._ready 内联腿逐位等价）：
## pending_jump_stage 命中本场景路径即清空（检查点回跳落位）。
static func consume_pending_jump(scene_path: String) -> void:
	if GameEvents.pending_jump_stage == scene_path:
		GameEvents.pending_jump_stage = ""


## 检测器导出 → 生成器数组（房聚合与段聚合的单一采集器）：
## 路径相对检测器解析（与 detector._ready 自激活同源，4.7 探针实证——从房框
## 解析会恒 null）；类型过滤+去重（paths 重复项同检测器内吸收）。
static func spawners_from_detector(detector: QuiverPlayerDetector) -> Array[QuiverEnemySpawner]:
	var out: Array[QuiverEnemySpawner] = []
	for p in detector.paths_enemy_spawners:
		var sp := detector.get_node_or_null(p) as QuiverEnemySpawner
		if sp == null or out.has(sp):
			continue
		out.append(sp)
	return out


## 终点面板接线（S1 终审 B7 锁语义）：弹面板会冻结全树，面板继承不到 ALWAYS
## 则两钮 pressed 永闸=不可解软锁；两钮纯代码接线（tscn 零 [connection]，
## 防编辑器双路）。BaseStage 与 ChapterShell 共用。
static func wire_end_panel(panel: Control, on_back_title: Callable, on_replay: Callable) -> void:
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.get_node("PanelBox/BackTitle").pressed.connect(on_back_title)
	panel.get_node("PanelBox/Replay").pressed.connect(on_replay)


## 回标题时序铁律（暂停壳同款）：转场前必须显式解冻，否则 tween 在冻结树下
## 永挂；顺带清掉未被消费的回跳传渡。
static func goto_title(tree: SceneTree) -> void:
	tree.paused = false
	GameEvents.pending_jump_stage = ""
	ScreenTransitions.transition_to_scene(TITLE_PATH)


## 换人接缝手术本体（B2.5/T5，BaseStage 与 ChapterShell 双轨共用，防两份漂移）：
## 释放模板内嵌主角 old，用 override 实例化顶上原槽位——同父/同 index/同名/
## 同出生位；宿主场景根在角色身上额外挂载的子节点（owner==host 判据，4.7.1
## 探针实证：角色本体件 owner=角色根，模板/夹具加挂件 owner=宿主场景根，如
## LevelCamera）随迁替身。挂件先经宿主中转两跳 reparent（reparent 要求双方
## 都在树，而 old.free() 级联即杀仍挂其下的挂件——故**必先摘再 free**，
## keep_global_transform=true 全程保变换）。旧体走**即时 free**（非 queue_free）：
## 槽位名要当帧让给替身，延迟删除会撞名；此刻全树仍在 _ready 同步段，无物理
## 查询回调在途，free 合法。返回新主角；根类型不符返回 null（此时旧体未动、
## 场景原样，由调用方报错弃用）。
static func swap_in_playable(host: Node, old: QuiverCharacter, override: PackedScene) -> QuiverCharacter:
	var inst := override.instantiate()
	var qc := inst as QuiverCharacter
	if qc == null:
		if inst != null:
			inst.free()
		return null
	var parent := old.get_parent()
	var idx := old.get_index()
	var slot := String(old.name)
	var spawn := old.global_position
	var extras: Array[Node] = []
	for c in old.get_children():
		if c.get_owner() == host:
			extras.append(c)
	for c in extras:
		c.reparent(host, true)   # 第一跳：挂件脱体借宿宿主（免被 old 级联释放）
	old.free()
	qc.name = slot
	parent.add_child(qc)
	parent.move_child(qc, idx)
	qc.global_position = spawn
	for c in extras:
		c.reparent(qc, true)   # 第二跳：随迁入替身（全局变换全程锁定）
		# 相机随迁后补位 current（摘旧体会清空 viewport 当前相机指针；
		# 容器 E7 探针按 root.get_camera_2d() 取证，掉相机=锁房链整断）
		var cam := c as Camera2D
		if cam != null and not cam.is_current():
			cam.make_current()
	return qc


## 原型重载（debug_restart 腿/章节重走）：**先显式解冻再重载**（B7 冻结所有权
## 铁律：冻结树被重载继承=新壳出生即 paused、ESC 永闸=不可解软锁——终点面板
## 正是冻结全树后拉"重走一遍"的现场）；随后角色复位广播 + 延迟重载当前场景。
static func reload_prototype(tree: SceneTree) -> void:
	tree.paused = false
	Events.characters_reseted.emit()
	tree.call_deferred("reload_current_scene")
