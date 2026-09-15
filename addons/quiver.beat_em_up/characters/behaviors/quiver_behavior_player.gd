class_name QuiverBehaviorPlayer
extends QuiverBehavior

## 玩家行为脚本——全场唯一接触物理键盘/手柄的角色组件。
##
## 两条泵水路径：
## [br]· 事件类（"刚按了X"）：_unhandled_input 收到 OS 广播后，转投宿主状态机
##   的 deliver_event 注入口（沿用原有的"输入窗口"门控，行为与改造前一致），
##   并在通道上盖法术等自定义轮询键的边沿戳。
## [br]· 轮询类（摇杆/按住）：pre_physics 每帧把真实输入状态刷进通道。
##
## 过场/对话期间的总开关用基类 [member QuiverBehavior.active]（置 false 即
## 停止采集并清零通道，供剧情系统调用）。

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _enter_tree() -> void:
	# 多个玩家操控角色共存时提醒（v1 允许共存，便于双打测试；正式关卡应由
	# 关卡设计保证只有一个 PLAYER_INPUT 档角色）。
	if Engine.is_editor_hint():
		return
	add_to_group("player_controlled_behavior")
	_warn_if_multiple_players.call_deferred()


func _warn_if_multiple_players() -> void:
	if not is_inside_tree():
		return
	for other in get_tree().get_nodes_in_group("player_controlled_behavior"):
		if other != self and is_instance_valid(other) and other.is_inside_tree():
			push_warning("检测到多个玩家操控角色共用同一键盘：%s / %s" % [
					str(other.get_path()), str(get_path())])
			return


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not active:
		return
	# 边沿盖戳：供根脚本轮询的自定义键（法术 spell_1..4 等）读取。
	# InputMap 映射的动作在输入阶段即表现为 InputEventAction。
	if event is InputEventAction and not event.is_echo():
		if event.pressed:
			_channel.press(String(event.action))
		else:
			_channel.release(String(event.action))
	# 事件转投宿主状态机（窗口门控在 deliver_event 内部，保持原语义）
	var machine := _get_machine()
	if machine != null:
		machine.deliver_event(event)

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func pre_physics(_delta: float) -> void:
	if Engine.is_editor_hint() or _channel == null:
		return
	if active:
		_channel.refresh_from_os()
	else:
		_channel.reset()

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _get_machine() -> QuiverStateMachine:
	if _character == null:
		return null
	return _character.state_machine

### -----------------------------------------------------------------------------------------------
