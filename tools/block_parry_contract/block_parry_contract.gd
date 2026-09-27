extends Node

## S2-B3 盾反批契约：M 流=修饰核心 B′ 手术（重算回写）的回归流——
## base 捕获、加乘复合按序重算、乱序摘除、同 id 替换、非法型零副作用、
## reset 清账。
## P 流=判定缝三分支（Task4 批入）：靶场仿 attack_lane_contract——test_actor(A)
## 出拳 × street_vendor(V) 受击，场景 helper 逐字移植自 lane（99-107 家族）。
## Q 流=T5 姿态状态自选进出 × 真键盘 K 链（P7 腿）：raw 注入 K → Block 态、
## 序列中挨拳走格挡支（OS 链×缝整合）、序列自动收口回 Idle、输入窗关不劫持、
## K 让位后跳跃仍可用。三件套成对写入零内部捷径——生产写方只有 QuiverActionBlock。
## T6 补腿：弹体弹反/反顶升格/姿态×发射器双向（相位制后平移编号 P13-P16）。
## 本套自 T6 起入 run_matrix 名册，身份见证=ACTOR-GATE（守卫通过行）。
##
## T7 强化（R13，测试强度批）：P16c 由"起飞后定点 30 帧非 Block"改为"打断→
## Move 途中逐帧零 Block + Move 必达"全录像判停；P6c/P13e 加"命中帧起 ≤15 帧
## 离场"护栏（max_lifetime 与采样窗同长的窗缘假绿边角封堵）。
##
## T8 白闪可见性腿（2026-09-24 LDR 判例）：P2g/P2h（格挡弱闪挂/摘）+
## P3j/P3k/P3l（弹反双闪挂/挂/摘），逐物理帧采样 sprite.material 非空首末帧。
##
## ════ 相位制改判 2026-09-27（S2-B4.8 点按序列制，本文件大手术申报）════
## 法源 specs/2026-09-27-s2-b48-block-flow-design.md R1-R11。改判要点：
## ① `parry_window_frames`/`block_started_frame` 双字段退役——P 流全部"帧窗
##   预置/hold 重写/窗修饰"构造消亡；防路前置改直写三件套
##   `is_blocking + block_phase(+block_facing)`（测试捷径，生产写方归 Q 流）。
## ② 既有弹反/格挡/弹体/反顶/发射器腿的伤害/池/旗/击退作废判据**原样保**，
##   只换前置条件（相位+面匹配）。
## ③ 编号说明（默认已裁）：brief 点名的新族号 P8-P12 与在册 T6 旧腿（旧 P8
##   弹体弹反/旧 P9 反顶升格/旧 P10 吞发射器/旧 P11 打断注销）撞号——旧腿
##   判据一字不动、编号整体平移为 P13-P16；五新族顺延取号：
##   P17 方向、P18 序列、P19 后摇架、P20 防路特效回执、P21 兜底时序。
## ④ 新族明细：
##   P17 方向族（R6/R7）：同面弹反成/背面来袭=常规满伤（伤害+Hurt+扣池+
##     攻击方自慢放照常，D12 二元）/背面×GUARD 仍满伤（错面不降级）/
##     纵深威胁按 x 划侧挡成（已知行为锁）/门序源锁（方向门在车道门下游）
##     + "平局归右 >="形制源锁。
##   P18 序列族（R1/R8/R9/R10 面）：点按全程相位链 NONE→OUT→GUARD→自动 Idle
##     采样/弹反成功后不跳相续播（R8，命中拍后 is_blocking 连续存活≥7 拍
##     活体锁）/序列中再按 K 不重入（GUARD 恒不回退 OUT）/白名单外（Hurt
##     在途）持 K 不起架 + 白名单源码锁（三连段在场、空中 Attack 绝不在列）。
##   P19 后摇架族（R10）：raw J 出招中按 K → 取消进序列（空中不食言=不测）。
##   P20 防路特效回执族（R11 改判）：hit_landed 采集——弹反支 &"parry"、
##     格挡支 &"block"、背面来袭 &"default"（滑常规支证明）+ 防路 strength
##     =0 参 vs 常规支击打值对读。
##   P21 兜底时序族（spec §2.3）：test_actor 无 block 槽=过渡期实况——
##     OUT≈12 拍实测域/窗内挡击=弹反（出手提前量走 w_cal 校准基）/
##     全程 12+30 拍量级/GUARD 毕自动回 Idle 且松键不回流。
## ⑤ R8 体检四档红据（/tmp/opencode/b48_t0/red_*.log）：a 摘方向门恒真→P17
##   红；b 摘相位推进（信标首行 return）→P18/P21 红；c 白名单删地面攻击→
##   P19/P18e2 红；d 防路 emit 注释→P20 红。
##
## 【测试特权豁免申报】（hit_feedback T4 同款制度）：P 流直写
## is_blocking/block_phase/block_facing（判定缝捷径，生产义务归 Q 流）、Q 流
## 手拨 A._skin.facing_x（模拟"面朝敌人"，enter 快照取此值）、CombatSystem
## 公开入口直推 knockout、私制重拳换挂 attack_data 副本、源文本形制锁——
## 皆台架特权非生产写方形制范例，勿以本套为抄写模板。
##
## Step0 探针实锤（2026-09-23）史注：定格期间物理帧号照走、Area 回调被暂停门
## 扣到恢复帧才发；无暂停期"观察循环见旗帧 == 回调帧"（j=0）。⚠ B4.7 R2 后
## 弹反不再停世界；⚠ B4.8 相位制后"帧窗蚕食"命题整体消亡（弹反窗=防守者
## 动画时钟）。**新时基约定：w_cal（P1 实测出手→命中帧距）继续采用，仅作
## 兜底时序腿的出手提前量校准，不再参与任何判定预置。**
## 几何速记（P17 方向证人构造依据，run1 实证定档勿空推）：_place(V,A,offset)
## 语义=V 摆到 A+offset；(80,30)/(20,30)=西威胁 sign-1，(-30,-40)=Δy 主导纵深
## 但 x 判东 sign+1（hit 盒心随动画前伸，静态 Area 位模型不可靠已证伪）。
## 运行：godot --headless --path . res://tools/block_parry_contract/block_parry_contract.tscn

const A_AT := "res://addons/quiver.beat_em_up/characters/quiver_attributes.gd"
const HURT_BOX_SRC := "res://addons/quiver.beat_em_up/combat/collision_areas/quiver_hurt_box.gd"
const BLOCK_STATE_SRC := "res://_beat_em_up/action_states/quiver_action_block.gd"
const M_BASE_MOVE := 600.0
## raw J 注入设备号（hit_feedback T1 探针实锤判例：attack 绑定 device=16，
## 注入 device=-1 被 is_action_pressed 拒匹配——判据恒"注入设备==绑定设备"）
const J_DEV := 16

# ── P 流场景段（仿 lane 骨架）─────────────────────────────────────────────────
const Kit := preload("res://tools/matrix_runner/test_actor_kit.gd")
const ACTOR_SCENE := Kit.ACTOR_SCENE
const VENDOR := "res://characters/neutrals/street_vendor/street_vendor.tscn"
const SPELL_SCENE := "res://spells/fire_ball/fire_ball.tscn"
const SPELL_DEF := "res://spells/fire_ball/resources/fire_ball_definition.tres"
## 双方池上限均=默认 600（V 走 tres 缺省，A tres 显式 600）——P 流按池值判
## "扣没扣"的基准线
const POOL0 := 600.0

var _fails := 0
var _finished_m := false
var _finished_p := false
var _finished_q := false
## P20 回执采集（hit_feedback E 流同款形制：自采自摘，[point, style, strength]）
var _landed: Array = []


func _ready() -> void:
	# B4.5 测试卫生条款（spec §2）：影子落盘一律重定向 scratch，永不碰生产槽
	#（scene runner 里 /root/SaveSystem 恒在场，取空即当场炸=响亮红，不静默跳闸）
	get_node_or_null(^"/root/SaveSystem").slot_path = "user://b45_block_parry_scratch.json"
	await _flow_modifiers()
	# 判例（AGENTS）：子协程运行时炸掉后主协程照常续跑——每流自带完成旗单独锁
	_check(_finished_m, "M 流全序列执行完成（协程静默中断防线）")
	await _flow_parry()
	_check(_finished_p, "P 流全序列执行完成（协程静默中断防线）")
	await _flow_stance()
	_check(_finished_q, "Q 流全序列执行完成（协程静默中断防线）")
	get_node_or_null(^"/root/SaveSystem").delete_save()   # B4.5 测试卫生：套尾删净 scratch 不过夜
	print("════════ block-parry-contract: %s ════════" % ("PASS" if _fails == 0 else "FAIL"))
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails += 1
	print("  %s: %s" % ["PASS" if ok else "FAIL", label])


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


