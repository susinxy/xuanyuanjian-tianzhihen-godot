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

var _skin_node: QuiverCharacterSkinAnimTree = null

var _preview_btn: Button
var _scan_btn: Button
var _status_label: Label
var _preview_label: RichTextLabel
var _result_label: Label
var _collapse_btn_ref: Button
var _details_container_ref: VBoxContainer
var _is_collapsed := false

var _last_preview_result: Dictionary  # 保存预览结果，用于后续扫描

# 轮廓转换 UI
var _body_contour_btn: Button
var _attack_contour_btn: Button
var _contour_status_label: Label
var _contour_result_label: RichTextLabel
var _alpha_threshold_spinbox: SpinBox
var _simplify_tolerance_spinbox: SpinBox

# 单文件测试 UI
var _test_file_path: LineEdit
var _test_file_btn: Button
var _test_body_btn: Button
var _test_attack_btn: Button
var _test_result_label: RichTextLabel

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	_build_ui()
	# 如果 set_skin_node() 在 _ready() 之前被调用，此时 UI 已构建，重新更新状态
	if _skin_node != null:
		_update_status()


### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## 由 inspector_plugin 调用，传入皮肤节点引用
func set_skin_node(skin_node: Node) -> void:
	_skin_node = skin_node as QuiverCharacterSkinAnimTree
	_update_status()


### Private Methods -------------------------------------------------------------------------------

func _build_ui() -> void:
	# 单文件测试区域
	_build_test_ui()
	
	# 标题
	var header := Label.new()
	header.text = "📏 高度层动画扫描"
	header.add_theme_font_size_override("font_size", 16)
	add_child(header)
	
	add_child(HSeparator.new())
	
	# 描述
	var desc := Label.new()
	desc.text = "扫描动画帧文件名中的 physical_/attack_/speed_ 标注，生成高度轨道。\n\n" + \
				"1. 点击「预览」查看将要修改的动画\n2. 确认无误后点击「扫描」执行修改"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_color_override("font_color", Color.GRAY)
	add_child(desc)
	
	# 状态标签
	_status_label = Label.new()
	_status_label.text = "等待预览..."
	_status_label.add_theme_color_override("font_color", Color.GRAY)
	add_child(_status_label)
	
	# 按钮容器
	var btn_container := HBoxContainer.new()
	add_child(btn_container)
	
	# 预览按钮
	_preview_btn = Button.new()
	_preview_btn.text = "🔍 预览"
	_preview_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_btn.pressed.connect(_on_preview_pressed)
	btn_container.add_child(_preview_btn)
	
	# 扫描按钮
	_scan_btn = Button.new()
	_scan_btn.text = "▶ 扫描并生成高度轨道"
	_scan_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scan_btn.pressed.connect(_on_scan_pressed)
	_scan_btn.disabled = true  # 必须先预览
	btn_container.add_child(_scan_btn)
	
	# 可折叠的结果展示面板
	var result_container := VBoxContainer.new()
	add_child(result_container)
	
	var collapse_btn := Button.new()
	collapse_btn.text = "▼ 修改预览（点击展开/折叠）"
	collapse_btn.pressed.connect(_on_collapse_toggle)
	result_container.add_child(collapse_btn)
	_collapse_btn_ref = collapse_btn
	
	var details_container := VBoxContainer.new()
	result_container.add_child(details_container)
	_details_container_ref = details_container
	
	# 预览展示（RichTextLabel 支持 BBCode）
	_preview_label = RichTextLabel.new()
	_preview_label.bbcode_enabled = true
	_preview_label.text = "[color=gray]请点击「预览」按钮查看可修改的动画[/color]"
	_preview_label.custom_minimum_size = Vector2(0, 200)
	details_container.add_child(_preview_label)
	
	# 扫描结果标签
	_result_label = Label.new()
	_result_label.text = ""
	details_container.add_child(_result_label)
	
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
	_simplify_tolerance_spinbox.min_value = 0.5
	_simplify_tolerance_spinbox.max_value = 20.0
	_simplify_tolerance_spinbox.step = 0.5
	_simplify_tolerance_spinbox.value = 2.0
	_simplify_tolerance_spinbox.suffix = " px"
	_simplify_tolerance_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tolerance_row.add_child(_simplify_tolerance_spinbox)
	
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


