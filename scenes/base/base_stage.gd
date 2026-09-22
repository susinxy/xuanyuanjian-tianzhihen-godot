extends Node2D
class_name BaseStage
## 地点制关卡父骨架（S1）：四段式节点树 + 三件通用胶水——
## ①进地点注册检查点；②波次聚合解锁（读检测器 paths_enemy_spawners 导出，
## 全 is_completed 才 setup_after_fight_room + room_cleared——上游逐关手写
## 胶水在此机制化）；③player_died 转交 DeathScreen。
## 参考关两处以后要换的口子以 TODO 挂子项目编号。

## 重走一遍的落点（T5 已落地；下方存在性守卫是文件级防御，非待办口子）
const STAGE_A_PATH := "res://scenes/stages/ref/stage_ref_a.tscn"
## 本骨架文件自身（_scene_path 判别"实例化根被祖先污染"用的锚点）
const BASE_SCENE_FILE := "res://scenes/base/base_stage.tscn"

@export var stage_id: StringName
@export var ends_after_last_room := false

## 软边阴影合成层覆写（默认哨兵=自动档 z=Level.z_index-1，装配者无需感知；
## 唯一合法改值理由=本地点有压在世界内容之上、又要在阴影之上的特殊裸层件。
## 派生逻辑单一存于 ShadowSoftEdge.derived_z_for，此处仅存意图覆写）
@export var shadow_composite_override: int = -2147483648

## room(NodePath) -> {room: QuiverFightRoom, spawners: Array[QuiverEnemySpawner]}
var _rooms := {}
var _cleared_count := 0

@onready var _pause_menu: Control = $HudLayer/PauseLayer/PauseMenu
@onready var _death_screen: Control = $HudLayer/PauseLayer/DeathScreen
@onready var _end_panel: Control = $HudLayer/StageEndPanel


func _ready() -> void:
	# 计划草稿的 resource_path 系 Node 上不存在的杜撰属性（T3 探针裁决弃用）；
	# 可转场路径的三形态解析收口在 _scene_path()
	GameEvents.add_checkpoint(stage_id, _scene_path())
	# 层级军规 canary（法典 R10 runtime 腿）：背景 CanvasLayer ≥0 会盖掉全部世界
	# 内容（文本校验看不见"忘写 layer=默认 1"这类缺失，这里兜底）。子 _ready 先跑，
	# debug 背景已置 -10；正式背景换件同样必须负档——软边自动档落位的承重墙。
	var bg := get_node_or_null("Background") as CanvasLayer
	if bg != null and bg.layer >= 0:
		push_warning("BaseStage: Background.layer=%d ≥ 0 将盖住世界内容，须负档（法典 R10）" % bg.layer)
	# player_died → 死亡界面（S1 唯一流程订阅者；角色自我清理订阅各自在壳脚本）
	Events.player_died.connect(_on_player_died)
	_collect_rooms()
	# 检查点回跳落位，一次性消费（T5/D10：与壳同源，规则本体在 SessionRules）
	SessionRules.consume_pending_jump(_scene_path())
	# 终点面板接线（tscn 零 [connection] 防编辑器双路 + 冻结树 ALWAYS——
	# B7 死锁锁语义）：与壳同源收进 SessionRules.wire_end_panel
	SessionRules.wire_end_panel(_end_panel, _on_back_title, _on_replay)


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed("debug_restart"):
		reload_prototype()


func reload_prototype() -> void:
	SessionRules.reload_prototype(get_tree())


## 本场景可转场文件路径（检查点注册/回跳比对单一入口）。两形态判例与
## 章节壳同源（T5/D10），解析规则本体在 SessionRules.resolve_scene_path，
## 锚点=本骨架文件；边界（骨架本体直挂测试树等）见 SessionRules 注释。
func _scene_path() -> String:
	return SessionRules.resolve_scene_path(self, BASE_SCENE_FILE)


func _collect_rooms() -> void:
	for room in $FightRooms.get_children():
		if not (room is QuiverFightRoom):
			continue
		var spawners: Array[QuiverEnemySpawner] = []
		for detector in _room_detectors(room):
			# 检测器导出→生成器的相对解析/去重与壳段聚合同源（T5/D10）
			for sp in SessionRules.spawners_from_detector(detector):
				if not spawners.has(sp):
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
	var key: NodePath = room.get_path()
	if not _rooms.has(key):
		# 瞬态取证：谁的表、哪个房、双方是否在树（跨实例/重连竞态诊断）
		push_warning("ROOMKEY MISS key=%s self=%s in_tree=%s room_in_tree=%s keys=%s" % [
				key, get_path(), str(is_inside_tree()), str(room.is_inside_tree()), str(_rooms.keys())])
		return
	var entry: Dictionary = _rooms[key]
	for sp in entry.spawners:
		if not sp.is_completed:
			return
	room.setup_after_fight_room()
	_cleared_count += 1
	GameEvents.room_cleared.emit(room.name)
	if ends_after_last_room and _cleared_count == _rooms.size():
		_show_end_panel()  # TODO(S3)：剧情批换演出（编号 2026-09-21 换序：S2=切片 S3=对话）


func _show_end_panel() -> void:
	get_tree().paused = true
	_end_panel.visible = true  # 面板两钮（返回标题/重走一遍）已在 _ready 代码接线


func _on_player_died() -> void:
	get_tree().paused = true
	_death_screen.open_screen()


## 时序铁律（转场前显式解冻）与回跳清理与壳同源，本体在 SessionRules.goto_title
func _on_back_title() -> void:
	SessionRules.goto_title(get_tree())


func _on_replay() -> void:
	get_tree().paused = false
	GameEvents.reset_session()
	# 守卫仅作文件缺失防御（A 已由 T5 落地，正常链路走 transition）
	if not ResourceLoader.exists(STAGE_A_PATH):
		push_error("参考地点 A 文件缺失：%s" % STAGE_A_PATH)
		return
	ScreenTransitions.transition_to_scene(STAGE_A_PATH)
