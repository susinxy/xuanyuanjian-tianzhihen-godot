extends Control
## 死亡结算壳：base_stage 在 player_died 后转交 open_screen（本壳不自监听信号，
## 保持被动）；open 时从 GameEvents 检查点表**清空重建**条目，末条固定"返回标题"。
## 时序铁律与暂停壳同款：任何 transition 之前必须先 unpause。

const TITLE_PATH := "res://ui/menus/title_screen.tscn"

var _entries: VBoxContainer

@onready var _anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_entries = $ContentLayer


func add_entry(label: String, callback: Callable, enabled := true) -> Button:
	return _entries.add_entry(label, callback, enabled)


func open_screen() -> void:
	if visible:
		return
	visible = true
	_rebuild_entries()
	if _anim.has_animation("open") and _anim.get_animation("open").length > 0.0:
		_anim.play("open")


func close_screen() -> void:
	if not visible:
		return
	visible = false
	if _anim.has_animation("close") and _anim.get_animation("close").length > 0.0:
		_anim.play("close")
		# 动画末尾 method track 应调用 unpause_now()；无动画则立即执行
		if not _anim.is_playing():
			unpause_now()
	else:
		unpause_now()


## 供动画 method-track 回调（占位批无动画时由 close_screen 直接调）
func unpause_now() -> void:
	get_tree().paused = false


## 注册表旧→新，最新在尾（摘旧追新+append）：取逆渲染得可见序"新→旧"
func _rebuild_entries() -> void:
	for child in _entries.get_children():
		child.free()
	var cps: Array[Dictionary] = GameEvents.get_checkpoints()
	for i in range(cps.size() - 1, -1, -1):
		var cp: Dictionary = cps[i]
		add_entry(String(cp.stage_id), _jump_to.bind(cp))
	add_entry("返回标题", _goto_title)


func _jump_to(cp: Dictionary) -> void:
	unpause_now()
	GameEvents.pending_jump_stage = cp.scene_path
	ScreenTransitions.transition_to_scene(cp.scene_path)


func _goto_title() -> void:
	unpause_now()
	GameEvents.pending_jump_stage = ""
	ScreenTransitions.transition_to_scene(TITLE_PATH)
