extends Control
## 标题壳：传渡清理点（reset_session 只清传渡不清账，B4.5-T1 语义注：回标题≠清档，
## 清账唯一口 GameSave.new_profile，spec §3）+ 开始游戏=GameSave 建档；
## 进场淡入经全局转场层；
## 预载玩法场景——GAMEPLAY_SCENE 文件 T5 才存在，占位批按 ResourceLoader.exists
## 守卫跳过（避免 autoload 加载器对缺失路径越界报错），T5 落地后预载自动生效。

const GAMEPLAY_SCENE := "res://scenes/stages/ref/stage_ref_a.tscn"

var _entries: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_entries = $ContentLayer
	GameEvents.reset_session()   # 只清传渡（账目随档案走，新开局由 _start_game 建档）
	GameEvents.pending_jump_stage = ""
	ScreenTransitions.fade_out_transition(0.6)
	if ResourceLoader.exists(GAMEPLAY_SCENE):
		BackgroundLoader.load_resource(GAMEPLAY_SCENE)
	add_entry("开始游戏", _start_game)
	add_entry("读取存档", Callable(), false)  # TODO(B4.5)：落盘读档流程落地后接线（仍置灰）
	add_entry("退出游戏", _quit)


func add_entry(label: String, callback: Callable, enabled := true) -> Button:
	return _entries.add_entry(label, callback, enabled)


func _start_game() -> void:
	# 开始游戏=新开局建档（B4-T1，spec §2：new_profile 是账本唯一重置口，
	# 重跑/回跳/换章一律不碰账）
	GameSave.new_profile()
	GameEvents.pending_jump_stage = ""
	ScreenTransitions.transition_to_scene(GAMEPLAY_SCENE)


func _quit() -> void:
	get_tree().quit()
