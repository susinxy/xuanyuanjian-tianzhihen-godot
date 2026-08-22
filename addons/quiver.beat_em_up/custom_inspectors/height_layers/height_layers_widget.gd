@tool
extends VBoxContainer
## 高度层扫描工具 Widget
##
## 提供的 Inspector UI：
## - "扫描并生成高度轨道" 按钮
## - 状态/错误信息显示
## - 扫描结果预览（动画数量、帧数量、错误数量）
##
## 工作流程：
## 1. 用户选择皮肤节点（QuiverCharacterSkinAnimTree）时，此 Widget 出现
## 2. 点击按钮触发扫描
## 3. Widget 调用 AnimationTrackInjector 执行：
##    a. 从 AnimatedSprite2D.sprite_frames 读取帧 → 文件名
##    b. 解析文件名 → CharacterHeightData
##    c. 注入 value tracks / method tracks 到 Animation 资源
##    d. 保存 .tres 文件
## 4. 显示扫描结果

signal scan_completed(anim_count: int, frame_count: int, error_count: int)

### Member Variables and Dependencies -------------------------------------------------------------

const AnimationTrackInjector = preload(
	"res://addons/quiver.beat_em_up/custom_inspectors/height_layers/"
	+ "animation_track_injector.gd"
)

# 持久化文件路径（跨 widget 重建）
static var _persisted_preview_file_path: String = ""

# 持久化转换参数（跨 widget 重建）
static var _persisted_alpha_threshold: float = 0.5
static var _persisted_simplify_tolerance: float = 100.0
static var _persisted_min_area_ratio: float = 0.3
static var _persisted_erosion_radius: int = 0
static var _persisted_shape_type: int = 0

var _skin_node: Node = null
var _show_body_button: bool = true

# 轮廓转换 UI
var _body_contour_btn: Button
var _attack_contour_btn: Button
var _contour_status_label: Label
var _contour_result_label: RichTextLabel
var _current_contour_mode: String = "Body"
var _shape_type_option: OptionButton
var _alpha_threshold_spinbox: SpinBox
var _simplify_tolerance_spinbox: SpinBox
var _min_area_ratio_spinbox: SpinBox
var _erosion_radius_spinbox: SpinBox

# 预览区域 UI
var _preview_file_path: LineEdit
var _preview_file_select_btn: Button
var _preview_contour_btn: Button
var _preview_mask_btn: Button
var _preview_mabr_test_btn: Button
var _preview_result_label: RichTextLabel
var _preview_texture: TextureRect

# 预览区域专用参数 UI
var _preview_alpha_threshold_spinbox: SpinBox
var _preview_simplify_tolerance_spinbox: SpinBox
var _preview_min_area_ratio_spinbox: SpinBox
var _preview_erosion_radius_spinbox: SpinBox

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	_build_ui()
	
	# 恢复持久化的文件路径
	if not _persisted_preview_file_path.is_empty():
		_preview_file_path.text = _persisted_preview_file_path
		_preview_contour_btn.disabled = false
		_preview_mask_btn.disabled = false
	
	# 恢复持久化的转换参数
	_alpha_threshold_spinbox.value = _persisted_alpha_threshold
	_simplify_tolerance_spinbox.value = _persisted_simplify_tolerance
	_min_area_ratio_spinbox.value = _persisted_min_area_ratio
	_erosion_radius_spinbox.value = _persisted_erosion_radius
	_shape_type_option.selected = _persisted_shape_type


### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## 由 inspector_plugin 调用，传入皮肤节点引用
func set_skin_node(skin_node: Node) -> void:
	_skin_node = skin_node


## 法术模式：隐藏 Body 按钮（法术不需要身体轮廓转换）
func hide_body_button() -> void:
	_show_body_button = false


### Private Methods -------------------------------------------------------------------------------

