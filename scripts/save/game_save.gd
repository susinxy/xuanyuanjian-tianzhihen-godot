extends Node

## GameSave 单账本（S2-B4 立户，spec §2 宪章 / §3 门一门二）：全游戏"该记住的
## 事实"唯一存放点，随进程活；场景实例=账本的易失投影；硬盘=账本快照（B4.5）。
##
## 宪章摘要：
## 　· 存档生命周期只有两种——新开局（new_profile 清账建档，唯一重置口）/
## 　　读档（B4.5；本批=to_dict/from_dict 内存快照还原）。重跑/回跳/换章=不碰账。
## 　· 门一·单一门洞：账目只经 record/has_record/ids 读写；namespace 必须先
## 　　claim_namespace 开户，未开户写入=push_error+拒写。
## 　· 门二·类型闸：值只收普通类型（bool/int/float/String/StringName 及上述
## 　　一层 Array；Dictionary/Object 拒收）——B4.5 落盘日=一个字典写盘，
## 　　不许有格式惊喜。
## 　· 读档/回检查点=满状态复活：生命/法力/池/冷却一律不入账。
##
## 消费规范：新内容一律走 record/has_record/ids（键 StringName、带章前缀惯例），
## 禁止再造四账式专用包装；flags/chests/cleared_segments 存量 API 原签名兼容
## （自 chapter_session.gd 迁入，底层统一走 record 门洞），三信号随迁且仅首记发射。
##
## 开户决定申报（plan T0 Step2）：NS_SPELLS 在 _ready 随三系统户预列，供契约
## S 流先行使用；T2 已落地（2026-09-25）：InteractSpellBook._on_interacted 触发
## 时对自己的户再复查式 claim（owner 申报 InteractSpellBook；claim 幂等，
## 预列在前故不换手，语义=所有权再确认注记，本行即当时的"届时更新"兑现）。
##
## B4.5 三裁决落点（spec §2/§3/§8，2026-09-25 设计会）：
## 　R1 影子条款——一切首记/检查点/地点访问经泛信号广播，SaveSystem 是账的
## 　　自动影子（记账即落盘，内容件零自觉调用；见 signal recorded 等三条）；
## 　R2 一本账闭环——回跳表迁账（add_location_checkpoint/locations 随 to_dict
## 　　入快照、随 from_dict 还魂；GameEvents 降纯总线归 T1）；
## 　传渡条款——resume_pending 等一次性意图永不入账（不入 to_dict 不落盘）。

signal flag_added(id: StringName)
signal chest_opened(id: StringName)
signal segment_cleared(id: StringName)
## B4.5 泛信号三条（spec §2 影子条款 / §3 裁决 R2；新监听一律吃这三条，
## 上面旧三兼容信号仅存量消费面在用——spec §7.5 防信号面漂移注记）：
## record 门洞首记才发（四账兼容层底层走本门洞，故天然全覆盖）
signal recorded(ns: StringName, id: StringName)
## 检查点记账完成即发；载荷={scene, segment, entry} 三键拷贝（外改不回染账本）
signal checkpoint_recorded(checkpoint: Dictionary)
## 地点访问入账（原 GameEvents.story_checkpoint_added 语义随迁；T1 已拆旧轨，
## 本表为唯一存放）
signal location_visited(stage_id: StringName)

## 快照格式版本（B4.5 落盘文件同字段；不符=拒收保旧账）
const SAVE_VERSION := 1

## 系统户（GameSave 自开，spec §3 门一）
const NS_FLAGS := &"flags"
const NS_CHESTS := &"chests"
const NS_CLEARED := &"cleared_segments"
const NS_SPELLS := &"spells_known"
## 通关事实户（B4.5 T0 预开系统户；写入方=章壳 _maybe_finish_chapter 成功分支，
## T2 落地——plan Interfaces 钉名）
const NS_CHAPTERS_DONE := &"chapters_done"

## 传渡旗（spec §3 传渡条款）：读档"落位检查点"的一次性意图，与
## GameEvents.pending_jump_stage 同族——易失：不入账、不进 to_dict、不落盘
## （D 流⑤钉死）；first-wins 消费（壳端 _ready 读后即清）归 T2 接线。
var resume_pending := false

