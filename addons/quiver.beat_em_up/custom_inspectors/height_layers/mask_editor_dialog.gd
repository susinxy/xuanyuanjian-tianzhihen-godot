@tool
extends AcceptDialog
## Mask 编辑器对话框
##
## 在精灵图片上绘制 mask，用于限制轮廓提取区域。
##
## 两种模式（自动判定，对使用者透明）：
## - 母版模式：该图在母版目录（sprites_master/，与缩放面板同源配置）存在原画 →
##   画布 = 母版大图，保存自动写两份：权威版进母版 + 缩印版进游戏目录（永远同步）
## - 普通模式：无母版体系的角色（run_test/敌人/模板）→ 与历史行为完全一致（单写）
##
## 工作流程：
## 1. 加载底图（母版模式自动换成大图原画）
## 2. 如果已有 mask（优先母版版），自动加载
## 3. 鼠标绘制/擦除 mask（笔刷随画布倍率补偿，手感一致）
## 4. 实时预览轮廓效果
## 5. 保存（母版模式双写）

const ContourTracer = preload(
	"res://addons/quiver.beat_em_up/custom_inspectors/height_layers/contour_tracer.gd"
)
const Injector = preload(
	"res://addons/quiver.beat_em_up/custom_inspectors/height_layers/animation_track_injector.gd"
)
const SpriteScan = preload(
	"res://addons/quiver.beat_em_up/custom_inspectors/height_layers/sprite_browser_scan.gd"
)

## 在编辑器内换图时通知面板同步"当前文件"
signal file_changed(new_path: String)

var _png_path: String = ""
var _mask_path: String = ""
var _alpha_threshold: float = 0.5
var _simplify_tolerance: float = 2.0
var _min_area_ratio: float = 0.3

# 母版体系上下文（set_master_context 传入；判定不出母版则一切维持旧行为）
var _source_dir: String = ""
var _backup_dir: String = ""
var _master_png_path: String = ""
var _is_master_mode: bool = false
var _output_mask_path: String = ""
var _master_mask_path: String = ""
var _output_size: Vector2i = Vector2i.ZERO
var _brush_scale: float = 1.0
var _mask_suffix: String = ".mask"

# 内嵌图片浏览器（左侧目录树 + 缩略图，点选换图）
var _file_tree: Tree
var _browse_root: String = ""
var _thumb_cache: Dictionary = {}
var _tree_items: Dictionary = {}   # 图片路径 -> TreeItem（刷新图标用）
var _mask_dirty: bool = false      # 有未保存笔迹

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
var _delete_btn: Button
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
	_populate_tree()


func set_png_path(path: String) -> void:
	_png_path = path
	_update_mask_path()
	
	if _file_label != null:
		_file_label.text = "文件: %s" % path.get_file()
		_load_images()


## 母版体系上下文（与缩放面板同源配置），须在 set_png_path 之前调用。
func set_master_context(source_dir: String, backup_dir: String) -> void:
	_source_dir = source_dir.strip_edges().trim_suffix("/")
	_backup_dir = backup_dir.strip_edges().trim_suffix("/")


func _update_mask_path() -> void:
	if _png_path.is_empty():
		_mask_path = ""
		_output_mask_path = ""
		_master_mask_path = ""
		_master_png_path = ""
		_is_master_mode = false
		return
	
	var selected_id := 0
	if _mask_type_option != null:
		selected_id = _mask_type_option.get_selected_id()
	
	match selected_id:
		1:  # Body
			_mask_suffix = ".body.mask"
		2:  # Attack
			_mask_suffix = ".attack.mask"
		3:  # Shadow（独立解析链，不继承 body）
			_mask_suffix = ".shadow.mask"
		_:  # 通用
			_mask_suffix = ".mask"
	
	# 成品层 mask（游戏检测读取的那份）
	_output_mask_path = _png_path.replace(".png", "") + _mask_suffix + ".png"
	
	# 母版判定：优先面板目录对；回退到 /sprites/ → /sprites_master/ 兄弟推导
	_master_png_path = ""
	var candidate := ""
	if not _source_dir.is_empty() and not _backup_dir.is_empty() and _png_path.begins_with(_source_dir + "/"):
		candidate = _backup_dir + _png_path.trim_prefix(_source_dir)
	elif _png_path.contains("/sprites/"):
		candidate = _png_path.replace("/sprites/", "/sprites_master/")
	if not candidate.is_empty() and candidate != _png_path and FileAccess.file_exists(candidate):
		_master_png_path = candidate
	
	_is_master_mode = not _master_png_path.is_empty()
	_master_mask_path = (_master_png_path.replace(".png", "") + _mask_suffix + ".png") if _is_master_mode else ""
	# 活动路径 = 母版画布对应的 mask；无母版时即成品 mask（旧行为）
	_mask_path = _master_mask_path if _is_master_mode else _output_mask_path


