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
## S 流先行使用；T2 由 InteractSpellBook 对自己的户复查式 claim（claim 幂等，
## 重复开户静默通过）——届时在此更新备注。

signal flag_added(id: StringName)
signal chest_opened(id: StringName)
signal segment_cleared(id: StringName)

## 快照格式版本（B4.5 落盘文件同字段；不符=拒收保旧账）
const SAVE_VERSION := 1

## 系统户（GameSave 自开，spec §3 门一）
const NS_FLAGS := &"flags"
const NS_CHESTS := &"chests"
const NS_CLEARED := &"cleared_segments"
const NS_SPELLS := &"spells_known"

## 账本内部结构私有（spec §3 门三静态清点：game_save.gd 之外命中 _ledges=0）
var _ledges := {}   # ns(StringName) -> {id(StringName): value(普通类型)}
var _claims := {}   # ns(StringName) -> owner(StringName)，开户登记簿


func _ready() -> void:
	# 系统户自开（claim 幂等，故重复 _ready 亦安全）
	claim_namespace(NS_FLAGS, &"GameSave")
	claim_namespace(NS_CHESTS, &"GameSave")
	claim_namespace(NS_CLEARED, &"GameSave")
	claim_namespace(NS_SPELLS, &"GameSave")  # T0 预列决定申报见头注


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
	return true


func has_record(ns: StringName, id: StringName) -> bool:
	return _ledges.get(ns, {}).has(id)


## 键清单副本：改返回值不污染账本；元素恒 StringName（from_dict 归一化保证）
func ids(ns: StringName) -> Array:
	var out := []
	for key in _ledges.get(ns, {}):
		out.append(key)
	return out


## 全账清空（含 checkpoint 两件套）——账本唯一重置口（新开局/回环中转）。
## 设计决定：清账目不清开户登记（_claims 属代码级注册，非玩家档案数据）
func new_profile() -> void:
	_ledges.clear()
	_ensure_system_ledges()
	_checkpoint_segment = &""
	_checkpoint_entry = &"default"


## 快照导出：全普通类型（String 键 + 门二白名单值），JSON.stringify 直落
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
	return {
		"version": SAVE_VERSION,
		"ledges": ledges_out,
		"checkpoint": {"segment": str(_checkpoint_segment), "entry": str(_checkpoint_entry)},
	}


## 快照还原：先验形（缺 version/版本不符/ledges 非字典/账值过不了类型闸=
## 整包拒收保旧账 + push_error），全有或全无；键 String→StringName 归一化；
## 数值经 JSON 回环 int→float（判例同 version，B4.5 落盘侧知情，账目真值性不受影响）。
## 还原视同系统级动作：快照内未开户命名空间自动登记（owner=from_dict），
## 否则还原出的账会变成"写不进去的死账"。
func from_dict(data: Dictionary) -> void:
	var ver: Variant = data.get("version", null)
	# JSON 判例：parse_string 把所有数字解析为 float（int 1 回环变 1.0），
	# 故 version 认 int 与"恰等于版本号的 float"两种形态，其余一律形挫
	var ver_ok: bool = (typeof(ver) == TYPE_INT and ver == SAVE_VERSION) \
		or (typeof(ver) == TYPE_FLOAT and ver == float(SAVE_VERSION))
	if not ver_ok:
		push_error("GameSave: 快照缺 version 或版本不符（期望=%d 实际=%s），拒收保旧账"
			% [SAVE_VERSION, str(ver)])
		return
	if typeof(data.get("ledges")) != TYPE_DICTIONARY:
		push_error("GameSave: 快照 ledges 字段形挫（%s），拒收保旧账"
			% type_string(typeof(data.get("ledges", -1))))
		return
	var ledges_in: Dictionary = data["ledges"]
	for ns in ledges_in:
		if typeof(ledges_in[ns]) != TYPE_DICTIONARY:
			push_error("GameSave: 快照账页 %s 非字典，形挫拒收保旧账" % str(ns))
			return
		for id in ledges_in[ns]:
			if not _is_plain_value(ledges_in[ns][id]):
				push_error("GameSave: 快照值 %s/%s 类型过不了门二（%s），形挫拒收保旧账"
					% [str(ns), str(id), type_string(typeof(ledges_in[ns][id]))])
				return
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
		_checkpoint_segment = StringName(str(cp.get("segment", "")))
		_checkpoint_entry = StringName(str(cp.get("entry", "default")))


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


# checkpoint 两字段单独存放（不入 _ledges：非"有无型"账目而是双槽游标）
var _checkpoint_segment: StringName = &""
var _checkpoint_entry: StringName = &"default"


func record_checkpoint(segment: StringName, entry: StringName) -> void:
	_checkpoint_segment = segment
	_checkpoint_entry = entry


func checkpoint_segment() -> StringName:
	return _checkpoint_segment


func checkpoint_entry() -> StringName:
	return _checkpoint_entry


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
	for ns in [NS_FLAGS, NS_CHESTS, NS_CLEARED, NS_SPELLS]:
		if not _ledges.has(ns):
			_ledges[ns] = {}