func _build_ui() -> void:
	# 预览区域
	_build_preview_ui()
	
	# === 轮廓多边形转换区域 ===
	add_child(HSeparator.new())
	
	var contour_header := Label.new()
	contour_header.text = "🔷 轮廓多边形转换"
	contour_header.add_theme_font_size_override("font_size", 16)
	add_child(contour_header)
	
	var contour_desc := Label.new()
	contour_desc.text = "从 PNG 提取轮廓，生成精确碰撞多边形。\n" + \
						"Body: 替换 HurtShape，计算 physical_height\n" + \
						"Attack: 替换 AttackShape，计算 attack_heights"
	contour_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	contour_desc.add_theme_color_override("font_color", Color.GRAY)
	add_child(contour_desc)
	
	# 参数行
	var param_container := VBoxContainer.new()
	add_child(param_container)
	
	# Alpha 阈值
	var alpha_row := HBoxContainer.new()
	param_container.add_child(alpha_row)
	var alpha_label := Label.new()
	alpha_label.text = "Alpha 阈值:"
	alpha_label.custom_minimum_size.x = 80
	alpha_row.add_child(alpha_label)
	_alpha_threshold_spinbox = SpinBox.new()
	_alpha_threshold_spinbox.min_value = 0.0
	_alpha_threshold_spinbox.max_value = 1.0
	_alpha_threshold_spinbox.step = 0.1
	_alpha_threshold_spinbox.value = 0.5
	_alpha_threshold_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alpha_row.add_child(_alpha_threshold_spinbox)
	
	# 简化容差
	var tolerance_row := HBoxContainer.new()
	param_container.add_child(tolerance_row)
	var tolerance_label := Label.new()
	tolerance_label.text = "简化容差:"
	tolerance_label.custom_minimum_size.x = 80
	tolerance_row.add_child(tolerance_label)
	_simplify_tolerance_spinbox = SpinBox.new()
	_simplify_tolerance_spinbox.min_value = 0.0
	_simplify_tolerance_spinbox.max_value = 256.0
	_simplify_tolerance_spinbox.step = 0.5
	_simplify_tolerance_spinbox.value = 100.0
	_simplify_tolerance_spinbox.suffix = " px"
	_simplify_tolerance_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tolerance_row.add_child(_simplify_tolerance_spinbox)
	
	# 最小面积比例
	var area_ratio_row := HBoxContainer.new()
	param_container.add_child(area_ratio_row)
	var area_ratio_label := Label.new()
	area_ratio_label.text = "最小面积比例:"
	area_ratio_label.custom_minimum_size.x = 80
	area_ratio_row.add_child(area_ratio_label)
	_min_area_ratio_spinbox = SpinBox.new()
	_min_area_ratio_spinbox.min_value = 0.1
	_min_area_ratio_spinbox.max_value = 0.8
	_min_area_ratio_spinbox.step = 0.05
	_min_area_ratio_spinbox.value = 0.3
	_min_area_ratio_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area_ratio_row.add_child(_min_area_ratio_spinbox)
	
	# 碰撞形状类型
	var shape_row := HBoxContainer.new()
	param_container.add_child(shape_row)
	var shape_label := Label.new()
	shape_label.text = "碰撞形状:"
	shape_label.custom_minimum_size.x = 80
	shape_row.add_child(shape_label)
	_shape_type_option = OptionButton.new()
	_shape_type_option.add_item("Polygon", AnimationTrackInjector.ShapeType.POLYGON)
	_shape_type_option.add_item("Capsule", AnimationTrackInjector.ShapeType.CAPSULE)
	_shape_type_option.add_item("Rectangle", AnimationTrackInjector.ShapeType.RECTANGLE)
	_shape_type_option.selected = 0
	_shape_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shape_type_option.item_selected.connect(_on_shape_type_changed)
	shape_row.add_child(_shape_type_option)
	
	# 腐蚀半径（仅影响 MABR/Capsule/Rectangle）
	var erosion_row := HBoxContainer.new()
	param_container.add_child(erosion_row)
	var erosion_label := Label.new()
	erosion_label.text = "腐蚀半径:"
	erosion_label.custom_minimum_size.x = 80
	erosion_row.add_child(erosion_label)
	_erosion_radius_spinbox = SpinBox.new()
	_erosion_radius_spinbox.min_value = 0
	_erosion_radius_spinbox.max_value = 100
	_erosion_radius_spinbox.step = 1
	_erosion_radius_spinbox.value = 0
	_erosion_radius_spinbox.suffix = " px"
	_erosion_radius_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	erosion_row.add_child(_erosion_radius_spinbox)
	var erosion_hint := Label.new()
	erosion_hint.text = "(仅 MABR)"
	erosion_hint.add_theme_color_override("font_color", Color.GRAY)
	erosion_row.add_child(erosion_hint)
	
	# 按钮容器
	var contour_btn_container := HBoxContainer.new()
	add_child(contour_btn_container)
	
	_body_contour_btn = Button.new()
	_body_contour_btn.text = "🏃 Body 轮廓转换"
	_body_contour_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_contour_btn.pressed.connect(_on_body_contour_pressed)
	contour_btn_container.add_child(_body_contour_btn)
	
	_attack_contour_btn = Button.new()
	_attack_contour_btn.text = "⚔ Attack 轮廓转换"
	_attack_contour_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attack_contour_btn.pressed.connect(_on_attack_contour_pressed)
	contour_btn_container.add_child(_attack_contour_btn)
	
	# 轮廓转换状态
	_contour_status_label = Label.new()
	_contour_status_label.text = "就绪"
	_contour_status_label.add_theme_color_override("font_color", Color.GRAY)
	add_child(_contour_status_label)
	
	# 轮廓转换结果
	_contour_result_label = RichTextLabel.new()
	_contour_result_label.bbcode_enabled = true
	_contour_result_label.text = ""
	_contour_result_label.custom_minimum_size = Vector2(0, 100)
	add_child(_contour_result_label)
	
	# 法术模式：禁用 Body 按钮
	if not _show_body_button:
		_body_contour_btn.disabled = true
		_body_contour_btn.tooltip_text = "法术不需要 Body 轮廓转换"


