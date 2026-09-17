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
	out = ensure_game_hud(out)
	return out


## 发令台（Enter 控制 AI 待命/进攻）统一注入：所有 Run Test 场景共用同一编排，
## 场景种类不再各自硬编码（曾漏掉法术测试场景导致被测角色被陪练白打死）。
## 正式 HUD 统一注入：跟随 players 组自动锁定被操作角色（角色切换系统零改动跟手）。
static func ensure_game_hud(content: String) -> String:
	if content.contains("ui/game_hud.tscn"):
		return content
	var ext_line := "[ext_resource type=\"PackedScene\" path=\"res://ui/game_hud.tscn\" id=\"15_hud\"]"
	var insert_at := content.find("[sub_resource")
	if insert_at == -1:
		insert_at = content.find("[node")
	content = content.left(insert_at) + ext_line + "\n\n" + content.substr(insert_at)
	return content + "\n[node name=\"GameHUD\" parent=\".\" instance=ExtResource(\"15_hud\")]\n"


static func ensure_conductor(content: String) -> String:
	if content.contains("test_scene_ai_conductor.gd"):
		return content
	var ext_line := "[ext_resource type=\"Script\" path=\"res://scripts/test_scene_ai_conductor.gd\" id=\"14_conductor\"]"
	var insert_at := content.find("[sub_resource")
	if insert_at == -1:
		insert_at = content.find("[node")
	content = content.left(insert_at) + ext_line + "\n\n" + content.substr(insert_at)
	return content + ("\n[node name=\"AIConductor\" type=\"Node\" parent=\".\"]\nscript = ExtResource(\"14_conductor\")\n"
			+ "\n[node name=\"DebugDockOpen\" type=\"Node\" parent=\".\" groups=[\"debug_dock_default_open\"]]\n")


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


## Run Test 场景底版（角色测试与法术测试共用唯一真相，2026-09-15 产线统一迁入）。
## 2.5D 碰撞约束：所有物理碰撞用 CapsuleShape2D（radius=20）旋转 90° 水平放置，
## 物体底部贴 ground_level 线（Y=500，position.y=480 因半径 20），地面仅可视化。
## tokens：{{CHAR_PATH}}（主角场景）、{{CHAR_NAME}}（显示名）。
## 法术侧差异一律走 add_spell_test_kit()，禁止复制第二份底版（历史上两份模板
## 漂移出"发令台漏装/数据窗口缺席"等多起事故）。
## 法术 Run Test 场景统一生成入口（2026-09-17 自愈改造）：编辑器插件与
## headless 测试共用——测试不再依赖 Windows 遗留生成物，读前先 ensure。
## 返回 {"path": 场景路径, "changed": 是否写盘}
static func ensure_spell_run_test(spell_name: String, char_name: String = "chen") -> Dictionary:
	var test_scene_path := "res://test_scenes/_test_spell_" + spell_name + ".tscn"
	var character_scene_path := "res://characters/playable/" + char_name + "/" + char_name + ".tscn"
	var spell_definition_path := "res://spells/" + spell_name + "/resources/" + spell_name + "_definition.tres"
	var spell_scene_path := "res://spells/" + spell_name + "/" + spell_name + ".tscn"
	var helper_script_path := "res://test_scenes/_test_spell_helper_" + spell_name + ".gd"
	if not DirAccess.dir_exists_absolute("res://test_scenes"):
		DirAccess.make_dir_recursive_absolute("res://test_scenes")
	var helper_written := write_if_changed(helper_script_path, spell_helper_text(spell_name, spell_definition_path, spell_scene_path))
	var test_scene_content := base_scene_text() \
			.replace("{{CHAR_PATH}}", character_scene_path) \
			.replace("{{CHAR_NAME}}", char_name)
	test_scene_content = add_spell_test_kit(test_scene_content, spell_name, helper_script_path)
	var subject_mode := scene_behavior_mode(character_scene_path)
	test_scene_content = compose(test_scene_content, character_scene_path, subject_mode)
	var scene_written := write_if_changed(test_scene_path, test_scene_content)
	return {"path": test_scene_path, "changed": helper_written or scene_written}


