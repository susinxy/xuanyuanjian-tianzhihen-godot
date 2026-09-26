@tool
extends VBoxContainer
## Character Creator Widget
## Provides UI for creating and deleting characters from template.

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

signal character_created(char_name: String)
signal character_deleted(char_name: String)
signal character_test_requested(char_name: String, pkg: String)

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const CHARACTERS_ROOT = "res://characters/"
## 阵营包目录（列表扫描与重名检查共用）
const PKG_DIRS = ["playable", "enemies", "allies", "neutrals"]
const TEMPLATE_DIR = "res://templates/character/"

#--- public variables - order: export > normal var & onready --------------------------------------

#--- private variables - order: export > normal var & onready -------------------------------------

var _char_name_edit: LineEdit
var _class_name_edit: LineEdit
var _display_name_edit: LineEdit
var _control_option: OptionButton
var _faction_edit: LineEdit
var _faction_pick: OptionButton
var _faction_insert: Button
var _move_speed_spin: SpinBox
var _walk_speed_spin: SpinBox
var _health_max_spin: SpinBox
var _air_control_spin: SpinBox
var _hit_lane_offset_spin: SpinBox
var _mana_max_spin: SpinBox
var _resistance_spin: SpinBox
var _jump_force_spin: SpinBox
var _knockback_weight_spin: SpinBox
var _grab_check: CheckBox
var _invuln_check: CheckBox
var _superarmor_check: CheckBox
# 攻击朝向模式下拉（S2-B4.6）：取值经 get_item_id，item 序与枚举值故意相反
# （item0="只有左右"→id=1、item1="上下左右"→id=0），防按索引直取踩反转坑
var _axis_mode_option: OptionButton
# 四招出生值控件（槽序与 CharacterCreator.DEFAULT_ATTACKS 对齐）
var _atk_damage: Array[SpinBox] = []
var _atk_hurt: Array[OptionButton] = []
var _atk_knock: Array[SpinBox] = []
var _atk_angle: Array[SpinBox] = []
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
	
	# Control mode dropdown（单壳架构：控制方式决定行为档与输出目录）
	var hbox_control := HBoxContainer.new()
	var label_control := Label.new()
	label_control.text = "控制方式:"
	label_control.custom_minimum_size.x = 120
	hbox_control.add_child(label_control)
	_control_option = OptionButton.new()
	_control_option.add_item("玩家操控", 0)
	_control_option.add_item("AI 自动战斗", 1)
	_control_option.add_item("被动站立", 2)
	_control_option.select(0)
	_control_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_control_option.item_selected.connect(_on_control_mode_selected)
	hbox_control.add_child(_control_option)
	add_child(hbox_control)
	
	# 阵营标签（area2d 单一存放点体系：只写根节点 groups=["area2d:<标签>"]，
	# 战斗盒由角色 _ready 运行时下发；逗号分隔可多标签）
	var hbox_faction := HBoxContainer.new()
	var label_faction := Label.new()
	label_faction.text = "阵营标签:"
	label_faction.custom_minimum_size.x = 120
	hbox_faction.add_child(label_faction)
	_faction_edit = LineEdit.new()
	_faction_edit.placeholder_text = "player 或 player,team_two（逗号分隔）"
	_faction_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_faction_edit.text_changed.connect(func(_t): _validate_all_inputs())
	hbox_faction.add_child(_faction_edit)
	_faction_pick = OptionButton.new()
	_populate_faction_pick()
	hbox_faction.add_child(_faction_pick)
	_faction_insert = Button.new()
	_faction_insert.text = "插入"
	_faction_insert.pressed.connect(_on_faction_insert_pressed)
	hbox_faction.add_child(_faction_insert)
	add_child(hbox_faction)
	var faction_hint := Label.new()
	faction_hint.text = (
		"阵营=area2d 共享标签：同标签互免伤害，不同标签互相可打。\n"
		+"默认随控制方式：玩家→player、AI→enemy、被动→角色名（可改可多选）。\n"
		+"持 player 标签者=玩家身份（HUD 跟随/入战/索敌/死亡游戏结束都认它）。\n"
		+"输出目录由控制方式决定；额外标签可出生后进编辑器自由补挂。"
	)
	faction_hint.add_theme_color_override("font_color", Color.GRAY)
	faction_hint.add_theme_font_size_override("font_size", 12)
	add_child(faction_hint)
	_apply_control_linkage()
	
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
	
	# Walk Speed input
	var hbox_walk_speed := HBoxContainer.new()
	var label_walk_speed := Label.new()
	label_walk_speed.text = "步行速度:"
	label_walk_speed.custom_minimum_size.x = 120
	hbox_walk_speed.add_child(label_walk_speed)
	_walk_speed_spin = SpinBox.new()
	_walk_speed_spin.min_value = 0
	_walk_speed_spin.max_value = 2000
	_walk_speed_spin.step = 10
	_walk_speed_spin.value = 300
	_walk_speed_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_walk_speed.add_child(_walk_speed_spin)
	add_child(hbox_walk_speed)
	var walk_speed_hint := Label.new()
	walk_speed_hint.text = "按住Shift时的步行速度（像素/秒）"
	walk_speed_hint.add_theme_color_override("font_color", Color.GRAY)
	walk_speed_hint.add_theme_font_size_override("font_size", 12)
	add_child(walk_speed_hint)
	
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
	hit_lane_hint.text = (
			"调整受击车道窗口（垂直于攻击方向的轴：横攻比排/纵攻比列；正扩负缩）"
	)
	hit_lane_hint.add_theme_color_override("font_color", Color.GRAY)
	hit_lane_hint.add_theme_font_size_override("font_size", 12)
	# ==== 出生属性扩容区（2026-09-18 面板=唯一真相批）====
	# 默认值统一读 CharacterCreator.DEFAULT_STATS/DEFAULT_ATTACKS——面板、
	# 合成、复位三处同源，杜绝演示值藏进快照的旧形态。
	_mana_max_spin = _make_spin_row("最大法力值:", "施法资源上限（mana_max）", 0, 9999, 10, CharacterCreator.DEFAULT_STATS.mana_max)
	_resistance_spin = _make_spin_row("抗击打值 R:", "命中先扣此额度，扣穿即被击飞；初速=击打值-剩余+保底（精英调高）", 0, 99999, 50, CharacterCreator.DEFAULT_STATS.knockout_resistance_max)
	_jump_force_spin = _make_spin_row("跳跃力:", "负数=向上（jump_force）", -5000, -100, 50, CharacterCreator.DEFAULT_STATS.jump_force)
	_knockback_weight_spin = _make_spin_row("击飞权重:", "被击飞冲量乘数，>1 飞更远、<1 更沉", 0, 10, 0.1, CharacterCreator.DEFAULT_STATS.knockback_weight)
	_grab_check = _make_check_row("可被抓取:", "出生 can_be_grabbed（默认关=不可被抓；抓取靶子如木桩/杂兵按需勾选）", CharacterCreator.DEFAULT_STATS.can_be_grabbed)
	_invuln_check = _make_check_row("天生无敌:", "警告：勾选=全程免伤免击退，正常由动画轨道控制", false)
	_superarmor_check = _make_check_row("天生霸体:", "警告：勾选=受击不打断且击打值无效，同上", false)
	# 攻击朝向模式（S2-B4.6 裁决①：全局默认=只有左右）。item 携带的 id 即枚举值
	# （AttackAxisMode：FOUR_DIRECTION=0 / HORIZONTAL_ONLY=1），故 item0→id 1、
	# item1→id 0 与显示序相反——收集处只认 get_item_id，不认 selected 索引。
	var hbox_axis := HBoxContainer.new()
	var label_axis := Label.new()
	label_axis.text = "攻击朝向模式:"
	label_axis.custom_minimum_size.x = 120
	hbox_axis.add_child(label_axis)
	_axis_mode_option = OptionButton.new()
	_axis_mode_option.add_item("只有左右", int(QuiverAttributes.AttackAxisMode.HORIZONTAL_ONLY))
	_axis_mode_option.add_item("上下左右", int(QuiverAttributes.AttackAxisMode.FOUR_DIRECTION))
	_axis_mode_option.selected = _axis_mode_option.get_item_index(int(CharacterCreator.DEFAULT_STATS.attack_axis_mode))
	_axis_mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_axis.add_child(_axis_mode_option)
	add_child(hbox_axis)
	_add_hint("地面攻击定向：只有左右=出手向恒取左右朝向记忆（与跳跃同源）；上下左右=旧四向主轴塌缩")
	var atk_header := Label.new()
	atk_header.text = "招式出生值（刺拳1 / 刺拳2 / 刺拳3 / 空中踢）"
	atk_header.add_theme_font_size_override("font_size", 14)
	add_child(atk_header)
	var atk_cols := Label.new()
	atk_cols.text = "列序：伤害 / 击退值K / 受击部位 / 弹射角度"
	atk_cols.add_theme_color_override("font_color", Color.GRAY)
	atk_cols.add_theme_font_size_override("font_size", 12)
	add_child(atk_cols)
	var atk_names := ["刺拳1:", "刺拳2:", "刺拳3:", "空中踢:"]
	for i in CharacterCreator.DEFAULT_ATTACKS.size():
		var base: Dictionary = CharacterCreator.DEFAULT_ATTACKS[i]
		var hbox := HBoxContainer.new()
		var lab := Label.new()
		lab.text = atk_names[i]
		lab.custom_minimum_size.x = 120
		hbox.add_child(lab)
		var dmg := SpinBox.new()
		dmg.min_value = 0
		dmg.max_value = 999
		dmg.step = 1
		dmg.value = base.attack_damage
		dmg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(dmg)
		_atk_damage.append(dmg)
		var knock := SpinBox.new()
		knock.min_value = 0
		knock.max_value = 9999
		knock.step = 10
		knock.value = base.knock_strength
		knock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(knock)
		_atk_knock.append(knock)
		var hurt := OptionButton.new()
		hurt.add_item("上身")
		hurt.add_item("中部")
		hurt.select(int(base.hurt_type))
		hbox.add_child(hurt)
		_atk_hurt.append(hurt)
		var angle := SpinBox.new()
		angle.min_value = 0
		angle.max_value = 360
		angle.step = 5
		angle.value = base.launch_angle
		angle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(angle)
		_atk_angle.append(angle)
		add_child(hbox)
	var atk_hint := Label.new()
	atk_hint.text = "击退值 K=统一模型击打值：0=纯伤害；轻拳攒不满额度只硬直，扣穿按溢出起飞"
	atk_hint.add_theme_color_override("font_color", Color.GRAY)
	atk_hint.add_theme_font_size_override("font_size", 12)
	add_child(atk_hint)
	
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
	
	var characters := []
	for pkg in PKG_DIRS:
		var pkg_dir := CHARACTERS_ROOT.path_join(pkg)
		var dir := DirAccess.open(pkg_dir)
		if dir == null:
			continue
		dir.list_dir_begin()
		var folder_name := dir.get_next()
		while not folder_name.is_empty():
			if dir.current_is_dir() and folder_name != "." and folder_name != ".." \
					and folder_name != "_template":
				# Try to read display name from attributes file
				var attrs_path = pkg_dir.path_join(folder_name).path_join("resources") \
						.path_join(folder_name + "_attributes.tres")
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
				
				characters.append({"pkg": pkg, "name": folder_name, "display": display_name})
			folder_name = dir.get_next()
	
	# Sort by package then English name (stable)
	characters.sort_custom(func(a, b):
		if a.pkg != b.pkg:
			return PKG_DIRS.find(a.pkg) < PKG_DIRS.find(b.pkg)
		return a.name < b.name)
	
	for char_data in characters:
		var item_text = "%s (%s) ▸%s" % [char_data.display, char_data.name, char_data.pkg]
		_delete_dropdown.add_item(item_text)
		_delete_dropdown.set_item_metadata(_delete_dropdown.item_count - 1, char_data)
		
		if is_instance_valid(_test_dropdown):
			_test_dropdown.add_item(item_text)
			_test_dropdown.set_item_metadata(_test_dropdown.item_count - 1, char_data)
	
	# Force no selection AFTER all items are added
	# (OptionButton auto-selects index 0 on first add_item)
	_delete_dropdown.selected = -1
	if is_instance_valid(_test_dropdown):
		_test_dropdown.selected = -1


