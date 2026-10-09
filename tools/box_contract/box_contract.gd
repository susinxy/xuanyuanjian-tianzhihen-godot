extends Node

## box_contract —— PlayfieldBox 盒组件契约（2026-10 盒轨搭建批 T1，矩阵新条目）
## 管辖腿表：
## · A 装配自证：盒节点在位、四边墙带生成、墙带配方（layer=全高度 16760832/mask=0）、
##   组注册 &"playfield_box"（A1+A2-A5 在位+A6-A9 配方+A10 组，共 10）；
## · B 行走封锁：探针体恒速南行/东行，真物理 move_and_slide 撞带被阻不越盒界；
## · C 击飞封锁：1500px/s 高速东行不穿盒墙（判据须真撞墙：0 起点→界 790/拍 25px，
##   brief 原 30 拍=750px 触不到墙属空转腿，实调 60 拍使红档该腿响亮 FAIL，对账见报告）；
## · D 开关独立性：gen_vis/north_wall 各自关闭件消失、余带不受影响；
## · E 真角色共存冒烟：test_actor 入场沉降（判例：初速沉降相位随机→宽松界）存活；
## · F 模板 v2 结构冒烟：load scenes/chapter/segment_template.tscn 实例化，验盒在位
##   生带、遭遇带无房合法形、锁房件在位/旧手摆几何已退（手改 tscn 判例防线）；
## · 终旗（完成旗，协程静默跳段判例防线）：全序列跑到尾才绿。
## 测试主权法（B2.5）：E 腿一律 test_actor 替身（Kit 消费只读，缺席=红+处方）。
## 落盘卫生：本套不写账不记检查点（仅段 fixture+盒组件，无壳无记账件），免重定向。
## 【豁免】无——不消费 chen 本体数据。

const Kit := preload("res://tools/matrix_runner/test_actor_kit.gd")
const SEG_FIXTURE := "res://tools/box_contract/fixtures/seg_box_min.tscn"
const PROBE := preload("res://tools/box_contract/probe_body.gd")
const BOX_RECT := Rect2(-200, -200, 1000, 500)   # fixture 盒矩形（局部=世界，段摆原点）
const EXPECTED := 24  # 终账门（T1 腿表实数 A10+B2+C1+D3+E2+完成旗=19，
                      # T3 追加 F 模板冒烟 5 → 实测终数 24；brief 的 23 少算完成旗
                      # 一枚，按"实测终数为准"取紧门 24，对账见 T3 报告）

var _fails := 0
var _asserts := 0
var _finished := false


func _ready() -> void:
	await _run_all()
	# 完成旗（协程静默跳段判例的防线）：全序列跑到尾才绿
	_finished = true
	_check(_finished, "F 全序列执行完成")
	_report()


func _check(cond: bool, msg: String) -> void:
	_asserts += 1
	if cond:
		print("  PASS: ", msg)
	else:
		_fails += 1
		print("  FAIL: ", msg)


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _require_kit(tag: String) -> bool:
	if not Kit.exists():
		_check(false, "%s test_actor 缺席（先跑 run_matrix.sh --ensure-only）" % tag)
		return false
	return true


func _band(seg: Node, p_name: String) -> StaticBody2D:
	return seg.get_node_or_null(NodePath("PlayfieldBox/" + p_name)) as StaticBody2D


