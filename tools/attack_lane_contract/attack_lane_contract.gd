extends Node

## 受击车道换轴契约（2026-09-19 上下攻击批）：
## 单元层——CombatSystem 排(Y)/列(X)窗口家族（同一 HitLaneLimits，中心换轴，
## lane_size±hit_lane_offset 语义对称）；
## 行为层——真替身出手（QuiverActionAttack 主轴塌缩 + attributes.skin_direction
## 镜像生命周期）× PASSIVE 站桩小贩（零漂移靶）四方位打点：
## 主权迁移（B2.5 Task4）：出手位从活体 chen 换成矩阵替身 test_actor——
## 车道契约约束的是插件动作层+模板皮肤血统一致的攻击盒，不验 chen 本体内容。
## B1 正北 120px：旧 Y 车道必拒、新 X 车道必中（用户定罪现场=本案主症状）；
## B4 北偏东 100px：列外必拒；B5 正东同排：旧横攻语义回归；B6 东偏北 120px：排外必拒；
## B7-B9（2026-09-20 决策定档批）表现层防"乌龙"断言：命中后防守方必达 Ground/Hurt、
## 皮肤 AnimTree 必落 hurt_high、纵攻受击全程不改写 facing_x——把"纵向受击动画方向 =
## 防守方上一次水平朝向（与上下跳跃同源机制）"从口头共识钉成机器契约。
## H 腿组（S2-B4.6 攻击朝向模式批）：横模（全局默认）出手向=跳跃同源 facing_x 记忆、
## 纵向输入出手"同排可中+邻列免疫"端到端、双模式切换快照生命周期对称、纵站出手
## 不吃零向量退化；B 组纵向机制腿活在四向行为上，按 spec §4 覆写自洁形制就地括弧。
## 运行：godot --headless --path . res://tools/attack_lane_contract/attack_lane_contract.tscn

const Kit := preload("res://tools/matrix_runner/test_actor_kit.gd")
const ACTOR_SCENE := Kit.ACTOR_SCENE
const VENDOR := "res://characters/neutrals/street_vendor/street_vendor.tscn"

var _fails := 0
var _finished := false


func _ready() -> void:
	await _flow()
	_check(_finished, "全序列执行完成（协程静默中断防线）")
	print("════════ attack-lane-contract: %s ════════" % ("PASS" if _fails == 0 else "FAIL"))
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		_fails += 1
	print("  %s: %s" % ["PASS" if ok else "FAIL", label])


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


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


