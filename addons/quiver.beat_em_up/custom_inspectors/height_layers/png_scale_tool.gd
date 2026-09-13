@tool
extends RefCounted
## PNG 缩放工具核心（纯文件操作，不依赖编辑器运行时，可 headless 测试）
##
## 设计原则：备份柜（backup_dir）= 原画唯一真理；展示柜（source_dir）= 派生物 +
## 用户的"投稿箱"。每次运行逐文件回答"这个源文件是什么"——判定以**内容哈希**为
## 裁判（journal 账本），尺寸仅在无账本的迁移运行中兜底一次。
##
## 判定规则（process_pair，按序命中即止）：
## R0 无备份 或 勾选"重新采集原底"(reclaim)
##        → 以当前源内容为原底（源必须可解码，否则跳过且不碰备份）→ 印 → 记账
##        动作名：无备份="captured"（新文件收底）/ reclaim="recaptured"（强制换底）
## R1 源字节 == 备份字节            → 原画未动（含"恢复原图"后）→ 从备份印 "printed"
## R2 源字节 == 账本记录的本文件上次输出字节 → 我的印品未被动过 → 从备份重印 "reprinted"
## R3 其余（内容被改过/对不上）：
##    - 正常模式：视为用户投稿的新原画 → 换底 + 印 + 记账 "recaptured"
##    - 迁移模式（首次升级、账本尚不存在，一次性兜底）：
##        源尺寸 == 备份尺寸（同尺寸换画）→ 换底 "recaptured"
##        源尺寸 != 备份尺寸              → 判为无账本时代的旧印品 → 重印 "reprinted"
## 护栏：任何"换底"动作前源图必须可解码；损坏文件只报错跳过，绝不污染备份。
## 收尾：账本压实（仅保留本次源目录所见文件，删除的美术不留死条目）；
##       孤儿统计（备份有、源无 = 被删除美术的原画保险，恢复原图会复活它们，故须报告）。
## "恢复原图"完成后清空账本（源==备份，R1 自然接管）。
##
## 掩码三型（*.mask.png / *.body.mask.png / *.attack.mask.png）自动识别，直接
## resize 仅取 alpha；普通精灵图 fix_alpha_edges → Lanczos（4.7 无 depremultiply，
## premultiply 路线不可逆，弃用）。
##
## 蒙版与缩放的关系（mask 母版体系）：蒙版的"原画"永远是母版目录里那份（由蒙版
## 编辑器在母版画布上绘制写入），源目录的蒙版只是印品。因此蒙版**绝不走 R0/R3 的
## 收底/换底**——有母版则从母版重印，无母版判为历史孤儿并告警跳过（不污染母版、
## 不二次缩小）。*.no.png 跳过标记是纯布尔旗标、只需存在于源目录，缩放完全不碰。
## 完成后由调用方（widget/runner）负责"重跑两类轮廓转换"提醒与资源扫描。

const JOURNAL_FILE := "_journal.log"


