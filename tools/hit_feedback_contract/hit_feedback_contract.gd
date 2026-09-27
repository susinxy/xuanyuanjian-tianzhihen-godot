extends Node

## S2-B4.7 命中反馈契约（T1 首版 S/H 流 → T2 并 P 流 → T3 并 E/K 流 + P6 腿）。
##
## S 流·定格退役（R1）：freeze_frames 双零（tscn 生效值+脚本默认）、三字段
## 数值域默认到位且 reset() 不清（档案配置非运行时态）、普通命中全程
## `not tree.paused` 行为锁。
## H 流·近战自慢放（R3）：命中→攻击者时间倍速掉档生效
## （H1，通道经皮肤门面路由：树驱动皮肤=树内 AnimationNodeTimeScale 参数、
## 直驱皮肤=player.speed_scale 备胎，本构建无 process_custom_speed；判例链
## 见 PLUGIN_ARCHITECTURE §17.1）→窗口
## （=实测攻击动画长×pct，禁硬编码 ms 判例）毕恢复 1.0（H2）；挥空全程
## 不触发（H3）；行为级副锁——命中慢放的出招全程相对挥空基线拉长
## （H1b，动画信标随慢放等比延迟=主通道属性断言之外的现象级见证）；
## 弹体形制命中（attacker 恒 null 的结构排除）无人被慢（H4）；双向性——
## 敌人命中玩家→敌人被慢、玩家全程满速（H5）；连段不破——首拳触发慢放
## 后三连段仍完整衔接（H6，raw J 走 OS 链×输入窗，spec §2.3 行为锁）。
##
## P 流·弹反改道（T2 R2"敌罚站我自由"）：弹反成立缝帧起——攻击者动画倍速
## ≤2 拍内掉 0（P2a）、其皮肤帧号在冻结窗内逐拍恒等且弹前推进=观测鲜活
## （P2b，位置通道判例见下）、防守方全程满速（P2c）、窗口（=防守方
## parry_stun_frames 折算，读守方数值域非魔数=P5 腿）毕恢复 1.0（P2d）、
## 冻结窗内守方移动输入生效（P3，raw D 注入 OS 链）、冻毕受击动画完整收口
## （P4，信标链不死=spec §5 风险 2 的锁）、全程世界零暂停（P1）。
##
## 观测通道判例（T0/T1/T2 探针实锤，4.7.1，§17.1）：AnimTree 驱动下
## player.get_current_animation()/position 族恒空/报错，动画长度经
## playback 当前状态→states/<名>/node→blend_point_N 就近点→"库/名"全名
## 查库；倍速观测=QuiverCharacter.anim_time_scale() 门面→皮肤路由
## （树驱动读 AnimationNodeTimeScale 参数、直驱读 player.speed_scale）；
## **动画位置**本构建无 Mixer/SMPlayback getter（T2 探针1/2：
## get_current_animation_position / get_current_playback_position /
## get_parameter_list 全不存在，节点参数盲猜族全 null），正解=皮肤
## AnimatedSprite2D 的 (animation, frame) 签名（T2 探针3：冻结恒等/推进
## 可见，两拍采样的判别力由弹前推进腿现场自证）。
##
## 测试主权法（B2.5）：只读消费 test_actor（peek() 三态守卫，缺席打处方红
## 绝不代 runner 创建）。落盘卫生（B4.5）：_ready 首行重定向套内 scratch，
## 套尾删净。共享 attributes 判例：全部角色实例 dup 后 root+skin 双写，
## **且必须先于入树**（本套 H5 零命中悬案病根：入树后换账=动作状态缓存原
## tres、受击盒拿 dup，ground_level 记账分家致车道中心漂移）。
## 时序断言全部从"测试内实测动画长×档案 pct"折算，不硬编码 ms。
##
## 直戳私有=测试特权豁免申报（T1 评审 M-4，T4 补声明）：套内多处绕过生产
## 写方直改内部字段/状态——P 流直写 `is_blocking/block_started_frame`（弹反
## 缝捷径，生产义务归 block_parry Q 流）、`state_machine.transition_to`
## 强制入场（P6d 跳攻腿）、提线盒摘挂阵营标签、行为总开关反拨等。这些是
## 台架特权**不是生产写方形制范例**，勿以本套为抄写模板。
##
## E 流·接触特效（T3 R4）：命中→特效节点出生且贴 hit_landed 回执接触点
## （E1/E1b）→default 风格+z=20 夹层（E1c）→生命周期毕场景根计数归零
## （E2 自动清理）→弹体命中同样出生（E3）+fire 卡消费经节点属性可证
## （E5a/E5b）→挥空零出生零信号（E4）。
## K 流·运行时开关（T3 R5）：toggle() 公开入口翻旗（K1，直改属性等价）+
## 开键预铺形制源码锁（K1b：InputMap.has_action 短路三连——hit_fx_toggle
## 缺席零报错零行为，controller 登记 [input] 后自动通电）+ 关闭态命中
## 零特效但慢放照常（K2a/K2b，视觉/时间双腿独立锁）。
## P6 腿·罚站封形（T2 扩权裁决并入）：弹反罚站中封形在场证明=全盒
## monitorable 关（P6a，形状 disabled 因活 blend 回写作废不作证人）；守方
## 踏出再踏回→零二次扣血（P6b）零 hurt 派发（P6c）；P6c 兼见证"再入期间
## 攻击者仍冻"（防窗口自然恢复后的假绿）；P6d（C1 评审）封形后强制空袭
## 入场，全盒 monitorable 须回 true——地面独占释放的旧形制让空袭盒恒静默
## 穿人，本腿先红后绿。红档对照=摘封形调用（d）/摘 jump-attack 释放（e）。
##
## 裸舞台沉降判例（T2 探针 d/e 实锤，P/E/K 流装配纪律）：角色在空 Node2D
## 舞台入场后**不会停在摆放位**——先悬停数拍再以 ~400px/拍初速下落、匀减速
## ~10px/拍²，历 ~45 拍才钉死在 y≈8174 的隐形地板，且**各角色起落相位随机**
## （26 拍时对位可差 2000px ⇒ 中途出拳必挥空）。H 流幸存纯侥幸：双方同拍
## 入场的平行下落保住相对偏移+每发 `_place` 重锚。P/E 流显式补防：同拍摆位 →
## `_settle` 族逐拍位移稳定判据等沉降毕 → 每发出拳前 `_place` 重锚。
##
## T3 探针新判例三条（4.7.1）：①headless 场景 runner 下 `_process`/
## SceneTreeTimer/Timer/Tween **全部照常推进**（40 物理拍配 76 idle 拍实测；
## 2026-09-16 "_process 面板从不出活"旧案系另病，特效生命周期可放心走
## timer/tween 通道）；②本构建 CPUParticles2D.color_ramp **收裸 Gradient**，
## CurveTexture/GradientTexture1D 赋值编译期拒收——参数卡色带运行时构造；
## ③动态 InputMap.add_action + raw 键直投**喂不饱** is_action_just_pressed
## 轮询（400 拍未命中）——K 流因此走 toggle 注入等价+源码形制锁，真开关键
## 端到端归 F5 感官单。
##
## 已知观察（极端测试档的副产物，非生产缺陷）：TEST_PCT=1.0 把慢放窗口放大
## 到整个攻击动画，攻击盒在受击者身上多拖数帧，受击晃动可致同一拳二段进窗
## （首发伤害锁帧判 10，窗口恢复从末次命中起算——block_parry"首血降锁缝帧"
## 同族纪律）。生产默认 pct=0.15 窗口≈1 帧，无此放大。
##
## 运行：bash tools/matrix_runner/run_matrix.sh --ensure-only 建替身后
##       godot --headless --path . res://tools/hit_feedback_contract/hit_feedback_contract.tscn

const Kit := preload("res://tools/matrix_runner/test_actor_kit.gd")
const ACTOR_SCENE := Kit.ACTOR_SCENE
const VENDOR := "res://characters/neutrals/street_vendor/street_vendor.tscn"
const SPELL_SCENE := "res://spells/fire_ball/fire_ball.tscn"
const SPELL_DEF := "res://spells/fire_ball/resources/fire_ball_definition.tres"
const HIT_FREEZE_SCRIPT := "res://addons/quiver.beat_em_up/utilities/helpers/autoload/hit_freeze/hit_freeze.gd"
# ── T3 特效件（宿主脚本按 SaveSystem 判例无 class_name，一律 preload 通道）──
const HIT_FX := preload("res://scripts/effects/hit_fx.gd")
const HIT_FX_PATH := "res://scripts/effects/hit_fx.gd"
const SPARK_FX := preload("res://scripts/effects/hit_spark_fx.gd")
const CARD_DEFAULT := preload("res://scripts/effects/presets/spark_default.tres")
const CARD_FIRE := preload("res://scripts/effects/presets/spark_fire.tres")

