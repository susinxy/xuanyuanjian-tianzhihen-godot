class_name SwitchFlow
extends RefCounted

## 转场链载体（B2-T1，终审 Issue 1）：静默窗/强清/结算的逐帧等待全部发生
## 在 RefCounted 协程里——续体经 _flows 注册表自持（判例 gh-74990：signal
## 方法续体不持宿主 RefCounted），壳先亡只触发 instance 失效让位，
## **不再踩 resume-on-freed**（await-self 判例收口）。
## 时序与旧 _settle_before_switch 逐位等价（T1 红线）；T2 终裁已落地：
## 判清登记在本链 gen 对号之后、落位之前（船闸 force×死亡竞态前置裁决，
## 2026-09-22 定档）——被顶掉的陈旧链零副作用（判清/落位/信标三件；reg+90 战场强清除外）。
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
## mark_src 消费位（T2 终裁，法源=终审 Issue 2 + spec §4 船闸竞态，
## 2026-09-22 定档）：判清登记随"**本链通过代际对号、即将落位**"才落，
## 被顶掉的陈旧链零副作用（严格=判清/落位/信标三件，reg+90 战场强清除外；
## 源段不背判清→死亡重跑走丢弃重建）。顺序硬约束：
## mark 必在 enter_segment **之前**——其内 _remove_current 读 is_cleared(源段)
## 选缓存保活腿还是丢弃腿，晚落=赢链判清被自己丢弃（D4 哨兵锁成功路径）。
## 等帧一律 Engine.get_main_loop()（SceneTree 单例），不持壳/tree 常驻引用。
func _run(target: StringName, entry: StringName, why: StringName,
		revive: bool, mark_src: StringName) -> void:
	for _i in 90:
		await _frame()
		if not _alive():
			return
	var shell := instance_from_id(_shell_id) as ChapterShell
	if shell == null:
		return   # R8 显式守卫（T1 评审裁决载荷）：解引用前判空，防后人插 await 即 use-after-freed
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
	if shell == null:
		return   # R8 显式守卫：壳已亡=链作废（原合取式拆开，防后人插 await 即 use-after-freed）
	if _gen != shell._transition_gen:
		return   # I2 语义不变：最新意图胜出，本链连让位带解绑（判清随顶号一并扣下）
	if mark_src != &"":
		shell.session.mark_cleared(mark_src)   # T2 终裁落点：链赢才落判清
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
