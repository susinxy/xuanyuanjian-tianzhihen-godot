@tool
extends VBoxContainer
## Spell Creator Widget
## Provides UI for creating and deleting spells from template.

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

signal spell_created(spell_name: String)
signal spell_deleted(spell_name: String)

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const SPELL_DIR = "res://spells/"

#--- public variables - order: export > normal var & onready --------------------------------------

#--- private variables - order: export > normal var & onready -------------------------------------

var _spell_name_edit: LineEdit
var _class_name_edit: LineEdit
var _display_name_edit: LineEdit
var _status_label: Label
var _create_btn: Button

var _delete_dropdown: OptionButton
var _delete_path_label: Label
var _delete_btn: Button

var _is_updating_class_name := false

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
    if not Engine.is_editor_hint():
        return
    _build_ui()
    _refresh_spell_list()
    if EditorInterface.get_resource_filesystem():
        EditorInterface.get_resource_filesystem().filesystem_changed.connect(_refresh_spell_list)


func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        if EditorInterface.get_resource_filesystem():
            if EditorInterface.get_resource_filesystem().filesystem_changed.is_connected(_refresh_spell_list):
                EditorInterface.get_resource_filesystem().filesystem_changed.disconnect(_refresh_spell_list)

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
    
    var creator := SpellCreator.new()
    if creator.create_spell(spell_name, pascal_name, display_name):
        _set_status("✓ Created: %s" % spell_name, Color.GREEN)
        _spell_name_edit.text = ""
        _class_name_edit.text = ""
        _display_name_edit.text = ""
        _create_btn.disabled = true
        spell_created.emit(spell_name)
    else:
        _set_status("✗ Failed to create spell", Color.RED)


func _refresh_spell_list() -> void:
    _delete_dropdown.clear()
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
    
    _delete_btn.disabled = true
    _delete_path_label.text = ""


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

### -----------------------------------------------------------------------------------------------
