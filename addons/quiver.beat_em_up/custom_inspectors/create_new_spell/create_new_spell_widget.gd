@tool
extends VBoxContainer
## Spell Creator Widget
## Provides UI for creating and deleting spells from template.

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

signal spell_created(spell_name: String)
signal spell_deleted(spell_name: String)
signal spell_test_requested(char_name: String, spell_name: String)

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const SPELL_DIR = "res://spells/"
const CHARACTER_DIR = "res://characters/playable/"

#--- public variables - order: export > normal var & onready --------------------------------------

#--- private variables - order: export > normal var & onready -------------------------------------

var _spell_name_edit: LineEdit
var _class_name_edit: LineEdit
var _display_name_edit: LineEdit
# 出生数值控件（2026-09-18 与角色线拉齐：默认表读 SpellCreator，三处同源）
var _desc_edit: LineEdit
var _mana_cost_spin: SpinBox
var _lifetime_spin: SpinBox
var _cooldown_spin: SpinBox
var _cast_time_spin: SpinBox
var _release_x_spin: SpinBox
var _release_y_spin: SpinBox
var _fade_in_spin: SpinBox
var _fade_out_spin: SpinBox
var _allowed_edit: LineEdit
var _disallowed_edit: LineEdit
var _atk_damage_spin: SpinBox
var _atk_hurt_option: OptionButton
var _atk_knock_spin: SpinBox
var _atk_angle_spin: SpinBox
var _status_label: Label
var _create_btn: Button

var _delete_dropdown: OptionButton
var _delete_path_label: Label
var _delete_btn: Button

var _test_char_dropdown: OptionButton
var _test_spell_dropdown: OptionButton
var _test_btn: Button