## 账本内部结构私有（spec §3 门三静态清点：game_save.gd 之外命中 _ledges=0）
var _ledges := {}   # ns(StringName) -> {id(StringName): value(普通类型)}
var _claims := {}   # ns(StringName) -> owner(StringName)，开户登记簿


func _ready() -> void:
	# 系统户自开（claim 幂等，故重复 _ready 亦安全）
	claim_namespace(NS_FLAGS, &"GameSave")
	claim_namespace(NS_CHESTS, &"GameSave")
	claim_namespace(NS_CLEARED, &"GameSave")
	claim_namespace(NS_SPELLS, &"GameSave")  # T0 预列决定申报见头注
	claim_namespace(NS_CHAPTERS_DONE, &"GameSave")  # B4.5 通关事实户预开（写入方 T2 落）


## 门一·开户（幂等）：已开户静默通过（复查式 claim 不炸不换手）
## 形参名申报：plan Interfaces 块的 `namespace` 系 4.7 GDScript 保留字
## （class_name 判例同族），实参位置/语义不变，callers 一律位置传参
func claim_namespace(ns: StringName, owner: StringName) -> void:
	if not _claims.has(ns):
		_claims[ns] = owner
	# 账页无条件确保存在（new_profile 清账后重开户/还原重灌都必须再给页）
	if not _ledges.has(ns):
		_ledges[ns] = {}


## 门一+门二·唯一写入洞：先验开户→类型闸→幂等写入。
## 返回：首记 true；重复记 false（值不覆盖不报错）；未开户/类型违规 false+push_error
func record(ns: StringName, id: StringName, value: Variant = true) -> bool:
	if not _claims.has(ns):
		push_error("GameSave: namespace %s 未开户即写入（须先 claim_namespace），拒写" % ns)
		return false
	if not _is_plain_value(value):
		push_error("GameSave: %s/%s 值类型 %s 非普通类型（门二类型闸），拒写"
			% [ns, id, type_string(typeof(value))])
		return false
	if not _ledges.has(ns):
		_ledges[ns] = {}  # 懒造账页（new_profile 清账后开户权仍在，可再记）
	var ledge: Dictionary = _ledges[ns]
	if ledge.has(id):
		return false
	ledge[id] = value
	recorded.emit(ns, id)   # B4.5 影子触发源：仅首记发射（重记/拒写噤声，spec §2）
	return true


func has_record(ns: StringName, id: StringName) -> bool:
	return _ledges.get(ns, {}).has(id)


## 销账（record 对偶，B4-T1/D-T1-1）：语义=合法销账（测试复原/未来剧情复位），
## 私有账本不开裸口——契约腿需要"复原未清场"等反向操作时仅此一门洞。
## 返回：确有该账目且已删除 true；无此账目 false（静默幂等，不报错）。
func erase_record(ns: StringName, id: StringName) -> bool:
	var ledge: Dictionary = _ledges.get(ns, {})
	if not ledge.has(id):
		return false
	ledge.erase(id)
	return true


## 键清单副本：改返回值不污染账本；元素恒 StringName（from_dict 归一化保证）
func ids(ns: StringName) -> Array:
	var out := []
	for key in _ledges.get(ns, {}):
		out.append(key)
	return out


## 全账清空（含 checkpoint 三件套+地点访问表）——账本唯一重置口（新开局/回环中转）。
## 设计决定：清账目不清开户登记（_claims 属代码级注册，非玩家档案数据）；
## B4.5 起 locations 同族入账——表随档案：清账=清表（spec §3 回跳改判前提）。
func new_profile() -> void:
	_ledges.clear()
	_ensure_system_ledges()
	_checkpoint_segment = &""
	_checkpoint_entry = &"default"
	_checkpoint_scene = ""
	_locations.clear()


## 快照导出：全普通类型（String 键 + 门二白名单值），JSON.stringify 直落。
## B4.5 形状扩展（向后兼容不 bump 版本，plan Global Constraints）：checkpoint 加
## 第三键 scene；顶层加 locations（[{stage_id, scene_path}]，值全 String 化）。
## 传渡旗 resume_pending 永不出现在此（D 流⑤钉）。
func to_dict() -> Dictionary:
	var ledges_out := {}
	for ns in _ledges:
		var ledge_out := {}
		for id in _ledges[ns]:
			var v: Variant = _ledges[ns][id]
			if v is Array:
				v = (v as Array).duplicate()  # 快照纯函数：数组值出拷贝，账本不外泄
			ledge_out[str(id)] = v
		ledges_out[str(ns)] = ledge_out
	var locs_out := []
	for e in _locations:
		locs_out.append({"stage_id": str(e.stage_id), "scene_path": str(e.scene_path)})
	return {
		"version": SAVE_VERSION,
		"ledges": ledges_out,
		"checkpoint": {"scene": _checkpoint_scene,
			"segment": str(_checkpoint_segment), "entry": str(_checkpoint_entry)},
		"locations": locs_out,
	}


