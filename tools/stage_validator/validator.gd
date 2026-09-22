extends SceneTree

## 关卡装配校验器（S1-T4，矩阵第 21 项）：对 spec §5 地点契约做 R1-R10 十条
## 独立规则的机械执法。**只读 .tscn 文本**（FileAccess+逐行解析），不走
## ResourceLoader——避免加载副作用与对未落地依赖的真实解析。
## 运行：
##   矩阵：  godot --headless --path . -s tools/stage_validator/validator.gd
##           （默认扫 scenes/stages/**/*.tscn；目录未建=T5 前真空绿，非错误）
##   自检：  ... -s tools/stage_validator/validator.gd -- --fixtures
##           （跑 tools/stage_validator/fixtures/，每个 fixture 首行
##            `[gd_scene ... expect="R#"]` 声明**恰**触发的规则；
##            stage_ok 声明 none 必须全绿）
## 规则表（账本裁决绑定版；S2-M1-B1 双轨扩，spec D10）：
##   R1 根必须 instance=ExtResource(base_stage.tscn **或** chapter_shell.tscn)
##   R2 根节点存在形态主键 = &"..." 非空（S1 终审 M-2：限定根属性块，
##      挂在子孙节点上的主键属污染残留，不算满足）：
##      base 形态查 stage_id；shell 形态查 chapter_id（R2' 并表同码，hint 区分）
##   R3 每个 QuiverFightRoom 子树含 ≥1 检测器与 ≥1 生成器
##   R4 检测器 path_fight_room 非空 且 paths_enemy_spawners ≥1 条非空路径
##   R5 生成器 path_spawn_parent ∈ 两种合法形态（白名单）：base 轨
##      ../../../Level/Characters（房挂 FightRooms 下恒 3 级）/ shell 轨
##      ../../../../Players（段挂壳 Segments 下恒 4 级，spec C6）；默认值/缺失红
##   R6 生成器 spawn_waves 在位且每个 SubResource 有 enemy_scene=ExtResource
##      指向盘上真实存在的 .tscn
##   R7 Level/Collisions 下每个 StaticBody2D：collision_layer 必须存在、
##      含全部高度层（bit15-24，16760832）且无旧屏限位（值 4=layer3 屏限、
##      值 8=layer4 顶限，合计 12）；bit2 障碍位允许出现（不检查）
##   R8 地点含 StageExit 子树（脚本识别）或 ends_after_last_room = true；
##      shell 形态天然豁免（章节终点=ChapterShell.chapter_finished 信号构造自带）
##   R9 同一 spawner 路径被 ≥2 个不同房的检测器引用（跨房重引）= 违例
##   （WIP 豁免：目录内放 .wip 空文件=该目录树整体跳过并打 NOTICE）
##   R10 背景 CanvasLayer 显式写的 layer 必须 <0（≥0 连角色/阴影合成层整个盖掉；
##       负档是软边阴影自动档 z=Level-1 正确落位的承重墙，2026-09-20 光照收编）

const BASE_PATH := "res://scenes/base/base_stage.tscn"
const SHELL_PATH := "res://scenes/chapter/chapter_shell.tscn"
const STAGES_DIR := "res://scenes/stages"
const FIXTURES_DIR := "res://tools/stage_validator/fixtures"
const HEIGHT_ALL := 16760832  # = QuiverCharacter.get_all_height_layers_mask()
const OLD_GUARD_BITS := 12    # 屏限 bit 值 4 + 顶限 bit 值 8
const ROOM_GD := "quiver_fight_room.gd"
const DET_GD := "quiver_player_detector.gd"
const SPAWN_GD := "quiver_enemy_spawner.gd"
const EXIT_GD := "stage_exit.gd"
# R5 白名单双形（spec D10/C6）：base 轨房挂 FightRooms 下恒 3 级到根；
# shell 轨段挂壳 Segments 下、房直接挂段根，恒 4 级到壳根 Players
const LEGAL_SPAWN_PARENTS := [
	'NodePath("../../../Level/Characters")',
	'NodePath("../../../../Players")',
]

var _rx_attr := _rx('(\\w+)="([^"]*)"')
var _rx_prop := _rx("^([A-Za-z0-9_/]+) = (.+)$")
var _rx_extref := _rx('ExtResource\\("([^"]*)"\\)')
var _rx_subref := _rx('SubResource\\("([^"]*)"\\)')
var _rx_nodepath := _rx('NodePath\\("([^"]*)"\\)')