var _is_updating_class_name := false

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	_build_ui()
	_refresh_spell_list()
	_refresh_character_list()
	if EditorInterface.get_resource_filesystem():
		EditorInterface.get_resource_filesystem().filesystem_changed.connect(_refresh_spell_list)
		EditorInterface.get_resource_filesystem().filesystem_changed.connect(_refresh_character_list)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if EditorInterface.get_resource_filesystem():
			if EditorInterface.get_resource_filesystem().filesystem_changed.is_connected(_refresh_spell_list):
				EditorInterface.get_resource_filesystem().filesystem_changed.disconnect(_refresh_spell_list)
			if EditorInterface.get_resource_filesystem().filesystem_changed.is_connected(_refresh_character_list):
				EditorInterface.get_resource_filesystem().filesystem_changed.disconnect(_refresh_character_list)

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _build_ui() -> void:
	# === Create Section ===
	var create_header := Label.new()
	create_header.text = "✨ Create New Spell"
	create_header.add_theme_font_size_override("font_size", 16)
	add_child(create_header)
	add_child(HSeparator.new())
	
	# English Name
	var hbox1 := HBoxContainer.new()
	var label1 := Label.new()
	label1.text = "English Name:"
	label1.custom_minimum_size.x = 120
	hbox1.add_child(label1)
	_spell_name_edit = LineEdit.new()
	_spell_name_edit.placeholder_text = "fire_ball"
	_spell_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spell_name_edit.text_changed.connect(_on_spell_name_changed)
	hbox1.add_child(_spell_name_edit)
	add_child(hbox1)
	
	# Class Name (auto-generated)
	var hbox2 := HBoxContainer.new()
	var label2 := Label.new()
	label2.text = "Class Name:"
	label2.custom_minimum_size.x = 120
	hbox2.add_child(label2)
	_class_name_edit = LineEdit.new()
	_class_name_edit.placeholder_text = "FireBall (auto)"
	_class_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox2.add_child(_class_name_edit)
	add_child(hbox2)
	
	# Display Name
	var hbox3 := HBoxContainer.new()
	var label3 := Label.new()
	label3.text = "Display Name:"
	label3.custom_minimum_size.x = 120
	hbox3.add_child(label3)
	_display_name_edit = LineEdit.new()
	_display_name_edit.placeholder_text = "火球术"
	_display_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_display_name_edit.text_changed.connect(func(_t): _validate_all_inputs())
	hbox3.add_child(_display_name_edit)
	add_child(hbox3)
	
	# Status
	# ==== 出生数值区（面板=唯一真相批）====
	var d: Dictionary = SpellCreator.DEFAULT_DEF_STATS
	var da: Dictionary = SpellCreator.DEFAULT_ATTACK
	_desc_edit = _make_line_row("描述:", "图鉴/提示文案，可留空")
	_mana_cost_spin = _make_spin_row("法力消耗:", "施放一次扣除的 mana", 0, 9999, 10, d.mana_cost)
	_lifetime_spin = _make_spin_row("存在时限(s):", "弹体最长存活秒数，0=不限", 0, 60, 0.5, d.max_lifetime)
	_cooldown_spin = _make_spin_row("冷却(s):", "槽位冷却时长", 0, 60, 0.1, d.cooldown)
	_cast_time_spin = _make_spin_row("引导(s):", "起手后按住阶段的引导时长，0=起手播完立即出手", 0, 10, 0.1, d.caster_cast_time)
	_release_x_spin = _make_spin_row("出手点 X:", "相对身高比例（1=身高处），左右镜像自动翻", 0.1, 3, 0.01, d.release_x)
	_release_y_spin = _make_spin_row("出手点 Y:", "0=脚下 1=头顶（fire_ball 演示值 0.34）", 0, 2, 0.01, d.release_y)
	_fade_in_spin = _make_spin_row("淡入(s):", "出场渐显时长", 0, 2, 0.01, d.fade_in_time)
	_fade_out_spin = _make_spin_row("淡出(s):", "消亡渐隐时长", 0, 2, 0.01, d.fade_out_time)
	_allowed_edit = _make_line_row("允许施法状态:", "逗号分隔状态名，空=不限制")
	_allowed_edit.text = String(d.allowed_states)
	_disallowed_edit = _make_line_row("禁止施法状态:", "逗号分隔；默认 Die,Knockout（倒地/击飞中禁放）")
	_disallowed_edit.text = String(d.disallowed_states)
	var atk_header := Label.new()
	atk_header.text = "⚔ 弹体命中数据"
	atk_header.add_theme_font_size_override("font_size", 14)
	add_child(atk_header)
	var atk_row := HBoxContainer.new()
	atk_row.add_child(_row_label("伤害/击退/部位/角度:"))
	_atk_damage_spin = _inline_spin(0, 999, 1, da.attack_damage, atk_row)
	_atk_knock_spin = _inline_spin(0, 9999, 10, da.knock_strength, atk_row)
	_atk_hurt_option = OptionButton.new()
	_atk_hurt_option.add_item("上身")
	_atk_hurt_option.add_item("中部")
	_atk_hurt_option.select(int(da.hurt_type))
	atk_row.add_child(_atk_hurt_option)
	_atk_angle_spin = _inline_spin(0, 360, 5, da.launch_angle, atk_row)
	add_child(atk_row)
	_add_hint("击退值 K=统一模型击打值：0=纯伤害且空中不打断弹道；扣穿受击方额度即按其溢出量起飞")
	
	_status_label = Label.new()
	_status_label.text = "Enter spell name to begin"
	_status_label.add_theme_color_override("font_color", Color.GRAY)
	add_child(_status_label)
	
	# Create button
	_create_btn = Button.new()
	_create_btn.text = "Create Spell ▶"
	_create_btn.disabled = true
	_create_btn.pressed.connect(_on_create_pressed)
	add_child(_create_btn)
	
	add_child(HSeparator.new())
	
	# === Delete Section ===
	var delete_header := Label.new()
	delete_header.text = "🗑️ Delete Spell"
	delete_header.add_theme_font_size_override("font_size", 16)
	add_child(delete_header)
	
	_delete_dropdown = OptionButton.new()
	_delete_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_delete_dropdown.item_selected.connect(_on_delete_dropdown_selected)
	add_child(_delete_dropdown)
	
	_delete_path_label = Label.new()
	_delete_path_label.add_theme_color_override("font_color", Color.ORANGE)
	add_child(_delete_path_label)
	
	_delete_btn = Button.new()
	_delete_btn.text = "Delete 🗑️"
	_delete_btn.disabled = true
	_delete_btn.pressed.connect(_on_delete_pressed)
	add_child(_delete_btn)
	
	add_child(HSeparator.new())
	
	# === Test Section ===
	var test_header := Label.new()
	test_header.text = "🧪 Test Spell"
	test_header.add_theme_font_size_override("font_size", 16)
	add_child(test_header)
	add_child(HSeparator.new())
	
	# Character dropdown
	var test_char_hbox := HBoxContainer.new()
	var test_char_label := Label.new()
	test_char_label.text = "Character:"
	test_char_label.custom_minimum_size.x = 120
	test_char_hbox.add_child(test_char_label)
	_test_char_dropdown = OptionButton.new()
	_test_char_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_test_char_dropdown.item_selected.connect(_on_test_char_selected)
	test_char_hbox.add_child(_test_char_dropdown)
	add_child(test_char_hbox)
	
	# Spell dropdown
	var test_spell_hbox := HBoxContainer.new()
	var test_spell_label := Label.new()
	test_spell_label.text = "Spell:"
	test_spell_label.custom_minimum_size.x = 120
	test_spell_hbox.add_child(test_spell_label)
	_test_spell_dropdown = OptionButton.new()
	_test_spell_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_test_spell_dropdown.item_selected.connect(_on_test_spell_selected)
	test_spell_hbox.add_child(_test_spell_dropdown)
	add_child(test_spell_hbox)
	
	# Test button
	_test_btn = Button.new()
	_test_btn.text = "Run Test ▶"
	_test_btn.disabled = true
	_test_btn.modulate = Color(0.4, 0.8, 0.4)
	_test_btn.pressed.connect(_on_test_pressed)
	add_child(_test_btn)
	
	# Test info
	var test_info := Label.new()
	test_info.text = "生成临时测试场景并运行，按 ESC 退出测试"
	test_info.add_theme_color_override("font_color", Color.GRAY)
	add_child(test_info)


