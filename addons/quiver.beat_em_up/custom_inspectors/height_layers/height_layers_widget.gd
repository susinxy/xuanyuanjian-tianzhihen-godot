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

var _scan_btn: Button
var _status_label: Label
var _result_label: Label

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
	desc.text = "扫描动画帧文件名中的 physical_/attack_/speed_ 标注，生成高度轨道。"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_color_override("font_color", Color.GRAY)
	add_child(desc)
	
	# 状态标签
	_status_label = Label.new()
	_status_label.text = "等待扫描..."
	_status_label.add_theme_color_override("font_color", Color.GRAY)
	add_child(_status_label)
	
	# 扫描按钮
	_scan_btn = Button.new()
	_scan_btn.text = "扫描并生成高度轨道 ▶"
	_scan_btn.pressed.connect(_on_scan_pressed)
	add_child(_scan_btn)
	
	# 结果展示
	_result_label = Label.new()
	_result_label.text = ""
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_result_label)


func _update_status() -> void:
	if _skin_node == null:
		_status_label.text = "Status: ⚠️ 未关联皮肤节点"
		_status_label.add_theme_color_override("font_color", Color.ORANGE)
		_scan_btn.disabled = true
		return
	
	_status_label.text = "Status: ✅ 已关联: %s" % _skin_node.name
	_status_label.add_theme_color_override("font_color", Color.GREEN)
	_scan_btn.disabled = false


func _on_scan_pressed() -> void:
	if _skin_node == null:
		return
	
	_status_label.text = "Status: 🔍 扫描中..."
	_status_label.add_theme_color_override("font_color", Color.CYAN)
	_scan_btn.disabled = true
	
	# 调用扫描器
	var injector := AnimationTrackInjector.new()
	var result := injector.run(_skin_node)
	
	# 显示结果
	var error_count: int = result.errors.size()
	var summary_lines := [
		"扫描结果:",
		"  - 动画数: %d" % result.anim_count,
		"  - 帧数:   %d" % result.frame_count,
		"  - 错误:   %d" % error_count,
	]
	
	# 附加错误详情（最多显示 5 个）
	if error_count > 0:
		summary_lines.append("")
		summary_lines.append("错误示例（最多 5 个）:")
		for i in range(min(5, error_count)):
			summary_lines.append("  ❌ %s" % result.errors[i])
		if error_count > 5:
			summary_lines.append("  ... 还有 %d 个" % (error_count - 5))
	
	_result_label.text = "\n".join(summary_lines)
	
	# 更新状态颜色和文本
	if error_count == 0:
		_status_label.text = "Status: ✅ 扫描完成，轨道已写入"
		_status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		_status_label.text = "Status: ⚠️ 扫描完成，有 %d 个错误" % error_count
		_status_label.add_theme_color_override("font_color", Color.ORANGE)
	
	_scan_btn.disabled = false
	
	# 通知 inspector_plugin
	scan_completed.emit(result.anim_count, result.frame_count, error_count)

### -----------------------------------------------------------------------------------------------
