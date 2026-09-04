extends Node2D

## 阴影几何调试覆盖层
## 绘制投影后的 polygon 轮廓（支持 N 顶点）

var _polygon: PackedVector2Array = PackedVector2Array()

func update_polygon(polygon: PackedVector2Array) -> void:
	_polygon = polygon
	queue_redraw()

func _draw() -> void:
	if _polygon.size() < 2:
		return

	for i in range(_polygon.size()):
		var next := (i + 1) % _polygon.size()
		draw_line(_polygon[i], _polygon[next], Color.WHITE, 2.0)

	var colors := [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW,
				   Color.CYAN, Color.MAGENTA, Color.ORANGE, Color.PURPLE]
	for i in range(_polygon.size()):
		draw_circle(_polygon[i], 5.0, colors[i % colors.size()])

	draw_line(Vector2(-15, 0), Vector2(15, 0), Color.WHITE, 2.0)
	draw_line(Vector2(0, -15), Vector2(0, 15), Color.WHITE, 2.0)
