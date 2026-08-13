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
	
	# 直接加载单个 Animation 资源文件
	var test_files = [
		["res://characters/playable/chen_jingchou/resources/animations/idle_left.tres", "idle_left"],
		["res://characters/playable/chen_jingchou/resources/animations/attack1_left.tres", "attack1_left"],
		["res://characters/playable/chen_jingchou/resources/animations/jump_left.tres", "jump_left"],
		["res://characters/playable/chen_jingchou/resources/animations/walk_left.tres", "walk_left"],
	]
	var passed := 0
	var failed := 0
	
	for test in test_files:
		var file_path = test[0]
		var anim_name = test[1]
		
		if not FileAccess.file_exists(file_path):
			print("  ✗ 动画文件不存在: %s" % file_path)
			failed += 1
			continue
		
		var anim = load(file_path)
		if not anim:
			print("  ✗ 无法加载动画: %s" % anim_name)
			failed += 1
			continue
		
		var track_count = anim.get_track_count()
		
		# 检查是否包含 height tracks
		var has_physical = false
		var has_attack = false
		var has_method = false
		
		for i in range(track_count):
			var path = str(anim.track_get_path(i))
			var type = anim.track_get_type(i)
			
			if path == "../physical_height" and type == Animation.TYPE_VALUE:
				has_physical = true
			elif path == "../attack_heights" and type == Animation.TYPE_VALUE:
				has_attack = true
			elif path == ".." and type == Animation.TYPE_METHOD:
				has_method = true
		
		var valid = has_physical and has_attack and has_method
		
		if valid:
			passed += 1
			print("  ✓ %s: 验证通过 (%d tracks, 包含 height tracks)" % [anim_name, track_count])
		else:
			failed += 1
			print("  ✗ %s: 验证失败 (%d tracks)" % [anim_name, track_count])
			if not has_physical:
				print("    - 缺少 ../physical_height track")
			if not has_attack:
				print("    - 缺少 ../attack_heights track")
			if not has_method:
				print("    - 缺少 .. method track")
	
	print("动画注入验证: %d 通过, %d 失败\n" % [passed, failed])