static func spell_helper_text(spell_name: String, spell_definition_path: String, spell_scene_path: String) -> String:
	var content := HELPER_SCRIPT_TEMPLATE \
			.replace("{{SPELL_DEF_PATH}}", spell_definition_path) \
			.replace("{{SPELL_SCENE_PATH}}", spell_scene_path)
	return content


const HELPER_SCRIPT_TEMPLATE := """extends Node

## 法术注入脚本（测试场景生成物）：唯一职责是把被测法术教给被测角色本人；
## 按键轮询/扣蓝/冷却/施法全部由角色壳自己的既有链路统一负责。
## 历史教训（2026-09）：私有输入通道的按键边沿"读一次即消费"，且父节点
## （角色壳）先于子节点轮询——助手若自建管理器自听键，永远抢不到按键。

var _taught := false

func _ready():
	# 子节点 _ready 早于父节点，而角色壳的法术管理器要到父 _ready 才创建
	# → 延后一帧再教。
	call_deferred("_teach")

func _teach():
	var host = get_parent()
	if not host.has_method("learn_spell"):
		push_error("[SpellTest] 宿主角色缺少 learn_spell，无法注入")
		return
	var spell_def: SpellDefinition = load("{{SPELL_DEF_PATH}}")
	spell_def.spell_scene = load("{{SPELL_SCENE_PATH}}")
	_taught = host.learn_spell(spell_def)
	if not _taught:
		push_error("[SpellTest] 法术注入失败（手册已满或定义加载失败）")
"""


