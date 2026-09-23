extends Node

## 攻击冻结在册断言台（矩阵名册常驻；原 2026-09-16 悬案取证台第二版转正——
## 在册即红必须红：判红退出码 1，见 _finish）：
## 真 test_actor 皮肤（模板快照血缘）+真 attack 动画，AnimationTree 走**真实物理帧管线**
## （B2.5 主权迁移：原绑活体 chen 皮肤——用户调打击感（attack1 0.333s→0.1s）会
## 直接改写本台的末帧/停摆窗时序前提；替身动画=模板快照，与生产手感调优解耦。）
## （process_callback=PHYSICAL——headless 无 idle 帧；教训定档：
## AnimationTree.advance() 只计算输出，方法轨道信标要 commit 阶段才发，
## 手动推帧测信标是假现场）。三场景全部协程化串行 await（防未 await 假绿）：
##  对照   信标→idle 消化2拍→再进 attack1（应二次信标）
##  H1     信标同一同步栈内 idle→attack1 背靠背双转换（模拟信标帧内
##         FSM 退场+缓冲输入再进场，树一帧未走）
##  H3     末段（pos≥0.30）树 active 置假 3 个物理帧（HitFreeze 型停摆）
## 红判据：40 物理帧内等不到预期信标。

const MAX_FRAMES := 40

const Kit := preload("res://tools/matrix_runner/test_actor_kit.gd")

var _skin
var _tree: AnimationTree
var _playback
var _beacons := 0
var _pos_key := "parameters/state_machine/attack1/current_position"
var _results: Array[String] = []


## 头部三态守卫（input_channel 同款只读阶梯；缺席打可读红、绝不代 runner 创建）
func _guard_actor() -> bool:
	var remedy := "先跑 bash tools/matrix_runner/run_matrix.sh --ensure-only 建好 test_actor"
	# 终审波：判态结构性断奶 ensure()——peek() 零副作用三态分类
	var st: int = Kit.peek()  # 只读分类（peek 承诺零副作用、永不建档）
	match st:
		Kit.READY:
			print("ACTOR-GATE: test_actor 就绪（只读三态守卫通过）")
			return true
		Kit.NEEDS_IMPORT:
			_record(false, "守卫", "test_actor 已建未导入（%s）" % remedy)
		Kit.ABSENT:
			_record(false, "守卫", "test_actor 缺席（%s）" % remedy)
		_:
			_record(false, "守卫", "peek() 返回未知态 %d（kit 契约破损，查 test_actor_kit）" % st)
	return false


func _ready() -> void:
	await get_tree().physics_frame
	if not _guard_actor():
		_finish()
		return
	_skin = load(Kit.ACTOR_SKIN_SCENE).instantiate()
	add_child(_skin)
	for i in 30:
		await get_tree().physics_frame
	_tree = _find_tree(_skin)
	if _tree == null:
		_record(false, "装配", "找不到 AnimationTree")
		_finish()
		return
	@warning_ignore("unsafe_property_access")
	_tree.set("process_callback", 0)  # 0=物理回调（枚举成员名各版漂移，行为裁决）
	_playback = _find_playback()
	if _playback == null:
		_record(false, "装配", "找不到 playback")
		_finish()
		return
	_skin.skin_animation_finished.connect(func(): _beacons += 1)
	print("[攻复] active=%s root_node=%s callback=PHYSICAL" % [_tree.active, _tree.root_node])
	var seeks: Array[String] = []
	for prop in _tree.get_property_list():
		if String(prop.name).contains("attack1"):
			seeks.append(String(prop.name))
	print("[攻复] attack1 参数族=%s" % ", ".join(seeks))

	await _scenario_control()
	await _scenario_same_tick_double()
	await _scenario_pause_at_tail()
	await _scenario_idempotent_reentry()
	await _scenario_endframe_hold()
	_finish()


## ---- 场景 ----

func _scenario_control() -> void:
	await _harden()
	_beacons = 0
	_skin.transition_to("attack1")
	if not await _wait_beacon():
		_record(false, "对照组", "首信标未响（基础链路断，后续作废）")
		return
	_skin.transition_to("idle")
	await _wait(2)
	_beacons = 0
	_skin.transition_to("attack1")
	var ok := await _wait_beacon()
	_record(ok, "对照（消化2拍再回访）", "pos=%s current=%s" % [_pos(), _node()])


func _scenario_same_tick_double() -> void:
	await get_tree().physics_frame
	await _harden()
	_beacons = 0
	var cb := func():
		if _beacons == 1:
			# 信标同一同步栈：FSM→idle 与 缓冲输入→attack1 背靠背，树未走一帧
			_skin.transition_to("idle")
			_skin.transition_to("attack1")
	_skin.skin_animation_finished.connect(cb)
	_skin.transition_to("attack1")
	if not await _wait_beacon():
		_skin.skin_animation_finished.disconnect(cb)
		_record(false, "H1 竞态", "首信标未响，场景作废")
		return
	await _wait(1)
	print("[攻复]   双转换后: current=%s pos=%s path=%s" % [_node(), _pos(), _path()])
	_skin.skin_animation_finished.disconnect(cb)
	_beacons = 0
	var ok := await _wait_beacon()
	_record(ok, "H1 竞态（信标同栈 idle→attack1 背靠背，皮肤start修复）",
			"二次信标=%s current=%s pos=%s path=%s" % [
				"响" if ok else "未响", _node(), _pos(), _path()])


