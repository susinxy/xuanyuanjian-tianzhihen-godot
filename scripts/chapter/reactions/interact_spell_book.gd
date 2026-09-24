class_name InteractSpellBook
extends InteractReaction

## 《秘籍》反应件（S2-B4，spec §4；家族第四型，chest 同门形制）：挂
## InteractTrigger 子节点、_ready 订阅 interacted。E 触发→对 GameSave 的
## spells_known 户记账（manual_id 空则回落 spell_id 作账本键）→**首开**即时
## 把 registry 解析出的定义教给 shell.playable（def 缺件=push_error 不炸链，
## 账已记=道具确被拾取，降级不吞事件）→无论首开与否 consume()+0.4s 缩小消失
## （再触发不重发学习、再出现不吐第二份——chest 判例⑤同法）。
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
	if trig:
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
	var first: bool = shell.session.record(_GameSaveScript.NS_SPELLS, key)
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
