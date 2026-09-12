@tool
extends RefCounted
## PNG 缩放工具（核心逻辑，纯文件操作，不依赖编辑器运行时，可 headless 测试）
##
## 语义（钉死的 6 条规则）：
## 1. 首次执行先把源目录 PNG 备份到备份目录（文件名不变、只换位置），备份只认第一次
## 2. 缩放永远从备份原图重算写回源目录——杜绝"缩小版再缩小"的画质复损
## 3. restore_to_original：备份整体拷回源目录
## 4. reclaim_original=true 时才用当前源图覆盖备份（手动换了一套新美术的场景）
## 5. *.mask.png（含 .body./.attack. 三型）直接 resize；普通精灵图
##    fix_alpha_edges（把不透明颜色渗入透明像素，防重采样黑边）→ resize。
##    （4.7 的 Image 无 depremultiply_alpha，premultiply 路线不可逆，弃用）
## 6. 由调用方（widget）负责提示"动画数据已过期需重跑轮廓转换"与触发资源扫描

## 执行结果统计
const RESULT_KEYS := ["scaled", "masks", "backed_up", "restored", "errors"]


## 缩放主流程。所有目录使用 res:// 路径。
## 返回 { scaled:int, masks:int, backed_up:int, restored:int, errors:Array[String] }
static func apply_scale(source_dir: String, backup_dir: String, factor: float, reclaim_original: bool) -> Dictionary:
	var result := _empty_result()
	if factor <= 0.0:
		result.errors.append("缩放系数必须大于 0")
		return result
	var files := _collect_pngs(source_dir, backup_dir)
	if files.is_empty():
		result.errors.append("源目录没有 PNG 文件: %s" % source_dir)
		return result
	
	var src_root := ProjectSettings.globalize_path(source_dir)
	var bak_root := ProjectSettings.globalize_path(backup_dir)
	
	for abs_path in files:
		var rel: String = abs_path.trim_prefix(src_root).trim_prefix("/")
		var backup_path := bak_root.path_join(rel)
		
		# 规则 1/4：采集原底（仅当备份缺失，或显式 reclaim）
		if not FileAccess.file_exists(backup_path) or reclaim_original:
			if not _ensure_parent_dir(backup_path):
				result.errors.append("无法创建备份目录: %s" % backup_path.get_base_dir())
				continue
			var cp_err := DirAccess.copy_absolute(abs_path, backup_path)
			if cp_err != OK:
				result.errors.append("备份失败: %s (err=%d)" % [rel, cp_err])
				continue
			result.backed_up += 1
		
		# 规则 2：永远从备份缩放
		var image := Image.load_from_file(backup_path)
		if image == null:
			result.errors.append("无法读取备份图: %s" % rel)
			continue
		var nw := maxi(1, int(round(image.get_width() * factor)))
		var nh := maxi(1, int(round(image.get_height() * factor)))
		var is_mask := rel.ends_with(".mask.png")
		if not is_mask:
			image.fix_alpha_edges()
		image.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
		
		var save_err := image.save_png(abs_path)
		if save_err != OK:
			result.errors.append("写回失败: %s (err=%d)" % [rel, save_err])
			continue
		
		if is_mask:
			result.masks += 1
		else:
			result.scaled += 1
	
	return result


## 恢复原图：备份目录所有文件按相对路径拷回源目录。
static func restore_to_original(source_dir: String, backup_dir: String) -> Dictionary:
	var result := _empty_result()
	var src_root := ProjectSettings.globalize_path(source_dir)
	var bak_root := ProjectSettings.globalize_path(backup_dir)
	var files := _collect_pngs_in(bak_root)
	if files.is_empty():
		result.errors.append("备份目录没有文件，无法恢复: %s" % backup_dir)
		return result
	
	for abs_path in files:
		var rel: String = abs_path.trim_prefix(bak_root).trim_prefix("/")
		var target := src_root.path_join(rel)
		_ensure_parent_dir(target)
		var err := DirAccess.copy_absolute(abs_path, target)
		if err != OK:
			result.errors.append("恢复失败: %s (err=%d)" % [rel, err])
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