## 快照还原：先验形（缺 version/版本不符/ledges 非字典/locations 非数组元素非字典/
## 账值过不了类型闸=整包拒收保旧账 + push_error），全有或全无；键 String→StringName
## 归一化；数值经 JSON 回环 int→float（判例同 version，B4.5 落盘侧知情，账目真值性
## 不受影响）。B4.5 形状扩展：checkpoint 缺 scene 键、顶层缺 locations 键=默认值
## （version1 向后兼容，plan Global Constraints）。
## 还原视同系统级动作：快照内未开户命名空间自动登记（owner=from_dict），
## 否则还原出的账会变成"写不进去的死账"。
## 返回（B4.5 增补，void 时代调用方零破坏）：true=已还原；false=形挫拒收现账不动
## ——SaveSystem.load_game 据此回报成败（spec §2）。
func from_dict(data: Dictionary) -> bool:
	var ver: Variant = data.get("version", null)
	# JSON 判例：parse_string 把所有数字解析为 float（int 1 回环变 1.0），
	# 故 version 认 int 与"恰等于版本号的 float"两种形态，其余一律形挫
	var ver_ok: bool = (typeof(ver) == TYPE_INT and ver == SAVE_VERSION) \
		or (typeof(ver) == TYPE_FLOAT and ver == float(SAVE_VERSION))
	if not ver_ok:
		push_error("GameSave: 快照缺 version 或版本不符（期望=%d 实际=%s），拒收保旧账"
			% [SAVE_VERSION, str(ver)])
		return false
	if typeof(data.get("ledges")) != TYPE_DICTIONARY:
		push_error("GameSave: 快照 ledges 字段形挫（%s），拒收保旧账"
			% type_string(typeof(data.get("ledges", -1))))
		return false
	var ledges_in: Dictionary = data["ledges"]
	for ns in ledges_in:
		if typeof(ledges_in[ns]) != TYPE_DICTIONARY:
			push_error("GameSave: 快照账页 %s 非字典，形挫拒收保旧账" % str(ns))
			return false
		for id in ledges_in[ns]:
			if not _is_plain_value(ledges_in[ns][id]):
				push_error("GameSave: 快照值 %s/%s 类型过不了门二（%s），形挫拒收保旧账"
					% [str(ns), str(id), type_string(typeof(ledges_in[ns][id]))])
				return false
	# locations：缺键=默认空表（形状兼容腿 D⑦钉）；有键则必须数组且元素全字典
	var locs_raw: Variant = data.get("locations", [])
	if typeof(locs_raw) != TYPE_ARRAY:
		push_error("GameSave: 快照 locations 字段形挫（%s），拒收保旧账"
			% type_string(typeof(locs_raw)))
		return false
	for e in locs_raw:
		if typeof(e) != TYPE_DICTIONARY:
			push_error("GameSave: 快照 locations 元素非字典（%s），拒收保旧账"
				% type_string(typeof(e)))
			return false
	# 验毕，开始重建
	new_profile()
	for ns in ledges_in:
		var ns_key: StringName = str(ns)
		claim_namespace(ns_key, &"from_dict")
		for id in ledges_in[ns]:
			var id_key: StringName = str(id)
			var v: Variant = ledges_in[ns][id]
			if v is Array:
				v = (v as Array).duplicate()
			_ledges[ns_key][id_key] = v
	var cp: Variant = data.get("checkpoint", {})
	if typeof(cp) == TYPE_DICTIONARY:
		# scene 缺键→""（version1 旧快照向后兼容；"" 语义=未记账）
		_checkpoint_scene = String(cp.get("scene", ""))
		_checkpoint_segment = StringName(str(cp.get("segment", "")))
		_checkpoint_entry = StringName(str(cp.get("entry", "default")))
	# locations 还魂：stage_id 转回 StringName（键 String 化落 JSON 的判例点）
	for e in locs_raw:
		_locations.append({stage_id = StringName(str(e.get("stage_id", ""))),
			scene_path = String(str(e.get("scene_path", "")))})
	return true