func set_params(alpha: float, tolerance: float, min_area_ratio: float) -> void:
	_alpha_threshold = alpha
	_simplify_tolerance = tolerance
	_min_area_ratio = min_area_ratio


func _build_ui() -> void:
	var hsplit := HSplitContainer.new()
	_browse_root = _resolve_browse_root()
	if _browse_root.is_empty():
		add_child(hsplit)
	else:
		var outer := HSplitContainer.new()
		add_child(outer)
		outer.add_child(_build_file_browser())
		outer.add_child(hsplit)
	
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
	_mask_type_option.add_item("Shadow", 3)
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
	
	# 保存/涂空/删除按钮
	_save_btn = Button.new()
	_save_btn.text = "💾 保存 Mask"
	_save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_btn.pressed.connect(_on_save_pressed)
	_tool_panel.add_child(_save_btn)
	
	_clear_btn = Button.new()
	_clear_btn.text = "🧹 涂空 Mask（保留文件）"
	_clear_btn.tooltip_text = "把画布涂成全透明但仍保存空蒙版文件（＝检测区域被清空）。\n与「删除」不同：删除是移除文件、恢复整图检测。"
	_clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clear_btn.pressed.connect(_on_clear_pressed)
	_tool_panel.add_child(_clear_btn)
	
	_delete_btn = Button.new()
	_delete_btn.text = "🗑 删除 Mask 文件…"
	_delete_btn.tooltip_text = "彻底移除本图【当前所选档位】的蒙版文件。\n母版模式同时删母版+成品两份并清导入伴生（不会被缩放复活）。\n删除后此图恢复整图检测。不影响其它档位。"
	_delete_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_delete_btn.pressed.connect(_on_delete_pressed)
	_tool_panel.add_child(_delete_btn)
	
	# 状态标签
	_status_label = Label.new()
	_status_label.text = "就绪"
	_status_label.add_theme_color_override("font_color", Color.GRAY)
	_tool_panel.add_child(_status_label)


### 内嵌图片浏览器 ----------------------------------------------------------------

func _resolve_browse_root() -> String:
	if _png_path.is_empty():
		return ""
	if not _source_dir.is_empty() and _png_path.begins_with(_source_dir + "/"):
		return _source_dir
	var i := _png_path.rfind("/sprites/")
	if i >= 0:
		return _png_path.substr(0, i + "/sprites".length())
	return _png_path.get_base_dir()


func _build_file_browser() -> Control:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(250, 0)
	var title := Label.new()
	title.text = "📁 图片列表（点选换图）"
	panel.add_child(title)
	_file_tree = Tree.new()
	_file_tree.hide_root = true
	_file_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_file_tree.item_selected.connect(_on_tree_item_selected)
	panel.add_child(_file_tree)
	return panel


func _populate_tree() -> void:
	if _file_tree == null or _browse_root.is_empty():
		return
	_file_tree.clear()
	_tree_items.clear()
	var tree_root := _file_tree.create_item()
	var groups: Array = SpriteScan.scan_sprite_tree(_browse_root)
	var painted := 0
	for g in groups:
		var gitem: TreeItem = tree_root
		if String(g["dir"]) != "":
			gitem = _file_tree.create_item(tree_root)
			gitem.set_text(0, String(g["dir"]))
			gitem.set_selectable(0, false)
			gitem.set_expanded(true)
		for fpath in g["files"]:
			var it := _file_tree.create_item(gitem)
			it.set_metadata(0, fpath)
			_tree_items[fpath] = it
			painted += 1
			if painted % 48 == 0:
				await get_tree().process_frame  # 分批让出，构建不冻界面
	_refresh_badges()
	_ensure_current_selected()
	# 缩略图第二遍分批挂（图已缓存过就不重复解码）
	var n := 0
	for fpath in _tree_items:
		var it: TreeItem = _tree_items[fpath]
		it.set_icon(0, _get_thumb(fpath))
		n += 1
		if n % 24 == 0:
			await get_tree().process_frame


## 当前所选类型 → 文件名后追加状态标记：🎭=该类型有生效蒙版  ⛔=该类型被跳过检测
func _badge_suffix(png_path: String) -> String:
	var cat := _current_category()
	var out := ""
	if not Injector.resolve_mask_path(png_path, cat).is_empty():
		out += " 🎭"
	if not Injector.find_no_marker(png_path, cat).is_empty():
		out += " ⛔"
	return out


func _current_category() -> String:
	var id := 0
	if _mask_type_option != null:
		id = _mask_type_option.get_selected_id()
	return SpriteScan.option_category(id)


func _refresh_badges() -> void:
	for fpath in _tree_items:
		var it: TreeItem = _tree_items[fpath]
		it.set_text(0, String(fpath).get_file() + _badge_suffix(fpath))


