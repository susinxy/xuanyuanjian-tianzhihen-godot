@tool
extends RefCounted
class_name CharacterCreator
## 角色创建器：解析控制方式×阵营布局 → 组装 token → 交给共享克隆引擎
## （_shared/template_cloner.gd，2026-09-17 产线合流；本文件只留角色线知识：
## 布局规则、token 语义、排除名单）。

const TemplateCloner := preload("res://addons/quiver.beat_em_up/custom_inspectors/_shared/template_cloner.gd")

const TEMPLATE_DIR = "res://templates/character/"
const CHARACTERS_ROOT = "res://characters/"
const BODY_GROUP_PLAYERS = "players"

# 控制方式（与 QuiverCharacter.BehaviorMode 数值一致）
enum ControlMode { PLAYER_INPUT = 0, AI_POLICY = 1, PASSIVE = 2 }

# 模板文件里的占位 token
const TOKEN_NAME = "__NAME__"
const TOKEN_CLASS = "__CLASS__"
const TOKEN_DISPLAY = "__DISPLAY_NAME__"
const TOKEN_FACTION = "__FACTION__"
const TOKEN_PKG = "__PKG__"                    # 阵营包目录（playable/enemies/allies/neutrals）
const TOKEN_BODY_GROUP = "__BODY_GROUP__"      # 根节点 body group（players/enemies/...）
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


## 从模板创建新角色；成功返回 true。
## 单壳架构（见 docs/PLUGIN_ARCHITECTURE.md 5.0）：控制方式决定行为档与输出
## 目录，阵营决定 body group 与阵营包目录。AI 档 v1 仅开放敌人阵营。
func create_character(
	char_name: String,
	pascal_name: String,
	display_name: String,
	faction: String = "players",
	move_speed: float = 600.0,
	walk_speed: float = 300.0,
	health_max: int = 100,
	air_control: float = 0.6,
	hit_lane_offset: int = 0,
	control_mode: int = ControlMode.PLAYER_INPUT
) -> bool:
	var layout := resolve_layout(control_mode, faction)
	if layout.is_empty():
		push_error("Invalid control_mode/faction combination: mode=%d faction=%s" % [
			control_mode, faction])
		return false

	var target_dir := CHARACTERS_ROOT.path_join(layout.pkg).path_join(char_name)
	var tokens := {
		TOKEN_NAME: char_name,
		TOKEN_CLASS: pascal_name,
		TOKEN_DISPLAY: display_name,
		TOKEN_FACTION: faction,
		TOKEN_PKG: layout.pkg,
		TOKEN_BODY_GROUP: layout.body_group,
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
	print_rich("[color=green]✓ Character created: %s (%s) at %s[/color]" % [display_name, char_name, target_dir])
	return true


## 控制方式×阵营 → 输出布局（阵营包目录 / body group / 行为档）。
## 非法组合返回空字典。玩家操控强制 players；AI 档 v1 仅敌人阵营
## （插件 AI 状态虽已退役，但策略小抄的追击目标写死"最近的玩家"，
## 友方 AI 的索敌参数化留待切片设计会立项）。
static func resolve_layout(control_mode: int, faction: String) -> Dictionary:
	var pkg := ""
	var body_group := ""
	var behavior_mode := 0
	match control_mode:
		ControlMode.PLAYER_INPUT:
			pkg = "playable"
			body_group = "players"
			behavior_mode = 0
		ControlMode.AI_POLICY:
			if faction != "enemies":
				return {}
			pkg = "enemies"
			body_group = "enemies"
			behavior_mode = 1
		ControlMode.PASSIVE:
			behavior_mode = 2
			match faction:
				"players":
					pkg = "playable"
					body_group = "players"
				"enemies", "allies", "neutrals":
					pkg = faction
					body_group = faction
				_:
					return {}
		_:
			return {}
	return {"pkg": pkg, "body_group": body_group, "behavior_mode": behavior_mode}