## 测试档案装配用的慢放档（非生产默认值！生产默认 0.2/0.15 由 S0 静态腿
## 锁住）：pct=1.0 把窗口放大到整个攻击动画，使"生效→恢复"两拍在
## test_actor 占位攻长（探针实测 ~100ms）下仍有可观测帧距。
const TEST_PCT := 1.0
const TEST_FACTOR := 0.2
const TEST_FACTOR_STRETCH := 0.05

var _fails := 0
var _finished_s := false
var _finished_h := false
var _finished_p := false
var _finished_e := false
var _finished_k := false
var _paused_seen := false
## P 流专属世界暂停见证（与 H 流 S1 分旗——S1 在 P 流之前已结算）
var _paused_seen_p := false

## 双方抗击池上限（test_actor 数值域显式 600，block_parry POOL0 同源）：
## P 流"弹反成立缝"以攻击方反顶削池（600→540）为判据——该信号与时间机制
## 正交，R8 破坏腿（摘定格）下依然可测=探测位不与被测面同沉
const POOL0 := 600.0


func _ready() -> void:
	# B4.5 落盘卫生条款：影子落盘重定向套内 scratch，永不碰生产槽
	get_node_or_null(^"/root/SaveSystem").slot_path = "user://b47_hf_scratch.json"
	await _flow_static()
	_check(_finished_s, "S 流全序列执行完成（协程静默中断防线）")
	await _flow_melee()
	_check(_finished_h, "H 流全序列执行完成（协程静默中断防线）")
	await _flow_parry()
	_check(_finished_p, "P 流全序列执行完成（协程静默中断防线）")
	await _flow_fx()
	_check(_finished_e, "E 流全序列执行完成（协程静默中断防线）")
	_check(_finished_k, "K 流全序列执行完成（协程静默中断防线）")
	get_node_or_null(^"/root/SaveSystem").delete_save()   # 套尾删净 scratch 不过夜
	print("════════ hit-feedback-contract: %s ════════" % ("PASS" if _fails == 0 else "FAIL"))
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails += 1
	print("  %s: %s" % ["PASS" if ok else "FAIL", label])


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


## 头部三态守卫（input_channel/block_parry 同款只读阶梯；缺席打可读红、
## 绝不代 runner 创建）
func _guard_actor() -> bool:
	var remedy := "先跑 bash tools/matrix_runner/run_matrix.sh --ensure-only 建好 test_actor"
	var st: int = Kit.peek()  # 只读三态分类（零副作用、永不建档）
	match st:
		Kit.READY:
			print("ACTOR-GATE: test_actor 就绪（只读三态守卫通过）")
			return true
		Kit.NEEDS_IMPORT:
			_check(false, "替身守卫：test_actor 已建未导入（%s）" % remedy)
		Kit.ABSENT:
			_check(false, "替身守卫：test_actor 缺席（%s）" % remedy)
		_:
			_check(false, "替身守卫：peek() 返回未知态 %d（kit 契约破损）" % st)
	return false


func _wait_state(ch: QuiverCharacter, path: String, cap: int = 600) -> bool:
	for _i in cap:
		if str(ch.state_machine.state_name) == path:
			return true
		await get_tree().physics_frame
	return str(ch.state_machine.state_name) == path


func _place(victim: QuiverCharacter, attacker: QuiverCharacter, offset: Vector2) -> void:
	victim.global_position = attacker.global_position + offset
	await _frames(6)


func _attack(actor: QuiverCharacter, dir: Vector2) -> void:
	actor._skin.skin_direction = dir
	actor.state_machine.transition_to("Ground/Combo1")


## raw 键注入（B3-T2 判例：pressed 默认 false 陷阱，down 逐字段显式；
## keycode+physical 双填）。device 对齐**绑定原文**是新增判例（T1 探针实锤：
## attack 绑定 device=16，注入 device=-1 事件被 is_action_pressed 拒匹配；
## block/jump 绑定 device=-1 反例同场——判据恒"注入设备==绑定设备"）。
func _press_key(p_key: int, p_pressed: bool, p_device: int = -1) -> void:
	var ev := InputEventKey.new()
	ev.device = p_device
	ev.keycode = p_key
	ev.physical_keycode = p_key
	ev.pressed = p_pressed
	Input.parse_input_event(ev)


## 角色实例私有属性副本（共享 attributes 幻影判例）：dup 后 root+skin 双写。
func _own_attrs(actor: QuiverCharacter) -> QuiverAttributes:
	var dup: QuiverAttributes = actor.attributes.duplicate(true)
	actor.get_node(actor._path_skin).attributes = dup
	actor.attributes = dup
	return dup


# ═══════════════════════ S 流：静态退役锁（R1 + 数值域） ═══════════════════════

func _flow_static() -> void:
	# S0a 全局定格双保险归零：autoload 场景生效值 + 脚本裸默认
	_check(HitFreeze.freeze_frames == 0,
			"S0a HitFreeze（autoload 实载）freeze_frames=0——普通/格挡流不停世界")
	var bare: Node = (load(HIT_FREEZE_SCRIPT) as GDScript).new()
	_check(bare.freeze_frames == 0, "S0b hit_freeze.gd 脚本默认亦=0（tscn 属性行+代码默认双保险）")
	bare.free()
	# S0c 数值域三字段默认到位（法源 spec §2.3；chen 等既有 tres 无此键=
	# 零迁移吃代码默认，判例 attack_axis_mode）
	var a := QuiverAttributes.new()
	_check(is_equal_approx(a.hit_slow_factor, 0.2), "S0c hit_slow_factor 默认 0.2")
	_check(is_equal_approx(a.hit_slow_anim_pct, 0.15), "S0d hit_slow_anim_pct 默认 0.15")
	_check(a.parry_stun_frames == 6, "S0e parry_stun_frames 默认 6（T2 消费，T1 仅落字段）")
	# S0f 档案配置非运行时态：reset() 不清（B4.6 attack_axis_mode 同族注例）
	a.health_current = 1
	a.hit_slow_factor = 0.6
	a.reset()
	_check(is_equal_approx(a.hit_slow_factor, 0.6), "S0f reset() 不清命中反馈档（本腿唯一写 0.6 存活）")
	# RefCounted 手动释放通道在本构建不存在（delete 无、free 拒——block_parry
	# M 流判例：裸 new 的 attributes 放任随引用消亡自灭，Events 连接随尸解体）
	_finished_s = true


# ═══════════════════ H 流：近战自慢放 × 弹体排除 × 双向 × 连段 ═══════════════════

var _stage: Node2D
var _actor: QuiverCharacter   # A：玩家档近战者
var _vendor: QuiverCharacter  # V：被动挨打靶

func _flow_melee() -> void:
	if not _guard_actor():
		_finished_h = true
		return
	_stage = Node2D.new()
	add_child(_stage)
	_actor = (load(ACTOR_SCENE) as PackedScene).instantiate()
	_vendor = (load(VENDOR) as PackedScene).instantiate()
	# ⚠ dup 必须先于入树（Q 流形制；本套 H5 零命中悬案的病根）：动作状态在
	# owner.ready 时缓存 attributes——先 add 后换账会让 ground_level 等运行时
	# 写进原 tres 而受击盒拿着 dup（ground≡0），车道判定中心漂移（双零恰好
	# 互抵所以近战腿全绿，换"账本正确的攻击方"打它就恒拒）。
	_own_attrs(_actor)
	_own_attrs(_vendor)
	_stage.add_child(_actor)
	_stage.add_child(_vendor)
	_actor.global_position = Vector2(500, 400)
	_vendor.global_position = Vector2(500, 280)
	await _frames(18)
	var ok0: bool = await _wait_state(_actor, "Ground/Move/Idle", 120)
	_check(ok0 and str(_vendor.state_machine.state_name) != "", "H0a 替身/小贩入场就绪")
	# 测试档案装配：窗口=全攻击动画（放大到探针实测帧距可辨的量级）
	_actor.attributes.hit_slow_anim_pct = TEST_PCT
	_actor.attributes.hit_slow_factor = TEST_FACTOR
	# H0b 结构锁：attacker 下发链——近战角色攻击盒逐盒回指本体
	var stamps_ok := not _actor._skin.hitboxes.is_empty()
	for hb in _actor._skin.hitboxes:
		if hb.attacker != _actor:
			stamps_ok = false
	_check(stamps_ok,
			"H0b 近战攻击盒 attacker=角色本体（收集处 stamp；弹体路见 H4，攻长 %d 盒）"
			% _actor._skin.hitboxes.size())
	await _leg_hit_slow()
	await _leg_whiff()
	await _leg_stretch()
	await _leg_chain()
	await _leg_spell()
	await _leg_bidir()
	_check(not _paused_seen, "S1 本流全程无全局定格（普通/弹体/弹反外命中帧及后续 tree.paused 恒 false）")
	_stage.queue_free()
	_finished_h = true