func _ensure_current_selected() -> void:
	if _file_tree == null or not _tree_items.has(_png_path):
		return
	var it: TreeItem = _tree_items[_png_path]
	it.select(0)
	_file_tree.scroll_to_item(it)


func _get_thumb(png_path: String) -> Texture2D:
	if _thumb_cache.has(png_path):
		return _thumb_cache[png_path]
	var tex: Texture2D = null
	var img := Image.load_from_file(ProjectSettings.globalize_path(png_path))
	if img != null:
		var w := maxi(1, img.get_width())
		var h := maxi(1, img.get_height())
		var scale := 48.0 / float(maxi(w, h))
		img.resize(maxi(1, int(round(w * scale))), maxi(1, int(round(h * scale))), Image.INTERPOLATE_LANCZOS)
		tex = ImageTexture.create_from_image(img)
	_thumb_cache[png_path] = tex
	return tex


func _on_tree_item_selected() -> void:
	if _file_tree == null:
		return
	var it := _file_tree.get_selected()
	if it == null:
		return
	var meta = it.get_metadata(0)
	if meta == null:
		return
	var p := String(meta)
	if p.is_empty() or p == _png_path:
		return
	if _mask_dirty:
		var confirm := ConfirmationDialog.new()
		confirm.title = "有未保存的修改"
		confirm.dialog_text = "「%s」的笔迹还没保存，切换后这些笔迹会丢失。" % _png_path.get_file()
		add_child(confirm)
		confirm.confirmed.connect(_do_switch_to.bind(p))
		confirm.canceled.connect(confirm.queue_free)
		confirm.popup_centered()
	else:
		_do_switch_to(p)


func _do_switch_to(new_path: String) -> void:
	_png_path = new_path
	if _file_label != null:
		_file_label.text = "文件: %s" % new_path.get_file()
	_update_mask_path()
	_load_images()
	_refresh_badges()
	_ensure_current_selected()
	file_changed.emit(new_path)


func _load_images() -> void:
	if _png_path.is_empty():
		return
	
	# 母版模式在大尺寸原画上作画；否则与旧行为一致画当前图
	var active_png := _master_png_path if _is_master_mode else _png_path
	_original_image = Image.load_from_file(ProjectSettings.globalize_path(active_png))
	if _original_image == null:
		_status_label.text = "错误: 无法加载图片"
		_status_label.add_theme_color_override("font_color", Color.RED)
		return
	
	var img_w := _original_image.get_width()
	var img_h := _original_image.get_height()
	
	# 笔刷补偿：母版画布相对成品的倍率（同笔刷号手感一致）；成品尺寸供保存时缩印
	_brush_scale = 1.0
	_output_size = Vector2i(img_w, img_h)
	if _is_master_mode:
		var out_img := Image.load_from_file(ProjectSettings.globalize_path(_png_path))
		if out_img != null and out_img.get_width() > 0:
			_output_size = Vector2i(out_img.get_width(), out_img.get_height())
			_brush_scale = float(img_w) / float(out_img.get_width())
	
	# 设置 viewport 尺寸
	_viewport.size = Vector2i(img_w, img_h)
	
	# 设置底图
	_bg_texture_rect.texture = ImageTexture.create_from_image(_original_image)
	_bg_texture_rect.size = Vector2(img_w, img_h)
	
	# 加载或创建 mask：权威母版 → 成品旧版（升采样当起点，保存即转正）→ 新建
	var seed_from_output := false
	var load_path := _mask_path
	if _is_master_mode and not FileAccess.file_exists(_mask_path) and FileAccess.file_exists(_output_mask_path):
		load_path = _output_mask_path
		seed_from_output = true
	if FileAccess.file_exists(load_path):
		_mask_image = Image.load_from_file(ProjectSettings.globalize_path(load_path))
		if _mask_image.get_width() != img_w or _mask_image.get_height() != img_h:
			_mask_image.resize(img_w, img_h, Image.INTERPOLATE_LANCZOS)
		if seed_from_output:
			_status_label.text = "⚠️ 以成品层旧 mask 为起点（升采样），保存后将入册母版为权威版"
		else:
			_status_label.text = "已加载现有 mask" + ("（母版）" if _is_master_mode else "")
		_status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		_mask_image = Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)
		_status_label.text = "新建 mask (透明)" + ("　[母版画布 %d×%d]" % [img_w, img_h] if _is_master_mode else "")
		_status_label.add_theme_color_override("font_color", Color.CYAN)
	
	_update_mask_display()
	_mask_dirty = false


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
	_mask_dirty = true
	
	var radius: float = _brush_size_spinbox.value * _brush_scale / 2.0
	var color: Color = Color(1, 1, 1, 1) if not _is_eraser else Color(0, 0, 0, 0)
	
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
	var radius: float = _brush_size_spinbox.value * _brush_scale / 2.0
	var color: Color = Color(0, 1, 0, 0.5) if not _is_eraser else Color(1, 0, 0, 0.5)
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
	
	if _is_master_mode:
		# 双写核心下沉在 PngScaleTool.write_mask_pair（与缩放同一母版体系，可 headless 测试）
		var PngScaleTool = preload("res://addons/quiver.beat_em_up/custom_inspectors/height_layers/png_scale_tool.gd")
		var res: Dictionary = PngScaleTool.write_mask_pair(_mask_image, _master_mask_path, _output_mask_path, _output_size)
		EditorInterface.get_resource_filesystem().scan()
		if not res.ok:
			if not res.master_error.is_empty():
				_status_label.text = "❌ 母版保存失败 (%s)" % res.master_error
				_status_label.add_theme_color_override("font_color", Color.RED)
			else:
				_status_label.text = "⚠️ 母版已存，成品层写入失败 (%s)" % res.output_error
				_status_label.add_theme_color_override("font_color", Color.ORANGE_RED)
			return
		_status_label.text = "✅ 已保存两份：母版 %d×%d ＋ 成品 %d×%d" % [
			_mask_image.get_width(), _mask_image.get_height(), _output_size.x, _output_size.y]
		_status_label.add_theme_color_override("font_color", Color.GREEN)
		_mask_dirty = false
		return
	
	var global_path := ProjectSettings.globalize_path(_mask_path)
	var err := _mask_image.save_png(global_path)
	
	if err == OK:
		_status_label.text = "✅ 已保存: %s" % _mask_path.get_file()
		_status_label.add_theme_color_override("font_color", Color.GREEN)
		_mask_dirty = false
		
		# 刷新文件系统
		EditorInterface.get_resource_filesystem().scan()
	else:
		_status_label.text = "❌ 保存失败 (error=%d)" % err
		_status_label.add_theme_color_override("font_color", Color.RED)


