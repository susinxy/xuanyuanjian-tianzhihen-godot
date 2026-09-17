extends ScrollContainer

## 调试坞文字页签（DebugDock 内部件）：RichTextLabel + 行生产者拉取刷新。
## 刷新由 Dock 统一 0.15s 驱动；本控件只负责排版与容错
## （provider 抛错=该行显示错误文本，不炸窗口——调试工具自己不能成为事故源）。
## 显示契约（2026-09-16 双缺陷定档）：默认主题字色是黑的，压在暗色坞底上
## =黑纸黑字——必须显式浅色 override；RichTextLabel 放进允许横滚的容器会
## 宽度塌陷（无界宽不换行）——横向滚动关死、标签横向撑满，纵向滚动独活。

var _provider: Callable = Callable()
var _label: RichTextLabel


func setup(_title: String, provider: Callable) -> void:
	_provider = provider
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	focus_mode = Control.FOCUS_NONE
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.focus_mode = Control.FOCUS_NONE
	_label.scroll_active = false
	# 滚轮穿透（2026-09-16 定档）：RichTextLabel 默认接收鼠标，滚轮被它
	# 截获而自身 scroll_active=false 不滚——外层 ScrollContainer 永远收不到，
	# 两头皆哑。只读信息面板无选中需求，标签必须 IGNORE 让事件穿透。
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label.add_theme_color_override("default_color", Color(0.92, 0.94, 1.0))
	_label.add_theme_font_size_override("normal_font_size", 14)
	add_child(_label)


func refresh_from_provider() -> void:
	if not _provider.is_valid():
		return
	var lines: PackedStringArray = []
	var out = _provider.call()
	if out is Array:
		for item in out:
			lines.append(str(item))
	elif out is String:
		lines.append(out)
	if lines.is_empty():
		_label.add_theme_color_override("default_color", Color(0.6, 0.62, 0.66))
		_label.text = "（该页暂无数据）"
		return
	_label.add_theme_color_override("default_color", Color(0.92, 0.94, 1.0))
	_label.text = "\n".join(lines)