func _on_control_mode_selected(_index: int) -> void:
	_apply_control_linkage()
	_validate_all_inputs()


## 控制方式 → 阵营标签默认值联动（不再锁死：目录归属与标签解耦）
func _apply_control_linkage() -> void:
	match _control_option.selected:
		0:
			_faction_edit.text = "player"
		1:
			_faction_edit.text = "enemy"
		_:
			var name := _char_name_edit.text
			_faction_edit.text = name if CharacterCreator._validate_snake_static(name) else "neutral"


## 扫描全项目根节点上已有的 area2d 阵营标签，填进"插入"下拉
func _populate_faction_pick() -> void:
	_faction_pick.clear()
	var seen: Array[String] = []
	var regex := RegEx.create_from_string('"area2d:([a-z0-9_]+)"')
	for pkg in PKG_DIRS:
		var dir := DirAccess.open(CHARACTERS_ROOT.path_join(pkg))
		if dir == null:
			continue
		dir.list_dir_begin()
		var folder := dir.get_next()
		while not folder.is_empty():
			if folder != "." and folder != ".." and dir.current_is_dir():
				var main_path := CHARACTERS_ROOT.path_join(pkg).path_join(folder) 						.path_join(folder + ".tscn")
				if FileAccess.file_exists(main_path):
					var text := FileAccess.get_file_as_string(main_path)
					for line in text.split("\n"):
						if line.contains("groups=") and not line.contains("parent="):
							for m in regex.search_all(line):
								var tag := m.get_string(1)
								if tag != "wall" and tag != "__FACTION__" and not seen.has(tag):
									seen.append(tag)
							break
			folder = dir.get_next()
	for tag in seen:
		_faction_pick.add_item(tag)
	if _faction_pick.item_count > 0:
		_faction_pick.selected = 0


