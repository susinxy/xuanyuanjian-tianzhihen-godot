extends VBoxContainer
## 菜单数据驱动条目：add_entry 唯一入口，未来"设置/玩法说明"=加一行数据；
## 焦点样式归 theme，脚本不碰视觉。

func add_entry(label: String, callback: Callable, enabled := true) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.disabled = not enabled
	if callback.is_valid():
		btn.pressed.connect(callback)
	add_child(btn)
	if enabled:
		btn.grab_focus()
	return btn
