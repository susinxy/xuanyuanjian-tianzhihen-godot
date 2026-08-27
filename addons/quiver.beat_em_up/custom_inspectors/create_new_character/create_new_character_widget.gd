@tool
extends VBoxContainer
## Character Creator Widget
## Provides UI for creating and deleting characters from template.

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

signal character_created(char_name: String)
signal character_deleted(char_name: String)
signal character_test_requested(char_name: String)

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const CHARACTER_DIR = "res://characters/playable/"
const TEMPLATE_DIR = "res://characters/playable/_template/"

#--- public variables - order: export > normal var & onready --------------------------------------

#--- private variables - order: export > normal var & onready -------------------------------------

var _char_name_edit: LineEdit
var _class_name_edit: LineEdit
var _display_name_edit: LineEdit
var _faction_option: OptionButton
var _move_speed_spin: SpinBox
var _health_max_spin: SpinBox
var _air_control_spin: SpinBox
var _hit_lane_offset_spin: SpinBox
var _status_label: Label
var _create_btn: Button

var _delete_dropdown: OptionButton
var _delete_path_label: Label
var _delete_btn: Button

var _test_dropdown: OptionButton
var _test_btn: Button

var _is_updating_class_name := false
var _is_processing := false  # 防止创建/删除过程中清空字段触发验证

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	
	_build_ui()
	_refresh_character_list()
	
	# Listen to filesystem changes to update delete dropdown
	if EditorInterface.get_resource_filesystem():
		EditorInterface.get_resource_filesystem().filesystem_changed.connect(_refresh_character_list)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if EditorInterface.get_resource_filesystem():
			if EditorInterface.get_resource_filesystem().filesystem_changed.is_connected(_refresh_character_list):
				EditorInterface.get_resource_filesystem().filesystem_changed.disconnect(_refresh_character_list)

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _build_ui() -> void:
	# Create section
	var create_header := Label.new()
	create_header.text = "🎭 Create New Character"
	create_header.add_theme_font_size_override("font_size", 16)
	add_child(create_header)
	
	add_child(HSeparator.new())
	
	# English Name input
	var hbox1 := HBoxContainer.new()
	var label1 := Label.new()
	label1.text = "English Name:"
	label1.custom_minimum_size.x = 120
	hbox1.add_child(label1)
	_char_name_edit = LineEdit.new()
	_char_name_edit.placeholder_text = "yu_xiaoxue"
	_char_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_char_name_edit.text_changed.connect(_on_char_name_changed)
	hbox1.add_child(_char_name_edit)
	add_child(hbox1)
	
	# Class Name input (auto-generated)
	var hbox2 := HBoxContainer.new()
	var label2 := Label.new()
	label2.text = "Class Name:"
	label2.custom_minimum_size.x = 120
	hbox2.add_child(label2)
	_class_name_edit = LineEdit.new()
	_class_name_edit.placeholder_text = "YuXiaoxue (auto)"
	_class_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_class_name_edit.text_changed.connect(_on_class_name_changed)
	hbox2.add_child(_class_name_edit)
	add_child(hbox2)
	
	# Display Name input
	var hbox3 := HBoxContainer.new()
	var label3 := Label.new()
	label3.text = "Display Name:"
	label3.custom_minimum_size.x = 120
	hbox3.add_child(label3)
	_display_name_edit = LineEdit.new()
	_display_name_edit.placeholder_text = "于小雪"
	_display_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_display_name_edit.text_changed.connect(_on_display_name_changed)
	hbox3.add_child(_display_name_edit)
	add_child(hbox3)
	
	# Faction dropdown
	var hbox_faction := HBoxContainer.new()
	var label_faction := Label.new()
	label_faction.text = "阵营:"
	label_faction.custom_minimum_size.x = 120
	hbox_faction.add_child(label_faction)
	_faction_option = OptionButton.new()
	_faction_option.add_item("players", 0)
	_faction_option.add_item("enemies", 1)
	_faction_option.select(0)
	_faction_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_faction.add_child(_faction_option)
	add_child(hbox_faction)
	var faction_hint := Label.new()
	faction_hint.text = "角色阵营，决定根节点 group（players/enemies）"
	faction_hint.add_theme_color_override("font_color", Color.GRAY)
	faction_hint.add_theme_font_size_override("font_size", 12)
	add_child(faction_hint)
	
	# Move Speed input
	var hbox_move_speed := HBoxContainer.new()
	var label_move_speed := Label.new()
	label_move_speed.text = "移动速度:"
	label_move_speed.custom_minimum_size.x = 120
	hbox_move_speed.add_child(label_move_speed)
	_move_speed_spin = SpinBox.new()
	_move_speed_spin.min_value = 0
	_move_speed_spin.max_value = 2000
	_move_speed_spin.step = 10
	_move_speed_spin.value = 600
	_move_speed_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_move_speed.add_child(_move_speed_spin)
	add_child(hbox_move_speed)
	var move_speed_hint := Label.new()
	move_speed_hint.text = "地面移动速度（像素/秒）"
	move_speed_hint.add_theme_color_override("font_color", Color.GRAY)
	move_speed_hint.add_theme_font_size_override("font_size", 12)
	add_child(move_speed_hint)
	
	# Health Max input
	var hbox_health_max := HBoxContainer.new()
	var label_health_max := Label.new()
	label_health_max.text = "最大生命值:"
	label_health_max.custom_minimum_size.x = 120
	hbox_health_max.add_child(label_health_max)
	_health_max_spin = SpinBox.new()
	_health_max_spin.min_value = 1
	_health_max_spin.max_value = 9999
	_health_max_spin.step = 10
	_health_max_spin.value = 100
	_health_max_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_health_max.add_child(_health_max_spin)
	add_child(hbox_health_max)
	var health_max_hint := Label.new()
	health_max_hint.text = "角色的最大生命值"
	health_max_hint.add_theme_color_override("font_color", Color.GRAY)
	health_max_hint.add_theme_font_size_override("font_size", 12)
	add_child(health_max_hint)
	
	# Air Control input
	var hbox_air_control := HBoxContainer.new()
	var label_air_control := Label.new()
	label_air_control.text = "空中控制:"
	label_air_control.custom_minimum_size.x = 120
	hbox_air_control.add_child(label_air_control)
	_air_control_spin = SpinBox.new()
	_air_control_spin.min_value = 0.0
	_air_control_spin.max_value = 1.0
	_air_control_spin.step = 0.1
	_air_control_spin.value = 0.6
	_air_control_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_air_control.add_child(_air_control_spin)
	add_child(hbox_air_control)
	var air_control_hint := Label.new()
	air_control_hint.text = "空中控制灵活性（0=无法控制，1=和地面一样灵活）"
	air_control_hint.add_theme_color_override("font_color", Color.GRAY)
	air_control_hint.add_theme_font_size_override("font_size", 12)
	add_child(air_control_hint)
	
	# Hit Lane Offset input
	var hbox_hit_lane := HBoxContainer.new()
	var label_hit_lane := Label.new()
	label_hit_lane.text = "攻击范围调整:"
	label_hit_lane.custom_minimum_size.x = 120
	hbox_hit_lane.add_child(label_hit_lane)
	_hit_lane_offset_spin = SpinBox.new()
	_hit_lane_offset_spin.min_value = -100
	_hit_lane_offset_spin.max_value = 100
	_hit_lane_offset_spin.step = 5
	_hit_lane_offset_spin.value = 0
	_hit_lane_offset_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_hit_lane.add_child(_hit_lane_offset_spin)
	add_child(hbox_hit_lane)
	var hit_lane_hint := Label.new()
	hit_lane_hint.text = "调整攻击的Y轴判定范围（正值扩大，负值缩小）"
	hit_lane_hint.add_theme_color_override("font_color", Color.GRAY)
	hit_lane_hint.add_theme_font_size_override("font_size", 12)
	add_child(hit_lane_hint)
	
	# Status label
	_status_label = Label.new()
	_status_label.text = "Status: ⏳ Waiting for input..."
	_status_label.add_theme_color_override("font_color", Color.GRAY)
	add_child(_status_label)
	
	# Create button
	_create_btn = Button.new()
	_create_btn.text = "Create Character ▶"
	_create_btn.disabled = true
	_create_btn.pressed.connect(_on_create_pressed)
	add_child(_create_btn)
	
	add_child(HSeparator.new())
	
	# Delete section
	var delete_header := Label.new()
	delete_header.text = "🗑️ Delete Character"
	delete_header.add_theme_font_size_override("font_size", 16)
	add_child(delete_header)
	
	add_child(HSeparator.new())
	
	# Delete dropdown
	var hbox4 := HBoxContainer.new()
	var label4 := Label.new()
	label4.text = "Select:"
	label4.custom_minimum_size.x = 120
	hbox4.add_child(label4)
	_delete_dropdown = OptionButton.new()
	_delete_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_delete_dropdown.item_selected.connect(_on_delete_dropdown_selected)
	hbox4.add_child(_delete_dropdown)
	add_child(hbox4)
	
	# Delete path warning
	_delete_path_label = Label.new()
	_delete_path_label.text = ""
	_delete_path_label.add_theme_color_override("font_color", Color.ORANGE)
	add_child(_delete_path_label)
	
	# Delete button
	_delete_btn = Button.new()
	_delete_btn.text = "Delete 🗑️"
	_delete_btn.disabled = true
	_delete_btn.modulate = Color(1.0, 0.4, 0.4)
	_delete_btn.pressed.connect(_on_delete_pressed)
	add_child(_delete_btn)
	
	add_child(HSeparator.new())
	
	# Test section
	var test_header := Label.new()
	test_header.text = "🧪 Test Character"
	test_header.add_theme_font_size_override("font_size", 16)
	add_child(test_header)
	
	add_child(HSeparator.new())
	
	# Test dropdown
	var hbox5 := HBoxContainer.new()
	var label5 := Label.new()
	label5.text = "Select:"
	label5.custom_minimum_size.x = 120
	hbox5.add_child(label5)
	_test_dropdown = OptionButton.new()
	_test_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_test_dropdown.item_selected.connect(_on_test_dropdown_selected)
	hbox5.add_child(_test_dropdown)
	add_child(hbox5)
	
	# Test button
	_test_btn = Button.new()
	_test_btn.text = "Run Test ▶"
	_test_btn.disabled = true
	_test_btn.modulate = Color(0.4, 0.8, 0.4)
	_test_btn.pressed.connect(_on_test_pressed)
	add_child(_test_btn)
	
	# Test info label
	var test_info := Label.new()
	test_info.text = "生成临时测试场景并运行，按 ESC 退出测试"
	test_info.add_theme_color_override("font_color", Color.GRAY)
	add_child(test_info)


