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
## 键权现状钉腿（AI/被动档 channel 空转无劫持，spec §4"仅验证不新建机制"）、
## G7 learn_spell 契约三式（B4.5-T3 立法腿，spec §5：null 拒学/正常占槽/同学科
## 去重——裸 SpellManager 形制，与 G3/G4 账本预记腿零互作）；
## G8 分户键值维补学通（B4.5-T4 修复波：manual_id≠spell_id 装配→record 带值→
## value_of 读门洞→补学值优先回落键；走盘 JSON 回环 String 支+B4 老式账兼容面）；
## E 流（T3，本批在册）=正式壳 fixture 生产链施法 E2E：加载章壳夹具
## （playable_override=test_actor，替身缺席=NOTICE 大声跳腿）→ 驱动替身入秘籍触发区
## → trig.interacted.emit() 经 InteractSpellBook 生产链学会 → raw 数字键1（原始按键
## 直投，B3-T2 判例）→ 硬钉①进入 Ground/Cast 施法态 → 硬钉②场上生成 SpellBase 弹体
## → 敌血下降 best-effort（命中时序脆弱面，未捕获=NOTICE 据实报，红据留 T3b R8 验）；
## R 流（T3，本批在册）=重演等价：脚本序列采指纹 v1→内存假存档回环（to_dict→JSON→
## from_dict）→ v2 断言入册项逐位不变（门四主力面）；new_profile→ v3 全 false/空
## （新档=清账，cleared 归零=未来该段未清将丢弃重建的 ledger 侧证据）；申报单联动
## （遍历 X③名册逐 persists 户 record→回环→has_record 真，逐户执法非硬编码）；
## 逐类申报形制回归锁（据实比对 persists/resets + 点名供 X③）；NIT-1 探针一次性信号
## 形制示范。
## D 流（B4.5-T0，本批在册）=SaveSystem 影子落盘真盘腿（spec §2/§6）：scratch 注入
## →record→帧尾后文件存在且 JSON version1、与账本逐键一致；new_profile→load_game
## 还原真写账（R 流"还原真写"判例沿用）；写垃圾=load_game false 且现账无损；无档
## has_save false；resume_pending 置真后 to_dict 不含它（传渡条款钉死）；无 .tmp
## 残骸；生产槽零污染总断腿（T1 A2 形制改判：套头重定向+清 scratch+清生产槽名，
## 套尾删净 scratch、D9b 断生产槽不存在——单机自证，跨套防线在各套 scratch 重定向）。
## P 流（B4.5-T2，本批在册）=读档管线拆段腿（spec §4；标题钮真点击链归 F5）：
## 无旗对照落位 _order[0] + enter_segment 生产腿带 scene 入检查点行为锁；scratch
## 落含 checkpoint 的档→new_profile 清零→load_game 三件套还原→置 resume_pending
## 直建壳=「继续钮后半场」的拆段等价（落位检查点段+入口位、旗 first-wins 消费、
## 坏段（不在 _order）push_error 响亮回退首段且照样消费；通关入账：resume 落终点段
## →判清→终点墙同步链（container H6 判例）→chapter_finished 恰一次+chapters_done
## 首记入账+影子带盘（scratch 文件含该户键）；P6 旗滞留惰性面（B4.5-T4：场景不
## 命中→旗原样留，消费判据的未命中半面钉死）。全部壳腿吃 chapter_fix 夹具（test_actor
## 主权，kit 缺席=NOTICE 大声跳腿，M1 形制）。
## X 流（T3，本批在册，压轴）=静态清点：①账本私有域绕门裸写全仓扫描
## （game_save.gd 之外命中=0，被禁 token 运行期拼接不自伤）+ 旧公共字典形态=0；
## ②reactions/ 每 class_name 件必实存 save_claim；③申报名册=报表（DirAccess+基类
## 反射派生，逐类打印 persists/resets，并断言每类被 G/R/E 至少一根腿点名）；
## ④R-T2b「-s 无 autoload load 不炸」轻腿（@tool 角色脚本只 load 断非空、绝不 .new()）。
## 【豁免】无——本套不消费生产角色；M 流章壳腿复用 container 的 chapter_fix
## 夹具（内部=矩阵代管 test_actor，kit 缺席只 NOTICE 大声跳过、绝不代建，
## B2.5 主权法消费铁律）；T3b 入册：ATTEST 登记 ACTOR-GATE（_ready 头部只读
## 三态守卫就绪喊行，矩阵 M4 见证；缺席态不另加红、维持各流 NOTICE 跳腿形制）。
## 运行：godot --headless --path . res://tools/spell_save_contract/spell_save_contract.tscn

const NS_TEST := &"b4_contract_probe"
## D 流 scratch 槽（B4.5 测试卫生条款，spec §2）：全套落盘腿只读写此文件，
## 永不触碰 AUTOSAVE_PATH 生产档
const SCRATCH_D := "user://b45_d_stream.json"
## D 流探针户（plan Task0 Step2 钉名）
const NS_D := &"b45_probe"
## P3b 落位 y 容差（B4.5-T4 A4 裁定：常量化于套内、非生产常量——生产无此数值，
## 跨文件固化会伪造"生产语义"；64.0=物理沉降窗实校准：出生 (500,600)→20 物理帧
## 稳定后 ≈579.93，地板/高度层吸附所致，x 恒精确；改判历史=T2 首跑绿期校准注）
const RESUME_LAND_TOL := 64.0

## M 流章壳腿依赖：container 夹具（playable_override=test_actor）+ 主权 kit
## （preload 路径引用=全局类缓存判例同款；缺席=NOTICE 大声跳腿）
const Kit := preload("res://tools/matrix_runner/test_actor_kit.gd")
const FIX_CHAPTER := "res://tools/container_contract/fixtures/chapter_fix.tscn"
## E 流正式壳夹具（T3）：chapter_shell + seg_b4_manual（秘籍触发件+spar 敌），
## playable_override=test_actor（B2.5 主权法：替身缺席=NOTICE 大声跳腿不代建）
const FIX_B4_CHAPTER := "res://tools/spell_save_contract/fixtures/chapter_b4.tscn"

## 流注册表：后续任务在数组尾追加 {key,label,fn}，_ready 循环自动消费
var _flows := [
	{"key": "S", "label": "S 流 账本核心", "fn": "flow_save_core"},
	{"key": "M", "label": "M 流 壳迁移回归", "fn": "flow_migration"},
	{"key": "G", "label": "G 流 法术接入", "fn": "flow_spells"},
	{"key": "E", "label": "E 流 施法端到端", "fn": "flow_cast_e2e"},
	{"key": "R", "label": "R 流 重演等价", "fn": "flow_replay_equiv"},
	{"key": "D", "label": "D 流 影子落盘", "fn": "flow_disk"},
	{"key": "P", "label": "P 流 读档管线", "fn": "flow_resume"},
	# X 流压轴：其③"每反应件类名须被 G/R/E 至少一根腿点名"依赖前流执行期
	# 登记的 _named_by_streams，故必须排在所有行为流之后（D/P 流不点名反应件，
	# 置于 X 前不破坏该依赖）。
	{"key": "X", "label": "X 流 静态清点", "fn": "flow_static_scan"},
]

var _fails := 0
var _flow_done := {}

## X 流③登记面：各行为腿用 _name_class() 显式点名的反应件类名集合
## （非由目录名册派生——新件被忘记点名时，目录扫描会把它纳入名册却查无名点
##  → 响亮红，此即 spec §3 门三"新件零重演腿"的机器执法）。
var _named_by_streams := {}
## X 流③派生的申报名册：class_name(String) -> {persists:Array, resets:Array, path:String}
## R 流"申报单联动"遍历此名册取每类的 persists/resets 户做真写回读。
var _x_roster := {}
## GameSave autoload 引用（无 class_name 故不静态定型，动态调用；
## RED 期/缺席 = null → S0 可读红，不靠 Parse Error 炸整脚本）
var _save
## SaveSystem autoload 引用（B4.5 D 流，同款动态引用形制：无 class_name，
## 全经 get_node_or_null——scene runner 恒在场，缺席=D0 响亮红）
var _sys

# 信号计数（判例：lambda 按值捕获局部变量，计数一律走成员变量）
var _sig_flag := 0
var _sig_chest := 0
var _sig_cleared := 0


