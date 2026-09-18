extends Node

## 击飞统一模型契约测试（2026-09-18 统一模型批）：
## 单元层——QuiverAttributes.apply_knock 六规则（扣量/破线溢出+保底/回满/
## 霸体归零/无敌/死亡强飞/空中 K>0/空中 K=0 吞事件）；
## 链路层——CombatSystem 分发、起飞速度公式、连空即时再起飞、落地即停
## （A3 甲案）、落地回气、弹道高度打表（B2 观察，只打印不判定）。
## 运行：godot --headless --path . res://tools/knockout_contract/knockout_contract.tscn

const SPAR := "res://characters/enemies/spar_enemy/spar_enemy.tscn"
const EPS := 2.0

var _fails := 0
var _finished := false


func _ready() -> void:
	await _flow()
	_check(_finished, "全序列执行完成（协程静默中断防线）")
	print("════════ knockout-contract: %s ════════" % ("PASS" if _fails == 0 else "FAIL"))
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails += 1
	print("  %s: %s" % ["PASS" if ok else "FAIL", label])


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


## 等待状态机到达目标状态（超 600 物理帧视为失败），返回是否到达
func _wait_state(spawn: QuiverCharacter, path: String, cap: int = 600) -> bool:
	for _i in cap:
		if str(spawn.state_machine.state_name) == path:
			return true
		await get_tree().physics_frame
	return str(spawn.state_machine.state_name) == path


func _apply(spar: QuiverCharacter, k: float, vector: Vector2) -> Dictionary:
	var data := QuiverKnockbackData.new(k, CombatSystem.HurtTypes.HIGH, vector)
	CombatSystem.apply_knockback(data, spar.attributes)
	return {"signal_emitted": data.impulse, "kb": data}