func _refresh_character_list() -> void:
	if not is_instance_valid(_delete_dropdown):
		return
	
	_delete_dropdown.clear()
	_delete_btn.disabled = true
	_delete_path_label.text = ""
	
	if is_instance_valid(_test_dropdown):
		_test_dropdown.clear()
		_test_btn.disabled = true
	
	var dir := DirAccess.open(CHARACTER_DIR)
	if dir == null:
		_delete_dropdown.selected = -1
		if is_instance_valid(_test_dropdown):
			_test_dropdown.selected = -1
		return
	
	var characters := []
	dir.list_dir_begin()
	var folder_name := dir.get_next()
	while not folder_name.is_empty():
		if dir.current_is_dir() and folder_name != "." and folder_name != ".." and folder_name != "_template":
			# Try to read display name from attributes file
			var attrs_path = CHARACTER_DIR.path_join(folder_name).path_join("resources").path_join(folder_name + "_attributes.tres")
			var display_name := ""
			if FileAccess.file_exists(attrs_path):
				var file := FileAccess.open(attrs_path, FileAccess.READ)
				if file:
					var content := file.get_as_text()
					var match_str := 'display_name = "'
					var start := content.find(match_str)
					if start != -1:
						start += match_str.length()
						var end := content.find('"', start)
						if end != -1:
							display_name = content.substr(start, end - start)
			
			if display_name.is_empty():
				display_name = folder_name
			
			characters.append({"name": folder_name, "display": display_name})
		
		folder_name = dir.get_next()
	
	# Sort by English name (stable)
	characters.sort_custom(func(a, b): return a.name < b.name)
	
	for char_data in characters:
		var item_text = "%s (%s)" % [char_data.display, char_data.name]
		_delete_dropdown.add_item(item_text)
		_delete_dropdown.set_item_metadata(_delete_dropdown.item_count - 1, char_data.name)
		
		if is_instance_valid(_test_dropdown):
			_test_dropdown.add_item(item_text)
			_test_dropdown.set_item_metadata(_test_dropdown.item_count - 1, char_data.name)
	
	# Force no selection AFTER all items are added
	# (OptionButton auto-selects index 0 on first add_item)
	_delete_dropdown.selected = -1
	if is_instance_valid(_test_dropdown):
		_test_dropdown.selected = -1