# ── 四账兼容层（chapter_session.gd 原签名迁入，底层=record 门洞；
#    信号语义对齐：仅首记发射）──

func add_flag(id: StringName) -> void:
	if record(NS_FLAGS, id):
		flag_added.emit(id)


func has_flag(id: StringName) -> bool:
	return has_record(NS_FLAGS, id)


## 开宝箱：首次 true（拾取方），重复 false（消费方据此决定给不给东西）
func open_chest(id: StringName) -> bool:
	if not record(NS_CHESTS, id):
		return false
	chest_opened.emit(id)
	return true


func is_chest_open(id: StringName) -> bool:
	return has_record(NS_CHESTS, id)


func mark_cleared(id: StringName) -> void:
	if record(NS_CLEARED, id):
		segment_cleared.emit(id)


func is_cleared(id: StringName) -> bool:
	return has_record(NS_CLEARED, id)


# checkpoint 三字段单独存放（不入 _ledges：非"有无型"账目而是三槽游标）
var _checkpoint_segment: StringName = &""
var _checkpoint_entry: StringName = &"default"
var _checkpoint_scene: String = ""   # ""=未记账（B4.5 读档转场目标）


## 记录检查点（B4.5 签名扩位：scene_path 缺省空）。空参**不覆写已记场景**——
## 理由：段间回跳传渡/两参旧调用（chapter_shell:261 现腿）只带段+入口，
## 若空参即抹场景，三通道共用的检查点坐标会被传渡腿洗掉（spec §4）。
## 两行都记（scene_path 非空）则覆写。发 checkpoint_recorded 三键拷贝。
func record_checkpoint(segment: StringName, entry: StringName, scene_path := "") -> void:
	_checkpoint_segment = segment
	_checkpoint_entry = entry
	if not scene_path.is_empty():
		_checkpoint_scene = scene_path
	checkpoint_recorded.emit({"scene": _checkpoint_scene,
		"segment": _checkpoint_segment, "entry": _checkpoint_entry})


func checkpoint_segment() -> StringName:
	return _checkpoint_segment


func checkpoint_entry() -> StringName:
	return _checkpoint_entry


func checkpoint_scene() -> String:
	return _checkpoint_scene


# ── B4.5 地点访问表（回跳表迁账，spec §3 裁决 R2；摘旧追新语义逐位自
#    GameEvents.add_checkpoint 搬来，T1 拆旧轨后此表为唯一存放）──
var _locations: Array[Dictionary] = []   # [{stage_id(StringName), scene_path(String)}] 尾=最新


## 地点检查点入账：同 stage_id 重入摘旧追新（保持"新→旧"渲染序稳定）
func add_location_checkpoint(stage_id: StringName, scene_path: String) -> void:
	if stage_id == &"" or scene_path.is_empty():
		push_warning("GameSave: 地点检查点参数不全，忽略 (id=%s path=%s)" % [stage_id, scene_path])
		return
	for i in _locations.size():
		if _locations[i].stage_id == stage_id:
			_locations.remove_at(i)
			break
	_locations.append({stage_id = stage_id, scene_path = scene_path})
	location_visited.emit(stage_id)


## 访问表拷贝返回（原 GameEvents.get_checkpoints；数组尾=最新访问）
func locations() -> Array[Dictionary]:
	return _locations.duplicate()


## 门二·类型闸：bool/int/float/String/StringName 白名单；
## Array 递归一层（元素须全是白名单标量）；Dictionary/Object 等其余一律拒
static func _is_plain_value(value: Variant) -> bool:
	match typeof(value):
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return true
		TYPE_ARRAY:
			for elem in value:
				match typeof(elem):
					TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
						continue
					_:
						return false
			return true
		_:
			return false


func _ensure_system_ledges() -> void:
	for ns in [NS_FLAGS, NS_CHESTS, NS_CLEARED, NS_SPELLS, NS_CHAPTERS_DONE]:
		if not _ledges.has(ns):
			_ledges[ns] = {}