func _on_collapse_toggle() -> void:
	_is_collapsed = not _is_collapsed
	_details_container_ref.visible = not _is_collapsed
	_collapse_btn_ref.text = "▶ 修改预览（点击展开/折叠）" if _is_collapsed else "▼ 修改预览（点击展开/折叠）"


func _update_status() -> void:
	# 防御性检查：UI 元素可能尚未初始化
	if _status_label == null or _scan_btn == null or _preview_btn == null:
		return
	
	if _skin_node == null:
		_status_label.text = "Status: ⚠️ 未关联皮肤节点"
		_status_label.add_theme_color_override("font_color", Color.ORANGE)
		_preview_btn.disabled = true
		_scan_btn.disabled = true
		if _body_contour_btn != null:
			_body_contour_btn.disabled = true
		if _attack_contour_btn != null:
			_attack_contour_btn.disabled = true
		return
	
	_status_label.text = "Status: ✅ 已关联: %s" % _skin_node.name
	_status_label.add_theme_color_override("font_color", Color.GREEN)
	_preview_btn.disabled = false
	# 扫描按钮需要先完成预览
	_scan_btn.disabled = (_last_preview_result == null or _last_preview_result.is_empty())
	# 轮廓转换按钮始终可用（只要有 skin 节点）
	if _body_contour_btn != null:
		_body_contour_btn.disabled = false
	if _attack_contour_btn != null:
		_attack_contour_btn.disabled = false


func _on_preview_pressed() -> void:
	if _skin_node == null:
		return
	
	_status_label.text = "Status: 🔍 预览中..."
	_status_label.add_theme_color_override("font_color", Color.CYAN)
	_preview_btn.disabled = true
	_scan_btn.disabled = true  # 预览期间也禁用扫描按钮
	
	# 调用扫描器（dry_run=true）
	var injector := AnimationTrackInjector.new()
	var result := injector.run(_skin_node, true)  # dry_run
	
	# 保存预览结果
	_last_preview_result = result
	
	# 显示预览结果
	_display_preview(result)
	
	# 更新状态
	var error_count: int = result.errors.size()
	if error_count == 0 and result.anim_count > 0:
		_status_label.text = "Status: ✅ 预览完成，可以扫描"
		_status_label.add_theme_color_override("font_color", Color.GREEN)
		_scan_btn.disabled = false
	elif error_count > 0:
		# 包括 anim_count == 0 且有错误的情况（如验证失败）
		_status_label.text = "Status: ⚠️ 预览失败，有 %d 个错误（详见下方）" % error_count
		_status_label.add_theme_color_override("font_color", Color.ORANGE)
		_scan_btn.disabled = true
	else:
		# anim_count == 0 且无错误
		_status_label.text = "Status: ⚠️ 未找到可处理的动画"
		_status_label.add_theme_color_override("font_color", Color.ORANGE)
		_scan_btn.disabled = true
	
	_preview_btn.disabled = false


func _display_preview(result: Dictionary) -> void:
	var lines := []
	
	# 即使 anim_count == 0，也要显示具体错误（如果有的话）
	# 这样用户能看到验证失败的真正原因（如场景树结构不对）
	if result.anim_count == 0 and result.errors.is_empty():
		lines.append("[color=orange]未找到可处理的动画[/color]")
		lines.append("")
		lines.append("可能原因：")
		lines.append("  • SpriteFrames 中的帧文件名缺少 _physical_ 标注")
		lines.append("  • AnimationPlayer 中没有 AnimatedSprite2D:animation 轨道")
		lines.append("  • 皮肤节点场景树结构不符合预期")
		_preview_label.text = "\n".join(lines)
		return
	
	lines.append("[b]预览结果[/b]")
	lines.append("")
	lines.append("扫描到 [b]%d[/b] 个动画，共 [b]%d[/b] 帧" % [result.anim_count, result.frame_count])
	lines.append("")
	
	# 显示所有会被修改的动画
	if result.has("animations_to_modify") and result.animations_to_modify.size() > 0:
		var will_modify_count: int = result.animations_to_modify.size()
		lines.append("[b]将修改 %d 个动画：[/b]" % will_modify_count)
		for anim_name in result.animations_to_modify:
			lines.append("  • %s" % anim_name)
	
	lines.append("")
	
	# 显示跳跃和击飞 speed 映射
	if result.has("jump_speed_info") and not result.jump_speed_info.is_empty():
		var info: Dictionary = result.jump_speed_info
		
		if info.has("jump"):
			var jump_info: Dictionary = info["jump"]
			lines.append("[b]跳跃力度映射：[/b]")
			lines.append("  动画: %s" % jump_info.get("anim_name", ""))
			lines.append("  speed: %d → jump_force: %d" % [jump_info.get("speed", 0), jump_info.get("jump_force", 0)])
			lines.append("")
		
		if info.has("knockout"):
			var ko_info: Dictionary = info["knockout"]
			lines.append("[b]击飞权重映射：[/b]")
			lines.append("  动画: %s" % ko_info.get("anim_name", ""))
			lines.append("  speed: %.1f → knockback_weight: %.1f" % [ko_info.get("speed", 1.0), ko_info.get("knockback_weight", 1.0)])
			lines.append("")
	
	if result.errors.size() > 0:
		lines.append("[color=red][b]错误（%d 个）：[/b][/color]" % result.errors.size())
		# 显示所有错误
		for error in result.errors:
			lines.append("  ❌ %s" % error)
	
	_preview_label.text = "\n".join(lines)


