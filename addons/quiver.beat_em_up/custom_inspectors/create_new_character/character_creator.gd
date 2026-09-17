@tool
extends RefCounted
class_name CharacterCreator
## 角色创建器：解析控制方式×阵营布局 → 组装 token → 交给共享克隆引擎
## （_shared/template_cloner.gd，2026-09-17 产线合流；本文件只留角色线知识：
## 布局规则、token 语义、排除名单）。

const TemplateCloner := preload("res://addons/quiver.beat_em_up/custom_inspectors/_shared/template_cloner.gd")

const TEMPLATE_DIR = "res://templates/character/"
const CHARACTERS_ROOT = "res://characters/"

# 控制方式（与 QuiverCharacter.BehaviorMode 数值一致）
enum ControlMode { PLAYER_INPUT = 0, AI_POLICY = 1, PASSIVE = 2 }

# 模板文件里的占位 token
const TOKEN_NAME = "__NAME__"
const TOKEN_CLASS = "__CLASS__"
const TOKEN_DISPLAY = "__DISPLAY_NAME__"
const TOKEN_FACTION = "__FACTION__"            # 阵营标签（area2d:<标签> 的唯一存放点=根节点）
const TOKEN_PKG = "__PKG__"                    # 阵营包目录（playable/enemies/allies/neutrals）
const TOKEN_BEHAVIOR_MODE = "__BEHAVIOR_MODE__"  # 行为档 0/1/2
const TOKEN_MOVE_SPEED = "__MOVE_SPEED__"
const TOKEN_WALK_SPEED = "__WALK_SPEED__"
const TOKEN_HEALTH_MAX = "__HEALTH_MAX__"
const TOKEN_AIR_CONTROL = "__AIR_CONTROL__"
const TOKEN_HIT_LANE_OFFSET = "__HIT_LANE_OFFSET__"

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


## 从模板创建新角色；成功返回 true。
## 阵营新体系（2026-09-17 单一存放点定档）：faction_tags=逗号分隔阵营标签，
## 写入根节点 groups=["area2d:<标签>"]（唯一落点；战斗盒由角色 _ready 运行时
## 下发，皮肤场景不存阵营数据）。输出目录与行为档由控制方式决定，与标签解耦。
func create_character(
	char_name: String,
	pascal_name: String,
	display_name: String,
	faction_tags: String = "player",
	move_speed: float = 600.0,
	walk_speed: float = 300.0,
	health_max: int = 100,
	air_control: float = 0.6,
	hit_lane_offset: int = 0,
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
		TOKEN_MOVE_SPEED: str(move_speed),
		TOKEN_WALK_SPEED: str(walk_speed),
		TOKEN_HEALTH_MAX: str(health_max),
		TOKEN_AIR_CONTROL: str(air_control),
		TOKEN_HIT_LANE_OFFSET: str(hit_lane_offset),
	}
	if not TemplateCloner.clone_from_template(
			TEMPLATE_DIR, target_dir, tokens, EXCLUDED_FILES,
			TOKEN_NAME, PackedStringArray(), "角色创建"):
		return false
	if tags.size() > 1 and not _expand_faction_root(target_dir.path_join(char_name + ".tscn"), tags):
		return false
	print_rich("[color=green]✓ Character created: %s (%s) at %s[/color]" % [display_name, char_name, target_dir])
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
