class_name ChapterShell
extends Node2D

## 章节壳（S2-M1-B1，spec §3.1）：段生命周期+会话状态+壳件的唯一宿主。
## 与 BaseStage 双轨（spec D10）：本类只服务章节形态，单地点形态零扰动。

signal segment_entered(id: StringName)
signal chapter_error(message: String)
signal segment_cleared(id: StringName)
signal segment_advance_failed(reason: String)
## 语义（评审轮 1 定档）：**实际落位之后**才响（restart/强制推进链尾统一发；
## 被更新的转场意图顶掉、或终点推进失败时不发）。
signal segment_restarted(why: StringName)
## 章节终点（T5/B7 消费口）：**终点段已判清**且无后继、推进链撞墙时发射，
## 恰一次（闩锁）。终点段未判清的失败推进（F-2 强推）只发
## segment_advance_failed 不发本作完成——"历史不可变"跳段≠通关。
signal chapter_finished

## 本模板文件自身（_scene_path 判别"实例化根被祖先污染"用的锚点，
## BaseStage 同款两形态判例）
const SHELL_SCENE_FILE := "res://scenes/chapter/chapter_shell.tscn"

@export var chapter_id: StringName
@export var segment_scenes: Array[PackedScene] = []
@export_node_path("QuiverCharacter") var playable_path := NodePath("Players/Chen")
## 换人接缝（B2.5/T5 测试主权）：非空=在 _ready 一切绑段动作之前，把模板内嵌
## 主角释放、用本场景替身顶上原槽位（同父/同名/同位，模板挂载件随迁）。
## **生产场景永不设值**（默认 null=换人腿整体不执行，行为零变化）；唯一合法
## 消费方=test fixtures 的 .tscn（回归矩阵夹具把 chen 换成 test_actor）。
@export var playable_override: PackedScene = null

## 账本引用（B4-T1 迁移，spec §6）：ChapterSession 退役，session 指向
## /root/GameSave 单例；类型放宽为 Node（GameSave 无 class_name，消费点
## shell.session.xxx 零改动，动态派发）。兜底实例化见 _ready 首段。
var session: Node = null
var _instances := {}          # segment_id -> 实例（常驻缓存，spec D12 缓存面）
var _order: Array[StringName] = []
var _scene_by_id := {}        # segment_id -> PackedScene（扫描期建，first-wins；
							  # 位置双轨在跳过坏段时会错位映射，判例修正）
var _seg_spawner_set := {}    # segment_id -> Array[QuiverEnemySpawner]（R9：段清判定
							  # 的 spawner 集实源于接线期检测器 paths 并集）
var _current: StageContent = null
var _scene_file := ""                 # B4.5-T2：_scene_path() 结果缓存（_ready 解析
									  # 后填；enter_segment 传检查点与 resume 比对共用，
									  # 免每段重复两形态解析）
var applied_lighting := Color.WHITE   # 壳最近一次复位写入的画布色（契约断言面）
var _transition_gen := 0              # I2：转场意图代际（switch/restart/强制推进共用，
									  # 最新意图胜出；链尾对号，陈旧链静默让位）
var _suppress_state := {"gen": 0, "orig": {}}   # R12：屏蔽窗代际+检测器原值存证
												# （字典按引用被恢复 lambda 捕获，
												# 壳先亡也可安全清算）
var _chapter_finished_emitted := false          # chapter_finished 闩锁（恰一次）


@onready var playable: QuiverCharacter = get_node_or_null(playable_path)
@onready var _segments_root: Node2D = $Segments
@onready var _shell_canvas: CanvasModulate = $Ambient/CanvasModulate
@onready var _end_panel: Control = $HudLayer/StageEndPanel


