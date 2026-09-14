extends SceneTree

## Run Test 生成器纯函数回归（两阶段之外的第三组断言）。
## 运行：godot --headless --path . -s tools/wp2_creation_test/test_scene_gen.gd

func _initialize() -> void:
	var pass_n := 0
	var fail_n := 0
	
	# _scene_behavior_mode：从 tscn 文本解析档位
	var fake_scene := "res://tools/wp2_creation_test/_fake_scene_check.tscn"
	var f := FileAccess.open(fake_scene, FileAccess.WRITE)
	f.store_string("""[gd_scene load_steps=2 format=3]
[node name="X" type="CharacterBody2D"]
behavior_mode = 1
""")
	f.close()
	var mode: int = QuiverRunTestSceneBuilder.scene_behavior_mode(fake_scene)
	if mode == 1:
		pass_n += 1
		print("  PASS: behavior_mode 解析=1")
	else:
		fail_n += 1
		print("  FAIL: behavior_mode 解析得 ", mode)
	DirAccess.remove_absolute(fake_scene)
	
	# _attach_nonplayer_subject：剥离旧 enemy 块 + 注入被测者
	var fake_stage := "\n".join([
		"[gd_scene load_steps=5 format=3]",
		"",
		'[ext_resource type="PackedScene" path="{{CHAR_PATH}}" id="1_character"]',
		'[ext_resource type="PackedScene" path="res://characters/playable/enemy/enemy.tscn" id="4_enemy"]',
		'[ext_resource type="Script" path="res://characters/playable/enemy/enemy_periodic_attack.gd" id="5_periodic"]',
		"",
		'[sub_resource type="Resource" id="test_attack_data"]',
		"attack_damage = 50.0",
		"",
		'[node name="TestStage" type="Node2D"]',
		"",
		'[node name="Enemy" parent="." instance=ExtResource("4_enemy")]',
		"position = Vector2(522, 480)",
		"",
		'[node name="Attack1" parent="Enemy/EnemySkin/Attacks" index="0"]',
		"attack_data = SubResource(\"test_attack_data\")",
		"",
		'[node name="PeriodicAttack" type="Node" parent="Enemy"]',
		"facing_direction = -1",
		"",
	])
	var out: String = QuiverRunTestSceneBuilder.attach_nonplayer_subject(
			fake_stage, "res://characters/enemies/spar/spar.tscn")
	var checks := [
		[not out.contains("playable/enemy"), "旧 enemy 引用全部剥离"],
		[not out.contains('[node name="Enemy"'), "Enemy 节点块移除"],
		[not out.contains("PeriodicAttack"), "PeriodicAttack 节点块移除"],
		[not out.contains('parent="Enemy/'), "Enemy 内属性覆盖块移除"],
		[out.contains('path="res://characters/enemies/spar/spar.tscn" id="99_subject"'),
				"被测者 ext_resource 注入"],
		[out.contains('[node name="Subject" parent="." instance=ExtResource("99_subject")]'),
				"被测者节点追加"],
		[out.find("99_subject") < out.find("[sub_resource"),
				"ext_resource 位于 sub_resource 之前"],
		[out.contains("TestStage"), "宿主节点保留"],
	]
	for c in checks:
		if c[0]:
			pass_n += 1
			print("  PASS: ", c[1])
		else:
			fail_n += 1
			print("  FAIL: ", c[1])
	
	print("════════ scene-gen: %d PASS / %d FAIL ════════" % [pass_n, fail_n])
	quit(0 if fail_n == 0 else 1)