## 采样环公共义务：paused 见证位（S1 腿的行为锁，H 流全程共用一个旗）
func _watch_pause() -> void:
	if get_tree().paused:
		_paused_seen = true


## H1/H2：命中→1 拍内倍速掉档；窗口毕（实测攻长×pct 折算拍数 +4 裕量）恢复。
## 多进窗纪律（block_parry"首血降锁缝帧"判例同族）：攻击盒动画时间里单-enable
## 但几何位移，极端测试档（pct=1.0）下慢放窗口让盒子在受击者身上多拖数帧→
## 受击晃动可产生第二次 area_entered（同拳二段进窗）。故：伤害锁首发帧恰 10；
## 窗口裕量从最后一次命中请求起算（重入=代数令牌接力，语义仍正确）。
func _leg_hit_slow() -> void:
	_vendor.attributes.reset()
	await _place(_vendor, _actor, Vector2(80, 30))
	var v_hp0: float = _vendor.attributes.health_current
	var anim_ms_expected := _actor.attack_anim_length_ms()  # 起手前=攻树不可得，仅诊断用
	_attack(_actor, Vector2.RIGHT)
	var f_hit := -1
	var f_hit_last := -1
	var f_prev_hp := 0.0
	var scale_at_hit := 1.0
	var drop_at_first := 0.0
	var anim_ms_at_hit := -1.0
	var f_restore := -1
	var fps := Engine.get_physics_ticks_per_second()
	for _i in 240:
		await get_tree().physics_frame
		_watch_pause()
		var s := _actor.anim_time_scale()
		var hp := _vendor.attributes.health_current
		if f_hit < 0 and hp < v_hp0:
			f_hit = Engine.get_physics_frames()
			f_hit_last = f_hit
			scale_at_hit = s
			drop_at_first = v_hp0 - hp
			# 与生产钩子同源读数（同一帧、同一门面）：窗口分母
			anim_ms_at_hit = _actor.attack_anim_length_ms()
		elif f_hit >= 0 and hp < f_prev_hp - 0.001:
			f_hit_last = Engine.get_physics_frames()
		f_prev_hp = hp
		if f_hit >= 0 and f_restore < 0 and is_equal_approx(s, 1.0):
			f_restore = Engine.get_physics_frames()
		if f_hit >= 0 and f_restore >= 0:
			break
	_check(drop_at_first == 10.0, "H1-0 常规命中首发结算原样（掉血恰 10，实际 %.1f）" % drop_at_first)
	_check(f_hit >= 0 and scale_at_hit < 1.0 and is_equal_approx(scale_at_hit, TEST_FACTOR),
			"H1 命中可见帧攻击者倍速即掉档 %s（观测 %.3f，起手前攻长读数 %.1fms）"
			% [TEST_FACTOR, scale_at_hit, anim_ms_expected])
	_check(anim_ms_at_hit > 0.0 and anim_ms_at_hit < 5000.0,
			"H1' 命中帧生产侧动画长同源可得（%.1fms——非 -1 非兜底 500）" % anim_ms_at_hit)
	# 窗口折算：帧数=anim_ms×pct×fps/1000（与调度器同一公式，读档案现值）
	var expected := maxi(1, int(round(anim_ms_at_hit * _actor.attributes.hit_slow_anim_pct * fps / 1000.0)))
	_check(f_restore >= 0 and f_restore - f_hit_last <= expected + 4,
			"H2 末次命中窗口毕恢复 1.0（折算 %d 帧窗口，末命中→恢复 %d 帧，首命中→恢复 %d 帧含二段进窗接力）"
			% [expected, (f_restore - f_hit_last) if f_restore >= 0 else -1,
			(f_restore - f_hit) if f_restore >= 0 else -1])
	await _clean()


## H3：挥空全程倍速 1.0（触发面锁——只有命中才慢）；顺带产出 H1b 的
## 挥空全程基线 f0（同一角色同一动作的现象级对照）
func _leg_whiff() -> void:
	# V 挪出攻击触达（900px >> 盒宽+车道），挥完整招
	_vendor.global_position = _actor.global_position + Vector2(900, 30)
	await _frames(6)
	_attack(_actor, Vector2.RIGHT)
	var scaled_seen := false
	var v_hp0: float = _vendor.attributes.health_current
	var total := 0
	var done := false
	for _i in 300:
		await get_tree().physics_frame
		_watch_pause()
		total += 1
		if not is_equal_approx(_actor.anim_time_scale(), 1.0):
			scaled_seen = true
		if str(_actor.state_machine.state_name) == "Ground/Move/Idle":
			done = true
			break
	_check(not scaled_seen, "H3 挥空全程倍速恒 1.0（未命中不触发慢放）")
	_check(_vendor.attributes.health_current == v_hp0, "H3' 挥空零命中（靶血不动）")
	_whiff_baseline = total
	_check(done and total >= 4, "H3'' 挥空自然收招（全程 %d 帧，作 H1b 基线）" % total)
	await _clean()


var _whiff_baseline := 0

## H1b 行为级副锁：命中→慢放→动画时钟等比放慢→出招全程（信标收口）
## 相对挥空基线拉长。主通道属性断言（H1/H2）独证的防线：万一 speed_scale
## 只是"挂上了没接电"，本腿必红。第二窗口（命中重新起表）按档案换算
## 必然 >1 帧，+3 帧地板保守；无慢放世界里该差值恒 ≤1（两次同招抖动）。
func _leg_stretch() -> void:
	_actor.attributes.hit_slow_factor = TEST_FACTOR_STRETCH
	_vendor.attributes.reset()
	await _place(_vendor, _actor, Vector2(80, 30))
	_attack(_actor, Vector2.RIGHT)
	var total := 0
	var done := false
	var scaled_seen := false
	for _i in 400:
		await get_tree().physics_frame
		_watch_pause()
		total += 1
		if _actor.anim_time_scale() < 1.0:
			scaled_seen = true
		if str(_actor.state_machine.state_name) == "Ground/Move/Idle":
			done = true
			break
	_actor.attributes.hit_slow_factor = TEST_FACTOR
	_check(done and scaled_seen, "H1b-a 慢放命中招收招且途中倍速 <1 可观测（全程 %d 帧）" % total)
	_check(total - _whiff_baseline >= 3,
			"H1b-b 行为级：命中慢放全程 %d 帧 ≥ 挥空基线 %d + 3（动画信标被等比拖后）"
			% [total, _whiff_baseline])
	await _clean()