## 纯 RefCounted 消费（不建场景）：M 腿只碰 move_speed/reset 路径，
## 两路径均不解引用 character_node（apply_knock 才查 null，本流不调它）。
func _fresh_attrs() -> QuiverAttributes:
	var a: QuiverAttributes = load(A_AT).new()
	return a


func _flow_modifiers() -> void:
	var a := _fresh_attrs()
	# M1 base 捕获+重算：×0.5 → +100 → (600+100)×0.5=350（旧世界=400，必红）
	a.add_modifier(&"m_mult", &"move_speed", "multiply", 0.5)
	_check(a.move_speed == 300, "M1a 单乘回写=300（两世界同值，护住 locomotion）")
	a.add_modifier(&"m_add", &"move_speed", "add", 100.0)
	_check(a.move_speed == 350, "M1b 加乘复合按序重算=350")
	# M2 乱序摘除（旧世界：先摘 m_mult 会把 600 写回、再摘 m_add 落 300——必红）
	a.remove_modifier(&"m_mult")
	_check(a.move_speed == 700, "M2a 摘乘余加=700")
	a.remove_modifier(&"m_add")
	_check(a.move_speed == 600, "M2b 全摘归 base")
	# M3 同 id 刷新（replace）
	a.add_modifier(&"m_dup", &"move_speed", "multiply", 0.5)
	a.add_modifier(&"m_dup", &"move_speed", "multiply", 0.5)
	_check(a.move_speed == 300, "M3a 同 id 再挂=替换非叠乘（600 非 150）")
	a.remove_modifier(&"m_dup")
	_check(a.move_speed == 600, "M3b 一次摘净")
	# M4 非法 type：告警+不入账
	a.add_modifier(&"m_bad", &"move_speed", "wat", 2.0)
	_check(a.move_speed == 600, "M4a 非法操作型不改值")
	# M5 reset 清账（护人/locomotion 修饰不跨死亡）
	a.add_modifier(&"m_life", &"move_speed", "multiply", 0.5)
	a.reset()
	_check(a.move_speed == 600, "M5a reset 后受管值=base（旧世界：记录残留）")
	a.remove_modifier(&"m_life")
	_check(a.move_speed == 600, "M5b 死账摘除=无操作（记录已清）")
	# M6（相位制改判 2026-09-27）：新相位域是运行时态非修饰域——
	# reset() 必须清零 block_phase/block_facing（旧帧窗两字段的清账位升格为锁）
	var m6 := _fresh_attrs()
	m6.is_blocking = true
	m6.block_phase = QuiverAttributes.BlockPhase.GUARD
	m6.block_facing = Vector2(-1, 0)
	m6.reset()
	_check(m6.block_phase == QuiverAttributes.BlockPhase.NONE
			and m6.block_facing == Vector2.ZERO and not m6.is_blocking,
			"M6 reset 清相位三件套（NONE/零向量/总闸关）")
	_finished_m = true

# ═══════════════════ P 流：判定缝三分支（相位制改判 2026-09-27） ═════════════
# 场景 helper 逐字移植自 attack_lane_contract（主权法：只读消费 test_actor，
# 判态走 state_name，绝不代 runner 创建）。防路前置=直写三件套
# is_blocking+block_phase+block_facing（台架捷径；旧 hold/target_delta 帧窗
# 构造随字段退役整体消亡）。

func _wait_state(ch: QuiverCharacter, path: String, cap: int = 600) -> bool:
	for _i in cap:
		if str(ch.state_machine.state_name) == path:
			return true
		await get_tree().physics_frame
	return str(ch.state_machine.state_name) == path


## 头部三态守卫（input_channel 同款只读阶梯；缺席打可读红、绝不代 runner 创建）
func _guard_actor() -> bool:
	var remedy := "先跑 bash tools/matrix_runner/run_matrix.sh --ensure-only 建好 test_actor"
	# 终审波：判态结构性断奶 ensure()——peek() 零副作用三态分类，
	# ABSENT/NEEDS_IMPORT 两支都只打处方红，创建泄漏在类型上不可能
	var st: int = Kit.peek()  # 只读分类（peek 承诺零副作用、永不建档）
	match st:
		Kit.READY:
			print("ACTOR-GATE: test_actor 就绪（只读三态守卫通过）")
			return true
		Kit.NEEDS_IMPORT:
			_check(false, "替身守卫：test_actor 已建未导入（%s）" % remedy)
		Kit.ABSENT:
			_check(false, "替身守卫：test_actor 缺席（%s）" % remedy)
		_:
			_check(false, "替身守卫：peek() 返回未知态 %d（kit 契约破损，查 test_actor_kit）" % st)
	return false


func _attack(actor: QuiverCharacter, dir: Vector2) -> void:
	actor._skin.skin_direction = dir
	actor.state_machine.transition_to("Ground/Combo1")


func _place(vendor: QuiverCharacter, actor: QuiverCharacter, offset: Vector2) -> void:
	vendor.global_position = actor.global_position + offset
	await _frames(6)


## 防路三件套直写（台架捷径，相位制改判 2026-09-27）：Q 流锁生产写方形制，
## 本流只钉判定缝读值语义。facing_x=盾面朝向（±1，威胁侧匹配判据 R6）。
## 几何→威胁侧实证表（run1 定档，勿再凭 Area 位空推——攻击盒心随动画前伸）：
## · _place(V, A, (80,30)) / (20,30) → 西威胁 sign -1（盾朝西 -1=同面）
## · _place(V, A, (-30,-40)) → Δy 主导纵深位、x 判东 sign +1（盾朝东 +1=同面）
func _set_guard(v: QuiverCharacter, phase: QuiverAttributes.BlockPhase, facing_x: float) -> void:
	v.attributes.is_blocking = true
	v.attributes.block_phase = phase
	v.attributes.block_facing = Vector2(facing_x, 0.0)


func _clear_guard(v: QuiverCharacter) -> void:
	v.attributes.is_blocking = false
	v.attributes.block_phase = QuiverAttributes.BlockPhase.NONE
	v.attributes.block_facing = Vector2.ZERO


## 排空在途命中定格（探针 B1 史判例）——B4.8 后防路不打断序列、无全局定格，
## 本函数=若 freeze_frames 复活的保险丝（现行恒秒过，语义保留理由同旧批）。
func _drain_freeze() -> void:
	for _i in 60:
		if not get_tree().paused:
			break
		await get_tree().physics_frame
	await _frames(2)


## 皮肤精灵解析（白闪可见性腿的前置快照，R15 判例：先取引用再进采样环，
## 途中失效率低且红据可诊断）——与 _flash 同款形制：角色子树第一个
## AnimatedSprite2D。注意（2026-09-24 判例）：本构建 CanvasItem 无
## material_overlay 属性，闪白合成通道 = sprite.material 换挂。
func _skin_sprite(ch: QuiverCharacter) -> CanvasItem:
	var sprites := ch.find_children("*", "AnimatedSprite2D", true, false)
	return sprites[0] if not sprites.is_empty() else null


