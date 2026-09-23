extends Node

## WP2 断言集（两阶段，中间需由 shell 跑一次 --import 导入新建角色的图片资源）：
##   godot --headless --path . res://tools/wp2_creation_test/wp2_runner.tscn -- --phase=create
##   godot --headless --path . --import
##   godot --headless --path . res://tools/wp2_creation_test/wp2_runner.tscn -- --phase=verify
## 验证：三档位创建、阵营包目录、行为档写入、小抄约定加载、AI 追打、被动站桩。
## 主权迁移（B2.5 Task4）：组3 玩家身体从活体 chen 换成矩阵替身 test_actor
## （本组只需要一个玩家档身体挨打/被追）；组1/组2 是创建产线自证（tmp_* 临时
## 角色），从不绑 chen。本套走两阶段 shell 手动跑、不在矩阵名册，无需 ATTEST。

const TMP_CHARS := [
	{"name": "tmp_wp_player", "pkg": "playable", "mode": 0, "tags": "player, tmp_team",
	"pascal": "TmpWpPlayer", "display": "临时玩家",
	# 特征出生值（面板=唯一真相批）：非默认值逐行落盘核对，专杀静默空转
	"stats": {"health_max": 77.0, "mana_max": 33.0, "knockout_resistance_max": 900.0,
		"move_speed": 501.0, "walk_speed": 201.0, "air_control": 0.42,
		"jump_force": -1500.0, "knockback_weight": 2.5, "hit_lane_offset": 7.0,
		"can_be_grabbed": true, "is_invulnerable": false, "has_superarmor": false},
	"attacks": [
		{"attack_damage": 7.0, "hurt_type": 0, "knock_strength": 300.0, "launch_angle": 60.0},
		{"attack_damage": 8.0, "hurt_type": 1, "knock_strength": 100.0, "launch_angle": 20.0},
		{"attack_damage": 9.0, "hurt_type": 0, "knock_strength": 200.0, "launch_angle": 40.0},
		{"attack_damage": 11.0, "hurt_type": 1, "knock_strength": 400.0, "launch_angle": 80.0}],
	"expect_attrs": ["health_max = 77", "mana_max = 33", "knockout_resistance_max = 900",
		"move_speed = 501", "walk_speed = 201", "air_control = 0.42",
		"jump_force = -1500", "knockback_weight = 2.5", "hit_lane_offset = 7",
		"can_be_grabbed = true", "is_invulnerable = false", "has_superarmor = false"],
	"expect_punch1": ["attack_damage = 7", "hurt_type = 0", "knock_strength = 300", "launch_angle = 60"]},
	{"name": "tmp_wp_enemy", "pkg": "enemies", "mode": 1, "tags": "enemy",
	"pascal": "TmpWpEnemy", "display": "临时敌人"},
	{"name": "tmp_wp_vendor", "pkg": "neutrals", "mode": 2, "tags": "tmp_wp_vendor",
	"pascal": "TmpWpVendor", "display": "临时小贩"},
]

const Kit := preload("res://tools/matrix_runner/test_actor_kit.gd")

var _pass := 0
var _fail := 0
var _fail_names: Array[String] = []


func _check(ok: bool, name: String) -> void:
	if ok:
		_pass += 1
		print("  PASS: ", name)
	else:
		_fail += 1
		_fail_names.append(name)
		print("  FAIL: ", name)


func _tick(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func _phase() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):
			return arg.trim_prefix("--phase=")
	return ""


func _ready() -> void:
	match _phase():
		"create":
			_create_phase()
		"verify":
			await _verify_phase()
			_cleanup()
		_:
			push_error("用法: --phase=create|verify")
			get_tree().quit(2)
			return
	print("════════ %s: %d PASS / %d FAIL ════════" % [_phase(), _pass, _fail])
	if _fail > 0:
		print("失败项: ", _fail_names)
	get_tree().quit(0 if _fail == 0 else 1)


func _scene_path(spec: Dictionary) -> String:
	return "res://characters/%s/%s/%s.tscn" % [spec.pkg, spec.name, spec.name]