func _ready() -> void:
	# 账本接线（B4-T1 迁移，spec §6）：正常运行必走 /root/GameSave 单例；
	# 非 autoload 环境兜底=编辑器工具/独立夹具场境（自造一份进程内账本挂壳下，
	# 生命周期随壳）。置于函数首行——晚于任何 session 消费点即炸。
	session = get_node_or_null(^"/root/GameSave")
	if session == null:
		session = load("res://scripts/save/game_save.gd").new()
		add_child(session)
	# 五职责齐平（T5，spec §3.1"五壳件"）：进章节注册检查点 + 回跳一次性消费，
	# 路径解析与 BaseStage 同源（SessionRules）。注意（B4-T1 语义更新）：章节
	# 形态的回跳=整章场景重载，playable 回出生位，但**账目不丢**——GameSave
	# 单例账随进程（spec §2：重跑/回跳/换章一律不碰账，旧"会话重置清旗标"
	# 概念已废除）；D4 已把死亡改走段重跑，回跳仅服务暂停壳"回本地点入口"与 B4.5。
	var scene_path := _scene_path()
	# B4.5-T2 缓存（spec §4）：本壳场景文件=检查点第三键（record_checkpoint 传参）
	# 与 resume 比对（checkpoint_scene 命中本壳才消费旗）的单一依据；解析一次
	# 全流共用（enter_segment 在 _ready 尾之后还会反复触达，不重解）。
	_scene_file = scene_path
	# B4.5-T1 改口（spec §3 裁决 R2）：回跳表迁账 GameSave（本壳由场景 runner
	# 消费恒有 autoload，标识符直用与 GameEvents 同形制；编辑器提示环境不跑）
	GameSave.add_location_checkpoint(chapter_id, scene_path)
	SessionRules.consume_pending_jump(scene_path)
	# B7 锁语义容器版：终点面板 ALWAYS + 两钮代码接线（自动弹出无接入——
	# 章节终点演出=chapter_finished 的 B7 过场批消费口，面板留给消费方拉起）
	SessionRules.wire_end_panel(_end_panel, _on_back_title, _on_replay)
	# 换人接缝（B2.5/T5）：插入点裁决——①检查点注册/回跳消费/终点面板接线三条腿
	# 与角色身份无关，先跑无妨；②必须早于段扫描、Events.player_died 订阅与首次
	# enter_segment——enter_segment 会写 playable.global_position 并绑段，晚换人
	# =首段绑到已释放旧体；③@onready playable 在函数体首行前已解析成旧体，换完
	# 走既有 set_playable 覆盖引用与路径（area2d:player 身份校验链复用，缺组即
	# chapter_error，手术不落地场景原样保留）。
	if playable_override != null:
		if not _apply_playable_override():
			return
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
	# B4.5-T2 读档落位（spec §4，与 B4 pending_jump 传渡判例同构）：
	# resume_pending=「回检查点」一次性意图旗（易失不入账，GameSave 声明侧钉死），
	# 且检查点场景==本文件才消费——first-wins 读后即清（转场目标若是他章，
	# 旗原样留给那个场景的壳）。读档=全新场景加载，满状态天然成立（裁决 B4-R0b
	# 零实现成本）。检查点段不在 _order（档与章漂移）push_error 响亮回退首段
	# 不炸，旗同样已消费（读档失败不重试不滞留——P4b 判据）。
	var seg := _order[0]
	var entry: StringName = &"default"
	if GameSave.resume_pending and GameSave.checkpoint_scene() == _scene_file:
		GameSave.resume_pending = false
		var cp := GameSave.checkpoint_segment()
		if _order.has(cp):
			seg = cp
			entry = GameSave.checkpoint_entry()
		else:
			push_error("ChapterShell: 读档检查点段 %s 不在本章节 _order（档章漂移），回退首段"
					% str(cp))
	enter_segment(seg, entry)


func _on_player_died() -> void:
	# spec D4：段级重跑取代地点死亡壳（地点级回跳仍归暂停壳/检查点表；
	# DeathScreen 壳件照模板在位但章节形态不接死亡——休眠件）
	restart_segment(&"death")


func _unhandled_input(event: InputEvent) -> void:
	# debug_restart（BaseStage 同款：仅 debug 构建，原始事件流按动作判定）
	if OS.is_debug_build() and event.is_action_pressed("debug_restart"):
		reload_prototype()


func reload_prototype() -> void:
	SessionRules.reload_prototype(get_tree())


## 本章节可转场文件路径（检查点注册/回跳比对单一入口）。壳根非 BaseStage
## 实例，_scene_path 两形态判例经 SessionRules 共享、锚点换本模板文件：
## 正式章节=chapter_shell.tscn 的实例化根（change_scene 直载 → scene_file_path
## 即章节外层文件；场景内实例化根 → 外层文件，同 B5 探针实证形态）。
func _scene_path() -> String:
	return SessionRules.resolve_scene_path(self, SHELL_SCENE_FILE)


## 换人真身（B2.5/T5 接缝）：手术本体在 SessionRules.swap_in_playable（与
## BaseStage 双轨同源）。失败即 chapter_error + 早返（_ready 返回 false 时中止）；
## 成功后走既有 set_playable 收口——area2d:player 身份校验缺组即拒收（拒收时
## 替身释放、playable 归 null，与 playable 缺席腿同源形态，绝不扶正断链目标）。
func _apply_playable_override() -> bool:
	if playable == null:
		chapter_error.emit("playable_override 落空：playable_path 未命中内嵌主角")
		return false
	var qc := SessionRules.swap_in_playable(self, playable, playable_override)
	if qc == null:
		chapter_error.emit("playable_override 根非 QuiverCharacter，换人放弃（旧场景未动）")
		return false
	if not qc.is_in_group("area2d:player"):
		qc.free()
		playable = null
		chapter_error.emit("playable_override 替身缺 area2d:player 身份组，拒换上位")
		return false
	set_playable(qc)
	return playable == qc