func _ready() -> void:
	# B4.5 测试卫生条款（spec §2）：影子落盘一律吃 scratch——S/M/G/E/R 真写账同样
	# 触发泛信号，帧尾合并落盘绝不许碰生产槽（D9b 单机自证，T1 A2 形制改判）。
	# RED 期 stub 无 slot_path/save_now → 静默跳过本行，缺席态由 D0 响亮报红。
	_sys = get_node_or_null(^"/root/SaveSystem")
	if _sys != null and _sys.has_method("delete_save") and _sys.has_method("save_now"):
		_sys.slot_path = SCRATCH_D
		_sys.delete_save()   # 套头起手清场（scratch 不带上轮残骸）
		# B4.5-T1 A2 形制改判：生产槽名也经 delete_save 起手清掉（借道 slot_path
		# 即删即回，只删生产档+其 .tmp 残骸，其余 scratch 不动；同帧无 await
		# 引擎无法在借道窗口排入帧尾落盘）——D9b 由此单机自证，不再依赖矩阵内套序
		_sys.slot_path = PROD_SLOT
		_sys.delete_save()
		_sys.slot_path = SCRATCH_D
	# T3b 入册身份见证（M4）：只读三态守卫（peek 零副作用），就绪才喊
	# ACTOR-GATE；非就绪不另加红——缺席跳腿维持各流既有 NOTICE 形制（B2.5）
	if Kit.peek() == Kit.READY:
		print("ACTOR-GATE: test_actor 就绪（只读三态守卫通过）")
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
	# NIT-1（R-T1a 硬化）：S6 探针信号到此用尽，立即断连——单例信号跨流常驻会
	# 让后续 M/G/E/R 流真写账目时把 _sig_* 计数继续往上顶（虽本流断言已跑完，
	# 但"连着不摘"是脆弱态，示范 M3 的一次性形制）。
	_save.flag_added.disconnect(_on_flag_added)
	_save.chest_opened.disconnect(_on_chest_opened)
	_save.segment_cleared.disconnect(_on_segment_cleared)
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

		# ── G6 外观判重（用户 F5 裁决 2026-09-25，spec §4 注记）：一次性知识件
		# 学会后禁止再弹"拾取秘籍"——死亡段重跑/段重建后本件出生帧即整体消失
		# （账本有账→触发件 queue_free）。G6a 负对照（无账→正常在场）判重腿非真空 ──
		var bs6: GDScript = load(SPELL_BOOK_PATH)
		var shell6 := await _m_make_shell()
		var trig_ok: InteractTrigger = (load(TRIG_SCENE) as PackedScene).instantiate()
		var book_ok = bs6.new()
		book_ok.spell_id = &"fire_ball"
		trig_ok.add_child(book_ok)
		shell6.add_child(trig_ok)
		await _m_frames(3)
		_check(is_instance_valid(trig_ok),
				"G6a 无账：秘籍触发件正常在场（负对照=判重腿非真空）")
		_check(_save.record(_save.NS_SPELLS, &"fire_ball") == true,
				"G6a' 预记账本首记 true（构造已学会世界）")
		var trig_gone: InteractTrigger = (load(TRIG_SCENE) as PackedScene).instantiate()
		var book_gone = bs6.new()
		book_gone.spell_id = &"fire_ball"
		trig_gone.add_child(book_gone)
		shell6.add_child(trig_gone)
		await _m_frames(3)
		_check((not is_instance_valid(trig_gone)) or trig_gone.is_queued_for_deletion(),
				"G6b 有账：秘籍触发件出生帧即消失（学会过=外观不复活，F5 眼③改判）")
		if is_instance_valid(trig_ok):
			trig_ok.free()
		shell6.free()
		await _m_frames(4)
		GameSave.new_profile()

		# ── G8 分户键值维补学通（B4.5-T4 修复波第一件，T3 移交"manual_id 分户
		# 键补学断线"案偿）：装配现场=manual_id≠spell_id 的秘籍——键=拾得事件
		# 户名、值=教什么学科（spell_id）。旧断线两式：①秘籍 record 不带值
		# （值=true 无学科信息）；②补学循环把账本键当科目名 definition_for
		# （户名必 null→静默不学）。修法：record 带值+GameSave.value_of 读门洞
		# +补学值优先回落键。腿组形制（红档可读性优先——判决位一律 str()/短路
		# and 干净 FAIL 不崩流，value_of 缺 API 崩红压轴，红期前序腿信息不淹；
		# String(v) 构造器对 bool/Array 是运行时炸而非转换，判例=首轮红档实锤，
		# 一律用 str()）：
		var shell8 := await _m_make_shell()
		var trig8: InteractTrigger = (load(TRIG_SCENE) as PackedScene).instantiate()
		var book8 = bs6.new()
		book8.spell_id = &"fire_ball"
		book8.manual_id = &"ch0_x_manual"   # 分户装配：户名≠科目名（G1d 判例=definition_for(户名) 必 null）
		trig8.add_child(book8)
		shell8.add_child(trig8)
		await _m_frames(2)
		trig8.interacted.emit()
		_check(_save.ids(_save.NS_SPELLS).size() == 1
				and _save.ids(_save.NS_SPELLS)[0] == &"ch0_x_manual",
				"G8a 分户秘籍拾取：账本键=户名非科目名（键面既有判据口径不变，D/G 旧腿零破坏）")
		# 值面判据经 to_dict 公共快照读（红期不借 value_of——此腿旧码干净 FAIL：
		# 值=true 无学科信息=断线一实证；绿期翻绿=record 带值立法生效）
		var led8: Dictionary = _save.to_dict().get("ledges", {}).get(str(_save.NS_SPELLS), {})
		_check(str(led8.get("ch0_x_manual", "")) == "fire_ball",
				"G8b 秘籍记账带值维：快照值=spell_id 非 true（实际=%s；断线一修复锁）"
				% str(led8.get("ch0_x_manual", null)))
		# 补学通（内存面）：户名账在位→替身出生值优先解析科目→双断
		var actor8: QuiverCharacter = load(Kit.ACTOR_SCENE).instantiate()
		get_tree().root.add_child.call_deferred(actor8)
		await _m_frames(6)
		var sm8: SpellManager = actor8.get_spell_manager()
		_check(sm8 != null and not sm8.get_spell_slot(0).is_empty()
				and sm8.get_spell_slot(0).definition.spell_id == &"fire_ball",
				"G8c 分户键补学通（值优先：slot0 在位且科目=fire_ball 双断；旧码把户名当科目=null 静默不学=断线二红）")
		actor8.free()
		# new_profile 模拟重建（走盘：影子落盘→清内存→load_game 还原——值经 JSON
		# 回环 StringName→String（探针 P3），补学读侧须双形兼收）
		shell8.queue_free()
		await _m_frames(6)
		_check(_sys != null and _sys.save_now() == true, "G8d 前置：分户账落 scratch 盘")
		GameSave.new_profile()
		_check(_sys.load_game() == true, "G8d' load_game true（重建起点）")
		var actor8b: QuiverCharacter = load(Kit.ACTOR_SCENE).instantiate()
		get_tree().root.add_child.call_deferred(actor8b)
		await _m_frames(6)
		var sm8b: SpellManager = actor8b.get_spell_manager()
		_check(sm8b != null and not sm8b.get_spell_slot(0).is_empty()
				and sm8b.get_spell_slot(0).definition.spell_id == &"fire_ball",
				"G8e 走盘重建后分户补学通（值维跨 JSON 回环 String 支，读档面实链；旧码同红=断线二走盘形态）")
		actor8b.free()
		# B4 兼容面：老式无值账（value=true）回落键不炸——直造旧形（此腿旧码亦绿）
		GameSave.new_profile()
		_check(_save.record(_save.NS_SPELLS, &"fire_ball", true) == true,
				"G8f 前置：老式账直造（键=科目名+值=true，B4 时代形态）")
		var actor8c: QuiverCharacter = load(Kit.ACTOR_SCENE).instantiate()
		get_tree().root.add_child.call_deferred(actor8c)
		await _m_frames(6)
		var sm8c: SpellManager = actor8c.get_spell_manager()
		_check(sm8c != null and not sm8c.get_spell_slot(0).is_empty()
				and sm8c.get_spell_slot(0).definition.spell_id == &"fire_ball",
				"G8f' 老式无值账回落键补学（值非科目信息→键即科目名；本腿旧码亦绿=B4 行为零变兼容锁）")
		actor8c.free()
		# 值读门洞本体（压轴=旧码缺 value_of 函数：响亮崩红=立法主体红据，
		# D 流"SaveSystem 不存在"红形制先例；绿期两式=有账读值+无账读 null）
		GameSave.new_profile()
		_save.claim_namespace(_save.NS_SPELLS, &"spell_save_contract")
		_save.record(_save.NS_SPELLS, &"ch0_y_manual", &"fire_ball")
		var val8: Variant = _save.value_of(_save.NS_SPELLS, &"ch0_y_manual")
		_check(val8 != null and str(val8) == "fire_ball",
				"G8g value_of 有账读值（StringName 支；缺 API 时本行崩=红据）")
		_check(_save.value_of(_save.NS_SPELLS, &"no_such_manual_key") == null,
				"G8g' value_of 无账读 null（静默幂等，调用方自备回落策）")
		GameSave.new_profile()
		await _d_frames(2)   # 排干在途帧尾落盘再删（"删完又复活=残骸过夜"判例）
		_sys.delete_save()

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

	# ── G7 learn_spell 基础类契约三式（B4.5-T3 立法，spec §5）──
	# 裸 SpellManager 形制：学习腿不触角色（施法字段全用不到），与 G3/G4 的
	# test_actor 出生补学/秘籍腿零互作（账本预记形制勿破——本段零写账）。
	# 判据只认 spell_id 不认资源引用：G7e 用 duplicate 双引用钉"幻影家族判例
	# 镜像不误伤"（同 tres 两副本=同学科，照样拒收）。
	if reg != null:
		var sm7 := SpellManager.new(null)
		_check(sm7.learn_spell(null) == false,
				"G7a learn_spell(null) 拒学 false（B4.5 立法红主体：旧实现 null 落空槽假报 true）")
		_check(sm7.get_spell_slot(0).is_empty(),
				"G7a' null 拒学无痕（slot0 仍空，不产幻影槽）")
		var def7: SpellDefinition = reg.definition_for(&"fire_ball")
		_check(def7 != null, "G7b 前置：registry 解析 fire_ball 定义（真产件当教材）")
		if def7 != null:
			_check(sm7.learn_spell(def7) == true, "G7c 正常 def 新学会占槽 true")
			_check(sm7.get_spell_slot(0).definition == def7,
					"G7c' 占槽落位 slot0 且 definition 同一（进槽对象核对）")
			_check(sm7.learn_spell(def7) == false,
					"G7d 同 def 再学拒收 false（同学科去重；push_warning=预期报警噪音）")
			var twin7: SpellDefinition = def7.duplicate(true)
			_check(twin7 != null and twin7.get_instance_id() != def7.get_instance_id()
					and sm7.learn_spell(twin7) == false,
					"G7e 异资源同 spell_id 亦拒收（只按 id 判学科，防'同-tres-双引用幻影'判例镜像误伤）")
			_check(sm7.get_spell_slot(1).is_empty(),
					"G7e' 去重无痕（重复科目不叠槽，slot1 仍空）")

	GameSave.new_profile()   # 测试自洁：G 流探针键不外溢（单例账随进程）
	_flow_done["G"] = true


