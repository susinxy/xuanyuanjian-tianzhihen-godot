extends Node2D

## 测试场景网格背景（dev/debug 配套，勿用于正式关卡）
## 即时绑定绘制主网格/子网格/地面参考线，替代原 scenes/grid_background.gdshader：
## 零资产文件、随相机 zoom 保持清晰、静态绘制无每帧成本。
## 由两个 Run Test 生成器模板引用（characters/spell 的 inspector_plugin.gd）。

@export var area := Rect2(-2000, -500, 8000, 2500)
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

func _ready() -> void:
	z_index = -10            # 与原 Background ColorRect 同层级（最底）

func _draw() -> void:
	draw_rect(area, bg_color, true)
	var x := _snap(area.position.x, sub_grid_size)
	while x <= area.end.x:
		draw_rect(Rect2(x - sub_line_width * 0.5, area.position.y, sub_line_width, area.size.y), sub_grid_color, true)
		x += sub_grid_size
	var y := _snap(area.position.y, sub_grid_size)
	while y <= area.end.y:
		draw_rect(Rect2(area.position.x, y - sub_line_width * 0.5, area.size.x, sub_line_width), sub_grid_color, true)
		y += sub_grid_size
	x = _snap(area.position.x, grid_size)
	while x <= area.end.x:
		draw_rect(Rect2(x - line_width * 0.5, area.position.y, line_width, area.size.y), grid_color, true)
		x += grid_size
	y = _snap(area.position.y, grid_size)
	while y <= area.end.y:
		draw_rect(Rect2(area.position.x, y - line_width * 0.5, area.size.x, line_width), grid_color, true)
		y += grid_size
	draw_rect(Rect2(area.position.x, ground_line_y - ground_line_width * 0.5, area.size.x, ground_line_width), ground_line_color, true)

func _snap(v: float, step: float) -> float:
	return floor(v / step) * step
