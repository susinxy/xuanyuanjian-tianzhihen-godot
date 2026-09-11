extends CanvasLayer
## 测试场景网格背景（dev/debug 配套，勿用于正式关卡）
##
## 屏幕空间绘制 + 设备像素吸附：每根线把世界坐标经相机变换映射到屏幕后
## 取整到整数设备像素，线宽 = max(1, round(世界线宽 × zoom))。
## 消除世界空间 1px 几何线在相机分数坐标 + 非 1.0 zoom 下的抗锯齿蠕动
## （原"移动时 grid 变形"的根因）。
## 网格保持世界锚定语义：100px 主格仍对应 100 世界像素，格尺功能不失效，
## 单线位置量化误差 ≤0.5px（不可感知）。零 shader、零贴图资产。
##
## 由两个 Run Test 生成器模板引用（create_new_character / create_new_spell
## 的 inspector_plugin.gd），模板中本脚本挂在 CanvasLayer 类型节点上。

@export var grid_size := 100.0
@export var sub_grid_size := 25.0
@export var line_width := 1.0
@export var sub_line_width := 0.5
@export var bg_color := Color(0.6, 0.5, 0.4)
@export var grid_color := Color(0.55, 0.45, 0.35)
@export var sub_grid_color := Color(0.52, 0.42, 0.32)
@export var ground_line_y := 500.0
@export var ground_line_width := 3.0
@export var ground_line_color := Color(0.4, 0.3, 0.2)

var _view: Node2D


func _ready() -> void:
	layer = -10            # 位于所有世界绘制（含软边贴回 z=-1）之下
	_view = Node2D.new()
	_view.name = "GridView"
	_view.draw.connect(_draw_grid)
	add_child(_view)


func _process(_delta: float) -> void:
	# 相机每帧移动 → 每帧重建；~200 个整数像素矩形，成本可忽略
	_view.queue_redraw()


func _draw_grid() -> void:
	var size := _view.get_viewport_rect().size
	_view.draw_rect(Rect2(Vector2.ZERO, size), bg_color, true)
	var cam := _view.get_viewport().get_camera_2d()
	if cam == null:
		return
	var zoom: float = cam.zoom.x
	if zoom <= 0.0001:
		return
	# 注意必须用视口的 canvas transform（世界→屏幕观察变换，由 Camera2D._update_scroll 每帧写入）。
	# cam.get_screen_transform() 是 Node2D 的"本节点在屏幕中的摆放"变换——相机恒居屏幕中心，
	# 那是与相机位置无关的常量，误用会把网格钉死在屏幕上（线"跟着角色走"的根因）。
	var xform := _view.get_viewport().get_canvas_transform()   # 世界坐标 → 屏幕像素
	var inv := xform.affine_inverse()                          # 屏幕 → 世界（求可见范围）
	var w_tl := inv * Vector2.ZERO
	var w_br := inv * size
	
	var sub_wpx: int = _snap_width(sub_line_width, zoom)
	var main_wpx: int = _snap_width(line_width, zoom)
	# 保证主网格线严格比次级粗一档（低 zoom 下 round 后同为 1px 的问题）
	if main_wpx <= sub_wpx:
		main_wpx = sub_wpx + 1
	
	# 次级网格（仅绘制视口可见范围，天然"无限网格"，无需 area 边界）
	for x in _line_range(w_tl.x, w_br.x, sub_grid_size):
		_view.draw_rect(_vline_rect(xform, sub_wpx, x, size), sub_grid_color, true)
	for y in _line_range(w_tl.y, w_br.y, sub_grid_size):
		_view.draw_rect(_hline_rect(xform, sub_wpx, y, size), sub_grid_color, true)
	# 主网格
	for x in _line_range(w_tl.x, w_br.x, grid_size):
		_view.draw_rect(_vline_rect(xform, main_wpx, x, size), grid_color, true)
	for y in _line_range(w_tl.y, w_br.y, grid_size):
		_view.draw_rect(_hline_rect(xform, main_wpx, y, size), grid_color, true)
	# 地面参考线（世界 y 锚定）
	_view.draw_rect(_hline_rect(xform, _snap_width(ground_line_width, zoom), ground_line_y, size), ground_line_color, true)


## 设备像素量化线宽：至少 1px
func _snap_width(world_width: float, zoom: float) -> int:
	return maxi(1, int(round(world_width * zoom)))


## 把世界坐标线映射到屏幕并取整，构造整数边界的 竖直/水平线矩形
## 取整保证线永远占据恒定整数像素行/列 → 消除亚像素抗锯齿抖动
func _vline_rect(xform: Transform2D, wpx: int, world_x: float, size: Vector2) -> Rect2:
	var center := int(round((xform * Vector2(world_x, 0.0)).x))
	var left := center - wpx / 2
	return Rect2(left, 0, wpx, size.y)


func _hline_rect(xform: Transform2D, wpx: int, world_y: float, size: Vector2) -> Rect2:
	var center := int(round((xform * Vector2(0.0, world_y)).y))
	var top := center - wpx / 2
	return Rect2(0, top, size.x, wpx)


## [from, to] 范围内按 step 对齐的世界坐标线序列
func _line_range(from: float, to: float, step: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	if step <= 0.0:
		return out
	var x: float = floor(from / step) * step
	while x <= to:
		out.append(x)
		x += step
	return out
