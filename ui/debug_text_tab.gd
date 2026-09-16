extends ScrollContainer

## 调试坞文字页签（DebugDock 内部件）：RichTextLabel + 行生产者拉取刷新。
## 刷新由 Dock 统一 0.15s 驱动；本控件只负责排版与容错
## （provider 抛错=该行显示错误文本，不炸窗口——调试工具自己不能成为事故源）。

var _provider: Callable = Callable()
var _label: RichTextLabel


func setup(_title: String, provider: Callable) -> void:
	_provider = provider
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	focus_mode = Control.FOCUS_NONE
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.focus_mode = Control.FOCUS_NONE
	_label.scroll_active = false
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	_label.text = "\n".join(lines)
