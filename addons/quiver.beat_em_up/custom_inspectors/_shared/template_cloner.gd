@tool
extends RefCounted
## 模板克隆引擎（创建器产线共享核心，2026-09-17 合流：原角色/法术两套孪生
## 逻辑逐字重复约 1200 行，公共动作收进本文件；校验、布局解析、UI 留在各线）。
## 纯"复制→改名→占位替换→.import 清理"，不掺业务语义。
## 引用方式用 preload 而非 class_name：全局类缓存要编辑器扫描才登记，
## headless 测试进程不重扫（WheelProbe 同源教训）。

const BINARY_EXTS := ["png", "jpg", "jpeg", "webp", "svg", "wav", "ogg", "mp3"]
const TEXT_EXTS := ["gd", "tscn", "tres"]


## 从模板目录克生出目标资产目录。
## rename_token：文件名里等待替换的占位词（角色/法术同为 "__NAME__"）；
## tokens 必须含 rename_token 这一键（其值用于文件名改名）。
static func clone_from_template(
		template_dir: String,
		target_dir: String,
		tokens: Dictionary,
		excluded_files: Array,
		rename_token: String = "__NAME__",
		pre_make_dirs: PackedStringArray = PackedStringArray(),
		label: String = "模板") -> bool:
	if DirAccess.dir_exists_absolute(target_dir):
		push_error("%s: 目标目录已存在: %s" % [label, target_dir])
		return false
	if DirAccess.make_dir_recursive_absolute(target_dir) != OK:
		push_error("%s: 创建目录失败: %s" % [label, target_dir])
		return false
	for sub in pre_make_dirs:
		DirAccess.make_dir_recursive_absolute(target_dir.path_join(sub))
	if not _copy_tree(template_dir, target_dir, excluded_files, label):
		return false
	if not _rename_files(target_dir, rename_token, String(tokens.get(rename_token, "")), label):
		return false
	if not _replace_tokens(target_dir, tokens, label):
		return false
	_wipe_imports(target_dir)
	return true


## 递归删除目录及全部内容后移除目录本身（删除器共用）。
static func wipe_directory(target_dir: String, label: String) -> bool:
	if not DirAccess.dir_exists_absolute(target_dir):
		push_error("%s: 目录不存在: %s" % [label, target_dir])
		return false
	if not _wipe_tree(target_dir, label):
		return false
	if DirAccess.remove_absolute(target_dir) != OK:
		push_error("%s: 清空后移除目录失败: %s" % [label, target_dir])
		return false
	return true


### -----------------------------------------------------------------------------------------------
### 内部实现（原孪生函数的唯一权威版本）
### -----------------------------------------------------------------------------------------------

static func _copy_tree(source: String, destination: String, excluded_files: Array, label: String) -> bool:
	var dir := DirAccess.open(source)
	if dir == null:
		push_error("%s: 打开模板目录失败: %s" % [label, source])
		return false
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while not file_name.is_empty():
		if file_name != "." and file_name != "..":
			var source_path := source.path_join(file_name)
			var dest_path := destination.path_join(file_name)
			if dir.current_is_dir():
				if DirAccess.make_dir_recursive_absolute(dest_path) != OK:
					push_error("%s: 创建子目录失败: %s" % [label, dest_path])
					return false
				if not _copy_tree(source_path, dest_path, excluded_files, label):
					return false
			elif file_name not in excluded_files and not file_name.ends_with(".uid"):
				if not _copy_file(source_path, dest_path):
					return false
		file_name = dir.get_next()
	return true


