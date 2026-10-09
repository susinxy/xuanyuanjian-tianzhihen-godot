extends SceneTree

## 关卡装配校验器（S1-T4，矩阵第 21 项）：对地点/章节契约做 R1-R14 系列
## 独立规则（R8 随 5b 退役）的机械执法。**只读 .tscn 文本**（FileAccess+逐行
## 解析），不走 ResourceLoader——避免加载副作用与对未落地依赖的真实解析。
## 运行：
##   矩阵：  godot --headless --path . -s tools/stage_validator/validator.gd
##           （默认扫 scenes/stages/**/*.tscn；目录未建=T5 前真空绿，非错误）
##   自检：  ... -s tools/stage_validator/validator.gd -- --fixtures
##           （跑 tools/stage_validator/fixtures/，每个 fixture 首行
##            `[gd_scene ... expect="R#"]` 声明**恰**触发的规则；
##            stage_ok 声明 none 必须全绿）
##           NOTICE 通道（R3 黄/R13④ 黄）：只打印不进 violations、不参与 expect
##           比对——黄判据的合法性由"绿 fixture 仍全绿"自证
## 规则表（账本裁决绑定版；S2-M1-B1 双轨扩，spec D10）：
##   R1 根必须 instance=ExtResource(chapter_shell.tscn)（5b 单轨：base_stage 臂退役）；
##      豁免臂：③段形态（根 script=stage_content.gd）、④壳模板本体（根
##      script=chapter_shell.gd 且**仅模板自身路径**）；⑤另存分壳（同根脚本
##      形于别处）=合法根形态但归壳管辖，R2 照查 chapter_id（2026-09-28 收紧，
##      修"漏填 id 假绿"豁免洞；S2-M1-B2 T4 判例的域限定）
##   R2 根节点存在形态主键 = &"..." 非空（S1 终审 M-2：限定根属性块，
##      挂在子孙节点上的主键属污染残留，不算满足）四臂分派：
##      base 形态查 stage_id；shell 形态查 chapter_id（R2' 并表同码，hint 区分）；
##      ③段形态查 segment_id；④壳模板本体恒过（模板不携带 per-instance 主键，
##      chapter_id/segment_scenes 由子实例回填）
##   R3 降黄（盒轨批，法源 specs/2026-10-07-playfield-box-design §三）：房=可选的
##      镜头/锁战家具，**纯特写房（子树无检测器）合法**——只打 NOTICE 提醒"此房无
##      解锁源"，不列违例数（开战与战斗不依赖房；解锁机制缺口法典待立项）
##   R4 接线化（盒轨批，法源同上）：旧文"检测器 room 路径与 spawner 列表**都**非空"
##      是配方形状核对，误伤合法遭遇带；新罚真危害两端——①**哑检测器红**：
##      path_fight_room 空**且** paths_enemy_spawners 空（player_detected 无人应答）；
##      ②**孤儿生成器红**：段内每个生成器必须被 ≥1 个检测器 paths_enemy_spawners
##      引用（_resolve 反查表），否则波永不刷+壳实源集缺员=推进死锁
##   R5 生成器 path_spawn_parent ∈ 两种合法形态（白名单）：base 轨
##      （5b 单轨）shell 轨
##      ../../../../Players（段挂壳 Segments 下恒 4 级，spec C6）；默认值/缺失红
##   R6 生成器 spawn_waves 在位且每个 SubResource 有 enemy_scene=ExtResource
##      指向盘上真实存在的 .tscn
##   R7 Level/Collisions 下每个 StaticBody2D：collision_layer 必须存在、
##      含全部高度层（bit15-24，16760832）且无旧屏限位（值 4=layer3 屏限、
##      值 8=layer4 顶限，合计 12）；bit2 障碍位允许出现（不检查）
##   （R8 随 base 轨退役（5b）：章终点=段判清+chapter_finished 构造自带）
##   R9 判据去房化（盒轨批，法源同上）：同一 spawner 被 ≥2 个**检测器**共引=争抢
##      波次所有权（违例）；无房遭遇带的检测器同样入网（旧文以"房"为计数单位漏防）
##   （WIP 豁免：目录内放 .wip 空文件=该目录树整体跳过并打 NOTICE）
##   R10 背景 CanvasLayer 显式写的 layer 必须 <0（≥0 连角色/阴影合成层整个盖掉；
##       负档是软边阴影自动档 z=Level-1 正确落位的承重墙，2026-09-20 光照收编）
##   R11 触发件（script 路径尾 interact_trigger.gd 的节点）必有 CollisionShape2D
##       后代（零宽/缺形=隐身不可交互，法典第十条；经 instance= 引入的触发件
##       自带形状在**其本体文件**里，本文件无 script 属性行不误伤）
##   R12 章节轨反应件装配防呆（B4 门五，spec §3）：管辖=章节轨三形态
##   R14 壳形态（实例/另存）主角申报三选一：根 playable_override=ExtResource
##      行 / 根 playable_path=NodePath 非空 / Players 下有实例节点（5a 壳清空批，
##      空场=运行时必红，静态先拦；模板本体不在扫描域天然豁免）
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
##   R13 盒轨（新立，盒轨批，法源同上）：管辖=**含 playfield_box.gd 的段文件**
##      （旧形段无盒不查=兼容通道，ref/demo 不迁移判例在册）。四查——①**盒唯一**
##      （>1 红：双盒=模型破产，一段一界）；②**坐标系契约**（盒须直挂段根；盒节点写 anchor_*/
##      scale/position 行=红：ReferenceRect 是 Control，矩形全靠默认 anchors+
##      offset 四值，雷区 a 同源）；③**入口在盒**（根 entry_points 各值须落在盒
##      矩形闭区间（容差 0.5），红：落位必穿墙带）；④**房越盒黄**（任一 FightRoom 矩形超出
##      盒界=NOTICE：锁房全景时界外可见不可走，雷 l，多为摆错但不拦）。
##      零面积盒（offset 未摆正）=红并早退
##   空根守卫（T4 评审意见第 12 条，规则码记 R1 早退——勿与门五 R12 混读）：
##       零节点 .tscn（垃圾/截断）记 R1 早退，
##       不得流进 R2/R11 臂（root={} → .props null 崩）

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
const PLAYBOX_GD := "playfield_box.gd"   # R13 盒轨（常量区）
# R12（门五）反应件脚本与账本户桶名：户名字符串镜像 GameSave 的
# NS_CHESTS/NS_SPELLS 值——文本级扫描不加载 autoload，桶名仅用于分户查重
const CHEST_GD := "interact_chest.gd"
const BOOK_GD := "interact_spell_book.gd"
const NS_CHESTS_BUCKET := "chests"
const NS_SPELLS_BUCKET := "spells_known"
# R5 白名单双形（spec D10/C6）：base 轨房挂 FightRooms 下恒 3 级到根；
# shell 轨段挂壳 Segments 下、房直接挂段根，恒 4 级到壳根 Players
const LEGAL_SPAWN_PARENTS := [
	'NodePath("../../../../Players")',
]