# ── X 流（T3）：静态清点（spec §3 门三；判项表=报表，文档不手抄）──────────────
# 四检（注：本注释与标签刻意不连续拼写被禁 token——连写会让扫描器把契约自身
# 源码当违规现场；待查串一律运行期拼接，见 _x_split_token 与正则直写）：
#  ①账本内部私有域（下划线 + l e d g e s 复数）"绕门裸写"扫描——game_save.gd
#    之外全仓命中=0（白名单自证：唯一合法持有者=该文件自身，其 from_dict/erase/
#    claim 内部写点天然落此文件内故合规）；旧公共字典形态（点 fl a g s 方括号 /
#    点 ch e s t s 方括号）全仓=0（防四账回潮）。扫描器把被禁形态拆两段字面量
#    持有故不自我命中，白名单严格=仅 game_save.gd（与 spec 措辞一致，且让 T3b R8
#    往反应件注入的绕过门保持可被抓获）。
#  ②reactions/*.gd 每个含 class_name 的脚本必实存 `func save_claim`（本任务后 4/4）。
#  ③申报名册=报表：枚举全部 InteractReaction 子类，打印"类名 | persists | resets"，
#    并断言每类名已被 G/R/E 某腿点名（_name_class 登记，新件漏网=红）。
#  ④R-T2b 轻腿：chen.gd（@tool，补学块经 get_node_or_null 守卫）可编译加载不炸
#    ——证明"非 chapter/无 autoload"环境不会因缺 GameSave 在装载期报错
#    （判例：@tool 角色脚本 bare .new() 会崩，故此腿只 load 断非空、绝不实例化）。

const REACTIONS_DIR := "res://scripts/chapter/reactions"
const GAME_SAVE_PATH := "res://scripts/save/game_save.gd"
const CHEN_SCRIPT := "res://characters/playable/chen/chen.gd"


## 行为腿点名登记（独立于目录名册派生——见 _named_by_streams 头注）
func _name_class(cls_name: String) -> void:
	_named_by_streams[cls_name] = true


