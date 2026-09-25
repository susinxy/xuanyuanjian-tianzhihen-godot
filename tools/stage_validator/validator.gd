extends SceneTree

## 关卡装配校验器（S1-T4，矩阵第 21 项）：对地点/章节契约做 R1-R12 十二条
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
##   R1 根必须 instance=ExtResource(base_stage.tscn **或** chapter_shell.tscn)；
##      ③段形态（根 script=stage_content.gd）与④壳模板本体（根 script=
##      chapter_shell.gd）豁免——两形合法场景的根=脚本本体而非实例（S2-M1-B2 T4）
##   R2 根节点存在形态主键 = &"..." 非空（S1 终审 M-2：限定根属性块，
##      挂在子孙节点上的主键属污染残留，不算满足）四臂分派：
##      base 形态查 stage_id；shell 形态查 chapter_id（R2' 并表同码，hint 区分）；
##      ③段形态查 segment_id；④壳模板本体恒过（模板不携带 per-instance 主键，
##      chapter_id/segment_scenes 由子实例回填）
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
##      shell 形态天然豁免（章节终点=ChapterShell.chapter_finished 信号构造自带）；
##      ③段形态与④壳模板本体同豁免（段无 StageExit 义务，章节终点归壳）
##   R9 同一 spawner 路径被 ≥2 个不同房的检测器引用（跨房重引）= 违例
##   （WIP 豁免：目录内放 .wip 空文件=该目录树整体跳过并打 NOTICE）
##   R10 背景 CanvasLayer 显式写的 layer 必须 <0（≥0 连角色/阴影合成层整个盖掉；
##       负档是软边阴影自动档 z=Level-1 正确落位的承重墙，2026-09-20 光照收编）
##   R11 触发件（script 路径尾 interact_trigger.gd 的节点）必有 CollisionShape2D
##       后代（零宽/缺形=隐身不可交互，法典第十条；经 instance= 引入的触发件
##       自带形状在**其本体文件**里，本文件无 script 属性行不误伤）
##   R12 章节轨反应件装配防呆（B4 门五，spec §3）：管辖=章节轨三形态
##       （根实例 chapter_shell / ③段形态 / ④壳模板本体）。InteractChest 的
##       chest_id、InteractSpellBook 的 spell_id（manual_id 若设则为账本键、
##       空=回落 spell_id，与件内运行时回落一致）必须非空——缺行=吃导出默认
##       &""（R5 缺行同罪：多件共写一笔空账/幽灵账）；**同户**（chest 记
##       chests 户、book 记 spells_known 户）键值全章唯一——两件争一笔账=红。
##       跨户撞名**不算撞**（chests 的 ch_a 与 spells_known 的 ch_a 各记各账，
##       夹具 r12_ok_seg_b 钉死此判例：book 键撞段 A 宝箱 id 必须全绿）；
##       grants_flag 不在管辖（可选奖励旗、重复挂旗幂等无害，非争账键）。
##       "同章"=壳文件沿 PackedScene+.tscn 引用闭包递归（segment_scenes 数组
##       与各层 instance 引入、内联 Segments 子段皆覆盖；visited 防环；缺文件
##       不告——加载期自会响亮报）。base 单地点形态不管：无壳 find_shell=null，
##       反应件在其下静默不反应，账本无从争抢。在施章节走 .wip 整树豁免惯例。
##   空根守卫（T4 评审意见第 12 条，规则码记 R1 早退——勿与门五 R12 混读）：
##       零节点 .tscn（垃圾/截断）记 R1 早退，
##       不得流进 R2/R11 臂（root={} → .props null 崩）

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
const TRIG_GD := "interact_trigger.gd"
# R12（门五）反应件脚本与账本户桶名：户名字符串镜像 GameSave 的
# NS_CHESTS/NS_SPELLS 值——文本级扫描不加载 autoload，桶名仅用于分户查重
const CHEST_GD := "interact_chest.gd"
const BOOK_GD := "interact_spell_book.gd"
const NS_CHESTS_BUCKET := "chests"
const NS_SPELLS_BUCKET := "spells_known"
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
	# R12 守卫（T4 评审判例随批补）：零节点文件=垃圾 .tscn，记 R1 早退——
	# root={} 直进 R2/R11 臂会吃 null.props 崩（pre-existing 洞，非 R11 引入）
	if model.nodes.is_empty():
		add.call("R1", "场景零节点（.tscn 损坏/空文件）")
		return out
	var root: Dictionary = model.nodes[0]
	# 双轨判形（D10）：R1 通过的两形态之一=壳形态；R2/R8 按形分派
	var is_shell: bool = not root.is_empty() and (root.inst in model.exts) \
			and model.exts[root.inst] == SHELL_PATH
	# 判形加臂（S2-M1-B2 T4）：③段形态=根 script stage_content.gd；
	# ④壳模板本体=根 script chapter_shell.gd（模板自身，根不是任何实例）
	var root_script := _script_path_of(root, model) if not root.is_empty() else ""
	var is_segment := root_script.ends_with("stage_content.gd")
	var is_template := root_script.ends_with("chapter_shell.gd")
	_check_r1(model, root, add, is_segment, is_template)
	_check_r2(root, add, is_shell, is_segment, is_template)
	var rooms := _kind_nodes(model, ROOM_GD)
	var detectors := _kind_nodes(model, DET_GD)
	var spawners := _kind_nodes(model, SPAWN_GD)
	_check_r3(rooms, detectors, spawners, add)
	_check_r4(detectors, add)
	_check_r5(spawners, add)
	_check_r6(spawners, model, add)
	_check_r7(model, add)
	_check_r8(model, add, is_shell, is_segment, is_template)
	_check_r9(rooms, detectors, add)
	_check_r10(model, add)
	_check_r11(model, add)
	# R12 管辖=章节轨三形态（壳实例/③段/④壳模板本体）；base 单地点不查（头注）
	if is_shell or is_segment or is_template:
		_check_r12(path, text, add, is_shell)
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


