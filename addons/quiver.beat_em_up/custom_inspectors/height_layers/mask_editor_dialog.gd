@tool
extends AcceptDialog
## Mask 编辑器对话框
##
## 在精灵图片上绘制 mask，用于限制轮廓提取区域。
## 保存为 .mask.png 文件，与原始 PNG 同目录。
##
## 工作流程：
## 1. 加载原始 PNG 作为底图
## 2. 如果已有 .mask.png，自动加载
## 3. 鼠标绘制/擦除 mask
## 4. 实时预览轮廓效果
## 5. 保存为 .mask.png

const ContourTracer = preload(
	"res://addons/quiver.beat_em_up/custom_inspectors/height_layers/contour_tracer.gd"
)

var _png_path: String = ""
var _mask_path: String = ""
var _alpha_threshold: float = 0.5
var _simplify_tolerance: float = 2.0
var _min_area_ratio: float = 0.3

var _original_image: Image = null
var _mask_image: Image = null

var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _bg_texture_rect: TextureRect
var _mask_texture_rect: TextureRect
var _brush_preview: Node2D

var _tool_panel: VBoxContainer
var _file_label: Label
var _mask_type_option: OptionButton
var _brush_size_spinbox: SpinBox
var _is_eraser: bool = false
var _brush_button: Button
var _eraser_button: Button
var _preview_contour_btn: Button
var _preview_texture: TextureRect
var _save_btn: Button
var _clear_btn: Button
var _status_label: Label

var _is_drawing: bool = false
var _last_draw_pos: Vector2 = Vector2.ZERO
var _brush_position: Vector2 = Vector2.ZERO
var _zoom_level: float = 1.0


func _ready() -> void:
	title = "🎨 Mask 编辑器"
	_build_ui()
	if not _png_path.is_empty():
		_load_images()


func set_png_path(path: String) -> void:
	_png_path = path
	_update_mask_path()
	
	if _file_label != null:
		_file_label.text = "文件: %s" % path.get_file()
		_load_images()


func _update_mask_path() -> void:
	if _png_path.is_empty():
		_mask_path = ""
		return
	
	var base_path := _png_path.replace(".png", "")
	var selected_id := 0
	if _mask_type_option != null:
		selected_id = _mask_type_option.get_selected_id()
	
	match selected_id:
		1:  # Body
			_mask_path = base_path + ".body.mask.png"
		2:  # Attack
			_mask_path = base_path + ".attack.mask.png"
		_:  # 通用
			_mask_path = base_path + ".mask.png"


func set_params(alpha: float, tolerance: float, min_area_ratio: float) -> void:
	_alpha_threshold = alpha
	_simplify_tolerance = tolerance
	_min_area_ratio = min_area_ratio


