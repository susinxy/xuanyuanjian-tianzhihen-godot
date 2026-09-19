@tool
class_name QuiverFightRoom
extends ReferenceRect

## Write your doc string for this file here

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

## 落位收口的边界外扩量（px，负内缩正外扩）：必须覆盖"贴合法墙位"——墙外挪
## 分档（横 60/竖 30）后，贴横墙停位中心≈线−25、贴竖（上下）墙≈线−3~−9
## （深度向轮廓半高 ~21-27），取 −40 使钳位矩形恰包含全部贴墙位，只真抓
## "被扫掠落在墙外"的人（拖回最近界外沿）。
## 数值与 QuiverLevelCamera.WALL_OUTSET_* 耦合同步（D8/C2.5 两头钉）。
const SETTLE_CLAMP_MARGIN := -40.0

#--- public variables - order: export > normal var > onready --------------------------------------

@export_group("Fight Room")
@export var limit_left := 0: set = _set_limit_left
@export var limit_top := 0: set = _set_limit_top
@export var limit_right := 0: set = _set_limit_right
@export var limit_bottom := 0: set = _set_limit_bottom

@export_range(0.1, 3.0, 0.01, "or_greater") var zoom := 1.0:
	set(value):
		if _ignore_setters:
			zoom = value
		else:
			zoom = _handle_zoom(value)
		queue_redraw()
@export_range(0.0, 3.0, 0.01, "or_greater") var transition_duration := 0.8

var after_fight_use_new_room := false:
	set(value):
		after_fight_use_new_room = value
		if after_fight_use_new_room:
			_reset_after_room_limits()
		notify_property_list_changed()
		queue_redraw()
var after_fight_limit_left := 0:
	set(value):
		after_fight_limit_left = value
		queue_redraw()
var after_fight_limit_top := 0:
	set(value):
		after_fight_limit_top = value
		queue_redraw()
var after_fight_limit_right := 0:
	set(value):
		after_fight_limit_right = value
		queue_redraw()
var after_fight_limit_bottom := 0:
	set(value):
		after_fight_limit_bottom = value
		queue_redraw()
var after_fight_zoom := 1.0
var after_fight_transition_duration := 0.8

var preview_camera_color := Color.INDIGO:
	set(value):
		preview_camera_color = value
		queue_redraw()
var preview_camera := true:
	set(value):
		preview_camera = value
		queue_redraw()
var preview_after_color := Color.TEAL:
	set(value):
		preview_after_color = value
		queue_redraw()
var preview_after_room := true:
	set(value):
		preview_after_room = value
		queue_redraw()

#--- private variables - order: export > normal var > onready -------------------------------------

var _ignore_setters := false
var _backup_room := {
	left = 0,
	top = 0,
	rigth = 0,
	bottom = 0,
	zoom = 1.0
}

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	if Engine.is_editor_hint():
		QuiverEditorHelper.disable_all_processing(self)
		var limits := [limit_left, limit_top, limit_right, after_fight_limit_bottom]
		if limits.all(_is_value_zero):
			var project_size := _get_default_resolution()
			size = project_size
			_update_limits()
		
		set_process(true)
	else:
		set_process(false)


func _process(_delta: float) -> void:
	if _has_rect_moved_or_changed():
		_update_limits()
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint() and editor_only:
		return
	
	if preview_camera:
		var camera_size := _get_default_resolution()
		var limits_center = size/2.0 - camera_size / zoom / 2.0
		var camera_rect := Rect2(limits_center, camera_size / zoom)
		draw_rect(camera_rect, preview_camera_color, false, border_width)
	
	if preview_after_room and after_fight_use_new_room:
		var transform := get_global_transform().affine_inverse()
		var begin := transform * Vector2(after_fight_limit_left, after_fight_limit_top)
		var end := transform * Vector2(after_fight_limit_right, after_fight_limit_bottom)
		var after_room_rect := Rect2(begin, end - begin)
		draw_rect(after_room_rect, preview_after_color, false, border_width)

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func setup_fight_room() -> void:
	var camera2D := get_viewport().get_camera_2d() as QuiverLevelCamera
	if camera2D == null:
		_push_no_valid_camera_error()
		return
	
	if not after_fight_use_new_room:
		_backup_room.left = camera2D.limit_left
		_backup_room.top = camera2D.limit_top
		_backup_room.right = camera2D.limit_right
		_backup_room.bottom = camera2D.limit_bottom
		_backup_room.zoom = camera2D.zoom.x
	var tween := camera2D.delimitate_room(
			limit_left, limit_top, limit_right, limit_bottom, zoom, transition_duration
	)
	_connect_settle_clamp(tween, limit_left, limit_top, limit_right, limit_bottom)