## H6 连段不破：首拳命中触发慢放后，三连段仍完整衔接至终结收招
## （spec §2.3 节奏均匀性行为锁）。数据缺口申报：test_actor/模板的占位攻
## 击动画**不含 end_of_input_frames 方法轨**（chen 真动画 0.2s 处才有，
## 探针/T1 双实锤）——连段的信标腿改由测试显式 emit 皮肤信号驱动（生产
## 连接逻辑 _on_attack_input_frames_finished→combo_state 原样消费），
## 输入腿（J 键投递→deliver_event 窗控→attack() 闩锁）全程真链路。
func _leg_chain() -> void:
	# 慢放扰动维持最恶劣档（窗口=全攻长）；V 池×100 免飞天离场（修饰 API
	# 走受管路，refill 生效）
	_vendor.attributes.reset()
	_vendor.attributes.add_modifier(&"hf6_pool", &"knockout_resistance_max", "multiply", 100.0, self)
	_vendor.attributes.refill_resistance()
	await _place(_vendor, _actor, Vector2(80, 30))
	var v_hp0: float = _vendor.attributes.health_current
	const J_DEV := 16  # 探针实锤：attack 绑定 device=16
	# 起手（Idle→Combo1）走真按键
	_press_key(KEY_J, true, J_DEV)
	await _frames(1)
	_press_key(KEY_J, false, J_DEV)
	var ok1: bool = await _wait_state(_actor, "Ground/Combo1", 60)
	var hit1: bool = await _wait_vdrop(v_hp0, 1, 90)
	# Combo1 输入窗开着（占位攻无 input-frames 信标→窗不会自关）：真按键
	# 闩上 _should_combo，再显式响信标驱动生产连接腿
	_press_key(KEY_J, true, J_DEV)
	await _frames(1)
	_press_key(KEY_J, false, J_DEV)
	_actor._skin.attack_input_frames_finished.emit()
	var ok2: bool = await _wait_state(_actor, "Ground/Combo2", 600)
	var hit2 := false
	if ok2:
		hit2 = await _wait_vdrop(v_hp0, 2, 300)
		_press_key(KEY_J, true, J_DEV)
		await _frames(1)
		_press_key(KEY_J, false, J_DEV)
		_actor._skin.attack_input_frames_finished.emit()
	var ok3: bool = await _wait_state(_actor, "Ground/Combo3", 600)
	var hit3 := false
	if ok3:
		hit3 = await _wait_vdrop(v_hp0, 3, 300)
	var ok4: bool = await _wait_state(_actor, "Ground/Move/Idle", 600)
	_check(ok1 and ok2 and ok3 and ok4,
			"H6 慢放中三连段完整衔接 Combo1→2→3→Idle（%s/%s/%s/%s）"
			% [ok1, ok2, ok3, ok4])
	_check(hit1 and hit2 and hit3,
			"H6'' 逐拳命中节拍齐（信标腿×输入窗全链在慢放窗口下不吞命中）")
	var drop: float = v_hp0 - _vendor.attributes.health_current
	_check(drop == 55.0,
			"H6' 段段咬合：三拳总伤 55=10+15+30 全程在慢放窗口下照常结算（实际 %.1f）" % drop)
	# 腿内卫生：摘掉池修饰（_clean 的 reset 也会清账，此处显式=意图自白）
	_vendor.attributes.remove_modifier(&"hf6_pool")
	await _clean()


## 等 V 的掉血台阶到第 n 档（10/25/55）——单发单结算，最多 24 帧容差
func _wait_vdrop(v_hp0: float, n: int, cap: int) -> bool:
	var want: float = {1: 10.0, 2: 25.0, 3: 55.0}[n]
	for _i in cap:
		await get_tree().physics_frame
		_watch_pause()
		if v_hp0 - _vendor.attributes.health_current >= want - 0.001:
			return true
	return false


## H4 弹体形制：真 fire_ball 命中（其攻击盒 attacker 恒 null 的结构排除路）
## →施法者与受击者全程满速；并锚定"弹体攻击盒绑施法者属性"旧判例
## （若无 attacker 结构、凭 character_attributes 直觉判归属，本腿会慢错人）
func _leg_spell() -> void:
	_vendor.attributes.reset()
	await _place(_vendor, _actor, Vector2(80, 30))
	var spell_scene: PackedScene = load(SPELL_SCENE)
	var spell_def: SpellDefinition = load(SPELL_DEF)
	var ball := spell_scene.instantiate() as SpellBase
	_stage.add_child(ball)
	ball.global_position = Vector2(_vendor.global_position.x - 160.0, _vendor.global_position.y)
	ball.cast(_actor, spell_def, Vector2.RIGHT)
	# 结构锁：弹体皮肤攻击盒 attacker 恒 null（收集路不经过 QuiverCharacter）
	var structural_ok := not ball._skin.hitboxes.is_empty()
	var binds_caster := false
	for hb in ball._skin.hitboxes:
		if hb.attacker != null:
			structural_ok = false
		if hb.character_attributes == _actor.attributes:
			binds_caster = true
	_check(structural_ok, "H4a 弹体攻击盒 attacker 恒 null（近战 stamp 链结构外）")
	_check(binds_caster, "H4b 锚定旧判例：弹体盒 character_attributes=施法者属性（慢错人的诱惑源）")
	var v_hp0: float = _vendor.attributes.health_current
	var a_scaled := false
	var v_scaled := false
	var spent := false
	for _i in 300:
		await get_tree().physics_frame
		_watch_pause()
		if not is_equal_approx(_actor.anim_time_scale(), 1.0):
			a_scaled = true
		if not is_equal_approx(_vendor.anim_time_scale(), 1.0):
			v_scaled = true
		if not is_instance_valid(ball) or ball.state != SpellBase.SpellState.ACTIVE:
			spent = true
			break
	_check(_vendor.attributes.health_current < v_hp0 and spent,
			"H4c 弹体命中确实发生（靶掉血 %0.1f，弹体离场）"
			% (v_hp0 - _vendor.attributes.health_current))
	_check(not a_scaled and not v_scaled,
			"H4d 弹体命中无人被慢放（施法者/受击者倍速全程 1.0）")
	if spent and is_instance_valid(ball):
		ball.destroy()
	await _clean()


## H5 双向性：第二角色（提线攻击方，摘 player 阵营换挂 hf_puppet）命中
## 玩家 A → 攻击方自己掉档、玩家（受害者）全程满速——"谁打中慢谁"
func _leg_bidir() -> void:
	_vendor.attributes.reset()
	# V 挪远（B 的盒对 V 阵营不豁免——几何保险，见 Q 流同族判例）
	_vendor.global_position = Vector2(-2200, -400)
	var b: QuiverCharacter = (load(ACTOR_SCENE) as PackedScene).instantiate()
	_own_attrs(b)
	_stage.add_child(b)
	b.attributes.hit_slow_anim_pct = TEST_PCT
	b.attributes.hit_slow_factor = TEST_FACTOR
	# B 提线化：关行为总开关（J 键广播不劫持）+ 战斗盒阵营手术
	# （remove 走 Variant 动态调用触发 override 刷缓存；add 走公开入口——AGENTS 判例）
	(b.behavior as QuiverBehavior).active = false
	for node in b.find_children("*", "Area2D", true, false):
		var box = node
		if box is QuiverHitBox:
			box.remove_from_group(&"area2d:player")
			box.add_faction_group(&"area2d:hf_puppet")
		elif box is QuiverHurtBox:
			# 与 hitbox 对称（T4 终审清欠账：原版只换挂不摘 player=对"玩家打
			# 木偶"留同阵营豁免面，与本腿注"摘 player 换挂"的申报不符）
			box.remove_from_group(&"area2d:player")
			box.add_faction_group(&"area2d:hf_puppet")
	b.global_position = _actor.global_position - Vector2(80, 30)  # B 居西、默认面朝东
	await _frames(8)
	var a_hp0: float = _actor.attributes.health_current
	var b_first := 1.0
	var a_scaled := false
	var b_scaled_seen := false
	var f_hit := -1
	var f_hit_last := -1
	var prev_hp := 0.0
	var anim_ms := -1.0
	var f_restore := -1
	_attack(b, Vector2.RIGHT)
	var fps := Engine.get_physics_ticks_per_second()
	for _i in 240:
		await get_tree().physics_frame
		_watch_pause()
		var sb := b.anim_time_scale()
		if not is_equal_approx(_actor.anim_time_scale(), 1.0):
			a_scaled = true
		var hp := _actor.attributes.health_current
		if f_hit < 0 and hp < a_hp0:
			f_hit = Engine.get_physics_frames()
			f_hit_last = f_hit
			b_first = sb
			anim_ms = b.attack_anim_length_ms()
		elif f_hit >= 0 and hp < prev_hp - 0.001:
			f_hit_last = Engine.get_physics_frames()
		prev_hp = hp
		if f_hit >= 0 and not is_equal_approx(sb, 1.0):
			b_scaled_seen = true
		if f_hit >= 0 and f_restore < 0 and is_equal_approx(sb, 1.0):
			f_restore = Engine.get_physics_frames()
		if f_hit >= 0 and f_restore >= 0:
			break
	_check(f_hit >= 0, "H5a 提线方拳命中玩家（A 掉血 %.1f）" % (a_hp0 - _actor.attributes.health_current))
	_check(b_scaled_seen and b_first < 1.0,
			"H5b 敌人命中玩家→敌人自己掉档（观测 %.3f）" % b_first)
	_check(not a_scaled, "H5c 受害者全程满速（慢放只打攻击者，双向语义的另一面）")
	var expected := maxi(1, int(round(anim_ms * b.attributes.hit_slow_anim_pct * fps / 1000.0)))
	_check(f_restore >= 0 and f_restore - f_hit_last <= expected + 4,
			"H5d 攻击方末次命中窗口毕恢复 1.0（折算 %d 帧，末命中→恢复 %d 帧）"
			% [expected, (f_restore - f_hit_last) if f_restore >= 0 else -1])
	b.queue_free()
	await _frames(4)
	await _clean()