func _build_ui() -> void:
	var hsplit := HSplitContainer.new()
	add_child(hsplit)
	
	# 左侧：画布区域
	var canvas_container := VBoxContainer.new()
	canvas_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.add_child(canvas_container)
	
	# SubViewportContainer
	_viewport_container = SubViewportContainer.new()
	_viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport_container.stretch = true
	_viewport_container.gui_input.connect(_on_canvas_gui_input)
	_viewport_container.mouse_entered.connect(_on_canvas_mouse_entered)
	_viewport_container.mouse_exited.connect(_on_canvas_mouse_exited)
	canvas_container.add_child(_viewport_container)
	
	# SubViewport
	_viewport = SubViewport.new()
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport_container.add_child(_viewport)
	
	# 底图
	_bg_texture_rect = TextureRect.new()
	_viewport.add_child(_bg_texture_rect)
	
	# Mask 叠加层
	_mask_texture_rect = TextureRect.new()
	_mask_texture_rect.modulate = Color(1, 0.3, 0.3, 0.5)
	_viewport.add_child(_mask_texture_rect)
	
	# 笔刷预览
	_brush_preview = Node2D.new()
	_brush_preview.draw.connect(_on_brush_preview_draw)
	_viewport.add_child(_brush_preview)
	
	# 缩放控制
	var zoom_row := HBoxContainer.new()
	canvas_container.add_child(zoom_row)
	
	var zoom_out_btn := Button.new()
	zoom_out_btn.text = "-"
	zoom_out_btn.pressed.connect(_on_zoom_out)
	zoom_row.add_child(zoom_out_btn)
	
	var zoom_label := Label.new()
	zoom_label.text = "100%"
	zoom_label.name = "ZoomLabel"
	zoom_row.add_child(zoom_label)
	
	var zoom_in_btn := Button.new()
	zoom_in_btn.text = "+"
	zoom_in_btn.pressed.connect(_on_zoom_in)
	zoom_row.add_child(zoom_in_btn)
	
	# 右侧：工具面板
	_tool_panel = VBoxContainer.new()
	_tool_panel.custom_minimum_size.x = 180
	hsplit.add_child(_tool_panel)
	
	# 文件名
	_file_label = Label.new()
	_file_label.text = "文件: (未选择)"
	_file_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_tool_panel.add_child(_file_label)
	
	# Mask 类型选择
	var type_label := Label.new()
	type_label.text = "Mask 类型:"
	_tool_panel.add_child(type_label)
	
	_mask_type_option = OptionButton.new()
	_mask_type_option.add_item("通用", 0)
	_mask_type_option.add_item("Body", 1)
	_mask_type_option.add_item("Attack", 2)
	_mask_type_option.select(0)
	_mask_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mask_type_option.item_selected.connect(_on_mask_type_changed)
	_tool_panel.add_child(_mask_type_option)
	
	_tool_panel.add_child(HSeparator.new())
	
	# 工具标签
	var tool_label := Label.new()
	tool_label.text = "工具"
	tool_label.add_theme_font_size_override("font_size", 14)
	_tool_panel.add_child(tool_label)
	
	# 画笔/橡皮擦按钮
	var tool_btn_row := HBoxContainer.new()
	_tool_panel.add_child(tool_btn_row)
	
	_brush_button = Button.new()
	_brush_button.text = "🖌 画笔"
	_brush_button.toggle_mode = true
	_brush_button.button_pressed = true
	_brush_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_brush_button.pressed.connect(_on_brush_pressed)
	tool_btn_row.add_child(_brush_button)
	
	_eraser_button = Button.new()
	_eraser_button.text = "🧹 橡皮"
	_eraser_button.toggle_mode = true
	_eraser_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_eraser_button.pressed.connect(_on_eraser_pressed)
	tool_btn_row.add_child(_eraser_button)
	
	_tool_panel.add_child(HSeparator.new())
	
	# 画笔大小
	var size_label := Label.new()
	size_label.text = "画笔大小:"
	_tool_panel.add_child(size_label)
	
	_brush_size_spinbox = SpinBox.new()
	_brush_size_spinbox.min_value = 5
	_brush_size_spinbox.max_value = 100
	_brush_size_spinbox.step = 5
	_brush_size_spinbox.value = 20
	_brush_size_spinbox.suffix = " px"
	_brush_size_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tool_panel.add_child(_brush_size_spinbox)
	
	_tool_panel.add_child(HSeparator.new())
	
	# 预览轮廓按钮
	_preview_contour_btn = Button.new()
	_preview_contour_btn.text = "🔍 预览轮廓"
	_preview_contour_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_contour_btn.pressed.connect(_on_preview_contour_pressed)
	_tool_panel.add_child(_preview_contour_btn)
	
	# 轮廓预览图
	_preview_texture = TextureRect.new()
	_preview_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_texture.custom_minimum_size = Vector2(0, 120)
	_tool_panel.add_child(_preview_texture)
	
	_tool_panel.add_child(HSeparator.new())
	
	# 保存/清除按钮
	_save_btn = Button.new()
	_save_btn.text = "💾 保存 Mask"
	_save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_btn.pressed.connect(_on_save_pressed)
	_tool_panel.add_child(_save_btn)
	
	_clear_btn = Button.new()
	_clear_btn.text = "🗑 清除 Mask"
	_clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clear_btn.pressed.connect(_on_clear_pressed)
	_tool_panel.add_child(_clear_btn)
	
	# 状态标签
	_status_label = Label.new()
	_status_label.text = "就绪"
	_status_label.add_theme_color_override("font_color", Color.GRAY)
	_tool_panel.add_child(_status_label)


