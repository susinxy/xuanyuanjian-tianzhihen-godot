extends SceneTree

## Run Test 产线对等断言（2026-09-15 底版统一后重写）。
## 法术测试场景 = 角色底版 + 法术套件（结构性保证，不再依赖人工对表）。
## 断言三层：
##  1) 底版必备部件双方齐（共用同一 base_scene_text，天然成立，防有人绕过底版）；
##  2) 法术侧节点集合必须是角色侧**超集**（发令台型漏装的根治形态）；
##  3) 法术套件独有件在位：helper 节点/脚本行、法术面板、数据窗口右列避让、
##     帮助文本标注。
## 运行：godot --headless --path . -s tools/test_scene_parity/parity.gd

const CHEN := "res://characters/playable/chen/chen.tscn"
const HELPER := "res://test_scenes/_test_spell_helper_x.gd"

const REQUIRED_BOTH := ["Character", "LevelCamera", "Background", "Ground",
		"DebugHeightOverlay", "DebugKnockoutOverlay", "AIConductor", "Enemy",
		"DebugDockOpen", "GameHUD",
		"DebugLabel", "DayNightController", "DebugDayNightInput",
		"ShadowRegion", "ShortWall", "TallWall", "Platform"]
const KIT_ONLY := ["TestSpellHelper"]

var _fail := 0


func _initialize():
	var char_text := _compose_of(_base_with_tokens(), CHEN, 0)
	var spell_base := QuiverRunTestSceneBuilder.add_spell_test_kit(
			_base_with_tokens(), "fire_ball", HELPER)
	var spell_text := _compose_of(spell_base, CHEN, 0)
	
	var char_nodes := _nodes_of(char_text)
	var spell_nodes := _nodes_of(spell_text)
	if char_nodes.is_empty() or spell_nodes.is_empty():
		print("  FAIL: 底版装配失败")
		quit(1)
		return
	
	for req in REQUIRED_BOTH:
		_check(req in char_nodes, "角色场景含底版部件 %s" % req)
		_check(req in spell_nodes, "法术场景含底版部件 %s" % req)
	var missing := []
	for n in char_nodes:
		if not n in spell_nodes:
			missing.append(n)
	_check(missing.is_empty(), "法术场景是角色场景的节点超集（缺=%s）" % missing)
	for k in KIT_ONLY:
		_check(k in spell_nodes, "法术套件独有件在位 %s" % k)
		_check(not k in char_nodes, "角色场景不混入法术件 %s" % k)
	
	# 套件细节
	_check(spell_text.contains("[node name=\"TestSpellHelper\" type=\"Node\" parent=\"Character\"]\nscript = ExtResource(\"5_test_helper\")"),
			"helper 挂被测角色下且绑定注入脚本")
	_check(spell_text.contains("panel_position = Vector2(845, 10)")
			and spell_text.contains("panel_position = Vector2(845, 270)"),
			"两数据窗口右列避让（845 列）")
	_check(spell_text.contains("=== 法术测试: fire_ball"), "帮助文本标注被测法术")
	_check(spell_text.contains("[gd_scene load_steps=21"), "load_steps 已随套件 +1（诊断面板迁入 DebugDock）")
	_check(spell_text.contains(HELPER), "helper 脚本 ext 路径注入")
	
	# 角色侧不得被套件污染（回归锁）
	_check("add_spell_test_kit" not in char_text and "TestSpellHelper" not in char_text,
			"角色流未混入法术套件")
	
	print("════════ scene-parity: %s ════════" % ("PASS" if _fail == 0 else "FAIL"))
	quit(0 if _fail == 0 else 1)


func _base_with_tokens() -> String:
	return QuiverRunTestSceneBuilder.base_scene_text()\
			.replace("{{CHAR_NAME}}", "chen").replace("{{CHAR_PATH}}", CHEN)


func _compose_of(text: String, char_path: String, mode: int) -> String:
	return QuiverRunTestSceneBuilder.compose(text, char_path, mode)


func _nodes_of(text: String) -> Array[String]:
	var out: Array[String] = []
	var nx := RegEx.new()
	nx.compile("(?m)^\\[node name=\"([^\"]+)\"")
	for mm in nx.search_all(text):
		var n: String = mm.get_string(1)
		if not n in out:
			out.append(n)
	return out


func _check(ok: bool, label: String) -> void:
	if not ok:
		_fail += 1
	print("  %s: %s" % ["PASS" if ok else "FAIL", label])
