class_name SessionRules
extends RefCounted

## 壳与单地点骨架共享的会话规则（S2-M1-B1/D10"重构而非复制"）：
## BaseStage 与 ChapterShell 双轨并存，本库存放两者逐位同源的真实重复面
## （路径解析/回跳消费/检测器→生成器采集/终点面板接线/回标题/原型重载），
## 防两份实现漂移。抽取口径=读 base_stage.gd 实况后仅取真实共享件，
## brief 草图的 collect_rooms 与实况房聚合形态不符，裁决弃用（见任务报告）。

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


## 原型重载（debug_restart 腿）：角色复位广播 + 延迟重载当前场景。
static func reload_prototype(tree: SceneTree) -> void:
	Events.characters_reseted.emit()
	tree.call_deferred("reload_current_scene")
