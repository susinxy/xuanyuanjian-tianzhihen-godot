extends CanvasLayer

## 全局转场层。S5b 修复批（2026-09-30，transition_contract 六缺陷定档后手术）：
##  · D1 旧序"先拆台再取资源且取空不 return"=任何加载失败必黑屏——改为
##    **先取到资源才拆台**，取空=淡出回帘留在原场景（报错不毁现场）；
##  · D2 等待面从"押注 loading_finished 信号时序"改为**轮询加载器状态**
##    （loader 侧同步已保证终态信号必达，双保险）；
##  · D3 防重入闩：转场进行中再触发=警告忽略（旧版连点产生僵尸协程跨腿劫持
##    换场=生产事故"双击后下一次转场黑屏"的机理）；
##  · D4 动画等待改为"播放态轮询 + 随动画资产自然缩放的保险丝上限"，被顶掉/
##    被打断不再永挂（await animation_finished 丢信号判例）；
##  · D5 进度条监听收口：完成/失败统一 disconnect（bind 实例自存，幂等）。

### -----------------------------------------------------------------------------------------------
### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const FADE_DURATION = 0.3

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

var _tween: Tween
var _in_transition := false
## 进度条 handler 的绑定实例表（path → 实际 connect 出去的 Callable，收口用）
var _bar_handlers := {}

@onready var _animator := $AnimationPlayer as AnimationPlayer
@onready var _progress_bar := $ProgressBar as ProgressBar

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	pass

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func transition_to_scene(path: String) -> void:
	if _in_transition:
		push_warning("ScreenTransitions: 上一转场进行中，忽略重入请求 %s" % path)
		return
	_in_transition = true
	# A2 兜底（2026-09-18）：死亡慢动作(Engine.time_scale)的正常恢复点在 Die 状态，
	# 若死亡流程被切换/剧情截断则全局时钟永久卡慢——换场是流程级重置点，
	# 此处无条件恢复（幂等，正常路径下本已是 1.0）。
	Engine.time_scale = 1.0
	const ERROR_PACKED_SCENE = \
			"%s is not a path to a PackedScene, it's only possible to transition between scenes"

	if not (
			BackgroundLoader.is_loading_resource(path)
			or BackgroundLoader.is_loading_finished(path)
	):
		BackgroundLoader.load_resource(path)

	await _wait_animation(&"fade_in_transition", 1.0)
	# D2：轮询加载器状态直到终态（不押注信号时序；loader 协程三条收敛路径
	# 都会让状态离开 IN_PROGRESS，悬挂结构性不可能）
	while BackgroundLoader.is_loading_resource(path):
		await get_tree().process_frame
		if not is_instance_valid(self):
			return
	var scene := BackgroundLoader.get_resource(path) as PackedScene
	_dismiss_progress_bar(path)
	if scene == null:
		# D1：拿不到新场景就不拆旧场景——报错并升起黑幕回到现场景
		push_error(ERROR_PACKED_SCENE % [path])
		_in_transition = false      # 闩先放再举幕：新转场请求不该被回帘动画吞掉
		await _wait_animation(&"fade_out_transition", 1.0)
		return
	get_tree().unload_current_scene()
	var error := get_tree().change_scene_to_packed(scene)
	if error != OK:
		push_error("Could not transition to %s | error: %s" % [path, error])
	# 闩在换场完成即放：回帘 fade_out 是纯视觉尾带，期间若来新转场，
	# _wait_animation 的"换名放行"语义会自然接管（旧版把闩拖过尾幕=吞请求，
	# transition_contract T5 串台判例）
	_in_transition = false
	await _wait_animation(&"fade_out_transition", 1.0)


## 淡入（黑幕落下）。fire-and-play：等待语义收归 _wait_animation（旧版内部
## await animation_finished=可被顶掉丢信号的悬挂点，D4 根治）。
func fade_in_transition(duration: = 1.0) -> void:
	_animator.play("fade_in_transition", -1, 1.0 / duration)


func fade_out_transition(duration := 1.0) -> void:
	_animator.play("fade_out_transition", -1, 1.0 / duration)


func show_loading_bar_for(path: String) -> void:
	_progress_bar.value = BackgroundLoader.get_progress_for(path)
	if _progress_bar.value < 1.0:
		if not _bar_handlers.has(path):
			var cb := _update_progress_bar.bind(path)
			_bar_handlers[path] = cb
			BackgroundLoader.loading_progress.connect(cb)
		if _tween:
			_tween.kill()

		_tween = create_tween()
		_tween.tween_property(_progress_bar, "modulate:a", 1.0, FADE_DURATION)

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

## D4 的等待形态：轮询"这条动画还在放且还是它"——自然播完=秒放行；被别的动画
## 顶掉=秒放行（正是旧版永挂的场景）；保险丝上限从**动画资产自身时长**推导
## （natural=anim.length×duration，cap=1.5×natural+0.5s），改动画长度自动跟随，
## 不存在任何写死的秒数。
func _wait_animation(anim_name: StringName, duration: float) -> void:
	var anim := _animator.get_animation(anim_name)
	if anim_name == &"fade_in_transition":
		fade_in_transition(duration)
	else:
		fade_out_transition(duration)
	var natural: float = (anim.length if anim != null else duration) * maxf(duration, 0.01)
	var cap: float = natural * 1.5 + 0.5
	var waited := 0.0
	while _animator.is_playing() \
			and String(_animator.current_animation) == String(anim_name) and waited < cap:
		await get_tree().process_frame
		if not is_instance_valid(self):
			return
		waited += get_process_delta_time()


## 进度条收口（D5）：断连+淡隐，幂等（未显示过也安全）。
func _dismiss_progress_bar(path: String) -> void:
	if _bar_handlers.has(path):
		var cb: Callable = _bar_handlers[path]
		if BackgroundLoader.loading_progress.is_connected(cb):
			BackgroundLoader.loading_progress.disconnect(cb)
		_bar_handlers.erase(path)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_progress_bar, "modulate:a", 0.0, FADE_DURATION)


func _update_progress_bar(resource_path: String, progress: float, path: String) -> void:
	if resource_path != path:
		return

	_progress_bar.value = progress
	if _progress_bar.value >= 1.0:
		_dismiss_progress_bar(path)
