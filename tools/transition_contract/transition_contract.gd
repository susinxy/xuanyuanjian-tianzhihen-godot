extends Node

## transition_contract 契约套（S5b 转场层批）：ScreenTransitions + BackgroundLoader
## 的失败面契约。立项依据=读码定档的六缺陷（D1 先拆后取且不 return / D2 协程间
## 读键-删键零协调致信号可丢 / D3 无防重入 / D4 await animation_finished 被顶掉
## 即永挂 / D5 进度条连接收口 / D6 裸读与 print）；黑屏与偶发 "Invalid access
## to property or key '<场景路径>' on Dictionary" 两宗用户报案的共同嫌疑链。
## R8 红据四档：T1/T2/T3/T4 在旧实现上响亮红（红档日志 /tmp/opencode 本批目录，
## 案卷见 DEVELOPMENT_STATUS 与 PLUGIN_CHANGES），修复后全绿入册。
## 运行：godot --headless --path . res://tools/transition_contract/transition_contract.tscn

const REF_A := "res://scenes/stages/ref/chapter_ref_a.tscn"
const NOPE := "res://scenes/stages/ref/does_not_exist.tscn"
const SELF := "res://tools/transition_contract/transition_contract.tscn"

## 断言全数（防协程静默跳段假绿判例；自身计入前比对——回填见 EXPECTED）
const EXPECTED_ASSERTS := 10

var _fails := 0
var _checks := 0
var _finished := false


func _ready() -> void:
	# 落盘卫生条款：T0/T4 抵达真章节会触发壳检查点注册→影子落盘，重定向套内 scratch
	get_node_or_null(^"/root/SaveSystem").slot_path = "user://transition_scratch.json"
	# C0 存活化判例（stage_contract 同款搬法）——但必须 await 首帧后再动：
	# 场景加载进行中 root 正 "busy setting up children"，此刻搬自己=
	# add_child/remove_child/改 current_scene 三连被拒（TC 首跑尸检实锤）。
	await get_tree().process_frame
	var tree := get_tree()
	var decoy := Node.new()
	decoy.name = &"SceneDecoy"
	tree.root.add_child(decoy)
	tree.current_scene = decoy
	get_parent().remove_child(self)
	tree.root.add_child(self)
	# 分腿模式（--only=T2 等）：旧实现的僵尸协程会跨腿串台（正是 D4 生产事故
	# 形态），取证期每腿独立进程；**矩阵名册=六腿六个单进程条目**（全腿串
	# 跑模式在测试台层面与转场层抢 animator/loader，产品无此病、台子先不求）。
	var only := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--only="):
			only = String(a).trim_prefix("--only=")
	if only == "" or only == "T0":
		await _t0_positive()
	if only == "" or only == "T1":
		await _t1_missing_target()
	if only == "" or only == "T3":
		await _t3_failure_signal_closure()
	if only == "" or only == "T4":
		await _t4_reentrancy()
	if only == "" or only == "T5":
		await _t5_bar_connection_hygiene()
	# T2 压轴：旧实现它必然制造"await animation_finished 僵尸协程"（信号错发时
	# 隔空抢换 current_scene 搅测量面）——放最后一腿随 quit 陪葬；新实现免疫。
	if only == "" or only == "T2":
		await _t2_interrupted_fade()
	_finished = true
	if only == "":
		_check(_checks == EXPECTED_ASSERTS,
				"断言全数跑满 %d/%d（防分段静默跳过假绿）" % [_checks, EXPECTED_ASSERTS])
	else:
		print("TC 分腿模式 %s：全数门豁免（期望腿数=%d）" % [only, EXPECTED_ASSERTS])
	print("════════ transition-contract: %s ════════" % ("PASS" if _fails == 0 else "FAIL"))
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print("  %s: %s" % ["PASS" if ok else "FAIL", label])


func _wait_until(pred: Callable, cap: int) -> bool:
	for _i in cap:
		if pred.call():
			return true
		await get_tree().process_frame
	return pred.call()


func _cur() -> Node:
	return get_tree().current_scene


## 换台纪律：current_scene 永不指向本 runner（否则 D1 旧码的 unload 会把套件自己
## 拆了——红没拿到先陪葬）；每腿开局 _take_stage()（current=可牺牲 dummy Node），
## 收场 _restore()（current=runner 复位+烧掉的场景释放+清账）。change_scene_to_file
## 到 SELF=重建实例从头再跑=无限回环判例，禁。
func _take_stage() -> void:
	# 台间礼闸：等上一转场闩放（新实现换场即放闩，此处至多等几帧；
	# 若永挂=闩泄漏判据自然落进后续 FAIL）
	await _wait_until(func(): return not ScreenTransitions._in_transition, 600)
	var dummy := Node.new()
	dummy.name = &"Sacrificial"
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	await get_tree().process_frame


func _restore() -> void:
	var scene := get_tree().current_scene
	get_tree().current_scene = self
	if scene != null:
		scene.free()
	GameSave.new_profile()
	# 腿间闸：等上一转场的闩与尾幕动画全落定再进下一腿（转场层与套件共用
	# 唯一 animator/loader，腿间不留静默窗口=自造串台，全腿模式判例）
	await _wait_until(func():
			return not ScreenTransitions._in_transition \
					and not ScreenTransitions._animator.is_playing(), 600)
	await _frames(8)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


