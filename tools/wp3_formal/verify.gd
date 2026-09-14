extends Node

## WP3 正式验证角色行为断言（角色保留入库，不清理）。
## 运行：godot --headless --path . res://tools/wp3_formal/verify.tscn

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


func _ready() -> void:
	var chen: QuiverCharacter = load("res://characters/playable/chen/chen.tscn").instantiate()
	chen.position = Vector2(200, 400)
	add_child(chen)
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
	
	var hp0: float = chen.attributes.health_current
	var dist0: float = spar.global_position.distance_to(chen.global_position)
	var vendor_pos := vendor.global_position
	await _tick(150)
	var dist1: float = spar.global_position.distance_to(chen.global_position)
	_check(dist1 < dist0 - 50.0, \
			"陪练靠近（%f→%f px）" % [dist0, dist1])
	_check(chen.attributes.health_current < hp0, \
			"陪练打出伤害（chen %f→%f）" % [hp0, chen.attributes.health_current])
	_check(vendor_pos.distance_to(vendor.global_position) < 1.0, "小贩全程站桩")
	
	print("════════ wp3-verify: %d PASS / %d FAIL ════════" % [_pass, _fail])
	get_tree().quit(1 if get_tree().has_meta("failed") else 0)


func _tick(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