func _check_r1(model: Dictionary, root: Dictionary, add: Callable,
		is_segment: bool, is_template: bool) -> void:
	# ③段形态/④壳模板本体的根=脚本本体而非 base/shell 实例，属合法形态，跳过
	if is_segment or is_template:
		return
	if root.is_empty() or not (root.inst in model.exts) \
			or (model.exts[root.inst] != BASE_PATH
					and model.exts[root.inst] != SHELL_PATH):
		add.call("R1", "根未实例化 base_stage.tscn")


func _check_r2(root: Dictionary, add: Callable, is_shell: bool,
		is_segment: bool, is_template: bool) -> void:
	# ④壳模板本体恒过：模板不携带 per-instance 主键（chapter_id/segment_scenes
	# 由子实例回填），四臂分派见头注规则表
	if is_template:
		return
	# ③段形态主键=segment_id（并表同码，hint 区分）
	if is_segment:
		var s: String = root.props.get("segment_id", "")
		if s.begins_with('&"') and s.length() > 3:
			return
		add.call("R2", "段形态根缺 segment_id = &\"...\" 非空行")
		return
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


func _check_r8(model: Dictionary, add: Callable, is_shell: bool,
		is_segment: bool, is_template: bool) -> void:
	# 壳形态豁免（S2-M1-B1 裁决，最小诚实规则）：章节终点=段判清+无后继时
	# ChapterShell.chapter_finished 信号构造自带（T5/B7 消费口），既无
	# StageExit 义务，BaseStage 的 ends_after_last_room 导出也不存在于壳——
	# 单地点形态维持"二选一"红线不变。③段/④壳模板本体同豁免（S2-M1-B2 T4）：
	# 段无 StageExit 义务（章节终点归壳），模板本体同理。
	if is_shell or is_segment or is_template:
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


func _check_r11(model: Dictionary, add: Callable) -> void:
	# R11（法典第十条文本执法）：script=interact_trigger.gd 的节点必有
	# CollisionShape2D 后代——感应盒缺形=隐身不可交互（雷区：发丝线不判交的
	# 交互侧翻版）；实例化引入的触发件（instance= 行）脚本住在本体文件，
	# 本文件解析不到 script 属性=不误伤（形状由其本体场景自证）。
	for trig in _kind_nodes(model, TRIG_GD):
		var has_shape := false
		for n in model.nodes:
			if n.type == "CollisionShape2D" and n.full.begins_with(trig.full + "/"):
				has_shape = true
				break
		if not has_shape:
			add.call("R11", "触发件 %s 无感应形状（零宽/缺形=隐身不可交互）" % trig.full)


#--- R12 章节轨反应件装配防呆（B4 门五）------------------------------------------------------------

