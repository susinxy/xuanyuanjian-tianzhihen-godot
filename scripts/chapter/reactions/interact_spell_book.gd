class_name InteractSpellBook
extends InteractReaction

## 《秘籍》反应件（S2-B4，spec §4；家族第四型，chest 同门形制）：挂
## InteractTrigger 子节点、_ready 订阅 interacted。E 触发→对 GameSave 的
## spells_known 户记账（manual_id 空则回落 spell_id 作账本键；账值=spell_id，
## 键=拾得事件、值=教什么——B4.5-T4 值维立法）→**首开**即时
## 把 registry 解析出的定义教给 shell.playable（def 缺件=push_error 不炸链，
## 账已记=道具确被拾取，降级不吞事件）→无论首开与否 consume()+0.4s 缩小消失。
## **外观判重**（用户 F5 裁决 2026-09-25，_ready 腿）：账本有账=学会过，本件
## 出生帧连触发件整体退场——一次性知识件不重弹提示（与 chest"空箱物理语义"
## 分道：箱可再见只是不再吐宝，书见过即永别）。
## 与出生补学的分工：本件只管增量（拾取瞬间教当前实例），重建节点的学习
## 由玩家壳 _ready 的补学块查账回填（spec §4"节点会重建、账不重建"）。

## 账本 ns 常量取用（无 class_name 的 autoload 走 preload 脚本常量，M 流同款；
## 不引用全局标识符 GameSave——-s/独立夹具环境编译期安全）
const _GameSaveScript := preload("res://scripts/save/game_save.gd")

## 要学的法术 id（约定路径 spells/<id>/resources/<id>_definition.tres，
## SpellRegistry 单一解析点；装配非空校验归 validator R12，T3 在册）
@export var spell_id: StringName = &""
## 账本键（空=回落用 spell_id）：同一法术多份秘籍时按章前缀区分户头
@export var manual_id: StringName = &""


func _ready() -> void:
	var trig := get_parent() as InteractTrigger
	if trig == null:
		return
	# 外观判重（用户 F5 裁决 2026-09-25）：一次性知识件——账本已有账=学会过，
	# 本件出生帧连触发件整体退场，不再弹"拾取秘籍"（死亡段重跑/段重建后同理；
	# 与 chest 物理语义分道：空箱可再演诱惑，已读的知识不可）。无壳=无账可查，
	# 维持现状静默在场（独立跑测场境）。queue_free 帧尾收：physics 未走=无
	# body_entered 竞态面；订阅随之不建立（本帧起永不响应）。
	var shell := trig.find_shell()
	if shell != null and shell.session != null:
		var key: StringName = manual_id if manual_id != &"" else spell_id
		if shell.session.has_record(_GameSaveScript.NS_SPELLS, key):
			trig.queue_free()
			return
	trig.interacted.connect(_on_interacted)


## 申报单（spec §3 门三）：秘籍账入册（重演不重学）；无豁免面
func save_claim() -> Dictionary:
	return {&"persists": [_GameSaveScript.NS_SPELLS], &"resets": []}


func _on_interacted() -> void:
	var trig := get_parent() as InteractTrigger
	if trig == null or not is_instance_valid(trig):
		return
	var shell := trig.find_shell()
	if shell == null:
		return   # 无壳=无判重主体也无学习主体，静默不反应（chest 同款）
	trig.consume()
	# 复查式 claim（T0 头注条款兑现）：GameSave._ready 已预列 NS_SPELLS 系统户，
	# 本件对自己的户再报一次所有权——claim 幂等，重复开户静默通过不换手
	shell.session.claim_namespace(_GameSaveScript.NS_SPELLS, &"InteractSpellBook")
	var key: StringName = manual_id if manual_id != &"" else spell_id
	# 值维立法（B4.5-T4 修复波 A1）：键=拾得事件（manual_id 分户时是户名），
	# 值=教什么（spell_id）——分户件的科目信息随账走，重建节点补学经
	# GameSave.value_of 读回（record 幂等：值只在首记写入，重记不改）。
	# manual_id 空的常规装配下值==键，语义零漂移。
	var first: bool = shell.session.record(_GameSaveScript.NS_SPELLS, key, spell_id)
	if first:
		var def := SpellRegistry.definition_for(spell_id)
		if def == null:
			push_error("InteractSpellBook: 法术 %s 定义缺件（账已记 %s，本次不学习不炸链）"
					% [spell_id, key])
		elif shell.playable == null:
			push_error("InteractSpellBook: 壳 playable 缺席，法术 %s 无处可学" % spell_id)
		else:
			shell.playable.learn_spell(def)
	# 消失演出 0.4s（tween 绑触发件本体，照抄 chest 尾巴）：二次判定已由
	# spells_known 账兜底，释放节点只负责"秘籍不再诱惑"的视觉与物理清算
	var tw := trig.create_tween()
	tw.tween_property(trig, "scale", Vector2.ZERO, 0.4)
	tw.tween_callback(trig.queue_free)