## raw 键注入（block_parry T2 判例形制：down/up 同构造、pressed 显式写、
## keycode+physical 双填）——H2 正上行走走 OS 同款输入链
func _press_key(p_key: int, p_pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.device = -1
	ev.keycode = p_key
	ev.physical_keycode = p_key
	ev.pressed = p_pressed
	Input.parse_input_event(ev)


# ── 攻击朝向模式覆写自洁（S2-B4.6 spec §4 形制）──────────────────────────────
# 纵向机制腿活在四向行为上：腿组开覆写 FOUR_DIRECTION、腿组尾还原覆写前原值
# （成对括弧纪律，参 QuiverActionBlock 生命周期旗的 enter/exit 写形）。
# 禁改 test_actor 落盘 tres"修"契约（生成物+共享替身，plan 红线）。
# 【红相申报】本组辅助首版（red_h.log 取证时）走 Object.set/get 动态形制——
# 旧运行时字段缺席时 get 静默 null、set 静默 no-op，红只落在 H 腿值面；
# 运行时枚举行落地后切换为本 typed 直写形制（探针判例档 b46_t0/probe_dyn）。

## 纵向机制腿组开：覆写为四向档，返回覆写前原值供腿尾 _restore_axis（成对括弧）
func _use_4dir(actor: QuiverCharacter) -> int:
	var prev: int = actor.attributes.attack_axis_mode
	actor.attributes.attack_axis_mode = QuiverAttributes.AttackAxisMode.FOUR_DIRECTION
	return prev


## 纵向机制腿组尾：还原覆写前原值（括弧收口，防覆写泄漏串腿）
func _restore_axis(actor: QuiverCharacter, prev: int) -> void:
	actor.attributes.attack_axis_mode = prev
	# 评审 LOW#1 补强（非新缺陷、绿即过）：括弧收口必含"还原到位"自证——
	# 未来字段改名/写点漂移会让上面的还原行静默失联，此处响亮拦截
	_check(actor.attributes.attack_axis_mode == prev,
			"axis 括弧收口：还原后=%d（实得 %d）" % [prev, actor.attributes.attack_axis_mode])


func _place(vendor: QuiverCharacter, actor: QuiverCharacter, offset: Vector2) -> void:
	vendor.global_position = actor.global_position + offset
	await _frames(6)


func _reset_target(vendor: QuiverCharacter) -> void:
	vendor.attributes.reset()
	await _wait_state(vendor, "Ground/Move/Idle", 600)


func _flow() -> void:
	# ———— 单元层：车道窗口家族的轴无关构造（无角色依赖，缺席态也能跑）————
	var def := QuiverAttributes.new()
	def.ground_level = 200.0
	var atk := QuiverAttributes.new()
	atk.ground_level = 320.0
	_check(not CombatSystem.is_in_same_lane_as(def, atk),
			"L1 排窗口旧语义：Δy=120 出 60 窗 → 拒（病根现状钉死）")
	atk.ground_level = 240.0
	_check(CombatSystem.is_in_same_lane_as(def, atk), "L2 排窗口：Δy=40 窗内 → 收")
	_check(CombatSystem.is_in_same_column_as(def, atk, 500.0, 505.0),
			"L3 列窗口：同列 Δx=5 → 收")
	_check(not CombatSystem.is_in_same_column_as(def, atk, 500.0, 700.0),
			"L4 列窗口：Δx=200 → 拒")
	def.hit_lane_offset = -30
	_check(CombatSystem.is_in_same_column_as(def, atk, 500.0, 520.0)
			and not CombatSystem.is_in_same_column_as(def, atk, 500.0, 545.0),
			"L5 缩窗 offset=-30：列窗收至 [470,530]")
	def.hit_lane_offset = 0

	# ———— 行为层：真角色入场（替身只读守卫先行）————
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
	_check(ok0 and str(vendor.state_machine.state_name) != "", "B0 替身/小贩入场就绪")
	_check(actor.attributes.skin_direction == Vector2.ZERO,
			"B0b 待机镜像=零向量（非出手态旧语义护城河）")

	# ════ H0 产线出生档自证（S2-B4.6 T1 移交补强）════
	# test_actor 每轮经矩阵 destroy 先行 → CharacterCreator 真产线重建：运行值=
	# 横模 且 tres 合成行在场，两点合读证明档位来自"面板合成器落盘"而非
	# "字段缺席代码兜底"（单查运行值两种来源皆 1=假绿通道）。旧 tres 缺行会红，
	# 处方=bash tools/matrix_runner/run_matrix.sh --ensure-only 重建后再跑
	var actor_attrs_text := FileAccess.get_file_as_string(
			Kit.ACTOR_DIR + "/resources/test_actor_attributes.tres")
	_check(actor.attributes.attack_axis_mode == QuiverAttributes.AttackAxisMode.HORIZONTAL_ONLY
			and actor_attrs_text.contains("\nattack_axis_mode = 1\n"),
			"H0 替身出生=横模且 tres 有合成行（产线通道自证）")

	# ════ H 腿组（S2-B4.6）：横模语义 + 跳跃同源直证（默认档，先红后绿）════
	# H1 横模+面向正上：skin_direction=UP 出手，快照恰 (-1,0)=facing_x 记忆
	# （旧代码无本旗、主轴塌缩出 (0,-1) 纵快照——本条即 R8 定罪红据）
	actor._skin.facing_x = -1.0
	_attack(actor, Vector2.UP)
	_check(actor.attributes.skin_direction.is_equal_approx(Vector2(-1, 0)),
			"H1 横模 UP 输入出手快照=(-1,0)（facing_x 记忆，实际 %s）"
			% actor.attributes.skin_direction)
	_check(await _wait_state(actor, "Ground/Move/Idle", 600), "H1z 出手窗结束回 Idle")

	# H2 跳跃同源直证：raw W 注入正上行走全程（输入 x=0）——facing_x 记忆
	# 不动（locomotion:88-90 规则原文锁），纵向上行中出手=上一次左右向横拳。
	# 对照腿：出手前记录 facing_x，出手后快照 x==facing_x 且 y==0。
	var fx0: float = actor._skin.facing_x  # 承 H1 的 -1.0
	_press_key(KEY_W, true)
	var walked_up := false
	for _i in 60:
		await get_tree().physics_frame
		if actor.global_position.y < 399.0 \
				and actor._skin.skin_direction.is_equal_approx(Vector2.UP):
			walked_up = true
			break
	_check(walked_up, "H2a 正上行走成立（位置北移+皮肤纵向 UP，raw 键全链路）")
	_check(actor._skin.facing_x == fx0,
			"H2b 正上行走全程不改写左右记忆（facing_x 恒 %.0f）" % fx0)
	_press_key(KEY_W, false)
	_check(await _wait_state(actor, "Ground/Move/Idle", 120), "H2w 松键回 Idle")
	_attack(actor, Vector2.UP)
	_check(actor.attributes.skin_direction.is_equal_approx(Vector2(fx0, 0))
			and absf(actor.attributes.skin_direction.y) < 0.01,
			"H2c 纵向上行后出手=同向横拳（快照 x=facing_x=%.0f 且 y=0，实际 %s）"
			% [fx0, actor.attributes.skin_direction])
	_check(await _wait_state(actor, "Ground/Move/Idle", 600), "H2z 出手窗结束回 Idle")

	# H3 端到端（复用 B 组摆位骨架）：横模纵向输入出手——同排可中 + 邻列免疫
	# 成对钉"列比对形迹为零"（若快照仍纵向：H3a 列比 Δx=80 出窗必红、
	# H3b 列比 Δx=0 必中撞不中判据——两腿双世界互斥，无一假绿）
	actor._skin.facing_x = 1.0  # 夹具定向东：出手向=记忆值，与下面的纵向输入无关
	await _place(vendor, actor, Vector2(80, 30))
	var hp_h3: float = vendor.attributes.health_current
	_attack(actor, Vector2.UP)
	var hit_h3a: bool = await _watch_hit(vendor, hp_h3, 240)
	_check(hit_h3a, "H3a 横模纵输入出手同排可中（排比 Δy=30 收；旧纵快照列比拒——红）")
	_check(await _wait_state(actor, "Ground/Move/Idle", 600), "H3az 出手窗结束回 Idle")
	await _reset_target(vendor)
	await _place(vendor, actor, Vector2(0, -120))
	var hp_h3b: float = vendor.attributes.health_current
	_attack(actor, Vector2.UP)
	_check(await _wait_state(actor, "Ground/Move/Idle", 600), "H3bz 出手窗结束回 Idle")
	_check(vendor.attributes.health_current >= hp_h3b,
			"H3b 横模纵输入出手邻列免疫（排比 Δy=120 拒；旧纵快照列比必中——红）")
	await _reset_target(vendor)

	# H4 切换无残影：同角色先后两模式各出手，快照生命周期对称
	# （横档快照=(facing,0)、四向档=(0,-1)，exit 归零两档共用零特判）
	await _place(vendor, actor, Vector2(600, 400))  # 撤离靶位，免命中定格干扰
	_attack(actor, Vector2.UP)
	_check(actor.attributes.skin_direction.is_equal_approx(Vector2(1, 0)),
			"H4a 横模出手快照=(1,0)（切换前模式）")
	_check(await _wait_state(actor, "Ground/Move/Idle", 600), "H4b 横模出手窗结束回 Idle")
	_check(actor.attributes.skin_direction == Vector2.ZERO,
			"H4b' 横模 exit 镜像归零（生命周期成对）")
	var prev_axis := _use_4dir(actor)
	_attack(actor, Vector2.UP)
	_check(actor.attributes.skin_direction.is_equal_approx(Vector2(0, -1)),
			"H4c 四向模式出手快照=(0,-1)（切换零残影，实际 %s）"
			% actor.attributes.skin_direction)
	_check(await _wait_state(actor, "Ground/Move/Idle", 600), "H4d 四向出手窗结束回 Idle")
	_check(actor.attributes.skin_direction == Vector2.ZERO,
			"H4d' 四向 exit 镜像同形归零（两档对称）")
	_restore_axis(actor, prev_axis)

	# H5 纵向上站立静止（无移动输入）出手：吃 facing_x 现值（=1 右），
	# 恒出横快照不塌成零向量（零镜像=非出手态暗号，绝不能被出招态写出）
	actor._skin.skin_direction = Vector2.UP
	_attack(actor, Vector2.UP)
	_check(actor.attributes.skin_direction.is_equal_approx(Vector2(1, 0)),
			"H5 纵向上静止出手=(facing_x,0) 不退化零快照（实际 %s）"
			% actor.attributes.skin_direction)
	_check(await _wait_state(actor, "Ground/Move/Idle", 600), "H5z 出手窗结束回 Idle")

	# ———— H 组收场：回 B 组初始摆位（B1 依赖绝对摆位骨架，H2 位移须归零）————
	actor.velocity = Vector2.ZERO
	actor.global_position = Vector2(500, 400)
	vendor.global_position = Vector2(500, 280)
	await _frames(6)
	var vendor_back := await _wait_state(vendor, "Ground/Move/Idle", 120)
	_check(await _wait_state(actor, "Ground/Move/Idle", 120) and vendor_back,
			"Hz H 组收场：出手位/靶位回 Idle 就位（B 组摆位骨架复原）")

	# B1/B2/B3/B7/B8/B9 正北 120px → 纵攻必中 + 镜像生命周期 + 表现层断言组。
	# B9 决策锁：受击/击飞处理永不写防守方面向（动画走上一次水平朝向，同纵跳机制）
	# ——未来若有人实现"北来→强制 right"类映射，会先撞红本条。
	# [覆写自洁 spec §4] 本腿组（B1..B4 含比列家族）是纵向机制覆盖：活在四向
	# 行为上，腿组前覆写 FOUR_DIRECTION、腿组尾还原——机制与角色配置解耦。
	var prev_axis_b := _use_4dir(actor)
	vendor._skin.facing_x = -1.0
	_attack(actor, Vector2.UP)
	# 精确 == 会死于 from_angle(±90°) 的 6e-17 浮点 eps（B2 首跑实锤）：用近似
	_check(actor.attributes.skin_direction.is_equal_approx(Vector2(0, -1)),
			"B2 出手镜像=主轴塌缩快照 (0,-1)（近似比，%s）"
			% actor.attributes.skin_direction)
	var seen := await _watch_visual(vendor, vendor.attributes.health_current, 240)
	_check(seen.hit, "B1 正北 120px 上攻击中（换轴主症状；旧代码必挂）")
	_check(seen.hurt_state, "B7 命中后防守方状态机必达 Ground/Hurt（防乌龙断言）")
	_check(seen.hurt_anim, "B8 皮肤 AnimTree 当前节点必落 hurt_high（punch1 hurt_type=HIGH）")
	if not seen.hurt_anim:
		var pb = vendor._skin._playback
		print("[att-lane] B8 诊断 current_node=%s" % (
				str(pb.get_current_node()) if pb != null else "<playback 空>"))
	_check(vendor._skin.facing_x == -1.0,
			"B9 纵攻受击全程不改写 facing_x（方向=上次水平朝向，决策定档锁）")
	_check(await _wait_state(actor, "Ground/Move/Idle", 600), "B3a 出手窗结束后回 Idle")
	_check(actor.attributes.skin_direction == Vector2.ZERO,
			"B3 出手窗出 → 镜像归零（生命周期成对）")

	# B4 北偏东 100px → 列外必拒
	await _reset_target(vendor)
	await _place(vendor, actor, Vector2(100, -120))
	var hp4: float = vendor.attributes.health_current
	_attack(actor, Vector2.UP)
	await _wait_state(actor, "Ground/Move/Idle", 600)
	_check(vendor.attributes.health_current >= hp4,
			"B4 北偏东 100px 上攻不中（列窗 60 拒，%.0f）" % vendor.attributes.health_current)
	_restore_axis(actor, prev_axis_b)  # 括弧收口：B1..B4 四向覆写到此为止

	# B5 正东 80px 南偏 30（排内）→ 横攻回归。横模（全局默认）腿不括弧：
	# 出手向=facing_x 记忆，夹具显式定向东钉死快照 (1,0) 与旧塌缩同形
	await _reset_target(vendor)
	await _place(vendor, actor, Vector2(80, 30))
	hp4 = vendor.attributes.health_current
	actor._skin.facing_x = 1.0  # 横模夹具：出手向=记忆，定向东钉死 (1,0)
	_attack(actor, Vector2.RIGHT)
	_check(actor.attributes.skin_direction.is_equal_approx(Vector2(1, 0)),
			"B5a 横攻镜像=(1,0)（选轴判据走旧 Y 分支）")
	var hit_east: bool = await _watch_hit(vendor, hp4, 240)
	_check(hit_east, "B5 正东同排打中（横攻旧语义零扰动回归锁）")
	await _wait_state(actor, "Ground/Move/Idle", 600)

	# B6 东偏北 120px → 排外必拒（行为级锁）
	await _reset_target(vendor)
	await _place(vendor, actor, Vector2(80, -120))
	hp4 = vendor.attributes.health_current
	_attack(actor, Vector2.RIGHT)
	await _wait_state(actor, "Ground/Move/Idle", 600)
	_check(vendor.attributes.health_current >= hp4,
			"B6 东偏北 120px 横攻不中（排窗 60 拒/几何不达双保险）")
	await _reset_target(vendor)

	_finished = true
