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
	_check(creator.create_spell(TMP_NAME, TMP_PASCAL, "临时检查法术"), "创建返回成功")
	
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
		"resources/sprites/placeholder.png",
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
	
	# ── 四向树与库（模板=唯一作者的内容断言） ──
	var tree := FileAccess.get_file_as_string(DIR + "/resources/animations/animation_tree_root.tres")
	_check("AnimationNodeBlendSpace2D" in tree, "动画树为四点混合空间")
	_check(tree.count("TmpSpellCheck/active_") == 4, "四输入节点全部正确命名空间替换")
	var lib := FileAccess.get_file_as_string(DIR + "/resources/anim_library_tmp_spell_check.tres")
	for side in ["right", "left", "up", "down"]:
		_check("active_%s" % side in lib, "动画库含 active_%s 条目" % side)
	
	# ── 镜像元数据纪律（L1/L2 回归锁）：up/down 必须无标签，right↔left 成对 ──
	var up := FileAccess.get_file_as_string(DIR + "/resources/animations/active_up.tres")
	var down := FileAccess.get_file_as_string(DIR + "/resources/animations/active_down.tres")
	_check("mirrored_name" not in up and "mirrored_name" not in down, "up/down 无镜像覆盖标签")
	var right := FileAccess.get_file_as_string(DIR + "/resources/animations/active_right.tres")
	_check("active_left.tres" in right, "right 指向 left 的合法镜像对保留")
	
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
				elif f in ["spell.tres", "active_up.tres", "active_down.tres"]:
					if "mirrored_name" in FileAccess.get_file_as_string(full):
						bad.append(full)
				f = d.get_next()
	return bad
