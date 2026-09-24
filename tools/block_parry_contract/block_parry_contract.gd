extends Node

## S2-B3 盾反批契约：M 流=修饰核心 B′ 手术（重算回写）的回归流——
## base 捕获、加乘复合按序重算、乱序摘除、同 id 替换、非法型零副作用、
## reset 清账。
## P 流=判定缝三分支（Task4 批入）：靶场仿 attack_lane_contract——test_actor(A)
## 出拳 × street_vendor(V) 受击，场景 helper 逐字移植自 lane（99-107 家族）。
## Q 流=T5 姿态状态自选进出 × 真键盘 K 链（P7 腿）：raw 注入 K → Block 态、
## 姿态中挨拳走格挡支（OS 链×缝整合）、松键回 Idle、窗口关不劫持、K 让位后
## 跳跃仍可用。旗标成对写入零内部捷径——生产写方只有 QuiverActionBlock。
## T6 补腿（评审点名，R9④⑤/M4）：P8=弹体弹反（窗内格挡弹道 → 反顶施法者
## 池 540 + 弹体消亡，spell_base 绑施法者属性的悬案钉死）；P9=反顶升格
## （攻击方池预削 50，K60≥R → 统一模型 knockout，Air/Knockout/Launch）；
## P10/P11=M4 姿态×发射器双向——P10 格挡支整颗吞 1200 重击（spec §2.3
## "飞天变站桩"经真实姿态旗活体钉死），P11 经 CombatSystem 公开入口直推
## knockout_requested → Block 经 Ground 挂线被打断退场、exit 注销旗标
## （键仍按住也不复活，白名单不回流非 locomotion）。两流收尾 queue_free
## 残场（评审 I3：后流绝不看见前流的幻影键盘/共享原体）。
## 本套自 T6 起入 run_matrix 名册，身份见证=ACTOR-GATE（守卫通过行）。
##
## T7 强化（R13，测试强度批）：P11c 由"起飞后定点 30 帧非 Block"（击飞在途
## ⇒ 恒真窗盲）改为"打断→Move 途中逐帧零 Block + Move 必达"全录像判停（首
## Move 帧即收闸——此后回流起架是白名单设计语义，P7a 同路）；P6c/P8e 加
## "命中帧起 ≤15 帧离场"护栏（max_lifetime=300f 与本采样窗同长，只判最终
## 离场则穿体飞到超时仍绿=窗缘假绿边角；缝栈内回执与结算同帧，正常帧距 0）。
##
## T8 白闪可见性腿（2026-09-24 用户 F5 定罪缺陷的回归锁）：LDR-2D 下
## modulate>1 被钳制闪不出白（旧 helper 空转），修复=运行时混白 shader 换挂
## 皮肤精灵 material（本构建无 material_overlay，探针实锤）。新 5 腿 P2g/P2h
## （格挡弱闪挂/摘）+ P3j/P3k/P3l（弹反双闪挂/挂/摘），逐物理帧采样
## sprite.material 非空首末帧，对旧 modulate 形制恒红（red_run2 档：五腿
## 首见=-1），断言总数 79→84。
##
## Step0 探针实锤（2026-09-23，tools/tmp_b3probe 一次性台已毁尸，逐字记录见
## task-4-report）：定格期间 physics_frame 信号照响、Engine.get_physics_frames()
## 照走（定格 12 帧 → 帧号 +12），但 Area 回调被暂停门扣到恢复帧才发；
## 无暂停期"观察循环见旗帧 == 回调帧"（j=0）、碰撞窗使能后恰好 +1 帧送达。
## ⇒ 本流时间约定：①每条时序腿起手先 _drain_freeze()（"定格前起跳"）；
## ②校准帧距 w_cal = P1 实测（出手调用帧→命中观察帧），预置
##   block_started_frame = 出手帧 + w_cal − 目标delta 使判定缝读到的 delta 精确
##   等于目标值；③hold 模式逐帧重写 started=当前帧，由 j=0 保证缝读到 delta≡1。
## 运行：godot --headless --path . res://tools/block_parry_contract/block_parry_contract.tscn

const A_AT := "res://addons/quiver.beat_em_up/characters/quiver_attributes.gd"
const M_BASE_MOVE := 600.0

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


func _ready() -> void:
	await _flow_modifiers()
	# 判例（AGENTS）：子协程运行时炸掉后主协程照常续跑——每流自带完成旗单独锁
	_check(_finished_m, "M 流全序列执行完成（协程静默中断防线）")
	await _flow_parry()
	_check(_finished_p, "P 流全序列执行完成（协程静默中断防线）")
	await _flow_stance()
	_check(_finished_q, "Q 流全序列执行完成（协程静默中断防线）")
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
	_finished_m = true

