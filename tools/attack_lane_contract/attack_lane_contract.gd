extends Node

## 受击车道换轴契约（2026-09-19 上下攻击批）：
## 单元层——CombatSystem 排(Y)/列(X)窗口家族（同一 HitLaneLimits，中心换轴，
## lane_size±hit_lane_offset 语义对称）；
## 行为层——真替身出手（QuiverActionAttack 主轴塌缩 + attributes.skin_direction
## 镜像生命周期）× PASSIVE 站桩小贩（零漂移靶）四方位打点：
## 主权迁移（B2.5 Task4）：出手位从活体 chen 换成矩阵替身 test_actor——
## 车道契约约束的是插件动作层+模板皮肤血统一致的攻击盒，不验 chen 本体内容。
## B1 正北 120px：旧 Y 车道必拒、新 X 车道必中（用户定罪现场=本案主症状）；
## B4 北偏东 100px：列外必拒；B5 正东同排：旧横攻语义回归；B6 东偏北 120px：排外必拒；
## B7-B9（2026-09-20 决策定档批）表现层防"乌龙"断言：命中后防守方必达 Ground/Hurt、
## 皮肤 AnimTree 必落 hurt_high、纵攻受击全程不改写 facing_x——把"纵向受击动画方向 =
## 防守方上一次水平朝向（与上下跳跃同源机制）"从口头共识钉成机器契约。
## 运行：godot --headless --path . res://tools/attack_lane_contract/attack_lane_contract.tscn

const Kit := preload("res://tools/matrix_runner/test_actor_kit.gd")
const ACTOR_SCENE := Kit.ACTOR_SCENE
const VENDOR := "res://characters/neutrals/street_vendor/street_vendor.tscn"

var _fails := 0
var _finished := false


func _ready() -> void:
	await _flow()
	_check(_finished, "全序列执行完成（协程静默中断防线）")
	print("════════ attack-lane-contract: %s ════════" % ("PASS" if _fails == 0 else "FAIL"))
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails += 1
	print("  %s: %s" % ["PASS" if ok else "FAIL", label])


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _wait_state(ch: QuiverCharacter, path: String, cap: int = 600) -> bool:
	for _i in cap:
		if str(ch.state_machine.state_name) == path:
			return true
		await get_tree().physics_frame
	return str(ch.state_machine.state_name) == path


## 观察靶子掉血（命中即提前 true；全程未掉血 false）
func _watch_hit(vendor: QuiverCharacter, hp0: float, cap: int) -> bool:
	for _i in cap:
		if vendor.attributes.health_current < hp0:
			return true
		await get_tree().physics_frame
	return vendor.attributes.health_current < hp0


## 表现层记录窗：逐帧记录 掉血/入Hurt状态/hurt_high动画 三旗。转 Hurt 是
## call_deferred、动画节点切换要真实帧提交才可见——早退式断言会出竞态假红，
## 窗满或三旗齐才回（knockout 批"信标要 process 提交阶段才发"同款纪律）
func _watch_visual(vendor: QuiverCharacter, hp0: float, cap: int) -> Dictionary:
	var seen := {"hit": false, "hurt_state": false, "hurt_anim": false}
	for _i in cap:
		if vendor.attributes.health_current < hp0:
			seen.hit = true
		if str(vendor.state_machine.state_name) == "Ground/Hurt":
			seen.hurt_state = true
		# _playback 声明在皮肤组件子类上，走无类型局部避免基类静态检查误杀
		var pb = vendor._skin._playback
		if pb != null and String(pb.get_current_node()) == "hurt_high":
			seen.hurt_anim = true
		if seen.hit and seen.hurt_state and seen.hurt_anim:
			return seen
		await get_tree().physics_frame
	return seen


## 头部三态守卫（input_channel 同款只读阶梯；缺席打可读红、绝不代 runner 创建）
func _guard_actor() -> bool:
	var remedy := "先跑 bash tools/matrix_runner/run_matrix.sh --ensure-only 建好 test_actor"
	if not Kit.exists():
		_check(false, "替身守卫：test_actor 缺席（%s）" % remedy)
		return false
	var rc := Kit.ensure()
	if rc == Kit.NEEDS_IMPORT:
		_check(false, "替身守卫：test_actor 在但本进程不可加载=NEEDS_IMPORT(42)（%s）" % remedy)
		return false
	if rc != OK:
		_check(false, "替身守卫：ensure() 报产线失败（rc=%d，诊断见上行）" % rc)
		return false
	print("ACTOR-GATE: test_actor 就绪（只读三态守卫通过）")
	return true


func _attack(actor: QuiverCharacter, dir: Vector2) -> void:
	actor._skin.skin_direction = dir
	actor.state_machine.transition_to("Ground/Combo1")


func _place(vendor: QuiverCharacter, actor: QuiverCharacter, offset: Vector2) -> void:
	vendor.global_position = actor.global_position + offset
	await _frames(6)


func _reset_target(vendor: QuiverCharacter) -> void:
	vendor.attributes.reset()
	await _wait_state(vendor, "Ground/Move/Idle", 600)


