extends Node

## S2-B4 法术接入 + 存档账本体制契约（spell_save_contract，矩阵第 24 套）：
## GameSave 单账本执法五门（spec §3）的实体承载，流按任务生长（spec §5）。
## S 流（T0，本文件现状）=账本核心：
## 　门一·单一门洞——未开户 namespace 写入拒收且账本无痕，claim 后放行；
## 　门二·类型闸——Object/Dictionary/嵌套数组值拒写，bool/int/float/
## 　String/StringName/Array[StringName] 放行；
## 　幂等——record 首记 true 重复 false，has_record 跟手，ids() 为副本；
## 　JSON 兼容快照——to_dict→stringify→parse→from_dict 逐键一致，
## 　且 from_dict 后键归一化回 StringName（JSON 把键变 String 的判例点）；
## 　坏快照（缺 version/形挫/版本不符）=拒收保旧账；
## 　new_profile 全清（含 checkpoint 三件套）——账本唯一重置口；
## 　四账兼容层与 chapter_session.gd 语义逐位对齐（flag/chest/cleared/
## 　checkpoint），三信号存在且**首记才发**（connect 计数断言）。
## M 流（T1，本批在册）=壳迁移回归：shell.session 指向 /root/GameSave 单例的
## 身份钉；两壳先后（不 new_profile）账目互见=账随进程（旧"换壳=清账"判据
## 废除，spec §2）；new_profile 后清账不污染新档；erase_record 销账门洞往返
## （record→has→erase→not has→再 record 首记信号复数）。章壳腿经 container
## 的 chapter_fix 夹具（test_actor 主权消费，kit 缺席=NOTICE 大声跳过）。
## G 流（T2，本批在册）=法术生产链：SpellRegistry 约定路径解析（fire_ball 命中
## /缺件 null 降级）、反应件申报基类（InteractReaction 默认红+InteractSpellBook
## 实报 persists=[spells_known]）、出生补学（账本预记→test_actor 入树即会）、
## 《秘籍》端到端轻量腿（代码造 Trigger+Book→emit→入账+学会→二次 emit 不重发）、
## 键权现状钉腿（AI/被动档 channel 空转无劫持，spec §4"仅验证不新建机制"）；
## E 流（T3）=正式壳 fixture 生产链 E2E 施法；R 流（T3）=重演等价双跑+
## 申报单名册；X 流（T3）=静态清点——预留于流注册表 _flows，逐任务追加
## "流即函数"。
## 【豁免】无——本套不消费生产角色；M 流章壳腿复用 container 的 chapter_fix
## 夹具（内部=矩阵代管 test_actor，kit 缺席只 NOTICE 跳过、绝不代建，
## B2.5 主权法消费铁律）；ATTEST 登记随 T3 入册一并按名册裁决。
## 运行：godot --headless --path . res://tools/spell_save_contract/spell_save_contract.tscn

const NS_TEST := &"b4_contract_probe"

## M 流章壳腿依赖：container 夹具（playable_override=test_actor）+ 主权 kit
## （preload 路径引用=全局类缓存判例同款；缺席=NOTICE 大声跳腿）
const Kit := preload("res://tools/matrix_runner/test_actor_kit.gd")
const FIX_CHAPTER := "res://tools/container_contract/fixtures/chapter_fix.tscn"

## 流注册表：后续任务在数组尾追加 {key,label,fn}，_ready 循环自动消费
var _flows := [
	{"key": "S", "label": "S 流 账本核心", "fn": "flow_save_core"},
	{"key": "M", "label": "M 流 壳迁移回归", "fn": "flow_migration"},
	{"key": "G", "label": "G 流 法术接入", "fn": "flow_spells"},
]

var _fails := 0
var _flow_done := {}
## GameSave autoload 引用（无 class_name 故不静态定型，动态调用；
## RED 期/缺席 = null → S0 可读红，不靠 Parse Error 炸整脚本）
var _save