## 单文件全流程：判定 → （必要时换底）→ 从备份印 → 记账。
## dry=true 仅判定不写盘（确认弹窗预览计数用）。journal 字典会被实时更新。
## 返回 { "action": captured|printed|reprinted|recaptured|""(出错), "error": String,
##        "is_mask": bool }
static func process_pair(
	src_abs: String,
	bak_abs: String,
	rel: String,
	factor: float,
	reclaim: bool,
	migration: bool,
	dry: bool,
	bak_global: String,
	journal: Dictionary
) -> Dictionary:
	var out := {"action": "", "error": "", "is_mask": rel.ends_with(".mask.png")}
	if factor <= 0.0:
		out.error = "缩放系数必须大于 0"
		return out
	if not FileAccess.file_exists(src_abs):
		out.error = "源文件不存在: %s" % rel
		return out

	var src_md5 := FileAccess.get_md5(src_abs)
	var has_bak := FileAccess.file_exists(bak_abs)
	var truth := bak_abs  # 打印母本（备份/新收的底片）

	if out.is_mask:
		# 蒙版专用通道：原画永远是母版那份（编辑器写入），源目录蒙版只是印品。
		# 永不从源收底/换底；无母版 = 历史孤儿 → 告警跳过（绝不误收底导致二次缩小）。
		if not has_bak:
			out.error = "孤儿蒙版（母版无对应原画，请在蒙版编辑器重新保存入册）: %s" % rel
			return out
		out.action = "reprinted"
		truth = bak_abs
	elif not has_bak or reclaim:
		# R0：新文件收底 / 逃生门强制换底 —— 源必须可解码
		if Image.load_from_file(src_abs) == null:
			out.error = "源不可解码，跳过（备份未受污染）: %s" % rel
			return out
		if not dry:
			if not _ensure_parent_dir(bak_abs):
				out.error = "无法创建备份目录: %s" % bak_abs.get_base_dir()
				return out
			var cp := DirAccess.copy_absolute(src_abs, bak_abs)
			if cp != OK:
				out.error = "采集备份失败: %s (err=%d)" % [rel, cp]
				return out
		out.action = "captured" if not has_bak else "recaptured"
		truth = src_abs if not has_bak else bak_abs
	elif src_md5 == FileAccess.get_md5(bak_abs):
		# R1：原画未动
		out.action = "printed"
	elif journal.get(rel, "") == src_md5:
		# R2：账本认证的我的印品
		out.action = "reprinted"
	elif migration:
		# 迁移兜底（仅无账本的首次运行）
		var src_img := Image.load_from_file(src_abs)
		var bak_img := Image.load_from_file(bak_abs)
		if src_img == null or bak_img == null:
			out.error = "无法解码（迁移判定失败），跳过: %s" % rel
			return out
		if src_img.get_size() == bak_img.get_size():
			# 同尺寸不同内容 = 同尺寸换画 → 换底
			if not dry:
				var cp2 := DirAccess.copy_absolute(src_abs, bak_abs)
				if cp2 != OK:
					out.error = "换底失败: %s (err=%d)" % [rel, cp2]
					return out
			out.action = "recaptured"
		else:
			# 尺寸不像原画 = 无账本时代的旧印品 → 保守重印（绝不误收底）
			out.action = "reprinted"
	else:
		# R3：内容对不上任何已知身份 → 用户投稿的新原画 → 换底
		if Image.load_from_file(src_abs) == null:
			out.error = "源不可解码且身份不明，跳过（备份未受污染）: %s" % rel
			return out
		if not dry:
			var cp3 := DirAccess.copy_absolute(src_abs, bak_abs)
			if cp3 != OK:
				out.error = "换底失败: %s (err=%d)" % [rel, cp3]
				return out
		out.action = "recaptured"

	# 打印（母本 = truth；R0 新收底时 truth 即源本身，与备份内容一致）
	var image := Image.load_from_file(truth)
	if image == null:
		out.error = "无法读取原底: %s" % rel
		return out
	var nw := maxi(1, int(round(image.get_width() * factor)))
	var nh := maxi(1, int(round(image.get_height() * factor)))
	if not out.is_mask:
		image.fix_alpha_edges()
	image.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
	if dry:
		return out
	var save_err := image.save_png(src_abs)
	if save_err != OK:
		out.error = "写回失败: %s (err=%d)" % [rel, save_err]
		out.action = ""
		return out
	var out_md5 := FileAccess.get_md5(src_abs)
	journal[rel] = out_md5
	append_journal(bak_global, rel, out_md5)
	return out


### 同步封装（headless 测试入口；runner 循环逐文件调 process_pair 同语义） -----

static func apply_scale(source_dir: String, backup_dir: String, factor: float, reclaim_original: bool) -> Dictionary:
	var result := _empty_result()
	if factor <= 0.0:
		result.errors.append("缩放系数必须大于 0")
		return result
	var pairs := collect_scale_pairs(source_dir, backup_dir)
	if pairs.is_empty():
		result.errors.append("源目录没有 PNG 文件: %s" % source_dir)
		return result
	var bak_global := ProjectSettings.globalize_path(backup_dir)
	var src_global := ProjectSettings.globalize_path(source_dir)
	var migration := not FileAccess.file_exists(bak_global.path_join(JOURNAL_FILE))
	result.migrated = migration
	var journal := load_journal(bak_global)
	var seen := {}  # 仅本次源目录实际处理的文件（压实依据，删除的美术不留死条目）
	for p in pairs:
		var r := process_pair(p["src"], p["bak"], p["rel"], factor, reclaim_original, migration, false, bak_global, journal)
		if not r.error.is_empty():
			result.errors.append(r.error)
			continue
		_tally(result, r.action, r.is_mask)
		seen[p["rel"]] = journal.get(p["rel"], "")
	compact_journal(bak_global, seen)
	result.orphans = count_orphans(src_global, bak_global)
	return result


