class_name InteractChest
extends InteractReaction

## 宝箱反应件（S2-M1-B2 C 组，法典第十条⑤）：挂 InteractTrigger 子节点、
## _ready 订阅 interacted。判重单一真源在 session.open_chest（节点可被段丢弃
## 重建换新实例，二次开仍被 session 拦下）：首开→可选 grant 旗；无论首开与否
## 都显式 consume()（非重复触发件已在发射前自消耗，此处是⑤的收口仪式）并
## 0.4s 缩小消失→释放触发件（连带本件）。
##
## 账本 ns 常量取用（无 class_name 的 autoload 走 preload 脚本常量，InteractSpellBook
## 同款；不引用全局标识符 GameSave——-s/独立夹具环境编译期安全）
const _GameSaveScript := preload("res://scripts/save/game_save.gd")

## 申报单（spec §3 门三；B4-T3a 补，R-T2a）——三连问据实：
## 　Q1 游玩中会变吗？会：宝箱"已开/未开"随首次开启翻转、grants_flag 随首挂出现
## 　　→候选入册；
## 　Q2 不存能推导吗？不能：不记账则重演/换段回跳会**再吐一次宝、再挂一次旗**，
## 　　玩家不可接受（三连问③"重演不能接受"族）→必须入册。
## 　故 persists=[chests, flags]（flags 因 grants_flag 可写；grants_flag 是运行时
## 　值，申报按"件能产生的户"上报，无奖励旗的宝箱虽只碰 chests，仍并集报 flags）；
## 　resets=[]（本件无依赖的可重导账本户——空箱不再诱惑靠 chests 账，不靠重置）。
func save_claim() -> Dictionary:
	return {&"persists": [_GameSaveScript.NS_CHESTS, _GameSaveScript.NS_FLAGS], &"resets": []}


@export var chest_id: StringName = &""
## 非空=首开时向壳 session 补挂此旗（无奖励旗的宝箱留空）
@export var grants_flag: StringName = &""


func _ready() -> void:
	var trig := get_parent() as InteractTrigger
	if trig:
		trig.interacted.connect(_on_interacted)


func _on_interacted() -> void:
	var trig := get_parent() as InteractTrigger
	if trig == null or not is_instance_valid(trig):
		return
	var shell := trig.find_shell()
	if shell == null:
		return   # 无壳=无 session 判重主体，静默不反应（独立场地不成章）
	trig.consume()
	if shell.session.open_chest(chest_id):
		if grants_flag != &"":
			shell.session.add_flag(grants_flag)
	# 消失演出 0.4s（tween 绑触发件本体）：二次判定已由 session 兜底，
	# 释放节点只负责"空箱不再诱惑"的视觉与物理清算
	var tw := trig.create_tween()
	tw.tween_property(trig, "scale", Vector2.ZERO, 0.4)
	tw.tween_callback(trig.queue_free)
