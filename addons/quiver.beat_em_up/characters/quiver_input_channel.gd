class_name QuiverInputChannel
extends RefCounted

## 每具角色独享的私有输入通道（"虚拟手柄"）。
##
## 动作状态不再直接读物理键盘，只读本通道——"谁往通道里写"由行为脚本
## （QuiverBehavior 子类）决定：玩家行为抄真实键盘，AI 小抄写程序决策，
## 站立行为什么都不写。物理键盘事件永远不会到达非玩家角色的通道，
## 从数据结构上消灭"按键被其他角色听见"的串台问题。
##
## 三样数据：
## [br]· [member axis] —— 虚拟摇杆歪向（连续值，走路/空中控制读）
## [br]· [member is_held] —— "正按着没松"名单（walk 持续、抓取按住方向挣脱等）
## [br]· [member just_pressed] —— "本帧刚按下"边沿（读一次即消费，带 1 帧宽限）

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

## 边沿的有效年龄宽限（物理帧数）。用于吸收"事件阶段盖戳"与"轮询读取"
## 之间可能的帧号错位，并让冻结帧（HitFreeze）期间的按下存活到解冻后第一帧。
const EDGE_GRACE_TICKS := 1

#--- public variables - order: export > normal var > onready --------------------------------------

## 虚拟摇杆当前歪向（-1..1 的 2D 向量），由行为脚本每物理帧刷新。
var axis: Vector2 = Vector2.ZERO

#--- private variables - order: export > normal var > onready -------------------------------------

## 按住名单：动作名 -> 是否正被按住
var _held := {}

## 边沿表：动作名 -> 最后一次"刚按下"发生的物理帧号（读取即消费）
var _edge_tick := {}

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## 按下某个动作：写入按住名单并盖帧号戳。
func press(action: String) -> void:
	_held[action] = true
	_edge_tick[action] = Engine.get_physics_frames()


## 松开某个动作：只影响按住名单（边沿已被戳号自动过期管理）。
func release(action: String) -> void:
	_held[action] = false


## 写入虚拟摇杆歪向（AI 小抄"追/停"与玩家泵水共用）。
func set_axis(value: Vector2) -> void:
	axis = value


## 直接设置按住状态（不产生边沿）。AI 小抄需要"持续按住"语义时使用。
func set_held(action: String, value: bool) -> void:
	if value:
		_held[action] = true
	else:
		_held[action] = false


## 该动作此刻是否正被按住。
func is_held(action: String) -> bool:
	return _held.get(action, false)


## 该动作是否"刚按下"（边沿）。读一次即消费，保证一次按下只触发一次；
## 超过宽限期的陈旧边沿会被丢弃，不会跨帧重复触发。
func just_pressed(action: String) -> bool:
	var stamp: int = _edge_tick.get(action, -1)
	if stamp < 0:
		return false
	@warning_ignore("return_value_discarded")
	_edge_tick.erase(action)
	return Engine.get_physics_frames() - stamp <= EDGE_GRACE_TICKS


## 用真实键盘状态刷新摇杆与按住名单（仅玩家行为脚本调用）。
## 全量扫描 InputMap 动作表：动态键名（如抓取挣脱方向键）因此零特判。
func refresh_from_os() -> void:
	axis = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	for action_s in InputMap.get_actions():
		var action := String(action_s)
		if not action.begins_with("ui_"):
			_held[action] = Input.is_action_pressed(action)


## 清空一切状态（行为脚本切换时调用，防止旧操控者残留按住/边沿）。
func reset() -> void:
	axis = Vector2.ZERO
	_held.clear()
	_edge_tick.clear()


## 清理超龄边沿（无轮询者读取的按键会留下陈旧戳，如 AI 连点攻击键）。
## 由宿主角色每物理帧调用一次。
func prune_stale_edges() -> void:
	if _edge_tick.is_empty():
		return
	var now := Engine.get_physics_frames()
	for action in _edge_tick.keys():
		if now - _edge_tick[action] > EDGE_GRACE_TICKS:
			_edge_tick.erase(action)

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
