extends Node2D
class_name BaseStage
## 地点制关卡父骨架（S1）：四段式节点树 + 三件通用胶水——
## ①进地点注册检查点；②波次聚合解锁（读检测器 paths_enemy_spawners 导出，
## 全 is_completed 才 setup_after_fight_room + room_cleared——上游逐关手写
## 胶水在此机制化）；③player_died 转交 DeathScreen。
## 参考关两处以后要换的口子以 TODO 挂子项目编号。

const TITLE_PATH := "res://ui/menus/title_screen.tscn"
## 重走一遍的落点（TODO(T5)：参考地点 A 落地后此路径才存在，按钮按压守卫报错）
const STAGE_A_PATH := "res://scenes/stages/ref/stage_ref_a.tscn"
## 本骨架文件自身（_scene_path 判别"实例化根被祖先污染"用的锚点）
const BASE_SCENE_FILE := "res://scenes/base/base_stage.tscn"

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
	# 计划草稿的 resource_path 系 Node 上不存在的杜撰属性（T3 探针裁决弃用）；
	# 可转场路径的三形态解析收口在 _scene_path()
	GameEvents.add_checkpoint(stage_id, _scene_path())
	# player_died → 死亡界面（S1 唯一流程订阅者；角色自我清理订阅各自在壳脚本）
	Events.player_died.connect(_on_player_died)
	_collect_rooms()
	if GameEvents.pending_jump_stage == _scene_path():
		GameEvents.pending_jump_stage = ""  # 检查点回跳落位，一次性消费
	# 终点面板两钮纯代码接线（tscn 零 [connection]，防编辑器双路）；
	# 冻结树活性收口与 PauseLayer/death 壳同源——_show_end_panel 冻结全树，
	# 面板继承不到 ALWAYS 则两钮 pressed 永闸=不可解软锁（评审轮1 修复，B7 锁）
	_end_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_end_panel.get_node("PanelBox/BackTitle").pressed.connect(_on_back_title)
	_end_panel.get_node("PanelBox/Replay").pressed.connect(_on_replay)


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed("debug_restart"):
		reload_prototype()


func reload_prototype() -> void:
	Events.characters_reseted.emit()
	get_tree().call_deferred("reload_current_scene")


## 本场景可转场文件路径（检查点注册/回跳比对单一入口）。4.7 探针实证的两种
## 真实形态（正式地点=本骨架的实例，故恒为"外层文件"语义）：
## - current_scene（change_scene 直载）→ scene_file_path 即地点文件；
## - 场景内实例化根 → scene_file_path 被祖先实例化污染返回**内层**骨架文件，
##   须取 get_path() 去 "::" 前缀得外层地点文件。
## 边界：把骨架**本体**直挂测试树与"包裹层就叫骨架文件"不可判（探针实证同值），
## 契约 B 段因此一律经 fixtures/ 包裹实例，复刻正式地点形态。
func _scene_path() -> String:
	if get_tree().current_scene == self:
		return scene_file_path
	if scene_file_path != BASE_SCENE_FILE and not scene_file_path.is_empty():
		return scene_file_path
	var path := str(get_path())
	return path.get_slice("::", 0)


func _collect_rooms() -> void:
	for room in $FightRooms.get_children():
		if not (room is QuiverFightRoom):
			continue
		var spawners: Array[QuiverEnemySpawner] = []
		for detector in _room_detectors(room):
			for p in detector.paths_enemy_spawners:
				# 路径相对于检测器导出（与 detector._ready 自激活同源解析，4.7 探针
				# 实证）；brief 草稿的 room.get_node("../X") 会从房框解析→恒 null
				var sp: QuiverEnemySpawner = detector.get_node_or_null(p)
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
		_show_end_panel()  # TODO(S2)：剧情批换演出


func _show_end_panel() -> void:
	get_tree().paused = true
	_end_panel.visible = true  # 面板两钮：返回标题/重走一遍（T5 装配时铺按钮）


func _on_player_died() -> void:
	get_tree().paused = true
	_death_screen.open_screen()


## 时序铁律（暂停壳同款）：转场前必须显式解冻，否则 tween 在冻结树下永挂
func _on_back_title() -> void:
	get_tree().paused = false
	GameEvents.pending_jump_stage = ""
	ScreenTransitions.transition_to_scene(TITLE_PATH)


func _on_replay() -> void:
	get_tree().paused = false
	GameEvents.reset_session()
	# TODO(T5)：stage_ref_a 落地前按压只报错不转场（测试不 smoke-click 此钮）
	if not ResourceLoader.exists(STAGE_A_PATH):
		push_error("参考地点 A 尚未落地（T5）：%s" % STAGE_A_PATH)
		return
	ScreenTransitions.transition_to_scene(STAGE_A_PATH)