## 轮廓转换进度回调
func _on_contour_progress(current: int, total: int, filename: String) -> void:
	_contour_status_label.text = "⏳ %s 转换中: %d 帧 (%s)" % [_current_contour_mode, current, filename]


## 碰撞形状类型切换时设置默认参数
func _on_shape_type_changed(index: int) -> void:
	match index:
		AnimationTrackInjector.ShapeType.POLYGON:
			_erosion_radius_spinbox.value = 0
			_simplify_tolerance_spinbox.value = 100.0
		AnimationTrackInjector.ShapeType.CAPSULE, AnimationTrackInjector.ShapeType.RECTANGLE:
			_erosion_radius_spinbox.value = 20
			_simplify_tolerance_spinbox.value = 5.0


func _on_body_contour_pressed() -> void:
	if _skin_node == null:
		return
	_current_contour_mode = "Body"
	_body_contour_btn.disabled = true
	_attack_contour_btn.disabled = true
	
	_contour_status_label.text = "⏳ Body 轮廓转换中..."
	_contour_status_label.add_theme_color_override("font_color", Color.CYAN)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	_execute_contour_conversion_async("body")


func _on_attack_contour_pressed() -> void:
	if _skin_node == null:
		return
	_current_contour_mode = "Attack"
	_body_contour_btn.disabled = true
	_attack_contour_btn.disabled = true
	
	_contour_status_label.text = "⏳ Attack 轮廓转换中..."
	_contour_status_label.add_theme_color_override("font_color", Color.CYAN)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	_execute_contour_conversion_async("attack")