## 反应件账本键抽取：返回 {empty=[违例文案...], keys={户: {键: [出处...]}}}。
## 主文件与章节闭包段文件共用；tag=出处文件名前缀（闭包文件报"谁家的哪件"）。
func _r12_scan(text: String, tag: String) -> Dictionary:
	var model := _parse(text)
	var empty_list: Array = []
	# 判例（4.7 探针）：`{NS_X = v}` 字面量的键=标识符**字面名**非变量值，
	# 必须用冒号形 `{NS_X: v}` 才按常量值（户名字符串）建桶
	var keys := {NS_CHESTS_BUCKET: {}, NS_SPELLS_BUCKET: {}}
	for n in model.nodes:
		var script := _script_path_of(n, model)
		if script.ends_with(CHEST_GD):
			var cid := _r12_id(n.props.get("chest_id", ""))
			if cid.is_empty():
				empty_list.append("%s宝箱反应件 %s 缺/空 chest_id（缺行=吃导出默认 &\"\""
						% [tag, n.full] + "=多件共写一笔空账）")
			else:
				_r12_put(keys[NS_CHESTS_BUCKET], cid, tag + String(n.full))
		elif script.ends_with(BOOK_GD):
			var sid := _r12_id(n.props.get("spell_id", ""))
			if sid.is_empty():
				empty_list.append("%s秘籍反应件 %s 缺/空 spell_id（键空=账本记幽灵法术，"
						% [tag, n.full] + "registry 必缺件）")
			else:
				# manual_id 设了才算键、空=回落 spell_id（件内运行时同款回落）；
				# manual_id=&"" 不是违例（语义=未设），故此处永不因 manual_id 报空
				var mid := _r12_id(n.props.get("manual_id", ""))
				var eff_key: String = mid if not mid.is_empty() else sid
				_r12_put(keys[NS_SPELLS_BUCKET], eff_key, tag + String(n.full))
	return {empty = empty_list, keys = keys}


func _r12_put(bucket: Dictionary, key: String, where: String) -> void:
	if not bucket.has(key):
		bucket[key] = []
	bucket[key].append(where)


## 提取 &"xxx" StringName 字面量本体；缺行、&""（空）一律回空串
func _r12_id(raw: String) -> String:
	var s := raw.strip_edges()
	if s.begins_with('&"') and s.ends_with('"') and s.length() > 3:
		return s.substr(2, s.length() - 3)
	return ""


## 文件的 PackedScene+.tscn 引用清单（res:// 路径，章节闭包 BFS 的边；
## Script/Texture 等类型不跟）
func _r12_scene_deps(path: String) -> Array:
	var out: Array = []
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw.strip_edges()
		if not line.begins_with("[ext_resource"):
			continue
		if _attr(line, "type") != "PackedScene":
			continue
		var p := _attr(line, "path")
		if p.ends_with(".tscn"):
			out.append(p)
	return out


func _check_r12(path: String, text: String, add: Callable, is_shell: bool) -> void:
	var own: Dictionary = _r12_scan(text, "")
	for e in own["empty"]:
		add.call("R12", String(e))
	var per_ns := {}
	_r12_merge(per_ns, own["keys"])
	# 同章闭包（仅壳文件起算）：沿引用链逐层收段内键——两箱分家两个段
	# 仍算同章争账（夹具 r12_bad_dup_chapter 钉死）；缺文件静默跳过
	# （加载期自会响亮报，不属本律管辖）
	if is_shell:
		var visited := {path: true}
		var queue: Array = _r12_scene_deps(path)
		while not queue.is_empty():
			var p: String = queue.pop_front()
			if visited.has(p) or not FileAccess.file_exists(p):
				continue
			visited[p] = true
			var sub: Dictionary = _r12_scan(FileAccess.get_file_as_string(p),
					"%s/" % p.get_file())
			for e in sub["empty"]:
				add.call("R12", "%s（章节 %s 沿引用链查见）" % [String(e), path.get_file()])
			_r12_merge(per_ns, sub["keys"])
			queue.append_array(_r12_scene_deps(p))
	for ns in per_ns:
		for key in per_ns[ns]:
			var owners: Array = per_ns[ns][key]
			if owners.size() >= 2:
				add.call("R12", "同户 %s 键 %s 被 %d 件争抢（两件争一笔账）：%s"
						% [ns, key, owners.size(), str(owners)])


## 键集按户合并（dst/ns/key 追加 src 的出处清单）
func _r12_merge(dst: Dictionary, src: Dictionary) -> void:
	for ns in src:
		if not dst.has(ns):
			dst[ns] = {}
		for key in src[ns]:
			if not dst[ns].has(key):
				dst[ns][key] = []
			dst[ns][key].append_array(src[ns][key])


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