func _scenario_pause_at_tail() -> void:
	await get_tree().physics_frame
	await _harden()
	_beacons = 0
	_skin.transition_to("attack1")
	var guard := 0
	while float(_tree.get(_pos_key)) < 0.30 and _beacons == 0 and guard < 40:
		await get_tree().physics_frame
		guard += 1
	if _beacons > 0:
		_record(false, "H3 末段停摆", "还没到停摆窗信标就响了（pos=%s，场景作废）" % _pos())
		return
	_tree.active = false
	await _wait(3)
	_tree.active = true
	_beacons = 0
	var ok := await _wait_beacon()
	_record(ok, "H3 末段停摆3帧（HitFreeze 型）",
			"恢复后信标=%s pos=%s current=%s" % ["响" if ok else "未响", _pos(), _node()])


## H5 播中幂等自回访不得倒带：mid_air 等产线按"每帧幂等登记同一目的地"
## 惯例写；无差别倒带版 start() 把腾空动画钉死首帧（回归案）。
## 终版判据=脑意图：同目的地登记恒 no-op（播中/播完皆然），新意图才倒带。
func _scenario_idempotent_reentry() -> void:
	await get_tree().physics_frame
	await _harden()
	_beacons = 0
	_skin.transition_to("attack1")
	await _wait(3)
	var pos_before := float(_tree.get(_pos_key))
	_skin.transition_to("attack1")  # 播中幂等重登记
	await get_tree().physics_frame
	var pos_after := float(_tree.get(_pos_key))
	_record(pos_after >= pos_before and pos_after > 0.001,
			"H5 播中幂等自回访不倒带",
			"pos %.4f -> %.4f（被倒带则跌回 ~0.017）" % [pos_before, pos_after])


## H6 尾帧保持=设计意图（双断言锁死判据两面）：
##  rising 播完钉死尾帧后，同目的地幂等登记不得倒带（悬停姿势保持）；
##  脑改主意（idle→rising，模拟二次起跳）才算新播放意图 → 重入倒带。
func _scenario_endframe_hold() -> void:
	await get_tree().physics_frame
	await _harden()
	var pos_key := "parameters/state_machine/rising/current_position"
	var len_key := "parameters/state_machine/rising/current_length"
	_skin.transition_to("rising")
	for i in 30:
		await get_tree().physics_frame
	var clamped := float(_tree.get(pos_key))
	var hold_ok := clamped >= float(_tree.get(len_key)) - 0.001
	_skin.transition_to("rising")  # 幂等重登记（mid_air 惯例）
	for i in 3:
		await get_tree().physics_frame
	var after := float(_tree.get(pos_key))
	hold_ok = hold_ok and after >= clamped - 0.001
	# 新意图：改主意再回 rising → 必须重入倒带
	_skin.transition_to("idle")
	_skin.transition_to("rising")
	for i in 2:
		await get_tree().physics_frame
	var restarted := float(_tree.get(pos_key))
	_record(hold_ok and restarted < clamped - 0.05,
			"H6 尾帧保持(幂等)与倒带(新意图)两面",
			"钉死=%.3f 幂等后=%.3f 新意图后=%.3f" % [clamped, after, restarted])


## ---- 工具 ----

func _wait(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_beacon() -> bool:
	for i in MAX_FRAMES:
		await get_tree().physics_frame
		if _beacons > 0:
			return true
	return false


func _harden() -> void:
	_playback.travel("idle")
	_beacons = 0
	for i in 10:
		await get_tree().physics_frame
		if String(_playback.get_current_node()) == "idle":
			return


func _pos() -> String:
	return str(_tree.get(_pos_key))


func _node() -> String:
	return str(_playback.get_current_node())


func _path() -> String:
	return str(_playback.get_travel_path())


func _find_playback():
	for prop in _tree.get_property_list():
		var n: String = prop.name
		if n.begins_with("parameters/") and n.ends_with("playback"):
			var pb = _tree.get(n)
			if pb != null and pb.has_method("travel"):
				return pb
	return null


func _find_tree(n: Node):
	if n is AnimationTree:
		return n
	for c in n.get_children():
		var r = _find_tree(c)
		if r != null:
			return r
	return null


func _record(ok: bool, label: String, detail: String) -> void:
	_results.append("%s %s：%s" % ["绿" if ok else "红", label, detail])


func _finish() -> void:
	for r in _results:
		print("[攻复] ", r)
	var all_ok := true
	for r in _results:
		if r.begins_with("红"):
			all_ok = false
	print("════════ attack-freeze-repro: %s ════════" % ("绿（未复现）" if all_ok else "红（抓到冻结）"))
	# R8 诚实化（B2.5 Task6）：在册断言台判红必须 rc=1——历史取证台"红也退 0"
	# 的设计在入册后就是假绿矩阵的敞口。
	get_tree().quit(0 if all_ok else 1)