## 4.7 探针实证：RegEx 实例方法 create_from_string 现返回编译好的 RegEx
## （不是 Error）；RegExMatch 禁整数下标，取组一律 get_string(i)
static func _rx(pattern: String) -> RegEx:
	var made = RegEx.new().create_from_string(pattern)
	return made if made is RegEx else RegEx.new()


func _initialize() -> void:
	var fixtures_mode := OS.get_cmdline_user_args().has("--fixtures")
	var dir := FIXTURES_DIR if fixtures_mode else STAGES_DIR
	var files: Array = []
	_collect(dir, files)
	if fixtures_mode:
		quit(_run_fixtures(files))
		return
	quit(_run_default(files))


func _collect(dir: String, out: Array) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	# WIP 豁免（仿 .gdignore 先例，2026-09-21）：目录放 .wip 标记文件=整树跳过
	# 执法扫描并打印 NOTICE——法典"必过校验才有 F5 资格"针对成品地点，
	# 在施章节不该让全量回归矩阵替 WIP 红灯背书。
	if FileAccess.file_exists(dir.path_join(".wip")):
		print("NOTICE: WIP 目录豁免扫描 " + dir)
		return
	var d := DirAccess.open(dir)
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		var p := dir.path_join(f)
		if d.current_is_dir():
			_collect(p, out)
		elif f.ends_with(".tscn"):
			out.append(p)
		f = d.get_next()
	d.list_dir_end()


## 默认模式：正式地点逐文件报违例；空/缺目录 = 0 关 0 违例（绿）
func _run_default(files: Array) -> int:
	var total_fails := 0
	for p in files:
		var violations := _check_file(p)
		total_fails += violations.size()
		for v in violations:
			print("FAIL %s: %s %s" % [v.rule, p, v.hint])
	print("RESULT: 校验 %d 关 / 违例 %d" % [files.size(), total_fails])
	return 0 if total_fails == 0 else 1


## fixtures 模式：每文件触发的规则集合必须与 `# expect:` 声明一致
func _run_fixtures(files: Array) -> int:
	var bad := 0
	for p in files:
		var expect := _expect_of(p)
		var triggered := {}
		for v in _check_file(p):
			triggered[v.rule] = true
		var exp_set := {}
		if expect != "none" and expect != "":
			exp_set[expect] = true
		if triggered == exp_set:
			print("PASS %s（恰触发 %s）" % [p.get_file(), expect])
		else:
			bad += 1
			print("FAIL %s expect=%s triggered=%s" % [p.get_file(), expect, triggered.keys()])
	print("RESULT: 校验 %d fixture / 违例 %d" % [files.size(), bad])
	return 0 if bad == 0 and not files.is_empty() else 1


