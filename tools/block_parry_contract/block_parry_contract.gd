extends Node

## S2-B3 盾反批契约：M 流=修饰核心 B′ 手术（重算回写）的回归流——
## base 捕获、加乘复合按序重算、乱序摘除、同 id 替换、非法型零副作用、
## reset 清账。
## P 流=判定缝三分支（Task4 批入）：靶场仿 attack_lane_contract——test_actor(A)
## 出拳 × street_vendor(V) 受击，场景 helper 逐字移植自 lane（99-107 家族）。
## Q 流（姿态状态/真键盘链）等由后续任务在本文件生长。
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


func _ready() -> void:
	await _flow_modifiers()
	# 判例（AGENTS）：子协程运行时炸掉后主协程照常续跑——每流自带完成旗单独锁
	_check(_finished_m, "M 流全序列执行完成（协程静默中断防线）")
	await _flow_parry()
	_check(_finished_p, "P 流全序列执行完成（协程静默中断防线）")
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


## 观察靶子掉血（命中即提前 true；全程未掉血 false）
func _watch_hit(vendor: QuiverCharacter, hp0: float, cap: int) -> bool:
	for _i in cap:
		if vendor.attributes.health_current < hp0:
			return true
		await get_tree().physics_frame
	return vendor.attributes.health_current < hp0


## 表现层记录窗：逐帧记录 掉血/入Hurt状态/hurt_high动画 三旗。转 Hurt 是
## call_deferred、动画节点切换要真实帧提交才可见——早退式断言会出竞态假红，
## 窗满或三旗齐才回（knockout 批"信标要 process 提交阶段才发"同款纪律）
func _watch_visual(vendor: QuiverCharacter, hp0: float, cap: int) -> Dictionary:
	var seen := {"hit": false, "hurt_state": false, "hurt_anim": false}
	for _i in cap:
		if vendor.attributes.health_current < hp0:
			seen.hit = true
		if str(vendor.state_machine.state_name) == "Ground/Hurt":
			seen.hurt_state = true
		# _playback 声明在皮肤组件子类上，走无类型局部避免基类静态检查误杀
		var pb = vendor._skin._playback
		if pb != null and String(pb.get_current_node()) == "hurt_high":
			seen.hurt_anim = true
		if seen.hit and seen.hurt_state and seen.hurt_anim:
			return seen
		await get_tree().physics_frame
	return seen


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


## 通用一发：同帧记录出手帧→开火→逐帧采样双方血量/池轨迹、Hurt 落态、暂停可见。
## hold=true：每帧重写 V.block_started_frame=当前帧，模拟"被打前一瞬按下 K"
##   （探针 j=0 实锤 ⇒ 缝读到 delta≡1，与动画前摇长度无关——免歧义构造）。
## target_delta≥0：预置 started=出手帧+w_cal−target_delta ⇒ 缝读到 delta≡目标值
##   （w_cal 来自 P1 同几何实测出手→命中帧距，同场景确定性）。
## 池轨迹用 min 捕获：受击回 Idle 后 refill 会把余量抬回，事后采样会漏判。
func _shot(vendor: QuiverCharacter, actor: QuiverCharacter, hold := false,
		target_delta := -1, w_cal := 0) -> Dictionary:
	var r := {
		"f_call": 0, "f_hit": -1,
		"v_hp0": 0.0, "v_hp_drop": 0.0, "v_pool_min": POOL0, "v_hurt": false,
		"a_hp0": 0.0, "a_hp_drop": 0.0, "a_pool_min": POOL0, "a_hurt": false,
		"paused_seen": false,
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
		if str(vendor.state_machine.state_name) == "Ground/Hurt":
			r.v_hurt = true
		if str(actor.state_machine.state_name) == "Ground/Hurt":
			r.a_hurt = true
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
	vendor.attributes.is_blocking = true
	vendor.attributes.block_started_frame = Engine.get_physics_frames() - 99
	var r2 := await _shot(vendor, actor)
	_check(r2.v_hp_drop == 4.0, "P2a 格挡掉血恰 4=10×0.4（超窗，实际 %.1f）" % r2.v_hp_drop)
	_check(not r2.v_hurt, "P2b 格挡 V 不入 Hurt（击退派发整颗吞掉）")
	_check(r2.v_pool_min >= POOL0, "P2c 格挡 V 池一分不扣（%.0f）" % r2.v_pool_min)
	_check(r2.a_hp_drop == 0.0 and r2.a_pool_min >= POOL0, "P2d 格挡下攻击方无波及")
	await _clean(vendor, actor)

	# ── P3 弹反（hold 构造：缝读 delta≡1 < 6）──
	vendor.attributes.is_blocking = true
	var r3 := await _shot(vendor, actor, true)
	_check(r3.v_hp_drop == 0.0, "P3a 弹反 V 免伤（实际 %.1f）" % r3.v_hp_drop)
	_check(r3.v_pool_min >= POOL0, "P3b 弹反 V 池一分不扣（%.0f）" % r3.v_pool_min)
	_check(r3.a_pool_min == POOL0 - 60.0, "P3c 弹反反顶：A 池 600→540（实际 %.0f）" % r3.a_pool_min)
	_check(r3.a_hurt, "P3d 弹反反顶：A 被拽进自己的 Ground/Hurt（顶回去=播自己的挨打姿势）")
	_check(r3.paused_seen, "P3e 弹反支自发加强定格可观测（免伤路不经 apply_damage 的自发拍，探针 B1 佐证）")
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
	for _i in 300:
		await get_tree().physics_frame
		if str(vendor.state_machine.state_name) == "Ground/Hurt":
			v_hurt6 = true
		v_pool6_min = minf(v_pool6_min, vendor.attributes.resistance_current)
		if is_instance_valid(ball) and ball.state != SpellBase.SpellState.ACTIVE:
			ball_spent = true
			break
		if not is_instance_valid(ball):
			ball_spent = true
			break
	var drop6: float = hp6 - vendor.attributes.health_current
	_check(drop6 == 4.0, "P6a 弹体被挡掉血恰 4=弹伤10×1.0×0.4（实际 %.1f）" % drop6)
	_check(not v_hurt6 and v_pool6_min >= POOL0, "P6b 弹体被挡无反顶无池耗无受击态")
	_check(ball_spent, "P6c 格挡支公共义务：on_target_hit 回执照发（弹体离场非 ACTIVE，否则穿体飞到判例复发）")
	if ball_spent and is_instance_valid(ball):
		ball.destroy()

	_finished_p = true