# ═══════════════════════════ P 流：判定缝三分支 ══════════════════════════════
# 场景 helper 逐字移植自 attack_lane_contract（主权法：只读消费 test_actor，
# 判态走 peek()，绝不代 runner 创建）。

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


func _reset_target(vendor: QuiverCharacter) -> void:
	vendor.attributes.reset()
	await _wait_state(vendor, "Ground/Move/Idle", 600)


## 排空在途命中定格（探针 B1：定格期帧号照走 ⇒ delta 会被蚕食）——
## spec"定格前起跳"的落地：每条时序腿的 started 预置与出手必须在无暂停窗口内。
func _drain_freeze() -> void:
	for _i in 60:
		if not get_tree().paused:
			break
		await get_tree().physics_frame
	await _frames(2)


## 皮肤精灵解析（白闪可见性腿的前置快照，R15 判例：先取引用再进采样环，
## 途中失效率低且红据可诊断）——与 _flash 同款形制：角色子树第一个
## AnimatedSprite2D（chen 系皮肤 = Skin/AnimatedSprite2D，find_children 抗路径改动）。
## 注意（2026-09-24 判例）：本构建 CanvasItem 无 material_overlay 属性（探针实锤），
## 闪白合成通道 = sprite.material 换挂，本流探测物随之为 material。
func _skin_sprite(ch: QuiverCharacter) -> CanvasItem:
	var sprites := ch.find_children("*", "AnimatedSprite2D", true, false)
	return sprites[0] if not sprites.is_empty() else null


## 通用一发：同帧记录出手帧→开火→逐帧采样双方血量/池轨迹、Hurt 落态、暂停可见。
## hold=true：每帧重写 V.block_started_frame=当前帧，模拟"被打前一瞬按下 K"
##   （探针 j=0 实锤 ⇒ 缝读到 delta≡1，与动画前摇长度无关——免歧义构造）。
## target_delta≥0：预置 started=出手帧+w_cal−target_delta ⇒ 缝读到 delta≡目标值
##   （w_cal 来自 P1 同几何实测出手→命中帧距，同场景确定性）。
## 池轨迹用 min 捕获：受击回 Idle 后 refill 会把余量抬回，事后采样会漏判。
func _shot(vendor: QuiverCharacter, actor: QuiverCharacter, hold := false,
		target_delta := -1, w_cal := 0,
		v_ov: CanvasItem = null, a_ov: CanvasItem = null) -> Dictionary:
	var r := {
		"f_call": 0, "f_hit": -1,
		"v_hp0": 0.0, "v_hp_drop": 0.0, "v_pool_min": POOL0, "v_hurt": false,
		"a_hp0": 0.0, "a_hp_drop": 0.0, "a_pool_min": POOL0, "a_hurt": false,
		"a_knockout": false, "paused_seen": false,
		# 白闪可见性腿（LDR 判例 2026-09-24）：overlay 挂/摘首末帧 + 弹反缝帧
		# （攻击方池首降帧——免伤路 V 血不降，f_hit 恒 -1，须另立 seam）
		"v_ov_first": -1, "v_ov_last": -1,
		"a_ov_first": -1, "a_ov_last": -1, "a_pool_seam": -1,
	}
	r.v_hp0 = vendor.attributes.health_current
	r.a_hp0 = actor.attributes.health_current
	if hold:
		vendor.attributes.block_started_frame = Engine.get_physics_frames()
	_attack(actor, Vector2.RIGHT)
	r.f_call = Engine.get_physics_frames()
	if target_delta >= 0:
		vendor.attributes.block_started_frame = r.f_call + w_cal - target_delta
	for _i in 240:
		await get_tree().physics_frame
		if hold:
			vendor.attributes.block_started_frame = Engine.get_physics_frames()
		if get_tree().paused:
			r.paused_seen = true
		# 首血降即锁缝帧并停止累加：万一攻击动画存在二次 entered（多段盒窗），
		# 差值只忠实于第一缝——单发单结算才是本契约的命题
		if r.f_hit < 0 and vendor.attributes.health_current < r.v_hp0:
			r.v_hp_drop = r.v_hp0 - vendor.attributes.health_current
			r.f_hit = Engine.get_physics_frames()
		if actor.attributes.health_current < r.a_hp0:
			r.a_hp_drop = r.a_hp0 - actor.attributes.health_current
		r.v_pool_min = minf(r.v_pool_min, vendor.attributes.resistance_current)
		r.a_pool_min = minf(r.a_pool_min, actor.attributes.resistance_current)
		if r.a_pool_seam < 0 and actor.attributes.resistance_current < POOL0:
			r.a_pool_seam = Engine.get_physics_frames()
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
		# 反顶升格观察窗（P9）：攻击者被自己的弹反顶进 Air/Knockout/*
		if str(actor.state_machine.state_name).contains("Knockout"):
			r.a_knockout = true
	return r


