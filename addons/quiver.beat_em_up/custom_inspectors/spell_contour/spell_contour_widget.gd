@tool
extends VBoxContainer
## 法术轮廓转换工具 Widget
##
## 提供的 Inspector UI：
## - "攻击轮廓转换" 按钮
## - 轮廓转换参数（Alpha 阈值、简化容差、最小面积比例、腐蚀半径、形状类型）
## - 状态/错误信息显示
## - 转换结果预览
##
## 工作流程：
## 1. 用户选择法术皮肤节点（SpellSkinAnimTree）时，此 Widget 出现
## 2. 点击按钮触发转换
## 3. Widget 调用 AnimationTrackInjector 执行：
##    a. 从 AnimatedSprite2D.sprite_frames 读取帧 → 文件名
##    b. 提取攻击轮廓 → 生成碰撞形状
##    c. 注入 tracks 到 Animation 资源
##    d. 保存 .tres 文件
## 4. 显示转换结果

signal conversion_completed(frame_count: int, error_count: int)

### Member Variables and Dependencies -------------------------------------------------------------

const AnimationTrackInjector = preload(
	"res://addons/quiver.beat_em_up/custom_inspectors/height_layers/"
	+ "animation_track_injector.gd"
)

# 持久化转换参数（跨 widget 重建）
static var _persisted_alpha_threshold: float = 0.5
static var _persisted_simplify_tolerance: float = 100.0
static var _persisted_min_area_ratio: float = 0.3
static var _persisted_erosion_radius: int = 0
static var _persisted_shape_type: int = 0

var _skin_node: SpellSkinAnimTree = null

# 轮廓转换 UI
var _attack_contour_btn: Button
var _contour_status_label: Label
var _contour_result_label: RichTextLabel
var _shape_type_option: OptionButton
var _alpha_threshold_spinbox: SpinBox
var _simplify_tolerance_spinbox: SpinBox
var _min_area_ratio_spinbox: SpinBox
var _erosion_radius_spinbox: SpinBox

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	_build_ui()
	
	# 恢复持久化的转换参数
	_alpha_threshold_spinbox.value = _persisted_alpha_threshold
	_simplify_tolerance_spinbox.value = _persisted_simplify_tolerance
	_min_area_ratio_spinbox.value = _persisted_min_area_ratio
	_erosion_radius_spinbox.value = _persisted_erosion_radius
	_shape_type_option.selected = _persisted_shape_type


func set_skin_node(skin_node: SpellSkinAnimTree) -> void:
	_skin_node = skin_node

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _build_ui() -> void:
	# 标题
	var header := Label.new()
	header.text = "🔷 法术攻击轮廓转换"
	header.add_theme_font_size_override("font_size", 16)
	add_child(header)
	
	var desc := Label.new()
	desc.text = "从动画帧 PNG 提取攻击轮廓，生成碰撞形状并注入到动画轨道。"
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color.GRAY)
	add_child(desc)
	
	add_child(HSeparator.new())
	
	# 形状类型选择
	var shape_type_row := HBoxContainer.new()
	add_child(shape_type_row)
	
	var shape_type_label := Label.new()
	shape_type_label.text = "形状类型:"
	shape_type_label.custom_minimum_size.x = 80
	shape_type_row.add_child(shape_type_label)
	
	_shape_type_option = OptionButton.new()
	_shape_type_option.add_item("矩形 (Rectangle)", 0)
	_shape_type_option.add_item("胶囊 (Capsule)", 1)
	_shape_type_option.add_item("多边形 (Polygon)", 2)
	_shape_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shape_type_row.add_child(_shape_type_option)
	
	# 参数容器
	var param_container := VBoxContainer.new()
	add_child(param_container)
	
	var param_label := Label.new()
	param_label.text = "转换参数"
	param_label.add_theme_font_size_override("font_size", 14)
	param_container.add_child(param_label)
	
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
	
	# 腐蚀半径
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
	erosion_hint.text = "(仅多边形)"
	erosion_hint.add_theme_color_override("font_color", Color.GRAY)
	erosion_row.add_child(erosion_hint)
	
	add_child(HSeparator.new())
	
	# 攻击轮廓转换按钮
	_attack_contour_btn = Button.new()
	_attack_contour_btn.text = "⚔️ 攻击轮廓转换"
	_attack_contour_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attack_contour_btn.pressed.connect(_on_attack_contour_pressed)
	add_child(_attack_contour_btn)
	
	# 状态标签
	_contour_status_label = Label.new()
	_contour_status_label.text = "就绪"
	_contour_status_label.add_theme_color_override("font_color", Color.GRAY)
	add_child(_contour_status_label)
	
	# 结果显示
	_contour_result_label = RichTextLabel.new()
	_contour_result_label.bbcode_enabled = true
	_contour_result_label.text = "[color=gray]点击按钮开始转换[/color]"
	_contour_result_label.custom_minimum_size = Vector2(0, 150)
	add_child(_contour_result_label)


func _on_attack_contour_pressed() -> void:
	if _skin_node == null:
		_contour_status_label.text = "⚠️ 请先选择法术皮肤节点"
		_contour_status_label.add_theme_color_override("font_color", Color.ORANGE)
		return
	
	# 禁用按钮，显示进度
	_attack_contour_btn.disabled = true
	_contour_status_label.text = "⏳ 正在转换攻击轮廓..."
	_contour_status_label.add_theme_color_override("font_color", Color.CYAN)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	_execute_contour_conversion_async()


func _execute_contour_conversion_async() -> void:
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
	
	var result: Dictionary = await injector.convert_attack_contours(
		_skin_node,
		alpha_threshold,
		simplify_tolerance,
		min_area_ratio,
		erosion_radius,
		shape_type,
		false,
		self
	)
	
	# 显示结果
	var error_count: int = result.errors.size()
	var frame_count: int = result.frame_count
	
	var lines := []
	lines.append("[b]攻击轮廓转换结果[/b]")
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
	
	# 恢复按钮状态
	_attack_contour_btn.disabled = false
	
	if error_count == 0:
		_contour_status_label.text = "✅ 转换完成"
		_contour_status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		_contour_status_label.text = "⚠️ 转换完成，有 %d 个错误" % error_count
		_contour_status_label.add_theme_color_override("font_color", Color.ORANGE)
	
	conversion_completed.emit(frame_count, error_count)

### -----------------------------------------------------------------------------------------------