func _execute_contour_conversion_async(mode: String) -> void:
	# 保存当前参数到 static 变量（持久化）
	_persisted_alpha_threshold = _alpha_threshold_spinbox.value
	_persisted_simplify_tolerance = _simplify_tolerance_spinbox.value
	_persisted_min_area_ratio = _min_area_ratio_spinbox.value
	_persisted_erosion_radius = int(_erosion_radius_spinbox.value)
	_persisted_shape_type = _shape_type_option.selected
	
	var injector := AnimationTrackInjector.new()
	var alpha_threshold: float = _alpha_threshold_spinbox.value
	var simplify_tolerance: float = _simplify_tolerance_spinbox.value
	var min_area_ratio: float = _min_area_ratio_spinbox.value
	var erosion_radius: int = int(_erosion_radius_spinbox.value)
	var shape_type: int = _shape_type_option.selected
	
	var result: Dictionary
	if mode == "body":
		result = await injector.convert_body_contours(_skin_node, alpha_threshold, simplify_tolerance, min_area_ratio, erosion_radius, shape_type, false, self)
	else:
		result = await injector.convert_attack_contours(_skin_node, alpha_threshold, simplify_tolerance, min_area_ratio, erosion_radius, shape_type, false, self)
	
	# 显示结果
	var error_count: int = result.errors.size()
	var frame_count: int = result.frame_count
	
	var lines := []
	lines.append("[b]%s 轮廓转换结果[/b]" % ("Body" if mode == "body" else "Attack"))
	lines.append("")
	lines.append("处理帧数: [b]%d[/b]" % frame_count)
	lines.append("")
	
	if error_count == 0:
		lines.append("[color=green]✅ 转换完成，无错误[/color]")
	else:
		lines.append("[color=red]❌ 有 %d 个错误：[/color]" % error_count)
		for error in result.errors:
			lines.append("  • %s" % error)
	
	_contour_result_label.text = "\n".join(lines)
	
	# 恢复按钮状态（法术模式下 Body 保持禁用）
	_body_contour_btn.disabled = not _show_body_button
	_attack_contour_btn.disabled = false
	
	if error_count == 0:
		_contour_status_label.text = "✅ %s 转换完成" % ("Body" if mode == "body" else "Attack")
		_contour_status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		_contour_status_label.text = "⚠️ %s 转换完成，有 %d 个错误" % ["Body" if mode == "body" else "Attack", error_count]
		_contour_status_label.add_theme_color_override("font_color", Color.ORANGE)
	
	scan_completed.emit(0, frame_count, error_count)