func _on_spell_name_changed(new_text: String) -> void:
	if _is_updating_class_name:
		return
	_is_updating_class_name = true
	_class_name_edit.text = _auto_generate_class_name(new_text)
	_is_updating_class_name = false
	_validate_all_inputs()


func _auto_generate_class_name(snake: String) -> String:
	var parts = snake.split("_")
	var result = ""
	for part in parts:
		if not part.is_empty():
			result += part[0].to_upper() + part.substr(1)
	return result


func _validate_all_inputs() -> void:
	var spell_name = _spell_name_edit.text.strip_edges()
	var pascal_name = _class_name_edit.text.strip_edges()
	var display_name = _display_name_edit.text.strip_edges()
	
	# Validate snake_case
	if spell_name.is_empty():
		_set_status("Enter a spell name", Color.GRAY)
		_create_btn.disabled = true
		return
	
	if not _validate_snake_case(spell_name):
		_set_status("Invalid name: use lowercase + underscores", Color.RED)
		_create_btn.disabled = true
		return
	
	if DirAccess.dir_exists_absolute(SPELL_DIR.path_join(spell_name)):
		_set_status("Spell '%s' already exists" % spell_name, Color.RED)
		_create_btn.disabled = true
		return
	
	# Validate PascalCase
	if pascal_name.is_empty() or not _validate_pascal_case(pascal_name):
		_set_status("Invalid class name", Color.RED)
		_create_btn.disabled = true
		return
	
	# Validate display name
	if display_name.is_empty():
		_set_status("Enter a display name", Color.GRAY)
		_create_btn.disabled = true
		return
	
	_set_status("Ready: %s (%s)" % [pascal_name, display_name], Color.GREEN)
	_create_btn.disabled = false