# 信号计数（判例：lambda 按值捕获局部变量，计数一律走成员变量）
var _sig_flag := 0
var _sig_chest := 0
var _sig_cleared := 0


func _ready() -> void:
	for flow in _flows:
		await call(flow.fn)
		# 判例（AGENTS）：子协程运行时炸掉后主协程照常续跑到汇总——每流完成旗单独锁
		_check(_flow_done.get(flow.key, false), "%s 全序列执行完成（协程静默中断防线）" % flow.label)
	print("════════ spell-save-contract: %s ════════" % ("PASS" if _fails == 0 else "FAIL"))
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails += 1
	print("  %s: %s" % ["PASS" if ok else "FAIL", label])


func _on_flag_added(_id: StringName) -> void:
	_sig_flag += 1


func _on_chest_opened(_id: StringName) -> void:
	_sig_chest += 1


func _on_segment_cleared(_id: StringName) -> void:
	_sig_cleared += 1


func flow_save_core() -> void:
	_save = get_node_or_null(^"/root/GameSave")
	_check(_save != null, "S0 GameSave autoload 在场（scene runner 必在场，缺席=plan 假设错上报）")
	if _save == null:
		_flow_done["S"] = false
		return  # 无账本不硬闯：后续腿依赖账本本体，S0+完成旗双红即完整 RED 证据

	# ── S1 门一·单一门洞：未开户拒写无痕，claim 后放行且开户幂等 ──
	# （预期噪音：本段门洞/类型闸/坏快照各腿按宪章打 push_error 中文报错=被试行为）
	var ghost_ns := &"b4_not_claimed_ns"
	var ghost_ret: bool = _save.record(ghost_ns, &"x")
	_check(ghost_ret == false, "S1a 未开户 ns 写入返回 false（实际=%s）" % str(ghost_ret))
	_check(_save.has_record(ghost_ns, &"x") == false, "S1b 未开户 ns 拒写后账本无痕（has_record false）")
	_check(_save.ids(ghost_ns).is_empty(), "S1c 未开户 ns ids 为空数组（实际=%s）" % str(_save.ids(ghost_ns)))
	_save.claim_namespace(NS_TEST, &"spell_save_contract")
	_check(_save.record(NS_TEST, &"first") == true, "S1d claim_namespace 开户后 record 成功")
	_save.claim_namespace(NS_TEST, &"other_owner")  # 再开户应幂等静默（不炸不换手不扰账）
	_check(_save.record(NS_TEST, &"first") == false, "S1e 重复开户幂等·前账不受扰（同键再记 false）")

	# ── S2 幂等账目：has_record 跟手，ids 返回 StringName 且为副本 ──
	_check(_save.has_record(NS_TEST, &"first") == true, "S2a has_record 跟手为真")
	var ids1: Array = _save.ids(NS_TEST)
	_check(ids1.size() == 1 and ids1[0] == &"first", "S2b ids 键清单含 first（实际=%s）" % str(ids1))
	_check(ids1[0] is StringName, "S2c ids 元素是 StringName（实际类型=%s）" % type_string(typeof(ids1[0])))
	ids1.append(&"polluted")
	_check(_save.ids(NS_TEST).size() == 1, "S2d ids 是副本：外改返回值不污染账本（重取 size 实际=%d）" % _save.ids(NS_TEST).size())
	_check(_save.has_record(NS_TEST, &"polluted") == false, "S2e ids 副本：污染键未入账")

	# ── S3 门二·类型闸：Object/Dictionary/嵌套数组拒写，白名单放行 ──
	var junk := Node.new()
	_check(_save.record(NS_TEST, &"v_node", junk) == false, "S3a Object 值（Node.new()）拒写 false")
	_check(_save.has_record(NS_TEST, &"v_node") == false, "S3b 拒写值无痕（不入账）")
	junk.free()
	_check(_save.record(NS_TEST, &"v_dict", {"a": 1}) == false, "S3c Dictionary 值拒写 false")
	_check(_save.record(NS_TEST, &"v_nested", [[&"a"]]) == false, "S3d 嵌套数组（二层非白名单）拒写 false")
	_check(_save.record(NS_TEST, &"v_bool", true) == true, "S3e bool 通过")
	_check(_save.record(NS_TEST, &"v_int", 7) == true, "S3f int 通过")
	_check(_save.record(NS_TEST, &"v_float", 1.5) == true, "S3g float 通过")
	_check(_save.record(NS_TEST, &"v_str", "hello") == true, "S3h String 通过")
	_check(_save.record(NS_TEST, &"v_sn", &"sn") == true, "S3i StringName 通过")
	var arr: Array[StringName] = [&"a", &"b"]
	_check(_save.record(NS_TEST, &"v_arr", arr) == true, "S3j Array[StringName] 通过")

	# ── S6 四账兼容层：与 chapter_session.gd 语义逐位对齐 + 信号首记才发 ──
	_save.flag_added.connect(_on_flag_added)
	_save.chest_opened.connect(_on_chest_opened)
	_save.segment_cleared.connect(_on_segment_cleared)
	_check(_save.NS_FLAGS == &"flags" and _save.NS_CHESTS == &"chests"
		and _save.NS_CLEARED == &"cleared_segments" and _save.NS_SPELLS == &"spells_known",
		"S6a 系统户常量名册=[flags, chests, cleared_segments, spells_known]（NS_SPELLS 系 T0 预列，T2 秘籍复查开户）实际=%s/%s/%s/%s"
		% [str(_save.NS_FLAGS), str(_save.NS_CHESTS), str(_save.NS_CLEARED), str(_save.NS_SPELLS)])
	_check(_save.has_flag(&"f_probe") == false, "S6b 新档 flags 空（对齐 chapter_session 空表起点）")
	_save.add_flag(&"f_probe")
	_save.add_flag(&"f_probe")  # 重复 add 不重发信号（chapter_session 同形）
	_check(_save.has_flag(&"f_probe") == true, "S6c add_flag/has_flag 对齐")
	_check(_sig_flag == 1, "S6d flag_added 仅首记发射（计数实际=%d）" % _sig_flag)
	_check(_save.open_chest(&"c_probe") == true, "S6e open_chest 首次 true（拾取方）")
	_check(_save.open_chest(&"c_probe") == false, "S6f open_chest 重复 false（消费方据此不吐宝）")
	_check(_save.is_chest_open(&"c_probe") == true, "S6g is_chest_open")
	_check(_save.has_record(_save.NS_CHESTS, &"c_probe") == true, "S6h chests 账同源一致（兼容层底层=record 门洞）")
	_check(_sig_chest == 1, "S6i chest_opened 仅首记发射（计数实际=%d）" % _sig_chest)
	_save.mark_cleared(&"seg_probe")
	_save.mark_cleared(&"seg_probe")
	_check(_save.is_cleared(&"seg_probe") == true, "S6j mark_cleared/is_cleared 对齐")
	_check(_sig_cleared == 1, "S6k segment_cleared 仅首记发射（计数实际=%d）" % _sig_cleared)
	_check(_save.checkpoint_segment() == &"" and _save.checkpoint_entry() == &"default",
		"S6l 初始 checkpoint=空段+default 入口（对齐 chapter_session 空表默认值）实际=%s/%s"
		% [str(_save.checkpoint_segment()), str(_save.checkpoint_entry())])

	# ── S4 JSON 兼容快照回环（B4.5 落盘日=一个字典写盘的前置门）──
	_save.record_checkpoint(&"seg_rt", &"entry_rt")
	var snap_text := JSON.stringify(_save.to_dict())
	var snap: Dictionary = JSON.parse_string(snap_text)
	_check(int(snap.get("version", -1)) == 1, "S4a to_dict 含 version=1（JSON 后仍是 int，实际=%s）" % type_string(typeof(snap.get("version", -1))))
	_save.new_profile()
	_check(_save.has_record(NS_TEST, &"first") == false, "S4b 回环前先清账（证明还原真写账，防假绿）")
	_save.from_dict(snap)
	_check(_save.has_record(NS_TEST, &"first") == true, "S4c 回环后逐键行为一致（first）")
	_check(_save.has_record(NS_TEST, &"v_arr") == true, "S4d 回环后数组值账恢复")
	_check(_save.has_flag(&"f_probe") == true, "S4e 回环后 flags 系统户恢复")
	_check(_save.is_chest_open(&"c_probe") == true, "S4f 回环后 chests 系统户恢复")
	_check(_save.is_cleared(&"seg_probe") == true, "S4g 回环后 cleared 系统户恢复")
	_check(_save.checkpoint_segment() == &"seg_rt" and _save.checkpoint_entry() == &"entry_rt",
		"S4h 回环后 checkpoint 两件套还原（实际=%s/%s）" % [str(_save.checkpoint_segment()), str(_save.checkpoint_entry())])
	var rt_ids: Array = _save.ids(NS_TEST)
	var all_sn := true
	for sid in rt_ids:
		if not (sid is StringName):
			all_sn = false
	_check(all_sn and not rt_ids.is_empty(), "S4i from_dict 后键归一化回 StringName（JSON 判例点：键变 String 必归一，实际=%s）" % str(rt_ids))
	# 坏快照三连拒收保旧账（预期 push_error 各一条=被试行为）
	_save.from_dict({"ledges": {}})
	_check(_save.has_record(NS_TEST, &"first") == true, "S4j 缺 version 坏快照=拒收保旧账")
	_save.from_dict({"version": 1, "ledges": 5})
	_check(_save.has_record(NS_TEST, &"first") == true, "S4k ledges 非字典坏快照=拒收保旧账")
	_save.from_dict({"version": 99})
	_check(_save.has_record(NS_TEST, &"first") == true, "S4l version 不符坏快照=拒收保旧账")

	# ── S5 new_profile 全清（账本唯一重置口，spec §2 开局=新开局语义）──
	_save.new_profile()
	_check(_save.has_flag(&"f_probe") == false, "S5a 清账后 flags 空")
	_check(_save.is_chest_open(&"c_probe") == false, "S5b 清账后 chests 空")
	_check(_save.is_cleared(&"seg_probe") == false, "S5c 清账后 cleared 空")
	_check(_save.ids(NS_TEST).is_empty(), "S5d 清账后非系统户账目空（实际=%s）" % str(_save.ids(NS_TEST)))
	_check(_save.checkpoint_segment() == &"" and _save.checkpoint_entry() == &"default",
		"S5e 清账含 checkpoint 三件套回默认（实际=%s/%s）" % [str(_save.checkpoint_segment()), str(_save.checkpoint_entry())])
	_check(_save.open_chest(&"c_probe") == true, "S5f 清账=新档：同宝箱可再开（首记语义复位）")
	_check(_sig_chest == 2, "S5g 新档重开照发 chest_opened（计数实际=%d，首记才发规则不因清账失效）" % _sig_chest)
	_save.new_profile()  # 测试自洁：探针键不外溢后续流/他套（单例账随进程）

	_flow_done["S"] = true


