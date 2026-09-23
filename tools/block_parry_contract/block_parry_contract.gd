extends Node

## S2-B3 盾反批契约：M 流=修饰核心 B′ 手术（重算回写）的回归流——
## base 捕获、加乘复合按序重算、乱序摘除、同 id 替换、非法型零副作用、
## reset 清账。P/Q 流（姿态状态/判定缝）由后续任务在本文件生长。
## 运行：godot --headless --path . res://tools/block_parry_contract/block_parry_contract.tscn

const A_AT := "res://addons/quiver.beat_em_up/characters/quiver_attributes.gd"
const M_BASE_MOVE := 600.0

var _fails := 0
var _finished_m := false


func _ready() -> void:
	await _flow_modifiers()
	# 判例（AGENTS）：子协程运行时炸掉后主协程照常续跑——每流自带完成旗单独锁
	_check(_finished_m, "M 流全序列执行完成（协程静默中断防线）")
	print("════════ block-parry-contract: %s ════════" % ("PASS" if _fails == 0 else "FAIL"))
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails += 1
	print("  %s: %s" % ["PASS" if ok else "FAIL", label])


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


## 纯 RefCounted 消费（不建场景）：M 腿只碰 move_speed/reset 路径，
## 两路径均不解引用 character_node（apply_knock 才查 null，本流不调它）。
func _fresh_attrs() -> QuiverAttributes:
	var a: QuiverAttributes = load(A_AT).new()
	return a


func _flow_modifiers() -> void:
	var a := _fresh_attrs()
	# M1 base 捕获+重算：×0.5 → +100 → (600+100)×0.5=350（旧世界=400，必红）
	a.add_modifier(&"m_mult", &"move_speed", "multiply", 0.5)
	_check(a.move_speed == 300, "M1a 单乘回写=300（两世界同值，护住 locomotion）")
	a.add_modifier(&"m_add", &"move_speed", "add", 100.0)
	_check(a.move_speed == 350, "M1b 加乘复合按序重算=350")
	# M2 乱序摘除（旧世界：先摘 m_mult 会把 600 写回、再摘 m_add 落 300——必红）
	a.remove_modifier(&"m_mult")
	_check(a.move_speed == 700, "M2a 摘乘余加=700")
	a.remove_modifier(&"m_add")
	_check(a.move_speed == 600, "M2b 全摘归 base")
	# M3 同 id 刷新（replace）
	a.add_modifier(&"m_dup", &"move_speed", "multiply", 0.5)
	a.add_modifier(&"m_dup", &"move_speed", "multiply", 0.5)
	_check(a.move_speed == 300, "M3a 同 id 再挂=替换非叠乘（600 非 150）")
	a.remove_modifier(&"m_dup")
	_check(a.move_speed == 600, "M3b 一次摘净")
	# M4 非法 type：告警+不入账
	a.add_modifier(&"m_bad", &"move_speed", "wat", 2.0)
	_check(a.move_speed == 600, "M4a 非法操作型不改值")
	# M5 reset 清账（护人/locomotion 修饰不跨死亡）
	a.add_modifier(&"m_life", &"move_speed", "multiply", 0.5)
	a.reset()
	_check(a.move_speed == 600, "M5a reset 后受管值=base（旧世界：记录残留）")
	a.remove_modifier(&"m_life")
	_check(a.move_speed == 600, "M5b 死账摘除=无操作（记录已清）")
	_finished_m = true
