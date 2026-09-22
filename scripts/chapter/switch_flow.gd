class_name SwitchFlow
extends RefCounted

## 转场链载体（B2-T1，终审 Issue 1）：静默窗/强清/结算的逐帧等待全部发生
## 在 RefCounted 协程里——续体经 _flows 注册表自持（判例 gh-74990：signal
## 方法续体不持宿主 RefCounted），壳先亡只触发 instance 失效让位，
## **不再踩 resume-on-freed**（await-self 判例收口）。
## 时序与旧 _settle_before_switch 逐位等价（T1 红线；mark 后移另案 T2）。
## 跨文件下划线调用（_transition_gen/_revive_playable/_live_enemies）为刻意
## 安排（GDScript 无 private），判例互指见 chapter_shell.gd switch_segment。


var _shell_id := 0
var _gen := 0

## 在途载体自持注册表（判例 gh-74990：signal 方法续体对 RefCounted 是弱引用，
## start 返回即 ref=0 → 实例析构断连=链胎死第一步）。协程自然收尾时除名。
static var _flows: Array[SwitchFlow] = []


static func start(shell: ChapterShell, gen: int, target: StringName,
		entry: StringName, why: StringName, revive: bool,
		mark_src: StringName) -> void:
	var flow := SwitchFlow.new()
	flow._shell_id = shell.get_instance_id()
	flow._gen = gen
	_flows.append(flow)
	flow._drive(target, entry, why, revive, mark_src)


## 外层驱动：等完 _run 协程体（所有让位/落位路径都汇经此处）后解除自持。
func _drive(target: StringName, entry: StringName, why: StringName,
		revive: bool, mark_src: StringName) -> void:
	await _run(target, entry, why, revive, mark_src)
	_flows.erase(self)


## 协程宿主=本 RefCounted（存活由 _flows 注册表担保，协程收尾除名）；
## 壳亡/被顶号 → _alive() 假 → 静默让位，**不再有 resume-on-freed 路径**。
## mark_src 本任务**不消费**（判清登记仍留在壳 switch_segment 同步段的旧位，
## T1 逐位等价红线；T2 终裁后搬来此处）。
## 等帧一律 Engine.get_main_loop()（SceneTree 单例），不持壳/tree 常驻引用。
func _run(target: StringName, entry: StringName, why: StringName,
		revive: bool, _mark_src: StringName) -> void:
	for _i in 90:
		await _frame()
		if not _alive():
			return
	var shell := instance_from_id(_shell_id) as ChapterShell
	# 在场敌强清（策略 A）：判例备忘——queue_free **不触发**段清推进，
	# spawner 完成只认真实死亡链（quiver_enemy_spawner.gd:94-98）。
	for e in shell._live_enemies():
		e.queue_free()
	var waited := 0
	while shell._live_enemies().size() > 0 and waited < 120:
		await _frame()
		waited += 1
		if not _alive():
			return
	shell = instance_from_id(_shell_id) as ChapterShell
	if shell == null or _gen != shell._transition_gen:
		return   # I2 语义不变：最新意图胜出，本链连让位带解绑
	if revive:
		shell._revive_playable()
	shell.enter_segment(target, entry)
	if why != &"":
		shell.segment_restarted.emit(why)


func _alive() -> bool:
	var shell := instance_from_id(_shell_id) as ChapterShell
	return shell != null and _gen == shell._transition_gen


func _frame() -> void:
	await Engine.get_main_loop().physics_frame