## 通用一发：逐帧采样双方血量/池轨迹、Hurt 落态、暂停可见、白闪挂摘。
## 相位制后**不再写任何防路字段**（前置由 _set_guard 预写，采样环零重写——
## 相位不会自己漂移，旧"hold 每帧重写 started"构造随帧窗消亡）。
## 命中拍现场三采：v_state_at_hit / v_phase_at_hit / v_style_at_hit（血降拍
## 或攻方池首降拍同口——R9 序列保持、P20 回执族、P21 兜底族的"命中瞬间"
## 证人）+ v_alive_after（命中后 8 拍 is_blocking 存活计数——序列不被防路
## 击中断的活体锁，R8/R9 行为面）。池轨迹用 min 捕获：受击回 Idle 后 refill
## 会把余量抬回，事后采样会漏判。
func _shot(vendor: QuiverCharacter, actor: QuiverCharacter,
		v_ov: CanvasItem = null, a_ov: CanvasItem = null) -> Dictionary:
	var r := {
		"f_call": 0, "f_hit": -1,
		"v_hp0": 0.0, "v_hp_drop": 0.0, "v_pool_min": POOL0, "v_hurt": false,
		"a_hp0": 0.0, "a_hp_drop": 0.0, "a_pool_min": POOL0, "a_hurt": false,
		"a_knockout": false, "paused_seen": false,
		"a_scale_min": 1.0, "v_scale_min": 1.0,
		"v_ov_first": -1, "v_ov_last": -1,
		"a_ov_first": -1, "a_ov_last": -1, "a_pool_seam": -1,
		"v_state_at_hit": "", "v_phase_at_hit": -1, "v_style_at_hit": &"",
		"v_alive_after": 0,
	}
	r.v_hp0 = vendor.attributes.health_current
	r.a_hp0 = actor.attributes.health_current
	_attack(actor, Vector2.RIGHT)
	r.f_call = Engine.get_physics_frames()
	for _i in 240:
		await get_tree().physics_frame
		if get_tree().paused:
			r.paused_seen = true
		r.a_scale_min = minf(r.a_scale_min, actor.anim_time_scale())
		r.v_scale_min = minf(r.v_scale_min, vendor.anim_time_scale())
		# 首血降即锁缝帧并停止累加（单发单结算纪律逐字保）；免伤路血不降，
		# 命中拍=攻方池首降帧（P3j seam 同源）
		if r.f_hit < 0 and vendor.attributes.health_current < r.v_hp0:
			r.v_hp_drop = r.v_hp0 - vendor.attributes.health_current
			r.f_hit = Engine.get_physics_frames()
			r.v_state_at_hit = str(vendor.state_machine.state_name)
			r.v_phase_at_hit = vendor.attributes.block_phase
			r.v_style_at_hit = _last_style()
		if actor.attributes.health_current < r.a_hp0:
			r.a_hp_drop = r.a_hp0 - actor.attributes.health_current
		r.v_pool_min = minf(r.v_pool_min, vendor.attributes.resistance_current)
		r.a_pool_min = minf(r.a_pool_min, actor.attributes.resistance_current)
		if r.a_pool_seam < 0 and actor.attributes.resistance_current < POOL0:
			r.a_pool_seam = Engine.get_physics_frames()
			if r.v_state_at_hit == "" and r.f_hit < 0:
				r.v_state_at_hit = str(vendor.state_machine.state_name)
				r.v_phase_at_hit = vendor.attributes.block_phase
				r.v_style_at_hit = _last_style()
		# 命中拍后 8 拍存活窗采样（两路 seam 统一在 f_hit/a_pool_seam 定拍后）
		var seam: int = r.f_hit if r.f_hit >= 0 else r.a_pool_seam
		if seam >= 0:
			var d := Engine.get_physics_frames() - seam
			if d >= 1 and d <= 8 and vendor.attributes.is_blocking:
				r.v_alive_after += 1
		if v_ov != null and v_ov.material != null:
			if r.v_ov_first < 0:
				r.v_ov_first = Engine.get_physics_frames()
			r.v_ov_last = Engine.get_physics_frames()
		if a_ov != null and a_ov.material != null:
			if r.a_ov_first < 0:
				r.a_ov_first = Engine.get_physics_frames()
			r.a_ov_last = Engine.get_physics_frames()
		if str(vendor.state_machine.state_name) == "Ground/Hurt":
			r.v_hurt = true
		if str(actor.state_machine.state_name) == "Ground/Hurt":
			r.a_hurt = true
		# 反顶升格观察窗：攻击者被自己的弹反顶进 Air/Knockout/*
		if str(actor.state_machine.state_name).contains("Knockout"):
			r.a_knockout = true
	return r


## P20 回执采集（自采自摘，hit_feedback E 流同款；_shot 环内按拍读取）
func _on_landed_capture(point: Vector2, style: StringName, strength: float, _dir: Vector2) -> void:
	_landed.append([point, style, strength])


func _last_style() -> StringName:
	return _landed[_landed.size() - 1][1] if not _landed.is_empty() else &""


## 腿间卫生：双方回池回待机、防路三件套清零、排空定格、复位几何（池显式
## refill——受击归 Idle 的自动回气时机不属本契约命题，不押注；血量差值走
## 相对读数不依赖满血，唯防路旗必须显式归零，防上一腿的"真"漏进下一腿）。
func _clean(vendor: QuiverCharacter, actor: QuiverCharacter) -> void:
	_clear_guard(vendor)
	await _drain_freeze()
	await _wait_state(actor, "Ground/Move/Idle", 600)
	await _wait_state(vendor, "Ground/Move/Idle", 600)
	vendor.attributes.refill_resistance()
	actor.attributes.refill_resistance()
	await _place(vendor, actor, Vector2(80, 30))