func _validate_snake_case(text: String) -> bool:
	if text.is_empty():
		return false
	if text.begins_with("_") or text.ends_with("_"):
		return false
	if text.find("__") != -1:
		return false
	
	var regex := RegEx.new()
	regex.compile("^[a-z][a-z0-9_]*$")
	return regex.search(text) != null


func _validate_pascal_case(text: String) -> bool:
	if text.is_empty():
		return false
	if text[0].to_upper() != text[0]:
		return false
	
	var regex := RegEx.new()
	regex.compile("^[A-Z][a-zA-Z0-9]*$")
	return regex.search(text) != null


func _auto_generate_class_name(snake: String) -> String:
	var parts := snake.split("_")
	var result := ""
	for part in parts:
		if part.length() > 0:
			result += part[0].to_upper() + part.substr(1).to_lower()
	return result


func _char_name_exists(name: String) -> bool:
	var path := CHARACTER_DIR.path_join(name)
	return DirAccess.dir_exists_absolute(path)


func _validate_all_inputs() -> bool:
	var char_name := _char_name_edit.text
	var pascal_name := _class_name_edit.text
	var display_name := _display_name_edit.text
	
	# Validate English name
	if not _validate_snake_case(char_name):
		_status_label.text = "Status: ❌ English name must be snake_case (letters, numbers, underscores only, start with lowercase letter)"
		_status_label.add_theme_color_override("font_color", Color.RED)
		return false
	
	if _char_name_exists(char_name):
		_status_label.text = "Status: ❌ Character '%s' already exists!" % char_name
		_status_label.add_theme_color_override("font_color", Color.RED)
		return false
	
	# Validate Class name
	if not _validate_pascal_case(pascal_name):
		_status_label.text = "Status: ❌ Class name must be PascalCase (start with uppercase letter, no underscores)"
		_status_label.add_theme_color_override("font_color", Color.RED)
		return false
	
	# Validate Display name
	if display_name.is_empty():
		_status_label.text = "Status: ❌ Display name cannot be empty"
		_status_label.add_theme_color_override("font_color", Color.RED)
		return false
	
	# All valid
	_status_label.text = "Status: ✅ Ready to create: %s (%s)" % [pascal_name, display_name]
	_status_label.add_theme_color_override("font_color", Color.GREEN)
	return true


