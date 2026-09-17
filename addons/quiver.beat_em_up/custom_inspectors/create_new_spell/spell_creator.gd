@tool
extends RefCounted
class_name SpellCreator
## 法术创建器：只留法术线知识（token 三格 + 预建目录 + 排除名单），
## 克隆动作委托共享引擎（_shared/template_cloner.gd，2026-09-17 产线合流）。
## 真相全部物化在 templates/spell/，不再有代码内嵌字符串
## （历史上双作者已漂移：模板停在双向、内嵌串升级了四向——2026-09-15 定档）。

const TemplateCloner := preload("res://addons/quiver.beat_em_up/custom_inspectors/_shared/template_cloner.gd")

const TEMPLATE_DIR = "res://templates/spell/"
const SPELL_DIR = "res://spells/"

const TOKEN_NAME = "__NAME__"
const TOKEN_CLASS = "__CLASS__"
const TOKEN_DISPLAY = "__DISPLAY_NAME__"

const EXCLUDED_FILES = [
	"spell_template.tscn",
	"spell_template.gd",
	"spell_template.gd.uid",
	"README.md",
]


func create_spell(spell_name: String, pascal_name: String, display_name: String) -> bool:
	var target_dir := SPELL_DIR.path_join(spell_name)
	var tokens := {
		TOKEN_NAME: spell_name,
		TOKEN_CLASS: pascal_name,
		TOKEN_DISPLAY: display_name,
	}
	if not TemplateCloner.clone_from_template(
			TEMPLATE_DIR, target_dir, tokens, EXCLUDED_FILES,
			TOKEN_NAME, PackedStringArray(["resources/animations"]), "法术创建"):
		return false
	print_rich("[color=green]✓ Spell created: %s (%s) at %s[/color]" % [display_name, spell_name, target_dir])
	return true
