extends Control
## 标题壳（S2-B4.5-T2 起为读档三通道之入口，spec §4）：
## 　· 传渡清理点：GameEvents.reset_session 只清传渡不清账（T1 语义：回标题≠清档，
##     T2 清账——旧 :17 冗余 pending 复写行并入 reset_session 既有职责顺手收掉）；
## 　· 「继续游戏」：enabled=SaveSystem.has_save()（每次 _ready 评估，替换 T1 前
##     disabled「读取存档」占位钮=其 TODO 兑现）；点击=load_game 成功→
##     resume_pending 传渡→转场检查点场景（落位由壳 _ready 消费，spec §4；
##     真点击链归 F5，契约走拆段腿——T1 移交②"点=真转场拆套"）；
## 　· 「开始游戏」：有档=运行时构建 ConfirmationDialog（无新 .tscn，debug 面板
##     先例；PROCESS_MODE 随壳 ALWAYS）"进度将被清除，确定重新开始？"，确认=
##     SessionRules.begin_new_profile（清账+删档+清传渡收口）+转场，取消=不转；
##     无档直进=B4 行为零变；
## 　· 进场淡入经全局转场层；GAMEPLAY_SCENE 预载的 ResourceLoader.exists 守卫注
##     沿用（T5 占位批条款）。

const GAMEPLAY_SCENE := "res://scenes/stages/ref/stage_ref_a.tscn"

var _entries: VBoxContainer
var _confirm_dialog: ConfirmationDialog


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_entries = $ContentLayer
	GameEvents.reset_session()   # 只清传渡（账目随档案走；旧同行之下的 pending
	                              # 复写系冗余，B4.5-T2 清账——reset_session 已做该事）
	_build_confirm_dialog()
	ScreenTransitions.fade_out_transition(0.6)
	if ResourceLoader.exists(GAMEPLAY_SCENE):
		BackgroundLoader.load_resource(GAMEPLAY_SCENE)
	add_entry("开始游戏", _start_game)
	add_entry("继续游戏", _continue_game, SaveSystem.has_save())
	add_entry("退出游戏", _quit)


func add_entry(label: String, callback: Callable, enabled := true) -> Button:
	return _entries.add_entry(label, callback, enabled)


## 覆盖确认框（spec §4 运行时构建）：confirmed 只吃 begin_new_profile+转场两步，
## 取消钮走 Popup 默认关闭=不转（confirmed 不发射）。挂壳下 process_mode 显式
## ALWAYS（wire_end_panel B7 同款冻结树活性纪律，标题壳虽不冻结亦对齐）。
func _build_confirm_dialog() -> void:
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.name = &"NewGameConfirm"
	_confirm_dialog.dialog_text = "进度将被清除，确定重新开始？"
	_confirm_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	_confirm_dialog.confirmed.connect(_on_confirm)
	add_child(_confirm_dialog)


func _start_game() -> void:
	# 分相形制（B4.5-T2，契约可测性的来源）：有档=只拉弹窗即返——转场是
	# confirmed 之后的另一相，套件模拟点击永远停在弹窗步，不拆套（A7d/e 腿）。
	if SaveSystem.has_save():
		_confirm_dialog.set_visible(true)
		return
	# 无档直进：begin_new_profile 的 delete_save 幂等静默，与旧"new_profile+清传渡"
	# 外等价=B4 行为零变（清账唯一口收口收编）。
	SessionRules.begin_new_profile()
	_enter_game_scene()


func _on_confirm() -> void:
	SessionRules.begin_new_profile()
	_enter_game_scene()


func _enter_game_scene() -> void:
	ScreenTransitions.transition_to_scene(GAMEPLAY_SCENE)


func _continue_game() -> void:
	# load_game 失败（无档竞态/坏档）=现账一字不动且不推进（spec §2②），静默返；
	# 成功=置传渡旗再转场，落位由目标壳 _ready first-wins 消费（spec §4）。
	# 检查点场景空串（T0 前旧档/未记账档）=push_error 响亮不转，不猜去处。
	if not SaveSystem.load_game():
		return
	GameSave.resume_pending = true
	var scene := GameSave.checkpoint_scene()
	if scene.is_empty():
		push_error("标题壳：存档未记检查点场景（空串），「继续游戏」取消转场")
		return
	ScreenTransitions.transition_to_scene(scene)


func _quit() -> void:
	get_tree().quit()