## 递归收集某目录树下全部 .gd 绝对 res:// 路径（跳过以 . 开头的隐藏项：
## .godot 导入缓存等）；返回相对 res:// 全路径便于与白名单比对
func _x_collect_gd(dir_path: String, out: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if not n.begins_with("."):   # 隐藏目录/文件（.godot/.import 等）整支跳过
			var full := dir_path.path_join(n)
			if d.current_is_dir():
				_x_collect_gd(full, out)
			elif n.ends_with(".gd"):
				out.append(full)
		n = d.get_next()
	d.list_dir_end()


## 构造"被禁形态"的字面量：用拼接令其在扫描器自身源码里也非连续，
## 从而实现"白名单严格仅 game_save.gd"而不自我误伤（见 X 流头注①说明）
func _x_split_token(a: String, b: String) -> String:
	return a + b


func flow_static_scan() -> void:
	GameSave.new_profile()
	_save = get_node_or_null(^"/root/GameSave")
	_check(_save != null, "X0 GameSave autoload 在场（scene runner 恒在场）")
	if _save == null:
		_flow_done["X"] = false
		return

	# 拆分后的待查 token（源码内不连续 → 扫描器自读零命中）
	var tok_led := _x_split_token("_led", "ges")
	# 正则直写：`.` 手工反斜杠转义，token 拆两段保证源码非连续（免依赖版本漂移的
	# escape 静态口，判例：引擎 API 零信任）；运行时串= `\.flags *\[` / `\.chests *\[`
	var re_flags := RegEx.new()
	re_flags.compile("\\.fl" + "ags *\\[")
	var re_chests := RegEx.new()
	re_chests.compile("\\.ch" + "ests *\\[")

	# 全仓 .gd 扫描（相对 res:// 根）：账本私有域白名单外命中 + 旧公共字段形态命中
	var all_gd: Array = []
	_x_collect_gd("res://", all_gd)
	var ledges_hits := 0
	var field_hits := 0
	var ledges_hit_paths: Array = []
	# 报表显示 token（运行期拼接，源码非连续 → 扫描器不自我命中，标签输出仍可读）
	var disp_led := _x_split_token("_led", "ges")
	var disp_flags := _x_split_token(".fl", "ags[")
	var disp_chests := _x_split_token(".ch", "ests[")
	for gp in all_gd:
		var p: String = gp
		if p == GAME_SAVE_PATH:
			continue   # 唯一合法持有者（门洞/快照/销账/开户的内部写点全在此文件）
		var text := FileAccess.get_file_as_string(p)
		if text.is_empty() and not FileAccess.file_exists(p):
			continue
		if text.contains(tok_led):
			ledges_hits += 1
			ledges_hit_paths.append(p)
		if re_flags.search(text) != null or re_chests.search(text) != null:
			field_hits += 1
	_check(ledges_hits == 0,
			"X1a game_save.gd 之外全仓 %s 命中=0（实际=%d %s）"
			% [disp_led, ledges_hits, str(ledges_hit_paths)])
	_check(field_hits == 0,
			"X1b 旧公共字段形态 %s/%s 全仓=0（防四账回潮，实际=%d）"
			% [disp_flags, disp_chests, field_hits])

	# ②reactions/*.gd 每个 class_name 脚本必实存 func save_claim（非递归列目录）
	var d := DirAccess.open(REACTIONS_DIR)
	_check(d != null, "X2a reactions 目录可枚举（%s）" % REACTIONS_DIR)
	var claim_missing: Array = []
	var claim_ok := 0
	var class_total := 0
	if d != null:
		d.list_dir_begin()
		var n := d.get_next()
		while n != "":
			if n.ends_with(".gd") and not n.ends_with(".uid"):
				var text := FileAccess.get_file_as_string(REACTIONS_DIR.path_join(n))
				if text.contains("class_name"):
					class_total += 1
					if text.contains("func save_claim"):
						claim_ok += 1
					else:
						claim_missing.append(n)
			n = d.get_next()
		d.list_dir_end()
	# 基数=chest/gate/qte/spell_book 四件（InteractReaction 基类自身亦含 save_claim，
	# 计入 class_total/save_ok 不影响"每子类必有 save_claim"判据；据实 4 子类 + 1 基类）
	_check(claim_missing.is_empty(),
			"X2b 每个 class_name 反应件脚本必实存 save_claim（缺失=%s 覆盖=%d/%d 文件）"
			% [str(claim_missing), claim_ok, class_total])

	# ③申报名册派生（按基类反射，非 GCL 基字段）+ 打印=报表
	_check(load(REACTION_BASE_PATH) != null,
			"X3a InteractReaction 基类脚本在场（名册派生锚）")
	var names: Array = _x_derive_roster()
	if not names.is_empty():
		# 判项表=报表：逐类打印申报两列（供报告与 F5 单尾引用，禁手抄进文档）
		print("  ── X3 申报名册（判项表=报表，spec §2.1/§3 门三）──")
		for cname in names:
			var rec: Dictionary = _x_roster[cname]
			print("    %s | persists=%s | resets=%s" % [
				cname, str(rec.persists), str(rec.resets)])
		_check(names.size() == 4,
				"X3b InteractReaction 子类名册恰 4 件（chest/gate/qte/spell_book，实际=%d %s）"
				% [names.size(), str(names)])
		# 每类名须被 G/R/E 某腿显式点名（_named_by_streams 由行为腿填，非此处填）
		var unnamed: Array = []
		for cname in names:
			if not _named_by_streams.has(cname):
				unnamed.append(cname)
		_check(unnamed.is_empty(),
				"X3c 名册每类均被 G/R/E 至少一根腿点名（漏网=%s 已点名=%s）"
				% [str(unnamed), str(_named_by_streams.keys())])
	else:
		_check(false, "X3b/X3c 名册腿跳过（基类缺失）")

	# ④R-T2b 轻腿：@tool 角色脚本可编译加载不炸（守卫 get_node_or_null 结构性证明）
	var chen: GDScript = load(CHEN_SCRIPT)
	_check(chen != null and chen is GDScript,
			"X4 -s 无 autoload load 不炸轻腿：chen.gd 可编译加载非空"
			+ "（补学块 get_node_or_null 守卫=装载期不依赖 GameSave；@tool 角色"
			+ "脚本 bare .new() 会崩故本腿只 load 不实例化）")

	GameSave.new_profile()
	_flow_done["X"] = true


## path→class_name 反查表（class_name 与基字段无关，故 extends 改判不影响取键）
func _x_build_class_name_map() -> Dictionary:
	var m := {}
	for e in ProjectSettings.get_global_class_list():
		var pth: String = String(e.get("path", ""))
		if pth.is_empty():
			continue
		m[pth] = String(e.get("class", ""))
	return m


## 反射判"脚本继承链是否抵达 InteractReaction"（不依赖 GCL 的 base 字段——
## 该字段只在 --import 后刷新，extends 改判当期可能陈旧；链走 get_base_script 实源）
func _x_extends_reaction(s: GDScript, base: GDScript) -> bool:
	var cur: GDScript = s
	while cur != null:
		if cur == base:
			return true
		cur = cur.get_base_script()
	return false


## 名册派生单一入口（X 流打印/③点名判据 与 R 流"申报单联动"共用）：DirAccess
## 枚举 reactions/*.gd → load → 反射基类走查 → .new() 取 save_claim（不依赖 GCL
## base 字段，见 _x_extends_reaction 判例）→ 填充 _x_roster，返回类名清单。
## 幂等：每次清空重建；.new()/free 平衡（探针纪律：Node 型显式 free，防退出泄漏）。
func _x_derive_roster() -> Array:
	var names: Array = []
	_x_roster.clear()
	var base: GDScript = load(REACTION_BASE_PATH)
	if base == null:
		return names
	var path_to_class := _x_build_class_name_map()
	var d := DirAccess.open(REACTIONS_DIR)
	if d == null:
		return names
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if n.ends_with(".gd") and not n.ends_with(".uid"):
			var abs_path: String = REACTIONS_DIR.path_join(n)
			var s: GDScript = load(abs_path)
			if s != null and s != base and _x_extends_reaction(s, base):
				var cname: String = path_to_class.get(abs_path, n.get_basename())
				var inst: Object = s.new()
				var claim: Dictionary = inst.save_claim() if inst.has_method("save_claim") else {}
				if inst is Node:
					(inst as Node).free()
				_x_roster[cname] = {
					"persists": claim.get(&"persists", []),
					"resets": claim.get(&"resets", []),
					"path": abs_path,
				}
				names.append(cname)
		n = d.get_next()
	d.list_dir_end()
	return names


# ── E 流（T3）：正式壳生产链施法端到端（spec §5；plan Task3 Step1）───────────
# 唯一真键盘腿：加载章壳夹具（playable_override=test_actor）→ 驱动替身入秘籍触发
# 区 → trig.interacted.emit() 学会（判重/入账/即时教学全走生产链 InteractSpellBook）
# → raw 数字键 1（Input.parse_input_event 原始按键，B3-T2 判例非 InputEventAction）
# → 断言进入 Cast 态 → 断言场上生成弹体（SpellBase）→ 敌血下降（best-effort）。
# 硬钉两段（Cast 进入 + 弹体生成，确定性强）；命中链在 headless 下时序脆弱（敌 AI
# 自由度/咏唱窗竞态），按 plan Task3 Step1 明文设 best-effort：命中=PASS，未捕获=
# NOTICE 大声据实报（红据留 T3b R8 正式验），绝不静默假绿。

func _e_find(node: Node, pred: Callable) -> Node:
	for c in node.get_children():
		if pred.call(c):
			return c
		var found := _e_find(c, pred)
		if found != null:
			return found
	return null


func flow_cast_e2e() -> void:
	GameSave.new_profile()
	_save = get_node_or_null(^"/root/GameSave")
	_check(_save != null, "E0 GameSave autoload 在场（scene runner 恒在场）")
	if _save == null:
		_flow_done["E"] = false
		return

	if Kit.peek() != Kit.READY:
		print("  NOTICE: 跳过 E 流——test_actor 非就绪态（peek=%d，处方：bash " % Kit.peek()
				+ "tools/matrix_runner/run_matrix.sh --ensure-only）；章壳夹具"
				+ "playable_override 不可解析（主权法 B2.5：只读消费不代建）")
		GameSave.new_profile()
		_flow_done["E"] = true
		return

	_name_class("InteractSpellBook")   # E 流真腿点名（独立于 X③目录派生）
	var shell: ChapterShell = (load(FIX_B4_CHAPTER) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(shell)
	await _m_frames(20)
	_check(shell.playable != null and shell.playable.is_in_group("area2d:player"),
			"E1 章壳加载且 playable 换人为 test_actor（area2d:player 身份在位）")

	# 找段内秘籍触发件（InteractTrigger，其子挂 InteractSpellBook）
	var trig: InteractTrigger = _e_find(shell, func(c): return c is InteractTrigger) as InteractTrigger
	_check(trig != null, "E2 段内 InteractTrigger 在场")
	if trig == null:
		shell.queue_free()
		await _m_frames(6)
		GameSave.new_profile()
		_flow_done["E"] = true
		return

	# 驱动替身入触发区（判例：位置写完整构造式；触发区默认 160×160 已覆出生点，
	# 显式贴脸保证 body_entered 计数确定，再走 emit 生产学习路径）
	shell.playable.global_position = trig.global_position
	await _m_frames(4)
	_check(trig.in_range(), "E2b 替身已入秘籍触发区（in_range 真）")

	trig.interacted.emit()   # 生产学习链（入账+首开教学当前实例）
	await _m_frames(4)
	_check(_save.has_record(_save.NS_SPELLS, &"fire_ball"),
			"E3 经 InteractSpellBook 生产链：账本 has_record(spells_known, fire_ball)")
	var psm: SpellManager = shell.playable.get_spell_manager()
	_check(psm != null and not psm.get_spell_slot(0).is_empty(),
			"E3b 当前 playable 实例即时学会（slot0 非空——增量教学腿）")

	# 替身朝向敌（右）：弹体出手方向读 skin.skin_direction，显式定右让 best-effort
	# 命中窗最大化（硬钉 Cast/弹体与本朝向无关，此为给敌血下降腿创造确定性条件）
	if shell.playable._skin != null:
		shell.playable._skin.skin_direction = Vector2.RIGHT
	# raw 数字键 1（唯一真键盘腿，_g_press_key 逐字段显式：device/keycode/physical/pressed）
	_g_press_key(KEY_1, true)
	_g_press_key(KEY_1, false)

	# 硬钉①：进入 Cast 态（state_name 路径含 "Cast"，spell_manager CAST_STATE_PATH 同源）
	var entered_cast := false
	for _i in 40:
		await get_tree().physics_frame
		if str(shell.playable.state_machine.state_name).contains("Cast"):
			entered_cast = true
			break
	_check(entered_cast, "E4【硬钉①】raw 数字键1 → 角色进入 Ground/Cast 施法态")

	# 硬钉②：场上生成弹体（SpellBase 上场，递归查壳）+ best-effort 敌血下降
	var enemy := _e_find(shell, func(c): return c is QuiverCharacter and c.is_in_group("area2d:spar_enemy"))
	var hp_prev: float = enemy.attributes.health_current if enemy != null else 0.0
	var proj_found := false
	var hp_dropped := false
	for _i in 120:
		await get_tree().physics_frame
		if not proj_found and _e_find(shell, func(c): return c is SpellBase) != null:
			proj_found = true
		if enemy != null and not hp_dropped and enemy.attributes.health_current < hp_prev:
			hp_dropped = true
		if proj_found and (hp_dropped or _i > 80):
			break
	_check(proj_found, "E5【硬钉②】场上生成弹体（SpellBase 上场——施法链真放体）")
	if hp_dropped:
		_check(true, "E6 敌血下降（best-effort 命中链本次已捕获：弹体真命中 spar）")
	else:
		print("  NOTICE: E6 敌血下降 best-effort——本次 headless 窗内未捕获命中"
				+ "（弹体生成已硬钉；命中时序脆弱属 plan Task3 Step1 知情面，红据留"
				+ " T3b R8 正式验，非静默假绿）")

		shell.queue_free()
		await _m_frames(6)
		GameSave.new_profile()
	_flow_done["E"] = true


# ── R 流（T3）：重演等价（spec §3 门四，plan Step2）─────────────────────────
# 用账本可观测面做确定性双跑（不跑敌人 AI、不进战斗，规避非确定源，spec §7.5）：
#  脚本序列 seq（全走 GameSave 公开面）→ 采指纹 v1 →
#  to_dict→JSON.stringify→JSON.parse_string→from_dict（内存"假存档"，B4.5 换真盘）
#  → 重采 v2 → 断言 v1==v2（入册项跨快照不变=还原保账，门四主力面）；
#  new_profile() 后采 v3 → 全 false/空（新档=清账，含 cleared 归零=未来该段未清
#  将丢弃重建的 ledger 侧证据，避免真 spawn）。
#  申报单联动：遍历 X③名册，对每 persists 户用代表 key 做 record→假存档回环→
#  has_record 真（证明"还原保账"是按申报单逐户执法，非硬编码某账目）；本批三件
#  resets 皆空（gate/qte 据实申报零账本足迹），无豁免归零腿可验，据实打点。

## 指纹采样（只采账本可查确定观测量，禁采血/池/冷却等满状态可推项，spec §7.5）
func _r_fingerprint() -> Array:
	return [
		_save.is_chest_open(&"b4_r_chest"),
		_save.has_record(_save.NS_SPELLS, &"fire_ball"),
		_save.has_flag(&"b4_r_flag"),
		_save.is_cleared(&"b4_r_seg"),
		"%s|%s" % [str(_save.checkpoint_segment()), str(_save.checkpoint_entry())],
	]


## 脚本化操作序列（走 GameSave 公开门洞，非直戳内部）
func _r_run_seq() -> void:
	_save.open_chest(&"b4_r_chest")
	_save.record(_save.NS_SPELLS, &"fire_ball")
	_save.add_flag(&"b4_r_flag")
	_save.mark_cleared(&"b4_r_seg")
	_save.record_checkpoint(&"b4_r_seg", &"entry_default")


## 内存"假存档"回环（B4.5 落盘日此三行换成真盘写读，套零改动，spec §8）
func _r_fake_restore() -> void:
	var snap: Dictionary = JSON.parse_string(JSON.stringify(_save.to_dict()))
	_save.from_dict(snap)


func _r_rep_key(ns: StringName) -> StringName:
	match ns:
		_save.NS_CHESTS: return &"b4_r_rep_chest"
		_save.NS_FLAGS: return &"b4_r_rep_flag"
		_save.NS_SPELLS: return &"b4_r_rep_spell"
		_: return &"b4_r_rep_any"


## 单件申报形制回归锁 + 点名：实读该类 save_claim 与据实期望比对（忘改申报单/
## 悄悄增写账本户=当场红），并显式 _name_class 供 X③判"每类被行为腿点名"。
func _r_claim_leg(cls_name: String, script_path: String, exp_p: Array, exp_r: Array) -> void:
	_name_class(cls_name)
	var s: GDScript = load(script_path)
	_check(s != null, "R5a %s 脚本在场（申报形制腿）" % cls_name)
	if s == null:
		return
	var inst: Object = s.new()
	var claim: Dictionary = inst.save_claim() if inst.has_method("save_claim") else {}
	if inst is Node:
		(inst as Node).free()
	_check(claim.get(&"persists", []) == exp_p and claim.get(&"resets", []) == exp_r,
			"R5b %s 申报单据实：persists=%s resets=%s（实际=%s/%s）"
			% [cls_name, str(exp_p), str(exp_r), str(claim.get(&"persists", [])), str(claim.get(&"resets", []))])


func flow_replay_equiv() -> void:
	GameSave.new_profile()
	_save = get_node_or_null(^"/root/GameSave")
	_check(_save != null, "R0 GameSave autoload 在场（scene runner 恒在场）")
	if _save == null:
		_flow_done["R"] = false
		return

	# ── 门四·重演等价（双跑入册项不变）──
	_r_run_seq()
	var v1: Array = _r_fingerprint()
	_r_fake_restore()
	var v2: Array = _r_fingerprint()
	_check(v1 == v2,
			"R1 重演等价·入册项跨假存档不变：v1==v2（v1=%s v2=%s）" % [str(v1), str(v2)])
	# 逐项等（v1==v2 已覆盖，但失败时逐项定位——且首跑必须全 true，防"两遍都空"假绿）
	var all_set := true
	for i in v1.size():
		if i < 4 and v1[i] != true:
			all_set = false
	_check(all_set,
			"R1b seq 真把四类入册项置真（前四指纹全 true，实际=%s）" % str(v1))

	# ── 豁免/重置向：新档=清账（含 cleared 归零=段将丢弃重建的 ledger 侧证据）──
	_save.new_profile()
	var v3: Array = _r_fingerprint()
	_check(v3 == [false, false, false, false, "|default"],
			"R2 新档=清账：v3 全 false/空（cleared 归零即'未清将重建'证据，实际=%s）" % str(v3))

	# ── 申报单联动：逐 persists 户 record→假存档回环→has_record 真 ──
	_x_derive_roster()   # R 流自带派生（X 流在其后跑，名册同源不依赖顺序）
	var tested_ns := {}
	for cname in _x_roster:
		for ns in (_x_roster[cname] as Dictionary).persists:
			if tested_ns.has(ns):
				continue
			tested_ns[ns] = true
			var key: StringName = _r_rep_key(ns)
			_save.record(ns, key)
			_r_fake_restore()
			_check(_save.has_record(ns, key),
					"R3 %s 的 persists 户 %s 经假存档还原后 has_record 真（逐户执法非硬编码）"
					% [cname, str(ns)])
	_check(not tested_ns.is_empty(),
			"R3b 联动至少覆盖名册全部 persists 户（实际户集=%s）" % str(tested_ns.keys()))
	# 重置面（resets）据实：本批三件皆报空 → 无豁免归零腿可验，据实打点非静默
	var any_reset := false
	for cname in _x_roster:
		if not (_x_roster[cname] as Dictionary).resets.is_empty():
			any_reset = true
	if not any_reset:
		print("  NOTICE: R4 resets 面——本批全部反应件 resets=[]（gate/qte 零账本足迹，"
				+ "chest/spell_book 纯持久户），据实无豁免归零腿可验；有件报 resets 时此腿激活")

	# ── 申报形制回归锁（逐类据实比对 + 点名供 X③）──
	GameSave.new_profile()
	_r_claim_leg("InteractChest", REACTIONS_DIR.path_join("interact_chest.gd"),
			[_save.NS_CHESTS, _save.NS_FLAGS], [])
	_r_claim_leg("InteractGate", REACTIONS_DIR.path_join("interact_gate.gd"), [], [])
	_r_claim_leg("InteractQte", REACTIONS_DIR.path_join("interact_qte.gd"), [], [])
	_r_claim_leg("InteractSpellBook", SPELL_BOOK_PATH, [_save.NS_SPELLS], [])

	# ── NIT-1 示范形制：跨流探针信号一次性计数 + 用完即摘（单例信号常驻=串扰雷）──
	GameSave.new_profile()
	var probe_cnt := {"n": 0}
	var probe_cb := func(_id) -> void: probe_cnt["n"] += 1
	_save.flag_added.connect(probe_cb)
	_save.add_flag(&"b4_r_probe")
	_save.add_flag(&"b4_r_probe")   # 重复 add 不重发（首记才发）
	_save.flag_added.disconnect(probe_cb)   # 立即摘连（不跨流常驻）
	_save.add_flag(&"b4_r_probe2")   # 摘连后再发信号不再计入本探针
	_check(int(probe_cnt["n"]) == 1,
			"R6 探针信号一次性形制：计数恰 1 且 disconnect 后不复增（实际=%d）"
			% int(probe_cnt["n"]))

	GameSave.new_profile()
	_flow_done["R"] = true


# ── D 流（B4.5-T0）：SaveSystem 影子落盘真盘腿（spec §2/§6；plan Task0 Step2 八组）──
# 判例：SaveSystem 无 class_name，全经 get_node_or_null 动态消费（缺席=响亮红不硬闯）；
# 泛信号 connect 一律 lambda 形参对齐信号实参（4.7 探针实锤：0 参回调接 2 参信号
# 在 emit 时报 "Method expected 0 argument(s)"——少参不算兼容）；帧尾合并落盘的断言
# 前必 await 帧（测试卫生条款）；全套只吃 SCRATCH_D，D9a 总断言钉生产槽零污染。

const PROD_SLOT := "user://save_auto.json"   # 生产槽字面镜像（save_system.gd AUTOSAVE_PATH）


func _d_frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func flow_disk() -> void:
	_save = get_node_or_null(^"/root/GameSave")
	_sys = get_node_or_null(^"/root/SaveSystem")
	_check(_save != null, "D0a GameSave autoload 在场（scene runner 恒在场）")
	_check(_sys != null, "D0b SaveSystem autoload 在场（scene runner 恒在场，缺席=响亮红）")
	if _save == null or _sys == null:
		_flow_done["D"] = false
		return
	var api_ok: bool = _sys.has_method("has_save") and _sys.has_method("save_now") \
		and _sys.has_method("load_game") and _sys.has_method("delete_save")
	_check(api_ok, "D0c SaveSystem API 面齐（has_save/save_now/load_game/delete_save）")
	var gs_ok: bool = _save.has_signal("recorded") and _save.has_signal("checkpoint_recorded") \
		and _save.has_signal("location_visited") \
		and _save.has_method("checkpoint_scene") \
		and _save.has_method("add_location_checkpoint") and _save.has_method("locations") \
		and _save.get("resume_pending") != null
		# ↑传渡旗生育核验（4.7 探针 P2-6：属性缺失时 get 回 null、set 静默丢——
		# RED 期本门挡下 ⑤ 腿，避免 GameSave.xxx 静态属性访问在旧脚本上编译期炸）
	_check(gs_ok, "D0d GameSave 扩展面齐（三信号/checkpoint_scene/locations 双口）")
	if not (api_ok and gs_ok):
		# RED 期：八组腿各记一条可读红（缺门不硬闯缺失 API——S0 判例同款）
		for leg_name in ["D1 scratch 清场", "D2 首记→帧尾自动落盘", "D3 影子自动触发合并腿",
				"D4 save_now→load_game 还原真写账", "D5 传渡条款 resume_pending 不落盘",
				"D6 坏文件拒收保现账", "D7 version1 形状兼容默认值", "D8 信号纪律首记才发",
				"D9 生产槽零污染总断言"]:
			_check(false, "%s——D0c/D0d 门缺位跳过调用（RED 现场）" % leg_name)
		_flow_done["D"] = true   # 本流序列完整执行（红在门，非协程炸段）
		return

	# ── ① scratch 注入 + 清场 ──
	_sys.slot_path = SCRATCH_D
	await _d_frames(2)   # 先排干前流（S/M/G/E/R 真写账）在途帧尾落盘，防串扰本流判据
	GameSave.new_profile()
	_sys.delete_save()
	_check(_sys.has_save() == false, "D1a delete_save 清场后 has_save false（scratch 起点确无档）")

	# ── ② 首记→帧尾自动落盘：文件+version1+账键在+无 .tmp 残骸 ──
	_save.claim_namespace(NS_D, &"D流")
	_check(_save.record(NS_D, &"d_rec") == true, "D2a record 首记 true（影子触发源）")
	await _d_frames(2)
	_check(_sys.has_save(), "D2b 首记帧尾后 scratch 文件自动出现（未调 save_now=影子语义）")
	var snap2: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCRATCH_D))
	_check(typeof(snap2) == TYPE_DICTIONARY, "D2c JSON.parse_string 可读回字典")
	if typeof(snap2) == TYPE_DICTIONARY:
		_check(int((snap2 as Dictionary).get("version", -1)) == 1, "D2d 快照 version==1")
		var led2: Variant = (snap2 as Dictionary).get("ledges", {})
		var probe2: Dictionary = led2.get(String(NS_D), {}) if typeof(led2) == TYPE_DICTIONARY else {}
		_check(probe2.has("d_rec"), "D2e ledges.%s 含 d_rec（与账本逐键一致的最小钉）" % String(NS_D))
	_check(FileAccess.file_exists(SCRATCH_D + ".tmp") == false, "D2f 无 .tmp 残骸（tmp→rename 原子替换收口）")

	# ── ③ 影子自动触发合并腿（本批宪法腿：文件回来只可能来自信号）──
	_sys.save_now()      # 基线一笔（此后除本行外全腿禁再直调 save_now）
	_sys.delete_save()
	GameSave.new_profile()
	_check(_sys.has_save() == false, "D3a 清场后确无文件（后续出现即影子铁证）")
	_save.claim_namespace(NS_D, &"D流")
	# 一帧内三来源各记一笔：recorded / location_visited / checkpoint_recorded
	_save.record(NS_D, &"d3_rec")                                          # 来源一
	_save.add_location_checkpoint(&"d3_stage", "res://d3_fake.tscn")       # 来源二
	_save.record_checkpoint(&"d3_seg", &"d3_entry", "res://d3_fake.tscn")  # 来源三
	_check(_sys.has_save() == false, "D3b 三笔记毕同帧内文件未回（帧尾合并≠逐笔记逐笔写）")
	await _d_frames(2)
	_check(_sys.has_save() == true, "D3c 帧尾后文件自动回来且全程未直调 save_now（影子存在性证明）")
	var snap3: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCRATCH_D))
	if typeof(snap3) != TYPE_DICTIONARY:
		_check(false, "D3d 影子落盘内容不可解析（实际=%s）" % str(snap3))
	else:
		var led3: Variant = (snap3 as Dictionary).get("ledges", {})
		var probe3: Dictionary = led3.get(String(NS_D), {}) if typeof(led3) == TYPE_DICTIONARY else {}
		_check(probe3.has("d3_rec"), "D3d 三笔之一 record 在档")
		var cp3: Variant = (snap3 as Dictionary).get("checkpoint", {})
		var cp3d: Dictionary = cp3 if typeof(cp3) == TYPE_DICTIONARY else {}
		_check(cp3d.get("segment") == "d3_seg" and cp3d.get("scene") == "res://d3_fake.tscn",
				"D3e 三笔之二 checkpoint 在档（scene 三键形状，实际=%s）" % str(cp3d))
		var locs3: Variant = (snap3 as Dictionary).get("locations", [])
		var l3ok: bool = typeof(locs3) == TYPE_ARRAY and (locs3 as Array).size() == 1 \
			and ((locs3 as Array)[0] as Dictionary).get("stage_id") == "d3_stage"
		_check(l3ok, "D3f 三笔之三 locations 在档（String 化落 JSON，实际=%s）" % str(locs3))
	_check(FileAccess.file_exists(SCRATCH_D + ".tmp") == false, "D3g 合并写后仍无 .tmp 残骸")

	# ── ④ roundtrip：save_now→new_profile→load_game 还原真写账 ──
	GameSave.new_profile()
	_save.record(NS_D, &"d4_key", 7)
	_save.add_flag(&"d4_flag")
	_save.open_chest(&"d4_chest")
	_save.record_checkpoint(&"d4_seg", &"d4_entry", "res://fake.tscn")
	_save.add_location_checkpoint(&"d4_stage_a", "res://a.tscn")
	_save.add_location_checkpoint(&"d4_stage_a", "res://a2.tscn")   # 摘旧追新现场
	_save.add_location_checkpoint(&"d4_stage_b", "res://b.tscn")
	_check(_sys.save_now() == true, "D4a save_now 同步强存 true")
	GameSave.new_profile()
	_check(_save.has_record(NS_D, &"d4_key") == false, "D4b 还原前先清账（R 流'还原真写'判例防假绿）")
	_check(_sys.load_game() == true, "D4c load_game true")
	_check(_save.has_record(NS_D, &"d4_key") and _save.has_flag(&"d4_flag") \
		and _save.is_chest_open(&"d4_chest"), "D4d 逐键 has_record 还原（探针户+兼容层双验）")
	_check(_save.checkpoint_scene() == "res://fake.tscn" \
		and _save.checkpoint_segment() == &"d4_seg" and _save.checkpoint_entry() == &"d4_entry",
		"D4e checkpoint 三件套还原（实际=%s/%s/%s）" % [_save.checkpoint_scene(),
			str(_save.checkpoint_segment()), str(_save.checkpoint_entry())])
	var locs4: Array = _save.locations()
	_check(locs4.size() == 2 and locs4[1].stage_id == &"d4_stage_b" \
		and locs4[0].scene_path == "res://a2.tscn",
		"D4f locations 还魂 2 笔·摘旧追新·尾=最新（实际=%s）" % str(locs4))
	# ── D4g/D4h 空参不覆写已记 scene（B4.5-T0 评审 F1 移交补腿，spec §3）──
	# 先三参带 scene 记账 → 两参/空参再记：段入更新但坐标必保——三通道共用
	# 检查点坐标不被传渡腿洗掉（game_save.record_checkpoint 保 scene 分支的行为锁）
	_save.record_checkpoint(&"f1_seg", &"f1_entry", "res://f1_scene.tscn")
	_save.record_checkpoint(&"f1b_seg", &"f1b_entry")            # 两参旧调用形
	_check(_save.checkpoint_scene() == "res://f1_scene.tscn" \
		and _save.checkpoint_segment() == &"f1b_seg" \
		and _save.checkpoint_entry() == &"f1b_entry",
		"D4g 两参再记：换段不抹 scene（实际=%s/%s）" % [_save.checkpoint_scene(),
			str(_save.checkpoint_segment())])
	_save.record_checkpoint(&"f1c_seg", &"f1c_entry", "")        # 显式空参形
	_check(_save.checkpoint_scene() == "res://f1_scene.tscn" \
		and _save.checkpoint_segment() == &"f1c_seg",
		"D4h 空参再记：换段不抹 scene（与两参同义，实际=%s）" % _save.checkpoint_scene())

	# ── ⑤ 传渡条款腿（resume_pending 易失：不入账不落盘，spec §3）──
	# 形制注：旗读写走 _save.set()（动态通道）而非 GameSave.resume_pending——
	# 后者是 autoload 静态类型访问，RED 期旧 game_save.gd 无此属性=整脚本
	# Parse Error 级联（手写 .tscn 判例同族的"红期不炸解析"纪律；D0d 门已证属性在场）
	_save.set("resume_pending", true)
	var td: Dictionary = _save.to_dict()
	_check(td.has("resume_pending") == false, "D5a to_dict 顶层无 resume_pending 键")
	_check(JSON.stringify(td).find("resume_pending") == -1, "D5b JSON 串不含 resume_pending 子词")
	_save.set("resume_pending", false)   # 清场（传渡旗不外溢后续流/T2 消费面）

	# ── ⑥ 坏文件腿：拒收=false 且现账一字不动 ──
	var fp_before: String = JSON.stringify(_save.to_dict())
	var fw6 := FileAccess.open(SCRATCH_D, FileAccess.WRITE)
	if fw6 != null:
		fw6.store_string("{{{垃圾")
		fw6.close()
	_check(_sys.load_game() == false, "D6a 垃圾文件 load_game false（push_warning=被试行为）")
	_check(JSON.stringify(_save.to_dict()) == fp_before, "D6b 拒收后现账逐键无损（快照串等值）")

	# ── ⑦ 形状兼容腿：version1 旧形状（缺 scene/缺 locations）→ 默认值 ──
	var fw7 := FileAccess.open(SCRATCH_D, FileAccess.WRITE)
	if fw7 != null:
		fw7.store_string('{"version":1,"ledges":{},"checkpoint":{"segment":"s7","entry":"e7"}}')
		fw7.close()
	_check(_sys.load_game() == true, "D7a 缺键旧形状 load_game true（向后兼容形状扩展钉）")
	_check(_save.checkpoint_scene() == "", "D7b 缺 scene 键→默认空串")
	_check(_save.checkpoint_segment() == &"s7" and _save.checkpoint_entry() == &"e7",
			"D7c 既有 segment/entry 仍正确还魂")
	_check(_save.locations().is_empty(), "D7d 缺 locations 键→默认空表")

	# ── ⑧ 信号纪律腿（recorded 首记一发/重记零发；checkpoint_recorded 三键拷贝）──
	GameSave.new_profile()
	await _d_frames(2)   # 排干在途落盘再起步计数（防他流脏影干扰观感，非判据主体）
	var cnt8 := {"rec": 0, "cp": 0, "bad": 0, "cpd": {}}
	var cb_rec := func(_ns, _id) -> void: cnt8["rec"] += 1
	var cb_cp := func(cp: Dictionary) -> void:
		cnt8["cp"] += 1
		if not (cp.has("scene") and cp.has("segment") and cp.has("entry")):
			cnt8["bad"] += 1
		cnt8["cpd"] = cp
	_save.recorded.connect(cb_rec)
	_save.checkpoint_recorded.connect(cb_cp)
	_save.claim_namespace(NS_D, &"D流")
	_save.record(NS_D, &"d8_one")
	_check(int(cnt8["rec"]) == 1, "D8a recorded 首记恰一发（实际=%d）" % int(cnt8["rec"]))
	_save.record(NS_D, &"d8_one")
	_save.record(NS_D, &"d8_one", false)   # 同键重记（值不覆盖也不重发）
	_check(int(cnt8["rec"]) == 1, "D8b 重记零发（首记才发，实际=%d）" % int(cnt8["rec"]))
	_save.record_checkpoint(&"d8_seg", &"d8_entry")
	_check(int(cnt8["cp"]) == 1 and int(cnt8["bad"]) == 0,
			"D8c checkpoint_recorded 恰一发且三键齐（scene/segment/entry）")
	# 拷贝纪律：emit 字典被外部改写不得回染账本（emit 每次现造新档）
	(cnt8["cpd"] as Dictionary)["segment"] = &"polluted"
	_check(_save.checkpoint_segment() == &"d8_seg", "D8d emit 三键是拷贝：外染不回账本")
	_save.recorded.disconnect(cb_rec)
	_save.checkpoint_recorded.disconnect(cb_cp)   # 用完即摘（NIT-1 形制）

	# ── D9 生产槽零污染总断腿（B4.5-T1 A2 形制改判：单机自证）──
	# 套头已 delete_save 清生产槽名，本腿"不存在"判据自此只证本套落盘只吃
	# scratch；跨套互写生产槽的防线=各套自己的 scratch 重定向（含 stage_contract
	# A1 扩展），不再依赖矩阵内套序。
	var consts_map: Dictionary = (_sys.get_script() as GDScript).get_script_constant_map()
	_check(consts_map.get("AUTOSAVE_PATH") == PROD_SLOT,
			"D9a SaveSystem.AUTOSAVE_PATH 常量=plan 钉名（实际=%s）" % str(consts_map.get("AUTOSAVE_PATH")))
	_check(FileAccess.file_exists(PROD_SLOT) == false,
			"D9b 生产槽 %s 套内零出现（起手清名→尾断不存在，单机自证）" % PROD_SLOT)

	GameSave.new_profile()   # 流尾自洁（探针键不外溢 X 流；单例账随进程）
	await _d_frames(2)       # 排干 ⑧ 记账的在途帧尾落盘（先写后删，否则删完又复活=残骸过夜）
	_sys.delete_save()       # 套尾删净 scratch（测试卫生条款：不留残骸）
	_flow_done["D"] = true