func _on_faction_insert_pressed() -> void:
	if _faction_pick.selected < 0:
		return
	var tag: String = _faction_pick.get_item_text(_faction_pick.selected)
	var parts := CharacterCreator.parse_faction_tags(_faction_edit.text)
	if parts.has(tag):
		return
	parts.append(tag)
	_faction_edit.text = ", ".join(parts)


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
	# 跨阵营包查重名（不同目录同名角色同样会造成引用混乱）
	for pkg in PKG_DIRS:
		if DirAccess.dir_exists_absolute(CHARACTERS_ROOT.path_join(pkg).path_join(name)):
			return true
	return false


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
	
	# Validate faction tags
	if CharacterCreator.parse_faction_tags(_faction_edit.text.strip_edges()).is_empty():
		_status_label.text = "Status: ❌ 阵营标签需至少一个 snake_case 词（逗号分隔）"
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
	
	# 立即更新 UI：按钮变灰、文本变化、颜色变暗
	_create_btn.disabled = true
	_create_btn.text = "⏳ Creating..."
	_create_btn.modulate = Color(0.6, 0.6, 0.6)
	_status_label.text = "Status: ⏳ Creating character..."
	_status_label.add_theme_color_override("font_color", Color.YELLOW)
	
	# 让出一帧，让 UI 重绘
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 收集参数
	var stats := {
		"health_max": _health_max_spin.value,
		"mana_max": _mana_max_spin.value,
		"knockout_resistance_max": _resistance_spin.value,
		"move_speed": _move_speed_spin.value,
		"walk_speed": _walk_speed_spin.value,
		"air_control": _air_control_spin.value,
		"jump_force": _jump_force_spin.value,
		"knockback_weight": _knockback_weight_spin.value,
		"hit_lane_offset": _hit_lane_offset_spin.value,
		"can_be_grabbed": _grab_check.button_pressed,
		"is_invulnerable": _invuln_check.button_pressed,
		"has_superarmor": _superarmor_check.button_pressed,
		# 枚举值只认 item id（显示序与枚举值相反，见 _build_ui 防反转注）
		"attack_axis_mode": _axis_mode_option.get_item_id(_axis_mode_option.selected),
	}
	var attacks: Array = []
	for i in _atk_damage.size():
		attacks.append({
			"attack_damage": _atk_damage[i].value,
			"hurt_type": _atk_hurt[i].selected,
			"knock_strength": _atk_knock[i].value,
			"launch_angle": _atk_angle[i].value,
		})
	var params = {
		"char_name": _char_name_edit.text,
		"pascal_name": _class_name_edit.text,
		"display_name": _display_name_edit.text,
		"faction_tags": _faction_edit.text.strip_edges(),
		"stats": stats,
		"attacks": attacks,
		"control_mode": _control_option.selected
	}
	
	# 异步执行创建
	await _create_character_async(params)


