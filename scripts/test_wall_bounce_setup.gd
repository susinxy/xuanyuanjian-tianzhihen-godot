extends Node

## 墙壁反弹测试设置脚本
##
## 在测试场景启动时自动锁定相机到小区域，验证墙壁反弹功能

func _ready():
	await get_tree().process_frame
	
	var camera = get_node("../Character/LevelCamera")
	if camera:
		camera.delimitate_room(0, -500, 500, 1000, 0.85, 0.0)
		print("[TestSetup] Camera locked to room [0, 500]")
	else:
		push_error("[TestSetup] Camera not found")