func _on_char_name_changed(new_text: String) -> void:
	if _is_processing:
		return
	# Auto-generate class name
	if not _is_updating_class_name:
		_is_updating_class_name = true
		_class_name_edit.text = _auto_generate_class_name(new_text)
		_is_updating_class_name = false
	
	_validate_all_inputs()
	_create_btn.disabled = not _validate_all_inputs()


func _on_class_name_changed(new_text: String) -> void:
	if _is_processing:
		return
	_validate_all_inputs()
	_create_btn.disabled = not _validate_all_inputs()


func _on_display_name_changed(new_text: String) -> void:
	if _is_processing:
		return
	_validate_all_inputs()
	_create_btn.disabled = not _validate_all_inputs()


func _on_create_pressed() -> void:
	_is_processing = true
	_create_btn.disabled = true
	_status_label.text = "Status: ⏳ Creating character..."
	_status_label.add_theme_color_override("font_color", Color.YELLOW)
	
	# 让出一帧，让 UI 重绘按钮变灰和状态文本
	await get_tree().process_frame
	
	var char_name := _char_name_edit.text
	var pascal_name := _class_name_edit.text
	var display_name := _display_name_edit.text
	var faction := _faction_option.get_item_text(_faction_option.selected)
	var move_speed := _move_speed_spin.value
	var health_max := int(_health_max_spin.value)
	var air_control := _air_control_spin.value
	var hit_lane_offset := int(_hit_lane_offset_spin.value)
	
	var creator := CharacterCreator.new()
	var success := creator.create_character(
		char_name, pascal_name, display_name,
		faction, move_speed, health_max, air_control, hit_lane_offset
	)
	
	if success:
		_status_label.text = "Status: ✅ Character '%s' created successfully!" % display_name
		_status_label.add_theme_color_override("font_color", Color.GREEN)
		
		# Clear inputs
		_char_name_edit.text = ""
		_class_name_edit.text = ""
		_display_name_edit.text = ""
		_faction_option.select(0)
		_move_speed_spin.value = 600
		_health_max_spin.value = 100
		_air_control_spin.value = 0.6
		_hit_lane_offset_spin.value = 0
		_create_btn.disabled = true
		
		# Refresh filesystem
		EditorInterface.get_resource_filesystem().scan()
		
		character_created.emit(char_name)
	else:
		_status_label.text = "Status: ❌ Failed to create character. Check console for errors."
		_status_label.add_theme_color_override("font_color", Color.RED)
		_create_btn.disabled = not _validate_all_inputs()
	
	_is_processing = false


