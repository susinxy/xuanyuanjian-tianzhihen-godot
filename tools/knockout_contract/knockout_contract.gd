extends Node

## 击飞统一模型契约测试（2026-09-18 统一模型批）：
## 单元层——QuiverAttributes.apply_knock 六规则（扣量/破线溢出+保底/回满/
## 霸体归零/无敌/死亡强飞/空中 K>0/空中 K=0 吞事件）；
## 链路层——CombatSystem 分发、起飞速度公式、连空即时再起飞、落地即停
## （A3 甲案）、落地回气、弹道高度打表（B2 观察，只打印不判定）。
## D 段（2026-09-19 弹墙状态门批）——真实 Area2D 物理重叠级契约：走路贴
## 弹墙带免伤（用户 F5 定罪现场）、链内贴墙扣血反弹（保留设计）、链退出
## 旗自动归零、旁观者零误伤、阵营组纯度哨兵。
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

	await _section_wall(spar, dir30)

	_finished = true


## D 段：弹墙状态门（物理重叠级）。用真场景 fixture（wall_band.tscn）当
## 相机隐形弹墙带替身（层配置同 QuiverLevelCamera：全高度层、被动可测）。
## 引擎陷阱备案（本批实测）：代码裸建 QuiverHitBox 子类必炸——_ready 读
## owner.get_path()，而 owner 赋值要求"已入树且为祖先"，add_child 前必 null，
## 两条件互斥无解，只能走场景实例（场景内非根节点 owner=场景根）。
const WALL_FIXTURE := "res://tools/knockout_contract/wall_band.tscn"

const CAMERA_SCENE := "res://addons/quiver.beat_em_up/utilities/custom_nodes/level_camera/quiver_level_camera.tscn"

func _make_wall() -> WallHitBox:
	var rig := (load(WALL_FIXTURE) as PackedScene).instantiate()
	add_child(rig)
	return rig.get_node("Wall") as WallHitBox


## 带相对墙的"向场内领先距离"：带墙位移在指场内单位向量上的投影。
func _band_lead(cam: Node, wall_path: String, band_path: String, inward: Vector2) -> float:
	var w := cam.get_node_or_null(wall_path) as Node2D
	var b := cam.get_node_or_null(band_path) as Node2D
	if w == null or b == null:
		return -1.0
	return (b.global_position - w.global_position).dot(inward)


func _find_hurtbox(ch: QuiverCharacter) -> QuiverHurtBox:
	for n in ch.find_children("*", "", true, false):
		if n is QuiverHurtBox:
			return n
	return null


