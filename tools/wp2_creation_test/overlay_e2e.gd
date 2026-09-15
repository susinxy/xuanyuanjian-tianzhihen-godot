extends Node

## 引擎级端到端断言：取角色插件里的真实测试场景模板 → 以"被测者=spar_enemy"
## 组装 → 写盘 → 正常装载运行（等物理帧让各节点的 _ready 真实发生）→
## 验证两个调试数据窗口确实解析到了被测者本人。
## 背景教训：窗口曾用"节点对象引用型"导出，文本赋值从不生效（恒 null），
## 一直靠"自动找第一个角色"兜底——表现为"测怪物却显示 chen"。
## 运行：godot --headless --path . res://tools/wp2_creation_test/overlay_e2e.tscn

const SUBJECT := "res://characters/enemies/spar_enemy/spar_enemy.tscn"


func _ready() -> void:
	var fails := 0
	
	var gen := QuiverRunTestSceneBuilder.base_scene_text()
	gen = gen.replace("{{CHAR_NAME}}", "spar_enemy")
	gen = gen.replace("{{CHAR_PATH}}", "res://characters/playable/chen/chen.tscn")
	gen = QuiverRunTestSceneBuilder.compose(gen, SUBJECT, 1)
	
	var uf := FileAccess.open("user://overlay_e2e.tscn", FileAccess.WRITE)
	uf.store_string(gen)
	uf.close()
	var stage: Node = (load("user://overlay_e2e.tscn") as PackedScene).instantiate()
	add_child(stage)
	# 关键：真实跑两帧，让 _ready（含窗口的路径解析）完整发生
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	var ovh: Node = stage.get_node("DebugHeightOverlay")
	var ovk: Node = stage.get_node("DebugKnockoutOverlay")
	var okh: bool = ovh.character != null and String(ovh.character.name) == "Subject"
	var okk: bool = ovk.character != null and String(ovk.character.name) == "Subject"
	_check(okh, "高度窗口真正显示被测者")
	_check(okk, "击倒窗口真正显示被测者")
	if not okh:
		fails += 1
	if not okk:
		fails += 1
	
	print("════════ overlay-e2e: %s ════════" % ("PASS" if fails == 0 else "FAIL"))
	stage.queue_free()
	get_tree().quit(0 if fails == 0 else 1)


func _check(ok: bool, name: String) -> void:
	print("  %s: %s" % ["PASS" if ok else "FAIL", name])
