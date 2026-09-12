@tool
extends RefCounted
## PNG 缩放工具核心（纯文件操作原语，不依赖编辑器运行时，可 headless 测试）
##
## 语义（钉死的规则）：
## 1. 首次执行先把源目录 PNG 备份到备份目录（文件名不变、只换位置），备份只认第一次
## 2. 缩放永远从备份原图重算写回源目录——杜绝"缩小版再缩小"的画质复损
## 3. restore：备份整体拷回源目录
## 4. reclaim_original=true 时才用当前源图覆盖备份（手动换了一套新美术的场景）
## 5. *.mask.png（含 .body./.attack. 三型）直接 resize；普通精灵图
##    fix_alpha_edges（不透明颜色渗入透明像素，防重采样黑边）→ Lanczos
##    （4.7 的 Image 无 depremultiply_alpha，premultiply 路线不可逆，弃用）
## 6. 单文件语义全部集中在 scale_one()/restore_one() 原语：
##    同步封装 apply_scale()/restore_to_original()（headless 测试用）与
##    编辑器 runner 的分帧循环共用同一原语，单一实现、双入口
## 7. 完成后由调用方负责"重跑 Body/Attack 轮廓转换"提醒与资源扫描

## 源目录内全部待处理 PNG 的配对表（排除备份目录自身防自吞）
## 返回 Array[Dictionary]: [{ "src": 绝对路径, "bak": 备份绝对路径, "rel": 相对路径 }]
static func collect_scale_pairs(source_dir: String, backup_dir: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var src_root := ProjectSettings.globalize_path(source_dir)
	var bak_root := ProjectSettings.globalize_path(backup_dir)
	for abs_path in _collect_pngs(source_dir, backup_dir):
		var rel: String = abs_path.trim_prefix(src_root).trim_prefix("/")
		out.append({"src": abs_path, "bak": bak_root.path_join(rel), "rel": rel})
	return out


## 单文件"采集备份（若缺/强制）→ 从备份缩放 → 写回源"。
## 返回 { "error": ""表示成功, "backed_up": 本次是否新采集了原底, "is_mask": 是否掩码 }
static func scale_one(src_abs: String, bak_abs: String, factor: float, reclaim_original: bool) -> Dictionary:
	var out := {"error": "", "backed_up": false, "is_mask": src_abs.ends_with(".mask.png")}
	if factor <= 0.0:
		out.error = "缩放系数必须大于 0"
		return out
	
	# 规则 1/4：备份缺失或显式 reclaim 时，以当前源图为原底
	if reclaim_original or not FileAccess.file_exists(bak_abs):
		if not FileAccess.file_exists(src_abs):
			out.error = "源文件不存在: %s" % src_abs.get_file()
			return out
		if not _ensure_parent_dir(bak_abs):
			out.error = "无法创建备份目录: %s" % bak_abs.get_base_dir()
			return out
		var cp_err := DirAccess.copy_absolute(src_abs, bak_abs)
		if cp_err != OK:
			out.error = "备份失败: %s (err=%d)" % [src_abs.get_file(), cp_err]
			return out
		out.backed_up = true
	
	# 规则 2：永远从备份缩放
	var image := Image.load_from_file(bak_abs)
	if image == null:
		out.error = "无法读取备份图: %s" % bak_abs.get_file()
		return out
	var nw := maxi(1, int(round(image.get_width() * factor)))
	var nh := maxi(1, int(round(image.get_height() * factor)))
	if not out.is_mask:
		image.fix_alpha_edges()
	image.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
	var save_err := image.save_png(src_abs)
	if save_err != OK:
		out.error = "写回失败: %s (err=%d)" % [src_abs.get_file(), save_err]
		return out
	return out


## 备份目录 → 源目录的配对表（按备份侧枚举，恢复不依赖源当前内容）
static func collect_restore_pairs(source_dir: String, backup_dir: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var src_root := ProjectSettings.globalize_path(source_dir)
	var bak_root := ProjectSettings.globalize_path(backup_dir)
	for abs_path in _collect_pngs_in(bak_root):
		var rel: String = abs_path.trim_prefix(bak_root).trim_prefix("/")
		out.append({"src": src_root.path_join(rel), "bak": abs_path, "rel": rel})
	return out


## 单文件恢复：备份拷回源。返回 ""=成功。
static func restore_one(bak_abs: String, src_abs: String) -> String:
	_ensure_parent_dir(src_abs)
	var err := DirAccess.copy_absolute(bak_abs, src_abs)
	if err != OK:
		return "恢复失败: %s (err=%d)" % [bak_abs.get_file(), err]
	return ""


## 同步封装：完整缩放流程（runner 分帧循环的等价一次性版本，headless 测试入口）
static func apply_scale(source_dir: String, backup_dir: String, factor: float, reclaim_original: bool) -> Dictionary:
	var result := _empty_result()
	if factor <= 0.0:
		result.errors.append("缩放系数必须大于 0")
		return result
	var pairs := collect_scale_pairs(source_dir, backup_dir)
	if pairs.is_empty():
		result.errors.append("源目录没有 PNG 文件: %s" % source_dir)
		return result
	for p in pairs:
		var r := scale_one(p["src"], p["bak"], factor, reclaim_original)
		if not r.error.is_empty():
			result.errors.append(r.error)
			continue
		if r.backed_up:
			result.backed_up += 1
		if r.is_mask:
			result.masks += 1
		else:
			result.scaled += 1
	return result


## 同步封装：完整恢复流程
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
	return result


### 内部辅助 ------------------------------------------------------------------------

static func _empty_result() -> Dictionary:
	return {"scaled": 0, "masks": 0, "backed_up": 0, "restored": 0, "errors": [] as Array[String]}


## 源目录下全部 PNG 绝对路径（递归）；排除位于备份目录内的文件（防自吞）
static func _collect_pngs(source_dir: String, backup_dir: String) -> Array[String]:
	var out := _collect_pngs_in(ProjectSettings.globalize_path(source_dir))
	var bak := ProjectSettings.globalize_path(backup_dir)
	var filtered: Array[String] = []
	for p in out:
		if not p.begins_with(bak + "/"):
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
		elif name.ends_with(".png"):
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
