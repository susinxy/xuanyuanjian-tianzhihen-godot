extends Node
## 调试用：按键切换相位 / 触发光照覆盖
## 按键：
##   1 → 切换到 DAWN（黎明）
##   2 → 切换到 DAY（白天）
##   3 → 切换到 DUSK（黄昏）
##   4 → 切换到 NIGHT（夜晚）
##   O → 应用 3 秒临时覆盖（变暗，模拟 Boss 战）

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	
	var manager = get_node_or_null("/root/DayNightManager")
	if not manager:
		return
	
	match event.keycode:
		KEY_1:
			manager.transition_to(manager.TimePhase.DAWN)
		KEY_2:
			manager.transition_to(manager.TimePhase.DAY)
		KEY_3:
			manager.transition_to(manager.TimePhase.DUSK)
		KEY_4:
			manager.transition_to(manager.TimePhase.NIGHT)
		KEY_O:
			var override := LightingOverride.new()
			override.color = Color(0.2, 0.2, 0.3)
			override.light_rotation = 200.0
			override.light_energy = 0.3
			override.light_color = Color(0.4, 0.3, 0.5)
			override.transition_duration = 0.5
			manager.apply_lighting_override(override, 3.0)
