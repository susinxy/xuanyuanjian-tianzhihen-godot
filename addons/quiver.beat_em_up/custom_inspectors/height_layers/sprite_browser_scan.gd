@tool
extends RefCounted
## 蒙版编辑器左侧"图片列表"的纯数据层：目录扫描/伴生识别/类型映射。
## 刻意不依赖编辑器单例与注入器，游戏模式亦可加载（headless 可测）。
## 🎭/⛔ 标记判定不在这里——由蒙版编辑器直接复用注入器的
## resolve_mask_path()/find_no_marker()，保证图标与真实转换同一套规则。

## 扫描浏览根，返回 [{dir: 相对目录(""=根), files: [资源路径升序]}]，按 dir 升序。
static func scan_sprite_tree(root: String) -> Array:
	var groups: Array = []
	_scan_into(root, "", groups)
	groups.sort_custom(func(a, b): return String(a["dir"]) < String(b["dir"]))
	return groups


static func _scan_into(root: String, rel: String, groups: Array) -> void:
	var full := root.path_join(rel) if rel != "" else root
	var d := DirAccess.open(full)
	if d == null:
		return
	var subs: Array[String] = []
	var files: Array[String] = []
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		var sub_rel := (rel + "/" + n) if rel != "" else n
		if d.current_is_dir():
			if not n.begins_with(".") and n != "png_scale_backup" and n != "sprites_master":
				subs.append(sub_rel)
		elif n.ends_with(".png") and not is_companion_png(n):
			files.append(root.path_join(sub_rel))
		n = d.get_next()
	d.list_dir_end()
	files.sort()
	if not files.is_empty():
		groups.append({"dir": rel, "files": files})
	subs.sort()
	for s in subs:
		_scan_into(root, s, groups)


## 伴生文件识别：蒙版三型/通用、跳过标记四型都不算"图片"
static func is_companion_png(file_name: String) -> bool:
	if not file_name.ends_with(".png"):
		return true
	var core := file_name.trim_suffix(".png")
	for suf in [".shadow.mask", ".attack.mask", ".body.mask", ".mask",
			".shadow.no", ".attack.no", ".body.no", ".no"]:
		if core.ends_with(suf):
			return true
	return false


## 类型下拉框选项 id → 解析链类别键（与注入器同词表；"generic" 走默认单档链）
static func option_category(id: int) -> String:
	match id:
		1: return "body"
		2: return "attack"
		3: return "shadow"
		_: return "generic"
