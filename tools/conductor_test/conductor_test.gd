extends Node

## AI 发令台断言：待命→Enter 开打→再 Enter 暂停。
## 运行：godot --headless --path . res://tools/conductor_test/conductor_test.tscn

var _pass := 0
var _fail := 0


func _check(ok: bool, name: String) -> void:
	if ok:
		_pass += 1
		print("  PASS: ", name)
	else:
		_fail += 1
		print("  FAIL: ", name)


func _tick(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	var chen: QuiverCharacter = load("res://characters/playable/chen/chen.tscn").instantiate()
	chen.position = Vector2(200, 400)
	add_child(chen)
	var spar: QuiverCharacter = load(
			"res://characters/enemies/spar_enemy/spar_enemy.tscn").instantiate()
	spar.position = Vector2(600, 400)
	add_child(spar)
	var conductor := preload("res://scripts/test_scene_ai_conductor.gd").new()
	conductor.name = "AIConductor"
	add_child(conductor)
	await _tick(4)
	
	_check(spar.behavior.get("active") == false, "开局 AI 待命（active=false）")
	var p0: Vector2 = spar.global_position
	await _tick(60)
	_check(spar.global_position.distance_to(p0) < 1.0, "待命期 60 帧零位移")
	_check(chen.behavior.get("active") == true, "玩家档不受控于待命（仍 active）")
	
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.pressed = true
	get_window().push_input(ev)
	await _tick(2)
	_check(spar.behavior.get("active") == true, "Enter → AI 开始行动")
	
	var d0: float = spar.global_position.distance_to(chen.global_position)
	await _tick(150)
	var d1: float = spar.global_position.distance_to(chen.global_position)
	_check(d1 < d0 - 50.0, "开令后逼近（%f→%f）" % [d0, d1])
	
	var ev2 := InputEventKey.new()
	ev2.keycode = KEY_ENTER
	ev2.pressed = true
	get_window().push_input(ev2)
	await _tick(2)
	_check(spar.behavior.get("active") == false, "再按 Enter → 暂停")
	_check(spar.channel.axis.length() < 0.001, "暂停瞬间通道清零（无残余滑行）")
	var p1: Vector2 = spar.global_position
	await _tick(60)
	_check(spar.global_position.distance_to(p1) < 1.0, "暂停期 60 帧零位移")
	_check(spar.attributes.health_current > 0, "全程 spar 存活（断言环境纯净）")
	
	print("════════ conductor: %d PASS / %d FAIL ════════" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
