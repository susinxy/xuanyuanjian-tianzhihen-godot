extends SceneTree

## 法术创建流回归测试（2026-09-15 审计补洞：法术线此前无任何创建流自动检查）
## 验证"模板单权威"管线：纯复制+改名+token 替换后，产物结构必须完整正确。
## 运行：godot --headless --path . -s tools/spell_creation_test/test_spell_creation.gd

const TMP_NAME := "tmp_spell_check"
const TMP_PASCAL := "TmpSpellCheck"
const DIR := "res://spells/tmp_spell_check"

var _pass := 0
var _fail := 0


func _initialize():
	var creator = load(
			"res://addons/quiver.beat_em_up/custom_inspectors/create_new_spell/spell_creator.gd"
	).new()
	var deleter = load(
			"res://addons/quiver.beat_em_up/custom_inspectors/create_new_spell/spell_deleter.gd"
	).new()
	
	deleter.delete_spell(TMP_NAME)  # 清理历史残留，保证幂等
	_check(creator.create_spell(TMP_NAME, TMP_PASCAL, "临时检查法术",
			{"cooldown": 1.5, "mana_cost": 20.0, "release_y": 0.5,
			"disallowed_states": "Die, Knockout, Hurt"},
			{"attack_damage": 33.0, "knock_strength": 300.0, "hurt_type": 0,
			"launch_angle": 45.0}), "创建返回成功（特征出生值）")
	
	# ── 文件齐全（模板物化后全部复制而来） ──
	var required := [
		"tmp_spell_check.gd", "tmp_spell_check_skin.gd",
		"tmp_spell_check.tscn", "tmp_spell_check_skin.tscn",
		"resources/tmp_spell_check_definition.tres",
		"resources/anim_library_tmp_spell_check.tres",
		"resources/spriteframes_tmp_spell_check.tres",
		"resources/attacks/tmp_spell_check_attack_data.tres",
		"resources/animations/animation_tree_root.tres",
		"resources/animations/RESET.tres",
		"resources/animations/active_right.tres",
		"resources/animations/active_left.tres",
		"resources/animations/active_up.tres",
		"resources/animations/active_down.tres",
	]
	for rel in required:
		_check(FileAccess.file_exists(DIR.path_join(rel)), "产物存在 %s" % rel)
	
	# ── token 零残留 ──
	var token_free := true
	var token_hit := ""
	for rel in required:
		if not rel.ends_with(".png"):
			var text := FileAccess.get_file_as_string(DIR.path_join(rel))
			for tok in ["__NAME__", "__CLASS__", "__DISPLAY_NAME__"]:
				if tok in text:
					token_free = false
					token_hit = "%s 含 %s" % [rel, tok]
	_check(token_free, "全部文本无占位符残留（%s）" % token_hit)
	
	# ── 出生数值合成生效（2026-09-18 面板=唯一真相批，文本+装载双关卡）──
	var syn_def_txt := FileAccess.get_file_as_string(DIR.path_join("resources/tmp_spell_check_definition.tres"))
	_check(syn_def_txt.contains("cooldown = 1.5") and syn_def_txt.contains("mana_cost = 20"),
			"definition 特征值落盘（冷却/法力）")
	_check(syn_def_txt.contains("max_lifetime = 5") and syn_def_txt.contains("fade_in_time = 0.3")
			and syn_def_txt.contains("caster_cast_time = 0.5"),
			"definition 未传字段回落默认（时限/淡入/引导）")
	_check(syn_def_txt.contains("release_ratio = Vector2(1, 0.5)"),
			"出手点 y 覆盖生效、x 保默认")
	_check(syn_def_txt.contains('Array[StringName]([&"Die", &"Knockout", &"Hurt"])'),
			"禁止状态逗号串→Array[StringName] 序列化")
	_check(syn_def_txt.contains("spell_scene = ExtResource"), "spell_scene 回环引用在位")
	var syn_atk_txt := FileAccess.get_file_as_string(DIR.path_join("resources/attacks/tmp_spell_check_attack_data.tres"))
	_check(syn_atk_txt.contains("attack_damage = 33") and syn_atk_txt.contains("knock_strength = 300")
			and syn_atk_txt.contains("hurt_type = 0") and syn_atk_txt.contains("launch_angle = 45"),
			"attack 四字段特征值全落盘")
	# 解析器验收：剥掉 spell_scene 两行做剥壳副本装载——headless -s 无导入产物，
	# 经场景→皮肤→贴图链的原文件装载必报 non-existent（wp2 两阶段同因的环境约束），
	# [resource] 段全部属性（含 Array[StringName] 序列化形态）由剥壳副本真解析。
	var probe_path := DIR.path_join("resources/_syn_probe.tres")
	var probe_text := syn_def_txt.replace(
			'[ext_resource type="PackedScene" path="res://spells/tmp_spell_check/tmp_spell_check.tscn" id="2_scene"]\n', "")
	probe_text = probe_text.replace('spell_scene = ExtResource("2_scene")\n', "")
	var pf := FileAccess.open(probe_path, FileAccess.WRITE)
	pf.store_string(probe_text)
	pf.close()
	var syn_def := load(probe_path)
	_check(syn_def != null and syn_def.cooldown == 1.5 and syn_def.mana_cost == 20.0
			and str(syn_def.spell_id) == "tmp_spell_check"
			and syn_def.disallowed_states.size() == 3 and syn_def.allowed_states.is_empty()
			and syn_def.max_lifetime == 5.0 and syn_def.fade_in_time == 0.3
			and syn_def.release_ratio == Vector2(1, 0.5),
			"definition 剥壳装载成功且全字段一致（解析器验收）")
	var syn_atk := load(DIR.path_join("resources/attacks/tmp_spell_check_attack_data.tres"))
	_check(syn_atk != null and syn_atk.knock_strength == 300.0 and syn_atk.launch_angle == 45
			and syn_atk.attack_damage == 33.0,
			"attack 装载成功且字段一致（launch_vector 由角度推导=%s）" % str(syn_atk.launch_vector if syn_atk != null else "?"))
	
	# ── 四向树与库（模板=唯一作者的内容断言） ──
	var tree := FileAccess.get_file_as_string(DIR + "/resources/animations/animation_tree_root.tres")
	_check("AnimationNodeBlendSpace2D" in tree, "动画树为四点混合空间")
	_check(tree.count("TmpSpellCheck/active_") == 4, "四输入节点全部正确命名空间替换")
	var lib := FileAccess.get_file_as_string(DIR + "/resources/anim_library_tmp_spell_check.tres")
	for side in ["right", "left", "up", "down"]:
		_check("active_%s" % side in lib, "动画库含 active_%s 条目" % side)
	
	# ── 镜像元数据纪律（2026-09-16 用户裁决改版）：圆弹体四向镜像链合法，
	# 守卫从"up/down 禁标签"改为"标签指向必须成对存在"（悬空标签=真危险形态）。
	var mirror_ok := true
	var anim_dir := DirAccess.open(DIR + "/resources/animations")
	for side in ["right", "left", "up", "down"]:
		var txt := FileAccess.get_file_as_string(
				DIR + "/resources/animations/active_%s.tres" % side)
		var key_pos := txt.find("mirrored_name = \"")
		if key_pos < 0:
			continue
		var start := key_pos + 17
		var end := txt.find("\"", start)
		var target := txt.substr(start, end - start) if end > start else ""
		if target.is_empty() or not anim_dir.file_exists(target):
			mirror_ok = false
	_check(mirror_ok, "镜像标签指向的目标动画文件均存在（无悬空覆盖链）")
	var right := FileAccess.get_file_as_string(DIR + "/resources/animations/active_right.tres")
	_check("active_left.tres" in right, "right↔left 合法镜像对保留")
	
	# ── 弹体帧组完整性（模板晋升后契约：sprites/ 平铺帧 + spriteframes 引用零断链） ──
	var spr_dir := DirAccess.open(DIR + "/resources/sprites")
	var frame_n := 0
	if spr_dir != null:
		for fn in spr_dir.get_files():
			if str(fn).ends_with(".png"):
				frame_n += 1
	_check(frame_n > 0, "产物 sprites/ 帧目录非空（%d 帧）" % frame_n)
	var sf := FileAccess.get_file_as_string(DIR + "/resources/spriteframes_tmp_spell_check.tres")
	var broken := 0
	var idx := 0
	while true:
		var hit := sf.find("res://spells/tmp_spell_check/resources/sprites/", idx)
		if hit < 0:
			break
		var tail := sf.substr(hit)
		var path := tail.left(tail.find("\""))
		if not FileAccess.file_exists(path):
			broken += 1
		idx = hit + 1
	_check(broken == 0, "spriteframes 引用的弹体帧全部存在（断链 %d）" % broken)
	
	# ── 循环法术动画无结束信标（2026-09-16 定罪：信标只属一次性动画；
	#    循环方法轨道=每圈误触发一次的死线，工具已循环感知强制） ──
	var beacon_free := true
	for side in ["right", "left", "up", "down"]:
		var atxt := FileAccess.get_file_as_string(
				DIR + "/resources/animations/active_%s.tres" % side)
		if '"type": "method"' in atxt:
			beacon_free = false
	_check(beacon_free, "循环 active 动画均无结束信标轨道")
	
	# ── 皮肤场景路径替换 ──
	var skin_tscn := FileAccess.get_file_as_string(DIR + "/tmp_spell_check_skin.tscn")
	_check("res://spells/tmp_spell_check/resources" in skin_tscn and "__NAME__" not in skin_tscn,
			"皮肤场景路径指向产物目录")
	
	# ── 资源可加载（文本 .tres 直读，验证序列化合法） ──
	var loaded = load(DIR + "/resources/animations/animation_tree_root.tres")
	_check(loaded != null, "产物动画树可加载")
	
	# ── 清理 ──
	_check(deleter.delete_spell(TMP_NAME), "删除产物成功")
	_check(not DirAccess.dir_exists_absolute(DIR), "产物目录已移除")
	
	# ── 库存守卫：全仓"不该有镜像覆盖标签"的文件确实干净（编辑器旧内存回写防复发） ──
	var dirty := _scan_forced_mirror_tags()
	_check(dirty.is_empty(), "无文件被重新写回错误镜像标签（脏=%s）" % dirty)
	
	print("════════ spell-creation: %d PASS / %d FAIL ════════" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("  %s: %s" % ["PASS" if ok else "FAIL", label])


func _scan_forced_mirror_tags() -> Array[String]:
	var bad: Array[String] = []
	for root in ["res://characters", "res://spells"]:
		var stack: Array = [root]
		while not stack.is_empty():
			var dir_path: String = stack.pop_back()
			var d := DirAccess.open(dir_path)
			if d == null:
				continue
			d.list_dir_begin()
			var f := d.get_next()
			while not f.is_empty():
				var full := dir_path.path_join(f)
				if d.current_is_dir():
					stack.append(full)
				elif f in ["spell.tres"]:
			# 2026-09-16 裁决：active_up/down 从黑名单移除——圆弹体四向共用一张图，
			# 右→其余三向的镜像+允许覆盖是法术线合法工作流；守卫只盯真正的遗产雷
			# （已退役拼写 spell.tres 复活）。警告：某法术若为上/下方向画了定制图，
			# 须先在该动画上取消"允许覆盖"勾选，否则镜像链会静默碾过定制。
					if "mirrored_name" in FileAccess.get_file_as_string(full):
						bad.append(full)
				f = d.get_next()
	return bad
