extends Node

## WP3 正式验证角色行为断言（角色保留入库，不清理）。
## 主权迁移（B2.5 Task4）：玩家身体从活体 chen 换成矩阵替身 test_actor——
## 本套验证对象是 spar_enemy（追打/小抄）与 street_vendor（站桩），
## 玩家位只需要一个持 area2d:player 的靶。
## 运行：godot --headless --path . res://tools/wp3_formal/verify.tscn

const Kit := preload("res://tools/matrix_runner/test_actor_kit.gd")
const SPAR := "res://characters/enemies/spar_enemy/spar_enemy.tscn"
const VENDOR := "res://characters/neutrals/street_vendor/street_vendor.tscn"

var _pass := 0
var _fail := 0


func _check(ok: bool, name: String) -> void:
	if ok:
		_pass += 1
		print("  PASS: ", name)
	else:
		_fail += 1
		print("  FAIL: ", name)
		get_tree().set_meta("failed", true)


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


func _ready() -> void:
	if not _guard_actor():
		print("════════ wp3-verify: %d PASS / %d FAIL ════════" % [_pass, _fail])
		get_tree().quit(1)
		return
	var actor: QuiverCharacter = load(Kit.ACTOR_SCENE).instantiate()
	actor.position = Vector2(200, 400)
	add_child(actor)
	var spar: QuiverCharacter = load(SPAR).instantiate()
	spar.position = Vector2(650, 400)
	add_child(spar)
	var vendor: QuiverCharacter = load(VENDOR).instantiate()
	vendor.position = Vector2(400, 520)
	add_child(vendor)
	await _tick(6)
	
	var policy: Script = spar.behavior.get_script() if spar.behavior != null else null
	_check(policy != null and String(policy.resource_path).ends_with("spar_enemy_ai.gd"), \
			"spar_enemy 挂自家小抄")
	_check(vendor.behavior is QuiverBehaviorIdle, "street_vendor 被动档")
	
	var hp0: float = actor.attributes.health_current
	var dist0: float = spar.global_position.distance_to(actor.global_position)
	var vendor_pos := vendor.global_position
	await _tick(150)
	var dist1: float = spar.global_position.distance_to(actor.global_position)
	_check(dist1 < dist0 - 50.0, \
			"陪练靠近（%f→%f px）" % [dist0, dist1])
	_check(actor.attributes.health_current < hp0, \
			"陪练打出伤害（替身 %f→%f）" % [hp0, actor.attributes.health_current])
	_check(vendor_pos.distance_to(vendor.global_position) < 1.0, "小贩全程站桩")
	
	print("════════ wp3-verify: %d PASS / %d FAIL ════════" % [_pass, _fail])
	get_tree().quit(1 if get_tree().has_meta("failed") else 0)


func _tick(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
