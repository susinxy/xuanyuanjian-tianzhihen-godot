@tool
extends Control

## Write your doc string for this file here

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const META_MIRRORED_NAME = "mirrored_name"
const META_OVERWRITE = "should_overwrite"

const ERROR_NO_TRACK_FOUND = "No position, rotation or flip_h tracks found to be mirrored."
const ERROR_FILE_EXISTS = (
		"Target file already exists and overwriet is turned off.\n"
		+ "Turn on Overwrite, or change the name of the animation to be saved."
)
const ERROR_FAMILY_MISMATCH = (
		"目标文件与源动画不属同一镜像族系——疑似复制带来的错误 mirrored_name 元数据，已拒绝覆盖。\n"
		+ "（只有同一动作的 left/right 互镜才允许覆盖既有文件，例如 attack1_right ↔ attack1_left）\n"
		+ "请取消 Overwrite 勾选，或修正 Mirrored Name。"
)

#--- public variables - order: export > normal var > onready --------------------------------------

var animation: Animation = null:
	set(value):
		animation = value
		_configure_animation_properties()

#--- private variables - order: export > normal var > onready -------------------------------------

var _changed_report := ""

@onready var _line_edit := $NameLine/LineEdit as LineEdit
@onready var _check_box := $OverwriteLine/CheckBox as CheckBox
@onready var _finished_popup := $AcceptDialog as AcceptDialog
@onready var _report_label := $AcceptDialog/RichTextLabel as RichTextLabel

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	pass

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _on_button_pressed() -> void:
	_changed_report = ERROR_NO_TRACK_FOUND
	var folder := animation.resource_path.get_base_dir()
	var file_name := animation.get_meta(META_MIRRORED_NAME) as String
	var new_path := folder.path_join(file_name)
	
	var target_exists := ResourceLoader.exists(new_path)
	var will_overwrite := target_exists and bool(animation.get_meta(META_OVERWRITE))
	if will_overwrite and not _is_mirror_family(animation.resource_path.get_file(), file_name):
		# 只有同一动作的 left/right 互镜才允许覆盖既有文件，防止复制带来的错误
		# mirrored_name（如施法动画误指 attack1_left）毁掉无关动画（2026-09-15 审计 L1/L2）
		_changed_report = ERROR_FAMILY_MISMATCH
	elif target_exists and not animation.get_meta(META_OVERWRITE):
		_changed_report = ERROR_FILE_EXISTS
	else:
		var new_animation := animation.duplicate() as Animation
		var total_tracks := new_animation.get_track_count()
		for track_index in total_tracks:
			var path := new_animation.track_get_path(track_index)
			var property_subpath := path.get_concatenated_subnames()
			if _is_mirrorable_property(property_subpath):
				if _changed_report == ERROR_NO_TRACK_FOUND:
					_changed_report = "Track: %s "%[path]
				else:
					_changed_report += "\nTrack: %s "%[path]
				_mirror_track_values(new_animation, track_index, property_subpath)
		
		if _changed_report != ERROR_NO_TRACK_FOUND:
			new_animation.resource_name = file_name.get_basename()
			ResourceSaver.save(new_animation, new_path, ResourceSaver.FLAG_CHANGE_PATH)
			get_tree().call_group("quiver_beat_em_up_plugin", "emit_filesystem_changed")
		
	_report_label.text = _changed_report
	_finished_popup.popup_centered(_finished_popup.min_size)


func _is_mirrorable_property(property_name: String) -> bool:
	const VALID_PROPERTIES = [
		"flip_h",
		"position",
		"position:x",
		"rotation",
	]
	if property_name in VALID_PROPERTIES:
		return true
	if property_name.ends_with(":polygon"):
		return true
	return false


## 源与目标是否同属一个左右镜像族系（剥去 left/right/mirrored 后骨架须一致）
func _is_mirror_family(src_file: String, dst_file: String) -> bool:
	return _mirror_family(src_file) == _mirror_family(dst_file)


func _mirror_family(file_name: String) -> String:
	var s := file_name.get_basename().to_lower()
	for tok in ["_mirrored", "mirrored", "_left", "_right", "left", "right"]:
		s = s.replace(tok, "")
	return s


func _mirror_track_values(p_animation: Animation, track_index: int, subpath: String) -> void:
	var key_count := p_animation.track_get_key_count(track_index)
	for key_index in key_count:
		var value = p_animation.track_get_key_value(track_index, key_index)
		var mirrored_value
		match subpath:
			"flip_h":
				mirrored_value = not value
			"position":
				mirrored_value = Vector2(value.x * -1, value.y)
			"position:x", "rotation":
				mirrored_value = value * -1
			_:
				if subpath.ends_with(":polygon") and value is PackedVector2Array:
					var mirrored := PackedVector2Array()
					for v in value:
						mirrored.append(Vector2(-v.x, v.y))
					mirrored_value = mirrored
				else:
					continue
		
		p_animation.track_set_key_value(track_index, key_index, mirrored_value)
		_changed_report += "\n\t value: %s ------> %s"%[value, mirrored_value]


func _configure_animation_properties() -> void:
	if animation == null:
		return
	
	if not is_inside_tree():
		await ready
	
	# 只读面板：缺元数据时仅在输入框给出"建议目标"，**不再向资源写 meta**——
	# 查看资源即改资源会导致旧内存回写把删过的错误标签复活（2026-09-15 事故）
	if animation.has_meta(META_MIRRORED_NAME):
		_line_edit.text = animation.get_meta(META_MIRRORED_NAME)
	else:
		var file_name := animation.resource_path.get_file()
		var extension := ".%s"%[animation.resource_path.get_extension()]
		_line_edit.text = _get_mirrored_name(file_name.replace(extension, "")) + extension
	_check_box.button_pressed = bool(animation.get_meta(META_OVERWRITE)) if animation.has_meta(META_OVERWRITE) else false


func _get_mirrored_name(anim_name: String) -> String:
	var new_name = "%s_mirrored"%[anim_name]
	if anim_name.ends_with("left"):
		new_name = anim_name.replace("left", "right")
	elif anim_name.ends_with("right"):
		new_name = anim_name.replace("right", "left")
	
	return new_name


func _on_line_edit_text_changed(new_text: String) -> void:
	animation.set_meta(META_MIRRORED_NAME, new_text)


func _on_check_box_toggled(button_pressed: bool) -> void:
	animation.set_meta(META_OVERWRITE, button_pressed)

### -----------------------------------------------------------------------------------------------