func _on_clear_pressed() -> void:
	if _mask_image == null or _original_image == null:
		return
	
	_mask_image.fill(Color(0, 0, 0, 0))
	_mask_dirty = true
	_update_mask_display()
	_preview_texture.texture = null
	_status_label.text = "Mask 已涂空（仍保留空蒙版文件，保存后＝检测区域清空）"
	_status_label.add_theme_color_override("font_color", Color.CYAN)


## 删除当前档位的蒙版文件（真删，非涂空）：确认弹窗列出将被删文件，删除后复位画布＝整图检测
func _on_delete_pressed() -> void:
	if _png_path.is_empty():
		return
	
	var candidates: Array[String] = []
	if _is_master_mode:
		candidates.append(_master_mask_path)
	candidates.append(_output_mask_path)
	var will_delete: Array[String] = []
	for c in candidates:
		if not c.is_empty() and c not in will_delete and FileAccess.file_exists(c):
			will_delete.append(c)
	
	if will_delete.is_empty():
		_status_label.text = "本图当前【%s】档无蒙版文件，无需删除" % _mask_suffix
		_status_label.add_theme_color_override("font_color", Color.GRAY)
		return
	
	var confirm := ConfirmationDialog.new()
	confirm.title = "🗑 确认删除蒙版（%s 档）" % _mask_suffix
	confirm.dialog_text = "将彻底删除以下 %d 个文件（不可撤销）：\n\n%s\n\n删除后此图恢复整图检测。不影响其它档位与其它图。" % [
		will_delete.size(), "\n".join(will_delete)
	]
	add_child(confirm)
	confirm.confirmed.connect(_perform_delete.bind(will_delete))
	confirm.canceled.connect(confirm.queue_free)
	confirm.popup_centered()


func _perform_delete(_will_delete: Array[String]) -> void:
	var PngScaleTool = preload("res://addons/quiver.beat_em_up/custom_inspectors/height_layers/png_scale_tool.gd")
	var res: Dictionary = PngScaleTool.delete_mask_pair(_master_mask_path, _output_mask_path, _is_master_mode)
	# 画布复位为全透明＝等同于"未加载蒙版"的整图检测起点
	if _mask_image != null:
		_mask_image.fill(Color(0, 0, 0, 0))
		_update_mask_display()
	if _preview_texture != null:
		_preview_texture.texture = null
	EditorInterface.get_resource_filesystem().scan()
	_mask_dirty = false
	if res.ok:
		_status_label.text = "✅ 已删除 %d 个蒙版文件，本图恢复整图检测" % res.deleted.size()
		_refresh_badges()
		_status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		_status_label.text = "⚠️ 删除部分出错：%s" % ", ".join(res.errors)
		_status_label.add_theme_color_override("font_color", Color.ORANGE_RED)


func _on_mask_type_changed(_idx: int) -> void:
	_update_mask_path()
	if not _png_path.is_empty():
		_load_images()
	_refresh_badges()
