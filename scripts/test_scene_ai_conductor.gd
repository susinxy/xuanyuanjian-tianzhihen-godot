extends Node

## Run Test 场景的 AI 发令台（仅生成物测试场景使用，正式关卡不挂）。
##
## 场景就绪后把所有"AI 档行为"的角色置 active=false（待命），
## 按一下 Enter 全体开始/再按暂停——测试者由此控制交手起点，
## 可反复"暂停→摆位→再战"。玩家档/被动档角色不受影响。
## 原理用的是行为脚本基类的通用 active 原语（见 QuiverBehavior），
## 本节点只是它在测试场景里的第一个驱动者。

const TOGGLE_KEY: Key = KEY_ENTER

var _controlled: Array[QuiverBehavior] = []
var _running := false


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	_scan.call_deferred()


func _scan() -> void:
	_controlled = []
	_walk(get_tree().current_scene)
	for behavior in _controlled:
		behavior.active = false
	_running = false
	print("[Conductor] %d 只 AI 角色待命中——按 Enter 开始/暂停" % _controlled.size())


func _walk(node: Node) -> void:
	for child in node.get_children():
		if child is QuiverCharacter and child.behavior is QuiverBehaviorAI:
			_controlled.append(child.behavior)
		_walk(child)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode != TOGGLE_KEY:
		return
	_running = not _running
	for behavior in _controlled:
		behavior.active = _running
	var verb := "▶ 开始行动" if _running else "⏸ 暂停待命"
	print("[Conductor] %s（%d 只 AI）" % [verb, _controlled.size()])
