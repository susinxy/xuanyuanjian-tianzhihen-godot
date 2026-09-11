@tool
class_name ContourConversionRunner
extends Node
## 轮廓转换运行器（常驻 Node，与 Inspector widget 生命周期解耦）
##
## 背景（Godot 4.7 editor_inspector.cpp 源码实证）：
## - EditorInspector::_clear() 对 Inspector 内的自定义控件用 memdelete 立即销毁，
##   任何选中切换/刷新都会重建 widget。
## - 若转换协程跑在 widget 里（callback_obj=widget），运行中切页会导致：
##   进度/结果文字随 widget 销毁丢失、帧让出失效（callback_obj 判空 → 不再 await → 主线程假死）。
##
## 本节点常驻在 EditorInterface.get_base_control() 下（编辑器场景树内），负责：
## - 执行 AnimationTrackInjector 转换（作为进度回调与帧让出的宿主）
## - 保存状态快照（is_running / status_text / progress_text / result_text）
## - 重建后的 widget 通过 get_or_create() + 信号订阅恢复显示，运行文字不再被刷新冲掉

signal progress_updated()
signal run_finished()

static var _instance: ContourConversionRunner = null

## 状态快照（widget 重建时读取）
var is_running := false
var running_mode := ""
var target_name := ""
var status_text := ""
var status_color := Color.GRAY
var progress_text := ""
var result_text := ""

## 会话号：防止目标失效中止后又启动新转换时，旧协程的收尾覆盖新状态
var _session := 0
var _active_skin: Node = null

const AnimationTrackInjector = preload(
	"res://addons/quiver.beat_em_up/custom_inspectors/height_layers/"
	+ "animation_track_injector.gd"
)


## 获取常驻实例（非编辑器环境返回 null）
static func get_or_create() -> ContourConversionRunner:
	if not Engine.is_editor_hint():
		return null
	if is_instance_valid(_instance):
		return _instance
	var runner := ContourConversionRunner.new()
	runner.name = "ContourConversionRunner"
	EditorInterface.get_base_control().add_child(runner)
	_instance = runner
	return runner


## 只读取，不创建
static func peek() -> ContourConversionRunner:
	if is_instance_valid(_instance):
		return _instance
	return null


## 启动转换；正在运行时忽略。
## mode: "body" / "attack"
## params: { alpha_threshold, simplify_tolerance, min_area_ratio, erosion_radius,
##           shape_type, shadow_simplify_tolerance, shadow_min_area_ratio }
func start(mode: String, skin_node: Node, params: Dictionary) -> void:
	if is_running or skin_node == null or not is_instance_valid(skin_node):
		return
	_session += 1
	is_running = true
	running_mode = "Body" if mode == "body" else "Attack"
	target_name = String(skin_node.name)
	_active_skin = skin_node
	status_text = "⏳ %s 轮廓转换中…（目标: %s，切页不影响进度）" % [running_mode, target_name]
	status_color = Color.CYAN
	progress_text = ""
	result_text = ""
	progress_updated.emit()
	_execute(_session, mode, skin_node, params)


## 转换协程（fire-and-forget）
func _execute(session: int, mode: String, skin_node: Node, params: Dictionary) -> void:
	var injector := AnimationTrackInjector.new()
	var result = null
	if mode == "body":
		result = await injector.convert_body_contours(
			skin_node,
			params["alpha_threshold"],
			params["simplify_tolerance"],
			params["min_area_ratio"],
			params["erosion_radius"],
			params["shape_type"],
			false, self,
			params["shadow_simplify_tolerance"],
			params["shadow_min_area_ratio"]
		)
	else:
		result = await injector.convert_attack_contours(
			skin_node,
			params["alpha_threshold"],
			params["simplify_tolerance"],
			params["min_area_ratio"],
			params["erosion_radius"],
			params["shape_type"],
			false, self
		)
	if session != _session:
		return
	if not (result is Dictionary):
		_finalize({ "errors": ["转换中断（转换期间目标场景可能被关掉了）"], "frame_count": 0 })
	else:
		_finalize(result)


## 注入器进度鸭子类型回调（原 widget 上的同名方法迁移至此）
## 注入器还会通过 has_method("get_tree") + get_tree() 取帧让出——本节点常驻编辑器树，始终有效
func _on_contour_progress(current: int, total: int, filename: String, phase: String = "") -> void:
	if not is_running:
		return
	if _active_skin != null and not is_instance_valid(_active_skin):
		# 目标已释放（转换期间关闭场景页签）：立即作废旧协程收尾权并中止本次运行，
		# 防止 is_running 永久卡 true（注入器后续访问 freed 节点会自行报错，结果被 session 丢弃）
		_session += 1
		_finalize({ "errors": ["目标皮肤节点已被释放（转换期间关闭了场景？），转换中止"], "frame_count": 0 })
		return
	if phase != "":
		progress_text = "⏳ [%s] 轮廓扫描: %d/%d 帧 (%s)" % [phase, current, total, filename]
	else:
		progress_text = "⏳ %s 转换中: %d 帧 (%s)" % [running_mode, current, filename]
	progress_updated.emit()


## 收尾：生成结果文本、复位状态、刷新文件系统、通知视图
func _finalize(result: Dictionary) -> void:
	is_running = false
	_active_skin = null
	var errors: Array = result.get("errors", [])
	var error_count: int = errors.size()
	var frame_count: int = result.get("frame_count", 0)
	
	var lines := []
	lines.append("[b]%s 轮廓转换结果[/b]" % running_mode)
	lines.append("")
	lines.append("处理帧数: [b]%d[/b]" % frame_count)
	lines.append("")
	if error_count == 0:
		lines.append("[color=green]✅ 转换完成，无错误[/color]")
	else:
		lines.append("[color=red]❌ 有 %d 个错误：[/color]" % error_count)
		for error in errors:
			lines.append("  • %s" % error)
	result_text = "\n".join(lines)
	
	if error_count == 0:
		status_text = "✅ %s 转换完成（目标: %s）" % [running_mode, target_name]
		status_color = Color.GREEN
	else:
		status_text = "⚠️ %s 转换完成，有 %d 个错误（目标: %s）" % [running_mode, error_count, target_name]
		status_color = Color.ORANGE
	progress_text = ""
	
	# 文件系统自动刷新（原 widget scan_completed → inspector_plugin 中转；
	# widget 死亡会断链，改由此处直调）
	EditorInterface.get_resource_filesystem().scan()
	run_finished.emit()