func _create_phase() -> void:
	print("════ 组0：自愈清理残留 ════")
	_cleanup()
	
	print("════ 组1：三档位创建 ════")
	var creator := CharacterCreator.new()
	for spec in TMP_CHARS:
		var ok := creator.create_character(
				spec.name, spec.pascal, spec.display, spec.tags,
				spec.get("stats", {}), spec.get("attacks", []), spec.mode)
		_check(ok, "创建 %s 返回成功" % spec.name)
	
	print("════ 组2：文件层断言 ════")
	for spec in TMP_CHARS:
		var sp := _scene_path(spec)
		_check(FileAccess.file_exists(sp), "%s 主场景在阵营包 %s/ 下" % [spec.name, spec.pkg])
		var text := FileAccess.get_file_as_string(sp)
		_check(text.contains("behavior_mode = %d" % spec.mode), "%s 行为档=%d" % [spec.name, spec.mode])
		var first_tag := String(spec.tags).split(",")[0].strip_edges()
		_check(text.contains('groups=["area2d:%s"' % first_tag), \
				"%s 根节点首阵营标签=area2d:%s" % [spec.name, first_tag])
		_check(not text.contains('groups=["area2d:player"]') or spec.name == "tmp_wp_player", \
				"%s 无标签串台" % spec.name)
		if spec.tags.contains(","):
			_check(text.contains('"area2d:tmp_team"'), \
					"%s 多标签展开到位（player, tmp_team 并列）" % spec.name)
		# —— 出生数值合成落盘断言（2026-09-18 面板=唯一真相批）——
		var syn_attrs := FileAccess.get_file_as_string(
				"res://characters/%s/%s/resources/%s_attributes.tres" % [spec.pkg, spec.name, spec.name])
		var expect_attrs: Array = spec.get("expect_attrs", [
				"health_max = 100", "mana_max = 100", "knockout_resistance_max = 600",
				"move_speed = 600", "walk_speed = 300", "air_control = 0.6",
				"jump_force = -1200", "knockback_weight = 1", "hit_lane_offset = 0",
				"can_be_grabbed = false"])
		for line in expect_attrs:
			_check(syn_attrs.contains("\n" + line + "\n"),
					"%s attributes 行: %s" % [spec.name, line])
		for slot in ["punch1", "punch2", "punch3", "air_kick"]:
			_check(FileAccess.file_exists(
					"res://characters/%s/%s/resources/attacks/%s_attack_data.tres" % [spec.pkg, spec.name, slot]),
					"%s 招式 %s 已合成" % [spec.name, slot])
		var syn_p1 := FileAccess.get_file_as_string(
				"res://characters/%s/%s/resources/attacks/punch1_attack_data.tres" % [spec.pkg, spec.name])
		for line in spec.get("expect_punch1", ["attack_damage = 10", "knock_strength = 60", "hurt_type = 1", "launch_angle = 15"]):
			_check(syn_p1.contains("\n" + line + "\n"),
					"%s punch1 行: %s" % [spec.name, line])
		var ai_path := sp.trim_suffix(".tscn") + "_ai.gd"
		_check(FileAccess.file_exists(ai_path), "%s 默认小抄存在" % spec.name)
		_check(not text.contains("__"), "%s 主场景无占位符残留" % spec.name)
		var ai_text := FileAccess.get_file_as_string(ai_path)
		_check(ai_text.contains("class_name %sAI" % spec.pascal), "%s 小抄类名正确" % spec.name)
		_check(not ai_text.contains("__NAME__") and not ai_text.contains("__CLASS__"), \
				"%s 小抄无占位符残留" % spec.name)
		_check(FileAccess.file_exists(sp.trim_suffix(".tscn") + ".gd"), "%s 根脚本存在" % spec.name)
		_check(FileAccess.file_exists("res://characters/%s/%s/resources/%s_attributes.tres" % [
				spec.pkg, spec.name, spec.name]), "%s 属性资源存在" % spec.name)
		var attrs_display := FileAccess.get_file_as_string("res://characters/%s/%s/resources/%s_attributes.tres" % [
				spec.pkg, spec.name, spec.name])
		_check(attrs_display.contains('display_name = "%s"' % spec.display) \
				and not attrs_display.contains("陈靖仇"),
				"%s 显示名=表单填写值（占位符链闭环）" % spec.name)
		var tree_txt := FileAccess.get_file_as_string("res://characters/%s/%s/resources/animations/animation_tree_root.tres" % [
				spec.pkg, spec.name])
		_check(tree_txt.contains("blend_spell_start") and tree_txt.contains("blend_spelling"),
				"%s 出生即带 spell_start+spelling 两槽（模板继承）" % spec.name)


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