func _on_scan_pressed() -> void:
	if _skin_node == null:
		return
	
	# 立即禁用两个按钮并改变文本和视觉状态
	_preview_btn.disabled = true
	_scan_btn.disabled = true
	_scan_btn.text = "⏳ 扫描并注入轨道中..."
	_status_label.text = "Status: ⏳ 扫描并注入轨道..."
	_status_label.add_theme_color_override("font_color", Color.YELLOW)
	
	# 等待两帧以确保 UI 状态变化被渲染
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 异步执行扫描（不会阻塞编辑器界面）
	_execute_scan_async()


func _execute_scan_async() -> void:
	var injector := AnimationTrackInjector.new()
	var result = await injector.run_incremental(_skin_node, false, self)
	
	# 显示详细结果（所有动画和错误）
	var error_count: int = result.errors.size()
	var summary_lines := []
	
	summary_lines.append("[b]扫描结果[/b]")
	summary_lines.append("")
	summary_lines.append("扫描到 [b]%d[/b] 个动画，共 [b]%d[/b] 帧" % [result.anim_count, result.frame_count])
	summary_lines.append("")
	
	# 显示所有修改的动画
	if result.has("animations_to_modify") and result.animations_to_modify.size() > 0:
		summary_lines.append("[b]已修改 %d 个动画：[/b]" % result.animations_to_modify.size())
		for anim_name in result.animations_to_modify:
			summary_lines.append("  ✓ %s" % anim_name)
		summary_lines.append("")
	
	# 显示跳跃和击飞 speed 映射
	if result.has("jump_speed_info") and not result.jump_speed_info.is_empty():
		var info: Dictionary = result.jump_speed_info
		
		if info.has("jump"):
			var jump_info: Dictionary = info["jump"]
			summary_lines.append("[b]跳跃力度已更新：[/b]")
			summary_lines.append("  %s: speed %d → jump_force %d" % [
				jump_info.get("anim_name", ""), jump_info.get("speed", 0), jump_info.get("jump_force", 0)])
			summary_lines.append("")
		
		if info.has("knockout"):
			var ko_info: Dictionary = info["knockout"]
			summary_lines.append("[b]击飞权重已更新：[/b]")
			summary_lines.append("  %s: speed %.1f → knockback_weight %.1f" % [
				ko_info.get("anim_name", ""), ko_info.get("speed", 1.0), ko_info.get("knockback_weight", 1.0)])
			summary_lines.append("")
	
	# 显示所有错误
	summary_lines.append("[color=%s]错误数量: %d[/color]" % [
		"green" if error_count == 0 else "red",
		error_count
	])
	
	if error_count > 0:
		for i in range(error_count):
			summary_lines.append("  ❌ %s" % result.errors[i])
	
	_result_label.text = "\n".join(summary_lines)
	
	# 更新状态并重新启用按钮，恢复文本
	_preview_btn.disabled = false
	_scan_btn.text = "▶ 扫描并生成高度轨道"
	_scan_btn.disabled = false  # 允许重新扫描
	
	if error_count == 0:
		_status_label.text = "Status: ✅ 扫描完成，轨道已写入"
		_status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		_status_label.text = "Status: ⚠️ 扫描完成，有 %d 个错误" % error_count
		_status_label.add_theme_color_override("font_color", Color.ORANGE)
	
	# 通知 inspector_plugin
	scan_completed.emit(result.anim_count, result.frame_count, error_count)