var _rx_attr := _rx('(\\w+)="([^"]*)"')
var _rx_prop := _rx("^([A-Za-z0-9_/]+) = (.+)$")
var _rx_extref := _rx('ExtResource\\("([^"]*)"\\)')
var _rx_subref := _rx('SubResource\\("([^"]*)"\\)')
var _rx_nodepath := _rx('NodePath\\("([^"]*)"\\)')
var _rx_vec2 := _rx('Vector2\\(\\s*(-?\\d+(?:\\.\\d+)?),\\s*(-?\\d+(?:\\.\\d+)?)\\)')


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
	# 判形加臂（S2-M1-B2 T4；2026-09-28 手册批收紧豁免域）：③段形态=根
	# script stage_content.gd；④壳模板本体=根 script chapter_shell.gd 且**仅
	# 模板文件自身路径**（模板恒常无 per-instance 主键，豁免合理）；⑤"场景
	# 另存为"产出的散布分壳（同根脚本形、别处路径）=归壳形态管辖——
	# chapter_id 漏填必须被 R2 抓住，否则手册验收对另存形=假绿（豁免洞修复）。
	var root_script := _script_path_of(root, model) if not root.is_empty() else ""
	var is_segment := root_script.ends_with("stage_content.gd")
	var is_template := root_script.ends_with("chapter_shell.gd") and path == SHELL_PATH
	var is_saveas_shell := root_script.ends_with("chapter_shell.gd") and path != SHELL_PATH
	is_shell = is_shell or is_saveas_shell
	_check_r1(model, root, add, is_segment, is_template, is_shell)
	_check_r2(root, add, is_shell, is_segment, is_template)
	var rooms := _kind_nodes(model, ROOM_GD)
	var detectors := _kind_nodes(model, DET_GD)
	var spawners := _kind_nodes(model, SPAWN_GD)
	_check_r3(rooms, detectors)
	_check_r4(detectors, spawners, add)
	_check_r5(spawners, add)
	_check_r6(spawners, model, add)
	_check_r7(model, add)
	# R8 随 base 轨退役（5b）：段清推进义务=ChapterShell 构造自带，无静态面
	_check_r9(detectors, add)
	_check_r10(model, add)
	_check_r11(model, add)
	# R12 管辖=章节轨三形态（壳实例/③段/④壳模板本体）；base 单地点不查（头注）
	if is_shell or is_segment or is_template:
		_check_r12(path, text, add, is_shell)
	# R14 壳主角申报（5a 壳清空批）：仅壳形文件（实例/另存），模板本体不在
	# scenes/stages 扫描域天然豁免
	if is_shell:
		_check_r14(model, root, add)
	# R13 盒轨（盒轨批）：管辖=段形态；无盒旧形段在函数内首行早退=兼容通道
	if is_segment:
		_check_r13(model, root, add)
	return out