## 换角接口位（D11：本切片只留位，换人实现——皮肤/输入通道/相机迁移——留 D2 批）：
## 换引用 + `area2d:player` 身份组校验。缺组=拒换并广播 chapter_error——
## HUD 跟手、AI 索敌、死亡游戏结束全按该组查询身份，禁把断链目标扶正。
func set_playable(next: QuiverCharacter) -> void:
	if next == null:
		chapter_error.emit("set_playable: 目标为空")
		return
	if not next.is_in_group("area2d:player"):
		chapter_error.emit("set_playable: 目标缺 area2d:player 身份组")
		return
	playable = next
	# 路径存证只在目标已挂树时进行（不在树时 get_path() 报引擎错误——噪音纪律）
	if next.is_inside_tree():
		playable_path = next.get_path()


func _on_back_title() -> void:
	SessionRules.goto_title(get_tree())


func _on_replay() -> void:
	# 章节重走=原型重载（B4-T1 语义更新：清场=场景重建，账目保留——账随进程，
	# D4 注同文）。
	# 解冻收口在 SessionRules.reload_prototype 共享腿（B7：冻结树不得跨重载）
	reload_prototype()


## 段重跑（D4，曹氏血崩等剧情杀复用 why 通道）：不 spawn 自建协程，而是
## 借道 switch 链（I3：信号侧只同步登记意图，消灭"死亡瞬间壳被删=90+ 帧
## 自等协程 resume-on-freed"这一与 R12 同族的雷；I2：与在途切段天然互斥）。
## 复活（回血+动作脑复位）排在链尾静默窗**之后**——顺序判例（D1 实测）：
## 先回血=给在场敌 90 帧无抗打靶窗，落位时血已非满（71/101 案）。
## revive=true 是本 API 与强制推进的分水岭（F-1）：死亡重跑必复活，
## force_advance_current 只落位/推进不治疗。
func restart_segment(why: StringName = &"manual") -> void:
	if playable == null:
		return
	switch_segment(session.checkpoint_segment(), session.checkpoint_entry(),
			why, true)


## 复活真身（R2+I5）：满血+额度/旗标回满、动作脑重入 initial_state、输入
## 窗口重开。Die 是终态（physics 无推进、信标已消费），不手动重入角色就
## 永久冻死；手工三连镜像 transition_to 的 exit→set→enter 时序（m4 备忘：
## 不经 transition_to 则不发 transitioned 信号，调试面板看不到这一次跳转）。
func _revive_playable() -> void:
	playable.attributes.reset()
	var sm := playable.state_machine
	if sm == null:
		return
	if sm.state:
		sm.state.exit()
	sm.state = sm.get_node(sm.initial_state)
	sm.state.enter({})
	# I5：input_window_open 由攻击/施法窗族按 enter/exit 时点各自开关，
	# mid_air 等存在"enter 关窗、exit 不复开"的路径（quiver_action_mid_air
	# .gd:86）——死在连段/空中窗口里时窗会带着 false 进重跑，全体复位须显式重开。
	sm.input_window_open = true


## 曹氏血崩等"历史不可变强制推进"（spec D6）：当前段判清+前进。
## 纯推进**不复活**（F-1）：残血/断法/输入窗状态原样带进新段——剧情跳段
## 不是免费治疗。判清持久化的登记延迟到链尾"**代际对号通过、即将落位**"
## 才落（T2 终裁：船闸 force×死亡竞态前置裁决，2026-09-22 定档）——
## 被更晚意图顶掉时陈旧链零副作用（判清/落位/信标三件；reg+90 战场强清除外），
## 源段不背判清（重跑走丢弃重建）；
## 终点解析失败（F-2）同样扣下，只发 segment_advance_failed，原地不动。
func force_advance_current(reason: StringName) -> void:
	if _current == null:
		return
	switch_segment.call_deferred(&"", &"default", reason, false,
			_current.segment_id)


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
	# B4.5-T2（spec §4）：检查点带场景第三键——死亡重跑/暂停回跳/读档三通道
	# 共用同一份 checkpoint 数据，读档侧没有本行就永远找不到回家的路。
	session.record_checkpoint(id, entry, _scene_file)
	_wire_segment(_current)
	_apply_lighting(_current)
	segment_entered.emit(id)
	if _current.auto_complete:
		session.mark_cleared(id)
		switch_segment.call_deferred()