## 进度回调（由 injector 调用）
func _on_progress(current: int, total: int, anim_name: String) -> void:
	_scan_btn.text = "⏳ 处理中: %d/%d (%s)" % [current, total, anim_name]
	_status_label.text = "Status: ⏳ 正在处理动画 %d/%d: %s" % [current, total, anim_name]


## 轮廓转换进度回调
func _on_contour_progress(current: int, total: int, filename: String) -> void:
	var mode_text := "Body" if _body_contour_btn.disabled else "Attack"
	_contour_status_label.text = "⏳ %s 转换中: %d 帧 (%s)" % [mode_text, current, filename]


func _on_body_contour_pressed() -> void:
	if _skin_node == null:
		return
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
	_body_contour_btn.disabled = true
	_attack_contour_btn.disabled = true
	_contour_status_label.text = "⏳ Attack 轮廓转换中..."
	_contour_status_label.add_theme_color_override("font_color", Color.CYAN)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	_execute_contour_conversion_async("attack")


func _execute_contour_conversion_async(mode: String) -> void:
	var injector := AnimationTrackInjector.new()
	var alpha_threshold: float = _alpha_threshold_spinbox.value
	var simplify_tolerance: float = _simplify_tolerance_spinbox.value
	
	var result: Dictionary
	if mode == "body":
		result = injector.convert_body_contours(_skin_node, alpha_threshold, simplify_tolerance, false, self)
	else:
		result = injector.convert_attack_contours(_skin_node, alpha_threshold, simplify_tolerance, false, self)
	
	# 显示结果
	var error_count: int = result.errors.size()
	var frame_count: int = result.frame_count
	var rename_count: int = result.png_renames.size()
	
	var lines := []
	lines.append("[b]%s 轮廓转换结果[/b]" % ("Body" if mode == "body" else "Attack"))
	lines.append("")
	lines.append("处理帧数: [b]%d[/b]" % frame_count)
	lines.append("PNG 重命名: [b]%d[/b] 个" % rename_count)
	lines.append("")
	
	if error_count == 0:
		lines.append("[color=green]✅ 转换完成，无错误[/color]")
	else:
		lines.append("[color=red]❌ 有 %d 个错误：[/color]" % error_count)
		for error in result.errors:
			lines.append("  • %s" % error)
	
	_contour_result_label.text = "\n".join(lines)
	
	# 恢复按钮状态
	_body_contour_btn.disabled = false
	_attack_contour_btn.disabled = false
	
	if error_count == 0:
		_contour_status_label.text = "✅ %s 转换完成" % ("Body" if mode == "body" else "Attack")
		_contour_status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		_contour_status_label.text = "⚠️ %s 转换完成，有 %d 个错误" % ["Body" if mode == "body" else "Attack", error_count]
		_contour_status_label.add_theme_color_override("font_color", Color.ORANGE)
	
	scan_completed.emit(0, frame_count, error_count)


## 构建单文件测试 UI
func _build_test_ui() -> void:
	var test_header := Label.new()
	test_header.text = "🧪 单文件测试"
	test_header.add_theme_font_size_override("font_size", 16)
	add_child(test_header)
	
	add_child(HSeparator.new())
	
	# 文件选择行
	var file_row := HBoxContainer.new()
	add_child(file_row)
	
	var file_label := Label.new()
	file_label.text = "PNG 文件:"
	file_label.custom_minimum_size.x = 80
	file_row.add_child(file_label)
	
	_test_file_path = LineEdit.new()
	_test_file_path.placeholder_text = "选择 PNG 文件..."
	_test_file_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_test_file_path.editable = false
	file_row.add_child(_test_file_path)
	
	_test_file_btn = Button.new()
	_test_file_btn.text = "浏览"
	_test_file_btn.pressed.connect(_on_test_file_btn_pressed)
	file_row.add_child(_test_file_btn)
	
	# 测试按钮行
	var test_btn_row := HBoxContainer.new()
	add_child(test_btn_row)
	
	_test_body_btn = Button.new()
	_test_body_btn.text = "测试 Body"
	_test_body_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_test_body_btn.disabled = true
	_test_body_btn.pressed.connect(_on_test_body_btn_pressed)
	test_btn_row.add_child(_test_body_btn)
	
	_test_attack_btn = Button.new()
	_test_attack_btn.text = "测试 Attack"
	_test_attack_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_test_attack_btn.disabled = true
	_test_attack_btn.pressed.connect(_on_test_attack_btn_pressed)
	test_btn_row.add_child(_test_attack_btn)
	
	# 结果显示
	_test_result_label = RichTextLabel.new()
	_test_result_label.bbcode_enabled = true
	_test_result_label.text = "[color=gray]选择文件后点击测试按钮[/color]"
	_test_result_label.custom_minimum_size = Vector2(0, 150)
	add_child(_test_result_label)
	
	add_child(HSeparator.new())


