@tool
extends QuiverCharacter
## 陈靖仇 - 玩家主角（天之痕主角）
##
## 薄壳脚本，继承 QuiverCharacter。只负责：
##   1. 编辑器模式下禁用处理（防编辑器里跑游戏逻辑）
##   2. 运行时 reset attributes（确保 HP/状态从初始值开始）
##   3. 加入 "player" 全局 group（敌人 AI 用这个找到玩家）
##   4. F6 独立运行该场景时，加一个调试相机
##
## 游戏逻辑（移动、攻击、受击、跳跃等）全部由 QuiverStateMachine 接管，
## 本脚本不写任何 gameplay 代码。

func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		QuiverEditorHelper.disable_all_processing(self)
		return

	if attributes != null:
		attributes.reset()

	add_to_group("player")

	if QuiverEditorHelper.is_standalone_run(self):
		QuiverEditorHelper.add_debug_camera2D_to(self, Vector2(0, -0.8))