static func restore_to_original(source_dir: String, backup_dir: String) -> Dictionary:
	var result := _empty_result()
	var pairs := collect_restore_pairs(source_dir, backup_dir)
	if pairs.is_empty():
		result.errors.append("备份目录没有文件，无法恢复: %s" % backup_dir)
		return result
	for p in pairs:
		var err := restore_one(p["bak"], p["src"])
		if not err.is_empty():
			result.errors.append(err)
			continue
		result.restored += 1
	clear_journal(ProjectSettings.globalize_path(backup_dir))
	return result


## 干跑：仅判定（确认弹窗预览计数用），返回与 apply_scale 相同计数字典（不含写盘）
static func preview_actions(source_dir: String, backup_dir: String, factor: float) -> Dictionary:
	var result := _empty_result()
	var pairs := collect_scale_pairs(source_dir, backup_dir)
	var bak_global := ProjectSettings.globalize_path(backup_dir)
	var migration := not FileAccess.file_exists(bak_global.path_join(JOURNAL_FILE))
	result.migrated = migration
	var journal := load_journal(bak_global)
	for p in pairs:
		var r := process_pair(p["src"], p["bak"], p["rel"], factor, false, migration, true, bak_global, journal)
		if not r.error.is_empty():
			result.errors.append(r.error)
			continue
		_tally(result, r.action, r.is_mask)
	return result


### 配对与恢复（源/备份目录扫描） ------------------------------------------------

