class_name QuiverRunTestSceneBuilder
extends RefCounted

## Run Test 场景生成的纯字符串逻辑（无编辑器依赖，可被 headless 断言直接测试）。
##
## 编排规则（单壳行为档，2026-09-14）：
## [br]· 被测者=玩家档 → 它是主角；场景注入默认对手 spar_enemy（AI 自动靠近攻击，
##   给玩家角色当陪练），不存在则空场景
## [br]· 被测者=非玩家档 → 主角固定 chen，被测者作为对手实例注入
##   （AI 自动追打 chen = 天然验收；被动档站桩挨打），
##   且把两个调试数据窗口"显示谁"的设置改指被测者——测谁看谁
## 生成物模板本身不再内置任何敌人；旧 enemy 块剥离逻辑保留为保险丝。
## 注入的角色一律排在场景文件里调试窗口节点之前（对象引用装载顺序，见
## [method inject_actor] 注释）。

const CHEN_SCENE := "res://characters/playable/chen/chen.tscn"
const DEFAULT_OPPONENT := "res://characters/enemies/spar_enemy/spar_enemy.tscn"
const OLD_ENEMY_PATH := "res://characters/playable/enemy/"


## 从角色场景文件文本读取 behavior_mode 属性（缺失=0 玩家档）
static func scene_behavior_mode(scene_path: String) -> int:
	var text := FileAccess.get_file_as_string(scene_path)
	var regex := RegEx.new()
	regex.compile("behavior_mode = (\\d)")
	var match_result := regex.search(text)
	if match_result == null:
		return 0
	return int(match_result.get_string(1))


## 主角路径（玩家档=被测者自己；否则 chen）
static func hero_path_for(subject_path: String, subject_mode: int) -> String:
	return subject_path if subject_mode == 0 else CHEN_SCENE


## 完成 {{CHAR_PATH}} 替换后的统一编排
static func compose(content: String, subject_path: String, subject_mode: int) -> String:
	var out := strip_enemy_legacy(content)
	if subject_mode == 0:
		if FileAccess.file_exists(DEFAULT_OPPONENT):
			out = inject_actor(out, DEFAULT_OPPONENT, "Enemy", Vector2(522, 480))
	else:
		out = inject_actor(out, subject_path, "Subject", Vector2(522, 480))
		# 调试数据窗口（高度层/击倒）"显示谁"的设置跟着被测者走：
		# 此时主角位是 chen（操作锚），窗口若仍指它，显示的就是 chen 而非被测怪物
		out = out.replace("character_path = NodePath(\"../Character\")", \
				"character_path = NodePath(\"../Subject\")")
	out = ensure_conductor(out)
	return out


## 发令台（Enter 控制 AI 待命/进攻）统一注入：所有 Run Test 场景共用同一编排，
## 场景种类不再各自硬编码（曾漏掉法术测试场景导致被测角色被陪练白打死）。
static func ensure_conductor(content: String) -> String:
	if content.contains("test_scene_ai_conductor.gd"):
		return content
	var ext_line := "[ext_resource type=\"Script\" path=\"res://scripts/test_scene_ai_conductor.gd\" id=\"14_conductor\"]"
	var insert_at := content.find("[sub_resource")
	if insert_at == -1:
		insert_at = content.find("[node")
	content = content.left(insert_at) + ext_line + "\n\n" + content.substr(insert_at)
	return content + "\n[node name=\"AIConductor\" type=\"Node\" parent=\".\"]\nscript = ExtResource(\"14_conductor\")\n"


## 剥离旧 enemy（魔法替身）引用块：ext、专属 hack 脚本、节点与属性覆盖
static func strip_enemy_legacy(content: String) -> String:
	var kept: Array[String] = []
	var skip := false
	for line in content.split("\n"):
		if line.begins_with("[node ") or line.begins_with("[ext_resource") \
				or line.begins_with("[sub_resource"):
			skip = line.contains(OLD_ENEMY_PATH) \
					or line.begins_with('[node name="Enemy" parent=".') \
					or line.contains('parent="Enemy/EnemySkin/Attacks"') \
					or line.begins_with('[node name="PeriodicAttack"') \
					or line.begins_with('[node name="HurtHandler"')
		if not skip:
			kept.append(line)
	return "\n".join(kept)


## 通用注入：ext_resource 插到首个 [sub_resource/[node 之前；节点块插到第一个
## 调试窗口类节点之前（稳定排布约定，方便人读文件时先演员后道具）。
## 历史注记：曾怀疑"节点排在引用之后导致解析为空"，实为误诊——真因见
## debug_height_overlay.gd 头注（对象引用型导出不认文本赋值），已由
## "路径 + 运行时解析"方案根治，装载顺序不再有影响。
static func inject_actor(
		content: String, actor_path: String, node_name: String, at: Vector2) -> String:
	var actor_ext := "[ext_resource type=\"PackedScene\" path=\"%s\" id=\"99_%s\"]" % [
			actor_path, node_name.to_lower()]
	var insert_at := content.find("[sub_resource")
	if insert_at == -1:
		insert_at = content.find("[node")
	var out := content.left(insert_at) + actor_ext + "\n\n" + content.substr(insert_at)
	var actor_block := "[node name=\"%s\" parent=\".\" instance=ExtResource(\"99_%s\")]\n" % [
			node_name, node_name.to_lower()]
	actor_block += "position = Vector2(%f, %f)\n\n" % [at.x, at.y]
	var debug_pos := out.find("\n[node name=\"Debug")
	if debug_pos != -1:
		return out.left(debug_pos + 1) + actor_block + out.substr(debug_pos + 1)
	return out + "\n" + actor_block
