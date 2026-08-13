@tool
extends EditorScript

## Phase 1 验证脚本
## 用法：在 Godot 编辑器中，File > Run > 选择此脚本

func _run() -> void:
	print("=== Phase 1 验证脚本 ===\n")
	
	# 1. 验证文件名解析器
	test_filename_parser()
	
	# 2. 验证动画注入结果
	test_animation_injection()
	
	print("\n=== 验证完成 ===")


func test_filename_parser() -> void:
	print("[1/2] 测试文件名解析器...")
	
	var test_cases := [
		# [文件名, 预期结果]
		["idle_00_physical_180.png", {"physical": 180.0, "attack_heights": [], "speed": null}],
		["punch1_00_physical_180_attack_80.png", {"physical": 180.0, "attack_heights": [80.0], "speed": null}],
		["punch2_01_physical_180_attack_60.png", {"physical": 180.0, "attack_heights": [60.0], "speed": null}],
		["jump_05_speed_-800_physical_180.png", {"physical": 180.0, "attack_heights": [], "speed": -800.0}],
		["turnaround_00_physical_180.png", {"physical": 180.0, "attack_heights": [], "speed": null}],
	]
	
	var passed := 0
	var failed := 0
	
	for i in range(test_cases.size()):
		var test = test_cases[i]
		var filename = test[0]
		var expected = test[1]
		
		var result = CharacterHeightData.parse_height_from_filename(filename)
		
		if result.physical == expected.physical and \
		   result.attack_heights == expected.attack_heights and \
		   result.speed == expected.speed:
			passed += 1
			print("  ✓ 测试 %d: %s" % [i + 1, filename])
		else:
			failed += 1
			print("  ✗ 测试 %d: %s" % [i + 1, filename])
			print("    预期: %s" % str(expected))
			print("    实际: %s" % str(result))
	
	print("文件名解析器: %d 通过, %d 失败\n" % [passed, failed])


func test_animation_injection() -> void:
	print("[2/2] 验证动画注入结果...")
	
	var anim_library_path = "res://characters/playable/chen_jingchou/resources/animations/library.tres"
	
	if not FileAccess.file_exists(anim_library_path):
		print("  ✗ 动画库文件不存在: %s" % anim_library_path)
		return
	
	var library = load(anim_library_path)
	if not library:
		print("  ✗ 无法加载动画库")
		return
	
	var test_anims = ["idle_left", "attack1_left", "jump_left", "hurt_mid_left"]
	var passed := 0
	var failed := 0
	
	for anim_name in test_anims:
		var anim = library.get_animation(anim_name)
		if not anim:
			print("  ✗ 动画不存在: %s" % anim_name)
			failed += 1
			continue
		
		var track_count = anim.get_track_count()
		var expected_tracks = 16  # 原有的 + 3 个新增
		
		if track_count != expected_tracks:
			print("  ✗ %s: track 数量错误 (预期 %d, 实际 %d)" % [anim_name, expected_tracks, track_count])
			failed += 1
			continue
		
		# 验证新增 tracks 的路径和方法
		var valid := true
		var errors := []
		
		# Track 13: physical_height (value track)
		var track_13_path = anim.track_get_path(13)
		var track_13_type = anim.track_get_type(13)
		if track_13_type != Animation.TYPE_VALUE:
			valid = false
			errors.append("track 13 不是 value track (实际: %d)" % track_13_type)
		elif track_13_path != NodePath("../physical_height"):
			valid = false
			errors.append("track 13 path 错误: %s" % str(track_13_path))
		
		# Track 14: attack_heights (value track)
		var track_14_path = anim.track_get_path(14)
		var track_14_type = anim.track_get_type(14)
		if track_14_type != Animation.TYPE_VALUE:
			valid = false
			errors.append("track 14 不是 value track (实际: %d)" % track_14_type)
		elif track_14_path != NodePath("../attack_heights"):
			valid = false
			errors.append("track 14 path 错误: %s" % str(track_14_path))
		
		# Track 15: method track
		var track_15_path = anim.track_get_path(15)
		var track_15_type = anim.track_get_type(15)
		if track_15_type != Animation.TYPE_METHOD:
			valid = false
			errors.append("track 15 不是 method track (实际: %d)" % track_15_type)
		elif track_15_path != NodePath(".."):
			valid = false
			errors.append("track 15 path 错误: %s" % str(track_15_path))
		else:
			# 检查 method track 是否有 key
			var key_count = anim.track_get_key_count(15)
			if key_count == 0:
				valid = false
				errors.append("track 15 没有 key")
			else:
				# 获取第一个 key 的值
				var first_key = anim.track_get_key_value(15, 0)
				if first_key.get("method", "") != "_sync_base_height":
					valid = false
					errors.append("track 15 method 错误: %s" % str(first_key))
		
		if valid:
			passed += 1
			print("  ✓ %s: 验证通过 (16 tracks, 包含 height tracks)" % anim_name)
		else:
			failed += 1
			print("  ✗ %s: 验证失败" % anim_name)
			for err in errors:
				print("    - %s" % err)
	
	print("动画注入验证: %d 通过, %d 失败\n" % [passed, failed])
