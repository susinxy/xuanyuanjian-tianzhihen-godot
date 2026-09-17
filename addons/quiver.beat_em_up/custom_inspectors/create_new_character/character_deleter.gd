@tool
extends RefCounted
class_name CharacterDeleter
## 角色删除器：特判名单留本线，递归清除委托共享引擎（2026-09-17 产线合流）。

const TemplateCloner := preload("res://addons/quiver.beat_em_up/custom_inspectors/_shared/template_cloner.gd")

const CHARACTERS_ROOT = "res://characters/"


## 删除一个角色目录及全部内容。pkg 为阵营包目录（playable/enemies/allies/neutrals）。
func delete_character(char_name: String, pkg: String = "playable") -> bool:
	var target_dir := CHARACTERS_ROOT.path_join(pkg).path_join(char_name)
	if char_name in ["_template", ".", ".."]:
		push_error("Cannot delete special directory: %s" % char_name)
		return false
	if not TemplateCloner.wipe_directory(target_dir, "角色删除"):
		return false
	print_rich("[color=green]✓ Character deleted: %s[/color]" % char_name)
	return true
