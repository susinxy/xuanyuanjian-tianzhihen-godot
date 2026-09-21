extends Node2D

## 舞台容器原型 spike（2026-09-21）——一次性耗材，不进回归矩阵、不承载施工。
## 七点事实 = S2 设计会"舞台容器/跨地点状态延续"议题的实测底稿：
## E1 锁房刷怪 E2 清场（真死链） E3 切 B（A 摘树/玩家相机迁移） E4 回 A
## 清场持久+检测幂等 E5 光照归属与画布残留 E6 玩家状态天然延续 E7 破坏面清单。

const STAGE_A := preload("res://tools/container_prototype/stage_a.tscn")
const STAGE_B := preload("res://tools/container_prototype/stage_b.tscn")

## key -> 舞台实例：常驻内存只摘树不释放，"清场持久"的机制来源即在此
var _stages := {}
var _active := ""
var _log: Array[String] = []

@onready var _chen: QuiverCharacter = $Players/Chen


func _ready() -> void:
	await get_tree().physics_frame
	await _probe()
	print("════════ container-spike: 完成 ════════")
	for line in _log:
		print("  " + line)
	get_tree().quit(0)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _wait_until(pred: Callable, cap: int = 600) -> bool:
	for _i in cap:
		if pred.call():
			return true
		await get_tree().physics_frame
	return pred.call()


func _stage(key: String) -> Node2D:
	if not _stages.has(key):
		_stages[key] = (STAGE_A if key == "A" else STAGE_B).instantiate()
	return _stages[key]


## 切换三拍：静默窗（在途 tween 落位）→ 等死亡链离场清空 → 摘挂树
## （不排空就摘树=孤儿 tween 回调炸 get_tree()null + 尸体随树迁移复挂，
##  两条都是本 spike 钉出的真实裂缝，正式容器策略位：强清或等待）
func _switch_to(key: String, entry: Vector2) -> void:
	if _active == key:
		return
	if _active != "":
		await _frames(90)
		# 策略 A=切换即强清：等 120 帧不动就回收在场敌人（尸体/在途都清）
		var settled := 0
		while _spar_count() > 0 and settled < 4:
			var c0 := _spar_count()
			await _frames(30)
			settled = settled + 1 if _spar_count() == c0 else 0
		for x in get_tree().get_nodes_in_group("area2d:spar_enemy"):
			if x is Node:
				x.queue_free()
		await _frames(4)
		remove_child(_stage(_active))
	add_child(_stage(key))
	_active = key
	_chen.global_position = entry


func _spawner(key: String) -> QuiverEnemySpawner:
	return _stage(key).get_node("Room1/EnemySpawner1")


func _spar_count() -> int:
	var n := 0
	for x in get_tree().get_nodes_in_group("area2d:spar_enemy"):
		if x is QuiverCharacter:
			n += 1
	return n


## 真死链清场（判例照抄 stage_contract：血归零+带竖直分量 launch，浅杀不走演出）
func _kill_all() -> void:
	for x in get_tree().get_nodes_in_group("area2d:spar_enemy"):
		if x is QuiverCharacter:
			x.attributes.health_current = 0
			var data := QuiverKnockbackData.new(1200.0, CombatSystem.HurtTypes.HIGH,
					Vector2(0.866, -0.5))
			CombatSystem.apply_knockback(data, x.attributes)


func _probe() -> void:
	# —— E1 锁房刷怪 ——
	await _switch_to("A", Vector2(500, 600))
	await _frames(30)
	var cam: Camera2D = _chen.get_node("LevelCamera")
	_chen.global_position = Vector2(700, 600)
	var locked: bool = await _wait_until(func(): return cam.limit_right == 1500, 300)
	var spawned: bool = await _wait_until(func(): return _spar_count() == 1, 120)
	_log.append("E1 锁房刷怪：locked=%s（limit_right=%d） spawned=%s" % [locked, cam.limit_right, spawned])

	# —— E2 清场 ——
	await _frames(30)
	_kill_all()
	var cleared: bool = await _wait_until(func(): return _spawner("A").is_completed, 900)
	_log.append("E2 真死链清场：spawner.is_completed=%s" % cleared)
	_chen.attributes.health_current = 71.0
	# 伤害日志：抓"谁在咬玩家"（spike 工具自证）
	_chen.attributes.health_changed.connect(func():
			_log.append("    [dmg] hp→%.0f state=%s" % [_chen.attributes.health_current,
					str(_chen.state_machine.state_name)]))

	# —— E3 切 B（B 房入口=线东：不锁房不刷怪是设计前提，E3 验证它）——
	await _switch_to("B", Vector2(700, 600))
	await _frames(30)
	_log.append("E3 切舞台 B：A 摘树=%s B 在树=%s 相机随玩家留存=%s 场上敌人=%d（应为 0）" % [
			not _stage("A").is_inside_tree(), _stage("B").is_inside_tree(),
			cam.is_inside_tree() and cam.is_current(), _spar_count()])

	# —— E4 回 A：清场持久 + 检测幂等（入口同放线东，隔离出"真复挂复活"）——
	await _switch_to("A", Vector2(700, 600))
	await _frames(40)
	var persists: bool = _spawner("A").is_completed and _spar_count() == 0
	_chen.global_position = Vector2(700, 600)
	await _frames(60)
	var no_retrigger: bool = _spar_count() == 0
	_log.append("E4 回 A 清场持久=%s 再跨线不复活=%s（摘树不释放=持久机制本体）" % [persists, no_retrigger])

	# —— E5 光照归属 ——
	var cm: CanvasModulate = _stage("A").get_node("CanvasModulate")
	_log.append("E5 光照：controller 一次性 ready 语义（摘挂不重跑 enter_scene）；"
			+ "画布色 %s 随舞台摘树仍留全局——切换者负责复位（骨架缺口清单项）" % cm.color)

	# —— E6 玩家状态 ——
	_log.append("E6 玩家状态跨切换天然延续：hp=%.0f（玩家永驻壳内=不重载设计的直接红利）"
			% _chen.attributes.health_current)

	# —— E7 破坏面盘点（设计会参考） ——
	_log.append("E7 破坏面：骨架五职责需升壳——检查点/HUD+暂停+死亡壳/波次聚合解锁/"
			+ "ESC 接管/通关面板；相机挂玩家零改动✓；R5 落位路径重定义（本实验 ../../../Players）；"
			+ "清场持久只在'不释放'策略下成立→存档(S5)天然同构；单地点双轨制=待裁决议题③")