func _section_wall(spar: QuiverCharacter, dir30: Vector2) -> void:
	var hurt := _find_hurtbox(spar)
	_check(hurt != null, "D0 spar 受击盒寻得（测试基建）")
	# D6 组纯度哨兵：阵营真实下发、wall 永绝回潮（防"伪阵营"机制复活）
	_check(hurt != null and hurt.is_in_group("area2d:spar_enemy")
			and not hurt.is_in_group("area2d:wall"),
			"D6 受击盒有真阵营且零 wall 残留")

	var bounces := {"n": 0}
	spar.attributes.wall_bounced.connect(func(_axis): bounces.n += 1)
	# 起身无敌帧纪律备案：Recovery 系动画带 attributes:is_invulnerable 值轨
	# （设计=起身保护窗口，CombatSystem.apply_knockback 入口直接吞交易）。
	# D2 的破线拳必须等回到 Idle 再发，否则被保护窗正确拦截（首跑实锤）。
	await _wait_state(spar, "Ground/Move/Idle", 900)
	var wall := _make_wall()
	var rig: Node = wall.get_parent()
	var hp0: float = spar.attributes.health_current

	# D1 站外贴带：链外旗默认 false → 真 area_entered 发生了但零结算
	rig.global_position = spar.global_position
	await _frames(3)
	_check(spar.attributes.health_current == hp0 and bounces.n == 0,
			"D1 链外走路贴弹墙带免伤（hp %.0f 弹 %d）" % [
			spar.attributes.health_current, bounces.n])
	remove_child(rig)

	# D2 真链路开链：唯一写入者在击飞链父状态 enter 置旗
	_apply(spar, 1200.0, dir30)
	var in_chain: bool = await _wait_state(spar, "Air/Knockout/Launch", 90)
	_check(in_chain and spar.attributes.in_knockout,
			"D2 开链 → in_knockout 置位（状态 %s 旗=%s）" % [
			str(spar.state_machine.state_name), str(spar.attributes.in_knockout)])

	# D3 链内贴带：扣 5 + wall_bounced 响（保留设计的物理级锁）
	rig.global_position = spar.global_position
	add_child(rig)
	await _frames(3)
	_check(is_equal_approx(spar.attributes.health_current, hp0 - 5.0)
			and bounces.n == 1,
			"D3 链内撞墙=扣5+反弹信号（hp %.0f 弹 %d）" % [
			spar.attributes.health_current, bounces.n])
	# D3 的 apply_damage 会挂 HitFreeze 慢放（真实副作用）；测试收权保帧预算
	await _frames(2)
	Engine.time_scale = 1.0

	# D4 链自然走完退出：旗自动归零（生命周期闭环，旧机制死亡分支泄漏已封）
	var back: bool = await _wait_state(spar, "Ground/Recovery", 1800)
	_check(back and not spar.attributes.in_knockout,
			"D4 链出 → 旗自动复位（状态 %s 旗=%s）" % [
			str(spar.state_machine.state_name), str(spar.attributes.in_knockout)])
	remove_child(rig)

	# D5 链外再贴 + 旁观者零误伤：门是角色侧属性，墙上无状态可泄
	var hp1: float = spar.attributes.health_current
	var bystander: QuiverCharacter = (load(SPAR) as PackedScene).instantiate()
	add_child(bystander)
	bystander.global_position = spar.global_position + Vector2(2000, 0)
	for _i in 12:
		await get_tree().physics_frame
	rig.global_position = bystander.global_position
	add_child(rig)
	await _frames(4)
	_check(spar.attributes.health_current == hp1
			and bystander.attributes.health_current
					== bystander.attributes.health_max
			and bounces.n == 1,
			"D5 链外再贴+旁观者免伤（弹计数保持 %d）" % bounces.n)
	remove_child(rig)
	rig.queue_free()

	# D7 reflect 语义引擎真值表（2026-09-19 弹墙终案卷的永久钉）：
	# reflect(n)=2(v·n)n−v 翻转“垂直于 n”的分量——左右竖墙配 UP 翻水平、
	# 上下横墙配 RIGHT 翻竖直。谁再凭文档措辞推理这两行，先来看看这条断言。
	_check(Vector2(100, -50).reflect(Vector2.UP) == Vector2(-100, -50),
			"D7 reflect(UP)=以竖轴为镜像翻水平分量")
	_check(Vector2(100, -50).reflect(Vector2.RIGHT) == Vector2(100, 50),
			"D7 reflect(RIGHT)=以横轴为镜像翻竖直分量")

	# D8 带墙分离几何锁：真实相机场景四带=墙心向场内 100px（带内墙外，
	# 命中必早于撞墙 ≥2 物理帧）——带墙同心旧布局若回潮，此断言当场红。
	var cam_rig: Node = (load(CAMERA_SCENE) as PackedScene).instantiate()
	add_child(cam_rig)
	await _frames(2)
	var d_l := _band_lead(cam_rig, "ScreenLimits/Left", "LeftBounce", Vector2.RIGHT)
	var d_r := _band_lead(cam_rig, "ScreenLimits/Right", "RightBounce", Vector2.LEFT)
	var d_t := _band_lead(cam_rig, "ScreenLimits/Top", "TopBounce", Vector2.DOWN)
	var d_b := _band_lead(cam_rig, "ScreenLimits/Bottom", "BottomBounce", Vector2.UP)
	# 带心−墙心 = BAND_REACH+WALL_OUTSET = 20+60 = 80（定和下 b+O≥74 即 2 帧余量）；
	# 带内沿入线仅 20px、墙面外挪 35px 处拦人（线−60+…）——参数调档须连读此锁。
	_check(d_l > 74.0 and d_r > 74.0 and d_t > 74.0 and d_b > 74.0
			and d_l < 90.0 and d_r < 90.0 and d_t < 90.0 and d_b < 90.0,
			"D8 带墙间距=80±定和合规（实测 %.0f/%.0f/%.0f/%.0f）"
			% [d_l, d_r, d_t, d_b])
	cam_rig.queue_free()


func _get_skin(ch: QuiverCharacter) -> CanvasItem:
	for c in ch.get_children():
		if c is CanvasItem and str(c.name).ends_with("Skin"):
			return c
	return null
