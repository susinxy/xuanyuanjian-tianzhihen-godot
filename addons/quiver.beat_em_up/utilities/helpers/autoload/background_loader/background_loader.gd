extends Node

## Wrapper autoload for loading resources in the background using ResourceLoader thread methods.
## S5b 转场层修复批（2026-09-30）：协程与取用方对 _progress 的读/删零协调是
## "Invalid access to property or key '<路径>' on Dictionary" 报案根因（D2）；
## 失败路径不发终态信号= await 订阅者永挂（transition 侧已改轮询免疫，本侧
## 同步补"终态信号必达"契约语义，transition_contract T3 判据）。

### -----------------------------------------------------------------------------------------------
### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

## Emitted once the resource finishes loading, **and also on the failure path**（S5b：
## 终态必达——成功/失败/被 get_resource 接管三种收敛都发；订阅者 await 此信号
## 不再可能悬挂）。It only sends the path as an argument, you have to
## call [method get_resource] with the same path to actually get the loaded resource.
signal loading_finished(path: String)
## Emitted every frame while loading.
signal loading_progress(path: String, progress: float)

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

## Keys are paths being loaded, and values are arrays with one float value, that are returned
## from ResourceLoader
var _progress := {}

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	pass

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## Starts loading resource on the path given using threads.
## S5b：循环内所有 _progress 读取先查 has——键被 get_resource 摘除=已被接管，
## 本协程静默让位（不再裸读报错），让位路径与正常路径同样在末尾发终态信号。
func load_resource(path: String) -> void:
	var status := ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		push_warning("Already loading %s"%[path])
		return
	elif status == ResourceLoader.THREAD_LOAD_LOADED:
		push_warning("Already finished loading %s but resource hasn't been retrieved yet."%[
				path
		])
		return

	ResourceLoader.load_threaded_request(path, "", false, ResourceLoader.CACHE_MODE_REUSE)

	_progress[path] = []
	var load_status := ResourceLoader.load_threaded_get_status(path, _progress[path])
	var taken_over := false
	while load_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if not _progress.has(path):
			taken_over = true   # get_resource 已接管此路径：本协程让位，不裸读不报错
			break
		loading_progress.emit(path, float(_progress[path][0]))
		await get_tree().process_frame
		if not _progress.has(path):
			taken_over = true
			break
		load_status = ResourceLoader.load_threaded_get_status(path, _progress[path])

	if not taken_over:
		if load_status == ResourceLoader.THREAD_LOAD_LOADED:
			loading_progress.emit(path, 1.0)
		else:
			_push_loading_error(path)
		_progress.erase(path)
	# S5b 终态必达（T3 判据）：成功/失败/被接管三收敛统一发
	loading_finished.emit(path)


## Returns the progress from any given path, or an error if the path is not being loaded.
func get_progress_for(path: String) -> float:
	var value := 0.0

	if _progress.has(path):
		value = float(_progress[path][0])
	else:
		push_error("Path not found in progress dictionary: %s"%[path])

	return value


## Returns the loaded Resource from any given path, or an error if the path hasn't been loaded.
func get_resource(path: String) -> Resource:
	const ERROR_NO_PATH = "Resource at path %s is not on cache nor loading. Have you used the 
			function start_loading() with it?"
	var loaded_resource: Resource = null
	var status := ResourceLoader.load_threaded_get_status(path)

	if status in [ResourceLoader.THREAD_LOAD_IN_PROGRESS, ResourceLoader.THREAD_LOAD_LOADED]:
		loaded_resource = ResourceLoader.load_threaded_get(path)
		_progress.erase(path)
	elif status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		if ResourceLoader.has_cached(path):
			loaded_resource = ResourceLoader.load(path)
		else:
			push_error(ERROR_NO_PATH)

	return loaded_resource


## Returns true if the resource is loading. Be careful that false means it either never started 
## loading or already has finished loading.
func is_loading_resource(path: String) -> bool:
	return ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS


## Returns true if it has been loaded but not retrieved yet.
func is_loading_finished(path: String) -> bool:
	return ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _push_loading_error(path) -> void:
	push_error("Failed to load resource: %s | Error: %s"%[
			path,
			ResourceLoader.load_threaded_get_status(path)
		])
