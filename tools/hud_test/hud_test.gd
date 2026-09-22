extends Node

## GameHUD 契约测试（批 3）：players 组跟手/血蓝同步/名字头像/已学名/
## 冷却遮罩/目标消失自隐。
## 主权迁移（B2.5 Task4）：被测玩家从活体 chen 换成矩阵替身 test_actor；
## 名字断言随之改绑替身自身 display_name（HUD 契约验的是"名字=属性值"链路，
## 不是 chen 的姓名；头像断言同理吃替身自己的 profile_texture）。
## 运行：godot --headless --path . res://tools/hud_test/hud_test.tscn

const Kit := preload("res://tools/matrix_runner/test_actor_kit.gd")
const HUD := "res://ui/game_hud.tscn"
const FIRE_DEF := "res://spells/fire_ball/resources/fire_ball_definition.tres"
const FIRE_SCENE := "res://spells/fire_ball/fire_ball.tscn"

var _fails := 0
var _finished := false


func _ready() -> void:
	await _flow()
	_check(_finished, "全序列执行完成（协程静默中断防线）")
	print("════════ game-hud: %s ════════" % ("PASS" if _fails == 0 else "FAIL"))
	get_tree().quit(0 if _fails == 0 else 1)


## 解析器三链单元段：①icon 提供即优先 ②派生链非空 ③无链可派生 null 不崩
func _resolver_cases() -> void:
	var Resolver := load("res://ui/spell_icon_resolver.gd")
	var bare: SpellDefinition = (load(FIRE_DEF) as SpellDefinition).duplicate(true)
	bare.icon = null
	bare.spell_scene = load(FIRE_SCENE)
	_check(Resolver.icon_for(bare) != null, "resolver：②派生链非空")
	var fake := SpellDefinition.new()
	# 注：该 png 是 fire_ball 法术自己的素材（文件名恰含 chen 字样），非生产角色绑定
	fake.icon = load("res://spells/fire_ball/resources/sprites/chen_00001.png")
	_check(Resolver.icon_for(fake) == fake.icon, "resolver：①icon 提供即优先")
	var junk := SpellDefinition.new()
	junk.spell_scene = null
	_check(Resolver.icon_for(junk) == null, "resolver：③无链可派生 null 不崩")


func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails += 1
	print("  %s: %s" % ["PASS" if ok else "FAIL", label])


## 槽0 是否已回到"空槽数字态"（遗忘断言谓词；lambda 单行化避开解析雷）
func _slot0_empty(slots_row: HBoxContainer) -> bool:
	var p: Panel = slots_row.get_child(0)
	return (p.get_child(0) as TextureRect).texture == null \
			and p.tooltip_text == "" \
			and (p.get_child(1) as Label).text == "1"


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


## 上升沿观察（input_channel 同款孪生）：逐物理帧轮询 pred，命中即真；先判
## 后等=第 0 帧也算一次采样。HUD 每帧在 _process 重绘，而 _process 提交可能
## 晚于若干个物理 tick（矩阵通道实测：import 冷缓存下血条腿 2 物理帧瞬时抽查
## 读到旧绘值 100 假红）——"值终会同步"类断言一律观察化，不再押固定帧预算。
func _wait_until(pred: Callable, cap_frames: int) -> bool:
	for _i in cap_frames:
		if pred.call():
			return true
		await get_tree().physics_frame
	return pred.call()


## 头部三态守卫（input_channel 同款只读阶梯；缺席打可读红、绝不代 runner 创建）
func _guard_actor() -> bool:
	var remedy := "先跑 bash tools/matrix_runner/run_matrix.sh --ensure-only 建好 test_actor"
	if not Kit.exists():
		_check(false, "替身守卫：test_actor 缺席（%s）" % remedy)
		return false
	var rc := Kit.ensure()
	if rc == Kit.NEEDS_IMPORT:
		_check(false, "替身守卫：test_actor 在但本进程不可加载=NEEDS_IMPORT(42)（%s）" % remedy)
		return false
	if rc != OK:
		_check(false, "替身守卫：ensure() 报产线失败（rc=%d，诊断见上行）" % rc)
		return false
	print("ACTOR-GATE: test_actor 就绪（只读三态守卫通过）")
	return true