func _on_delete_dropdown_selected(index: int) -> void:
	if index < 0:
		_delete_btn.disabled = true
		_delete_path_label.text = ""
		return
	
	var char_name := _delete_dropdown.get_item_metadata(index) as String
	_delete_path_label.text = "⚠️ This will permanently delete: %s" % [CHARACTER_DIR.path_join(char_name)]
	_delete_btn.disabled = false


func _on_delete_pressed() -> void:
	var index := _delete_dropdown.selected
	if index < 0:
		return
	
	var char_name := _delete_dropdown.get_item_metadata(index) as String
	
	# Show confirmation dialog
	var confirm_dialog := ConfirmationDialog.new()
	confirm_dialog.title = "Delete Character"
	confirm_dialog.dialog_text = "确定删除角色 %s？此操作不可逆。" % char_name
	confirm_dialog.confirmed.connect(_on_delete_confirmed.bind(char_name))
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()


func _on_delete_confirmed(char_name: String) -> void:
	_is_processing = true
	_delete_btn.disabled = true
	_status_label.text = "Status: ⏳ Deleting character..."
	_status_label.add_theme_color_override("font_color", Color.YELLOW)
	
	# 让出一帧，让 UI 重绘按钮变灰和状态文本
	await get_tree().process_frame
	
	var deleter := CharacterDeleter.new()
	var success := deleter.delete_character(char_name)
	
	if success:
		_status_label.text = "Status: ✅ Character '%s' deleted successfully!" % char_name
		_status_label.add_theme_color_override("font_color", Color.GREEN)
		
		# Reset dropdown
		_delete_dropdown.selected = -1
		_delete_btn.disabled = true
		_delete_path_label.text = ""
		
		# Refresh filesystem (will auto-update dropdown)
		EditorInterface.get_resource_filesystem().scan()
		
		character_deleted.emit(char_name)
	else:
		_status_label.text = "Status: ❌ Failed to delete character. Check console for errors."
		_status_label.add_theme_color_override("font_color", Color.RED)
		_delete_btn.disabled = _delete_dropdown.selected < 0
	
	_is_processing = false


func _on_test_dropdown_selected(index: int) -> void:
	if index < 0:
		_test_btn.disabled = true
		return
	_test_btn.disabled = false


func _on_test_pressed() -> void:
	var index := _test_dropdown.selected
	if index < 0:
		return
	
	var char_name := _test_dropdown.get_item_metadata(index) as String
	_status_label.text = "Status: 🧪 Testing character '%s'..." % char_name
	_status_label.add_theme_color_override("font_color", Color.CYAN)
	
	character_test_requested.emit(char_name)

### -----------------------------------------------------------------------------------------------