## 顺序推进（id 空=下一段）；段清除链的出口，也是 restart/强制推进的共用
## 落位链（I2/I3/I1；B2-T1 起为**同步登记 + SwitchFlow 载体**，本函数不再
## 是协程——await-self 收口，见 scripts/chapter/switch_flow.gd）：
## · 代际互斥——每次成功登记意图 +1，链尾对号，陈旧链让位（最新意图胜出）；
## · 终点失败发生在登记代际**之前**，只发 segment_advance_failed，绝不把
##   在途链顶成孤儿（否则两头不落地=卡死），mark_cleared_after 同被扣下（F-2）；
## · mark_cleared_after 不在本函数落账（T2 终裁判词：船闸 force×死亡竞态
##   前置裁决，2026-09-22 定档）——登记随链赢落位（gen 对号后、enter 前，
##   见 switch_flow._run），被顶掉的陈旧链零副作用（判清/落位/信标三件；reg+90 战场强清除外）；
## · restart_why / revive 均为链局部量：链被顶掉则信标与复活随之作废，
##   不会串到别的链上误发（F-1：why≠复活——强制推进带 why 但 revive=false）。
## 跨文件下划线调用（_transition_gen/_revive_playable/_live_enemies）系刻意
## 安排（GDScript 无 private），判例互指见 switch_flow.gd。
func switch_segment(id: StringName = &"", entry: StringName = &"default",
		restart_why: StringName = &"", revive: bool = false,
		mark_cleared_after: StringName = &"") -> void:
	var target := id
	if target == &"":
		var idx := _order.find(current_segment_id())
		if idx >= _order.size() - 1:
			segment_advance_failed.emit("章节终点（无后继段）")
			_maybe_finish_chapter()
			return
		target = _order[idx + 1]
	_transition_gen += 1
	# 静默窗/强清/结算整段移交 RefCounted 载体（fire-and-forget；登记即返，
	# 时序与旧协程体逐位等价——T1 红线；mark 落点随 T2 终裁移入链尾对号后，
	# 本同步段不再登记判清）
	SwitchFlow.start(self, _transition_gen, target, entry, restart_why,
			revive, mark_cleared_after)


## 终点撞墙链的完成判定（T5/B7）：**当前（终点）段已判清**才广播 chapter_finished，
## F-2 未判清的强推失败不发（跳段≠通关）；闩锁保恰一次（auto_complete 终点段
## 重进、重复终点推等后续链路不得二次广播）。
func _maybe_finish_chapter() -> void:
	if _chapter_finished_emitted:
		return
	var sid := current_segment_id()
	if sid == &"" or not session.is_cleared(sid):
		return
	_chapter_finished_emitted = true
	# B4.5-T2 通关事实入账（spec §2 影子条款：记账=自动落盘，内容件零自觉调用；
	# NS_CHAPTERS_DONE 系统户 GameSave._ready 预开）——"打过哪一章"跨档记住，
	# 重跑/回跳不抹（new_profile 唯一清账口，新开局归零重来）。闩锁在前，
	# 本行恒恰一次首记（chapter_finished 二次广播结构性不可能）。
	session.record(GameSave.NS_CHAPTERS_DONE, chapter_id)
	chapter_finished.emit()


## 在场敌查询（B2-T1 起由 scripts/chapter/switch_flow.gd 经 instance id 调用——
## 跨文件下划线互指判例见 switch_segment 头注）：切换强清的 targets 与
## tree_exited 结算窗观察面。
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
		return   # m1：没闭任何检测器就不推进代际（零检测器段不得让在途窗变孤儿）
	state["gen"] += 1
	var gen: int = state["gen"]
	# m3：process_in_physics=true，时基与 physics_frame 同源，2 格=2 物理帧
	var timer := get_tree().create_timer(
			2.0 / float(Engine.physics_ticks_per_second), true, true)
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
		for oid in orig.keys():   # m2：陈旧代残留（被丢弃段的死 id）随最新代收尾清算
			if not is_instance_id_valid(oid):
				orig.erase(oid)
	)


## 三件套聚合接线（spec §3.1，R9 实源化）：段清判定的 spawner 集取自检测器
## paths_enemy_spawners 并集（运行时按段存 _seg_spawner_set）——枚举式判清
## 在空集时会假性秒段清（静默跳段），实源集把该危害变成显式防呆。
func _wire_segment(seg: StageContent) -> void:
	var wired: Array[QuiverEnemySpawner] = []
	for det in seg.find_children("*", "", true, false):
		if not (det is QuiverPlayerDetector):
			continue
		# 检测器导出→生成器的解析/去重与 BaseStage 房聚合同源（D10，SessionRules）
		for sp in SessionRules.spawners_from_detector(det):
			if sp in wired:
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