## 构建单文件测试 UI
func _build_preview_ui() -> void:
	var preview_header := Label.new()
	preview_header.text = "🎨 轮廓预览 & Mask 编辑"
	preview_header.add_theme_font_size_override("font_size", 16)
	add_child(preview_header)
	
	add_child(HSeparator.new())
	
	# 文件选择行
	var file_row := HBoxContainer.new()
	add_child(file_row)
	
	var file_label := Label.new()
	file_label.text = "PNG 文件:"
	file_label.custom_minimum_size.x = 80
	file_row.add_child(file_label)
	
	_preview_file_path = LineEdit.new()
	_preview_file_path.placeholder_text = "选择 PNG 文件..."
	_preview_file_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_file_path.editable = false
	file_row.add_child(_preview_file_path)
	
	_preview_file_select_btn = Button.new()
	_preview_file_select_btn.text = "浏览"
	_preview_file_select_btn.pressed.connect(_on_preview_file_select_btn_pressed)
	file_row.add_child(_preview_file_select_btn)
	
	# 预览参数区域
	var preview_param_container := VBoxContainer.new()
	add_child(preview_param_container)
	
	var preview_param_label := Label.new()
	preview_param_label.text = "预览参数"
	preview_param_label.add_theme_font_size_override("font_size", 14)
	preview_param_container.add_child(preview_param_label)
	
	# Alpha 阈值
	var preview_alpha_row := HBoxContainer.new()
	preview_param_container.add_child(preview_alpha_row)
	var preview_alpha_label := Label.new()
	preview_alpha_label.text = "Alpha 阈值:"
	preview_alpha_label.custom_minimum_size.x = 80
	preview_alpha_row.add_child(preview_alpha_label)
	_preview_alpha_threshold_spinbox = SpinBox.new()
	_preview_alpha_threshold_spinbox.min_value = 0.0
	_preview_alpha_threshold_spinbox.max_value = 1.0
	_preview_alpha_threshold_spinbox.step = 0.1
	_preview_alpha_threshold_spinbox.value = 0.5
	_preview_alpha_threshold_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_alpha_row.add_child(_preview_alpha_threshold_spinbox)
	
	# 简化容差
	var preview_tolerance_row := HBoxContainer.new()
	preview_param_container.add_child(preview_tolerance_row)
	var preview_tolerance_label := Label.new()
	preview_tolerance_label.text = "简化容差:"
	preview_tolerance_label.custom_minimum_size.x = 80
	preview_tolerance_row.add_child(preview_tolerance_label)
	_preview_simplify_tolerance_spinbox = SpinBox.new()
	_preview_simplify_tolerance_spinbox.min_value = 0.0
	_preview_simplify_tolerance_spinbox.max_value = 256.0
	_preview_simplify_tolerance_spinbox.step = 0.5
	_preview_simplify_tolerance_spinbox.value = 100.0
	_preview_simplify_tolerance_spinbox.suffix = " px"
	_preview_simplify_tolerance_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_tolerance_row.add_child(_preview_simplify_tolerance_spinbox)
	
	# 最小面积比例
	var preview_area_ratio_row := HBoxContainer.new()
	preview_param_container.add_child(preview_area_ratio_row)
	var preview_area_ratio_label := Label.new()
	preview_area_ratio_label.text = "最小面积比例:"
	preview_area_ratio_label.custom_minimum_size.x = 80
	preview_area_ratio_row.add_child(preview_area_ratio_label)
	_preview_min_area_ratio_spinbox = SpinBox.new()
	_preview_min_area_ratio_spinbox.min_value = 0.1
	_preview_min_area_ratio_spinbox.max_value = 0.8
	_preview_min_area_ratio_spinbox.step = 0.05
	_preview_min_area_ratio_spinbox.value = 0.3
	_preview_min_area_ratio_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_area_ratio_row.add_child(_preview_min_area_ratio_spinbox)
	
	# 腐蚀半径
	var preview_erosion_row := HBoxContainer.new()
	preview_param_container.add_child(preview_erosion_row)
	var preview_erosion_label := Label.new()
	preview_erosion_label.text = "腐蚀半径:"
	preview_erosion_label.custom_minimum_size.x = 80
	preview_erosion_row.add_child(preview_erosion_label)
	_preview_erosion_radius_spinbox = SpinBox.new()
	_preview_erosion_radius_spinbox.min_value = 0
	_preview_erosion_radius_spinbox.max_value = 100
	_preview_erosion_radius_spinbox.step = 1
	_preview_erosion_radius_spinbox.value = 0
	_preview_erosion_radius_spinbox.suffix = " px"
	_preview_erosion_radius_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_erosion_row.add_child(_preview_erosion_radius_spinbox)
	var preview_erosion_hint := Label.new()
	preview_erosion_hint.text = "(仅 MABR)"
	preview_erosion_hint.add_theme_color_override("font_color", Color.GRAY)
	preview_erosion_row.add_child(preview_erosion_hint)
	
	# 操作按钮行
	var preview_btn_row := HBoxContainer.new()
	add_child(preview_btn_row)
	
	_preview_contour_btn = Button.new()
	_preview_contour_btn.text = "🔍 预览轮廓"
	_preview_contour_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_contour_btn.disabled = true
	_preview_contour_btn.pressed.connect(_on_preview_contour_pressed)
	preview_btn_row.add_child(_preview_contour_btn)
	
	_preview_mask_btn = Button.new()
	_preview_mask_btn.text = "🎨 编辑 Mask"
	_preview_mask_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_mask_btn.disabled = true
	_preview_mask_btn.pressed.connect(_on_preview_mask_pressed)
	preview_btn_row.add_child(_preview_mask_btn)
	
	_preview_mabr_test_btn = Button.new()
	_preview_mabr_test_btn.text = "🧪 MABR 测试"
	_preview_mabr_test_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_mabr_test_btn.pressed.connect(_on_preview_mabr_test_pressed)
	preview_btn_row.add_child(_preview_mabr_test_btn)
	
	# 结果显示
	_preview_result_label = RichTextLabel.new()
	_preview_result_label.bbcode_enabled = true
	_preview_result_label.text = "[color=gray]选择文件后点击预览按钮[/color]"
	_preview_result_label.custom_minimum_size = Vector2(0, 150)
	add_child(_preview_result_label)
	
	# 轮廓预览图
	_preview_texture = TextureRect.new()
	_preview_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_texture.custom_minimum_size = Vector2(0, 256)
	add_child(_preview_texture)
	
	add_child(HSeparator.new())