func setup_after_fight_room() -> void:
	var camera2D := get_viewport().get_camera_2d() as QuiverLevelCamera
	if camera2D == null:
		_push_no_valid_camera_error()
		return
	
	if after_fight_use_new_room:
		# after_fight_zoom 与战斗 zoom 同式夹紧（本批修正：旧形态裸值消费，
		# after 房一旦比视口宽即把墙推出镜头=无条件出屏，参考房数值恰好未露馅）
		var settled_zoom := _fit_zoom(after_fight_limit_left, after_fight_limit_top,
				after_fight_limit_right, after_fight_limit_bottom, after_fight_zoom)
		var tween := camera2D.delimitate_room(
				after_fight_limit_left, after_fight_limit_top, 
				after_fight_limit_right, after_fight_limit_bottom, 
				settled_zoom, after_fight_transition_duration
		)
		_connect_settle_clamp(tween, after_fight_limit_left, after_fight_limit_top,
				after_fight_limit_right, after_fight_limit_bottom)
	else:
		var tween := camera2D.delimitate_room(
				_backup_room.left, _backup_room.top, _backup_room.right, _backup_room.bottom,
				_backup_room.zoom, transition_duration
		)
		_connect_settle_clamp(tween, _backup_room.left, _backup_room.top,
				_backup_room.right, _backup_room.bottom)


## 过渡完成后执行一次"落位收口"（扫掠吞人对策，2026-09-19 定罪批）：
## 相机隐形墙是单向的且每帧跟随视口——锁房推近期间墙以扫掠速度合拢，
## 往回退的玩家会从未来得及合拢的缝隙绕到墙背面（背面不设防），此后
## 想走多远走多远、直接出镜头。契约=过渡结束不许任何人留在墙外。
func _connect_settle_clamp(tween: Tween, p_l: int, p_t: int, p_r: int, p_b: int) -> void:
	if tween == null:
		return
	# bind 快照按值传入（lambda 捕获局部变量按值陷阱的同族防线）
	tween.finished.connect(_clamp_players_into_room.bind(p_l, p_t, p_r, p_b))


## 只钳位置不清速度：击飞弹道/受击滑移原样保留，撞墙弹归状态门那套管。
func _clamp_players_into_room(p_l: int, p_t: int, p_r: int, p_b: int) -> void:
	var inset := Rect2(
			p_l + SETTLE_CLAMP_MARGIN, p_t + SETTLE_CLAMP_MARGIN,
			maxf(0.0, p_r - p_l - 2.0 * SETTLE_CLAMP_MARGIN),
			maxf(0.0, p_b - p_t - 2.0 * SETTLE_CLAMP_MARGIN)
	)
	for node in get_tree().get_nodes_in_group("area2d:player"):
		# 玩家阵营组里同挂战斗盒（下发产物），is 过滤是法典纪律
		var ch := node as QuiverCharacter
		if ch == null:
			continue
		if not inset.has_point(ch.global_position):
			ch.global_position = Vector2(
					clampf(ch.global_position.x, inset.position.x, inset.end.x),
					clampf(ch.global_position.y, inset.position.y, inset.end.y)
			)

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _is_value_zero(value: int) -> bool:
	return value == 0


func _get_default_resolution() -> Vector2:
	var project_size := Vector2(
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height")
	)
	return project_size


func _get_scaled_rect() -> Rect2:
	var rect := get_global_rect()
	rect.size * scale
	return rect


func _has_rect_moved_or_changed() -> bool:
	var rect := _get_scaled_rect()
	var rect_values := [rect.position.x, rect.position.y, rect.end.x, rect.end.y]
	var limit_values := [limit_left, limit_top, limit_right, limit_bottom]
	
	var value := false
	for index in rect_values.size():
		value = rect_values[index] != limit_values[index]
		if value:
			break
	
	return value


func _update_limits() -> void:
	var rect := _get_scaled_rect()
	_ignore_setters = true
	limit_right = rect.end.x
	limit_bottom = rect.end.y
	limit_left = rect.position.x
	limit_top = rect.position.y
	zoom = _handle_zoom(zoom)
	_ignore_setters = false


func _handle_zoom(value: float) -> float:
	return _fit_zoom(limit_left, limit_top, limit_right, limit_bottom, value)


## 房间期望 zoom 的夹紧纯函数：不得低于"把房间主轴收进视口"（主轴=相对视口
## 更短的那根）。战斗 zoom（属性 setter）与 after_fight_zoom（setup 消费）共用
## 此式——两路取一必踩"墙被推出镜头"雷（2026-09-19 批注）。
func _fit_zoom(p_l: int, p_t: int, p_r: int, p_b: int, want: float) -> float:
	var room_size := Vector2(p_r - p_l, p_b - p_t)
	if room_size.x <= 0.0 or room_size.y <= 0.0:
		return want
	var fit := _get_default_resolution() / room_size
	return maxf(maxf(fit.x, fit.y), want)