## 文件选择按钮点击
func _on_test_file_btn_pressed() -> void:
	var file_dialog := FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.filters = ["*.png ; PNG Images"]
	file_dialog.current_dir = "res://characters/playable/"
	
	file_dialog.file_selected.connect(func(path: String):
		_test_file_path.text = path
		_test_body_btn.disabled = false
		_test_attack_btn.disabled = false
		file_dialog.queue_free()
	)
	
	file_dialog.canceled.connect(func():
		file_dialog.queue_free()
	)
	
	add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(800, 600))


## 测试 Body 按钮点击
func _on_test_body_btn_pressed() -> void:
	_run_single_file_test("body")


## 测试 Attack 按钮点击
func _on_test_attack_btn_pressed() -> void:
	_run_single_file_test("attack")


## 执行单文件测试
func _run_single_file_test(test_type: String) -> void:
	if _skin_node == null:
		_test_result_label.text = "[color=red]错误: 未关联皮肤节点[/color]"
		return
	
	var file_path := _test_file_path.text
	if file_path.is_empty():
		_test_result_label.text = "[color=red]错误: 未选择文件[/color]"
		return
	
	# 禁用按钮
	_test_body_btn.disabled = true
	_test_attack_btn.disabled = true
	_test_result_label.text = "[color=cyan]测试中...[/color]"
	
	# 等待两帧确保 UI 更新
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 获取参数
	var alpha_threshold: float = _alpha_threshold_spinbox.value
	var simplify_tolerance: float = _simplify_tolerance_spinbox.value
	
	# 执行测试
	var injector := AnimationTrackInjector.new()
	var result := injector.test_single_file(file_path, test_type, alpha_threshold, simplify_tolerance, _skin_node)
	
	# 显示结果
	_display_test_result(result)
	
	# 恢复按钮
	_test_body_btn.disabled = false
	_test_attack_btn.disabled = false


## 显示测试结果
func _display_test_result(result: Dictionary) -> void:
	var lines := []
	
	if result.error != "":
		lines.append("[color=red]错误: %s[/color]" % result.error)
		_test_result_label.text = "\n".join(lines)
		return
	
	lines.append("[b]文件名:[/b] %s" % result.file_name)
	lines.append("[b]图片尺寸:[/b] %d × %d" % [result.image_size.x, result.image_size.y])
	lines.append("[b]提取轮廓数:[/b] %d" % result.contour_count)
	lines.append("[b]顶点总数:[/b] %d" % result.total_vertices)
	lines.append("[b]Mask 文件:[/b] %s" % ("有" if result.has_mask else "无"))
	lines.append("")
	
	if result.type == "body":
		lines.append("[b]类型:[/b] Body")
		lines.append("[b]physical_height:[/b] %.1f" % result.physical_height)
	elif result.type == "attack":
		lines.append("[b]类型:[/b] Attack")
		var heights_str := ""
		for i in range(result.attack_heights.size()):
			if i > 0:
				heights_str += ", "
			heights_str += "%.1f" % result.attack_heights[i]
		lines.append("[b]attack_heights:[/b] [%s]" % heights_str)
	
	lines.append("")
	lines.append("[b]转换后坐标范围:[/b]")
	lines.append("  X: %.1f ~ %.1f" % [result.bounding_box.position.x, result.bounding_box.position.x + result.bounding_box.size.x])
	lines.append("  Y: %.1f ~ %.1f" % [result.bounding_box.position.y, result.bounding_box.position.y + result.bounding_box.size.y])
	lines.append("")
	lines.append("[b]参数:[/b] alpha=%.1f, tolerance=%.1f" % [result.alpha_threshold, result.simplify_tolerance])
	
	_test_result_label.text = "\n".join(lines)

### -----------------------------------------------------------------------------------------------