func _validate_snake_case(text: String) -> bool:
	var regex = RegEx.new()
	regex.compile("^[a-z][a-z0-9_]*$")
	if regex.search(text) == null:
		return false
	if text.begins_with("_") or text.ends_with("_") or text.contains("__"):
		return false
	return true


func _validate_pascal_case(text: String) -> bool:
	var regex = RegEx.new()
	regex.compile("^[A-Z][a-zA-Z0-9]*$")
	return regex.search(text) != null


func _set_status(text: String, color: Color) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)


func _on_create_pressed() -> void:
	var spell_name = _spell_name_edit.text.strip_edges()
	var pascal_name = _class_name_edit.text.strip_edges()
	var display_name = _display_name_edit.text.strip_edges()
	var def_stats := {
		"description": _desc_edit.text.strip_edges(),
		"mana_cost": _mana_cost_spin.value,
		"max_lifetime": _lifetime_spin.value,
		"cooldown": _cooldown_spin.value,
		"caster_cast_time": _cast_time_spin.value,
		"release_x": _release_x_spin.value,
		"release_y": _release_y_spin.value,
		"fade_in_time": _fade_in_spin.value,
		"fade_out_time": _fade_out_spin.value,
		"allowed_states": _allowed_edit.text.strip_edges(),
		"disallowed_states": _disallowed_edit.text.strip_edges(),
	}
	var attack := {
		"attack_damage": _atk_damage_spin.value,
		"hurt_type": _atk_hurt_option.selected,
		"knock_strength": _atk_knock_spin.value,
		"launch_angle": _atk_angle_spin.value,
	}
	
	var creator := SpellCreator.new()
	if creator.create_spell(spell_name, pascal_name, display_name, def_stats, attack):
		_set_status("✓ Created: %s" % spell_name, Color.GREEN)
		_spell_name_edit.text = ""
		_class_name_edit.text = ""
		_display_name_edit.text = ""
		_reset_spell_stats()
		_create_btn.disabled = true
		spell_created.emit(spell_name)
	else:
		_set_status("✗ Failed to create spell", Color.RED)


func _refresh_spell_list() -> void:
	_delete_dropdown.clear()
	_test_spell_dropdown.clear()
	var dir := DirAccess.open(SPELL_DIR)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var spells := []
	
	while not file_name.is_empty():
		if file_name != "." and file_name != ".." and file_name != "_template" and file_name != "_base":
			if dir.current_is_dir():
				spells.append(file_name)
		file_name = dir.get_next()
	
	spells.sort()
	for spell in spells:
		_delete_dropdown.add_item(spell)
		_test_spell_dropdown.add_item(spell)
	
	# OptionButton 在首个 add_item 时会自动选中 index 0，必须填充完后强制取消，
	# 否则用户没选也有"当前项"，测试按钮会误点亮（对齐角色侧做法，2026-09-15 审计 L6）
	_delete_dropdown.selected = -1
	_test_spell_dropdown.selected = -1
	_delete_btn.disabled = true
	_delete_path_label.text = ""
	_update_test_btn_state()


func _refresh_character_list() -> void:
	_test_char_dropdown.clear()
	var dir := DirAccess.open(CHARACTER_DIR)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var characters := []
	
	while not file_name.is_empty():
		if file_name != "." and file_name != ".." and file_name != "_template":
			if dir.current_is_dir():
				characters.append(file_name)
		file_name = dir.get_next()
	
	characters.sort()
	for char_name in characters:
		_test_char_dropdown.add_item(char_name)
	
	_test_char_dropdown.selected = -1
	_update_test_btn_state()


func _on_delete_dropdown_selected(index: int) -> void:
	var spell_name = _delete_dropdown.get_item_text(index)
	_delete_path_label.text = "Will delete: %s%s/" % [SPELL_DIR, spell_name]
	_delete_btn.disabled = false


