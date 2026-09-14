class_name QuiverRunTestSceneBuilder
extends RefCounted

## Run Test 场景生成的纯字符串逻辑（无编辑器依赖，可被 headless 断言直接测试）。
##
## 编排规则（单壳行为档，2026-09-14）：
## [br]· 被测者=玩家档 → 它是主角；场景注入默认对手 spar_enemy（AI 自动靠近攻击，
##   给玩家角色当陪练），不存在则空场景
## [br]· 被测者=非玩家档 → 主角固定 chen，被测者作为对手实例注入
##   （AI 档自动追打 chen = 天然验收；被动档站桩挨打）
## 生成物模板本身不再内置任何敌人；旧 enemy 块剥离逻辑保留为保险丝。

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
	return out


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


## 通用注入：ext_resource 插到首个 [sub_resource/[node 之前，节点追加到文件末尾
static func inject_actor(
		content: String, actor_path: String, node_name: String, at: Vector2) -> String:
	var actor_ext := "[ext_resource type=\"PackedScene\" path=\"%s\" id=\"99_%s\"]" % [
			actor_path, node_name.to_lower()]
	var insert_at := content.find("[sub_resource")
	if insert_at == -1:
		insert_at = content.find("[node")
	var out := content.left(insert_at) + actor_ext + "\n\n" + content.substr(insert_at)
	out += "\n[node name=\"%s\" parent=\".\" instance=ExtResource(\"99_%s\")]\n" % [
			node_name, node_name.to_lower()]
	out += "position = Vector2(%f, %f)\n" % [at.x, at.y]
	return out
