extends Node

## AI 发令台断言：待命→Enter 开打→再 Enter 暂停。
## 主权迁移（B2.5 Task4）：玩家身体从活体 chen 换成矩阵替身 test_actor
## （本套只需要一个持 area2d:player 标签的身体当 AI 目标，不验证 chen 内容）。
## 运行：godot --headless --path . res://tools/conductor_test/conductor_test.tscn

const Kit := preload("res://tools/matrix_runner/test_actor_kit.gd")

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


## 头部三态守卫（input_channel 同款只读阶梯；缺席打可读红、绝不代 runner 创建）
func _guard_actor() -> bool:
	var remedy := "先跑 bash tools/matrix_runner/run_matrix.sh --ensure-only 建好 test_actor"
	# 终审波：判态结构性断奶 ensure()——peek() 零副作用三态分类，
	# ABSENT/NEEDS_IMPORT 两支都只打处方红，创建泄漏在类型上不可能
	var st: int = Kit.peek()  # 只读分类（peek 承诺零副作用、永不建档）
	match st:
		Kit.READY:
			print("ACTOR-GATE: test_actor 就绪（只读三态守卫通过）")
			return true
		Kit.NEEDS_IMPORT:
			_check(false, "替身守卫：test_actor 已建未导入（%s）" % remedy)
		Kit.ABSENT:
			_check(false, "替身守卫：test_actor 缺席（%s）" % remedy)
		_:
			_check(false, "替身守卫：peek() 返回未知态 %d（kit 契约破损，查 test_actor_kit）" % st)
	return false


func _ready() -> void:
	if not _guard_actor():
		print("════════ conductor: %d PASS / %d FAIL ════════" % [_pass, _fail])
		get_tree().quit(0 if _fail == 0 else 1)
		return
	var actor: QuiverCharacter = load(Kit.ACTOR_SCENE).instantiate()
	actor.position = Vector2(200, 400)
	add_child(actor)
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
	_check(actor.behavior.get("active") == true, "玩家档不受控于待命（仍 active）")
	
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.pressed = true
	get_window().push_input(ev)
	await _tick(2)
	_check(spar.behavior.get("active") == true, "Enter → AI 开始行动")
	
	var d0: float = spar.global_position.distance_to(actor.global_position)
	await _tick(150)
	var d1: float = spar.global_position.distance_to(actor.global_position)
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