func _parse(text: String) -> Dictionary:
	var model := {exts = {}, subs = {}, nodes = []}
	var cur = null
	var lines := text.split("\n")
	var i := 0
	while i < lines.size():
		var line := String(lines[i]).strip_edges()
		i += 1
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
				var value := pm.get_string(2)
				# 编辑器存盘的多行字典/数组形制（entry_points = { 换行 … }）折叠回
				# 单值：不折叠则"读属性文本"的判据（R13③ 入口在盒）对真实存盘形
				# 静默失效=假绿（判例 fixture box_ok_seg 钉死此形制）
				if value.ends_with("{") or value.ends_with("["):
					while i < lines.size():
						var cont := String(lines[i]).strip_edges()
						i += 1
						value += " " + cont
						if cont.ends_with("}") or cont.ends_with("]"):
							break
				cur.props[pm.get_string(1)] = value
	return model


func _attr(line: String, key: String) -> String:
	for m in _rx_attr.search_all(line):
		if m.get_string(1) == key:
			return m.get_string(2)
	return ""


## R14：壳=空场地基，但成品章节必须有主角来源三选其一——
## ①根 playable_override=ExtResource(...)；②根 playable_path=NodePath 非空；
## ③Players 容器下存在场景实例节点（手动摆角色形）。
## 全无=运行时必 chapter_error（空场红）——静态先拦，报错即教学。
func _check_r14(model: Dictionary, root: Dictionary, add: Callable) -> void:
	if str(root.props.get("playable_override", "")).begins_with("ExtResource"):
		return
	var pp := str(root.props.get("playable_path", ""))
	if pp != "" and pp != 'NodePath("")':
		return
	for n in model.nodes:
		if n.get("parent", "") == "Players" and str(n.get("inst", "")) != "":
			return
	add.call("R14", "壳无主角申报：把玩家档角色 .tscn 拖进壳根 Inspector 的 " \
			+ "playable_override 槽（推荐正门），或将角色实例摆进 Players 容器，" \
			+ "或多角色时设 playable_path 显式指路（运行时三来源解析同序）")


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
		is_segment: bool, is_template: bool, is_shell: bool) -> void:
	# ③段形态/④壳模板本体/⑤另存分壳（含于 is_shell）=合法根形态，跳过
	if is_segment or is_template or is_shell:
		return
	if root.is_empty() or not (root.inst in model.exts) \
			or model.exts[root.inst] != SHELL_PATH:
		add.call("R1", "根须为 chapter_shell.tscn 实例或合法脚本形态（base_stage 单地点轨已随 5b 下线）")


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
		add.call("R2", "壳形态根缺 chapter_id = &\"...\" 非空行")
		return


## R3 降黄（盒轨批：纯特写房=合法，解锁机制缺口法典待立项——只提醒不执法）
func _check_r3(rooms: Array, detectors: Array) -> void:
	for room in rooms:
		if _under(room, detectors).is_empty():
			print("NOTICE: R3黄 房 %s 无检测器触发（空特写房合法，注意无解锁源）" % room.full)


func _under(room: Dictionary, nodes: Array) -> Array:
	return nodes.filter(func(n): return n.full.begins_with(room.full + "/"))