func _flow() -> void:
	# ———— 单元层：裸属性资源，无角色挂接（地面语义）————
	var a := QuiverAttributes.new()
	_check(is_equal_approx(a.resistance_current, 600.0), "初始抗击打余量=上限 600")
	var v: Dictionary = a.apply_knock(200.0)
	_check(not v.launched and is_equal_approx(a.resistance_current, 400.0),
			"K=200 → 硬直扣量 R=400")
	v = a.apply_knock(200.0)
	_check(not v.launched and is_equal_approx(a.resistance_current, 200.0),
			"K=200 → R=200")
	v = a.apply_knock(250.0)
	_check(v.launched and absf(v.impulse - 100.0) < EPS and a.resistance_current == 0.0,
			"K=250 破线 → 冲量=溢出(50)+保底(50)=100，余量清空（实际 %.0f）" % v.impulse)
	a.refill_resistance()
	_check(is_equal_approx(a.resistance_current, 600.0), "回气 refill → 回满 600")
	a.has_superarmor = true
	v = a.apply_knock(5000.0)
	_check(not v.launched and v.swallow and is_equal_approx(a.resistance_current, 600.0),
			"霸体归零制：K=5000 交易作废（swallow），额度分毫不动")
	a.has_superarmor = false
	a.is_invulnerable = true
	v = a.apply_knock(700.0)
	_check(not v.launched, "无敌：直接免结算")
	a.is_invulnerable = false
	a.health_current = 0.0
	v = a.apply_knock(60.0)
	_check(v.launched and absf(v.impulse - 110.0) < EPS,
			"死亡强飞：绕过额度，冲量=K+保底=110（实际 %.0f）" % v.impulse)
	a.health_current = 100.0

	# ———— 链路层：真实 spar 入场 ————
	var stage := Node2D.new()
	add_child(stage)
	var spar: QuiverCharacter = (load(SPAR) as PackedScene).instantiate()
	stage.add_child(spar)
	for _i in 12:
		await get_tree().physics_frame
	_check(spar.state_machine != null and str(spar.state_machine.state_name) != "",
			"spar 状态机激活（%s）" % str(spar.state_machine.state_name))

	# 空中语义借用 spar 的角色挂接（character_node.is_on_air）
	var air_a := QuiverAttributes.new()
	air_a.character_node = spar
	spar.is_on_air = true
	v = air_a.apply_knock(0.0)
	_check(not v.launched and v.swallow, "空中 K=0 → 吞事件（G5 火球穿身不打断弹道）")
	v = air_a.apply_knock(100.0)
	_check(v.launched and absf(v.impulse - 150.0) < EPS
			and is_equal_approx(air_a.resistance_current, 600.0),
			"空中 K=100 → 冲量=K+保底（额度不追溯，实际 %.0f）" % v.impulse)
	spar.is_on_air = false

	# ———— 信号分发：地面三连 ————
	# GDScript 陷阱备案：lambda 捕获局部变量按值——+= 只改副本，外层恒 0
	# （首跑三连 FAIL 而物理断言全对的谜底）。计数必须走引用型容器。
	var counters := {"ko": 0, "hurt": 0}
	spar.attributes.knockout_requested.connect(func(_kb): counters.ko += 1)
	spar.attributes.hurt_requested.connect(func(_kb): counters.hurt += 1)

	_apply(spar, 200.0, Vector2.RIGHT)
	_apply(spar, 200.0, Vector2.RIGHT)
	_check(counters.hurt == 2 and counters.ko == 0
			and is_equal_approx(spar.attributes.resistance_current, 200.0),
			"链路：两下 K=200 均走受击分发（hurt=%d ko=%d R=%.0f）" % [
			counters.hurt, counters.ko, spar.attributes.resistance_current])

	var dir30 := Vector2(cos(deg_to_rad(-30.0)), sin(deg_to_rad(-30.0)))
	_apply(spar, 1200.0, dir30)
	_check(counters.ko == 1, "链路：破线击走 knockout_requested 分发（ko=%d）" % counters.ko)
	var reached_launch: bool = await _wait_state(spar, "Air/Knockout/Launch", 60)
	_check(reached_launch, "破线后进入起飞状态")
	var expect_vx := 1050.0 * cos(deg_to_rad(30.0))
	_check(absf(spar.velocity.x - expect_vx) < 5.0,
			"起飞水平速度=冲量×cos30（期望 %.0f 实际 %.0f）" % [expect_vx, spar.velocity.x])

	# ———— 连空即时再起飞：弹道中途 K=1200 → 空中=额度空，冲量全额 ————
	spar.attributes.refill_resistance()
	_apply(spar, 1200.0, dir30)
	await _frames(2)
	_check(counters.ko == 2, "空中再击 → 立刻第二次 knockout（ko=%d）" % counters.ko)
	_check(str(spar.state_machine.state_name) == "Air/Knockout/Launch",
			"再击后仍处于起飞状态")
	_check(spar.velocity.x > expect_vx * 1.5,
			"再起飞冲量叠加现有速度（vx 现值 %.0f）" % spar.velocity.x)

	# ———— G5 实链路：空中 K=0 不再发任何信号 ————
	var ko_before: int = counters.ko
	var hurt_before: int = counters.hurt
	_apply(spar, 0.0, Vector2.RIGHT)
	await _frames(2)
	_check(counters.ko == ko_before and counters.hurt == hurt_before,
			"空中 K=0 实链路：无任何信号（弹道不被零击打值打断）")

	# ———— 弹道打表（B2 观察）+ 落地即停（A3 甲案）+ 回气 ————
	var skin := _get_skin(spar)
	var peak_up := 0.0
	var saw_flying := false
	var landed := false
	for _i in 900:
		await get_tree().physics_frame
		peak_up = minf(peak_up, skin.position.y)
		var st := str(spar.state_machine.state_name)
		if st.begins_with("Air/"):
			saw_flying = true
		if st == "Air/Knockout/Bounce":
			_check(spar.velocity.x == 0.0,
					"触地瞬间水平速度清零（落地即停实证，实测 %.1f）" % spar.velocity.x)
			landed = true
			break
	_check(saw_flying, "弹道全程走过空中状态（打表峰值 %.0fpx）" % absf(peak_up))
	print("  [观察] B2 弹道峰值高度 %.0f px；高度层每层 18px → 顶点抬升约 %.1f 层" % [
			absf(peak_up), absf(peak_up) / 18.0])
	_check(landed, "到达落地弹跳阶段")
	var reached_recovery: bool = await _wait_state(spar, "Ground/Recovery", 600)
	_check(reached_recovery, "落地 → 起身状态")
	_check(is_equal_approx(spar.attributes.resistance_current,
			spar.attributes.knockout_resistance_max),
			"回气：落地瞬间抗击打回满（%.0f）" % spar.attributes.resistance_current)

	_finished = true


func _get_skin(ch: QuiverCharacter) -> CanvasItem:
	for c in ch.get_children():
		if c is CanvasItem and str(c.name).ends_with("Skin"):
			return c
	return null
