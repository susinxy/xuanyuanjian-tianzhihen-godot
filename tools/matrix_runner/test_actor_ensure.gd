extends SceneTree
## `-s` 入口：调 TestActorKit.ensure() 并按三态契约给 shell 回退出码。
## 退出码（run_matrix.sh 消费）：
## 0 = 就绪；42 = NEEDS_IMPORT（须 `godot --headless --import` 后重开进程再调）；
## 1 = 产线创建失败（诊断见 stderr）。

const Kit := preload("res://tools/matrix_runner/test_actor_kit.gd")


func _initialize() -> void:
	var code: int = Kit.ensure()
	print("[test_actor_ensure] ensure() -> %d" % code)
	if code == OK:
		quit(0)
	elif code == Kit.NEEDS_IMPORT:
		quit(Kit.NEEDS_IMPORT)
	else:
		quit(1)
