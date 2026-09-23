@tool
extends RefCounted
class_name CharacterCreator
## 角色创建器：解析控制方式×阵营布局 → 组装身份 token → 交给共享克隆引擎
## （_shared/template_cloner.gd）。
##
## 出生数值合成（2026-09-18 "面板=出生数值唯一真相"定档）：attributes 与四张
## 招式 attack_data 不再随模板快照携带——快照体系下数值行会被任何一次 sync 用
## chen 字面值洗掉，面板旋钮沦为静默空转（testme/spar/货摊 现场铁证）。现由本
## 文件在克隆后全量合成，模板禁止存在这些文件（sync 工具反向守卫）。
## 默认表（DEFAULT_STATS/DEFAULT_ATTACKS）是本机件出生值的唯一权威：widget
## 初值与合成兜底共用，改默认只改这里。

const TemplateCloner := preload("res://addons/quiver.beat_em_up/custom_inspectors/_shared/template_cloner.gd")

const TEMPLATE_DIR = "res://templates/character/"
const CHARACTERS_ROOT = "res://characters/"

# 控制方式（与 QuiverCharacter.BehaviorMode 数值一致）
enum ControlMode { PLAYER_INPUT = 0, AI_POLICY = 1, PASSIVE = 2 }

# 模板文件里的占位 token（仅身份类——数值 token 体系随合成本批次退役）
const TOKEN_NAME = "__NAME__"
const TOKEN_CLASS = "__CLASS__"
const TOKEN_DISPLAY = "__DISPLAY_NAME__"
const TOKEN_FACTION = "__FACTION__"            # 阵营标签（area2d:<标签> 的唯一存放点=根节点）
const TOKEN_PKG = "__PKG__"                    # 阵营包目录（playable/enemies/allies/neutrals）
const TOKEN_BEHAVIOR_MODE = "__BEHAVIOR_MODE__"  # 行为档 0/1/2

## 出生属性默认表（键与 QuiverAttributes 导出名一一对应；值=脚本默认而非 chen
## 个性值——can_be_grabbed 的 chen=false 属她自己的编辑历史，不再感染新生儿）。
const DEFAULT_STATS := {
	"health_max": 100.0,
	"mana_max": 100.0,
	"knockout_resistance_max": 600.0,
	"move_speed": 600.0,
	"walk_speed": 300.0,
	"air_control": 0.6,
	"jump_force": -1200.0,
	"knockback_weight": 1.0,
	"hit_lane_offset": 0.0,
	"can_be_grabbed": false,
	"is_invulnerable": false,
	"has_superarmor": false,
	"parry_window_frames": 6.0,
	"block_damage_ratio": 0.4,
	"attack_output": 1.0,
}

## 招式槽表（文件名固定，与皮肤场景 ext_resource 引用对齐；
## 默认值=旧 chen 快照演示值的等值搬运）。
const DEFAULT_ATTACKS := [
	{"file": "punch1", "attack_damage": 10.0, "hurt_type": 1, "knock_strength": 60.0, "launch_angle": 15.0},
	{"file": "punch2", "attack_damage": 15.0, "hurt_type": 1, "knock_strength": 60.0, "launch_angle": 30.0},
	{"file": "punch3", "attack_damage": 30.0, "hurt_type": 0, "knock_strength": 1200.0, "launch_angle": 30.0},
	{"file": "air_kick", "attack_damage": 20.0, "hurt_type": 1, "knock_strength": 1200.0, "launch_angle": 45.0},
]

# 不随模板复制的触发器件
const EXCLUDED_FILES = [
	"character_template.tscn",
	"character_template.gd",
	"create_character.sh",
	"README.md",
]


