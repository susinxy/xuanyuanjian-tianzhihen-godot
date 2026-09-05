extends Node2D

## 阴影几何调试覆盖层
## 绘制投影后（可能经区域裁剪的多块）polygon 轮廓

var _pieces: Array[PackedVector2Array] = []

func update_polygons(pieces: Array[PackedVector2Array]) -> void:
	_pieces = pieces
	queue_redraw()

func update_polygon(polygon: PackedVector2Array) -> void:
	update_polygons([polygon])

func _draw() -> void:
	var colors := [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW,
				   Color.CYAN, Color.MAGENTA, Color.ORANGE, Color.PURPLE]
	for _poly in _pieces:
		var poly := _poly as PackedVector2Array
		if poly.size() < 2:
			continue
		for i in range(poly.size()):
			var next := (i + 1) % poly.size()
			draw_line(poly[i], poly[next], Color.WHITE, 2.0)
		for i in range(poly.size()):
			draw_circle(poly[i], 5.0, colors[i % colors.size()])

	draw_line(Vector2(-15, 0), Vector2(15, 0), Color.WHITE, 2.0)
	draw_line(Vector2(0, -15), Vector2(0, 15), Color.WHITE, 2.0)
