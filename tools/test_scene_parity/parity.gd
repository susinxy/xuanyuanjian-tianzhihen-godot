extends SceneTree

## Run Test 场景"功能对等"清单断言（2026-09-15 审计 T3：发令台只挂角色场景、
## 法术场景漏装的同类问题防再发）。对两侧插件模板跑同一 compose 后：
##  1) 必备公共部件必须双方都有；
##  2) 单侧独有部件必须在豁免白名单里显式登记——
##     任何一侧新增公共性部件而未同步/未登记 → 红灯。
## 运行：godot --headless --path . -s tools/test_scene_parity/parity.gd

const CHAR_PLUGIN := "res://addons/quiver.beat_em_up/custom_inspectors/create_new_character/inspector_plugin.gd"
const SPELL_PLUGIN := "res://addons/quiver.beat_em_up/custom_inspectors/create_new_spell/inspector_plugin.gd"
const CHEN := "res://characters/playable/chen/chen.tscn"

## 两侧都必须存在的部件（角色节点名）
const REQUIRED_BOTH := ["Character", "LevelCamera", "Background",
		"DebugHeightOverlay", "DebugKnockoutOverlay", "AIConductor", "Enemy", "DebugLabel"]
## 允许单侧独有（豁免登记，改模板必须同步改这张表）
const CHAR_ONLY := ["TestStage", "Ground", "CollisionShape2D", "Platform", "ShortWall",
		"TallWall", "Visual", "CanvasModulate", "DirectionalLight2D", "Lantern1",
		"Lantern2", "DayNightController", "DebugDayNightInput", "ShadowRegion",
		"Label"]
const SPELL_ONLY := ["TestSpellStage", "Ground", "CollisionShape2D",
		"TestSpellHelper", "DebugOverlay", "Label"]

var _fail := 0


func _initialize():
	var char_nodes := _composed_nodes(load(CHAR_PLUGIN), CHEN)
	var spell_nodes := _composed_nodes(load(SPELL_PLUGIN), CHEN)
	if char_nodes.is_empty() or spell_nodes.is_empty():
		print("  FAIL: 模板提取失败 char=", char_nodes.size(), " spell=", spell_nodes.size())
		quit(1)
		return
	for req in REQUIRED_BOTH:
		_check(req in char_nodes, "角色场景含必备部件 %s" % req)
		_check(req in spell_nodes, "法术场景含必备部件 %s" % req)
	for n in char_nodes:
		_check(n in REQUIRED_BOTH or n in CHAR_ONLY, "角色侧节点已登记：%s" % n)
	for n in spell_nodes:
		_check(n in REQUIRED_BOTH or n in SPELL_ONLY, "法术侧节点已登记：%s" % n)
	print("════════ scene-parity: %s ════════" % ("PASS" if _fail == 0 else "FAIL"))
	quit(0 if _fail == 0 else 1)


func _composed_nodes(plugin, char_path: String) -> Array[String]:
	var src := FileAccess.get_file_as_string(plugin.resource_path)
	var rx := RegEx.new()
	rx.compile("(?s)var test_scene_template = \"\"\"(.*?)\"\"\"")
	var m := rx.search(src)
	var seen := {}
	var out: Array[String] = []
	if m == null:
		return out
	var t: String = m.get_string(1)
	t = t.replace("{{CHAR_NAME}}", "chen").replace("{{CHAR_PATH}}", char_path)
	t = t.replace("{{SPELL_NAME}}", "x").replace("{{TEST_HELPER_PATH}}", "res://x.gd")
	t = QuiverRunTestSceneBuilder.compose(t, char_path, 0)
	var nx := RegEx.new()
	nx.compile("(?m)^\\[node name=\"([^\"]+)\"")
	for mm in nx.search_all(t):
		var n: String = mm.get_string(1)
		if not seen.has(n):
			seen[n] = true
			out.append(n)
	return out


func _check(ok: bool, label: String) -> void:
	if not ok:
		_fail += 1
	print("  %s: %s" % ["PASS" if ok else "FAIL", label])