# ── M 流（T1）：壳迁移回归（spec §5/§6；D-T1-6 三腿制）──

func _m_frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


## 章壳建造体（**不含** new_profile——M1c/M1d 要的正是"换壳不建档=保账"面；
## 流水起点的清账由 flow_migration 头部显式供给，与 container/interact 的
## 建壳 helper 同款隔离规约，只是本套刻意把两者拆开各演一面）
func _m_make_shell() -> ChapterShell:
	var shell: ChapterShell = (load(FIX_CHAPTER) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(shell)
	await _m_frames(20)
	return shell


func flow_migration() -> void:
	GameSave.new_profile()   # B4-T1 隔离规约：建壳流水起点清账
	_save = get_node_or_null(^"/root/GameSave")
	_check(_save != null, "M0 GameSave autoload 在场（scene runner 恒在场；缺席=S0 同红）")
	if _save == null:
		_flow_done["M"] = false
		return

	if not Kit.exists():
		print("  NOTICE: 跳过 M1/M2 章壳腿——test_actor 替身缺席，chapter_fix 夹具"
				+ "不可解析（处方：bash tools/matrix_runner/run_matrix.sh "
				+ "--ensure-only 建好替身后复跑；壳无关腿 M0/M3 照跑）")
	else:
		# ── M1 单例本性钉死：两壳先后，A 记账 B 不建档仍见 ──
		var shell_a := await _m_make_shell()
		_check(shell_a.session == _save,
				"M1a shell.session 指向 /root/GameSave 单例（迁移身份钉）")
		_check(shell_a.session.open_chest(&"m_solo_chest") == true,
				"M1b 壳 A 经 session 开宝箱首记 true")
		shell_a.queue_free()
		await _m_frames(6)
		var shell_b := await _m_make_shell()   # 故意不 new_profile=换壳保账面
		_check(shell_b.session.has_record(_save.NS_CHESTS, &"m_solo_chest") == true,
				"M1c 换壳不 new_profile 仍见旧账（账随进程——旧'新壳=新账'判据"
				+ "废除，B4-T1 改判，spec §2）")
		_check(shell_b.session.open_chest(&"m_solo_chest") == false,
				"M1d 壳 B 重复开 false（重建节点不再吐宝）")
		shell_b.queue_free()
		await _m_frames(6)
		# ── M2 新档=清账、档间互不污染 ──
		GameSave.new_profile()
		_check(_save.has_record(_save.NS_CHESTS, &"m_solo_chest") == false,
				"M2a new_profile 后旧档宝箱清零（new_profile=清账唯一口）")
		_check(_save.open_chest(&"m_solo_chest") == true,
				"M2b 新档同键首记 true（换壳不建档=保账 / 建档=清账，两面对偶）")

	# ── M3 erase_record 销账门洞往返（D-T1-1：record 对偶，不开裸字典口）──
	var cnt := {"flag": 0}   # 字典引用捕获判例（lambda 对标量捕获=拷贝不适用）
	var cb := func(_id): cnt["flag"] += 1
	_save.flag_added.connect(cb)
	_check(_save.has_flag(&"m_erase") == false, "M3a 新档旗标空")
	_save.add_flag(&"m_erase")
	_check(int(cnt["flag"]) == 1 and _save.has_flag(&"m_erase") == true,
			"M3b add_flag 首计入账+信号恰一")
	_check(_save.erase_record(_save.NS_FLAGS, &"m_erase") == true,
			"M3c 有账销账返回 true")
	_check(_save.has_flag(&"m_erase") == false, "M3d 销账后 has_record false")
	_check(_save.erase_record(_save.NS_FLAGS, &"m_erase") == false,
			"M3e 无账再销 false（幂等静默，不报错）")
	_save.add_flag(&"m_erase")   # 销账后重记=首记（信号复数计数）
	_check(int(cnt["flag"]) == 2 and _save.has_flag(&"m_erase") == true,
			"M3f 销账后重记走首记语义：信号计数复数（实际=%d）" % int(cnt["flag"]))
	_save.flag_added.disconnect(cb)

	GameSave.new_profile()   # 测试自洁：M 流探针键不外溢（单例账随进程）
	_flow_done["M"] = true


# ── G 流（T2）：法术生产链（spec §4；registry/申报单/秘籍/补学/键权现状）──
# 新件一律 load() 动态引用（判例：S0 红期不靠 Parse Error 炸整脚本——
# SpellRegistry/InteractSpellBook 等 class_name 未出生时本流须能跑出可读红）

const REGISTRY_PATH := "res://spells/_base/spell_registry.gd"
const REACTION_BASE_PATH := "res://scripts/chapter/reactions/interact_reaction.gd"
const SPELL_BOOK_PATH := "res://scripts/chapter/reactions/interact_spell_book.gd"
const TRIG_SCENE := "res://scenes/chapter/interact_trigger.tscn"
const SPAR_SCENE := "res://characters/enemies/spar_enemy/spar_enemy.tscn"
const VENDOR_SCENE := "res://characters/neutrals/street_vendor/street_vendor.tscn"


## raw 键注入（B3-T2 判例：down 事件逐字段显式写，禁依赖 pressed 默认值；
## keycode+physical 双填、device=-1 对齐绑定文本，block_parry _press_key 同形制）
func _g_press_key(p_key: int, p_pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.device = -1
	ev.keycode = p_key
	ev.physical_keycode = p_key
	ev.pressed = p_pressed
	Input.parse_input_event(ev)


func flow_spells() -> void:
	GameSave.new_profile()
	_save = get_node_or_null(^"/root/GameSave")
	_check(_save != null, "G0 GameSave autoload 在场（scene runner 恒在场）")
	if _save == null:
		_flow_done["G"] = false
		return

	# ── G1 SpellRegistry：约定路径命中 fire_ball；缺件 null+push_warning 不崩 ──
	var reg: GDScript = load(REGISTRY_PATH)
	_check(reg != null, "G1a SpellRegistry 脚本在场（%s）" % REGISTRY_PATH)
	if reg != null:
		var def = reg.definition_for(&"fire_ball")
		_check(def != null, "G1b definition_for(fire_ball) 非 null（约定路径=SpellCreator 产线镜像）")
		if def != null:
			_check(def.spell_id == &"fire_ball",
					"G1c 解析出的 def.spell_id==fire_ball（实际=%s）" % str(def.spell_id))
		var ghost_def = reg.definition_for(&"no_such_spell_zzz")
		_check(ghost_def == null,
				"G1d 缺件 spell 返回 null 不崩（push_warning 中文=被试行为）")

	# ── G2 反应件申报基类 + 秘籍件申报单 ──
	var base: GDScript = load(REACTION_BASE_PATH)
	_check(base != null, "G2a InteractReaction 基类脚本在场")
	if base != null:
		var probe = base.new()   # 无 class_name 编译期引用：动态调用（红期不炸解析）
		var claim0: Dictionary = probe.save_claim()   # 基类默认=push_error+空单（门三）
		_check(claim0.is_empty(),
				"G2b 基类默认 save_claim 返回空字典（push_error 响=被试行为，子类必须申报）")
		probe.free()
	var bs: GDScript = load(SPELL_BOOK_PATH)
	_check(bs != null, "G2c InteractSpellBook 脚本在场")
	if bs != null and base != null:
		_check(bs.get_base_script() == base,
				"G2d InteractSpellBook 挂 InteractReaction 基类（申报门对新生件即时生效）")
		var book = bs.new()
		var claim: Dictionary = book.save_claim()
		_check(claim.get(&"persists", []) == [_save.NS_SPELLS]
				and claim.get(&"resets", []) == [],
				"G2e 秘籍件申报单 persists=[spells_known]/resets=[]（实际=%s）" % str(claim))
		book.free()

	# ── 替身门（消费铁律 B2.5）：G3/G4 需要 test_actor（模板同文双写的产线
	# 镜像验证主体）；peek() 只读三态，缺席/未导入=NOTICE 大声跳腿不代建 ──
	var actor_ready: bool = Kit.peek() == Kit.READY
	if not actor_ready:
		print("  NOTICE: 跳过 G3/G4 补学与秘籍腿——test_actor 非就绪态（peek=%d，" % Kit.peek()
				+ "处方：bash tools/matrix_runner/run_matrix.sh --ensure-only）；"
				+ "G1/G2/G5 与键权腿照跑")

	if actor_ready:
		# ── G3 出生补学：账本预记→替身入树即会（节点会重建、账不重建，spec §4）──
		_check(_save.record(_save.NS_SPELLS, &"fire_ball") == true,
				"G3a 预记 spells_known/fire_ball 首记 true")
		var actor: QuiverCharacter = load(Kit.ACTOR_SCENE).instantiate()
		get_tree().root.add_child.call_deferred(actor)
		await _m_frames(6)
		var sm: SpellManager = actor.get_spell_manager()
		_check(sm != null, "G3b 替身 spell_manager 在场（补学块挂在 _spell_manager 之后）")
		if sm != null:
			var slot0: SpellSlot = sm.get_spell_slot(0)
			_check(slot0 != null and not slot0.is_empty(),
					"G3c 出生补学腿：账本有账→入树即会（slot0 非空）")
			if slot0 != null and not slot0.is_empty():
				_check(slot0.definition.spell_id == &"fire_ball",
						"G3d 补学内容=账本键对应的 registry 产物（实际=%s）"
						% str(slot0.definition.spell_id))
		actor.free()
		GameSave.new_profile()   # 自洁：不留账防 G4 首记语义被污染

		# ── G4 秘籍件端到端（轻量，代码造件）：emit→入账+学会→二次 emit 不重发──
		# （真键盘 E2E 归 T3 E 流 raw 键腿，本腿钉反应件合同形制）
		var shell := await _m_make_shell()
		var trig: InteractTrigger = (load(TRIG_SCENE) as PackedScene).instantiate()
		if bs != null:
			var book2 = bs.new()
			book2.spell_id = &"fire_ball"   # manual_id 留空=回落 spell_id 作账本键
			trig.add_child(book2)
			shell.add_child(trig)
			await _m_frames(2)
			trig.interacted.emit()
			trig.interacted.emit()   # 同帧二发：first=false 腿（不重学）
			_check(_save.has_record(_save.NS_SPELLS, &"fire_ball") == true,
					"G4a 触发后账本 has_record(spells_known, fire_ball)")
			_check(_save.ids(_save.NS_SPELLS).size() == 1,
					"G4b 二次触发不重记账（ids size==1，实际=%s）"
					% str(_save.ids(_save.NS_SPELLS)))
			var psm: SpellManager = shell.playable.get_spell_manager()
			_check(psm != null and not psm.get_spell_slot(0).is_empty(),
					"G4c 首触发即学会（playable slot0 非空）")
			if psm != null:
				_check(psm.get_spell_slot(1).is_empty(),
						"G4d 二次触发不重学（slot1 仍空=槽不超发）")
			# 消失演出尾巴：0.4s tween 后 trig queue_free——等它收场再拆壳（防孤儿报错）
			await _m_frames(30)
		shell.queue_free()
		await _m_frames(6)
		GameSave.new_profile()

	# ── G5 键权现状钉腿（spec §4"仅加验证腿钉住现状，不新建机制"）──
	# 现状实读：模板壳法术键只经私有输入通道 channel.just_pressed 读取（无
	# 全局键盘监听、无 _unhandled_input 直读），非玩家行为档不向 channel 盖戳
	# ——raw 键注入下 AI/被动出生无 spell 键劫持（quiver_behavior_ai/idle 零
	# _unhandled_input 盖戳路径，player 档才有）。
	var spar: QuiverCharacter = load(SPAR_SCENE).instantiate()
	var vendor: QuiverCharacter = load(VENDOR_SCENE).instantiate()
	get_tree().root.add_child.call_deferred(spar)
	get_tree().root.add_child.call_deferred(vendor)
	await _m_frames(6)
	_g_press_key(KEY_1, true)
	_g_press_key(KEY_1, false)
	await _m_frames(3)
	var no_hijack := true
	for ch in [spar, vendor]:
		if ch.channel != null and ch.channel.just_pressed("spell_1"):
			no_hijack = false
		if str(ch.state_machine.state_name).contains("Cast"):
			no_hijack = false
	_check(no_hijack,
			"G5 现状钉腿：AI/被动档 raw 按 1 后 channel 无戳、状态非 Cast"
			+ "（现状：非玩家档 channel 空转无劫持）")
	spar.free()
	vendor.free()

	GameSave.new_profile()   # 测试自洁：G 流探针键不外溢（单例账随进程）
	_flow_done["G"] = true