func _create_character_async(params: Dictionary) -> void:
	var creator = CharacterCreator.new()
	var success = creator.create_character(
		params.char_name,
		params.pascal_name,
		params.display_name,
		params.faction_tags,
		params.stats,
		params.attacks,
		params.control_mode
	)
	
	_on_create_completed(success, params.char_name, params.display_name)


func _on_create_completed(success: bool, char_name: String, display_name: String) -> void:
	if success:
		_status_label.text = "Status: ✅ Character '%s' created successfully!" % display_name
		_status_label.add_theme_color_override("font_color", Color.GREEN)
		
		# 清空输入框
		_char_name_edit.text = ""
		_class_name_edit.text = ""
		_display_name_edit.text = ""
		_control_option.select(0)
		_apply_control_linkage()  # 阵营标签默认值随控制方式一并复位
		_reset_birth_stats()
		
		# 重置按钮（但不重新启用，因为输入框已清空）
		_create_btn.text = "Create Character ▶"
		_create_btn.modulate = Color.WHITE
		_create_btn.disabled = true
		
		# 发射信号
		character_created.emit(char_name)
	else:
		_status_label.text = "Status: ❌ Creation failed. Check console for errors."
		_status_label.add_theme_color_override("font_color", Color.RED)
		
		# 恢复按钮
		_create_btn.text = "Create Character ▶"
		_create_btn.modulate = Color.WHITE
		_create_btn.disabled = not _validate_all_inputs()
	
	_is_processing = false


