class_name ChapterShell
extends Node2D

## 章节壳（S2-M1-B1，spec §3.1）：段生命周期+会话状态+壳件的唯一宿主。
## 与 BaseStage 双轨（spec D10）：本类只服务章节形态，单地点形态零扰动。

signal segment_entered(id: StringName)
signal chapter_error(message: String)
signal segment_cleared(id: StringName)
signal segment_advance_failed(reason: String)
signal segment_restarted(why: StringName)

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
var _suppress_state := {"gen": 0, "orig": {}}   # R12：屏蔽窗代际+检测器原值存证
                                                # （字典按引用被恢复 lambda 捕获，
                                                # 壳先亡也可安全清算）


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
	Events.player_died.connect(_on_player_died)
	enter_segment(_order[0], &"default")


func _on_player_died() -> void:
	# spec D4：段级重跑取代地点死亡壳（地点级回跳仍归暂停壳/检查点表）
	restart_segment(&"death")


## 段重跑（D4，曹氏血崩等剧情杀复用 why 通道）：切换三拍清场→回满血→
## 动作脑复位（R2）→按检查点重进当前段（未清场=丢弃重建，敌复位）。
## 顺序判例（D1 实测）：reset 必须排在静默窗**之后**——先回血=给在场敌
## 90 帧无抗打靶窗，重进段时血已非满（71/101 案）。
func restart_segment(why: StringName = &"manual") -> void:
	if playable == null:
		return
	await _settle_before_switch()
	playable.attributes.reset()
	# R2：Die 是终态（physics 无推进、信标已消费），不手动重入 initial_state
	# 角色就永久冻死。手工三连镜像 transition_to 的 exit→set→enter 时序。
	var sm := playable.state_machine
	if sm and sm.state:
		sm.state.exit()
		sm.state = sm.get_node(sm.initial_state)
		sm.state.enter({})
	enter_segment(session.checkpoint_segment(), session.checkpoint_entry())
	segment_restarted.emit(why)


## 曹氏血崩等"历史不可变强制推进"（spec D6）：当前段判清+前进
func force_advance_current(reason: StringName) -> void:
	if _current == null:
		return
	session.mark_cleared(_current.segment_id)
	switch_segment.call_deferred()
	segment_restarted.emit(reason)


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


## R8（spec C4）+R12 重构：落位建立的既成重叠不得被当作"跨线"。入场即闭段内
## 全部检测器 monitoring，约 2 物理帧后恢复。两条判例雷的修法：
## ①恢复不走协程 await（壳先亡=resume on freed 炸点），改为一发 timer 到点
##   调 lambda，lambda 只捕获共享状态字典+本窗名单+代际号（零 self 依赖）；
## ②开窗内二次入场不得以"当前值"作快照（缓存复用段=同批检测器，二次快照
##   读到 false 会把 monitoring 恢复成 false=静默软锁）：原值 first-wins 存
##   在共享字典里，代际陈旧的窗只让路不恢复，最新一代窗统一收尾。
func _suppress_detectors(seg: StageContent) -> void:
	var state: Dictionary = _suppress_state
	state["gen"] += 1
	var gen: int = state["gen"]
	var orig: Dictionary = state["orig"]
	var watched: Array[int] = []
	for det in seg.find_children("*", "", true, false):
		if not (det is QuiverPlayerDetector):
			continue
		var did: int = det.get_instance_id()
		if not orig.has(did):
			orig[did] = det.monitoring   # 首见存原值：窗内再入不改写快照
		det.monitoring = false
		watched.append(did)
	if watched.is_empty():
		return
	var timer := get_tree().create_timer(2.0 / float(Engine.physics_ticks_per_second))
	timer.timeout.connect(func() -> void:
		if gen != int(state["gen"]):
			return   # 陈旧代：原值存目留给最新代恢复，防假快照/抢跑
		for did in watched:
			if not is_instance_id_valid(did):
				orig.erase(did)   # 段被丢弃重建：死检测器的存证顺手清
				continue
			var det := instance_from_id(did) as QuiverPlayerDetector
			det.monitoring = bool(orig.get(did, true))
			orig.erase(did)
	)


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