func _flow() -> void:
	if not _guard_actor():
		return
	var stage := Node2D.new()
	add_child(stage)
	var actor: QuiverCharacter = (load(Kit.ACTOR_SCENE) as PackedScene).instantiate()
	stage.add_child(actor)
	var hud := (load(HUD) as PackedScene).instantiate()
	stage.add_child(hud)
	# players 组由行为档延迟挂接（组注册晚于 _ready 若干物理帧）——等到跟手为止
	for _i in 90:
		await get_tree().physics_frame
		if hud._bound != null:
			break

	var frame := hud.get_node("Frame")
	var name_l: Label = hud.get_node("Frame/Row/Info/Name")
	var portrait: TextureRect = hud.get_node("Frame/Row/Portrait")
	var hp: ProgressBar = hud.get_node("Frame/Row/Info/Hp")
	var slots_row: HBoxContainer = hud.get_node("Frame/Row/Info/Slots")

	_check(frame.visible and not actor.attributes.display_name.strip_edges().is_empty()
			and name_l.text == actor.attributes.display_name.strip_edges(),
			"跟随 players 组：名字上屏=替身 display_name（%s）" % name_l.text)
	_check(portrait.texture != null, "头像自 attributes.profile_texture 上屏")
	_check(name_l.get_theme_color("font_color").v > 0.5, "HUD 名字浅色 override 在位")

	actor.attributes.health_current = 57.0
	# 观察帽 120 帧（≈2s 墙钟）= 一个完整冷却窗量级，远大于任何重绘迟到；
	# 同值后仍连续两帧复核由 _wait_until 的先判后等天然覆盖
	var hp_synced: bool = await _wait_until(
			func(): return is_equal_approx(hp.value, 57.0), 120)
	_check(hp_synced, "血条与属性同值（观察帽 120 帧，实=%.0f）" % hp.value)

	var def: SpellDefinition = (load(FIRE_DEF) as SpellDefinition).duplicate(true)
	def.cooldown = 5.0
	def.mana_cost = 0.0
	def.spell_scene = load(FIRE_SCENE)
	_check(actor.learn_spell(def), "学会冷却 5s 版火球")
	await _frames(2)
	var slot0: Panel = slots_row.get_child(0)
	var slot0_icon: TextureRect = slot0.get_child(0)
	var slot0_label: Label = slot0.get_child(1)
	_check(slot0_icon.texture != null, "无 icon 定义→派生 right 动画首帧上屏")
	_check(slot0_label.text == "1", "槽内键位角标数字（%s）" % slot0_label.text)
	_check(slot0.tooltip_text == "火球术", "显示名进 tooltip（%s）" % slot0.tooltip_text)

	actor.channel.press("spell_1")
	await _frames(80)
	var cover: ColorRect = (slots_row.get_child(0) as Panel).get_child(2)
	# 断言落几何（尺寸）不落锚点属性：锚点被改而矩形不动曾是隐身事故本故
	_check(cover.size.y > 25 and cover.size.y <= 57,
			"冷却遮罩真实下压（遮罩高 %.0f/槽 56）" % cover.size.y)

	# —— 可变性加固断言：遗忘即时性（拉取制核心承诺）——
	var sm = actor.get("_spell_manager")
	sm.forget_spell(0)
	# 拉取制即时性=观察式（下一枚 HUD 重绘必到位；120 帧帽同上推导）
	var forgot: bool = await _wait_until(
			func(): return _slot0_empty(slots_row), 120)
	var s0: Panel = slots_row.get_child(0)
	_check(forgot and (s0.get_child(0) as TextureRect).texture == null
			and s0.tooltip_text == ""
			and (s0.get_child(1) as Label).text == "1",
			"遗忘即时（观察帽 120 帧）：图标清/tooltip 空/回数字态")

	# —— 可变性加固断言：数量双向自校准（白盒改容量模拟未来扩容）——
	sm._slots.append(SpellSlot.new())
	var grew: bool = await _wait_until(
			func(): return slots_row.get_child_count() == sm.slot_count() and sm.slot_count() == 5,
			120)
	_check(grew,
			"扩容即时跟随（观察帽 120 帧）：HUD %d 格 = manager %d 格" % [slots_row.get_child_count(), sm.slot_count()])
	sm._slots.pop_back()
	var shrank: bool = await _wait_until(
			func(): return slots_row.get_child_count() == sm.slot_count() and sm.slot_count() == 4,
			120)
	_check(shrank,
			"缩容即时跟随（观察帽 120 帧）：HUD %d 格" % slots_row.get_child_count())

	actor.queue_free()
	await _frames(4)
	_check(not frame.visible, "players 组清空 → HUD 自隐")
	_resolver_cases()
	_finished = true