## 纯 snake_case 判定（widget 联动默认值用）
static func _validate_snake_static(text: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[a-z][a-z0-9_]*$")
	return regex.search(text) != null


## 解析阵营标签串（逗号分隔，snake_case，去重保序）；非法返回空数组。
static func parse_faction_tags(raw: String) -> Array[String]:
	var out: Array[String] = []
	var regex := RegEx.new()
	regex.compile("^[a-z][a-z0-9_]*$")
	for piece in raw.split(","):
		var tag := piece.strip_edges()
		if tag.is_empty() or out.has(tag):
			continue
		if regex.search(tag) == null:
			return []
		out.append(tag)
	return out


## 出生属性补全：只覆盖已知键，未知键忽略（面板新增字段时的宽容契约）。
static func merged_stats(partial: Dictionary) -> Dictionary:
	var out := DEFAULT_STATS.duplicate(true)
	for key in partial.keys():
		if out.has(key):
			out[key] = partial[key]
	return out


## 从模板创建新角色；成功返回 true。
## 阵营新体系（2026-09-17 单一存放点定档）：faction_tags=逗号分隔阵营标签，
## 写入根节点 groups=["area2d:<标签>"]（唯一落点；战斗盒由角色 _ready 运行时
## 下发，皮肤场景不存阵营数据）。输出目录与行为档由控制方式决定，与标签解耦。
## stats/attacks 为出生数值覆盖表（缺省=DEFAULT_STATS/DEFAULT_ATTACKS）。
func create_character(
	char_name: String,
	pascal_name: String,
	display_name: String,
	faction_tags: String = "player",
	stats: Dictionary = {},
	attacks: Array = [],
	control_mode: int = ControlMode.PLAYER_INPUT
) -> bool:
	var tags := parse_faction_tags(faction_tags)
	if tags.is_empty():
		push_error("Invalid faction tags: '%s'（需逗号分隔的 snake_case 标签，至少一个）" % faction_tags)
		return false
	var layout := resolve_layout(control_mode)

	var target_dir := CHARACTERS_ROOT.path_join(layout.pkg).path_join(char_name)
	var tokens := {
		TOKEN_NAME: char_name,
		TOKEN_CLASS: pascal_name,
		TOKEN_DISPLAY: display_name,
		TOKEN_FACTION: tags[0],
		TOKEN_PKG: layout.pkg,
		TOKEN_BEHAVIOR_MODE: str(layout.behavior_mode),
	}
	if not TemplateCloner.clone_from_template(
			TEMPLATE_DIR, target_dir, tokens, EXCLUDED_FILES,
			TOKEN_NAME, PackedStringArray(["resources/attacks"]), "角色创建"):
		return false
	if tags.size() > 1 and not _expand_faction_root(target_dir.path_join(char_name + ".tscn"), tags):
		return false
	if not _synthesize_attributes(target_dir, layout.pkg, char_name, display_name, stats):
		return false
	if not _synthesize_attacks(target_dir, attacks):
		return false
	print_rich("[color=green]✓ Character created: %s (%s) at %s[/color]" % [display_name, char_name, target_dir])
	return true


## 全量合成 <name>_attributes.tres（出生属性全字段逐行落盘=最大透明度；
## （原"13 行"计数随盾反批 +3 受管字段过时，改全字段措辞防再腐）
## 文件引用走包内固定路径，头像/渐变演示资产由模板复制而来必然在位）。
func _synthesize_attributes(
		target_dir: String, pkg: String, char_name: String,
		display_name: String, stats: Dictionary) -> bool:
	var s := merged_stats(stats)
	var res := target_dir.path_join("resources")
	var text := "" \
			+ "[gd_resource type=\"Resource\" script_class=\"QuiverAttributes\" format=3]\n\n" \
			+ "[ext_resource type=\"Script\" path=\"res://addons/quiver.beat_em_up/characters/quiver_attributes.gd\" id=\"1_script\"]\n" \
			+ ("[ext_resource type=\"Texture2D\" path=\"res://characters/%s/%s/resources/%s_gradient.tres\" id=\"2_gradient\"]\n" % [pkg, char_name, char_name]) \
			+ ("[ext_resource type=\"Texture2D\" path=\"res://characters/%s/%s/resources/sprites/%s_profile.png\" id=\"3_profile\"]\n\n" % [pkg, char_name, char_name]) \
			+ "[resource]\n" \
			+ "script = ExtResource(\"1_script\")\n" \
			+ "display_name = \"%s\"\n" % display_name \
			+ "profile_texture = ExtResource(\"3_profile\")\n" \
			+ "life_bar_gradient = ExtResource(\"2_gradient\")\n" \
			+ "health_max = %s\n" % _num(s.health_max) \
			+ "mana_max = %s\n" % _num(s.mana_max) \
			+ "knockout_resistance_max = %s\n" % _num(s.knockout_resistance_max) \
			+ "move_speed = %s\n" % _num(s.move_speed) \
			+ "walk_speed = %s\n" % _num(s.walk_speed) \
			+ "air_control = %s\n" % _num(s.air_control) \
			+ "jump_force = %s\n" % _num(s.jump_force) \
			+ "knockback_weight = %s\n" % _num(s.knockback_weight) \
			+ "hit_lane_offset = %s\n" % _num(s.hit_lane_offset) \
			+ "can_be_grabbed = %s\n" % ("true" if s.can_be_grabbed else "false") \
			+ "is_invulnerable = %s\n" % ("true" if s.is_invulnerable else "false") \
			+ "has_superarmor = %s\n" % ("true" if s.has_superarmor else "false") \
			+ "parry_window_frames = %s\n" % _num(s.parry_window_frames) \
			+ "block_damage_ratio = %s\n" % _num(s.block_damage_ratio) \
			+ "attack_output = %s\n" % _num(s.attack_output)
	return _write_text(res.path_join(char_name + "_attributes.tres"), text, "attributes 合成")


## 全量合成四张招式 attack_data.tres（槽序=DEFAULT_ATTACKS 序；越界/缺省槽用默认）。
func _synthesize_attacks(target_dir: String, attacks: Array) -> bool:
	var dir := target_dir.path_join("resources/attacks")
	for i in DEFAULT_ATTACKS.size():
		var base: Dictionary = DEFAULT_ATTACKS[i]
		var given: Dictionary = attacks[i] if i < attacks.size() and attacks[i] is Dictionary else {}
		var text := "" \
				+ "[gd_resource type=\"Resource\" script_class=\"QuiverAttackData\" format=3]\n\n" \
				+ "[ext_resource type=\"Script\" path=\"res://addons/quiver.beat_em_up/combat/quiver_attack_data.gd\" id=\"1_script\"]\n\n" \
				+ "[resource]\n" \
				+ "script = ExtResource(\"1_script\")\n" \
				+ "attack_damage = %s\n" % _num(given.get("attack_damage", base.attack_damage)) \
				+ "hurt_type = %d\n" % int(given.get("hurt_type", base.hurt_type)) \
				+ "knock_strength = %s\n" % _num(given.get("knock_strength", base.knock_strength)) \
				+ "launch_angle = %s\n" % _num(given.get("launch_angle", base.launch_angle))
		if not _write_text(dir.path_join("%s_attack_data.tres" % base.file), text,
				"招式 %s 合成" % base.file):
			return false
	return true


## 数值文本：整数值省掉 ".0" 尾巴（与编辑器写盘形态一致），bool 由调用处处理。
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


## 多标签展开：根节点行 groups=["area2d:<首标签>"] → 逗号并列全部标签
func _expand_faction_root(main_tscn: String, tags: Array[String]) -> bool:
	var f := FileAccess.open(main_tscn, FileAccess.READ)
	if f == null:
		push_error("无法读取主场景以展开阵营标签: %s" % main_tscn)
		return false
	var text := f.get_as_text()
	f.close()
	var single := 'groups=["area2d:%s"]' % tags[0]
	if not text.contains(single):
		push_error("主场景未找到阵营占位落地行（模板注入链疑似回退）: %s" % main_tscn)
		return false
	var parts: Array[String] = []
	for t in tags:
		parts.append('"area2d:%s"' % t)
	# 根节点行全文件唯一（模板注入断言保证），整串替换安全
	text = text.replace(single, "groups=[%s]" % ", ".join(parts))
	f = FileAccess.open(main_tscn, FileAccess.WRITE)
	if f == null:
		push_error("无法写回主场景阵营标签: %s" % main_tscn)
		return false
	f.store_string(text)
	f.close()
	return true


## 控制方式 → 输出布局（阵营包目录 / 行为档）。目录归属与阵营标签彻底解耦：
## 玩家→playable、AI→enemies、被动→neutrals（需要挪目录属组织偏好，创建后
## 移动文件夹即可——git/重名扫描都按目录现况走）。
static func resolve_layout(control_mode: int) -> Dictionary:
	match control_mode:
		ControlMode.PLAYER_INPUT:
			return {"pkg": "playable", "behavior_mode": 0}
		ControlMode.AI_POLICY:
			return {"pkg": "enemies", "behavior_mode": 1}
		ControlMode.PASSIVE:
			return {"pkg": "neutrals", "behavior_mode": 2}
	return {}