static func collect_scale_pairs(source_dir: String, backup_dir: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var src_root := ProjectSettings.globalize_path(source_dir)
	var bak_root := ProjectSettings.globalize_path(backup_dir)
	for abs_path in _collect_pngs(src_root, bak_root):
		var rel: String = abs_path.trim_prefix(src_root).trim_prefix("/")
		out.append({"src": abs_path, "bak": bak_root.path_join(rel), "rel": rel})
	return out


static func collect_restore_pairs(source_dir: String, backup_dir: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var src_root := ProjectSettings.globalize_path(source_dir)
	var bak_root := ProjectSettings.globalize_path(backup_dir)
	for abs_path in _collect_pngs_in(bak_root):
		var rel: String = abs_path.trim_prefix(bak_root).trim_prefix("/")
		out.append({"src": src_root.path_join(rel), "bak": abs_path, "rel": rel})
	return out


static func restore_one(bak_abs: String, src_abs: String) -> String:
	_ensure_parent_dir(src_abs)
	var err := DirAccess.copy_absolute(bak_abs, src_abs)
	if err != OK:
		return "恢复失败: %s (err=%d)" % [bak_abs.get_file(), err]
	return ""


## 备份有、源无 的 PNG 数量（被删除美术的原画残留统计，绝对路径入口）
static func count_orphans(src_global: String, bak_global: String) -> int:
	var n := 0
	for bak_file in _collect_pngs_in(bak_global):
		var rel: String = bak_file.trim_prefix(bak_global).trim_prefix("/")
		if not FileAccess.file_exists(src_global.path_join(rel)):
			n += 1
	return n


### 账本 ------------------------------------------------------------------------

static func journal_path(bak_global: String) -> String:
	return bak_global.path_join(JOURNAL_FILE)


## 读账本：每行 "rel\thash"，后写覆盖先写（append-only 语义）
static func load_journal(bak_global: String) -> Dictionary:
	var out := {}
	var f := FileAccess.open(journal_path(bak_global), FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line()
		if line.is_empty():
			continue
		var tab := line.find("\t")
		if tab > 0:
			out[line.substr(0, tab)] = line.substr(tab + 1)
	return out


static func append_journal(bak_global: String, rel: String, out_md5: String) -> void:
	var path := journal_path(bak_global)
	if not FileAccess.file_exists(path):
		var mk := FileAccess.open(path, FileAccess.WRITE)
		if mk != null:
			mk.close()
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line("%s\t%s" % [rel, out_md5])
	f.close()


## 压实：写入本次处理过的 { rel: 最新输出md5 }（同时完成迁移"建账"）
static func compact_journal(bak_global: String, journal: Dictionary) -> void:
	var keys := journal.keys()
	keys.sort()
	var f := FileAccess.open(journal_path(bak_global), FileAccess.WRITE)
	if f == null:
		return
	for k in keys:
		f.store_line("%s\t%s" % [k, journal[k]])
	f.close()


static func clear_journal(bak_global: String) -> void:
	var f := FileAccess.open(journal_path(bak_global), FileAccess.WRITE)
	if f != null:
		f.close()


## mask 母版体系的双写核心（供编辑器与测试复用，纯文件操作可 headless）。
## canvas = 母版画布尺寸的 mask：权威版原样写 master_path；
## 再等比缩印到 output_size 写 output_path（游戏读的成品层）。
## 返回 { "ok": bool, "master_error": String, "output_error": String }
static func write_mask_pair(canvas: Image, master_path: String, output_path: String, output_size: Vector2i) -> Dictionary:
	var res := {"ok": false, "master_error": "", "output_error": ""}
	var m_err := canvas.save_png(ProjectSettings.globalize_path(master_path))
	if m_err != OK:
		res.master_error = "master save err=%d" % m_err
		return res
	var printed: Image = canvas.duplicate()
	if printed.get_width() != output_size.x or printed.get_height() != output_size.y:
		printed.resize(output_size.x, output_size.y, Image.INTERPOLATE_LANCZOS)
	var o_err := printed.save_png(ProjectSettings.globalize_path(output_path))
	if o_err != OK:
		res.output_error = "output save err=%d" % o_err
		return res
	res.ok = true
	return res


## 与 write_mask_pair 对称的删除核心：彻底移除某档蒙版文件。
## 母版模式删 母版+成品 两份（并清各自 .import/.uid 伴生，杜绝缩放从母版复活、杜绝残留报错）；
## 非母版模式仅删成品单份。不存在的目标静默跳过（幂等）。
## 返回 { "ok": bool, "deleted": [路径…], "errors": [信息…] }
static func delete_mask_pair(master_path: String, output_path: String, in_master_mode: bool) -> Dictionary:
	var result := {"ok": true, "deleted": [] as Array[String], "errors": [] as Array[String]}
	var targets: Array[String] = []
	if in_master_mode and not master_path.is_empty():
		targets.append(master_path)
	if not output_path.is_empty() and (not in_master_mode or output_path != master_path):
		targets.append(output_path)
	for res_path in targets:
		if not FileAccess.file_exists(res_path):
			continue
		var g := ProjectSettings.globalize_path(res_path)
		var err := DirAccess.remove_absolute(g)
		if err == OK:
			result.deleted.append(res_path)
		else:
			result.ok = false
			result.errors.append("删除失败: %s (err=%d)" % [res_path, err])
		for side in [g + ".import", g + ".uid"]:
			if FileAccess.file_exists(side):
				DirAccess.remove_absolute(side)
	return result


### 内部辅助 --------------------------------------------------------------------

static func _empty_result() -> Dictionary:
	return {
		"scaled": 0, "masks": 0, "backed_up": 0, "recaptured": 0,
		"printed": 0, "reprinted": 0,
		"restored": 0, "orphans": 0, "migrated": false,
		"errors": [] as Array[String],
	}


static func _tally(result: Dictionary, action: String, is_mask: bool) -> void:
	match action:
		"captured":
			result.backed_up += 1
		"recaptured":
			result.recaptured += 1
		"printed":
			result.printed += 1
		"reprinted":
			result.reprinted += 1
	if is_mask:
		result.masks += 1
	else:
		result.scaled += 1


static func _collect_pngs(src_global: String, bak_global: String) -> Array[String]:
	var out := _collect_pngs_in(src_global)
	var filtered: Array[String] = []
	for p in out:
		if not p.begins_with(bak_global + "/"):
			filtered.append(p)
	return filtered


static func _collect_pngs_in(global_dir: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(global_dir)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := global_dir.path_join(name)
		if dir.current_is_dir():
			out.append_array(_collect_pngs_in(full))
		elif name.ends_with(".png") and not name.ends_with(".no.png"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


static func _ensure_parent_dir(global_file_path: String) -> bool:
	var parent := global_file_path.get_base_dir()
	if DirAccess.dir_exists_absolute(parent):
		return true
	return DirAccess.make_dir_recursive_absolute(parent) == OK
