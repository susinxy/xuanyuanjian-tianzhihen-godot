extends Node

## SaveSystem 影子落盘监听者（S2-B4.5 立户，spec §2 三条纪律）：
## 　①影子语义——账=事实，档=账的快照：GameSave 一切泛信号（recorded/
## 　　checkpoint_recorded/location_visited）到达即置脏，**帧尾合并落盘**
## 　　（一帧多记=一次写）；内容件零自觉调用，记账即落盘。
## 　②失败不抛——写失败只 push_error 不断游戏（丢档=可接受灾种，崩游戏=
## 　　不可接受灾种）；load_game 任一坏=返回 false 且现账一字不动。
## 　③测试吃 scratch——`slot_path` 运行时可注入（默认 AUTOSAVE_PATH 生产槽）；
## 　　契约/消费套一律重定向到 scratch 名（B4.5 测试卫生条款），永不读写生产档。
## 形制：extends Node、无 class_name（GameSave 同款）——全仓经 /root/SaveSystem
## 或 get_node_or_null 访问，禁 import/preload 单例引用（plan Interfaces 钉）。
## 启动序判例（T0 Step0 探针实锤 4.7.1）：autoload 按 [autoload] 声明序注册入树、
## 各自 _ready 在 add 时即跑、全部先于场景根 _ready——故 _ready 里取
## /root/GameSave 必在场、连接泛信号安全（GameSave 行在本行之前，勿换位）。

## 唯一自动档生产槽（plan Interfaces 钉名；headless/Windows 各自 user:// 下互不污染）
const AUTOSAVE_PATH := "user://save_auto.json"

## 落盘槽注入口：赋值后不自动回退（契约只吃 scratch——测试卫生条款，spec §2③）
var slot_path := AUTOSAVE_PATH

## 帧尾合并状态：_dirty=本帧有账变；_queued=已排一次 deferred 冲刷（防重入旗）
var _dirty := false
var _queued := false


func _ready() -> void:
	var save := get_node_or_null(^"/root/GameSave")
	if save == null:
		# 响亮红：影子失明（启动序反常或 GameSave 未注册），断言/日志都看得见
		push_error("SaveSystem: /root/GameSave 缺席——影子失明（检查 [autoload] 声明序）")
		return
	# 回调形参逐条对齐信号实参（4.7 探针判例：0 参回调接 2 参信号在 emit 时炸，
	# 少参不算兼容）；显式 Callable，经局部变量取信号对象（typed 调用判例留意）。
	save.recorded.connect(_on_recorded)
	save.checkpoint_recorded.connect(_on_checkpoint_recorded)
	save.location_visited.connect(_on_location_visited)


func _on_recorded(_ns: StringName, _id: StringName) -> void:
	_mark_dirty()


func _on_checkpoint_recorded(_checkpoint: Dictionary) -> void:
	_mark_dirty()


func _on_location_visited(_stage_id: StringName) -> void:
	_mark_dirty()


func _mark_dirty() -> void:
	_dirty = true
	if _queued:
		return   # 帧尾合并：一帧多记只排一次冲刷
	_queued = true
	call_deferred("_flush_if_dirty")


func _flush_if_dirty() -> void:
	_queued = false
	if not _dirty:
		return
	_dirty = false
	save_now()


## 有档判定（读端/标题壳消费）
func has_save() -> bool:
	return FileAccess.file_exists(slot_path)


## 同步强存（供退出路径/测试）：to_dict→JSON→写 tmp→rename_absolute 原子替换。
## 任一步失败 push_error 返回 false（影子纪律②：不抛不断游戏）并顺手清 tmp 残骸。
func save_now() -> bool:
	var save := get_node_or_null(^"/root/GameSave")
	if save == null:
		push_error("SaveSystem: save_now 时 /root/GameSave 缺席，取消落盘")
		return false
	var tmp_path := slot_path + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem: 临时槽打开失败（%s，err=%s），放弃本次落盘不断游戏"
			% [tmp_path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(save.to_dict()))
	f.close()   # 必须先关再改名（句柄未释放在 Windows 上 rename 必败）
	var err := DirAccess.rename_absolute(tmp_path, slot_path)
	if err != OK:
		push_error("SaveSystem: 原子改名失败 %s→%s（err=%s），清 tmp 残骸"
			% [tmp_path, slot_path, error_string(err)])
		DirAccess.remove_absolute(tmp_path)
		return false
	_dirty = false   # 影子与账此刻同相，帧尾合并可跳过一次冗余写
	return true


## 读档（回检查点的硬盘孪生入口，spec §4）：读+parse+形状校验→GameSave.from_dict。
## 任一坏=返回 false 且现账一字不动（from_dict 全有或全无；坏快照 push_error 是被试行为）。
func load_game() -> bool:
	var save := get_node_or_null(^"/root/GameSave")
	if save == null:
		push_error("SaveSystem: load_game 时 /root/GameSave 缺席")
		return false
	if not FileAccess.file_exists(slot_path):
		push_warning("SaveSystem: 槽位无档（%s），读档取消" % slot_path)
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(slot_path))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("SaveSystem: 快照 JSON 不可解析（%s），拒读保现账" % slot_path)
		return false
	var ok: bool = save.from_dict(data)
	if ok:
		# 还原后影子=账同相：清脏防一次冗余回写（from_dict 走门内重建，不发泛信号）
		_dirty = false
	return ok


## 删档：正档与 .tmp 残骸一并清（幂等，缺席静默）
func delete_save() -> void:
	if FileAccess.file_exists(slot_path):
		DirAccess.remove_absolute(slot_path)
	var tmp_path := slot_path + ".tmp"
	if FileAccess.file_exists(tmp_path):
		DirAccess.remove_absolute(tmp_path)