## 腿间卫生（block_parry _clean 形制）：双方回待机、靶清账、A 补档
func _clean() -> void:
	_actor.attributes.hit_slow_anim_pct = TEST_PCT
	_actor.attributes.hit_slow_factor = TEST_FACTOR
	await _wait_state(_actor, "Ground/Move/Idle", 900)
	await _wait_state(_vendor, "Ground/Move/Idle", 900)
	_vendor.attributes.reset()
	_actor.attributes.refill_resistance()
	await _frames(2)


# ═══════════════ P 流：弹反改道"敌罚站我自由"（T2 R2，B4.7） ═══════════════
# D=防守方（test_actor 玩家档，行为开，全程可动）；P=提线攻击方
# （H5 同款手术：行为总开关关 + 战斗盒摘 player 换挂 hfp_puppet，居西面东）。
# 弹反走判定缝内部捷径（直写 is_blocking/block_started_frame + hold 重写
# delta≡1，block_parry j=0 约定）——姿态旗的生产写方归 block_parry Q 流，
# 本流命题=定格拍改道后的时间面三件套（攻击者冻、防守方活、世界不暂停）。

var _stage_p: Node2D
var _def: QuiverCharacter
var _atk2: QuiverCharacter


## 皮肤精灵解析（位置观测，block_parry 同款：角色子树第一个 AnimatedSprite2D）
func _skin_sprite(ch: QuiverCharacter) -> AnimatedSprite2D:
	var sprites := ch.find_children("*", "AnimatedSprite2D", true, false)
	return sprites[0] if not sprites.is_empty() else null


func _flow_parry() -> void:
	if not _guard_actor():
		_finished_p = true
		return
	_stage_p = Node2D.new()
	add_child(_stage_p)
	_def = (load(ACTOR_SCENE) as PackedScene).instantiate()
	_atk2 = (load(ACTOR_SCENE) as PackedScene).instantiate()
	# dup 先于入树（H 流病根判例）
	_own_attrs(_def)
	_own_attrs(_atk2)
	_stage_p.add_child(_def)
	_stage_p.add_child(_atk2)
	# ⚠ 裸舞台沉降判例（T2 探针 d/e 实锤）：角色入场后并不停在摆放位——
	# 空舞台上有一段数十拍的高初速异步"落位"（各角色起落相位不一，26 拍时
	# 对位可差 2000px ⇒ 拳在中途挥空）。装配纪律=**同拍摆位 + 逐拍位移
	# 稳定判据等沉降毕 + 每发出拳前 _place 重锚**。
	_def.global_position = Vector2(500, 400)
	_atk2.global_position = Vector2(420, 370)
	var settled := await _settle(240)
	(_atk2.behavior as QuiverBehavior).active = false
	for node in _atk2.find_children("*", "Area2D", true, false):
		var box = node
		if box is QuiverHitBox:
			box.remove_from_group(&"area2d:player")
			box.add_faction_group(&"area2d:hfp_puppet")
		elif box is QuiverHurtBox:
			# 与 hitbox 对称（T4 终审清欠账，H5 同款勘误）
			box.remove_from_group(&"area2d:player")
			box.add_faction_group(&"area2d:hfp_puppet")
	await _frames(6)
	var ok0: bool = await _wait_state(_def, "Ground/Move/Idle", 120)
	_check(ok0 and settled,
			"P0a 防守/提线双入场就绪且落位沉降毕（沉降超时=对位漂移，全套时序作废）")
	await _leg_parry_freeze()
	await _leg_parry_stun_config()
	await _leg_parry_seal()
	await _p_clean()
	_stage_p.queue_free()
	_finished_p = true


## 等两名角色逐拍位移归稳（|Δ|<0.05 连续两拍）；超时返回 false
func _settle(cap: int) -> bool:
	var pa := Vector2(INF, INF)
	var pb := Vector2(INF, INF)
	for _i in cap:
		await get_tree().physics_frame
		var na: Vector2 = _def.global_position
		var nb: Vector2 = _atk2.global_position
		if (na - pa).length() < 0.05 and (nb - pb).length() < 0.05:
			return true
		pa = na
		pb = nb
	return false


## 主腿：弹反成立→攻击者 ≤2 拍冻、冻窗内皮肤签名恒等（罚站实证）、防守方
## 满速可动（raw D 走 OS 链位移生效）、世界零暂停、窗口毕恢复、冻毕受击
## 动画完整收口（信标链不死，spec §5 风险 2 的锁）。
func _leg_parry_freeze() -> void:
	var sp := _skin_sprite(_atk2)
	if sp == null:
		_check(false, "P0b 攻击方皮肤精灵可得（位置观测前置，缺席则本腿无证人）")
		return
	_def.attributes.is_blocking = true
	_def.attributes.block_started_frame = Engine.get_physics_frames()
	var d_hp0: float = _def.attributes.health_current
	var a_hp0: float = _atk2.attributes.health_current
	# 出拳前重锚（沉降纪律的 H 流 _place 同款）：双方已落位，6 拍让新对位入物理快照
	await _place(_atk2, _def, Vector2(-80, -30))
	_attack(_atk2, Vector2.RIGHT)
	var f_seam := -1
	var f_scale0 := -1
	var f_restore := -1
	var alive_pre := 0
	var last_sig := ""
	var frozen_sigs: Array = []
	## 边缘锁（T2 评审 M1，T4 补）：冻样首帧须离动画尾 ≥2 帧——"恒等"才是
	## 冻结实证而非"已到末帧自然收口"冒充
	var frozen_edge_ok := false
	var d_pos0 := Vector2.ZERO
	var dx_max := 0.0
	var a_scale_min := 1.0
	var d_scale_min := 1.0
	var a_pool_min := POOL0
	for _i in 120:
		await get_tree().physics_frame
		_watch_pause()
		if get_tree().paused:
			_paused_seen_p = true
		var s_atk := _atk2.anim_time_scale()
		a_scale_min = minf(a_scale_min, s_atk)
		d_scale_min = minf(d_scale_min, _def.anim_time_scale())
		a_pool_min = minf(a_pool_min, _atk2.attributes.resistance_current)
		var sig := "%s@%d" % [sp.animation, sp.frame]
		if f_seam < 0:
			# hold 重写（block_parry j=0 约定）：命中落哪帧都 delta≡1
			_def.attributes.block_started_frame = Engine.get_physics_frames()
			if last_sig != "" and sig != last_sig:
				alive_pre += 1
			if _atk2.attributes.resistance_current < POOL0 - 0.5:
				f_seam = Engine.get_physics_frames()
				d_pos0 = _def.global_position
				_press_key(KEY_D, true)  # P3：弹反成立即放防守方走路
		elif s_atk <= 0.001 and str(_atk2.state_machine.state_name).contains("Hurt"):
			# 冻窗采样（Hurt 落态后的签名，flip 至多污染头部一两拍，
			# 判据取尾部连续=两拍采样冻结）
			if frozen_sigs.is_empty():
				# 本构建 AnimatedSprite2D **无 frame_end**（T4 探针实锤）——
				# 帧数真相在 SpriteFrames.get_frame_count("动画名")
				var cnt := sp.sprite_frames.get_frame_count(sp.animation) \
					if sp.sprite_frames != null else 0
				frozen_edge_ok = sp.frame < cnt - 2
			frozen_sigs.append(sig)
		if f_seam >= 0 and f_scale0 < 0 and s_atk <= 0.001:
			f_scale0 = Engine.get_physics_frames()
		if f_seam >= 0 and f_restore < 0 and is_equal_approx(s_atk, 1.0):
			f_restore = Engine.get_physics_frames()
			_press_key(KEY_D, false)
		if f_seam >= 0:
			dx_max = maxf(dx_max, _def.global_position.x - d_pos0.x)
		last_sig = sig
		if f_seam >= 0 and f_restore >= 0 and Engine.get_physics_frames() - f_restore >= 3:
			break
	_press_key(KEY_D, false)  # 无条件净键（红世界 f_restore 可能永缺，防 D 漏键串腿）
	var stun := _def.attributes.parry_stun_frames
	_check(_def.attributes.health_current == d_hp0 and a_pool_min <= POOL0 - 59.0
			and _atk2.attributes.health_current == a_hp0,
			"P0 弹反成立（D 免伤、P 反顶削池最低 %.0f、P 血不动——缝语义原样）" % a_pool_min)
	_check(not _paused_seen_p,
			"P1 弹反成功起全程世界零暂停（tree.paused 恒 false，敌罚站我自由）")
	_check(f_seam >= 0 and f_scale0 >= 0 and f_scale0 - f_seam <= 2,
			"P2a 攻击者动画倍速 ≤2 拍内掉到 0（缝=%s 冻见=%s，最低读 %.2f）"
			% [f_seam, f_scale0, a_scale_min])
	_check(alive_pre >= 1,
			"P2b 观测鲜活：弹前（缝之前）攻击者皮肤签名推进 %d 次（通道非死读数）" % alive_pre)
	_check(frozen_sigs.size() >= 3 and _tail_equal(frozen_sigs, 3) and frozen_edge_ok,
			"P2b' 罚站实证：冻窗内攻击者 (动画@帧) 采样 %d 拍且尾 3 拍恒等，"
			% frozen_sigs.size()
			+ "首帧离尾 ≥2 帧（边缘锁防末帧自然收口冒充冻结；%s）"
			% [frozen_sigs[2] if frozen_sigs.size() >= 3 else "<采样不足>"])
	_check(d_scale_min >= 0.999,
			"P2c 防守方动画倍速全程不降（最低 %.2f，罚站不罚守）" % d_scale_min)
	_check(f_restore > 0 and f_restore - f_seam >= stun - 2 and f_restore - f_seam <= stun + 6,
			"P2d 窗口毕攻击者恢复 1.0（守方数值域 %d 帧，实测 %d 帧，缝=%s 恢=%s）"
			% [stun, (f_restore - f_seam) if f_restore > 0 else -1, f_seam, f_restore])
	_check(dx_max >= 8.0,
			"P3 冻窗内防守方移动输入生效（raw D 走 OS 链，窗前位移 %.0fpx——全局定格世界必钉零）"
			% dx_max)
	var ok4: bool = await _wait_state(_atk2, "Ground/Move/Idle", 240)
	_check(ok4, "P4 信标链不死：冻毕攻击者受击动画完整收口 Hurt→Idle（spec §5 风险 2 锁）")


