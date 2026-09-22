extends QuiverBehaviorAI
class_name TestChannelPolicy

## WP1 断言专用小抄：等宿主状态机就绪后按一次攻击键。

## 按压时刻（runner 的上升沿观察帽由此推导，Test3 评审：不留裸魔法数）
const PRESS_AT_TICK := 10

var _ticks := 0
var _pressed := false
## 实际按压发生的 tick 号（诊断用；语义不变）
var pressed_at := -1


func tick(_delta: float) -> void:
	_ticks += 1
	if _ticks >= PRESS_AT_TICK and not _pressed:
		_pressed = true
		pressed_at = _ticks
		press_attack()
		release_attack()