func _on_delete_pressed() -> void:
	var index = _delete_dropdown.selected
	if index < 0:
		return
	var spell_name = _delete_dropdown.get_item_text(index)
	
	var dialog := ConfirmationDialog.new()
	dialog.title = "Confirm Delete"
	dialog.dialog_text = "Delete spell '%s'? This cannot be undone." % spell_name
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		var deleter := SpellDeleter.new()
		if deleter.delete_spell(spell_name):
			_set_status("✓ Deleted: %s" % spell_name, Color.GREEN)
			spell_deleted.emit(spell_name)
		else:
			_set_status("✗ Failed to delete", Color.RED)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())


func _on_test_char_selected(_index: int) -> void:
	_update_test_btn_state()


func _on_test_spell_selected(_index: int) -> void:
	_update_test_btn_state()


func _update_test_btn_state() -> void:
	var char_selected := _test_char_dropdown.selected >= 0
	var spell_selected := _test_spell_dropdown.selected >= 0
	_test_btn.disabled = not (char_selected and spell_selected)


func _on_test_pressed() -> void:
	var char_index := _test_char_dropdown.selected
	var spell_index := _test_spell_dropdown.selected
	if char_index < 0 or spell_index < 0:
		return
	var char_name := _test_char_dropdown.get_item_text(char_index)
	var spell_name := _test_spell_dropdown.get_item_text(spell_index)
	_set_status("🧪 Testing spell '%s' with '%s'..." % [spell_name, char_name], Color.CYAN)
	spell_test_requested.emit(char_name, spell_name)

### -----------------------------------------------------------------------------------------------


### -----------------------------------------------------------------------------------------------
### 出生数值区构件（2026-09-18 与角色线拉齐批；默认表与创建器合成同源）
### -----------------------------------------------------------------------------------------------

func _row_label(text: String) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.custom_minimum_size.x = 150
	return lab


func _make_line_row(row_label: String, hint: String) -> LineEdit:
	var hbox := HBoxContainer.new()
	hbox.add_child(_row_label(row_label))
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(edit)
	add_child(hbox)
	if not hint.is_empty():
		_add_hint(hint)
	return edit


func _make_spin_row(row_label: String, hint: String, mn: float, mx: float, step: float, def: float) -> SpinBox:
	var hbox := HBoxContainer.new()
	hbox.add_child(_row_label(row_label))
	var spin := _inline_spin(mn, mx, step, def, hbox)
	add_child(hbox)
	if not hint.is_empty():
		_add_hint(hint)
	return spin


func _inline_spin(mn: float, mx: float, step: float, def: float, parent: Control) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = mn
	spin.max_value = mx
	spin.step = step
	spin.value = def
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spin)
	return spin


func _add_hint(hint: String) -> void:
	var h := Label.new()
	h.text = hint
	h.add_theme_color_override("font_color", Color.GRAY)
	h.add_theme_font_size_override("font_size", 12)
	add_child(h)


func _reset_spell_stats() -> void:
	var d: Dictionary = SpellCreator.DEFAULT_DEF_STATS
	var da: Dictionary = SpellCreator.DEFAULT_ATTACK
	_desc_edit.text = ""
	_mana_cost_spin.value = d.mana_cost
	_lifetime_spin.value = d.max_lifetime
	_cooldown_spin.value = d.cooldown
	_cast_time_spin.value = d.caster_cast_time
	_release_x_spin.value = d.release_x
	_release_y_spin.value = d.release_y
	_fade_in_spin.value = d.fade_in_time
	_fade_out_spin.value = d.fade_out_time
	_allowed_edit.text = String(d.allowed_states)
	_disallowed_edit.text = String(d.disallowed_states)
	_atk_damage_spin.value = da.attack_damage
	_atk_knock_spin.value = da.knock_strength
	_atk_hurt_option.select(int(da.hurt_type))
	_atk_angle_spin.value = da.launch_angle