## P5 数值域读取锁：防守方 parry_stun_frames 6→12，冻结窗必须同步变长
## （魔数 6 残留世界在第 ~6 拍就恢复——本腿抓"没读守方字段"）
func _leg_parry_stun_config() -> void:
	_def.attributes.parry_stun_frames = 12
	_def.attributes.is_blocking = true
	_def.attributes.block_started_frame = Engine.get_physics_frames()
	_atk2.attributes.refill_resistance()
	await _place(_atk2, _def, Vector2(-80, -30))
	_attack(_atk2, Vector2.RIGHT)
	var f_seam := -1
	var f_restore := -1
	for _i in 160:
		await get_tree().physics_frame
		_watch_pause()
		if get_tree().paused:
			_paused_seen_p = true
		var s_atk := _atk2.anim_time_scale()
		if f_seam < 0:
			_def.attributes.block_started_frame = Engine.get_physics_frames()
			if _atk2.attributes.resistance_current < POOL0 - 0.5:
				f_seam = Engine.get_physics_frames()
		elif f_restore < 0 and is_equal_approx(s_atk, 1.0):
			f_restore = Engine.get_physics_frames()
		if f_seam >= 0 and f_restore >= 0:
			break
	var span := (f_restore - f_seam) if (f_seam >= 0 and f_restore >= 0) else -1
	_check(f_seam >= 0 and span >= 9 and span <= 24,
			"P5 定格时长读防守方数值域（parry_stun_frames=12 实测冻 %d 拍≥9；魔数 6 世界 ≤8）"
			% span)
	_def.attributes.parry_stun_frames = 6


## 尾部 k 拍恒等（flip 污染只可能发生在头部，尾部连续=冻结稳定段）
func _tail_equal(arr: Array, k: int) -> bool:
	if arr.size() < k:
		return false
	var tail = arr[arr.size() - k]
	for i in range(arr.size() - k, arr.size()):
		if arr[i] != tail:
			return false
	return true


## 腿间卫生（P 流自有版）：双方回待机、旗清零、池补满、清账
func _p_clean() -> void:
	_def.attributes.is_blocking = false
	await _wait_state(_atk2, "Ground/Move/Idle", 600)
	await _wait_state(_def, "Ground/Move/Idle", 600)
	_atk2.attributes.refill_resistance()
	_def.attributes.reset()
	await _frames(2)


# ═══════════ P6 腿：罚站封形（T2 扩权裁决，B4.7 评审实证并入 T3） ═══════════
# 弹反改道后攻击者动画冻结⇒攻击盒停在开窗态，守方可动——踏出再踏回即可
# 二次进窗吃常规支满伤（旧全局暂停门天然免疫，改道新辟暴露面；评审实证
# 无单发去重机制）。处置=罚站同拍把攻击者全部攻击盒 monitorable 关死
# （主刀；形状 disabled 预关仅意图——活 blend 每帧回写，不作证人），
# 解封=角色门面 release_hitboxes()，地面 attack.enter 与空中
# jump-attack.enter 双路同调（C1 判例：单路独占=空袭盒恒静默穿人）。