func _on_delete_dropdown_selected(index: int) -> void:
	if index < 0:
		_delete_btn.disabled = true
		_delete_path_label.text = ""
		return
	
	var char_data: Dictionary = _delete_dropdown.get_item_metadata(index)
	_delete_path_label.text = "⚠️ This will permanently delete: %s" % [
		CHARACTERS_ROOT.path_join(char_data.pkg).path_join(char_data.name)]
	_delete_btn.disabled = false


func _on_delete_pressed() -> void:
	var index := _delete_dropdown.selected
	if index < 0:
		return
	
	var char_data: Dictionary = _delete_dropdown.get_item_metadata(index)
	
	# Show confirmation dialog
	var confirm_dialog := ConfirmationDialog.new()
	confirm_dialog.title = "Delete Character"
	confirm_dialog.dialog_text = "确定删除角色 %s？此操作不可逆。" % char_data.name
	confirm_dialog.confirmed.connect(_on_delete_confirmed.bind(char_data))
	# 确认/取消两条路径都要销毁弹窗节点，否则每次点删除泄漏一个 ConfirmationDialog
	# （对齐法术侧写法；queue_free 幂等，双信号不会二次释放）
	confirm_dialog.confirmed.connect(confirm_dialog.queue_free)
	confirm_dialog.canceled.connect(confirm_dialog.queue_free)
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()


func _on_delete_confirmed(char_data: Dictionary) -> void:
	_is_processing = true
	
	# 立即更新 UI：按钮变灰、文本变化、颜色变暗
	_delete_btn.disabled = true
	_delete_btn.text = "⏳ Deleting..."
	_delete_btn.modulate = Color(0.6, 0.6, 0.6)
	_status_label.text = "Status: ⏳ Deleting character..."
	_status_label.add_theme_color_override("font_color", Color.YELLOW)
	
	# 让出一帧，让 UI 重绘
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 异步执行删除
	await _delete_character_async(char_data)


func _delete_character_async(char_data: Dictionary) -> void:
	var deleter = CharacterDeleter.new()
	var success = deleter.delete_character(char_data.name, char_data.pkg)
	
	_on_delete_completed(success, char_data.name)