func _verify_phase() -> void:
	print("════ 组3：场景行为层 ════")
	if not _guard_actor():
		return
	var actor: QuiverCharacter = load(Kit.ACTOR_SCENE).instantiate()
	actor.position = Vector2(200, 400)
	add_child(actor)
	var enemy: QuiverCharacter = load(_scene_path(TMP_CHARS[1])).instantiate()
	enemy.position = Vector2(700, 400)
	add_child(enemy)
	var vendor: QuiverCharacter = load(_scene_path(TMP_CHARS[2])).instantiate()
	vendor.position = Vector2(400, 500)
	add_child(vendor)
	await _tick(6)
	
	await _tick(2)
	# 阵营下发核心断言：配对取【攻击盒×受击盒】的游戏真实形态。
	# （历史备案：旧 area2d:wall 伪阵营时代两只受击盒互比会假判同阵营；
	# 2026-09-19 弹墙改 in_knockout 状态门后 wall 组全库灭绝，该坑源头不存在，
	# 但攻击盒×受击盒仍是玩法真实配对，取样纪律保留。）
	var tagged := 0
	var actor_hurt: Area2D = null
	var actor_hit: Area2D = null
	for a2 in actor.find_children("*", "Area2D", true):
		if a2.is_in_group("area2d:player"):
			tagged += 1
			if a2 is QuiverHurtBox and actor_hurt == null:
				actor_hurt = a2
			if a2 is QuiverHitBox and actor_hit == null:
				actor_hit = a2
	_check(tagged >= 5, "替身根标签运行时下发到全部战斗盒（命中 %d 只）" % tagged)
	_check(actor_hurt != null and actor_hit != null, "替身受击/攻击盒分类取到")
	var enemy_hit: Area2D = null
	for a3 in enemy.find_children("*", "Area2D", true):
		if a3 is QuiverHitBox and a3.is_in_group("area2d:enemy"):
			enemy_hit = a3
	_check(enemy_hit != null, "enemy 攻击盒标签下发到位")
	if actor_hurt != null and actor_hit != null and enemy_hit != null:
		_check(not QuiverHurtBox.are_factions_equal(enemy_hit, actor_hurt),
				"enemy 拳 × player 身 = 敌对可打（交集空）")
		_check(QuiverHurtBox.are_factions_equal(actor_hit, actor_hurt),
				"自己的拳 × 自己的身 = 同标签互免（打不到自己）")
	
	var enemy_script: Script = enemy.behavior.get_script() if enemy.behavior != null else null
	_check(enemy_script != null \
			and String(enemy_script.resource_path).ends_with("tmp_wp_enemy_ai.gd"), \
			"AI 档按约定加载了自家小抄")
	_check(vendor.behavior is QuiverBehaviorIdle, "被动档挂零写入行为")
	_check(actor.behavior is QuiverBehaviorPlayer, "玩家档行为完好")
	
	var dist_start: float = enemy.global_position.distance_to(actor.global_position)
	var vendor_pos := vendor.global_position
	# 小抄循环：歇1s → 追击；观察 120 物理帧
	await _tick(120)
	var dist_end: float = enemy.global_position.distance_to(actor.global_position)
	_check(dist_end < dist_start - 40.0, \
			"AI 敌人向玩家逼近（%f→%f px）" % [dist_start, dist_end])
	_check(vendor_pos.distance_to(vendor.global_position) < 1.0, "被动角色 120 帧零位移")
	_check(actor.attributes.health_current < actor.attributes.health_max \
			or String(enemy.state_machine.state_name).contains("Attack") \
			or String(enemy.state_machine.state_name).contains("Combo"), \
			"AI 接敌后发动攻击（替身当前血量 %f）" % actor.attributes.health_current)


func _cleanup() -> void:
	for spec in TMP_CHARS:
		var dir_path := "res://characters/%s/%s" % [spec.pkg, spec.name]
		if DirAccess.dir_exists_absolute(dir_path):
			var deleter := CharacterDeleter.new()
			deleter.delete_character(spec.name, spec.pkg)