## P6 主腿（霸体鼠洞形制，spec §2.3 知情条款的暴露面正面化）：攻击方挂
## has_superarmor——弹反反顶的 K 被 apply_knock 归零制吞掉**且不发任何信号**
## ⇒无 hurt 落态，攻击者冻在 attack1 开窗态整窗不脱（T3 实测判例：普通攻击
## 方反顶→Hurt 落态→attack1 节点出活→enable 值轨 reset 在 ~3 拍内自愈关盒，
## "二次进窗满伤"在自愈形制下测不出；自愈缺席的护甲档才是裁决钉的暴露面）。
## 流程：弹反成立（倍速掉 0 且守方血不动）→封形见证（全盒 monitorable 关）→
## 守方解除格挡挪出再挪回→观察段零二次扣血零 hurt 派发（全程攻击者仍冻）。
## R8 对照档 d：摘 _silence_attacker_hitboxes 调用→P6a 永不开=红、
## P6b/P6c 二次进窗满伤=红（两世界差异由护甲档消自愈撑住，腿内自证）。
func _leg_parry_seal() -> void:
	await _p_clean()
	# 加长罚站窗（读同一数值域，P5 已锁）让"封形轮询≤5+挪出 8+挪回 8+观察 14"
	# 全程落在冻期内并留冗余（防恢复协程与观察环同拍竞速抖动）
	_def.attributes.parry_stun_frames = 48
	_atk2.attributes.has_superarmor = true
	_def.attributes.is_blocking = true
	_def.attributes.block_started_frame = Engine.get_physics_frames()
	_atk2.attributes.refill_resistance()
	await _place(_atk2, _def, Vector2(-80, -30))
	_attack(_atk2, Vector2.RIGHT)
	var f_seal := -1
	var d_hp0: float = _def.attributes.health_current
	for _i in 60:
		await get_tree().physics_frame
		_watch_pause()
		if get_tree().paused:
			_paused_seen_p = true
		# hold 重写（P 流惯例）：命中落哪帧都 delta≡1=弹反支
		_def.attributes.block_started_frame = Engine.get_physics_frames()
		if _atk2.anim_time_scale() <= 0.001:
			f_seal = Engine.get_physics_frames()
			break
	if f_seal < 0 or _def.attributes.health_current != d_hp0:
		_check(false, "P6-0 弹反+护甲冻窗未确立（f=%s 守血 %.1f/%.1f，本腿作废）"
				% [f_seal, _def.attributes.health_current, d_hp0])
		_atk2.attributes.has_superarmor = false
		_def.attributes.parry_stun_frames = 6
		return
	# P6a 封形在场证明：攻击者全部攻击盒 ≤5 拍内 monitorable 全关——
	# **形状 disabled 不作证人**（T3 判例：冻结活 blend 每帧回写开窗态，
	# 一次性形状禁用存活 ≤1 拍；封形主刀=零轨道盯防的 monitorable 门）
	var boxes_seen := 0
	var open_lanes := 0
	var sealed_f := -1
	for _i in 5:
		await get_tree().physics_frame
		boxes_seen = 0
		open_lanes = 0
		for hb in _atk2.hitboxes():
			boxes_seen += 1
			if hb.monitorable:
				open_lanes += 1
		if boxes_seen > 0 and open_lanes == 0:
			sealed_f = _i
			break
	_check(boxes_seen > 0 and sealed_f >= 0,
			"P6a 罚站同拍封形：%d 盒在第 %s 拍起 monitorable 全关（活通道 %d）"
			% [boxes_seen, sealed_f, open_lanes])
	# 出窗：守方解除格挡（二次接触按常规支结算=满伤，红世界现形）、挪出触达
	_def.attributes.is_blocking = false
	var contact := _def.global_position
	_def.global_position = contact + Vector2(300, 0)
	await _frames(8)
	_def.global_position = contact
	# 挪回后观察段：全程要求攻击者仍冻（窗口未自然关闭的见证）
	var hp0: float = _def.attributes.health_current
	var hurt_seen := false
	var unfrozen := 0
	for _i in 14:
		await get_tree().physics_frame
		_watch_pause()
		if _atk2.anim_time_scale() > 0.001:
			unfrozen += 1
		if str(_def.state_machine.state_name).contains("Hurt"):
			hurt_seen = true
	_check(_def.attributes.health_current == hp0,
			"P6b 踏出再踏回零二次扣血（%.1f→%.1f，未封形世界此处 -10）"
			% [hp0, _def.attributes.health_current])
	_check(not hurt_seen and unfrozen == 0,
			"P6c 观察段零 hurt 派发且攻击者全程仍罚站（解冻拍 %d/14；" % unfrozen \
			+ "若解冻=封形未生效窗口照走，判据作废）")
	# —— P6d（C1 评审腿）：罚站封形后、地面攻击解救前，先打一发空袭——
	# 旧形制释放只住在地面 attack.enter（QuiverActionJumpAttack 是旁支类），
	# 空袭盒 monitorable 恒 false=该角色空中攻击永久静默穿人。跳攻 enter
	# 必须自带释放（≤6 拍，deferred 落拍裕量）。红档对照 e=摘跳攻释放行。
	_atk2.state_machine.transition_to("Air/Jump/Attack")
	var released := false
	for _i in 6:
		await get_tree().physics_frame
		var all_open := true
		for hb in _atk2.hitboxes():
			if not hb.monitorable:
				all_open = false
		released = all_open and not _atk2.hitboxes().is_empty()
		if released:
			break
	_check(released,
			"P6d 空袭解救：封形后跳攻 enter ≤6 拍全盒 monitorable 回 true"
			+ "（地面独占释放旧形制=本腿红，空袭静默穿人现形）")
	_atk2.state_machine.transition_to("Ground/Move/Idle")
	_atk2.attributes.has_superarmor = false
	_def.attributes.parry_stun_frames = 6
	await _p_clean()


# ═══════════ E 流：接触点特效（T3 R4） × K 流：运行时开关（T3 R5） ═══════════
# 宿主接线（判决 #1 之后追加登记适配波）：controller 已把 HitFx 注册为
# autoload（/root/HitFx）+ hit_fx_toggle（V 键）——E/K 流**单点装配优先复用
# 单例**（双消费者=K2a 假红判例：手建+单例各喷一份且翻旗翻不到生产身），
# 缺席回退手建保旧世界兼容；腿尾开关还原原值。开键端到端归 F5 感官单
# （探针2 判例：headless 动态注册动作喂不饱 is_action_just_pressed 轮询）。
# 特效节点挂在 get_tree().current_scene（=本契约场景根）——扫描/距离/计数
# 全部经 world 坐标直读，无相机数学。裸舞台沉降判例同款装配：同拍摆位→
# _settle_pair 等钉死→每发出拳 _place 重锚。

var _stage_e: Node2D
var _e_actor: QuiverCharacter
var _e_vendor: QuiverCharacter
var _fx  # 无类型=Variant 动态通道（宿主脚本无 class_name 判例，_fx.enabled/toggle 走动态）
var _fx_owned := true         # 登记适配波：true=手建实例（本套自生自灭），false=复用 autoload 单例
var _fx_orig_enabled := true  # 复用单例时的开关原值（腿尾必还原，K 流翻过要回原）
var _landed: Array = []  # 自采 hit_landed 回执（[point, style]），E1/E3/E5 证人


func _flow_fx() -> void:
	if not _guard_actor():
		_finished_e = true
		_finished_k = true
		return
	Events.hit_landed.connect(_on_landed_capture)
	# 登记适配波（controller 已注册 [autoload] HitFx）：**单点装配**——
	# autoload 在场即复用单例，再手建=双消费者各喷一份特效且 K 流翻旗只
	# 翻手建实例（生产单例不受影响，K2a 假红根因，登记后实测一红）；
	# 缺席则回退手建挂树（登记前旧世界兼容，本套零改动）。E 流计数目标
	# 是"场景根下特效节点数"，单消费者形态下两世界同一语义天然正确。
	_fx = get_tree().root.get_node_or_null(^"HitFx")
	_fx_owned = _fx == null
	if _fx_owned:
		_fx = HIT_FX.new()
		add_child(_fx)
	_fx_orig_enabled = bool(_fx.enabled)
	print("FX-GATE: 特效宿主=%s（enabled 原值 %s）"
			% ["复用 /root/HitFx 单例" if not _fx_owned else "手建实例（autoload 缺席）",
			_fx_orig_enabled])
	_stage_e = Node2D.new()
	add_child(_stage_e)
	_e_actor = (load(ACTOR_SCENE) as PackedScene).instantiate()
	_e_vendor = (load(VENDOR) as PackedScene).instantiate()
	# dup 先于入树（H 流病根判例，全流通用）
	_own_attrs(_e_actor)
	_own_attrs(_e_vendor)
	_stage_e.add_child(_e_actor)
	_stage_e.add_child(_e_vendor)
	_e_actor.global_position = Vector2(500, 400)
	_e_vendor.global_position = Vector2(580, 430)
	var settled := await _settle_pair(_e_actor, _e_vendor, 240)
	var ok0: bool = await _wait_state(_e_actor, "Ground/Move/Idle", 120)
	_check(ok0 and settled,
			"E0a 特效舞台装配就绪（沉降毕；超时=漂移，本流时序作废）")
	_e_actor.attributes.hit_slow_anim_pct = TEST_PCT
	_e_actor.attributes.hit_slow_factor = TEST_FACTOR
	await _leg_fx_born()
	await _leg_fx_spell()
	await _leg_fx_whiff()
	await _leg_toggle_form()
	await _leg_toggle_off()
	_drain_sparks()
	# 开关还原原值（复用单例的义务——K 流翻过旗必须回给生产世界）；
	# 手建实例同样还原后自灭，两世界收口一致。
	_fx.enabled = _fx_orig_enabled
	if _fx_owned:
		_fx.queue_free()
	await _frames(4)
	Events.hit_landed.disconnect(_on_landed_capture)
	_stage_e.queue_free()
	_finished_e = true
	_finished_k = true


func _on_landed_capture(point: Vector2, style: StringName, _strength: float, _dir: Vector2) -> void:
	_landed.append([point, style])


## 场景根下特效层扫描（契约运行时 current_scene=本场景根；无 class_name 判例
## →按脚本同一性匹配）
func _spark_nodes() -> Array:
	var host: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	var out: Array = []
	for c in host.get_children():
		if c.get_script() == SPARK_FX:
			out.append(c)
	return out


## 特效排空（fire 卡 lifetime 0.5s=30 拍 @60Hz + 12 拍裕量）
func _drain_sparks() -> void:
	for _i in 45:
		if _spark_nodes().is_empty():
			return
		await get_tree().physics_frame