static func write_if_changed(path: String, text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f != null:
		var old := f.get_as_text()
		f.close()
		if old == text:
			return false
	var w := FileAccess.open(path, FileAccess.WRITE)
	if w == null:
		push_error("无法写出生成物: %s" % path)
		return false
	w.store_string(text)
	w.close()
	return true


static func base_scene_text() -> String:
	return """[gd_scene load_steps=19 format=3]

[ext_resource type="PackedScene" path="{{CHAR_PATH}}" id="1_character"]
[ext_resource type="PackedScene" path="res://addons/quiver.beat_em_up/utilities/custom_nodes/level_camera/quiver_level_camera.tscn" id="2_camera"]
[ext_resource type="Script" path="res://scripts/debug_height_overlay.gd" id="3_debug_overlay"]
[ext_resource type="Script" path="res://scripts/debug_background.gd" id="9_debug_bg"]
[ext_resource type="Script" path="res://scripts/day_night/day_night_controller.gd" id="10_day_night_ctrl"]
[ext_resource type="Script" path="res://scripts/debug_day_night_input.gd" id="11_debug_dn_input"]
[ext_resource type="Script" path="res://scripts/day_night/scene_time_data.gd" id="12_scene_time_data"]
[ext_resource type="Script" path="res://scripts/shadow_region.gd" id="13_shadow_region"]

[sub_resource type="CapsuleShape2D" id="short_wall_shape"]
radius = 20.0
height = 60.0

[sub_resource type="CapsuleShape2D" id="tall_wall_shape"]
radius = 20.0
height = 60.0

[sub_resource type="CapsuleShape2D" id="platform_shape"]
radius = 20.0
height = 300.0

[sub_resource type="RectangleShape2D" id="ground_shape"]
size = Vector2(8000, 200)

[sub_resource type="Resource" id="SceneTimeData_test"]
script = ExtResource("12_scene_time_data")

[sub_resource type="Gradient" id="Gradient_lantern"]
colors = PackedColorArray(1, 0.8, 0.4, 1, 1, 0.5, 0.2, 0)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_lantern"]
gradient = SubResource("Gradient_lantern")
width = 256
height = 256
fill = 1
fill_from = Vector2(0.5, 0.5)
fill_to = Vector2(0.5, 0)

[node name="TestStage" type="Node2D"]

[node name="Background" type="CanvasLayer" parent="."]
script = ExtResource("9_debug_bg")

[node name="Ground" type="StaticBody2D" parent="."]
position = Vector2(2000, 600)
collision_layer = 16384

[node name="CollisionShape2D" type="CollisionShape2D" parent="Ground"]
shape = SubResource("ground_shape")

[node name="Character" parent="." instance=ExtResource("1_character")]
position = Vector2(200, 480)

[node name="LevelCamera" parent="Character" instance=ExtResource("2_camera")]
offset = Vector2(0, -80)
zoom = Vector2(0.85, 0.85)
limit_left = 0
limit_top = -500
limit_right = 6000
limit_bottom = 1000

[node name="ShortWall" type="StaticBody2D" parent="."]
position = Vector2(1000, 480)
collision_layer = 16384

[node name="CollisionShape2D" type="CollisionShape2D" parent="ShortWall"]
rotation = 1.5708
shape = SubResource("short_wall_shape")

[node name="Visual" type="ColorRect" parent="ShortWall"]
offset_left = -30.0
offset_top = -140.0
offset_right = 30.0
offset_bottom = 20.0
color = Color(0.8, 0.6, 0.3, 1)

[node name="Label" type="Label" parent="ShortWall"]
offset_left = -40.0
offset_top = -100.0
offset_right = 40.0
offset_bottom = -80.0
text = "矮墙 160px"
horizontal_alignment = 1

[node name="TallWall" type="StaticBody2D" parent="."]
position = Vector2(2400, 480)
collision_layer = 16760832

[node name="CollisionShape2D" type="CollisionShape2D" parent="TallWall"]
rotation = 1.5708
shape = SubResource("tall_wall_shape")

[node name="Visual" type="ColorRect" parent="TallWall"]
offset_left = -30.0
offset_top = -380.0
offset_right = 30.0
offset_bottom = 20.0
color = Color(0.7, 0.3, 0.3, 1)

[node name="Label" type="Label" parent="TallWall"]
offset_left = -40.0
offset_top = -220.0
offset_right = 40.0
offset_bottom = -200.0
text = "高墙 400px"
horizontal_alignment = 1

[node name="Platform" type="StaticBody2D" parent="."]
position = Vector2(1700, 480)
collision_layer = 262144

[node name="CollisionShape2D" type="CollisionShape2D" parent="Platform"]
rotation = 1.5708
shape = SubResource("platform_shape")

[node name="Visual" type="ColorRect" parent="Platform"]
offset_left = -150.0
offset_top = -20.0
offset_right = 150.0
offset_bottom = 20.0
color = Color(0.3, 0.7, 0.5, 1)

[node name="Label" type="Label" parent="Platform"]
offset_left = -60.0
offset_top = -40.0
offset_right = 60.0
offset_bottom = -20.0
text = "悬空平台"
horizontal_alignment = 1

[node name="DebugLabel" type="Label" parent="."]
visible = false
offset_left = 10.0
offset_top = 270.0
offset_right = 500.0
offset_bottom = 510.0
text = "=== 2.5D 高度层 + 昼夜测试 ===

操作: WASD 移动, Space 跳跃, J 攻击\n1-4 法术(已学) | 5-8 昼夜相位 | O 光照覆盖 | Enter 敌人进攻

高度层测试:
1. 跳跃穿过矮墙 (160px)
2. 钻过悬空平台
3. 撞击高墙 (400px)
4. 攻击敌人 / 被敌人攻击

昼夜测试:
5/6/7/8 → 切换 DAWN/DAY/DUSK/NIGHT
O → 应用 3 秒光照覆盖（Boss 战变暗）

阴影测试:
L → 开/关软边(P2)
T → 开/关阴影区域(绿框)
走出绿框边界: 阴影被裁剪 / 出界无影

观察: 角色阴影方向平滑过渡, 灯笼 DUSK/NIGHT 点亮

AI 发令: Enter → 敌人开始行动/暂停（摆位复测用）"

[node name="CanvasModulate" type="CanvasModulate" parent="."]

[node name="DirectionalLight2D" type="DirectionalLight2D" parent="."]
shadow/enabled = false
rotation = -0.7853982

[node name="DayNightController" type="Node" parent="."]
script = ExtResource("10_day_night_ctrl")
scene_time_data = SubResource("SceneTimeData_test")
canvas_modulate_path = NodePath("../CanvasModulate")
directional_light_path = NodePath("../DirectionalLight2D")
point_lights_paths = Array[NodePath]([NodePath("../Lantern1"), NodePath("../Lantern2")])

[node name="Lantern1" type="PointLight2D" parent="."]
position = Vector2(400, 280)
scale = Vector2(2, 2)
enabled = false
color = Color(1, 0.8, 0.5, 1)
energy = 0.8
texture = SubResource("GradientTexture2D_lantern")

[node name="Lantern2" type="PointLight2D" parent="."]
position = Vector2(1600, 280)
scale = Vector2(2, 2)
enabled = false
color = Color(1, 0.8, 0.5, 1)
energy = 0.8
texture = SubResource("GradientTexture2D_lantern")

[node name="DebugDayNightInput" type="Node" parent="."]
script = ExtResource("11_debug_dn_input")

[node name="DebugHeightOverlay" type="CanvasLayer" parent="."]
script = ExtResource("3_debug_overlay")
character_path = NodePath("../Character")

[node name="ShadowRegion" type="ReferenceRect" parent="."]
script = ExtResource("13_shadow_region")
position = Vector2(50, 400)
size = Vector2(900, 300)
debug_preview = true

"""


## 法术测试套件：底版之上只做三件事——
##  1) 挂"法术注入脚本"节点（教 slot1 被测法术）+ 法术调试面板（左上角大面板）；
##  2) 两个数据窗口让位到屏幕右列（x=845，宽 300），避让 820 宽的法术面板；
##  3) 帮助文本标注被测法术。
## 其余部件（昼夜/墙台/灯笼/阴影/发令台/相机）与角色测试场景**完全同源**。
static func add_spell_test_kit(content: String, spell_name: String, helper_script_path: String) -> String:
	var out := content
	# ext 区追加（插到首个 sub_resource/node 之前，与 inject_actor 同规则）
	var ext_lines := "[ext_resource type=\"Script\" path=\"" + helper_script_path + "\" id=\"5_test_helper\"]\n\n"
	var insert_at := out.find("[sub_resource")
	if insert_at == -1:
		insert_at = out.find("[node")
	out = out.left(insert_at) + ext_lines + out.substr(insert_at)
	# load_steps 同步 +1（helper；旧法术诊断面板已迁入 DebugDock，不再注入）
	var rx := RegEx.new()
	rx.compile("(?m)^\\[gd_scene load_steps=(\\d+)")
	var m := rx.search(out)
	if m != null:
		out = out.replace(m.get_string(0), "[gd_scene load_steps=%d" % (int(m.get_string(1)) + 1))
	# helper 节点：插到被测角色（Character）块尾、LevelCamera 之前
	var anchor := "position = Vector2(200, 480)\n\n[node name=\"LevelCamera\""
	assert(out.contains(anchor))
	out = out.replace(anchor,
			"position = Vector2(200, 480)\n\n"
			+ "[node name=\"TestSpellHelper\" type=\"Node\" parent=\"Character\"]\n"
			+ "script = ExtResource(\"5_test_helper\")\n\n"
			+ "[node name=\"LevelCamera\"")
	# （旧文字诊断面板与右列避让已废：文字入 DebugDock 拉取制，
	# 高度层竖条按视口坐标自排，不再需要面板参数）
	# 帮助文本：标题与被测法术键位
	out = out.replace("=== 2.5D 高度层 + 昼夜测试 ===",
			"=== 法术测试: " + spell_name + "（角色底版 + slot1 注入） ===")
	out = out.replace("1-4 法术(已学)", "1-4 法术(槽1=被测法术)")
	return out