func _set_limit_left(value: int) -> void:
	limit_left = value
	if _ignore_setters:
		return
	
	if not is_inside_tree():
		await ready
	
	var difference := global_position.x - limit_left
	global_position.x = limit_left
	size.x += difference / scale.x


func _set_limit_top(value: int) -> void:
	limit_top = value
	if _ignore_setters:
		return
	
	if not is_inside_tree():
		await ready
	
	var difference := global_position.y - limit_top
	global_position.y = limit_top
	size.y += difference / scale.y


func _set_limit_right(value: int) -> void:
	limit_right = value
	if _ignore_setters:
		return
	
	if not is_inside_tree():
		await ready
	
	var new_size = limit_right - limit_left
	if new_size != size.x * scale.x:
		size.x = new_size / scale.x


func _set_limit_bottom(value: int) -> void:
	limit_bottom = value
	if _ignore_setters:
		return
	
	if not is_inside_tree():
		await ready
	
	var new_size = limit_bottom - limit_top
	if new_size != size.y * scale.y:
		size.y = new_size / scale.y


func _reset_after_room_limits() -> void:
	after_fight_limit_left = limit_left
	after_fight_limit_top = limit_top
	after_fight_limit_right = limit_right
	after_fight_limit_bottom = limit_bottom


func _push_no_valid_camera_error() -> void:
	push_error("Did not find a valid QuiverLevelCamera to delimitate room.")

### -----------------------------------------------------------------------------------------------

###################################################################################################
# Custom Inspector ################################################################################
###################################################################################################

func _get_custom_properties() -> Dictionary:
	var custom_properties := {
		"After Fight Room": {
			type = TYPE_NIL,
			usage = PROPERTY_USAGE_GROUP,
			hint_string = "after_fight_",
		},
		"after_fight_use_new_room": {
			default_value = false,
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
#		"": {
#			backing_field = "", # use if dict key and variable name are different
#			default_value = "", # use if you want property to have a default value
#			type = TYPE_NIL,
#			usage = PROPERTY_USAGE_DEFAULT,
#			hint = PROPERTY_HINT_NONE,
#			hint_string = "",
#		},
	}
	
	if after_fight_use_new_room:
		var after_limits := [
				"after_fight_limit_left", "after_fight_limit_top",
				"after_fight_limit_right","after_fight_limit_bottom"
		]
		for key in after_limits:
			custom_properties[key] = {
					type = TYPE_INT,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			}
		
		custom_properties["after_fight_zoom"] = {
				default_value = 1.0,
				type = TYPE_FLOAT,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
				hint = PROPERTY_HINT_RANGE,
				hint_string = "0.0,3.0,0.01,or_greater",
		}
		custom_properties["after_fight_transition_duration"] = {
				default_value = 0.8,
				type = TYPE_FLOAT,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
				hint = PROPERTY_HINT_RANGE,
				hint_string = "0.0,3.0,0.01,or_greater",
		}
	
	custom_properties["Editor Previews"] = {
			type = TYPE_NIL,
			usage = PROPERTY_USAGE_GROUP,
			hint_string = "preview_",
	}
	custom_properties["preview_camera"] = {
			default_value = true,
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}
	custom_properties["preview_camera_color"] = {
			default_value = Color.INDIGO,
			type = TYPE_COLOR,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}
	custom_properties["preview_after_room"] = {
			default_value = true,
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}
	custom_properties["preview_after_color"] = {
			default_value = Color.TEAL,
			type = TYPE_COLOR,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}
	
	return custom_properties


### Custom Inspector built in functions -----------------------------------------------------------

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	
	var custom_properties := _get_custom_properties()
	for key in custom_properties:
		var dict: Dictionary = custom_properties[key]
		if not dict.has("name"):
			dict.name = key
		properties.append(dict)
	
	return properties


func _property_can_revert(property: StringName) -> bool:
	var custom_properties := _get_custom_properties()
	if property in custom_properties and custom_properties[property].has("default_value"):
		return true
	else:
		return false


func _property_get_revert(property: StringName):
	var value
	
	var custom_properties := _get_custom_properties()
	if property in custom_properties and custom_properties[property].has("default_value"):
		value = custom_properties[property]["default_value"]
	
	return value


func _get(property: StringName):
	var value
	
	var custom_properties := _get_custom_properties()
	if property in custom_properties and custom_properties[property].has("backing_field"):
		value = get(custom_properties[property]["backing_field"])
	
	return value


func _set(property: StringName, value) -> bool:
	var has_handled: = false
	
	var custom_properties := _get_custom_properties()
	if property in custom_properties and custom_properties[property].has("backing_field"):
		set(custom_properties[property]["backing_field"], value)
		has_handled = true
	
	return has_handled

### -----------------------------------------------------------------------------------------------
