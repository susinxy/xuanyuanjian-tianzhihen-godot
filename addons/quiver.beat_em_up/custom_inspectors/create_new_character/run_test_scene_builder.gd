class_name QuiverRunTestSceneBuilder
extends RefCounted

## Run Test 场景生成的纯字符串逻辑（无编辑器依赖，可被 headless 断言直接测试）。

const CHEN_SCENE := "res://characters/playable/chen/chen.tscn"
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


## 主角换成 chen 时需要的路径
static func hero_path_for(subject_path: String, subject_mode: int) -> String:
	return subject_path if subject_mode == 0 else CHEN_SCENE


## 非玩家被测者接入：剥离旧 enemy 引用块，注入被测角色实例。
## 按节（[node/[ext_resource/[sub_resource 头行起、下一头行止）整块跳过/保留。
static func attach_nonplayer_subject(content: String, subject_path: String) -> String:
	var kept: Array[String] = []
	var skip := false
	for line in content.split("\n"):
		if line.begins_with("[node ") or line.begins_with("[ext_resource") \
				or line.begins_with("[sub_resource"):
			skip = line.contains(OLD_ENEMY_PATH) \
					or line.begins_with('[node name="Enemy" parent=".') \
					or line.contains('parent="Enemy/EnemySkin/Attacks"') \
					or line.begins_with('[node name="PeriodicAttack"')
		if not skip:
			kept.append(line)
	var out := "\n".join(kept)
	
	# 被测者 ext_resource 插到第一个 [sub_resource（或首个 [node）之前
	var subject_ext := "[ext_resource type=\"PackedScene\" path=\"%s\" id=\"99_subject\"]" % subject_path
	var insert_at := out.find("[sub_resource")
	if insert_at == -1:
		insert_at = out.find("[node")
	out = out.left(insert_at) + subject_ext + "\n\n" + out.substr(insert_at)
	
	# 被测者节点追加到场景末尾（AI 档会自动走向主角 chen）
	out += "\n[node name=\"Subject\" parent=\".\" instance=ExtResource(\"99_subject\")]\n" \
			+ "position = Vector2(522, 480)\n"
	return out
