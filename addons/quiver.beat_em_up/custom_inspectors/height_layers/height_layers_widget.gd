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
	
	# 预览展示（RichTextLabel 支持 BBCode）
	_preview_label = RichTextLabel.new()
	_preview_label.bbcode_enabled = true
	_preview_label.fit_content = true
	_preview_label.custom_minimum_size.y = 100
	_preview_label.text = ""
	add_child(_preview_label)
	
# 结果展示
var result_container := VBoxContainer.new()
add_child(result_container)

# 可折叠的标题按钮
var collapse_btn := Button.new()
collapse_btn.text = "▼ 修改预览（点击展开/折叠）"
collapse_btn.pressed.connect(_on_collapse_toggle)
result_container.add_child(collapse_btn)

# 折叠的内容容器
var details_container := VBoxContainer.new()
result_container.add_child(details_container)

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

# 折叠控件引用
_collapse_btn_ref = collapse_btn
_details_container_ref = details_container
_is_collapsed = false


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
		return
	
	_status_label.text = "Status: ✅ 已关联: %s" % _skin_node.name
	_status_label.add_theme_color_override("font_color", Color.GREEN)
	_preview_btn.disabled = false
	# 扫描按钮需要先完成预览
	_scan_btn.disabled = (_last_preview_result == null or _last_preview_result.is_empty())


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
	elif result.anim_count == 0:
		_status_label.text = "Status: ⚠️ 未找到可处理的动画"
		_status_label.add_theme_color_override("font_color", Color.ORANGE)
		_scan_btn.disabled = true
	else:
		_status_label.text = "Status: ⚠️ 预览完成，有 %d 个错误" % error_count
		_status_label.add_theme_color_override("font_color", Color.ORANGE)
		_scan_btn.disabled = true
	
	_preview_btn.disabled = false


func _display_preview(result: Dictionary) -> void:
	var lines := []
	
	if result.anim_count == 0:
		lines.append("[color=orange]未找到可处理的动画[/color]")
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
	
	if result.errors.size() > 0:
		lines.append("[color=red][b]错误（%d 个）：[/b][/color]" % result.errors.size())
		# 显示所有错误
		for error in result.errors:
			lines.append("  ❌ %s" % error)
	
	_preview_label.text = "\n".join(lines)


func _on_scan_pressed() -> void:
	if _skin_node == null:
		return
	
	# 扫描期间禁用两个按钮并改变文本
	_preview_btn.text = "⏳ 预览中..."
	_preview_btn.disabled = true
	_scan_btn.text = "⏳ 扫描并注入轨道中..."
	_scan_btn.disabled = true
	_status_label.text = "Status: ⏳ 扫描并注入轨道..."
	_status_label.add_theme_color_override("font_color", Color.YELLOW)
	
	# 调用扫描器（实际执行）
	var injector := AnimationTrackInjector.new()
	var result := injector.run(_skin_node, false)  # false = 实际执行
	
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
	_preview_btn.text = "🔍 预览"
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

### -----------------------------------------------------------------------------------------------
