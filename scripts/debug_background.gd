extends CanvasLayer
## 测试场景背景（dev/debug 配套，勿用于正式关卡）
##
## 屏幕空间纵向双色灰渐变：draw_polygon 顶点色插值（真平滑、无 shader、无贴图），
## 叠加一条**世界锚定**的地面参考线（对应 Ground 碰撞面上沿，角色下移的视觉边界）。
## 参考线经视口 get_canvas_transform()（世界→屏幕观察变换）映射后设备像素吸附，
## 线宽 max(1, round(世界宽×zoom))，相机移动时锚定世界位置、厚度恒定。
##
## 由两个 Run Test 生成器模板引用（create_new_character / create_new_spell
## 的 inspector_plugin.gd），模板中本脚本挂在 CanvasLayer 类型节点上。

@export var top_color := Color(0.10, 0.10, 0.12)
@export var bottom_color := Color(0.34, 0.34, 0.37)
@export var ground_line_y := 500.0
@export var ground_line_width := 3.0
@export var ground_line_color := Color(0.62, 0.5, 0.32)

var _view: Node2D


func _ready() -> void:
	layer = -10            # 位于所有世界绘制（含软边贴回 z=-1）之下
	_view = Node2D.new()
	_view.name = "BackgroundView"
	_view.draw.connect(_draw_background)
	add_child(_view)
	get_viewport().size_changed.connect(_view.queue_redraw)


func _process(_delta: float) -> void:
	# 地面参考线世界锚定 → 相机每帧移动都要重算；渐变+1 个矩形，成本可忽略
	_view.queue_redraw()


func _draw_background() -> void:
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
	var line := _ground_line_rect(size)
	if line.size.y > 0.0:
		_view.draw_rect(line, ground_line_color, true)


## 世界 y=ground_line_y 参考线的屏幕矩形（设备像素吸附）；无相机时为空
func _ground_line_rect(size: Vector2) -> Rect2:
	var cam := _view.get_viewport().get_camera_2d()
	if cam == null:
		return Rect2()
	var canvas := _view.get_viewport().get_canvas_transform()
	var center := int(round((canvas * Vector2(0.0, ground_line_y)).y))
	var wpx := maxi(1, int(round(ground_line_width * cam.zoom.x)))
	return Rect2(0, center - wpx / 2, size.x, wpx)
