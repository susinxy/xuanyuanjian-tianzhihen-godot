extends Node

## 动画树连通性回归测试（chen 皮肤）：
##  1) 中枢原则：非 idle 状态之间不得有直连边（连段链 attack1→2→3 除外）；
##     walk↔run、walk→attack1 这类边曾存在、2026-09-15 按用户原则移除（travel
##     经 idle 中转同帧推进完毕、无观感差异，边数组合爆炸才是问题）。
##  2) 回连完整：除 die（合法终态）外，每个状态必须能 travel 回 idle——
##     attack2 缺回连 idle 的 bug（寻路会误放 attack3）即本条抓获。
## 运行：godot --headless --path . res://tools/tree_connectivity_test/connectivity.tscn

const CHEN := "res://characters/playable/chen/chen.tscn"

var _fails := 0


func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails += 1
	print("  %s: %s" % ["PASS" if ok else "FAIL", label])


func _ready() -> void:
	var chen: Node = (load(CHEN) as PackedScene).instantiate()
	add_child(chen)
	for _i in 5:
		await get_tree().physics_frame
	var skin = chen._skin
	var tree: AnimationTree = skin.get("_animation_tree")
	var sm: AnimationNodeStateMachine = tree.tree_root.get_node("state_machine")
	var playback = skin._playback
	# 4.7 序列化：transitions = 平坦三元组数组 [from, to, Transition资源, ...]
	var raw: Array = sm.get("transitions")
	var edges: Array[String] = []
	for i in range(0, raw.size(), 3):
		edges.append("%s|%s" % [String(raw[i]), String(raw[i + 1])])

	# ── 1) 中枢原则定向断言（用户 2026-09-15 拍板的边集合） ──
	for banned in [["walk", "run"], ["run", "walk"], ["walk", "attack1"],
			["run", "attack1"], ["walk", "spell"], ["run", "spell"]]:
		_check(not _has_edge(edges, banned[0], banned[1]),
				"冗余边 %s→%s 不存在（经 idle 中转）" % banned)
	var state_names: Array[String] = []
	for pr in sm.get_property_list():
		var pn := String(pr.name)
		if pn.begins_with("states/") and pn.ends_with("/node"):
			state_names.append(pn.get_slice("/", 1))
	for name_str in state_names:
		if name_str != "spell":
			continue
		var spell_edges: Array[String] = []
		for e in edges:
			var pair: PackedStringArray = e.split("|")
			if pair[0] == name_str:
				spell_edges.append("→" + String(pair[1]))
			elif pair[1] == name_str:
				spell_edges.append(String(pair[0]) + "→")
		spell_edges.sort()
		var want: Array[String] = ["→idle", "idle→"]
		want.sort()
		_check(spell_edges == want,
				"spell 只与 idle 直连（实际=%s）" % str(spell_edges))
	_check(_has_edge(edges, "attack2", "idle"),
			"attack2 已回连 idle（曾缺边：寻路误放 attack3）")

	# ── 2) 全态可达 idle ──
	for name_str in state_names:
		if name_str == "Start" or name_str == "die":
			continue
		playback.travel(StringName(name_str))
		await get_tree().physics_frame
		await get_tree().physics_frame
		playback.travel(&"idle")
		var reached := false
		for _i in 4:
			await get_tree().physics_frame
			if String(playback.get_current_node()) == "idle":
				reached = true
				break
		_check(reached, "状态 %s 可寻路回 idle" % name_str)

	print("════════ tree-connectivity: %s ════════" % ("PASS" if _fails == 0 else "FAIL"))
	get_tree().quit(0 if _fails == 0 else 1)


func _has_edge(edges: Array[String], from: String, to: String) -> bool:
	return edges.has("%s|%s" % [from, to])