func _load_images() -> void:
	if _png_path.is_empty():
		return
	
	# 加载原始图片
	_original_image = Image.load_from_file(ProjectSettings.globalize_path(_png_path))
	if _original_image == null:
		_status_label.text = "错误: 无法加载图片"
		_status_label.add_theme_color_override("font_color", Color.RED)
		return
	
	var img_w := _original_image.get_width()
	var img_h := _original_image.get_height()
	
	# 设置 viewport 尺寸
	_viewport.size = Vector2i(img_w, img_h)
	
	# 设置底图
	_bg_texture_rect.texture = ImageTexture.create_from_image(_original_image)
	_bg_texture_rect.size = Vector2(img_w, img_h)
	
	# 加载或创建 mask
	if FileAccess.file_exists(_mask_path):
		_mask_image = Image.load_from_file(ProjectSettings.globalize_path(_mask_path))
		if _mask_image.get_width() != img_w or _mask_image.get_height() != img_h:
			_mask_image.resize(img_w, img_h, Image.INTERPOLATE_LANCZOS)
		_status_label.text = "已加载现有 mask"
		_status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		_mask_image = Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)
		_status_label.text = "新建 mask (透明)"
		_status_label.add_theme_color_override("font_color", Color.CYAN)
	
	_update_mask_display()


func _update_mask_display() -> void:
	if _mask_image == null:
		return
	_mask_texture_rect.texture = ImageTexture.create_from_image(_mask_image)
	_mask_texture_rect.size = Vector2(_mask_image.get_width(), _mask_image.get_height())


## 将 SubViewportContainer 坐标转换为 SubViewport/图片坐标
func _container_to_image_pos(container_pos: Vector2) -> Vector2:
	var container_size := Vector2(_viewport_container.size)
	var viewport_size := Vector2(_viewport.size)
	if container_size.x == 0 or container_size.y == 0:
		return container_pos
	return container_pos * viewport_size / container_size


func _on_canvas_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_drawing = event.pressed
			if event.pressed:
				_last_draw_pos = _container_to_image_pos(event.position)
				_draw_at(_last_draw_pos)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# 右键 = 临时切换橡皮擦
			var was_eraser := _is_eraser
			_is_eraser = event.pressed
			if event.pressed:
				_is_drawing = true
				_last_draw_pos = _container_to_image_pos(event.position)
				_draw_at(_last_draw_pos)
			else:
				_is_drawing = false
				_is_eraser = was_eraser
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_on_zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_on_zoom_out()
	
	elif event is InputEventMouseMotion:
		_brush_position = _container_to_image_pos(event.position)
		_brush_preview.queue_redraw()
		
		if _is_drawing:
			var current_pos: Vector2 = _container_to_image_pos(event.position)
			_draw_line(_last_draw_pos, current_pos)
			_last_draw_pos = current_pos


func _draw_at(pos: Vector2) -> void:
	if _mask_image == null:
		return
	
	var radius := _brush_size_spinbox.value / 2.0
	var color := Color(1, 1, 1, 1) if not _is_eraser else Color(0, 0, 0, 0)
	
	var center_x := int(pos.x)
	var center_y := int(pos.y)
	var r := int(radius)
	
	for y in range(center_y - r, center_y + r + 1):
		for x in range(center_x - r, center_x + r + 1):
			if x < 0 or x >= _mask_image.get_width():
				continue
			if y < 0 or y >= _mask_image.get_height():
				continue
			if Vector2(x, y).distance_to(pos) <= radius:
				_mask_image.set_pixel(x, y, color)
	
	_update_mask_display()


func _draw_line(from: Vector2, to: Vector2) -> void:
	var distance := from.distance_to(to)
	var steps := int(distance / 2.0) + 1
	
	for i in range(steps):
		var t := float(i) / float(steps)
		var pos := from.lerp(to, t)
		_draw_at(pos)


func _on_canvas_mouse_entered() -> void:
	_brush_preview.visible = true


func _on_canvas_mouse_exited() -> void:
	_brush_preview.visible = false
	_is_drawing = false


func _on_brush_preview_draw() -> void:
	var radius := _brush_size_spinbox.value / 2.0
	var color := Color(0, 1, 0, 0.5) if not _is_eraser else Color(1, 0, 0, 0.5)
	_brush_preview.draw_arc(_brush_position, radius, 0, TAU, 32, color, 2.0)


