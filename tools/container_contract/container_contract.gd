extends Node

## 舞台容器契约（S2-M1-B1）：ChapterSession 语义（S 组）、壳切换（E 组）、
## 段检查点（D 组）、壳件（H 组）。运行：
## godot --headless --path . res://tools/container_contract/container_contract.tscn

var _fails := 0
var _finished := false


func _ready() -> void:
	await _flow_session()
	_check(_finished, "全序列执行完成（协程静默中断防线）")
	print("════════ container-contract: %s ════════" % ("PASS" if _fails == 0 else "FAIL"))
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails += 1
	print("  %s: %s" % ["PASS" if ok else "FAIL", label])


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _flow_session() -> void:
	var s := ChapterSession.new()
	var got_flag: Array[StringName] = []
	s.flag_added.connect(func(id): got_flag.append(id))
	s.add_flag(&"key_lantern")
	s.add_flag(&"key_lantern")
	_check(s.has_flag(&"key_lantern") and got_flag.size() == 1,
			"S1 旗标幂等（信号只发一次）")
	_check(s.open_chest(&"chest_a") and not s.open_chest(&"chest_a")
			and s.is_chest_open(&"chest_a"), "S2 宝箱一次性语义")
	s.mark_cleared(&"seg_01")
	_check(s.is_cleared(&"seg_01") and not s.is_cleared(&"seg_02"),
			"S3 清场记录按段隔离")
	s.record_checkpoint(&"seg_02", &"gate")
	_check(s.checkpoint_segment() == &"seg_02" and s.checkpoint_entry() == &"gate",
			"S4 检查点记录段+入口名")
	_finished = true
