extends CanvasLayer
## 测试场景背景（dev/debug 配套，勿用于正式关卡）
##
## 屏幕空间纵向双色灰渐变：draw_polygon 顶点色插值（单次绘制、真平滑、
## 无网格线、无 shader、无贴图资产）。尺寸变化时自动重绘。
##
## 由两个 Run Test 生成器模板引用（create_new_character / create_new_spell
## 的 inspector_plugin.gd），模板中本脚本挂在 CanvasLayer 类型节点上。

@export var top_color := Color(0.10, 0.10, 0.12)
@export var bottom_color := Color(0.34, 0.34, 0.37)

var _view: Node2D


func _ready() -> void:
	layer = -10            # 位于所有世界绘制（含软边贴回 z=-1）之下
	_view = Node2D.new()
	_view.name = "BackgroundView"
	_view.draw.connect(_draw_gradient)
	add_child(_view)
	get_viewport().size_changed.connect(_view.queue_redraw)


func _draw_gradient() -> void:
	var size := _view.get_viewport_rect().size
	var vertices := PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		size,
		Vector2(0.0, size.y),
	])
	var colors := PackedColorArray([
		top_color, top_color,
		bottom_color, bottom_color,
	])
	_view.draw_polygon(vertices, colors)
