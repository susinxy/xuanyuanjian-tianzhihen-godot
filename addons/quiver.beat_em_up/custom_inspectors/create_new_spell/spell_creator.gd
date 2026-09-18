@tool
extends RefCounted
class_name SpellCreator
## 法术创建器：身份 token + 预建目录 + 排除名单交共享克隆引擎
## （_shared/template_cloner.gd），法术线知识（默认表、合成）留本文件。
##
## 出生数值合成（2026-09-18 与角色线同批拉齐，"面板=出生数值唯一真相"）：
## definition 与 attack_data 不再随模板快照携带，克隆后由本文件全量合成；
## 模板禁止存在这两个文件（sync 工具反向守卫）。
## 默认表是本机件出生值的唯一权威（widget 初值与合成兜底共用）。

const TemplateCloner := preload("res://addons/quiver.beat_em_up/custom_inspectors/_shared/template_cloner.gd")

const TEMPLATE_DIR = "res://templates/spell/"
const SPELL_DIR = "res://spells/"

const TOKEN_NAME = "__NAME__"
const TOKEN_CLASS = "__CLASS__"
const TOKEN_DISPLAY = "__DISPLAY_NAME__"

## 法术定义出生默认（数值=旧 fire_ball 快照演示值的等值搬运；
## release 拆 x/y 两栏供面板直排；状态列表用逗号串，空=不限）。
const DEFAULT_DEF_STATS := {
	"description": "",
	"mana_cost": 0.0,
	"max_lifetime": 5.0,
	"cooldown": 3.0,
	"caster_cast_time": 0.5,
	"release_x": 1.0,
	"release_y": 0.34,
	"fade_in_time": 0.3,
	"fade_out_time": 0.35,
	"allowed_states": "",
	"disallowed_states": "Die,Knockout",
}

## 法术攻击数据出生默认（同上，fire_ball 演示值等值搬运）。
const DEFAULT_ATTACK := {
	"attack_damage": 10.0,
	"hurt_type": 1,
	"knock_strength": 60.0,
	"launch_angle": 15.0,
}

const EXCLUDED_FILES = [
	"spell_template.tscn",
	"spell_template.gd",
	"spell_template.gd.uid",
	"README.md",
]


## def_stats/attack 为出生数值覆盖表（缺省=DEFAULT_* 两表）。
func create_spell(
		spell_name: String, pascal_name: String, display_name: String,
		def_stats: Dictionary = {}, attack: Dictionary = {}) -> bool:
	var target_dir := SPELL_DIR.path_join(spell_name)
	var tokens := {
		TOKEN_NAME: spell_name,
		TOKEN_CLASS: pascal_name,
		TOKEN_DISPLAY: display_name,
	}
	if not TemplateCloner.clone_from_template(
			TEMPLATE_DIR, target_dir, tokens, EXCLUDED_FILES,
			TOKEN_NAME, PackedStringArray(["resources/animations", "resources/attacks"]),
			"法术创建"):
		return false
	if not _synthesize_definition(target_dir, spell_name, display_name, def_stats):
		return false
	if not _synthesize_attack(target_dir, spell_name, attack):
		return false
	print_rich("[color=green]✓ Spell created: %s (%s) at %s[/color]" % [display_name, spell_name, target_dir])
	return true


func _synthesize_definition(
		target_dir: String, spell_name: String,
		display_name: String, def_stats: Dictionary) -> bool:
	var s := merged_def_stats(def_stats)
	var text := "" \
			+ "[gd_resource type=\"Resource\" script_class=\"SpellDefinition\" format=3]\n\n" \
			+ "[ext_resource type=\"Script\" path=\"res://spells/_base/spell_definition.gd\" id=\"1_script\"]\n" \
			+ "[ext_resource type=\"PackedScene\" path=\"res://spells/%s/%s.tscn\" id=\"2_scene\"]\n\n" \
			% [spell_name, spell_name] \
			+ "[resource]\n" \
			+ "script = ExtResource(\"1_script\")\n" \
			+ "spell_id = &\"%s\"\n" % spell_name \
			+ "display_name = \"%s\"\n" % display_name
	if not String(s.description).is_empty():
		text += "description = \"%s\"\n" % s.description
	text += "" \
			+ "spell_scene = ExtResource(\"2_scene\")\n" \
			+ "mana_cost = %s\n" % _num(s.mana_cost) \
			+ "max_lifetime = %s\n" % _num(s.max_lifetime) \
			+ "cooldown = %s\n" % _num(s.cooldown) \
			+ "caster_cast_time = %s\n" % _num(s.caster_cast_time) \
			+ "release_ratio = Vector2(%s, %s)\n" % [_num(s.release_x), _num(s.release_y)] \
			+ "fade_in_time = %s\n" % _num(s.fade_in_time) \
			+ "fade_out_time = %s\n" % _num(s.fade_out_time) \
			+ "allowed_states = %s\n" % _state_array(s.allowed_states) \
			+ "disallowed_states = %s\n" % _state_array(s.disallowed_states)
	return _write_text(
			target_dir.path_join("resources/%s_definition.tres" % spell_name),
			text, "definition 合成")


func _synthesize_attack(target_dir: String, spell_name: String, attack: Dictionary) -> bool:
	var a: Dictionary = DEFAULT_ATTACK.duplicate(true)
	for key in attack.keys():
		if a.has(key):
			a[key] = attack[key]
	var text := "" \
			+ "[gd_resource type=\"Resource\" script_class=\"QuiverAttackData\" format=3]\n\n" \
			+ "[ext_resource type=\"Script\" path=\"res://addons/quiver.beat_em_up/combat/quiver_attack_data.gd\" id=\"1_script\"]\n\n" \
			+ "[resource]\n" \
			+ "script = ExtResource(\"1_script\")\n" \
			+ "attack_damage = %s\n" % _num(a.attack_damage) \
			+ "hurt_type = %d\n" % int(a.hurt_type) \
			+ "knock_strength = %s\n" % _num(a.knock_strength) \
			+ "launch_angle = %s\n" % _num(a.launch_angle)
	return _write_text(
			target_dir.path_join("resources/attacks/%s_attack_data.tres" % spell_name),
			text, "attack 合成")


static func merged_def_stats(partial: Dictionary) -> Dictionary:
	var out := DEFAULT_DEF_STATS.duplicate(true)
	for key in partial.keys():
		if out.has(key):
			out[key] = partial[key]
	return out


## "Die, Knockout" → Array[StringName](&"Die", &"Knockout")；空串→空数组。
static func _state_array(raw) -> String:
	var parts: Array[String] = []
	for piece in String(raw).split(","):
		var one := piece.strip_edges()
		if not one.is_empty():
			parts.append(StringName(one))
	if parts.is_empty():
		return "Array[StringName]([])"
	var quoted: Array[String] = []
	for p in parts:
		quoted.append('&"%s"' % p)
	return "Array[StringName]([%s])" % ", ".join(quoted)


static func _num(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return str(v)


static func _write_text(path: String, text: String, label: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("%s 落盘失败: %s" % [label, path])
		return false
	f.store_string(text)
	f.close()
	return true
