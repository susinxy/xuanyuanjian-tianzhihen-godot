extends Node2D

## 阴影几何调试覆盖层
## 独立的 Node2D，通过 _draw() 绘制阴影平行四边形的几何体
## 作为 ShadowRenderer (Sprite2D) 的子节点，z_index=1 确保在 shader 之上显示

var _vertices: PackedVector2Array = PackedVector2Array()

func update_vertices(v0: Vector2, v1: Vector2, v2: Vector2, v3: Vector2) -> void:
	_vertices = PackedVector2Array([v0, v1, v2, v3])
	queue_redraw()

func _draw() -> void:
	if _vertices.size() != 4:
		return

	draw_line(_vertices[0], _vertices[1], Color.WHITE, 2.0)
	draw_line(_vertices[1], _vertices[2], Color.WHITE, 2.0)
	draw_line(_vertices[2], _vertices[3], Color.WHITE, 2.0)
	draw_line(_vertices[3], _vertices[0], Color.WHITE, 2.0)

	draw_circle(_vertices[0], 8.0, Color.RED)
	draw_circle(_vertices[1], 8.0, Color.GREEN)
	draw_circle(_vertices[2], 8.0, Color.BLUE)
	draw_circle(_vertices[3], 8.0, Color.YELLOW)

	draw_line(Vector2(-15, 0), Vector2(15, 0), Color.WHITE, 2.0)
	draw_line(Vector2(0, -15), Vector2(0, 15), Color.WHITE, 2.0)
