extends Node

## 受击车道换轴契约（2026-09-19 上下攻击批）：
## 单元层——CombatSystem 排(Y)/列(X)窗口家族（同一 HitLaneLimits，中心换轴，
## lane_size±hit_lane_offset 语义对称）；
## 行为层——真 chen 出手（QuiverActionAttack 主轴塌缩 + attributes.skin_direction
## 镜像生命周期）× PASSIVE 站桩小贩（零漂移靶）四方位打点：
## B1 正北 120px：旧 Y 车道必拒、新 X 车道必中（用户定罪现场=本案主症状）；
## B4 北偏东 100px：列外必拒；B5 正东同排：旧横攻语义回归；B6 东偏北 120px：排外必拒。
## 运行：godot --headless --path . res://tools/attack_lane_contract/attack_lane_contract.tscn

const CHEN := "res://characters/playable/chen/chen.tscn"
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


func _attack(chen: QuiverCharacter, dir: Vector2) -> void:
	chen._skin.skin_direction = dir
	chen.state_machine.transition_to("Ground/Combo1")


func _place(vendor: QuiverCharacter, chen: QuiverCharacter, offset: Vector2) -> void:
	vendor.global_position = chen.global_position + offset
	await _frames(6)


func _reset_target(vendor: QuiverCharacter) -> void:
	vendor.attributes.reset()
	await _wait_state(vendor, "Ground/Move/Idle", 600)


func _flow() -> void:
	# ———— 单元层：车道窗口家族的轴无关构造 ————
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

	# ———— 行为层：真角色入场 ————
	var stage := Node2D.new()
	add_child(stage)
	var chen: QuiverCharacter = (load(CHEN) as PackedScene).instantiate()
	var vendor: QuiverCharacter = (load(VENDOR) as PackedScene).instantiate()
	stage.add_child(chen)
	stage.add_child(vendor)
	chen.global_position = Vector2(500, 400)
	vendor.global_position = Vector2(500, 280)
	await _frames(18)
	var ok0: bool = await _wait_state(chen, "Ground/Move/Idle", 120)
	_check(ok0 and str(vendor.state_machine.state_name) != "", "B0 chen/小贩入场就绪")
	_check(chen.attributes.skin_direction == Vector2.ZERO,
			"B0b 待机镜像=零向量（非出手态旧语义护城河）")

	# B1/B2/B3 正北 120px（Δy 出旧排窗 2 倍）→ 纵攻必中 + 镜像生命周期
	_attack(chen, Vector2.UP)
	# 精确 == 会死于 from_angle(±90°) 的 6e-17 浮点 eps（B2 首跑实锤）：用近似
	_check(chen.attributes.skin_direction.is_equal_approx(Vector2(0, -1)),
			"B2 出手镜像=主轴塌缩快照 (0,-1)（近似比，%s）"
			% chen.attributes.skin_direction)
	var hit_north: bool = await _watch_hit(vendor, vendor.attributes.health_current, 240)
	_check(hit_north, "B1 正北 120px 上攻击中（换轴主症状；旧代码必挂）")
	_check(await _wait_state(chen, "Ground/Move/Idle", 600), "B3a 出手窗结束后回 Idle")
	_check(chen.attributes.skin_direction == Vector2.ZERO,
			"B3 出手窗出 → 镜像归零（生命周期成对）")

	# B4 北偏东 100px → 列外必拒
	await _reset_target(vendor)
	await _place(vendor, chen, Vector2(100, -120))
	var hp4: float = vendor.attributes.health_current
	_attack(chen, Vector2.UP)
	await _wait_state(chen, "Ground/Move/Idle", 600)
	_check(vendor.attributes.health_current >= hp4,
			"B4 北偏东 100px 上攻不中（列窗 60 拒，%.0f）" % vendor.attributes.health_current)

	# B5 正东 80px 南偏 30（排内）→ 横攻回归
	await _reset_target(vendor)
	await _place(vendor, chen, Vector2(80, 30))
	hp4 = vendor.attributes.health_current
	_attack(chen, Vector2.RIGHT)
	_check(chen.attributes.skin_direction.is_equal_approx(Vector2(1, 0)),
			"B5a 横攻镜像=(1,0)（选轴判据走旧 Y 分支）")
	var hit_east: bool = await _watch_hit(vendor, hp4, 240)
	_check(hit_east, "B5 正东同排打中（横攻旧语义零扰动回归锁）")
	await _wait_state(chen, "Ground/Move/Idle", 600)

	# B6 东偏北 120px → 排外必拒（行为级锁）
	await _reset_target(vendor)
	await _place(vendor, chen, Vector2(80, -120))
	hp4 = vendor.attributes.health_current
	_attack(chen, Vector2.RIGHT)
	await _wait_state(chen, "Ground/Move/Idle", 600)
	_check(vendor.attributes.health_current >= hp4,
			"B6 东偏北 120px 横攻不中（排窗 60 拒/几何不达双保险）")
	await _reset_target(vendor)

	_finished = true