# ── P 流（B4.5-T2）：读档管线拆段腿（spec §4；plan Task2 Step1 全量）────────────
# 套件不点钮（点=真转场拆套，T1 移交②）：title 函数体由「无档 has_save false 钮
# disabled」（stage_contract A4 改判腿）+代码走查覆盖，真点击链归 F5；本流按
# 「落盘→load_game→置旗→直建壳」走继续钮后半场的等价拆段，另钉落位/旗消费/
# 坏段回退/通关入账四判。checkpoint_scene 比对与消费全在壳 _ready（chapter_shell
# T2 分支），夹具章 id=fix、段序 seg_a→seg_b→seg_c（均非 auto_complete，落位后
# 无在途推进链，纯落位验证——无合用多段夹具时按 seg_it 形制新建的预案未触发）。

func flow_resume() -> void:
	_save = get_node_or_null(^"/root/GameSave")
	_sys = get_node_or_null(^"/root/SaveSystem")
	if _save == null or _sys == null:
		_check(false, "P0 GameSave/SaveSystem autoload 缺席（D0 同红，不硬闯）")
		_flow_done["P"] = false
		return
	GameSave.resume_pending = false   # 起手清旗（传渡不外溢本流判据）
	if not Kit.exists():
		print("  NOTICE: 跳过 P 流全部壳腿——test_actor 替身缺席，chapter_fix 夹具"
				+ "不可解析（处方：bash tools/matrix_runner/run_matrix.sh --ensure-only"
				+ " 建好替身后复跑；M1 形制，B2.5 主权法不代建）")
		_flow_done["P"] = true
		return
	# 本流自足起点：scratch 重定向+清场清账（不赌 D 流尾态）
	_sys.slot_path = SCRATCH_D
	await _d_frames(2)   # 排干前流在途帧尾落盘（D1a 判例）
	GameSave.new_profile()
	_sys.delete_save()

	# ── P1 对照腿：无旗自然落位 _order[0]（兼 T2 生产行"enter_segment 传 scene"锁）──
	var shell_a := await _m_make_shell()
	_check(shell_a.current_segment_id() == &"seg_a",
			"P1a 无旗对照落位 _order[0]=seg_a（resume 分支缺席态零变，B4 行为面）")
	_check(_save.checkpoint_scene() == FIX_CHAPTER,
			"P1b enter_segment 生产腿带 scene 入检查点（spec §4 三通道共用坐标源；实际=%s）"
			% _save.checkpoint_scene())

	# ── P2 落盘→清账→load_game 还原检查点（继续钮第一步）──
	_save.record_checkpoint(&"seg_b", &"e", FIX_CHAPTER)   # 三参显式挪游标到非首段
	_check(_sys.save_now() == true, "P2a scratch 落一份含 checkpoint 的档")
	shell_a.queue_free()
	await _m_frames(6)
	GameSave.new_profile()
	_check(_save.checkpoint_scene() == "" and _save.checkpoint_segment() == &"",
			"P2b load 前内存清零（R 流『还原真写』防假绿判例沿用）")
	_check(_sys.load_game() == true, "P2c load_game true（盘=继续钮的数据源）")
	_check(_save.checkpoint_scene() == FIX_CHAPTER
			and _save.checkpoint_segment() == &"seg_b" and _save.checkpoint_entry() == &"e",
			"P2d checkpoint 三件套还原（实际=%s/%s/%s）" % [_save.checkpoint_scene(),
				str(_save.checkpoint_segment()), str(_save.checkpoint_entry())])

	# ── P3 旗→壳落位（继续钮后半场：置旗+直建壳，等价 _continue_game 转场终点）──
	GameSave.resume_pending = true
	var shell_b := await _m_make_shell()
	_check(shell_b.current_segment_id() == &"seg_b",
			"P3a resume 落位检查点段（≠_order[0] 可辨识，spec §4 壳端消费）")
	var seg_inst: StageContent = shell_b._current
	# 落位判据形制注（P3b 首跑绿期校准）：x 恒精确（无横向漂移源），y 有物理
	# 沉降窗（出生 (500,600)→20 帧稳定后 ≈580，地板/高度层吸附所致）——放 64px
	# 沉降容差；段身份 conjunction 在位，RED 期"落错段但坐标巧合"不得假绿。
	var tgt := seg_inst.to_global(seg_inst.entry_position(&"e")) \
		if seg_inst != null else Vector2.INF
	_check(seg_inst != null and seg_inst.segment_id == &"seg_b"
			and shell_b.playable != null
			and is_equal_approx(shell_b.playable.global_position.x, tgt.x)
			and absf(shell_b.playable.global_position.y - tgt.y) <= RESUME_LAND_TOL,
			"P3b 落位=段 b 入口位（entry 通道随段走，y 容差=物理沉降窗，实际=%s 目标=%s）"
			% [str(shell_b.playable.global_position if shell_b.playable else Vector2.INF),
				str(tgt)])
	_check(_save.resume_pending == false, "P3c 旗 first-wins 消费（读后即清，B4 传渡判例同构）")

	# ── P4 错误路径：检查点段不在 _order（档章漂移）→ push_error 响亮回退首段不炸 ──
	shell_b.queue_free()
	await _m_frames(6)
	_save.record_checkpoint(&"ghost_seg", &"default", FIX_CHAPTER)
	GameSave.resume_pending = true
	var shell_c := await _m_make_shell()
	_check(shell_c.current_segment_id() == &"seg_a",
			"P4a 坏段落位回退 _order[0]（push_error 中文报错=被试行为）")
	_check(_save.resume_pending == false, "P4b 回退也消费旗（读档失败不重试不滞留）")

	# ── P5 通关入账：resume 落终点段→判清→终点墙同步链→chapters_done 入账+带盘 ──
	shell_c.queue_free()
	await _m_frames(6)
	_save.record_checkpoint(&"seg_c", &"default", FIX_CHAPTER)
	GameSave.resume_pending = true
	var shell_d := await _m_make_shell()
	_check(shell_d.current_segment_id() == &"seg_c",
			"P5a resume 可落终点段（入账驱动的廉价前置落位，plan Step1③）")
	var evs := {"failed": 0, "finished": 0}
	shell_d.segment_advance_failed.connect(func(_r): evs["failed"] += 1)
	shell_d.chapter_finished.connect(func(): evs["finished"] += 1)
	shell_d.session.mark_cleared(&"seg_c")
	shell_d.switch_segment(&"", &"default")   # 终点墙=同步链（container H6 判例，无在途转场）
	_check(int(evs["finished"]) == 1 and int(evs["failed"]) == 1,
			"P5b 终点段判清→chapter_finished 恰一次（入账腿挂载点真实到达）")
	_check(_save.has_record(_save.NS_CHAPTERS_DONE, &"fix"),
			"P5c 通关事实入账 chapters_done/fix（_maybe_finish_chapter 成功分支新行）")
	await _d_frames(2)   # 帧尾合并落盘（断言前必 await，spec §7.2 判例）
	var snap: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCRATCH_D))
	var led5: Dictionary = (snap as Dictionary).get("ledges", {}) \
		if typeof(snap) == TYPE_DICTIONARY else {}
	var cd5: Dictionary = led5.get(String(_save.NS_CHAPTERS_DONE), {})
	_check(cd5.has("fix"), "P5d 入账即影子带盘（scratch 文件含 chapters_done 户键）")

	# ── P6 旗滞留惰性面（B4.5-T4 修复波第三件，T2 移交②"场景不命中旗滞留腿"）：
	# 壳 _ready 消费条件是"旗起 且 检查点场景==本文件"的合取——本壳不命中转场目标
	# 时旗原样留给真正要落的场景（B4 pending_jump 传渡 first-wins 判例的未命中半面，
	# T2 立法行为本腿钉死覆盖；行为既有=覆盖腿无先红，报告申报）。注意壳出生
	# enter_segment 会把自己的场景反写进检查点（P1b 生产行），故判据必须在
	# _m_make_shell 返回后即读旗——此刻反写已发生但消费判定早已完成（不命中=没碰旗）。
	shell_d.queue_free()
	await _m_frames(6)
	_save.record_checkpoint(&"seg_b", &"e", "res://p6_foreign_scene_not_here.tscn")
	GameSave.resume_pending = true
	var shell_e := await _m_make_shell()
	_check(shell_e.current_segment_id() == &"seg_a",
			"P6a 他场景旗不落本壳（不命中=自然落 _order[0]，无假落位）")
	_check(_save.resume_pending == true,
			"P6b 场景不命中→旗原样滞留（未消费=留给转场目标壳，first-wins 仅命中时清）")
	# 清场：滞留旗不外溢流尾自洁/他套（真实游戏中该旗终被目标壳或 begin_new_profile 收掉）
	GameSave.resume_pending = false
	shell_e.queue_free()
	await _m_frames(6)

	# ── 流尾自洁：账清、旗落、盘净（不外溢 X 流/他套；壳已各腿收讫——
	#    shell_d 于 P6 起头清、shell_e 于 P6 尾清，旧"尾杀 shell_d"位前移，
	#    此处再 queue_free 已释放实例=3684 判例，勿回潮）──
	GameSave.new_profile()
	GameSave.resume_pending = false
	await _d_frames(2)
	_sys.delete_save()
	_flow_done["P"] = true