func _flow_parry() -> void:
	if not _guard_actor():
		return
	Events.hit_landed.connect(_on_landed_capture)
	var stage := Node2D.new()
	add_child(stage)
	var actor: QuiverCharacter = (load(ACTOR_SCENE) as PackedScene).instantiate()
	var vendor: QuiverCharacter = (load(VENDOR) as PackedScene).instantiate()
	stage.add_child(actor)
	stage.add_child(vendor)
	actor.global_position = Vector2(500, 400)
	vendor.global_position = Vector2(500, 280)
	await _frames(18)
	var ok0: bool = await _wait_state(actor, "Ground/Move/Idle", 120)
	_check(ok0 and str(vendor.state_machine.state_name) != "", "P0 替身/小贩入场就绪")
	await _place(vendor, actor, Vector2(80, 30))
	vendor.attributes.reset()
	actor.attributes.refill_resistance()

	# ── P1 无防回归：伤害/击退逐字如旧（改造前后零可观测差哨兵）──
	var r1 := await _shot(vendor, actor)
	var w_cal: int = r1.f_hit - r1.f_call  # 同几何出手→缝帧距（兜底时序腿校准基）
	_check(r1.v_hp_drop == 10.0, "P1a 未格挡掉血恰 10（out_mult=1.0 哨兵，实际 %.1f）" % r1.v_hp_drop)
	_check(r1.v_hurt, "P1b 未格挡 V 入 Ground/Hurt（受击链原样）")
	_check(r1.v_pool_min == POOL0 - 60.0, "P1c 未格挡 V 池 600→540（击退派发逐字如旧）")
	_check(r1.a_hp_drop == 0.0 and r1.a_pool_min >= POOL0 and not r1.a_hurt,
			"P1d 攻击方全程无损（血/池/Hurt 三不动）")
	_check(w_cal >= 1 and w_cal <= 120, "P1e 出手→命中帧距校准 w_cal=%d 在有效域" % w_cal)
	print("[b48-p] w_cal=%d（相位制：仅作 P21 兜底腿出手提前量校准）" % w_cal)
	await _clean(vendor, actor)

	# ── P2 格挡（GUARD 相位+同面）：伤害×ratio、击退值整颗作废 ──
	# 相位制改判 2026-09-27：旧"超窗 started=now−99"前置 → 直写 GUARD+同面
	# （西威胁盾朝西 -1）。判据伤害/池/受击豁免/白闪逐字保。
	var ov_v := _skin_sprite(vendor)
	var ov_a := _skin_sprite(actor)
	print("[b3-flash] 皮肤精灵 v=%s a=%s" % [ov_v, ov_a])
	_set_guard(vendor, QuiverAttributes.BlockPhase.GUARD, -1.0)
	var r2 := await _shot(vendor, actor, ov_v, ov_a)
	_check(r2.v_hp_drop == 4.0, "P2a 格挡掉血恰 4=10×0.4（GUARD 相位，实际 %.1f）" % r2.v_hp_drop)
	_check(not r2.v_hurt, "P2b 格挡 V 不入 Hurt（击退派发整颗吞掉）")
	_check(r2.v_pool_min >= POOL0, "P2c 格挡 V 池一分不扣（%.0f）" % r2.v_pool_min)
	_check(r2.a_hp_drop == 0.0 and r2.a_pool_min >= POOL0, "P2d 格挡下攻击方无波及")
	_check(r2.f_hit >= 0 and int(r2.v_phase_at_hit) == QuiverAttributes.BlockPhase.GUARD,
			"P2e 命中拍现场=GUARD 相位（相位分流证人，实得 %s）" % r2.v_phase_at_hit)
	# 白闪可见性（LDR 判例 2026-09-24 形制锁，判据逐字不动）：
	_check(r2.f_hit >= 0 and r2.v_ov_first >= 0 and r2.v_ov_first - r2.f_hit <= 2,
			"P2g 格挡命中后 ≤2 物理帧防守方皮肤闪白 material 挂上（缝帧=%s 首见=%s）"
			% [r2.f_hit, r2.v_ov_first])
	_check(r2.f_hit >= 0 and r2.v_ov_last >= 0 and r2.v_ov_last - r2.f_hit <= 30,
			"P2h 格挡弱闪 ≤30 帧后已摘净（末见=%s；240 帧全采样无残留=自动含'回原底材'）"
			% r2.v_ov_last)
	await _clean(vendor, actor)

	# ── P3 弹反（OUT 相位+同面）：免伤+反顶+双白闪，判据原样保 ──
	_set_guard(vendor, QuiverAttributes.BlockPhase.OUT, -1.0)
	var r3 := await _shot(vendor, actor, ov_v, ov_a)
	_check(r3.v_hp_drop == 0.0, "P3a 弹反 V 免伤（实际 %.1f）" % r3.v_hp_drop)
	_check(r3.v_pool_min >= POOL0, "P3b 弹反 V 池一分不扣（%.0f）" % r3.v_pool_min)
	_check(r3.a_pool_min == POOL0 - 60.0, "P3c 弹反反顶：A 池 600→540（实际 %.0f）" % r3.a_pool_min)
	_check(r3.a_hurt, "P3d 弹反反顶：A 被拽进自己的 Ground/Hurt（顶回去=播自己的挨打姿势）")
	# B4.7 R2 改道判停三件套（判据逐字不动）：
	_check(r3.a_scale_min <= 0.001,
			"P3e 弹反拍=只冻攻击者（其动画倍速全程最低 %.2f，B4.7 R2 单角色）"
			% r3.a_scale_min)
	_check(r3.v_scale_min >= 0.999,
			"P3e2 弹反全程防守方满速（最低 %.2f，罚站不罚守方）" % r3.v_scale_min)
	_check(not r3.paused_seen,
			"P3e3 弹反全程世界零暂停（tree.paused 恒 false；若有人重开全局定格本腿响红）")
	_check(int(r3.v_phase_at_hit) == QuiverAttributes.BlockPhase.OUT,
			"P3e4 命中拍现场=OUT 相位（弹反窗=相位非帧数，实得 %s）" % r3.v_phase_at_hit)
	# 弹反三件套之视觉两件（形制与窗宽逐字保；seam=攻方池首降帧）：
	_check(r3.a_pool_seam >= 0 and r3.v_ov_first >= 0 and r3.v_ov_first - r3.a_pool_seam <= 2,
			"P3j 弹反：防守方强白闪 ≤2 帧内挂上（seam=%s 首见=%s）"
			% [r3.a_pool_seam, r3.v_ov_first])
	_check(r3.a_pool_seam >= 0 and r3.a_ov_first >= 0 and r3.a_ov_first - r3.a_pool_seam <= 2,
			"P3k 弹反：攻击方同拍弱白闪 ≤2 帧内挂上（首见=%s）" % r3.a_ov_first)
	_check(r3.a_pool_seam >= 0 and r3.v_ov_last >= 0 and r3.a_ov_last >= 0
			and maxf(float(r3.v_ov_last), float(r3.a_ov_last)) - r3.a_pool_seam <= 40,
			"P3l 弹反双方白闪 ≤40 帧内全摘净（防守末见=%s / 攻击末见=%s）"
			% [r3.v_ov_last, r3.a_ov_last])
	# （相位制改判 2026-09-27 退役案卷）旧 P3f/P3g"delta==窗归格挡"、旧
	# P3h/P3i"窗修饰压 1 严格<哨兵"、旧 P4 族"每角色窗配置 int 锁"、旧
	# P5a/P5d/P5g"窗×2 判别位"——判据对象 parry_window_frames 整体出局；
	# 其语义位由相位分流（P2e/P3e4）与 P17 方向族接替，reset 清账位由 M6
	# 接管；"严格 <"边界命题随帧窗消亡（相位制无边界帧）。
	await _clean(vendor, actor)

	# ── P4′ 护人输出乘数腿（原 P5 族帧窗腿退役后瘦身顺延）：attack_output
	#    全程走修饰路（单写者哨兵），常规支乘算与撤除还原判据原样保 ──
	actor.attributes.add_modifier(&"escort_power", &"attack_output", "multiply", 0.3, self)
	_check(actor.attributes.attack_output == 0.3, "P4a 输出×0.3 生效（修饰路）")
	var r4a := await _shot(vendor, actor)
	_check(r4a.v_hp_drop == 3.0, "P4b 护人拳未防掉 3=10×0.3（输出乘数进常规支，实际 %.1f）" % r4a.v_hp_drop)
	actor.attributes.remove_modifiers_from_source(self)
	_check(actor.attributes.attack_output == 1.0, "P4c 撤修饰还原 1.0")
	await _clean(vendor, actor)
	var r4b := await _shot(vendor, actor)
	_check(r4b.v_hp_drop == 10.0, "P4d 撤除后未防回 10（实际 %.1f）" % r4b.v_hp_drop)
	await _clean(vendor, actor)

	# ── P6 弹体被挡（法术管线共缝：弹体 character_attributes=施法者属性
	#    判例逐字保；弹自西来 → 同面=盾朝西 -1）──
	_set_guard(vendor, QuiverAttributes.BlockPhase.GUARD, -1.0)
	var spell_scene: PackedScene = load(SPELL_SCENE)
	var spell_def: SpellDefinition = load(SPELL_DEF)
	var ball := spell_scene.instantiate() as SpellBase
	stage.add_child(ball)
	ball.global_position = Vector2(vendor.global_position.x - 160.0, vendor.global_position.y)
	ball.cast(actor, spell_def, Vector2.RIGHT)
	var hp6: float = vendor.attributes.health_current
	var v_hurt6 := false
	var v_pool6_min := POOL0
	var ball_spent := false
	# R13②帧距护栏（判据逐字保）：命中帧起 ≤15 帧离场
	var f_hit6 := -1
	var f_spent6 := -1
	for _i in 300:
		await get_tree().physics_frame
		if f_hit6 < 0 and vendor.attributes.health_current < hp6:
			f_hit6 = Engine.get_physics_frames()
		if str(vendor.state_machine.state_name) == "Ground/Hurt":
			v_hurt6 = true
		v_pool6_min = minf(v_pool6_min, vendor.attributes.resistance_current)
		if is_instance_valid(ball) and ball.state != SpellBase.SpellState.ACTIVE:
			f_spent6 = Engine.get_physics_frames()
			ball_spent = true
			break
		if not is_instance_valid(ball):
			f_spent6 = Engine.get_physics_frames()
			ball_spent = true
			break
	var drop6: float = hp6 - vendor.attributes.health_current
	_check(drop6 == 4.0, "P6a 弹体被挡掉血恰 4=弹伤10×1.0×0.4（实际 %.1f）" % drop6)
	_check(not v_hurt6 and v_pool6_min >= POOL0, "P6b 弹体被挡无反顶无池耗无受击态")
	_check(ball_spent and f_hit6 >= 0 and f_spent6 >= f_hit6
			and f_spent6 - f_hit6 <= 15,
			"P6c 格挡支公共义务：on_target_hit 回执在命中帧后 ≤15 帧内送达离场"
			+ "（命中帧=%d 离场帧=%d；穿体飞到超时≈300f 必炸本护栏）"
			% [f_hit6, f_spent6])
	if ball_spent and is_instance_valid(ball):
		ball.destroy()

	# ── P13 弹体弹反（原 P8 族平移编号，判据逐字保；OUT+同面 ⇒ 弹道走
	#    弹反支；反顶继承 spell_base 绑定的施法者属性 ⇒ A 池 600→540）──
	await _clean(vendor, actor)
	vendor.attributes.reset()
	_set_guard(vendor, QuiverAttributes.BlockPhase.OUT, -1.0)
	var ball2 := spell_scene.instantiate() as SpellBase
	stage.add_child(ball2)
	ball2.global_position = Vector2(vendor.global_position.x - 160.0, vendor.global_position.y)
	ball2.cast(actor, spell_def, Vector2.RIGHT)
	var hp8: float = vendor.attributes.health_current
	var a_hp8_0: float = actor.attributes.health_current
	var v_hurt8 := false
	var v_pool8_min := POOL0
	var a_pool8_min := POOL0
	var a_hurt8 := false
	var ball8_spent := false
	var grace8 := 0
	# R13②帧距护栏（P6c 同款）：观测位=反顶削池首帧
	var f_hit8 := -1
	var f_spent8 := -1
	for _i in 300:
		await get_tree().physics_frame
		if f_hit8 < 0 and actor.attributes.resistance_current < POOL0:
			f_hit8 = Engine.get_physics_frames()
		if str(vendor.state_machine.state_name) == "Ground/Hurt":
			v_hurt8 = true
		v_pool8_min = minf(v_pool8_min, vendor.attributes.resistance_current)
		a_pool8_min = minf(a_pool8_min, actor.attributes.resistance_current)
		if str(actor.state_machine.state_name) == "Ground/Hurt":
			a_hurt8 = true
		if ball8_spent:
			grace8 += 1
			if grace8 >= 30:
				break
		if not is_instance_valid(ball2) or ball2.state != SpellBase.SpellState.ACTIVE:
			if not ball8_spent:
				f_spent8 = Engine.get_physics_frames()
			ball8_spent = true
	_check(hp8 - vendor.attributes.health_current == 0.0,
			"P13a 弹体弹反 V 免伤（实际掉 %.1f）" % (hp8 - vendor.attributes.health_current))
	_check(v_pool8_min >= POOL0 and not v_hurt8,
			"P13b 弹反不磨 V 池不入受击态（池最低 %.0f）" % v_pool8_min)
	_check(a_pool8_min == POOL0 - 60.0,
			"P13c 弹体反顶回施法者头上来：A 池 600→540（实际最低 %.0f）" % a_pool8_min)
	_check(a_hurt8 and actor.attributes.health_current == a_hp8_0,
			"P13d 施法者被反顶进 Hurt 但零伤害（弹反支无反顶伤害要素）")
	_check(ball8_spent and f_hit8 >= 0 and f_spent8 >= f_hit8
			and f_spent8 - f_hit8 <= 15,
			"P13e 弹反支公共义务：on_target_hit 回执在命中帧后 ≤15 帧内送达离场"
			+ "（命中帧=%d 离场帧=%d；穿体飞到超时≈300f 必炸本护栏）"
			% [f_hit8, f_spent8])

	# ── P14 反顶升格（原 P9 族平移编号，判据逐字保）：攻击方余池 50 吃
	#    弹反 K=60 ⇒ 统一模型破池自动升格 knockout ──
	await _clean(vendor, actor)
	vendor.attributes.reset()
	_set_guard(vendor, QuiverAttributes.BlockPhase.OUT, -1.0)
	actor.attributes.resistance_current = 50.0
	var r9 := await _shot(vendor, actor)
	_check(r9.v_hp_drop == 0.0 and r9.v_pool_min >= POOL0,
			"P14a 格挡方 V 全程无伤（实际掉 %.1f）" % r9.v_hp_drop)
	_check(r9.a_knockout and not r9.a_hurt,
			"P14b K60≥R50 ⇒ 施法者被顶进 Air/Knockout/*（升格，非 Hurt）")
	_check(r9.a_pool_min == 0.0,
			"P14c 升格清空池（apply_knock launched 支 =0 定档，实际最低 %.0f）" % r9.a_pool_min)
	_check(r9.a_hp_drop == 0.0,
			"P14d 升格轰飞不掉施法者血（反顶只位移硬直不带伤害）")

	# ════ P17 方向族（B4.8 新族 R6/R7：相位即窗、x 一票）════
	# 两处实锤可命中几何（run1 定档；hit Area 全局位随动画前伸，盒心相对防守
	# hurt 盒心的侧向=判侧真相）：
	# · (80,30)=西威胁 sign -1（P1/P2/P3 本尊框架——同面弹反成已由 P3 绿档见证）
	# · (-30,-40)=Δy 主导纵深位、x 判东侧 sign +1（run1 实证 threat +1）
	# 本族钉三面：背面来袭滑常规（伤害/池/Hurt/慢放全套）、错面×GUARD 不降级、
	# 纵深来向按 x 划侧且翻侧即翻转待遇（=不看 y 的镜像对读）。
	await _clean(vendor, actor)
	vendor.attributes.reset()
	# P17a 西威胁 × 盾朝东=背面 → 视同没架满伤全套（掉 10+入 Hurt+扣池）
	await _place(vendor, actor, Vector2(80, 30))
	_set_guard(vendor, QuiverAttributes.BlockPhase.OUT, 1.0)
	var r17a := await _shot(vendor, actor)
	_check(r17a.v_hp_drop == 10.0 and r17a.v_hurt and r17a.v_pool_min == POOL0 - 60.0,
			"P17a 背面来袭=视同没架满伤全套（掉 10+入 Hurt+扣池，实际 %.1f）" % r17a.v_hp_drop)
	_check(r17a.a_scale_min < 0.999 and r17a.a_pool_min >= POOL0 and not r17a.a_hurt,
			"P17b 背面来袭攻击方自慢放照常、零反顶（滑常规支时间面证人，最低倍速 %.2f）"
			% r17a.a_scale_min)
	# P17c 背面 × GUARD 仍满伤（相位不豁免错面——D12 二元）
	await _clean(vendor, actor)
	vendor.attributes.reset()
	await _place(vendor, actor, Vector2(80, 30))
	_set_guard(vendor, QuiverAttributes.BlockPhase.GUARD, 1.0)
	var r17c := await _shot(vendor, actor)
	_check(r17c.v_hp_drop == 10.0,
			"P17c 背面×GUARD 相位仍满伤 10（错面不降级半伤，实际 %.1f）" % r17c.v_hp_drop)
	# P17d 纵深东威胁 × 盾朝东=同面弹反成（面匹配语义镜像侧对读 P3）
	await _clean(vendor, actor)
	vendor.attributes.reset()
	await _place(vendor, actor, Vector2(-30, -40))
	_set_guard(vendor, QuiverAttributes.BlockPhase.OUT, 1.0)
	var r17d := await _shot(vendor, actor)
	_check(r17d.v_hp_drop == 0.0 and r17d.a_pool_min == POOL0 - 60.0,
			"P17d 纵深东威胁×盾朝东=同面弹反成（V 免伤 A 池 540，实际掉 %.1f）" % r17d.v_hp_drop)
	# P17e 纵深来袭按 x 划侧挡成（Δy=40 主导、x 同侧 → 格挡 4=已知行为锁，
	#    设计基线 §1"挡得住挡不住只看横向"，非 bug）
	await _clean(vendor, actor)
	vendor.attributes.reset()
	await _place(vendor, actor, Vector2(-30, -40))
	_set_guard(vendor, QuiverAttributes.BlockPhase.GUARD, 1.0)
	var r17e := await _shot(vendor, actor)
	_check(r17e.v_hp_drop == 4.0,
			"P17e 纵深来袭按 x 划侧挡成（Δy=40 主导、x 同侧 → 格挡 4，实际 %.1f）" % r17e.v_hp_drop)
	# P17f 同几何翻盾面=待遇翻转（判侧只看 x 不看 y 的镜像证人）
	await _clean(vendor, actor)
	vendor.attributes.reset()
	await _place(vendor, actor, Vector2(-30, -40))
	_set_guard(vendor, QuiverAttributes.BlockPhase.GUARD, -1.0)
	var r17f := await _shot(vendor, actor)
	_check(r17f.v_hp_drop == 10.0,
			"P17f 纵深同拳×翻盾面 → 满伤 10（侧向由 x 独裁，实际 %.1f）" % r17f.v_hp_drop)
	# P17g/h 门序+平局形制源文本锁（R7 机检 / R6 "≥"；K1b 源码锁先例）
	var hb_src := FileAccess.get_file_as_string(HURT_BOX_SRC)
	var i_lane := hb_src.find("if not _can_be_attacked_by(")
	var i_dir := hb_src.find("var threat_sign :=")
	_check(i_lane >= 0 and i_dir > i_lane,
			"P17g 门序源锁：方向门(%d)在车道门(%d)下游，R7 明令" % [i_dir, i_lane])
	_check(hb_src.contains("contact.x >= global_position.x"),
			"P17h 平局归右源锁：`contact.x >= global_position.x` 形制在场（R6）")

	# ════ P20 防路特效回执族（B4.8 新族 R11：防路发专属卡）════
	# （P2/P3 腿已顺路采得 v_style_at_hit，本族独立复查 style 路由+强度参；
	#  采集器 _landed 在 _flow_parry 头部已挂、尾部摘）
	await _clean(vendor, actor)
	vendor.attributes.reset()
	await _place(vendor, actor, Vector2(80, 30))
	_landed.clear()
	_set_guard(vendor, QuiverAttributes.BlockPhase.OUT, -1.0)
	var r20a := await _shot(vendor, actor)
	_check(r20a.v_style_at_hit == &"parry",
			"P20a 弹反支回执 style=parry（实得 %s）" % r20a.v_style_at_hit)
	_landed.clear()
	await _clean(vendor, actor)
	vendor.attributes.reset()
	await _place(vendor, actor, Vector2(80, 30))
	_set_guard(vendor, QuiverAttributes.BlockPhase.GUARD, -1.0)
	var r20b := await _shot(vendor, actor)
	_check(r20b.v_style_at_hit == &"block",
			"P20b 格挡支回执 style=block（实得 %s）" % r20b.v_style_at_hit)
	_landed.clear()
	await _clean(vendor, actor)
	vendor.attributes.reset()
	await _place(vendor, actor, Vector2(20, 30))
	_set_guard(vendor, QuiverAttributes.BlockPhase.OUT, 1.0)   # 西威胁×盾朝东=背面
	var r20c := await _shot(vendor, actor)
	_check(r20c.v_style_at_hit == &"default",
			"P20c 背面来袭回执 style=default（滑常规支证明，实得 %s）" % r20c.v_style_at_hit)
	_check(not _landed.is_empty() and float(_landed[_landed.size() - 1][2]) == 60.0,
			"P20d 常规支回执 strength=击打值 60（防路两支恒 0.0 的对读证人）")
	_landed.clear()
	await _clean(vendor, actor)

	# ── 收场（评审 I3）：拆除残场——后流绝不看见前流的幻影键盘/共享原体 ──
	Events.hit_landed.disconnect(_on_landed_capture)
	stage.queue_free()
	_finished_p = true


