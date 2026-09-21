extends Node

## Dialogic 风险探测 spike（2026-09-21）——一次性耗材，**不进 23 套回归矩阵**，
## 红字≠否决（处置分级见 DEVELOPMENT_STATUS 路线 4 与根目录案卷备忘）。
## 四问进度：L1 冷启动回环｜L2 输入互斥真值表（游戏移动键会不会漏进角色/
## 会不会误推进对话）｜L3 暂停矩阵（tree.paused 与 Dialogic 推进/恢复语义）
## 运行：godot --headless --path . res://tools/dialogic_spike/spike_probe.tscn

const PROBE_DTL := "res://tools/dialogic_spike/probe.dtl"

var _events := 0
var _ended := false
var _tool_broken := 0  # 只统计"探针本身跑不完"，不统计四问答案


func _ready() -> void:
	await get_tree().physics_frame
	await _flow()
	print("════════ dspike: %s ════════" % ("完成" if _tool_broken == 0 else "工具自身异常(%d)" % _tool_broken))
	get_tree().quit(0 if _tool_broken == 0 else 1)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _note(ok: bool, label: String) -> void:
	print("  %s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_tool_broken += 1


## 判例修正：Dialogic 键盘监听在 _unhandled_input——合成 InputEventAction
## 根本不会出现在该流（AGENTS 输入判例）。推进必须走 OS 同款原始事件。
## 首选 raw Enter；若被 exact 匹配拒收则 raw 左键（_input 鼠标路，exact=false）。
func _advance() -> void:
	var kd := InputEventKey.new()
	kd.keycode = KEY_ENTER
	kd.physical_keycode = KEY_ENTER
	kd.pressed = true
	Input.parse_input_event(kd)
	await get_tree().physics_frame
	var ku := InputEventKey.new()
	ku.keycode = KEY_ENTER
	ku.physical_keycode = KEY_ENTER
	ku.pressed = false
	Input.parse_input_event(ku)
	await get_tree().physics_frame


func _advance_mouse() -> void:
	var c: Vector2 = get_viewport().get_visible_rect().size / 2.0
	var pd := InputEventMouseButton.new()
	pd.button_index = MOUSE_BUTTON_LEFT
	pd.pressed = true
	pd.position = c
	pd.global_position = c
	Input.parse_input_event(pd)
	await get_tree().physics_frame
	var pu := InputEventMouseButton.new()
	pu.button_index = MOUSE_BUTTON_LEFT
	pu.pressed = false
	pu.position = c
	pu.global_position = c
	Input.parse_input_event(pu)
	await get_tree().physics_frame


func _flow() -> void:
	var dlg := get_node_or_null("/root/Dialogic")
	_note(dlg != null, "L0a Dialogic autoload 在位")
	if dlg == null:
		return
	var dtl := load(PROBE_DTL)
	_note(dtl != null, "L0b probe.dtl 以 DialogicTimeline 资源载入")
	if dtl == null:
		return

	# ———— L1 冷启动回环 ————
	dlg.event_handled.connect(func(_e): _events += 1)
	dlg.timeline_ended.connect(func(): _ended = true)
	var layout: Node = dlg.start(dtl)
	_note(layout != null and is_instance_valid(layout),
			"L1a start(资源) 返回有效布局节点（无样式表也不炸）")
	await _frames(10)
	var idx0: int = dlg.current_event_idx
	_note(_events > 0, "L1b 事件开始推进（已处理 %d 条，停在等待输入）" % _events)
	# 打字机模式首按=跳过显示再按才推进：按压次数本身是探测事实
	var presses := 0
	var ok_end := false
	var via := "键盘"
	while presses < 8 and not _ended:
		print("    [state] 按前 state=%d idx=%d events=%d" % [dlg.current_state, dlg.current_event_idx, _events])
		if presses >= 3:
			via = "键盘无响应→改鼠标"
			await _advance_mouse()
		else:
			await _advance()
		presses += 1
		for _i in 15:
			if _ended:
				break
			await get_tree().physics_frame
		ok_end = _ended
	print("  [L1 事实] 推进通路=%s，共 %d 次（含打字机跳显首按）" % [via, presses])
	_note(ok_end, "L1c 有界按压内 timeline_ended 信号回环送达")
	if not _ended:
		# 判别探针：直调 handle_input 绕开一切事件路由，分离"传导问题 vs 内部机制"
		var idx_d: int = dlg.current_event_idx
		var ev_d: int = _events
		dlg.Inputs.handle_input()
		await _frames(20)
		dlg.Inputs.handle_input()
		await _frames(20)
		print("  [L1d 事实] 直调 handle_input×2：idx %d→%d events %d→%d 已送达=%s" % [
				idx_d, dlg.current_event_idx, ev_d, _events, str(_ended)])

	# ———— L2 输入互斥真值表 ————
	var chen: Node = (load("res://characters/playable/chen/chen.tscn") as PackedScene).instantiate()
	add_child(chen)
	chen.global_position = Vector2(500, 600)
	await _frames(20)
	dlg.start(dtl)
	await _frames(10)
	var x0: float = chen.global_position.x
	var idx_a: int = dlg.current_event_idx
	# 按住右移物理键 12 帧（OS 同款原始按键，走全部输入流）
	var kd := InputEventKey.new()
	kd.keycode = KEY_D
	kd.physical_keycode = KEY_D
	kd.pressed = true
	Input.parse_input_event(kd)
	await _frames(12)
	var ku := InputEventKey.new()
	ku.keycode = KEY_D
	ku.physical_keycode = KEY_D
	ku.pressed = false
	Input.parse_input_event(ku)
	await _frames(4)
	var dx: float = chen.global_position.x - x0
	var advanced_by_move: bool = dlg.current_event_idx != idx_a
	print("  [L2 事实] 对话等待中：角色位移=%.1fpx（漏=能移动）；" % dx
			+ "移动键误推进对话=%s（idx %d→%d）" % [advanced_by_move, idx_a, dlg.current_event_idx])
	_note(true, "L2 真值表采集完成（判读在备忘）")

	# ———— L3 暂停矩阵 ————
	var idx_b: int = dlg.current_event_idx
	get_tree().paused = true
	await _frames(4)
	await _advance()
	await _frames(8)
	var advanced_paused: bool = dlg.current_event_idx != idx_b
	print("  [L3 事实] tree.paused=true 时推进输入是否仍被 Dialogic 消费=%s" % advanced_paused)
	get_tree().paused = false
	var resumed_ok := false
	for _i in 8:
		await _advance()
		await _frames(8)
		if _ended:
			resumed_ok = true
			break
	_note(resumed_ok, "L3x 解除暂停后 Dialogic 不卡死（推进可响应直至收尾）")
	if dlg.current_state != 0:  # States.IDLE
		dlg.end_timeline()
	await _frames(6)
	chen.queue_free()