func _on_brush_pressed() -> void:
	_is_eraser = false
	_brush_button.button_pressed = true
	_eraser_button.button_pressed = false


func _on_eraser_pressed() -> void:
	_is_eraser = true
	_brush_button.button_pressed = false
	_eraser_button.button_pressed = true


func _on_zoom_in() -> void:
	_zoom_level = min(_zoom_level * 1.25, 4.0)
	_apply_zoom()


func _on_zoom_out() -> void:
	_zoom_level = max(_zoom_level / 1.25, 0.25)
	_apply_zoom()


func _apply_zoom() -> void:
	_viewport_container.stretch_shrink = 1.0 / _zoom_level
	
	var zoom_label := _tool_panel.get_node_or_null("ZoomLabel") as Label
	if zoom_label == null:
		zoom_label = _viewport_container.get_parent().find_child("ZoomLabel", true, false)
	if zoom_label != null:
		zoom_label.text = "%d%%" % int(_zoom_level * 100)


func _on_preview_contour_pressed() -> void:
	if _original_image == null or _mask_image == null:
		return
	
	_preview_contour_btn.disabled = true
	_status_label.text = "预览中..."
	_status_label.add_theme_color_override("font_color", Color.CYAN)
	
	# 使用 mask 提取轮廓
	var contours := ContourTracer.trace_contours(
		_original_image, _mask_image, _alpha_threshold, _simplify_tolerance, 512, _min_area_ratio
	)
	
	if contours.is_empty():
		_preview_texture.texture = null
		_status_label.text = "未提取到轮廓"
		_status_label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		# 生成预览图
		var preview := _generate_preview(_original_image, contours)
		_preview_texture.texture = preview
		
		var total_vertices := 0
		for contour in contours:
			total_vertices += contour.size()
		_status_label.text = "轮廓: %d 个, %d 顶点" % [contours.size(), total_vertices]
		_status_label.add_theme_color_override("font_color", Color.GREEN)
	
	_preview_contour_btn.disabled = false


func _generate_preview(image: Image, contours: Array[PackedVector2Array]) -> ImageTexture:
	var img_w := image.get_width()
	var img_h := image.get_height()
	
	var preview_image := image.duplicate()
	
	# 在预览图上绘制轮廓
	for contour in contours:
		if contour.size() < 3:
			continue
		
		# 绘制红色边线
		for i in range(contour.size()):
			var from := contour[i]
			var to := contour[(i + 1) % contour.size()]
			_draw_line_on_image(preview_image, from, to, Color(1, 0, 0, 1))
	
	return ImageTexture.create_from_image(preview_image)


func _draw_line_on_image(image: Image, from: Vector2, to: Vector2, color: Color) -> void:
	var distance := from.distance_to(to)
	var steps := int(distance) + 1
	
	for i in range(steps):
		var t := float(i) / float(steps)
		var pos := from.lerp(to, t)
		var x := int(pos.x)
		var y := int(pos.y)
		if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
			image.set_pixel(x, y, color)


func _on_save_pressed() -> void:
	if _mask_image == null:
		return
	
	var global_path := ProjectSettings.globalize_path(_mask_path)
	var err := _mask_image.save_png(global_path)
	
	if err == OK:
		_status_label.text = "✅ 已保存: %s" % _mask_path.get_file()
		_status_label.add_theme_color_override("font_color", Color.GREEN)
		
		# 刷新文件系统
		EditorInterface.get_resource_filesystem().scan()
	else:
		_status_label.text = "❌ 保存失败 (error=%d)" % err
		_status_label.add_theme_color_override("font_color", Color.RED)


func _on_clear_pressed() -> void:
	if _mask_image == null or _original_image == null:
		return
	
	_mask_image.fill(Color(0, 0, 0, 0))
	_update_mask_display()
	_preview_texture.texture = null
	_status_label.text = "Mask 已清除"
	_status_label.add_theme_color_override("font_color", Color.CYAN)


func _on_mask_type_changed(_idx: int) -> void:
	_update_mask_path()
	if not _png_path.is_empty():
		_load_images()