## 腿间卫生：双方回池回待机、姿态旗清零、排空定格、复位几何（池显式 refill——
## 受击归 Idle 的自动回气时机不属本契约命题，不押注；血量差值走相对读数不依赖
## 满血，唯 is_blocking 必须显式归零，防上一腿的"真"漏进下一腿的"未防"）。
func _clean(vendor: QuiverCharacter, actor: QuiverCharacter) -> void:
	vendor.attributes.is_blocking = false
	await _drain_freeze()
	await _wait_state(actor, "Ground/Move/Idle", 600)
	await _wait_state(vendor, "Ground/Move/Idle", 600)
	vendor.attributes.refill_resistance()
	actor.attributes.refill_resistance()
	await _place(vendor, actor, Vector2(80, 30))


func _flow_parry() -> void:
	if not _guard_actor():
		return
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
	var w_cal: int = r1.f_hit - r1.f_call  # 同几何出手→缝帧距（后续边界腿校准基）
	_check(r1.v_hp_drop == 10.0, "P1a 未格挡掉血恰 10（out_mult=1.0 哨兵，实际 %.1f）" % r1.v_hp_drop)
	_check(r1.v_hurt, "P1b 未格挡 V 入 Ground/Hurt（受击链原样）")
	_check(r1.v_pool_min == POOL0 - 60.0, "P1c 未格挡 V 池 600→540（击退派发逐字如旧）")
	_check(r1.a_hp_drop == 0.0 and r1.a_pool_min >= POOL0 and not r1.a_hurt,
			"P1d 攻击方全程无损（血/池/Hurt 三不动）")
	_check(w_cal >= 1 and w_cal <= 120, "P1e 出手→命中帧距校准 w_cal=%d 在有效域" % w_cal)
	print("[b3-p] w_cal=%d（探针 j=0：f_hit==缝帧）" % w_cal)
	await _clean(vendor, actor)

	# ── P2 格挡超窗：伤害×ratio、击退值整颗作废 ──
	# 判定缝测试内部捷径：直写 is_blocking/block_started_frame（超窗 started=now−99）。
	# OS 链（K 按住→Block 态 enter 写旗）归 T5 P7，本流只钉缝的读值语义。
	# 白闪腿前置：皮肤精灵引用在采样环前快照（R15 判例），P2/P3 共用。
	var ov_v := _skin_sprite(vendor)
	var ov_a := _skin_sprite(actor)
	print("[b3-flash] 皮肤精灵 v=%s a=%s" % [ov_v, ov_a])
	vendor.attributes.is_blocking = true
	vendor.attributes.block_started_frame = Engine.get_physics_frames() - 99
	var r2 := await _shot(vendor, actor, false, -1, 0, ov_v, ov_a)
	_check(r2.v_hp_drop == 4.0, "P2a 格挡掉血恰 4=10×0.4（超窗，实际 %.1f）" % r2.v_hp_drop)
	_check(not r2.v_hurt, "P2b 格挡 V 不入 Hurt（击退派发整颗吞掉）")
	_check(r2.v_pool_min >= POOL0, "P2c 格挡 V 池一分不扣（%.0f）" % r2.v_pool_min)
	_check(r2.a_hp_drop == 0.0 and r2.a_pool_min >= POOL0, "P2d 格挡下攻击方无波及")
	# 白闪可见性（LDR 判例 2026-09-24：modulate>1 被钳制闪不出白⇒用户 F5 定罪
	# 不可见；修复=运行时混白着色器换挂 sprite.material。本组腿对旧 modulate
	# 形制恒红，即该缺陷的机器回声——闪白 material 从未被挂上）：
	_check(r2.f_hit >= 0 and r2.v_ov_first >= 0 and r2.v_ov_first - r2.f_hit <= 2,
			"P2g 格挡命中后 ≤2 物理帧防守方皮肤闪白 material 挂上（缝帧=%s 首见=%s）"
			% [r2.f_hit, r2.v_ov_first])
	_check(r2.f_hit >= 0 and r2.v_ov_last >= 0 and r2.v_ov_last - r2.f_hit <= 30,
			"P2h 格挡弱闪 ≤30 帧后已摘净（末见=%s；240 帧全采样无残留=自动含'回原底材'）"
			% r2.v_ov_last)
	await _clean(vendor, actor)

	# ── P3 弹反（hold 构造：缝读 delta≡1 < 6）──
	vendor.attributes.is_blocking = true
	var r3 := await _shot(vendor, actor, true, -1, 0, ov_v, ov_a)
	_check(r3.v_hp_drop == 0.0, "P3a 弹反 V 免伤（实际 %.1f）" % r3.v_hp_drop)
	_check(r3.v_pool_min >= POOL0, "P3b 弹反 V 池一分不扣（%.0f）" % r3.v_pool_min)
	_check(r3.a_pool_min == POOL0 - 60.0, "P3c 弹反反顶：A 池 600→540（实际 %.0f）" % r3.a_pool_min)
	_check(r3.a_hurt, "P3d 弹反反顶：A 被拽进自己的 Ground/Hurt（顶回去=播自己的挨打姿势）")
	_check(r3.paused_seen, "P3e 弹反支自发加强定格可观测（免伤路不经 apply_damage 的自发拍，探针 B1 佐证）")
	# 弹反三件套之视觉两件（spec §2.4 修订形制：闪白 material 挂/摘）；缝帧=攻击方池
	# 首降帧（免伤路 V 血不降，f_hit 恒 -1）。双方同拍挂 ⇒ 共用 seam。
	_check(r3.a_pool_seam >= 0 and r3.v_ov_first >= 0 and r3.v_ov_first - r3.a_pool_seam <= 2,
			"P3j 弹反：防守方强白闪 ≤2 帧内挂上（seam=%s 首见=%s）"
			% [r3.a_pool_seam, r3.v_ov_first])
	_check(r3.a_pool_seam >= 0 and r3.a_ov_first >= 0 and r3.a_ov_first - r3.a_pool_seam <= 2,
			"P3k 弹反：攻击方同拍弱白闪 ≤2 帧内挂上（首见=%s）" % r3.a_ov_first)
	_check(r3.a_pool_seam >= 0 and r3.v_ov_last >= 0 and r3.a_ov_last >= 0
			and maxf(float(r3.v_ov_last), float(r3.a_ov_last)) - r3.a_pool_seam <= 30,
			"P3l 弹反双方白闪 ≤30 帧内全摘净（防守末见=%s / 攻击末见=%s）"
			% [r3.v_ov_last, r3.a_ov_last])
	# P3 第二发：delta==窗 精确预置 → 严格 `<` 归格挡
	await _clean(vendor, actor)
	vendor.attributes.reset()
	vendor.attributes.is_blocking = true
	var r3b := await _shot(vendor, actor, false, 6, w_cal)
	_check(r3b.v_hp_drop == 4.0, "P3f delta==窗(6) 归格挡掉 4（严格< 语义面一，实际 %.1f）" % r3b.v_hp_drop)
	_check(not r3b.v_hurt and r3b.a_pool_min >= POOL0, "P3g delta==窗 无受击无反顶")
	# P3 第三发：窗修饰压到 1 + hold（delta≡1）→ `<` 判格挡、`<=` 判弹反——
	# 无条件严格小于哨兵（不吃任何校准漂移）
	await _clean(vendor, actor)
	vendor.attributes.add_modifier(&"t_p3s", &"parry_window_frames", "add", -5.0)
	_check(vendor.attributes.parry_window_frames == 1, "P3h 窗修饰生效 6→1")
	vendor.attributes.is_blocking = true
	var r3c := await _shot(vendor, actor, true)
	_check(r3c.v_hp_drop == 4.0, "P3i delta1/窗1 走格挡（严格< 哨兵；<= 世界会弹反掉 0，实际 %.1f）" % r3c.v_hp_drop)
	vendor.attributes.remove_modifier(&"t_p3s")
	await _clean(vendor, actor)

	# ── P4 每角色窗配置（受管字段走修饰路，禁裸写）──
	vendor.attributes.add_modifier(&"t_p4", &"parry_window_frames", "add", -4.0)
	_check(vendor.attributes.parry_window_frames == 2 and
			typeof(vendor.attributes.parry_window_frames) == TYPE_INT,
			"P4a 窗 6→2 且 int 类型锁（B′ 回写 roundi，typeof=%d）"
			% typeof(vendor.attributes.parry_window_frames))
	vendor.attributes.is_blocking = true
	var r4 := await _shot(vendor, actor, false, 3, w_cal)
	# 旧常量世界 delta3<6 会弹反掉 0——本条即"读字段非读常量"的前接线红据
	_check(r4.v_hp_drop == 4.0, "P4b 窗=2 时 delta3 走格挡掉 4（旧常量世界=弹反 0，实际 %.1f）" % r4.v_hp_drop)
	vendor.attributes.remove_modifier(&"t_p4")
	_check(vendor.attributes.parry_window_frames == 6 and
			typeof(vendor.attributes.parry_window_frames) == TYPE_INT,
			"P4c 摘修饰窗回 6 + int 锁")
	vendor.attributes.is_blocking = true
	var r4b := await _shot(vendor, actor, true)
	_check(r4b.v_hp_drop == 0.0 and r4b.a_pool_min == POOL0 - 60.0,
			"P4d 复测 delta≡1 弹反成立（V 免伤 + A 池 540，实际掉 %.1f）" % r4b.v_hp_drop)
	await _clean(vendor, actor)

	# ── P5 护人换挡模拟（两条修饰挂/撤，机制全程只读数字；本批随判定缝落地）──
	vendor.attributes.add_modifier(&"escort_window", &"parry_window_frames", "multiply", 2.0, self)
	actor.attributes.add_modifier(&"escort_power", &"attack_output", "multiply", 0.3, self)
	_check(vendor.attributes.parry_window_frames == 12, "P5a 窗×2 生效 6→12")
	_check(actor.attributes.attack_output == 0.3, "P5b 输出×0.3 生效")
	var r5a := await _shot(vendor, actor)
	_check(r5a.v_hp_drop == 3.0, "P5c 护人拳未防掉 3=10×0.3（输出乘数进常规支，实际 %.1f）" % r5a.v_hp_drop)
	# leg2：还原干净前的窗×2 判别位——delta=8：窗12 弹反 / 未加倍(=6) 格挡。
	# escort_window 仍在本账（_clean 不 reset 不清修饰），此处只补血复位姿态旗
	await _clean(vendor, actor)
	vendor.attributes.health_current = vendor.attributes.health_max
	vendor.attributes.is_blocking = true
	var r5b := await _shot(vendor, actor, false, 8, w_cal)
	_check(r5b.v_hp_drop == 0.0 and r5b.a_pool_min == POOL0 - 60.0,
			"P5d 窗12 下 delta8 弹反（未加倍世界=格挡掉 %.1f 且无反顶）" % r5b.v_hp_drop)
	# 撤净复测：输出回 1.0 → 未防 10；窗回 6 → delta8 归格挡 4
	vendor.attributes.remove_modifiers_from_source(self)
	actor.attributes.remove_modifiers_from_source(self)
	_check(vendor.attributes.parry_window_frames == 6 and actor.attributes.attack_output == 1.0,
			"P5e 撤修饰双双还原")
	await _clean(vendor, actor)
	var r5c := await _shot(vendor, actor)
	_check(r5c.v_hp_drop == 10.0, "P5f 撤除后未防回 10（实际 %.1f）" % r5c.v_hp_drop)
	await _clean(vendor, actor)
	vendor.attributes.is_blocking = true
	var r5d := await _shot(vendor, actor, false, 8, w_cal)
	_check(r5d.v_hp_drop == 4.0, "P5g 撤除后 delta8 改判格挡 4（仍弹反=窗未还原，实际 %.1f）" % r5d.v_hp_drop)
	await _clean(vendor, actor)

	# ── P6 弹体被挡（法术管线共缝：弹体 attack_box 的 character_attributes
	#    实测=施法者属性（spell_base.gd:74 非 null）⇒ attack_output 走施法者侧读取）──
	vendor.attributes.is_blocking = true
	vendor.attributes.block_started_frame = Engine.get_physics_frames() - 99
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
	# R13②帧距护栏：max_lifetime=5s=300 物理 tick 与本采样窗同长——只判
	# "最终离场"则穿体飞到超时仍绿（窗缘假绿边角）。改判"命中帧起 ≤15 帧内
	# 离场"：缝内 on_target_hit 与伤害同栈同步（hurt_box:250），正常帧距 0。
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

	# ── P8 弹体弹反（R9④）：hold 构造 delta≡1 ⇒ 缝对弹道走弹反支；反顶继承
	#    spell_base 绑定的施法者属性 ⇒ A 池 600→540，弹体经 on_target_hit 回执离场。
	#    （M1 悬案苗子钉死：弹体弹反不是"打到空气"，公共义务双向都算账）──
	await _clean(vendor, actor)
	vendor.attributes.reset()
	vendor.attributes.is_blocking = true
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
	# R13②帧距护栏（P6c 同款）：命中帧观测位=反顶削池首帧（apply_knockback 与
	# on_target_hit 同在判定缝栈内，正常帧距 0）；穿体飞到超时≈300f 炸护栏。
	var f_hit8 := -1
	var f_spent8 := -1
	for _i in 300:
		await get_tree().physics_frame
		# hold 重写（与 _shot 同款 j=0 约定）：命中落在哪帧都 delta≡1 在窗内
		vendor.attributes.block_started_frame = Engine.get_physics_frames()
		if f_hit8 < 0 and actor.attributes.resistance_current < POOL0:
			f_hit8 = Engine.get_physics_frames()
		if str(vendor.state_machine.state_name) == "Ground/Hurt":
			v_hurt8 = true
		v_pool8_min = minf(v_pool8_min, vendor.attributes.resistance_current)
		a_pool8_min = minf(a_pool8_min, actor.attributes.resistance_current)
		if str(actor.state_machine.state_name) == "Ground/Hurt":
			a_hurt8 = true
		if ball8_spent:
			# 弹体离场后再采样：反顶的 Hurt 落态是 call_deferred，+帧才可见
			grace8 += 1
			if grace8 >= 30:
				break
		if not is_instance_valid(ball2) or ball2.state != SpellBase.SpellState.ACTIVE:
			if not ball8_spent:
				f_spent8 = Engine.get_physics_frames()
			ball8_spent = true
	_check(hp8 - vendor.attributes.health_current == 0.0,
			"P8a 弹体弹反 V 免伤（实际掉 %.1f）" % (hp8 - vendor.attributes.health_current))
	_check(v_pool8_min >= POOL0 and not v_hurt8,
			"P8b 弹反不磨 V 池不入受击态（池最低 %.0f）" % v_pool8_min)
	_check(a_pool8_min == POOL0 - 60.0,
			"P8c 弹体反顶回施法者头上来：A 池 600→540（实际最低 %.0f）" % a_pool8_min)
	_check(a_hurt8 and actor.attributes.health_current == a_hp8_0,
			"P8d 施法者被反顶进 Hurt 但零伤害（弹反支无反顶伤害要素）")
	_check(ball8_spent and f_hit8 >= 0 and f_spent8 >= f_hit8
			and f_spent8 - f_hit8 <= 15,
			"P8e 弹反支公共义务：on_target_hit 回执在命中帧后 ≤15 帧内送达离场"
			+ "（命中帧=%d 离场帧=%d；穿体飞到超时≈300f 必炸本护栏）"
			% [f_hit8, f_spent8])

	# ── P9 反顶升格（R9⑤）：攻击方余池 50 吃弹反 K=60 ⇒ 统一模型破池自动
	#    升格 knockout（apply_knock 唯一判定点不偏袒攻守哪一侧）──
	await _clean(vendor, actor)
	vendor.attributes.reset()
	vendor.attributes.is_blocking = true
	actor.attributes.resistance_current = 50.0
	var r9 := await _shot(vendor, actor, true)
	_check(r9.v_hp_drop == 0.0 and r9.v_pool_min >= POOL0,
			"P9a 格挡方 V 全程无伤（实际掉 %.1f）" % r9.v_hp_drop)
	_check(r9.a_knockout and not r9.a_hurt,
			"P9b K60≥R50 ⇒ 施法者被顶进 Air/Knockout/*（升格，非 Hurt）")
	_check(r9.a_pool_min == 0.0,
			"P9c 升格清空池（apply_knock launched 支 =0 定档，实际最低 %.0f）" % r9.a_pool_min)
	_check(r9.a_hp_drop == 0.0,
			"P9d 升格轰飞不掉施法者血（反顶只位移硬直不带伤害）" )

	# ── 收场（评审 I3）：拆除残场——后流绝不看见前流的幻影键盘/共享原体 ──
	stage.queue_free()
	_finished_p = true