## T0 正基线：转场必达（旧新双绿对照腿——证明套件与夹具本身无罪）
func _t0_positive() -> void:
	await _take_stage()
	ScreenTransitions.transition_to_scene(REF_A)
	var arrived: bool = await _wait_until(func():
			return _cur() != null and _cur().scene_file_path == REF_A, 900)
	_check(arrived, "T0 正基线：transition 抵达 chapter_ref_a")
	_check(_cur().get_node_or_null("Players/Chen") != null,
			"T0' 抵达后主角在位（转场后壳完整）")
	await _restore()


## T1 缺失目标留在原场景（D1 判据：旧=先拆后取 null 仍换场 → current_scene 毁）
func _t1_missing_target() -> void:
	await _take_stage()
	var before: Node = _cur()
	ScreenTransitions.transition_to_scene(NOPE)
	# 固定覆盖转场协程全流程：fade_in≈1.0s(146f)+失败退出窗，600 process 帧富余
	await _wait_until(func(): return false, 600)
	_check(_cur() == before and is_instance_valid(before),
			"T1 不存在路径=现场景保全（未被拆成空舞台；实际 cur=%s）"
			% str(_cur().name if _cur() != null else "<null>"))
	await _restore()


## T2 淡入被顶掉不悬挂（D4 判据：旧=animation_finished 永丢转场协程死在帘子里）
func _t2_interrupted_fade() -> void:
	await _take_stage()
	ScreenTransitions.transition_to_scene(REF_A)
	await get_tree().process_frame
	# 打断在途 fade_in 并让它永无"下一部完结动画"可偷信号：塞一条循环陷阱动画
	# （旧 `await animation_finished` 语义=只有"播完"才发信号 → 永挂=本腿红据）
	var trap := Animation.new()
	trap.length = 30.0
	trap.loop_mode = Animation.LOOP_LINEAR
	var an: AnimationPlayer = ScreenTransitions._animator
	var lib: AnimationLibrary = an.get_animation_library(&"")
	if not lib.has_animation(&"LOOP_TRAP"):
		lib.add_animation(&"LOOP_TRAP", trap)
	an.play(&"LOOP_TRAP", -1)
	var arrived: bool = await _wait_until(func():
			return _cur() != null and _cur().scene_file_path == REF_A, 1200)
	_check(arrived, "T2 淡入被永不断流的动画顶掉后转场仍在有界帧内落位（不永挂）")
	await _restore()


## T3 失败路径终态信号必达（D2 判据：旧=加载失败只 push_error，await 信号方永挂）
func _t3_failure_signal_closure() -> void:
	var got := [false]
	var cb := func(_p: String) -> void: got[0] = true
	BackgroundLoader.loading_finished.connect(cb)
	BackgroundLoader.load_resource(NOPE)
	var settled: bool = await _wait_until(func():
			return got[0] or not BackgroundLoader.is_loading_resource(NOPE), 600)
	_check(settled and got[0],
			"T3 加载失败路径 loading_finished 仍必达（信号订阅者不死等；got=%s settled=%s）"
			% [str(got[0]), str(settled)])
	if BackgroundLoader.loading_finished.is_connected(cb):
		BackgroundLoader.loading_finished.disconnect(cb)


## T4 防重入：连点两次只成一次且落位（D3/D1 复合判据）
func _t4_reentrancy() -> void:
	await _take_stage()
	ScreenTransitions.transition_to_scene(REF_A)
	ScreenTransitions.transition_to_scene(REF_A)   # 连点（模拟双击按钮）
	var arrived: bool = await _wait_until(func():
			return _cur() != null and _cur().scene_file_path == REF_A, 1500)
	_check(arrived, "T4 连点两次转场仍落位（无 null 换场/无互踩死锁；cur=%s）"
			% str(_cur().scene_file_path if _cur() != null else "<null>"))
	if _cur() != null:
		_check(_cur().get_node_or_null("Players/Chen") != null, "T4' 落位后壳完整")
	else:
		_check(false, "T4' 现场景 null 无从查壳")
	await _restore()


## T5 进度条连接收口（回归锁：转场完成后不留路径绑定的 loading_progress 监听）
func _t5_bar_connection_hygiene() -> void:
	var st := ScreenTransitions
	# 先清历史泄漏面（旧实现跨腿可能留连接）：只断与本套路径绑定的，保守计数在转场后
	_check(_cur() != null, "T5 前置：已在 runner 现场")
	ScreenTransitions.transition_to_scene(REF_A)
	var arrived: bool = await _wait_until(func():
			return _cur() != null and _cur().scene_file_path == REF_A, 1200)
	var leaked := false
	for c in BackgroundLoader.loading_progress.get_connections():
		var callable: Callable = c["callable"]
		var bound := callable.get_bound_arguments()
		if bound.size() == 1 and String(bound[0]) == REF_A:
			leaked = true
	_check(arrived and not leaked,
			"T5 转场完成后无残留按路径绑定的进度条监听（D5 收口锁）")
	await _restore()