# ═══════════ Q 流：序列态自选进出 × 真键盘 K 链（B4.8 相位制改判） ═══════════
# A=格挡方（test_actor 玩家档：raw K 只进它自己的私有通道，串台免疫）；
# B=提线木偶攻击方（行为总开关关→K 不会劫持它的 Block；战斗盒阵营手术见下方
# 注释→能咬 A 且不咬自己）。本流**零写入** is_blocking/block_phase/block_facing
# ——三件套全由 QuiverActionBlock enter/信标推进/exit 落笔（单写者活体=OS 链×
# 缝整合命题）。test_actor 无 block_out/block 动画槽=兜底时钟 12/30 拍实况，
# P18/P21 族据此把"兜底时序"钉成回归锁（T1 真动画到货后本流仍应全绿：推进口
# 同一，仅时钟源换信标——若换源翻车本流必红，届时按红档再议域宽）。
# raw 键注入按 T2 判例：InputEventKey 逐字段显式构造（pressed 默认 false 陷阱），
# device=-1 对齐 block/jump 绑定文本，attack(J) device=16（J_DEV 常量，
# hit_feedback 探针判例），physical 键位走 Input.parse_input_event 全链路。

## raw 键注入（down/up 同构造，pressed 显式指定；keycode 与 physical 双填
## ——interact helper_e2e 实证形制；device 参数=J 键 16 判例预留）
func _press_key(p_key: int, p_pressed: bool, p_device: int = -1) -> void:
	var ev := InputEventKey.new()
	ev.device = p_device
	ev.keycode = p_key
	ev.physical_keycode = p_key
	ev.pressed = p_pressed
	Input.parse_input_event(ev)