## 同拍摆位沉降判例的通用版（P 流 _settle 只盯 _def/_atk2，本对另建）
func _settle_pair(a: Node2D, b: Node2D, cap: int) -> bool:
	var pa := Vector2(INF, INF)
	var pb := Vector2(INF, INF)
	for _i in cap:
		await get_tree().physics_frame
		var na: Vector2 = a.global_position
		var nb: Vector2 = b.global_position
		if (na - pa).length() < 0.05 and (nb - pb).length() < 0.05:
			return true
		pa = na
		pb = nb
	return false


## E1/E1b/E1c + E2：近战命中→特效出生贴接触点、default 风格、z=20 夹层；
## 生命周期毕自动清理归零（pct=1.0 极端档二段进窗判例：只认首发回执+首生
## 特效的配对，几何锁 <40px——构造上恒 0，锁的是"没把位置写丢"）
func _leg_fx_born() -> void:
	await _e_clean()
	await _place(_e_vendor, _e_actor, Vector2(80, 30))
	_landed.clear()
	_attack(_e_actor, Vector2.RIGHT)
	var nodes: Array = []
	for _i in 90:
		await get_tree().physics_frame
		nodes = _spark_nodes()
		if not nodes.is_empty():
			break
	var born: bool = not nodes.is_empty() and not _landed.is_empty()
	_check(born, "E1 近战命中→hit_landed 回执在场且特效节点出生（节点 %d）" % nodes.size())
	if born:
		var point: Vector2 = _landed[0][0]
		var dist: float = (nodes[0] as Node2D).global_position.distance_to(point)
		_check(dist < 40.0,
				"E1b 特效贴接触点（回执两盒中点↔节点位 %.1fpx，中点数学未写丢）" % dist)
		_check(_landed[0][1] == &"default" and (nodes[0] as Node2D).z_index == 20,
				"E1c 风格 default（punch1 未配置吃代码默认）+ z=20 夹层（%s / %d）"
				% [_landed[0][1], (nodes[0] as Node2D).z_index])
	else:
		_check(false, "E1b 几何锁缺席跳测（E1 未生特效）")
		_check(false, "E1c 风格/夹层锁缺席跳测（E1 未生特效）")
	await _drain_sparks()
	_check(_spark_nodes().is_empty(),
			"E2 生命周期毕自动清理：场景根特效计数归零（one_shot+尾端 queue_free）")
	await _e_clean()


## E3/E5：真 fire_ball 命中→同样出生（弹体一视同仁）；fire 卡消费经节点
## 属性可证（preset 同一性 + gravity/amount 搬运直读——参数断言不走字符串）
func _leg_fx_spell() -> void:
	await _e_clean()
	await _place(_e_vendor, _e_actor, Vector2(80, 30))
	_landed.clear()
	var spell_scene: PackedScene = load(SPELL_SCENE)
	var spell_def: SpellDefinition = load(SPELL_DEF)
	var ball := spell_scene.instantiate() as SpellBase
	_stage_e.add_child(ball)
	ball.global_position = Vector2(_e_vendor.global_position.x - 160.0, _e_vendor.global_position.y)
	ball.cast(_e_actor, spell_def, Vector2.RIGHT)
	var nodes: Array = []
	for _i in 300:
		await get_tree().physics_frame
		nodes = _spark_nodes()
		if not nodes.is_empty():
			break
	_check(not nodes.is_empty(), "E3 弹体命中同样出生（近战+弹体一视同仁）")
	if nodes.is_empty():
		_check(false, "E5a 风格路由缺席跳测（E3 未生特效）")
		_check(false, "E5b 卡参数缺席跳测（E3 未生特效）")
	else:
		var fx = nodes[0]
		var routed: bool = fx.get("preset") == CARD_FIRE \
				and not _landed.is_empty() and _landed[_landed.size() - 1][1] == &"fire"
		_check(routed,
				"E5a 风格路由：fire_ball 攻击卡 hit_effect_style=fire →吃 fire 卡（回执 %s）"
				% (_landed[_landed.size() - 1][1] if not _landed.is_empty() else "<无>"))
		var parts = fx.get("particles")
		var card_g: Vector2 = CARD_FIRE.gravity
		var card_amt: int = CARD_FIRE.amount
		_check(parts != null and parts.gravity == card_g and parts.amount == card_amt,
				"E5b fire 卡参数经节点属性可证（重力 %s 上浮/粒数 %d 原样搬运）" % [card_g, card_amt])
	if is_instance_valid(ball):
		ball.destroy()
	await _drain_sparks()
	await _e_clean()


## E4：挥空零出生零回执（触发面锁；900px >> 盒宽+车道）
func _leg_fx_whiff() -> void:
	_e_vendor.global_position = _e_actor.global_position + Vector2(900, 30)
	await _frames(6)
	_landed.clear()
	_attack(_e_actor, Vector2.RIGHT)
	var seen := 0
	var done := false
	for _i in 300:
		await get_tree().physics_frame
		seen = maxi(seen, _spark_nodes().size())
		if str(_e_actor.state_machine.state_name) == "Ground/Move/Idle":
			done = true
			break
	_check(done and seen == 0 and _landed.is_empty(),
			"E4 挥空=零特效零回执（收口 %s / 峰值节点 %d / 回执 %d）"
			% [done, seen, _landed.size()])
	await _drain_sparks()
	await _e_clean()


## K1/K1b：toggle() 公开入口翻旗（直改属性等价的语义真身，判决 #1）+
## 开键预铺形制源码锁——"动作缺席零报错零行为、登记后自动通电"三行不许被
## 重构吞掉（controller 接线只需把 InputMap 判定连到 toggle）
func _leg_toggle_form() -> void:
	var before: bool = _fx.enabled
	_fx.toggle()
	var mid: bool = _fx.enabled
	_fx.toggle()
	_check(before != mid and bool(_fx.enabled) == before,
			"K1 toggle() 公开入口翻旗（%s→%s→%s，直改属性等价）" % [before, mid, _fx.enabled])
	var src := FileAccess.get_file_as_string(HIT_FX_PATH)
	# 第三子句收紧（I3 评审）：裸 "toggle()" 被 `func toggle()` 定义行恒真满足，
	# 必须锁"_process 内被调用"的制表缩进现场形（\n\t\t 前缀），否则通电契约没被锁。
	_check(src.contains("InputMap.has_action(&\"hit_fx_toggle\")")
			and src.contains("Input.is_action_just_pressed(\"hit_fx_toggle\")")
			and src.contains("\n\t\ttoggle()"),
			"K1b 开键预铺形制源码锁（has_action 短路+动作判定+_process 内 toggle() 调用现场；" \
			+ "headless 轮询判例→端到端归 F5 单）")


## K2：关闭态命中=零特效节点但慢放照常——视觉/时间双腿独立锁（R5 铁律的
## 结构证明：开关只在 HitFx 回调早退，HurtBox 时间腿根本不知道开关存在）
func _leg_toggle_off() -> void:
	await _place(_e_vendor, _e_actor, Vector2(80, 30))
	_fx.enabled = false
	_landed.clear()
	var v_hp0: float = _e_vendor.attributes.health_current
	_attack(_e_actor, Vector2.RIGHT)
	var seen_fx := 0
	var slow_seen := false
	var hit_seen := false
	for _i in 240:
		await get_tree().physics_frame
		seen_fx = maxi(seen_fx, _spark_nodes().size())
		if _e_actor.anim_time_scale() < 1.0:
			slow_seen = true
		if _e_vendor.attributes.health_current < v_hp0:
			hit_seen = true
		if hit_seen and str(_e_actor.state_machine.state_name) == "Ground/Move/Idle":
			break
	_fx.enabled = _fx_orig_enabled  # 还原原值而非硬置 true（复用单例纪律）
	_check(hit_seen and seen_fx == 0,
			"K2a 关闭态命中零特效节点（命中 %s / 特效峰值 %d——开关只在视觉腿早退）"
			% [hit_seen, seen_fx])
	_check(slow_seen, "K2b 关闭态慢放照常（攻击者倍速掉档可观测——开关不触时间腿）")
	await _e_clean()


## E 流腿间卫生（H 流 _clean 形制）
func _e_clean() -> void:
	await _wait_state(_e_actor, "Ground/Move/Idle", 900)
	await _wait_state(_e_vendor, "Ground/Move/Idle", 900)
	_e_vendor.attributes.reset()
	_e_actor.attributes.refill_resistance()
	await _frames(2)
