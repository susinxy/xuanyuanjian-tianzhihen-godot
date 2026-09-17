@tool
extends RefCounted
class_name SpellDeleter
## 法术删除器：特判名单留本线，递归清除委托共享引擎（2026-09-17 产线合流）。

const TemplateCloner := preload("res://addons/quiver.beat_em_up/custom_inspectors/_shared/template_cloner.gd")

const SPELL_DIR = "res://spells/"


func delete_spell(spell_name: String) -> bool:
	if spell_name in ["_template", "_base", ".", ".."]:
		push_error("Cannot delete special directory: %s" % spell_name)
		return false
	var target_dir := SPELL_DIR.path_join(spell_name)
	if not TemplateCloner.wipe_directory(target_dir, "法术删除"):
		return false
	print_rich("[color=green]✓ Spell deleted: %s[/color]" % spell_name)
	return true
