extends Control
## 暂停壳：ESC toggle；树冻结的置位/解冻全部收口本文件（三解冻路径：
## 继续/跳转类操作前/重载后）。时序铁律（上游教训）：**任何 transition 或
## reload 之前必须先 unpause**，否则转场 tween 在冻结树下永久挂起。

signal menu_opened
signal menu_closed

const TITLE_PATH := "res://ui/menus/title_screen.tscn"

var _entries: VBoxContainer

@onready var _anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_entries = $ContentLayer
	add_entry("继续", close_menu)
	add_entry("回本地点入口", _jump_latest_checkpoint)
	add_entry("返回标题", _goto_title)
	add_entry("退出游戏", _quit)


func add_entry(label: String, callback: Callable, enabled := true) -> Button:
	return _entries.add_entry(label, callback, enabled)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			close_menu()
		else:
			open_menu()
		get_viewport().set_input_as_handled()


func open_menu() -> void:
	# 冻结所有权：ESC 不得在他人冻结态上叠开暂停壳（DeathScreen/StageEndPanel
	# 持有冻结）——否则"继续"会无主解冻死亡世界（S1 终审 I-1）
	if get_tree().paused:
		return
	if visible:
		return
	visible = true
	get_tree().paused = true
	if _anim.has_animation("open") and _anim.get_animation("open").length > 0.0:
		_anim.play("open")
	menu_opened.emit()


func close_menu() -> void:
	if not visible:
		return
	visible = false
	# 占位批不得预置 length=0 动画：引擎载入钳到 0.001 骗过下方守卫，
	# 无 method track 则解冻信标永响（2026-09-18 探针实证，只留空动画库）
	if _anim.has_animation("close") and _anim.get_animation("close").length > 0.0:
		_anim.play("close")
		# 动画末尾 method track 应调用 unpause_now()；无动画则立即执行
		if not _anim.is_playing():
			unpause_now()
	else:
		unpause_now()
	menu_closed.emit()


## 供动画 method-track 回调（占位批无动画时由 close_menu 直接调）
func unpause_now() -> void:
	get_tree().paused = false


## 注册表旧→新，最新在尾（brief 原文 cps[0] 系计划笔误，T2 裁决修正）
## （B4.5-T1 改口，spec §3 裁决 R2：回跳表迁账 GameSave.locations()，浅拷只读够用）
func _latest_checkpoint() -> Dictionary:
	var cps: Array[Dictionary] = GameSave.locations()
	return {} if cps.is_empty() else cps.back()


func _jump_latest_checkpoint() -> void:
	unpause_now()
	var cp := _latest_checkpoint()
	if cp.is_empty():
		_goto_title()
		return
	GameEvents.pending_jump_stage = cp.scene_path
	ScreenTransitions.transition_to_scene(cp.scene_path)


func _goto_title() -> void:
	unpause_now()
	GameEvents.pending_jump_stage = ""
	ScreenTransitions.transition_to_scene(TITLE_PATH)


func _quit() -> void:
	get_tree().quit()
