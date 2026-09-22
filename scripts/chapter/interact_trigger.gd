class_name InteractTrigger
extends Area2D

## 通用互动触发件（S2-M1-B2，法典第十条）：段内 E 键感应区。本件只管
## "谁在距、按没按 E、旗标门放行没、一次性消没消耗"，发射 interacted 信号即止；
## 反应件（宝箱/剧情/商店）是后续批的独立件，经订阅本信号 + consume() 收口。

signal interacted

@export var prompt_text := "互动"
@export var action: StringName = &"interact"
## false=一次性（首触即消耗）；true=可重复（受 cooldown 节流）
@export var repeatable := false
## 秒；仅 repeatable=true 有意义（Time.get_ticks_msec 墙钟比较）
@export var cooldown := 0.0
## 非空=旗标门：壳 session 无此旗时**静默拒发**（不吃键、不置消耗）
@export var requires_flag: StringName = &""

@onready var _prompt: Label = get_node_or_null("Prompt")

var _in_range := 0        # 玩家进出计数（>0=在距；同体多次 entered 理论不存在，防御性用计数）
var _consumed := false
var _last_fire_ms := 0


func _ready() -> void:
	# 检测器掩码配方（雷区 b 同款）：mask 全高度层（玩家身体动态持有）、
	# monitorable=false（不参与别人的 area 查询）；layer 由场景写 0
	collision_mask = QuiverCharacter.get_all_height_layers_mask()
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if _prompt:
		_prompt.text = prompt_text
		_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	# 判例（2026-09-15 盖戳案+Dialogic spike）：未处理输入流只收原始按键、
	# 合成动作事件永不到达；is_action_pressed 走默认 exact=false
	# （exact=true 会拒收 physical 匹配绑定但 keycode 通道不同的注入事件）
	if event.is_action_pressed(action):
		_try_interact()


func in_range() -> bool:
	return _in_range > 0


## 上溯祖先首个壳（旗标门读 session 用；段挂壳 Segments 下恒有，独立场地为 null）
func find_shell() -> ChapterShell:
	var p := get_parent()
	while p != null:
		if p is ChapterShell:
			return p
		p = p.get_parent()
	return null


## 反应侧显式消耗（宝箱开完调）：此后 E 永不再响应、Prompt 永久隐身
func consume() -> void:
	_consumed = true
	_refresh_prompt()


func _on_body_entered(body: Node2D) -> void:
	if body is QuiverCharacter and body.is_in_group("area2d:player"):
		_in_range += 1
		_refresh_prompt()


func _on_body_exited(body: Node2D) -> void:
	if body is QuiverCharacter and body.is_in_group("area2d:player"):
		_in_range = maxi(_in_range - 1, 0)
		_refresh_prompt()


func _try_interact() -> void:
	if _consumed or not in_range():
		return
	if requires_flag != &"":
		var shell := find_shell()
		if shell == null or not shell.session.has_flag(requires_flag):
			return   # 静默拒发（法典第十条：旗标门经壳 session）
	if repeatable:
		var now := Time.get_ticks_msec()
		if cooldown > 0.0 and now - _last_fire_ms < int(cooldown * 1000.0):
			return
		_last_fire_ms = now
	else:
		_consumed = true
	_refresh_prompt()
	interacted.emit()


func _refresh_prompt() -> void:
	if _prompt:
		_prompt.visible = in_range() and not _consumed