static func _copy_file(source: String, destination: String) -> bool:
	var src_file := FileAccess.open(source, FileAccess.READ)
	if src_file == null:
		push_error("模板克隆: 无法打开源文件 %s" % source)
		return false
	if source.get_extension() in BINARY_EXTS:
		var data := src_file.get_buffer(src_file.get_length())
		src_file.close()
		var wb := FileAccess.open(destination, FileAccess.WRITE)
		if wb == null:
			push_error("模板克隆: 无法写入目标 %s" % destination)
			return false
		wb.store_buffer(data)
		wb.close()
		return true
	var content := src_file.get_as_text()
	src_file.close()
	# 文本：剥离嵌入 UID（防新资产继承模板 UID 撞车；ext_resource 行必须
	# 同覆盖——编辑器保存会给它自动补 uid，2026-09-15 审计 L5）
	var regex := RegEx.new()
	regex.compile("(\\[(?:gd_(?:scene|resource)|ext_resource)[^\\]]*?)\\s+uid=\"[^\"]+\"")
	content = regex.sub(content, "$1", true)
	var dest_file := FileAccess.open(destination, FileAccess.WRITE)
	if dest_file == null:
		push_error("模板克隆: 无法写入目标 %s" % destination)
		return false
	dest_file.store_string(content)
	dest_file.close()
	return true


static func _rename_files(directory: String, token: String, replacement: String, label: String) -> bool:
	var dir := DirAccess.open(directory)
	if dir == null:
		push_error("%s: 打开改名目录失败: %s" % [label, directory])
		return false
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var pending: Array = []
	while not file_name.is_empty():
		if file_name != "." and file_name != "..":
			if dir.current_is_dir():
				if not _rename_files(directory.path_join(file_name), token, replacement, label):
					return false
			elif file_name.find(token) != -1:
				pending.append({"old": file_name, "new": file_name.replace(token, replacement)})
		file_name = dir.get_next()
	for item in pending:
		if dir.rename(item["old"], item["new"]) != OK:
			push_error("%s: 改名失败 %s -> %s" % [label, directory.path_join(item["old"]), directory.path_join(item["new"])])
			return false
	# 目录自身也可能带占位词（模板的 __NAME___attributes/ 子目录，原版行为保真）
	var dir_name := directory.get_file()
	if dir_name.find(token) != -1:
		var parent := DirAccess.open(directory.get_base_dir())
		if parent == null or parent.rename(dir_name, dir_name.replace(token, replacement)) != OK:
			push_error("%s: 目录改名失败: %s" % [label, directory])
			return false
	return true


static func _replace_tokens(directory: String, tokens: Dictionary, label: String) -> bool:
	var dir := DirAccess.open(directory)
	if dir == null:
		push_error("%s: 打开替换目录失败: %s" % [label, directory])
		return false
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while not file_name.is_empty():
		if file_name != "." and file_name != "..":
			var file_path := directory.path_join(file_name)
			if dir.current_is_dir():
				if not _replace_tokens(file_path, tokens, label):
					return false
			elif file_name.get_extension() in TEXT_EXTS:
				if not _replace_in_file(file_path, tokens, label):
					return false
		file_name = dir.get_next()
	return true


static func _replace_in_file(file_path: String, tokens: Dictionary, label: String) -> bool:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("%s: 无法读取 %s" % [label, file_path])
		return false
	var content := file.get_as_text()
	file.close()
	# 占位词互不为子串，遍历序无关（角色 12 格/法术 3 格同一循环）
	for token in tokens:
		content = content.replace(token, tokens[token])
	file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("%s: 无法写回 %s" % [label, file_path])
		return false
	file.store_string(content)
	file.close()
	return true


static func _wipe_imports(directory: String) -> void:
	var dir := DirAccess.open(directory)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while not file_name.is_empty():
		if file_name != "." and file_name != "..":
			if dir.current_is_dir():
				_wipe_imports(directory.path_join(file_name))
			elif file_name.ends_with(".import"):
				dir.remove(file_name)
		file_name = dir.get_next()


static func _wipe_tree(directory: String, label: String) -> bool:
	var dir := DirAccess.open(directory)
	if dir == null:
		push_error("%s: 打开删除目录失败: %s" % [label, directory])
		return false
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while not file_name.is_empty():
		if file_name != "." and file_name != "..":
			var file_path := directory.path_join(file_name)
			if dir.current_is_dir():
				if not _wipe_tree(file_path, label):
					return false
				if dir.remove(file_name) != OK:
					push_error("%s: 移除子目录失败: %s" % [label, file_path])
					return false
			elif dir.remove(file_name) != OK:
				push_error("%s: 删除文件失败: %s" % [label, file_path])
				return false
		file_name = dir.get_next()
	return true