## 等 state_name 含子串（P7e 跳跃腿：Air/Jump/*）
func _wait_state_contains(ch: QuiverCharacter, token: String, cap: int = 60) -> bool:
	for _i in cap:
		if str(ch.state_machine.state_name).contains(token):
			return true
		await get_tree().physics_frame
	return str(ch.state_machine.state_name).contains(token)


## 等相位到达（只读采样零写入；超时 false——判态走读，绝不代跑生产写方）
func _wait_phase(ch: QuiverCharacter, phase: QuiverAttributes.BlockPhase, cap: int = 90) -> bool:
	for _i in cap:
		if ch.attributes.block_phase == phase:
			return true
		await get_tree().physics_frame
	return ch.attributes.block_phase == phase


func _flow_stance() -> void:
	if not _guard_actor():
		return
	var stage := Node2D.new()
	add_child(stage)
	var a: QuiverCharacter = (load(ACTOR_SCENE) as PackedScene).instantiate()
	# 属性私有副本（红跑尸检定案）：同 .tres 被两实例按引用共享——不 duplicate
	# 则 A/B（及 P 流本体）的血/池/相位旗全是一个对象，A 挨一发拳 B 也会
	# 幻影入 Hurt。两处都要换：root.attributes（动作状态 _on_owner_ready 的
	# 缓存源）+ 皮肤.attributes（战斗盒 character_attributes 经 group 推送源）；
	# 入树前 root setter 够不到 @onready 的 _skin，故显式双写。B 保留共享原体：
	# 其断言全为相对读数，Q 流窗口内原体无人可咬。
	var dup: QuiverAttributes = a.attributes.duplicate(true)
	a.get_node(a._path_skin).attributes = dup
	a.attributes = dup
	var b: QuiverCharacter = (load(ACTOR_SCENE) as PackedScene).instantiate()
	stage.add_child(a)
	stage.add_child(b)
	# 出生位整体偏到 P 靶场（500,400）以西 ≥2000px——三具玩家档角色共用键盘
	# 广播但通道私有，身体层再互不沾边，Q 流几何零污染
	a.global_position = Vector2(-2100, 400)
	b.global_position = Vector2(-2400, 400)
	await _frames(18)
	var ok0: bool = await _wait_state(a, "Ground/Move/Idle", 120)
	_check(ok0 and str(b.state_machine.state_name) != "", "Q0 双替身入场就绪（test_actor 含 Block 节点）")
	# B 提线化：行为总开关=产品级原语（通道零写/零投递），K 按住也架不起 B 的盾
	(b.behavior as QuiverBehavior).active = false
	# B 战斗盒阵营手术=摘 player 换挂 q_puppet（红跑判例，task-5-report 在案）：
	# ① B 盒 {q_puppet} vs A 受击盒 {player} 无公共标签 ⇒ 免伤门放行；
	# ② B 盒 vs B 自己受击盒 {player,q_puppet} 公共 ⇒ 自伤豁免保住——裸剥成空
	# 会让冲刺步中攻击盒擦过自身受击盒自伤（击退位移再弹第二次入射=A 双咬 20）。
	# remove 经 Variant 动态调用触发脚本层 override 刷缓存（AGENTS 判例：typed
	# 直调绕过 override 缓存冻结）；add 一律走公开入口 add_faction_group。
	for node in b.find_children("*", "Area2D", true, false):
		var box = node
		if box is QuiverHitBox:
			box.remove_from_group(&"area2d:player")
			box.add_faction_group(&"area2d:q_puppet")
		elif box is QuiverHurtBox:
			box.add_faction_group(&"area2d:q_puppet")
	# 台架特权（申报见文件头）：手拨 A 面朝西——站桩位无输入永不改
	# facing_x，enter 快照取此值 → 盾朝西正对"东邻 B 从西侧咬来"的威胁
	a._skin.facing_x = -1.0
	await _frames(2)

	# ── P7a raw K-down → 序列起 + enter 同帧三件套（生产唯一写方首验）──
	_press_key(KEY_K, true)
	var ok7a: bool = await _wait_state(a, "Ground/Block", 60)
	_check(ok7a, "P7a K 按下 → state=Ground/Block（自选进入，60 帧内）")
	_check(a.attributes.is_blocking and a.attributes.block_phase == QuiverAttributes.BlockPhase.OUT,
			"P7a' is_blocking+phase=OUT 同帧起笔（enter 落笔，本流零内部写）")
	_check(absf(a.attributes.block_facing.x) == 1.0 and is_zero_approx(a.attributes.block_facing.y),
			"P7a'' block_facing=恒左右单位快照（R5，实得 %s）" % a.attributes.block_facing)

	# ── P21a 兜底 OUT 窗长≈12 拍（信标缺席自计数；杀"相位推进摘除"红档 b：
	#    那会永不到 GUARD）。自 OUT 观测点到 GUARD 出现 ∈[8,16]：enter→观测
	#    存在 ±3 拍漂移，宽域仍具判别力 ──
	var f_out0 := Engine.get_physics_frames()
	var okG := await _wait_phase(a, QuiverAttributes.BlockPhase.GUARD, 60)
	var out_span := Engine.get_physics_frames() - f_out0
	_check(okG and out_span >= 8 and out_span <= 16,
			"P21a 兜底 OUT 窗≈12 拍（自 OUT 观测至 GUARD 实测 %d 拍）" % out_span)

	# ── P7b GUARD 段挨拳=格挡待遇（OS 链×缝整合）+ R9 命中拍序列在场 ──
	# 出拳前松 K（长按连架命题隔离到 P18d/P21d，本腿求时序纯净）
	_press_key(KEY_K, false)
	await _drain_freeze()
	await _place(a, b, Vector2(80, 30))
	var rq := await _shot(a, b)
	_check(rq.v_hp_drop == 4.0,
			"P7b OS 链×缝整合：序列中 GUARD 段挨拳掉血恰 4=10×0.4（非 10，实际 %.1f）" % rq.v_hp_drop)
	_check(not rq.v_hurt and rq.v_pool_min >= POOL0,
			"P7b' 格挡支 A 不受击不扣池（池最低读 %.0f）" % rq.v_pool_min)
	_check(rq.v_state_at_hit == "Ground/Block"
			and int(rq.v_phase_at_hit) == QuiverAttributes.BlockPhase.GUARD,
			"P7b'' R9 命中拍序列在场：state=Block 且 phase=GUARD（实得 %s/%s）"
			% [rq.v_state_at_hit, rq.v_phase_at_hit])
	_check(rq.v_alive_after >= 7,
			"P7b''' R9 挡击后序列保持：命中后 8 拍 is_blocking 存活 %d/8" % rq.v_alive_after)
	_check(rq.a_hp_drop == 0.0 and rq.a_pool_min >= POOL0 and not rq.a_hurt,
			"P7b'''' 无反顶波及：B 血/池/Hurt 三不动（池最低 %.0f）" % rq.a_pool_min)

	# ── P7c 序列自动收口回 Idle（点按制 R1：收口与键态无关）+ 清三件套 ──
	var ok7c: bool = await _wait_state(a, "Ground/Move/Idle", 90)
	_check(ok7c, "P7c 序列自动收口 → Ground/Move/Idle（动画/兜底时钟毕=唯一出口）")
	_check(not a.attributes.is_blocking and a.attributes.block_phase == QuiverAttributes.BlockPhase.NONE
			and a.attributes.block_facing == Vector2.ZERO,
			"P7c' exit 保证式清三件套（is_blocking=false/phase=NONE/盾向零向量）")
	_check(str(a.state_machine.state_name) == "Ground/Move/Idle",
			"P21d 收口后 Idle 驻留（松键态 is_held=false 不回流）")

	# ── P18a 全程相位链采样（新点按）：NONE→OUT→GUARD→Idle 一链到底 ──
	_press_key(KEY_K, true)
	var chain_seen := ""       # 进展记录：O/G 首见序
	var saw_guard := false
	var ended_idle := false
	var f_enter := Engine.get_physics_frames()
	for _i in 90:
		await get_tree().physics_frame
		var p: int = a.attributes.block_phase
		if p == QuiverAttributes.BlockPhase.OUT and not chain_seen.contains("O"):
			chain_seen += "O"
		elif p == QuiverAttributes.BlockPhase.GUARD and not chain_seen.contains("G"):
			chain_seen += "G"
			saw_guard = true
		if saw_guard and str(a.state_machine.state_name) == "Ground/Move/Idle":
			ended_idle = true
			break
	_press_key(KEY_K, false)
	var total := Engine.get_physics_frames() - f_enter
	_check(chain_seen == "OG" and ended_idle,
			"P18a 点按全程链=OUT→GUARD→Idle（链=%s 收口=%s，%d 拍）"
			% [chain_seen, ended_idle, total])
	# P21c 全程=12+30 拍量级（真动画长改变时本腿按红档重议域宽——申报）
	_check(total >= 34 and total <= 52,
			"P21c 兜底全程 OUT+GUARD≈12+30 拍（实测 %d 拍∈[34,52]）" % total)

	# ── P18b R8 弹反成功后不跳相：命中拍后序列续播（防"弹成功反而裸奔"）──
	await _frames(4)
	await _place(a, b, Vector2(80, 30))
	await _wait_state(a, "Ground/Move/Idle", 120)
	_press_key(KEY_K, true)
	var ok18b0: bool = await _wait_state(a, "Ground/Block", 60)
	# OUT 窗内立刻挨拳（hit≈w_cal 拍 ≤12 拍窗域内）：弹反成立
	var rb := await _shot(a, b)
	_press_key(KEY_K, false)
	_check(ok18b0 and rb.v_hp_drop == 0.0 and rb.a_pool_min == POOL0 - 60.0,
			"P18b1 点按即挨拳=OUT 弹反成（A 免伤 B 池 540，实际掉 %.1f）" % rb.v_hp_drop)
	_check(int(rb.v_phase_at_hit) == QuiverAttributes.BlockPhase.OUT,
			"P18b2 命中拍相位=OUT（弹反窗=相位即窗口，实得 %s）" % rb.v_phase_at_hit)
	_check(rb.v_alive_after >= 7,
			"P18b3 R8 弹反后序列不中断：命中后 8 拍 is_blocking 存活 %d/8（不跳相续播）"
			% rb.v_alive_after)
	_check(not rb.v_hurt and rb.v_pool_min >= POOL0 and rb.v_scale_min >= 0.999,
			"P18b4 弹反拍 A 不入 Hurt 不扣池不罚站（免伤路守方活体面）")
	_check(await _wait_phase(a, QuiverAttributes.BlockPhase.GUARD, 60),
			"P18b5 R8 续播见证：弹反拍后 GUARD 相位照常到来")
	await _wait_state(a, "Ground/Move/Idle", 120)

	# ── P18d 序列中再按 K 不重入（Block 不在白名单的活体面）──
	await _frames(2)
	_press_key(KEY_K, true)
	await _wait_state(a, "Ground/Block", 60)
	await _wait_phase(a, QuiverAttributes.BlockPhase.GUARD, 60)
	_press_key(KEY_K, false)
	_press_key(KEY_K, true)   # GUARD 段再点一下：若重入则相位倒退 OUT
	var re_back := false
	for _i in 10:
		await get_tree().physics_frame
		if a.attributes.block_phase == QuiverAttributes.BlockPhase.OUT:
			re_back = true
	_press_key(KEY_K, false)
	_check(not re_back, "P18d 序列中再按 K 不重入（GUARD 恒不回退 OUT，Block 不在白名单）")
	await _wait_state(a, "Ground/Move/Idle", 120)

	# ── P18e 白名单外（Hurt 在途）按 K 不起架 ──
	await _frames(2)
	await _drain_freeze()
	await _place(a, b, Vector2(80, 30))
	# 无防挨一拳入 Hurt（test_actor hurt 占位动画 5fps 多帧 ≥20 物理拍在途）。
	# 判据=**Hurt 在途单拍持键不被劫持起架**：见 Hurt 当拍 press K，下一拍采样
	# ——该拍 Hurt 必然仍在途（动画节拍 ≪ 物理拍），若 state=Block 即白名单破口；
	# 随即松键封死"Hurt 收口后合法回流"混入判据（收口回流属设计语义，P16c 同注）
	_attack(b, Vector2.RIGHT)
	var hurt_seen := false
	var block_in_hurt := false
	for _i in 60:
		await get_tree().physics_frame
		if str(a.state_machine.state_name) == "Ground/Hurt":
			hurt_seen = true
			_press_key(KEY_K, true)
			break
	if hurt_seen:
		await get_tree().physics_frame
		block_in_hurt = str(a.state_machine.state_name) == "Ground/Block"
		_press_key(KEY_K, false)
	_check(hurt_seen and not block_in_hurt,
			"P18e Hurt 在途持 K 不起架（白名单外禁入活体面：hurt_seen=%s 违规直跳=%s）"
			% [hurt_seen, block_in_hurt])
	await _wait_state(a, "Ground/Move/Idle", 120)
	# 白名单源码锁（行为面短窗难稳采——源文本双保险）：地面三连段在场、
	# 空中跳攻节点名 "Attack" 绝不在列（R10 后摇架+spec §5 空中不可架）
	var blk_src := FileAccess.get_file_as_string(BLOCK_STATE_SRC)
	_check(blk_src.contains("&\"Combo1\", &\"Combo2\", &\"Combo3\"")
			and not blk_src.contains("&\"Run\", &\"Attack\""),
			"P18e2 白名单源码锁：地面三连段+空中 Attack 不在列")

	# ── P19 后摇架族（R10）：地面出招中按 K 取消进序列 ──
	await _drain_freeze()
	# B 挪远避咬（P19 只需要 A 的自产攻击态，不需要对手——阵营面零事故）
	await _place(a, b, Vector2(-600, 0))
	_press_key(KEY_J, true, J_DEV)
	var ok19a: bool = await _wait_state_contains(a, "Combo", 30)
	_check(ok19a, "P19a 前置：raw J 出招成功（state 含 Combo）")
	_press_key(KEY_J, false, J_DEV)
	_press_key(KEY_K, true)
	var ok19b: bool = await _wait_state(a, "Ground/Block", 30)
	_check(ok19b, "P19b R10 攻击中/后摇按 K → 取消进格挡序列（Combo 在白名单活体）")
	_press_key(KEY_K, false)
	_check(await _wait_state(a, "Ground/Move/Idle", 120), "P19c 序列自动收口回 Idle（后摇架全程）")

	# ── P21b 兜底 OUT 窗内挡击=弹反（≈10 拍量级：起势 3 拍出拳，hit≈3+w_cal）──
	await _drain_freeze()
	await _place(a, b, Vector2(80, 30))
	await _wait_state(a, "Ground/Move/Idle", 120)
	_press_key(KEY_K, true)
	var ok21p: bool = await _wait_state(a, "Ground/Block", 60)
	await _frames(3)
	var rb21 := await _shot(a, b)
	_press_key(KEY_K, false)
	_check(ok21p and rb21.v_hp_drop == 0.0 and rb21.a_pool_min == POOL0 - 60.0
			and int(rb21.v_phase_at_hit) == QuiverAttributes.BlockPhase.OUT,
			"P21b 兜底 OUT 窗内（≈10 拍）挡击=弹反成（相位=%s 掉血 %.1f）"
			% [rb21.v_phase_at_hit, rb21.v_hp_drop])
	await _wait_state(a, "Ground/Move/Idle", 120)

	# ── P7d 新序列中输入窗关闭期间注入 Space 不劫持 ──
	_press_key(KEY_K, true)
	var ok7d0: bool = await _wait_state(a, "Ground/Block", 60)
	_check(ok7d0, "P7d 再进入序列成功（re-entered stance）")
	_press_key(KEY_SPACE, true)
	await _frames(12)
	_check(str(a.state_machine.state_name) == "Ground/Block",
			"P7d' 序列中注入 Space → 状态仍 Block（输入窗关，无劫持）")
	_press_key(KEY_SPACE, false)
	await _frames(2)
	_press_key(KEY_K, false)
	var ok7d2: bool = await _wait_state(a, "Ground/Move/Idle", 120)
	_check(ok7d2, "P7d'' 释放路径清理：先松 Space 再松 K → 序列收口回 Idle")

	# ── P7e K 让位之后：Space 独跳链路仍可用（游戏侧实证 T2 让位判例）──
	_press_key(KEY_SPACE, true)
	var ok7e: bool = await _wait_state_contains(a, "Air", 60)
	_check(ok7e, "P7e 最终释放后 Space 按下 → 跳跃仍工作（state 含 Air）")
	_press_key(KEY_SPACE, false)
	_check(await _wait_state(a, "Ground/Move/Idle", 180), "P7f 跳后落回 Idle（M4 组前置）")

	# ── P15（原 P10 族平移编号）姿态整口吞发射器（spec §2.3"飞天变站桩"
	#    经真实姿态旗活体验收；GUARD 段=挡击域）──
	_press_key(KEY_K, true)
	var ok10s: bool = await _wait_state(a, "Ground/Block", 60)
	_check(ok10s, "P15a 起架（M4 组前置：姿态旗由生产写方点亮）")
	# 相位制：等 GUARD 出场取代旧"睡 12 帧超窗"构造（挡击域=GUARD）
	await _wait_phase(a, QuiverAttributes.BlockPhase.GUARD, 60)
	await _drain_freeze()
	for hb in b._skin.hitboxes:
		if str(hb.name) == "Attack1":
			var launcher := hb.attack_data.duplicate(true) as QuiverAttackData
			launcher.attack_damage = 30.0
			launcher.knock_strength = 1200.0
			hb.attack_data = launcher
			break
	await _place(a, b, Vector2(80, 30))
	var r10 := await _shot(a, b)
	_check(r10.v_hp_drop == 12.0,
			"P15b 格挡整口吞必飞天重击：掉血恰 12=30×0.4（实际 %.1f）" % r10.v_hp_drop)
	_check(not r10.v_hurt and r10.v_pool_min >= POOL0,
			"P15c 1200 击退值整颗作废：不扣池不受击（池最低 %.0f）" % r10.v_pool_min)
	_check(r10.v_state_at_hit == "Ground/Block" and r10.v_alive_after >= 7,
			"P15d 挨完必飞天一发命中拍站桩且序列续命（飞天变站桩，state=%s 存活 %d/8）"
			% [r10.v_state_at_hit, r10.v_alive_after])

	# ── P16（原 P11 族平移编号）打断注销三件套（Ground 挂线在序列下仍活着）──
	# 格挡支吞 K ⇒ 序列不可被"被挡下的发射器"打断（P15 已钉）；打断者必须来自
	# 不可挡源：走 CombatSystem.apply_knockback 公开入口直推防守方 K=1200
	#（本契约内部捷径族同款：只借生产信号链 knockout_requested→Ground 挂线→
	# transition，不绕任何生产判则）→ Block.exit 注销三件套+开窗；键仍按住时
	# 恢复链途中白名单必须拒回流。
	await _wait_state(a, "Ground/Block", 60)
	CombatSystem.apply_knockback(QuiverKnockbackData.new(
			1200.0, CombatSystem.HurtTypes.HIGH, Vector2.UP), a.attributes)
	var ok11a: bool = await _wait_state_contains(a, "Knockout", 60)
	_check(ok11a, "P16a 不可挡发射器打断序列：A 升空进 Air/Knockout/*")
	_check(not a.attributes.is_blocking and a.attributes.block_phase == QuiverAttributes.BlockPhase.NONE,
			"P16b Block 经父挂线被打断时 exit 照跑、三件套注销（单写者闭环）")
	# P16c（R13①强化判停逐字保）：击飞→恢复→Move 途中持键零 Block 回流。
	# 注：相位制下 K 按住收口回 Move 后回流起架=设计语义（长按=自动连架序列），
	# 本腿只盯"恢复链途中零 Block"，首 Move 帧即收闸松键。
	var f11_move := -1
	var block11_seen := false
	for _i in 180:
		await get_tree().physics_frame
		if str(a.state_machine.state_name).contains("Block"):
			block11_seen = true
			break
		if str(a.state_machine.state_name).contains("Move"):
			f11_move = Engine.get_physics_frames()
			break
	_check(f11_move >= 0 and not block11_seen,
			"P16c 全录像判停：击飞→恢复→Move 途中持键零 Block（恢复=%s 违规帧=%s）"
			% [f11_move >= 0, block11_seen])
	_press_key(KEY_K, false)

	# ── 收场（评审 I3）：拆除残场，键位已净 ──
	stage.queue_free()
	_finished_q = true
