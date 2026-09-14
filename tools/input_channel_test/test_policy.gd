extends QuiverBehaviorAI
class_name TestChannelPolicy

## WP1 断言专用小抄：等宿主状态机就绪后按一次攻击键。

var _ticks := 0
var _pressed := false


func tick(_delta: float) -> void:
	_ticks += 1
	if _ticks >= 10 and not _pressed:
		_pressed = true
		press_attack()
		release_attack()