func _on_delete_completed(success: bool, char_name: String) -> void:
	if success:
		_status_label.text = "Status: ✅ Character '%s' deleted successfully!" % char_name
		_status_label.add_theme_color_override("font_color", Color.GREEN)
		
		# 重置下拉框
		_delete_dropdown.selected = -1
		_delete_btn.disabled = true
		_delete_path_label.text = ""
		
		# 恢复按钮
		_delete_btn.text = "Delete 🗑️"
		_delete_btn.modulate = Color(1.0, 0.4, 0.4)
		
		# 发射信号
		character_deleted.emit(char_name)
	else:
		_status_label.text = "Status: ❌ Deletion failed. Check console for errors."
		_status_label.add_theme_color_override("font_color", Color.RED)
		
		# 恢复按钮
		_delete_btn.text = "Delete 🗑️"
		_delete_btn.modulate = Color(1.0, 0.4, 0.4)
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
	
	var char_data: Dictionary = _test_dropdown.get_item_metadata(index)
	_status_label.text = "Status: 🧪 Testing character '%s'..." % char_data.name
	_status_label.add_theme_color_override("font_color", Color.CYAN)
	
	character_test_requested.emit(char_data.name, char_data.pkg)

### -----------------------------------------------------------------------------------------------


### -----------------------------------------------------------------------------------------------
### 出生数值区构件（2026-09-18 面板=唯一真相批）
### -----------------------------------------------------------------------------------------------

## SpinBox 行构造器：标签 120px 对齐既有行形态，hint 灰色小字（可空）。
func _make_spin_row(row_label: String, hint: String, mn: float, mx: float, step: float, def: float) -> SpinBox:
	var hbox := HBoxContainer.new()
	var lab := Label.new()
	lab.text = row_label
	lab.custom_minimum_size.x = 120
	hbox.add_child(lab)
	var spin := SpinBox.new()
	spin.min_value = mn
	spin.max_value = mx
	spin.step = step
	spin.value = def
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spin)
	add_child(hbox)
	if not hint.is_empty():
		_add_hint(hint)
	return spin


## CheckBox 行构造器（返回控件本体供调用处存引用）。
func _make_check_row(row_label: String, hint: String, def: bool) -> CheckBox:
	var hbox := HBoxContainer.new()
	var lab := Label.new()
	lab.text = row_label
	lab.custom_minimum_size.x = 120
	hbox.add_child(lab)
	var check := CheckBox.new()
	check.button_pressed = def
	hbox.add_child(check)
	add_child(hbox)
	if not hint.is_empty():
		_add_hint(hint)
	return check


func _add_hint(hint: String) -> void:
	var h := Label.new()
	h.text = hint
	h.add_theme_color_override("font_color", Color.GRAY)
	h.add_theme_font_size_override("font_size", 12)
	add_child(h)


## 全部出生数值控件归一复位（默认值与创建器合成兜底同源：DEFAULT_* 两表）。
func _reset_birth_stats() -> void:
	var d: Dictionary = CharacterCreator.DEFAULT_STATS
	_health_max_spin.value = d.health_max
	_mana_max_spin.value = d.mana_max
	_resistance_spin.value = d.knockout_resistance_max
	_move_speed_spin.value = d.move_speed
	_walk_speed_spin.value = d.walk_speed
	_air_control_spin.value = d.air_control
	_jump_force_spin.value = d.jump_force
	_knockback_weight_spin.value = d.knockback_weight
	_hit_lane_offset_spin.value = d.hit_lane_offset
	_grab_check.button_pressed = d.can_be_grabbed
	_invuln_check.button_pressed = d.is_invulnerable
	_superarmor_check.button_pressed = d.has_superarmor
	# 复位同样走 id→index 换算（DEFAULT_STATS 存枚举 int，不写死索引）
	_axis_mode_option.selected = _axis_mode_option.get_item_index(int(d.attack_axis_mode))
	for i in CharacterCreator.DEFAULT_ATTACKS.size():
		var base: Dictionary = CharacterCreator.DEFAULT_ATTACKS[i]
		_atk_damage[i].value = base.attack_damage
		_atk_knock[i].value = base.knock_strength
		_atk_hurt[i].select(int(base.hurt_type))
		_atk_angle[i].value = base.launch_angle
