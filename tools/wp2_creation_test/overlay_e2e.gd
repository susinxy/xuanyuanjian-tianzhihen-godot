extends Node

## 引擎级端到端断言：取角色插件里的真实测试场景模板 → 以"被测者=spar_enemy"
## 组装 → 写盘 → 正常装载运行（等物理帧让各节点的 _ready 真实发生）→
## 验证两个调试数据窗口确实解析到了被测者本人。
## 背景教训：窗口曾用"节点对象引用型"导出，文本赋值从不生效（恒 null），
## 一直靠"自动找第一个角色"兜底——表现为"测怪物却显示 chen"。
## 主权迁移（B2.5 Task4）：底版主角位从活体 chen 换成矩阵替身 test_actor
## （本套需要的是"场景里有一个玩家身体在位"，历史教训只作注释存档）。
## 运行：godot --headless --path . res://tools/wp2_creation_test/overlay_e2e.tscn

const Kit := preload("res://tools/matrix_runner/test_actor_kit.gd")
const SUBJECT := "res://characters/enemies/spar_enemy/spar_enemy.tscn"


## 头部三态守卫（input_channel 同款只读阶梯；缺席打可读红、绝不代 runner 创建——
## 生成物在运行时真实例化主角位，替身缺席/未导入都会把本套打成假现场）
func _guard_actor() -> bool:
	var remedy := "先跑 bash tools/matrix_runner/run_matrix.sh --ensure-only 建好 test_actor"
	if not Kit.exists():
		_check(false, "替身守卫：test_actor 缺席（%s）" % remedy)
		return false
	var rc := Kit.ensure()
	if rc == Kit.NEEDS_IMPORT:
		_check(false, "替身守卫：test_actor 在但本进程不可加载=NEEDS_IMPORT(42)（%s）" % remedy)
		return false
	if rc != OK:
		_check(false, "替身守卫：ensure() 报产线失败（rc=%d，诊断见上行）" % rc)
		return false
	print("ACTOR-GATE: test_actor 就绪（只读三态守卫通过）")
	return true


func _ready() -> void:
	var fails := 0
	if not _guard_actor():
		print("════════ overlay-e2e: %s ════════" % ("PASS" if fails == 0 else "FAIL"))
		get_tree().quit(1)
		return
	
	var gen := QuiverRunTestSceneBuilder.base_scene_text()
	gen = gen.replace("{{CHAR_NAME}}", "spar_enemy")
	gen = gen.replace("{{CHAR_PATH}}", Kit.ACTOR_SCENE)
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
	var okh: bool = ovh.character != null and String(ovh.character.name) == "Subject"
	_check(okh, "高度竖条真正跟随被测者")
	if not okh:
		fails += 1
	_check(stage.get_node("DebugLabel").visible == false,
			"操作说明牌已隐身（文字进 Dock[帮助]页）")
	
	print("════════ overlay-e2e: %s ════════" % ("PASS" if fails == 0 else "FAIL"))
	stage.queue_free()
	get_tree().quit(0 if fails == 0 else 1)


func _check(ok: bool, name: String) -> void:
	print("  %s: %s" % ["PASS" if ok else "FAIL", name])