## 预览区域文件选择按钮点击
func _on_preview_file_select_btn_pressed() -> void:
	var file_dialog := FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.filters = ["*.png ; PNG Images"]
	file_dialog.current_dir = "res://characters/playable/"
	
	file_dialog.file_selected.connect(func(path: String):
		_preview_file_path.text = path
		_persisted_preview_file_path = path
		_preview_contour_btn.disabled = false
		_preview_mask_btn.disabled = false
		file_dialog.queue_free()
	)
	
	file_dialog.canceled.connect(func():
		file_dialog.queue_free()
	)
	
	add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(800, 600))


## 预览轮廓按钮点击
func _on_preview_contour_pressed() -> void:
	_run_preview()


## Mask 编辑器按钮点击
func _on_preview_mask_pressed() -> void:
	var file_path := _preview_file_path.text
	if file_path.is_empty():
		return
	
	var MaskEditorDialog = preload("res://addons/quiver.beat_em_up/custom_inspectors/height_layers/mask_editor_dialog.gd")
	var dialog := MaskEditorDialog.new()
	dialog.set_params(_alpha_threshold_spinbox.value, _simplify_tolerance_spinbox.value, _min_area_ratio_spinbox.value)
	add_child(dialog)
	dialog.set_png_path(file_path)
	dialog.popup_centered(Vector2i(900, 700))
	dialog.closed.connect(func():
		dialog.queue_free()
	)


## MABR 测试按钮点击
func _on_preview_mabr_test_pressed() -> void:
	_preview_mabr_test_btn.disabled = true
	_preview_result_label.text = "[color=cyan]运行 MABR 基础测试...[/color]"
	
	await get_tree().process_frame
	
	var results := ContourTracer.run_mabr_tests()
	
	var lines := []
	lines.append("[b]MABR 基础测试结果[/b]")
	lines.append("")
	for r in results:
		if r.begins_with("✅"):
			lines.append("[color=green]%s[/color]" % r)
		elif r.begins_with("❌"):
			lines.append("[color=red]%s[/color]" % r)
		elif r.begins_with("总计"):
			lines.append("")
			if "0 失败" in r:
				lines.append("[color=green][b]%s[/b][/color]" % r)
			else:
				lines.append("[color=red][b]%s[/b][/color]" % r)
		else:
			lines.append(r)
	
	_preview_result_label.text = "\n".join(lines)
	_preview_mabr_test_btn.disabled = false


## 执行预览
func _run_preview() -> void:
	if _skin_node == null:
		_preview_result_label.text = "[color=red]错误: 未关联皮肤节点[/color]"
		return
	
	var file_path := _preview_file_path.text
	if file_path.is_empty():
		_preview_result_label.text = "[color=red]错误: 未选择文件[/color]"
		return
	
	# 禁用按钮
	_preview_contour_btn.disabled = true
	_preview_result_label.text = "[color=cyan]预览中...[/color]"
	
	# 等待两帧确保 UI 更新
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 获取预览专用参数
	var alpha_threshold: float = _preview_alpha_threshold_spinbox.value
	var simplify_tolerance: float = _preview_simplify_tolerance_spinbox.value
	var min_area_ratio: float = _preview_min_area_ratio_spinbox.value
	var erosion_radius: int = int(_preview_erosion_radius_spinbox.value)
	
	# 执行预览
	var injector := AnimationTrackInjector.new()
	var result := injector.preview_single_file(file_path, alpha_threshold, simplify_tolerance, min_area_ratio, erosion_radius)
	
	# 显示结果
	_display_preview_result(result)
	
	# 显示预览图
	await _display_preview(result)
	
	# 恢复按钮
	_preview_contour_btn.disabled = false


