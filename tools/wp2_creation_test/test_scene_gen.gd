extends SceneTree

## Run Test 编排器纯函数回归（依赖正式对手 spar_enemy 已生成）。
## 运行：godot --headless --path . -s tools/wp2_creation_test/test_scene_gen.gd


func _initialize() -> void:
	var pass_n := 0
	var fail_n := 0
	var checks: Array = []
	
	var fake_scene := "res://tools/wp2_creation_test/_fake_scene_check.tscn"
	var f := FileAccess.open(fake_scene, FileAccess.WRITE)
	f.store_string("""[gd_scene load_steps=2 format=3]
[node name="X" type="CharacterBody2D"]
behavior_mode = 1
""")
	f.close()
	checks.append([
		QuiverRunTestSceneBuilder.scene_behavior_mode(fake_scene) == 1,
		"behavior_mode 解析=1"])
	DirAccess.remove_absolute(fake_scene)
	
	var fake_stage := "\n".join([
		"[gd_scene load_steps=5 format=3]",
		"",
		'[ext_resource type="PackedScene" path="{{CHAR_PATH}}" id="1_character"]',
		'[ext_resource type="PackedScene" path="res://characters/playable/enemy/enemy.tscn" id="3_enemy"]',
		'[ext_resource type="Script" path="res://characters/playable/enemy/enemy_hurt_handler.gd" id="6_hurt_handler"]',
		"",
		'[sub_resource type="Resource" id="test_attack_data"]',
		"attack_damage = 50.0",
		"",
		'[node name="TestStage" type="Node2D"]',
		"",
		'[node name="Enemy" parent="." instance=ExtResource("3_enemy")]',
		"position = Vector2(522, 480)",
		"",
		'[node name="HurtHandler" type="Node" parent="Enemy"]',
		"script = ExtResource(\"6_hurt_handler\")",
		"",
		'[node name="Attack1" parent="Enemy/EnemySkin/Attacks" index="0"]',
		"attack_data = SubResource(\"test_attack_data\")",
		"",
		'[node name="DebugHeightOverlay" type="CanvasLayer" parent="."]',
		'character_path = NodePath("../Character")',
		"",
		'[node name="DebugKnockoutOverlay" type="CanvasLayer" parent="."]',
		'character_path = NodePath("../Character")',
		"",
	])
	var stripped := QuiverRunTestSceneBuilder.strip_enemy_legacy(fake_stage)
	checks.append([not stripped.contains("playable/enemy"), "旧 enemy 引用全部剥离"])
	checks.append([not stripped.contains('[node name="Enemy"'), "Enemy 节点块移除"])
	checks.append([not stripped.contains("HurtHandler"), "HurtHandler 节点块移除"])
	checks.append([not stripped.contains('parent="Enemy/'), "Enemy 内属性覆盖块移除"])
	checks.append([stripped.contains("TestStage"), "宿主节点保留"])
	
	var injected := QuiverRunTestSceneBuilder.inject_actor(
			stripped, "res://characters/enemies/spar/spar.tscn", "Subject", Vector2(522, 480))
	checks.append([injected.contains('path="res://characters/enemies/spar/spar.tscn" id="99_subject"'),
			"被测者 ext_resource 注入"])
	checks.append([injected.contains('[node name="Subject" parent="." instance=ExtResource("99_subject")]'),
			"被测者节点追加"])
	checks.append([injected.find("99_subject") < injected.find("[sub_resource"),
			"ext_resource 位于 sub_resource 之前"])
	
	# compose 编排：非玩家档注入 Subject；玩家档注入正式对手 spar_enemy
	var composed_ai := QuiverRunTestSceneBuilder.compose(
			stripped, "res://characters/enemies/tmp_x/tmp_x.tscn", 1)
	checks.append([composed_ai.contains('name="Subject"') \
			and not composed_ai.contains("spar_enemy"),
			"compose 非玩家档=注入被测者（不叠加对手）"])
	checks.append([composed_ai.count('character_path = NodePath("../Subject")') == 2 \
			and not composed_ai.contains('character_path = NodePath("../Character")'),
			"compose 非玩家档=调试窗口改指被测者（测谁看谁）"])
	checks.append([composed_ai.contains("test_scene_ai_conductor.gd")
			and composed_ai.contains('name="AIConductor"'),
			"compose 非玩家档=自动注入 Enter 发令台"])
	checks.append([composed_ai.find('[node name="Subject"') \
			< composed_ai.find('[node name="DebugHeightOverlay"'),
			"compose 非玩家档=被测者节点排在数据窗口之前（装载可解析）"])
	var hero := QuiverRunTestSceneBuilder.hero_path_for(
			"res://characters/enemies/tmp_x/tmp_x.tscn", 1)
	checks.append([hero.ends_with("chen/chen.tscn"), "compose 非玩家档主角=chen"])
	var composed_player := QuiverRunTestSceneBuilder.compose(
			stripped, "res://characters/playable/chen/chen.tscn", 0)
	checks.append([FileAccess.file_exists(QuiverRunTestSceneBuilder.DEFAULT_OPPONENT),
			"正式对手 spar_enemy 已存在（前置依赖）"])
	checks.append([composed_player.contains('name="Enemy"') \
			and composed_player.contains("spar_enemy/spar_enemy.tscn"),
			"compose 玩家档=注入 spar_enemy 陪练"])
	checks.append([composed_player.count('character_path = NodePath("../Character")') == 2,
			"compose 玩家档=调试窗口保持指被测玩家"])
	checks.append([composed_player.contains('name="AIConductor"'),
			"compose 玩家档=自动注入 Enter 发令台"])
	checks.append([composed_player.find('[node name="Enemy"') \
			< composed_player.find('[node name="DebugHeightOverlay"'),
			"compose 玩家档=陪练节点排在数据窗口之前（装载可解析）"])
	
	for c in checks:
		if c[0]:
			pass_n += 1
			print("  PASS: ", c[1])
		else:
			fail_n += 1
			print("  FAIL: ", c[1])
	
	print("════════ scene-gen: %d PASS / %d FAIL ════════" % [pass_n, fail_n])
	quit(0 if fail_n == 0 else 1)