func _run_all() -> void:
	print("════════ box-contract 开始 ════")

	# ── A 装配自证（挂点=self：root._ready 期间 add_child 丢演员判例同 control 套）──
	var seg := (load(SEG_FIXTURE) as PackedScene).instantiate()
	add_child(seg)
	await _frames(2)
	var box := seg.get_node_or_null(^"PlayfieldBox")
	_check(box != null, "A1 盒节点在位")
	var band_names := ["BandNorth", "BandSouth", "BandEast", "BandWest"]
	for i in range(4):
		_check(_band(seg, band_names[i]) != null, "A%d 墙带在位 %s" % [i + 2, band_names[i]])
	for i in range(4):
		var b := _band(seg, band_names[i])
		_check(b != null and b.collision_layer == 16760832 and b.collision_mask == 0,
				"A%d 墙带配方 %s" % [i + 6, band_names[i]])
	_check(box != null and box.is_in_group(&"playfield_box"), "A10 组注册")

	# ── B 行走封锁（真物理推进，非状态摆位）──
	var pb: CharacterBody2D = PROBE.new()
	pb.name = "ProbeBC"
	seg.add_child(pb)
	pb.global_position = Vector2(0, 0)
	pb.axis = Vector2(0, 1)
	await _frames(180)
	_check(pb.global_position.y <= BOX_RECT.end.y + 4.0,
			"B1 南界封锁（实际 %s）" % pb.global_position.y)
	pb.axis = Vector2(1, 0)
	await _frames(180)
	_check(pb.global_position.x <= BOX_RECT.end.x + 4.0,
			"B2 东界封锁（实际 %s）" % pb.global_position.x)

	# ── C 击飞封锁：高速不穿盒墙 ──
	pb.global_position = Vector2(0, 0)
	pb.speed = 1500.0
	pb.axis = Vector2(1, 0)
	await _frames(60)
	pb.axis = Vector2.ZERO
	await _frames(1)
	_check(pb.global_position.x <= BOX_RECT.end.x + 4.0,
			"C 高速 1500px/s 不穿盒墙（实际 %s）" % pb.global_position.x)

	# ── D Vis/开关独立性（新实例，入树前改导出）──
	pb.queue_free()
	await _frames(1)
	var seg2 := (load(SEG_FIXTURE) as PackedScene).instantiate()
	# instantiate 后 add_child 前遍历根子找盒节点（brief 判定 get_node 不可取，遵行）
	var box2: PlayfieldBox = null
	for c in seg2.get_children():
		if c is PlayfieldBox:
			box2 = c as PlayfieldBox
			break
	if box2 != null:
		box2.gen_vis = false
		box2.north_wall = false
	add_child(seg2)
	await _frames(2)
	_check(box2 != null and box2.get_node_or_null(^"VisFloor") == null,
			"D1 gen_vis 关闭无地板件")
	_check(box2 != null and _band(seg2, "BandNorth") == null, "D2 north_wall 关闭无北带")
	_check(box2 != null and _band(seg2, "BandSouth") != null, "D3 其余墙带不受影响")

	# ── E 真角色共存冒烟（test_actor 替身）──
	if _require_kit("E"):
		var seg3 := (load(SEG_FIXTURE) as PackedScene).instantiate()
		add_child(seg3)
		var actor := (load(Kit.ACTOR_SCENE) as PackedScene).instantiate() as QuiverCharacter
		actor.name = "BoxEActor"
		seg3.add_child(actor)
		actor.global_position = Vector2(0, 100)
		await _frames(60)
		_check(actor.global_position.y <= BOX_RECT.end.y + 60.0,
				"E1 活体不越界（宽松界，判据见判例：初速沉降 ±；实际 %s）"
				% actor.global_position.y)
		_check(actor != null and actor.attributes != null
				and actor.attributes.health_current > 0.0,
				"E2 活体存活入场")
		# 腿末清场
		actor.queue_free()
		seg3.queue_free()
		await _frames(3)

	# ── F：模板 v2 结构冒烟（手改 tscn 判例防线：解析错/吞属性当场现形）──
	var tpl := load("res://scenes/chapter/segment_template.tscn") as PackedScene
	_check(tpl != null, "F1 模板可实例化（零 Parse Error 族）")
	if tpl != null:
		var tpl_seg := tpl.instantiate()
		add_child(tpl_seg)
		await _frames(2)
		var tpl_box := tpl_seg.get_node_or_null(^"PlayfieldBox")
		_check(tpl_box != null and tpl_box.is_in_group(&"playfield_box"), "F2 盒在位且运行时生带")
		_check(tpl_box != null and tpl_box.get_node_or_null(^"BandSouth") != null, "F3 四带派生")
		var enc := tpl_seg.get_node_or_null(^"Encounter1/Detector")
		_check(enc != null and str(enc.get("path_fight_room")) == "", "F4 遭遇带无房合法形")
		_check(tpl_seg.get_node_or_null(^"Room1/PlayerDetector") != null \
				and tpl_seg.get_node_or_null(^"GroundBody") == null, "F5 锁房件在位/旧几何已退")
		tpl_seg.queue_free()
		await _frames(3)

	# 收尾拆除本套自生的段（矩阵同轮其他套不受污染）
	seg.queue_free()
	seg2.queue_free()
	await _frames(1)


func _report() -> void:
	var ok := _fails == 0 and _finished and _asserts >= EXPECTED
	print("════════ box-contract: %s ════（断言 %d，红 %d，完成旗=%s）"
			% ["PASS" if ok else "FAIL", _asserts, _fails, str(_finished)])
	get_tree().quit(0 if ok else 1)
