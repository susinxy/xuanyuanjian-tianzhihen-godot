class_name ChapterShell
extends Node2D

## 章节壳（S2-M1-B1，spec §3.1）：段生命周期+会话状态+壳件的唯一宿主。
## 与 BaseStage 双轨（spec D10）：本类只服务章节形态，单地点形态零扰动。

signal segment_entered(id: StringName)
signal chapter_error(message: String)
signal segment_cleared(id: StringName)
signal segment_advance_failed(reason: String)

@export var chapter_id: StringName
@export var segment_scenes: Array[PackedScene] = []
@export_node_path("QuiverCharacter") var playable_path := NodePath("Players/Chen")

var session := ChapterSession.new()
var _instances := {}          # segment_id -> 实例（常驻缓存，spec D12 缓存面）
var _order: Array[StringName] = []
var _scene_by_id := {}        # segment_id -> PackedScene（扫描期建，first-wins；
                              # 位置双轨在跳过坏段时会错位映射，判例修正）
var _seg_spawner_set := {}    # segment_id -> Array[QuiverEnemySpawner]（R9：段清判定
                              # 的 spawner 集实源于接线期检测器 paths 并集）
var _current: StageContent = null
var applied_lighting := Color.WHITE   # 壳最近一次复位写入的画布色（契约断言面）
var _switching := false


@onready var playable: QuiverCharacter = get_node_or_null(playable_path)
@onready var _segments_root: Node2D = $Segments
@onready var _shell_canvas: CanvasModulate = $Ambient/CanvasModulate


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
			inst.free()   # 扫描用即抛实例不是 RefCounted，不显式释放=退出期 ObjectDB 泄漏
			continue
		_order.append(inst.segment_id)
		_scene_by_id[inst.segment_id] = sc   # 重复 id 已被上行拦下=天然 first-wins
		inst.free()      # 同上：真身由 enter_segment 按需重新实例化（未清场=丢弃重建语义）
	if _order.is_empty():
		chapter_error.emit("零段可进（segment_scenes 空/全坏）")
		return
	enter_segment(_order[0], &"default")


func current_segment_id() -> StringName:
	return _current.segment_id if _current != null else &""


func _exit_tree() -> void:
	# 所有权清算：清场缓存段是 remove_child 摘出的游离树（_instances 字典引用
	# 不构成 Node 所有权——Godot 4 "摘树不 free=永久泄漏" 判例，退出期实测
	# 832 实例+3 PhysicsBody 滞留即此）。壳出树（含被删/进程退出）时，
	# 凡已无父节点的缓存段由壳显式释放；仍挂在壳下的交给删除级联。
	for sid in _instances.keys():
		var inst: StageContent = _instances[sid]
		if inst != null and inst.get_parent() == null:
			_instances.erase(sid)
			inst.free()


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
	_suppress_detectors(_current)   # R8/C4：落位既成重叠不得误判为"跨线"
	session.record_checkpoint(id, entry)
	_wire_segment(_current)
	_apply_lighting(_current)
	segment_entered.emit(id)
	if _current.auto_complete:
		session.mark_cleared(id)
		switch_segment.call_deferred()


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


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _live_enemies() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("area2d:spar_enemy"):
		if n is QuiverCharacter:
			out.append(n)
	return out


func _apply_lighting(seg: StageContent) -> void:
	# C5：段入场画布复位责任在壳。画布合成色由壳自建 CanvasModulate 承载
	# （段内不放 CanvasModulate），保证"每段必有其色"。
	applied_lighting = seg.lighting_color
	_shell_canvas.color = seg.lighting_color


## R8（spec C4）：落位建立的既成重叠不得被当作"跨线"。入场即闭段内全部
## 检测器 monitoring（存原值），2 物理帧后恢复；段被提前摘树时经
## is_instance_valid 幂等免炸。恢复只走时间轴、不依赖下次入场补写。
func _suppress_detectors(seg: StageContent) -> void:
	var saved: Array = []
	for det in seg.find_children("*", "", true, false):
		if det is QuiverPlayerDetector:
			saved.append([det, det.monitoring])
			det.monitoring = false
	if saved.is_empty():
		return
	for _i in 2:
		await get_tree().physics_frame
	for pair in saved:
		if is_instance_valid(pair[0]):
			pair[0].monitoring = pair[1]


## 三件套聚合接线（spec §3.1，R9 实源化）：段清判定的 spawner 集取自检测器
## paths_enemy_spawners 并集（运行时按段存 _seg_spawner_set）——枚举式判清
## 在空集时会假性秒段清（静默跳段），实源集把该危害变成显式防呆。
func _wire_segment(seg: StageContent) -> void:
	var wired: Array[QuiverEnemySpawner] = []
	for det in seg.find_children("*", "", true, false):
		if not (det is QuiverPlayerDetector):
			continue
		for sp_path in det.paths_enemy_spawners:
			var sp := det.get_node_or_null(sp_path) as QuiverEnemySpawner
			if sp == null or sp in wired:
				continue
			wired.append(sp)
			if not sp.all_waves_completed.is_connected(
					_on_spawner_completed.bind(seg)):
				sp.all_waves_completed.connect(_on_spawner_completed.bind(seg))
	_seg_spawner_set[seg.segment_id] = wired
	# 无房/无生成器的战斗空段防呆：进段即完成条件=auto_complete 已覆盖
	# （实源集为空集时 _on_spawner_completed 显式拒判段清，双保险）


func _on_spawner_completed(seg: StageContent) -> void:
	# 段内全部 spawner 完成才算段清（多房段聚合，集=接线期实源并集）
	var spawners: Array = _seg_spawner_set.get(seg.segment_id, [])
	if spawners.is_empty():
		return
	for sp in spawners:
		if not is_instance_valid(sp) or not sp.is_completed:
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


func _instantiate(sc: PackedScene) -> StageContent:
	if sc == null:
		return null
	var n := sc.instantiate()
	if n == null:
		return null
	if not (n is StageContent):
		n.free()   # 根类型不符=即抛实例，非 RefCounted 不释放=退出期泄漏
		return null
	return n


func _scene_of(id: StringName) -> PackedScene:
	return _scene_by_id.get(id)


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
		_seg_spawner_set.erase(sid)   # 实源集随丢弃段失效（再入走 _wire_segment 重建）
	_current = null
