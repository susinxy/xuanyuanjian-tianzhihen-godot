extends CanvasLayer

@export var character: CharacterBody2D

var _attributes: QuiverAttributes
var _panel: Panel
var _label: Label
var _error_message: String = ""

# 击飞快照数据
var _knockout_snapshot: Dictionary = {}

func _ready() -> void:
	_create_panel()
	
	if not character:
		_auto_find_character()
	
	if not character:
		_error_message = "❌ character: null (NodePath 未正确设置，且自动查找失败)"
		return
	
	_find_attributes()
	
	if not _attributes:
		_error_message = "❌ attributes: 未找到 QuiverAttributes"
		return
	
	_connect_signals()
	
	_error_message = ""


func _auto_find_character() -> void:
	var parent := get_parent()
	if not parent:
		return
	
	for child in parent.get_children():
		if child is CharacterBody2D:
			character = child
			return


func _create_panel() -> void:
	_panel = Panel.new()
	_panel.position = Vector2(370, 10)
	_panel.size = Vector2(350, 250)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.border_color = Color(1.0, 0.6, 0.3, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	
	_label = Label.new()
	_label.position = Vector2(10, 10)
	_label.size = Vector2(330, 230)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	_panel.add_child(_label)


func _find_attributes() -> void:
	_attributes = character.get("attributes")
	if _attributes:
		_attributes.hurt_requested.connect(_on_hurt_requested)
		return


func _connect_signals() -> void:
	if not _attributes:
		return
	
	_attributes.knockout_requested.connect(_on_knockout_requested)


func _on_knockout_requested(knockback: QuiverKnockbackData) -> void:
	# 记录击飞瞬间的数据快照
	_knockout_snapshot = {
		"knockback_amount": _attributes.knockback_amount,
		"knockback_weight": _attributes.knockback_weight,
		"launch_vector": knockback.launch_vector,
		"computed_velocity": knockback.launch_vector * _attributes.knockback_amount * _attributes.knockback_weight,
		"timestamp": Time.get_ticks_msec()
	}


func _on_hurt_requested(knockback: QuiverKnockbackData) -> void:
	pass


func _process(_delta: float) -> void:
	if not _panel or not _label:
		return
	
	if _error_message != "":
		_label.text = "=== 击飞调试 ===\n" + _error_message
		return
	
	if not character or not _attributes:
		return
	
	# 获取当前状态名称
	var state_name := "未知"
	if character.has_node("StateMachine"):
		var state_machine = character.get_node("StateMachine")
		if state_machine and state_machine.has_method("get_current_state"):
			var current_state = state_machine.get_current_state()
			if current_state:
				state_name = current_state.name
	
	# 实时数据
	_label.text = "=== 击飞调试 ===\n"
	_label.text += "knockback_amount: %d / 600\n" % _attributes.knockback_amount
	_label.text += "knockback_weight: %.1f\n" % _attributes.knockback_weight
	_label.text += "should_knockout: %s\n" % str(_attributes.should_knockout())
	_label.text += "状态: %s\n" % state_name
	_label.text += "is_invulnerable: %s\n" % str(_attributes.is_invulnerable)
	_label.text += "has_superarmor: %s\n" % str(_attributes.has_superarmor)
	_label.text += "health: %d / %d\n" % [_attributes.health_current, _attributes.health_max]
	
	# 击飞快照
	if not _knockout_snapshot.is_empty():
		_label.text += "\n[击飞记录]\n"
		_label.text += "knockback: %d × %.1f = %d\n" % [
			_knockout_snapshot.knockback_amount,
			_knockout_snapshot.knockback_weight,
			_knockout_snapshot.knockback_amount * _knockout_snapshot.knockback_weight
		]
		_label.text += "launch_vector: (%.2f, %.2f)\n" % [
			_knockout_snapshot.launch_vector.x,
			_knockout_snapshot.launch_vector.y
		]
		_label.text += "计算速度: (%.1f, %.1f)\n" % [
			_knockout_snapshot.computed_velocity.x,
			_knockout_snapshot.computed_velocity.y
		]
		
		# 计算最终速度（考虑 MAX_LAUNCH_SPEED = 2000）
		var final_velocity: Vector2 = _knockout_snapshot.computed_velocity
		var magnitude: float = final_velocity.length()
		if magnitude > 2000.0:
			final_velocity = final_velocity.normalized() * 2000.0
			_label.text += "最终速度: (%.1f, %.1f) [触发上限]\n" % [
				final_velocity.x,
				final_velocity.y
			]
		else:
			_label.text += "最终速度: (%.1f, %.1f)\n" % [
				final_velocity.x,
				final_velocity.y
			]