## R4 接线化（旧"room 与 spawner 都必填"是配方形状核对，误伤合法遭遇带；
## 新罚真危害两端：哑检测器=player_detected 无人应答；孤儿生成器=波永不刷
## +壳实源集缺员=推进死锁）
func _check_r4(detectors: Array, spawners: Array, add: Callable) -> void:
	var covered := {}
	for det in detectors:
		var room_p := _nodepath_of(det.props.get("path_fight_room", ""))
		var sp_list := _nodepaths_of(det.props.get("paths_enemy_spawners", ""))
		if room_p.is_empty() and sp_list.is_empty():
			add.call("R4", "检测器 %s 既无房亦无波次引用（哑件；处方：挂 path_fight_room 或至少引一个生成器）" % det.full)
		for p in sp_list:
			covered[_resolve(det.full, p)] = true
	for sp in spawners:
		if not covered.has(sp.full):
			add.call("R4", "生成器 %s 未被任何检测器引用（孤儿：波永不刷+段判清实源缺员=死锁；处方：列入某检测器 paths_enemy_spawners）" % sp.full)


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
	# 5b 单轨扩面：原"仅 Level/Collisions/ 前缀"为 base 路径法理，段形场地体
	# 直挂段根——全树 StaticBody2D 一律查配方（装配文件内无豁免体）
	for n in model.nodes:
		if n.type != "StaticBody2D":
			continue
		if not n.props.has("collision_layer"):
			add.call("R7", "%s 缺 collision_layer" % n.full)
			continue
		var layer: int = int(n.props.collision_layer)
		if (layer & HEIGHT_ALL) != HEIGHT_ALL or (layer & OLD_GUARD_BITS) != 0:
			add.call("R7", "%s collision_layer=%d 未⊇高度层或带旧屏限位" % [n.full, layer])



## R9 去房化：同一生成器被 ≥2 检测器共引=争抢波次所有权（遭遇带无房也入网）
func _check_r9(detectors: Array, add: Callable) -> void:
	var owners := {}  # 解析后的 spawner 全路径 -> {det.full: true}
	for det in detectors:
		for p in _nodepaths_of(det.props.get("paths_enemy_spawners", "")):
			var key := _resolve(det.full, p)
			if not owners.has(key):
				owners[key] = {}
			owners[key][det.full] = true
	for key in owners:
		if owners[key].size() >= 2:
			add.call("R9", "spawner %s 被 %d 个检测器共引" % [key, owners[key].size()])


## R13 盒轨（spec §三）：管辖=含 playfield_box.gd 的段文件；旧形段（无盒）
## 不查=兼容通道（ref/demo 不迁移判例在册）。①唯一②坐标系契约③入口在盒④房越盒黄。
func _check_r13(model: Dictionary, root: Dictionary, add: Callable) -> void:
	var boxes := _kind_nodes(model, PLAYBOX_GD)
	if boxes.is_empty():
		return
	if boxes.size() > 1:
		add.call("R13", "段含 %d 个盒（双盒=模型破产；一段一界）" % boxes.size())
		return
	var box: Dictionary = boxes[0]
	if box.get("parent", ".") != ".":
		add.call("R13", "盒 %s 必须直挂段根（家具坐标系契约）" % box.full)
		return
	for k in box.props:
		if k.begins_with("anchor_") or k == "scale" or k == "position":
			add.call("R13", "盒 %s 写了非默认坐标属性 %s（矩形全靠默认 anchors+offset，雷区 a 同源）" % [box.full, k])
			return
	var l := float(box.props.get("offset_left", "0"))
	var t := float(box.props.get("offset_top", "0"))
	var r := float(box.props.get("offset_right", "0"))
	var b := float(box.props.get("offset_bottom", "0"))
	var rect := Rect2(l, t, r - l, b - t)
	if not rect.has_area():
		add.call("R13", "盒 %s 零面积（offset 未摆正）" % box.full)
		return
	var ep: String = root.props.get("entry_points", "")
	if ep != "":
		for m in _rx_vec2.search_all(ep):
			var pt := Vector2(m.get_string(1).to_float(), m.get_string(2).to_float())
			if not rect.grow(0.5).has_point(pt):
				add.call("R13", "入口 %s 越出盒矩形 %s（落位必穿墙带；处方：改 entry_points 或挪盒）" % [pt, rect])
	for room in _kind_nodes(model, ROOM_GD):
		var rl := float(room.props.get("offset_left", "0"))
		var rt := float(room.props.get("offset_top", "0"))
		var rr := float(room.props.get("offset_right", "0"))
		var rb := float(room.props.get("offset_bottom", "0"))
		if rr > rect.end.x + 0.5 or rl < rect.position.x - 0.5 \
				or rb > rect.end.y + 0.5 or rt < rect.position.y - 0.5:
			print("NOTICE: R13黄 房 %s 矩形越出盒界（锁房全景时越界处可见不可走，雷 l）" % room.full)


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