## 显示预览结果
func _display_preview_result(result: Dictionary) -> void:
	var lines := []
	
	if result.error != "":
		lines.append("[color=red]错误: %s[/color]" % result.error)
		_preview_result_label.text = "\n".join(lines)
		return
	
	lines.append("[b]文件名:[/b] %s" % result.file_name)
	lines.append("[b]图片尺寸:[/b] %d × %d" % [result.image_size.x, result.image_size.y])
	lines.append("[b]提取轮廓数:[/b] %d" % result.contour_count)
	lines.append("[b]顶点总数:[/b] %d" % result.total_vertices)
	lines.append("[b]Mask 文件:[/b] %s" % ("有" if result.has_mask else "无"))
	lines.append("")
	
	lines.append("[b]physical_height:[/b] %.1f" % result.physical_height)
	
	if not result.attack_heights.is_empty():
		var heights_str := ""
		for i in range(result.attack_heights.size()):
			if i > 0:
				heights_str += ", "
			heights_str += "%.1f" % result.attack_heights[i]
		lines.append("[b]attack_heights:[/b] [%s]" % heights_str)
	
	if result.has("attack_node") and result.attack_node != "":
		lines.append("[b]Attack 节点:[/b] %s" % result.attack_node)
	
	lines.append("")
	lines.append("[b]转换后坐标范围:[/b]")
	lines.append("  X: %.1f ~ %.1f" % [result.bounding_box.position.x, result.bounding_box.position.x + result.bounding_box.size.x])
	lines.append("  Y: %.1f ~ %.1f" % [result.bounding_box.position.y, result.bounding_box.position.y + result.bounding_box.size.y])
	lines.append("")
	lines.append("[b]参数:[/b] alpha=%.1f, tolerance=%.1f, erosion=%d" % [result.alpha_threshold, result.simplify_tolerance, result.erosion_radius])
	
	# MABR/Capsule/Rectangle 信息（从 preview_single_file 返回的数据）
	if result.has("mabr") and not result.mabr.is_empty():
		var mabr: Dictionary = result.mabr
		var aabb := ContourTracer.calc_aabb(result.eroded_contours[0] if result.eroded_contours.size() > 0 else result.contours[0])
		
		lines.append("")
		lines.append("[b]MABR (最小包围矩形):[/b]")
		lines.append("  尺寸: %.1f × %.1f" % [mabr.size.x, mabr.size.y])
		lines.append("  角度: %.1f°" % rad_to_deg(mabr.angle))
		lines.append("  面积: %.1f" % mabr.area)
		lines.append("[b]AABB (轴对齐包围盒):[/b]")
		lines.append("  尺寸: %.1f × %.1f" % [aabb.size.x, aabb.size.y])
		lines.append("  面积: %.1f" % aabb.area)
		if aabb.area > 0.0:
			var saving: float = (1.0 - mabr.area / aabb.area) * 100.0
			lines.append("[b]MABR 节省:[/b] %.1f%%" % saving)
	
	if result.has("capsule") and not result.capsule.is_empty():
		var capsule: Dictionary = result.capsule
		lines.append("")
		lines.append("[b]Capsule (胶囊):[/b]")
		lines.append("  radius: %.1f" % capsule.radius)
		lines.append("  height: %.1f" % capsule.height)
		lines.append("  角度: %.1f°" % rad_to_deg(capsule.angle))
		lines.append("  总长度: %.1f" % capsule.height)
	
	if result.has("rectangle") and not result.rectangle.is_empty():
		var rectangle: Dictionary = result.rectangle
		lines.append("")
		lines.append("[b]Rectangle (矩形):[/b]")
		lines.append("  尺寸: %.1f × %.1f" % [rectangle.size.x, rectangle.size.y])
		lines.append("  角度: %.1f°" % rad_to_deg(rectangle.angle))
	
	_preview_result_label.text = "\n".join(lines)


## 显示轮廓预览图
func _display_preview(result: Dictionary) -> void:
	if result.contours.is_empty() or result.image == null:
		_preview_texture.texture = null
		return
	
	var eroded_contours = result.eroded_contours if result.has("eroded_contours") else result.contours
	var preview_texture = await _generate_contour_preview(result.image, result.contours, eroded_contours)
	_preview_texture.texture = preview_texture


