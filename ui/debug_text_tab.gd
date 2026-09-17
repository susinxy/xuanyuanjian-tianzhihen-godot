extends ScrollContainer

## 调试坞文字页签（DebugDock 内部件）：RichTextLabel + 行生产者拉取刷新。
## 刷新由 Dock 统一 0.15s 驱动；本控件只负责排版与容错
## （provider 抛错=该行显示错误文本，不炸窗口——调试工具自己不能成为事故源）。
## 显示契约（2026-09-16 三缺陷定档）：
## ①默认主题字色是黑的，压在暗色坞底上=黑纸黑字——必须显式浅色 override；
## ②RichTextLabel 放进允许横滚的容器会宽度塌陷（无界宽不换行）——横向滚动
##   关死、标签横向撑满，纵向滚动独活；
## ③fit_content=false 时标签自报最小高=0，容器认为零溢出——滚动条不出现、
##   滚轮无范围可滚（滚轮悬案真凶，headless 全树取证实测 text1439字/
##   内容高1600 而 min高=0 定案）；必须 fit_content=true。

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
	# 滚轮穿透：标签不截鼠标事件（真凶是上面的 fit_content，穿透是同伴契约，
	# 两者缺一都滚不动）。只读面板无选中需求，IGNORE 让事件直达滚动容器。
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.fit_content = true
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
