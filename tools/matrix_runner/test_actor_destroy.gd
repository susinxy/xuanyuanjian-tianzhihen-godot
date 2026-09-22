extends SceneTree
## `-s` 入口：调 TestActorKit.destroy()（真实产线递归删除 test_actor）。幂等。
## 退出码：0 = 已删除或本就不存在；1 = 删除失败。

const Kit := preload("res://tools/matrix_runner/test_actor_kit.gd")


func _initialize() -> void:
	var code: int = Kit.destroy()
	print("[test_actor_destroy] destroy() -> %d" % code)
	quit(0 if code == OK else 1)