## 生成轮廓预览图
##
## 在 SubViewport 中渲染：原图 + 轮廓多边形叠加
## 返回 ImageTexture
func _generate_contour_preview(image: Image, contours: Array[PackedVector2Array], eroded_contours: Array[PackedVector2Array]):
	var img_w := image.get_width()
	var img_h := image.get_height()
	
	# 创建 SubViewport
	var viewport := SubViewport.new()
	viewport.size = Vector2i(img_w, img_h)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	
	# 底层：原图
	var bg := TextureRect.new()
	bg.texture = ImageTexture.create_from_image(image)
	bg.size = Vector2(img_w, img_h)
	viewport.add_child(bg)
	
	# 上层：轮廓绘制节点
	var overlay := Node2D.new()
	overlay.set_meta("contours", contours)
	overlay.set_meta("eroded_contours", eroded_contours)
	viewport.add_child(overlay)
	
	# 连接 draw 信号
	overlay.draw.connect(_on_overlay_draw.bind(overlay))
	overlay.queue_redraw()
	
	# 等待一帧让渲染完成
	await get_tree().process_frame
	
	# 获取渲染结果
	var viewport_texture := viewport.get_texture()
	var result_texture := ImageTexture.create_from_image(viewport_texture.get_image())
	
	# 清理
	viewport.queue_free()
	
	return result_texture


## 轮廓绘制回调
func _on_overlay_draw(overlay: Node2D) -> void:
	var contours: Array[PackedVector2Array] = overlay.get_meta("contours")
	var eroded_contours: Array[PackedVector2Array] = overlay.get_meta("eroded_contours")
	
	for contour in contours:
		if contour.size() < 3:
			continue
		
		# 填充半透明绿色
		overlay.draw_colored_polygon(contour, Color(0, 1, 0, 0.3))
		
		# 绘制红色边线（闭合）
		var polyline := PackedVector2Array()
		for vertex in contour:
			polyline.append(vertex)
		polyline.append(contour[0])  # 闭合
		overlay.draw_polyline(polyline, Color(1, 0, 0, 1), 2.0, true)
	
	# 绘制 MABR（蓝色矩形 + 黄色中心点，使用腐蚀后的轮廓）
	if eroded_contours.size() > 0 and eroded_contours[0].size() >= 3:
		var mabr := ContourTracer.calc_mabr(eroded_contours[0])
		var corners: PackedVector2Array = mabr.corners
		
		if corners.size() == 4:
			# 蓝色半透明填充
			overlay.draw_colored_polygon(corners, Color(0, 0.5, 1, 0.15))
			
			# 蓝色边线（闭合）
			var mabr_polyline := PackedVector2Array()
			for c in corners:
				mabr_polyline.append(c)
			mabr_polyline.append(corners[0])
			overlay.draw_polyline(mabr_polyline, Color(0, 0.5, 1, 1), 3.0, true)
			
		# 黄色中心点
		var center: Vector2 = mabr.center
		overlay.draw_circle(center, 4, Color(1, 1, 0, 1))
		
		# 绘制 Capsule（品红色，使用 MABR 推导）
		var capsule := ContourTracer.calc_capsule_from_mabr(mabr)
		var capsule_polygon := ContourTracer.generate_capsule_polygon(
			capsule.center,
			capsule.radius,
			capsule.height,
			capsule.angle,
			16
		)
		
		if capsule_polygon.size() >= 3:
			# 品红色半透明填充
			overlay.draw_colored_polygon(capsule_polygon, Color(1, 0, 1, 0.15))
			
			# 品红色边线（闭合）
			var capsule_polyline := PackedVector2Array()
			for p in capsule_polygon:
				capsule_polyline.append(p)
			capsule_polyline.append(capsule_polygon[0])
			overlay.draw_polyline(capsule_polyline, Color(1, 0, 1, 1), 2.0, true)

### -----------------------------------------------------------------------------------------------