# ═══════════════ Q 流：姿态状态自选进出 × 真键盘 K 链（T5 · P7 腿） ═══════════════
# A=格挡方（test_actor 玩家档：raw K 只进它自己的私有通道，串台免疫）；
# B=提线木偶攻击方（行为总开关关→K 不会劫持它的 Block；战斗盒阵营手术见下方
# 注释→能咬 A 且不咬自己）。本流**零写入** is_blocking/block_started_frame——
# 旗标全由 QuiverActionBlock enter/exit 落笔（单写者活体=OS 链×缝整合命题）。
# raw 键注入按 T2 判例：InputEventKey 逐字段显式构造（pressed 默认 false 陷阱），
# device=-1 对齐绑定文本，physical 键位走 Input.parse_input_event 全链路。

## raw 键注入（down/up 同构造，pressed 显式指定；keycode 与 physical 双填
## ——interact helper_e2e 实证形制）
func _press_key(p_key: int, p_pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.device = -1
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


func _flow_stance() -> void:
	if not _guard_actor():
		return
	var stage := Node2D.new()
	add_child(stage)
	var a: QuiverCharacter = (load(ACTOR_SCENE) as PackedScene).instantiate()
	# 属性私有副本（红跑尸检定案）：同 .tres 被两实例按引用共享——不 duplicate
	# 则 A/B（及 P 流本体）的血/池/姿态旗全是一个对象，A 挨一发拳 B 也会
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
	await _frames(2)

	# ── P7a raw K-down → Block 姿态 + enter 同帧成对旗标（生产唯一写方首验）──
	_press_key(KEY_K, true)
	var ok7a: bool = await _wait_state(a, "Ground/Block", 60)
	var f_now: int = Engine.get_physics_frames()
	_check(ok7a, "P7a K 按住 → state=Ground/Block（自选进入，60 帧内）")
	_check(a.attributes.is_blocking, "P7a' is_blocking=true（enter 落笔，本流零内部写）")
	_check(absi(f_now - a.attributes.block_started_frame) <= 2,
			"P7a'' block_started_frame 同帧成对（R4 宪章，实际帧差 %d）"
			% (f_now - a.attributes.block_started_frame))

	# ── P7b 姿态存续中 B 出一拳（内部捷径）→ A 被格挡：掉血恰 4 ──
	# 先睡 12 帧再出手：命中帧 delta ≥ 12+w_cal > 6 ⇒ 落格挡支而非弹反支；
	# 成对旗标沿用 P7a enter 的写入（本腿 _shot 只读不写）
	await _frames(12)
	await _drain_freeze()
	await _place(a, b, Vector2(80, 30))
	var rq := await _shot(a, b)
	_check(rq.v_hp_drop == 4.0,
			"P7b OS 链×缝整合：K 按住的 A 挨拳掉血恰 4=10×0.4（非 10，实际 %.1f）" % rq.v_hp_drop)
	_check(not rq.v_hurt and rq.v_pool_min >= POOL0,
			"P7b' 格挡支 A 不受击不扣池（池最低读 %.0f）" % rq.v_pool_min)
	_check(str(a.state_machine.state_name) == "Ground/Block",
			"P7b'' 挨拳后姿态存续（格挡支零击退派发，Ground 挂线无事可做）")
	_check(rq.a_hp_drop == 0.0, "P7b''' 超窗无反顶：B 掉血 0（实际 %.1f）" % rq.a_hp_drop)
	_check(rq.a_pool_min >= POOL0, "P7b'''' B 池不动（最低 %.0f）" % rq.a_pool_min)
	_check(not rq.a_hurt, "P7b''''' B 不入 Hurt（hurt=%s）" % str(rq.a_hurt))

	# ── P7c K-up → exit 自选回 Idle，旗标注销 ──
	await _drain_freeze()
	_press_key(KEY_K, false)
	var ok7c: bool = await _wait_state(a, "Ground/Move/Idle", 60)
	_check(ok7c, "P7c K 松开 → 回 Ground/Move/Idle（引擎虚函数自选退出）")
	_check(not a.attributes.is_blocking, "P7c' exit 注销旗标 is_blocking=false")

	# ── P7d 二次姿态（re-entered stance）：输入窗关闭期间注入 Space 不劫持 ──
	_press_key(KEY_K, true)
	var ok7d0: bool = await _wait_state(a, "Ground/Block", 60)
	_check(ok7d0, "P7d 再进入姿态成功（re-entered stance）")
	_press_key(KEY_SPACE, true)
	await _frames(12)
	_check(str(a.state_machine.state_name) == "Ground/Block",
			"P7d' 姿态中注入 Space → 状态仍 Block（输入窗关，无劫持）")
	_press_key(KEY_SPACE, false)
	await _frames(2)
	_press_key(KEY_K, false)
	var ok7d2: bool = await _wait_state(a, "Ground/Move/Idle", 60)
	_check(ok7d2, "P7d'' 释放路径清理：先松 Space 再松 K → 回 Idle")

	# ── P7e K 让位之后：Space 独跳链路仍可用（游戏侧实证 T2 让位判例）──
	_press_key(KEY_SPACE, true)
	var ok7e: bool = await _wait_state_contains(a, "Air", 60)
	_check(ok7e, "P7e 最终释放后 Space 按下 → 跳跃仍工作（state 含 Air）")
	_press_key(KEY_SPACE, false)
	_check(await _wait_state(a, "Ground/Move/Idle", 180), "P7f 跳后落回 Idle（M4 组前置）")

	# ── P10 M4a 姿态整口吞发射器（spec §2.3"飞天变站桩"经真实姿态旗活体验收）──
	# B 的 Attack1 盒换挂私制重拳（attack_data 是共享导出资源严禁原地 mutate，
	# duplicate→改→回挂盒=实例级，随场死）：damage 30 / K=1200 是"池破必飞天"
	# 规格（同 chen 拳3 数值域）。防守方=真姿态（K 按住、超窗），缝读 enter
	# 落笔的旗 ⇒ 格挡支：-12 血、站桩、池一分不扣、派发零产生。
	_press_key(KEY_K, true)
	var ok10s: bool = await _wait_state(a, "Ground/Block", 60)
	_check(ok10s, "P10a 第三次起架（M4 组前置：姿态旗由生产写方点亮）")
	await _frames(12)  # 超窗纪律（同 P7b）：命中帧 delta≈20+ > 6 ⇒ 落格挡支
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
			"P10b 格挡整口吞必飞天重击：掉血恰 12=30×0.4（实际 %.1f）" % r10.v_hp_drop)
	_check(not r10.v_hurt and r10.v_pool_min >= POOL0,
			"P10c 1200 击退值整颗作废：不扣池不受击（池最低 %.0f）" % r10.v_pool_min)
	_check(str(a.state_machine.state_name) == "Ground/Block",
			"P10d 挨完必飞天一发姿态纹丝不动（飞天变站桩，无升格无派发）")
	_check(a.attributes.is_blocking, "P10e 键按住期间旗标存活（单写者无人抢笔）")

	# ── P11 M4b 打断注销旗标（Ground 挂线在姿态下仍活着，exit 闭环）──
	# 格挡支吞 K ⇒ 姿态不可被"被挡下的发射器"打断（P10 已钉）；打断者必须来自
	# 不可挡源：走 CombatSystem.apply_knockback 公开入口直推防守方 K=1200
	#（本契约内部捷径族同款：只借生产信号链 knockout_requested→Ground 挂线→
	# transition，不绕任何生产判则）→ Block.exit 注销旗标+开窗；键仍按住时
	# 白名单必须拒回流态姿态复活。
	CombatSystem.apply_knockback(QuiverKnockbackData.new(
			1200.0, CombatSystem.HurtTypes.HIGH, Vector2.UP), a.attributes)
	var ok11a: bool = await _wait_state_contains(a, "Knockout", 60)
	_check(ok11a, "P11a 不可挡发射器打断姿态：A 升空进 Air/Knockout/*")
	_check(not a.attributes.is_blocking,
			"P11b Block 经父挂线被打断时 exit 照跑、旗标注销（单写者闭环）")
	# P11c（R13①强化）：旧版起飞后定点采"第 30 帧非 Block"——击飞序列仍在途，
	# 白名单外禁入使断言恒真=窗盲。强化后全录像判停：自打断起逐帧盯到
	# state 含 "Move"（=落地+Recovery/GetBackUp 恢复链走完，脑回到自选权在
	# 地的 locomotion 门口，180 帧帽），途中任帧含 "Block" 即判红（白名单破
	# 口、持键回流的活体面）；180 帧不见 Move 亦红（"没恢复=没资格判"，反窗
	# 盲的证成腿）。首 Move 帧即收闸松键——此后再起架是白名单设计语义
	# （与 P7a 同路），本腿不越权判。
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
			"P11c 全录像判停：击飞→恢复→Move 途中持键零 Block（恢复=%s 违规帧=%s）"
			% [f11_move >= 0, block11_seen])
	_press_key(KEY_K, false)

	# ── 收场（评审 I3）：拆除残场，键位已净 ──
	stage.queue_free()
	_finished_q = true