func _flow() -> void:
	# ———— 单元层：车道窗口家族的轴无关构造（无角色依赖，缺席态也能跑）————
	var def := QuiverAttributes.new()
	def.ground_level = 200.0
	var atk := QuiverAttributes.new()
	atk.ground_level = 320.0
	_check(not CombatSystem.is_in_same_lane_as(def, atk),
			"L1 排窗口旧语义：Δy=120 出 60 窗 → 拒（病根现状钉死）")
	atk.ground_level = 240.0
	_check(CombatSystem.is_in_same_lane_as(def, atk), "L2 排窗口：Δy=40 窗内 → 收")
	_check(CombatSystem.is_in_same_column_as(def, atk, 500.0, 505.0),
			"L3 列窗口：同列 Δx=5 → 收")
	_check(not CombatSystem.is_in_same_column_as(def, atk, 500.0, 700.0),
			"L4 列窗口：Δx=200 → 拒")
	def.hit_lane_offset = -30
	_check(CombatSystem.is_in_same_column_as(def, atk, 500.0, 520.0)
			and not CombatSystem.is_in_same_column_as(def, atk, 500.0, 545.0),
			"L5 缩窗 offset=-30：列窗收至 [470,530]")
	def.hit_lane_offset = 0

	# ———— 行为层：真角色入场（替身只读守卫先行）————
	if not _guard_actor():
		return
	var stage := Node2D.new()
	add_child(stage)
	var actor: QuiverCharacter = (load(ACTOR_SCENE) as PackedScene).instantiate()
	var vendor: QuiverCharacter = (load(VENDOR) as PackedScene).instantiate()
	stage.add_child(actor)
	stage.add_child(vendor)
	actor.global_position = Vector2(500, 400)
	vendor.global_position = Vector2(500, 280)
	await _frames(18)
	var ok0: bool = await _wait_state(actor, "Ground/Move/Idle", 120)
	_check(ok0 and str(vendor.state_machine.state_name) != "", "B0 替身/小贩入场就绪")
	_check(actor.attributes.skin_direction == Vector2.ZERO,
			"B0b 待机镜像=零向量（非出手态旧语义护城河）")

	# B1/B2/B3/B7/B8/B9 正北 120px → 纵攻必中 + 镜像生命周期 + 表现层断言组。
	# B9 决策锁：受击/击飞处理永不写防守方面向（动画走上一次水平朝向，同纵跳机制）
	# ——未来若有人实现"北来→强制 right"类映射，会先撞红本条。
	vendor._skin.facing_x = -1.0
	_attack(actor, Vector2.UP)
	# 精确 == 会死于 from_angle(±90°) 的 6e-17 浮点 eps（B2 首跑实锤）：用近似
	_check(actor.attributes.skin_direction.is_equal_approx(Vector2(0, -1)),
			"B2 出手镜像=主轴塌缩快照 (0,-1)（近似比，%s）"
			% actor.attributes.skin_direction)
	var seen := await _watch_visual(vendor, vendor.attributes.health_current, 240)
	_check(seen.hit, "B1 正北 120px 上攻击中（换轴主症状；旧代码必挂）")
	_check(seen.hurt_state, "B7 命中后防守方状态机必达 Ground/Hurt（防乌龙断言）")
	_check(seen.hurt_anim, "B8 皮肤 AnimTree 当前节点必落 hurt_high（punch1 hurt_type=HIGH）")
	if not seen.hurt_anim:
		var pb = vendor._skin._playback
		print("[att-lane] B8 诊断 current_node=%s" % (
				str(pb.get_current_node()) if pb != null else "<playback 空>"))
	_check(vendor._skin.facing_x == -1.0,
			"B9 纵攻受击全程不改写 facing_x（方向=上次水平朝向，决策定档锁）")
	_check(await _wait_state(actor, "Ground/Move/Idle", 600), "B3a 出手窗结束后回 Idle")
	_check(actor.attributes.skin_direction == Vector2.ZERO,
			"B3 出手窗出 → 镜像归零（生命周期成对）")

	# B4 北偏东 100px → 列外必拒
	await _reset_target(vendor)
	await _place(vendor, actor, Vector2(100, -120))
	var hp4: float = vendor.attributes.health_current
	_attack(actor, Vector2.UP)
	await _wait_state(actor, "Ground/Move/Idle", 600)
	_check(vendor.attributes.health_current >= hp4,
			"B4 北偏东 100px 上攻不中（列窗 60 拒，%.0f）" % vendor.attributes.health_current)

	# B5 正东 80px 南偏 30（排内）→ 横攻回归
	await _reset_target(vendor)
	await _place(vendor, actor, Vector2(80, 30))
	hp4 = vendor.attributes.health_current
	_attack(actor, Vector2.RIGHT)
	_check(actor.attributes.skin_direction.is_equal_approx(Vector2(1, 0)),
			"B5a 横攻镜像=(1,0)（选轴判据走旧 Y 分支）")
	var hit_east: bool = await _watch_hit(vendor, hp4, 240)
	_check(hit_east, "B5 正东同排打中（横攻旧语义零扰动回归锁）")
	await _wait_state(actor, "Ground/Move/Idle", 600)

	# B6 东偏北 120px → 排外必拒（行为级锁）
	await _reset_target(vendor)
	await _place(vendor, actor, Vector2(80, -120))
	hp4 = vendor.attributes.health_current
	_attack(actor, Vector2.RIGHT)
	await _wait_state(actor, "Ground/Move/Idle", 600)
	_check(vendor.attributes.health_current >= hp4,
			"B6 东偏北 120px 横攻不中（排窗 60 拒/几何不达双保险）")
	await _reset_target(vendor)

	_finished = true