## expect 声明：fixture 首行 `[gd_scene ... expect="R#"]` 头属性。S1-T4 探针
## 实证 .tscn 词法器**不支持任何注释**（首行 `# expect` 与 body 注释均加载
## 失败），而未知头属性被加载器安全忽略且可正常加载——故声明载体从 brief
## 的头行注释改记为头属性（语义不变：声明住在 fixture 文件里）。
func _expect_of(path: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	var head := text.split("\n")[0]
	if not head.begins_with("[gd_scene"):
		return ""
	return _attr(head, "expect")


#--- 校验核心 --------------------------------------------------------------------------------------

func _check_file(path: String) -> Array:
	var text := FileAccess.get_file_as_string(path)
	var model := _parse(text)
	var out: Array = []
	var add := func(rule: String, hint: String) -> void:
		out.append({rule = rule, hint = hint})
	var root: Dictionary = model.nodes[0] if not model.nodes.is_empty() else {}
	# 双轨判形（D10）：R1 通过的两形态之一=壳形态；R2/R8 按形分派
	var is_shell: bool = not root.is_empty() and (root.inst in model.exts) \
			and model.exts[root.inst] == SHELL_PATH
	_check_r1(model, root, add)
	_check_r2(root, add, is_shell)
	var rooms := _kind_nodes(model, ROOM_GD)
	var detectors := _kind_nodes(model, DET_GD)
	var spawners := _kind_nodes(model, SPAWN_GD)
	_check_r3(rooms, detectors, spawners, add)
	_check_r4(detectors, add)
	_check_r5(spawners, add)
	_check_r6(spawners, model, add)
	_check_r7(model, add)
	_check_r8(model, add, is_shell)
	_check_r9(rooms, detectors, add)
	_check_r10(model, add)
	return out


func _parse(text: String) -> Dictionary:
	var model := {exts = {}, subs = {}, nodes = []}
	var cur = null
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("[ext_resource"):
			cur = null
			model.exts[_attr(line, "id")] = _attr(line, "path")
		elif line.begins_with("[sub_resource"):
			cur = {type = _attr(line, "type"), props = {}}
			model.subs[_attr(line, "id")] = cur
		elif line.begins_with("[node"):
			var parent := _attr(line, "parent")
			var name := _attr(line, "name")
			var inst := ""
			var m := _rx_extref.search(line)
			if m and "instance=" in line:
				inst = m.get_string(1)
			cur = {
				name = name, type = _attr(line, "type"), parent = parent,
				full = name if parent.is_empty() or parent == "." else parent + "/" + name,
				inst = inst, props = {},
			}
			model.nodes.append(cur)
		elif line.is_empty() or line.begins_with("#"):
			continue
		elif cur != null:
			var pm := _rx_prop.search(line)
			if pm:
				cur.props[pm.get_string(1)] = pm.get_string(2)
	return model


func _attr(line: String, key: String) -> String:
	for m in _rx_attr.search_all(line):
		if m.get_string(1) == key:
			return m.get_string(2)
	return ""


func _script_path_of(node: Dictionary, model: Dictionary) -> String:
	var m := _rx_extref.search(node.props.get("script", ""))
	return model.exts.get(m.get_string(1), "") if m else ""


func _kind_nodes(model: Dictionary, script_file: String) -> Array:
	var out: Array = []
	for n in model.nodes:
		if _script_path_of(n, model).ends_with(script_file):
			out.append(n)
	return out


func _check_r1(model: Dictionary, root: Dictionary, add: Callable) -> void:
	if root.is_empty() or not (root.inst in model.exts) \
			or (model.exts[root.inst] != BASE_PATH
					and model.exts[root.inst] != SHELL_PATH):
		add.call("R1", "根未实例化 base_stage.tscn")


func _check_r2(root: Dictionary, add: Callable, is_shell: bool) -> void:
	# 壳形态主键=chapter_id（R2' 并表：同码 R2 报告，hint 区分形态）
	if is_shell:
		var c: String = root.props.get("chapter_id", "")
		if c.begins_with('&"') and c.length() > 3:
			return
		add.call("R2", "壳形态根缺 chapter_id = &\"...\" 非空行（单地点形态才查 stage_id）")
		return
	var v: String = root.props.get("stage_id", "")
	if v.begins_with('&"') and v.length() > 3:
		return
	add.call("R2", "根节点缺 stage_id = &\"...\" 非空行")


func _check_r3(rooms: Array, detectors: Array, spawners: Array, add: Callable) -> void:
	for room in rooms:
		var dets := _under(room, detectors)
		var sps := _under(room, spawners)
		if dets.is_empty() or sps.is_empty():
			add.call("R3", "房 %s 子树缺%s%s" % [room.full,
					"检测器" if dets.is_empty() else "",
					"和生成器" if (dets.is_empty() and sps.is_empty())
						else ("生成器" if sps.is_empty() else "")])


func _under(room: Dictionary, nodes: Array) -> Array:
	return nodes.filter(func(n): return n.full.begins_with(room.full + "/"))


func _check_r4(detectors: Array, add: Callable) -> void:
	for det in detectors:
		var room_p := _nodepath_of(det.props.get("path_fight_room", ""))
		var sp_list := _nodepaths_of(det.props.get("paths_enemy_spawners", ""))
		if room_p.is_empty() or sp_list.is_empty():
			add.call("R4", "检测器 %s path_fight_room/spawner 路径不全" % det.full)


func _check_r5(spawners: Array, add: Callable) -> void:
	for sp in spawners:
		var raw: String = sp.props.get("path_spawn_parent", "")
		# 白名单双形（base 三级/shell 四级）；缺行=运行时吃上游默认值，同罪
		if raw.is_empty():
			add.call("R5", "生成器 %s path_spawn_parent 缺失（吃上游默认）" % sp.full)
		elif raw not in LEGAL_SPAWN_PARENTS:
			add.call("R5", "生成器 %s path_spawn_parent 非合法形态：%s" % [sp.full, raw])


func _check_r6(spawners: Array, model: Dictionary, add: Callable) -> void:
	for sp in spawners:
		var waves: String = sp.props.get("spawn_waves", "")
		if waves.is_empty() or waves == "[]":
			add.call("R6", "生成器 %s 无 spawn_waves" % sp.full)
			continue
		for sub_id in _all_subrefs(waves):
			if not model.subs.has(sub_id):
				add.call("R6", "生成器 %s 波次引用缺失 SubResource %s" % [sp.full, sub_id])
				continue
			var sub: Dictionary = model.subs[sub_id]
			var m := _rx_extref.search(sub.props.get("enemy_scene", ""))
			var scene: String = model.exts.get(m.get_string(1), "") if m else ""
			if not scene.ends_with(".tscn") or not FileAccess.file_exists(scene):
				add.call("R6", "SubResource %s 的 enemy_scene 非现存 .tscn：%s" % [sub_id, scene])


func _check_r7(model: Dictionary, add: Callable) -> void:
	for n in model.nodes:
		if n.type != "StaticBody2D" or not n.full.begins_with("Level/Collisions/"):
			continue
		if not n.props.has("collision_layer"):
			add.call("R7", "%s 缺 collision_layer" % n.full)
			continue
		var layer: int = int(n.props.collision_layer)
		if (layer & HEIGHT_ALL) != HEIGHT_ALL or (layer & OLD_GUARD_BITS) != 0:
			add.call("R7", "%s collision_layer=%d 未⊇高度层或带旧屏限位" % [n.full, layer])


func _check_r8(model: Dictionary, add: Callable, is_shell: bool) -> void:
	# 壳形态豁免（S2-M1-B1 裁决，最小诚实规则）：章节终点=段判清+无后继时
	# ChapterShell.chapter_finished 信号构造自带（T5/B7 消费口），既无
	# StageExit 义务，BaseStage 的 ends_after_last_room 导出也不存在于壳——
	# 单地点形态维持"二选一"红线不变。
	if is_shell:
		return
	if not _kind_nodes(model, EXIT_GD).is_empty():
		return
	for n in model.nodes:
		if n.props.get("ends_after_last_room", "") == "true":
			return
	add.call("R8", "无 StageExit 子树且无 ends_after_last_room=true")


func _check_r9(rooms: Array, detectors: Array, add: Callable) -> void:
	var owners := {}  # 解析后的 spawner 全路径 -> {room.full: true}
	for det in detectors:
		var owner := ""
		for room in rooms:
			if det.full.begins_with(room.full + "/"):
				owner = room.full
				break
		if owner.is_empty():
			continue
		for p in _nodepaths_of(det.props.get("paths_enemy_spawners", "")):
			var key := _resolve(det.full, p)
			if not owners.has(key):
				owners[key] = {}
			owners[key][owner] = true
	for key in owners:
		if owners[key].size() >= 2:
			add.call("R9", "spawner %s 被 %d 个房的检测器共引" % [key, owners[key].size()])


func _check_r10(model: Dictionary, add: Callable) -> void:
	for n in model.nodes:
		if n.type != "CanvasLayer" or n.name != "Background":
			continue
		if not n.props.has("layer"):
			continue  # 未显式写=归脚本/骨架 runtime 定档（debug 背景 -10），文本层不猜
		var layer: int = int(n.props.layer)
		if layer >= 0:
			add.call("R10", "Background CanvasLayer.layer=%d ≥0 会盖掉世界内容，须负档" % layer)


#--- 值解析小件 ------------------------------------------------------------------------------------

func _nodepath_of(value: String) -> String:
	var m := _rx_nodepath.search(value)
	return m.get_string(1) if m else ""


func _nodepaths_of(value: String) -> Array:
	var out: Array = []
	for m in _rx_nodepath.search_all(value):
		if not String(m.get_string(1)).is_empty():
			out.append(m.get_string(1))
	return out


func _all_subrefs(value: String) -> Array:
	var out: Array = []
	for m in _rx_subref.search_all(value):
		out.append(m.get_string(1))
	return out


## 从节点全路径出发解析相对 NodePath（".." 弹栈、"." 原地）
func _resolve(from_full: String, rel: String) -> String:
	var segs: Array = from_full.split("/")
	for s in rel.split("/"):
		if s == "..":
			if not segs.is_empty():
				segs.pop_back()
		elif s == "." or s.is_empty():
			continue
		else:
			segs.append(s)
	return "/".join(segs)
