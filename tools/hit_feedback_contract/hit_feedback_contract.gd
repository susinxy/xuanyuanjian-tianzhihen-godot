extends Node

## S2-B4.7 命中反馈契约（T1 首版：S 流静态 + H 流慢放）。
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
## 观测通道判例（T0/T1 探针实锤，4.7.1，§17.1）：AnimTree 驱动下
## player.get_current_animation()/position 族恒空/报错，动画长度经
## playback 当前状态→states/<名>/node→blend_point_N 就近点→"库/名"全名
## 查库；倍速观测=QuiverCharacter.anim_time_scale() 门面→皮肤路由
## （树驱动读 AnimationNodeTimeScale 参数、直驱读 player.speed_scale）。
##
## 测试主权法（B2.5）：只读消费 test_actor（peek() 三态守卫，缺席打处方红
## 绝不代 runner 创建）。落盘卫生（B4.5）：_ready 首行重定向套内 scratch，
## 套尾删净。共享 attributes 判例：全部角色实例 dup 后 root+skin 双写，
## **且必须先于入树**（本套 H5 零命中悬案病根：入树后换账=动作状态缓存原
## tres、受击盒拿 dup，ground_level 记账分家致车道中心漂移）。
## 时序断言全部从"测试内实测动画长×档案 pct"折算，不硬编码 ms。
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

## 测试档案装配用的慢放档（非生产默认值！生产默认 0.2/0.15 由 S0 静态腿
## 锁住）：pct=1.0 把窗口放大到整个攻击动画，使"生效→恢复"两拍在
## test_actor 占位攻长（探针实测 ~100ms）下仍有可观测帧距。
const TEST_PCT := 1.0
const TEST_FACTOR := 0.2
const TEST_FACTOR_STRETCH := 0.05

var _fails := 0
var _finished_s := false
var _finished_h := false
var _paused_seen := false


func _ready() -> void:
	# B4.5 落盘卫生条款：影子落盘重定向套内 scratch，永不碰生产槽
	get_node_or_null(^"/root/SaveSystem").slot_path = "user://b47_hf_scratch.json"
	await _flow_static()
	_check(_finished_s, "S 流全序列执行完成（协程静默中断防线）")
	await _flow_melee()
	_check(_finished_h, "H 流全序列执行完成（协程静默中断防线）")
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
