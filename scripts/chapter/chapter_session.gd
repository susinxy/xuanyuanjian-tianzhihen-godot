class_name ChapterSession
extends RefCounted

## 章节会话状态包 v1（S2-M1-B1，spec §3.3）：与 S5 存档同构的最小核——
## 角色本体状态（hp 等）不在包内（玩家永驻壳内天然延续，spike E6 实证）。

signal flag_added(id: StringName)
signal chest_opened(id: StringName)
signal segment_cleared(id: StringName)

var flags := {}
var chests := {}
var cleared_segments := {}
var checkpoint := {}


func add_flag(id: StringName) -> void:
	if flags.has(id):
		return
	flags[id] = true
	flag_added.emit(id)


func has_flag(id: StringName) -> bool:
	return flags.has(id)


## 开宝箱：首次 true（拾取方），重复 false（消费方据此决定给不给东西）
func open_chest(id: StringName) -> bool:
	if chests.has(id):
		return false
	chests[id] = true
	chest_opened.emit(id)
	return true


func is_chest_open(id: StringName) -> bool:
	return chests.has(id)


func mark_cleared(id: StringName) -> void:
	if cleared_segments.has(id):
		return
	cleared_segments[id] = true
	segment_cleared.emit(id)


func is_cleared(id: StringName) -> bool:
	return cleared_segments.has(id)


func record_checkpoint(segment: StringName, entry: StringName) -> void:
	checkpoint = {"segment": segment, "entry": entry}


func checkpoint_segment() -> StringName:
	return checkpoint.get("segment", &"")


func checkpoint_entry() -> StringName:
	return checkpoint.get("entry", &"default")
