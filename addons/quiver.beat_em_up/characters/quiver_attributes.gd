class_name QuiverAttributes
extends Resource

## Resource to store characters or other objects attributes.
##
## The purpose of this is to separate Data from Animations/Behavior/Feedback as much as possible.
## When two characters are fighting we want the Character Scenes worry about the "how" while
## the data resources will take of the "what", and will be able to guide the scenes. 
## [br][br]
## It is also easier to pass resources around than nodes, or node references. So for example,
## with resources a HitBox that is nested deeply on character skin to follow it's animation can
## collide with a deeply nested HurtBox of another charater and they can just trade attribute
## resources to resolve the damage, and the resource will notify the appropriate node.
## [br][br]
## It is a more modular way of architecturing the game, where you can use the best of nodes
## and node hierarchies without worrying about complex structures making your life harder as
## the most important logic can happen between simple resources.

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

signal health_changed
signal health_depleted
signal mana_changed
signal mana_depleted
signal hurt_requested(knockback: QuiverKnockbackData)
signal knockout_requested(knockback: QuiverKnockbackData)
## 撞墙反弹（2026-09-19 终案）：携带被撞那面墙的镜像轴（WallHitBox.mirror_axis），
## 击飞链据此对速度做真镜像；仅击飞链内有此事件（in_knockout 门在受击盒侧）。
signal wall_bounced(mirror_axis: Vector2)
signal grab_requested(grabbed_character: QuiverAttributes)
signal grab_released
signal grabbed(ground_level: float)
signal grab_denied

#--- enums ----------------------------------------------------------------------------------------

## 地面攻击朝向模式（S2-B4.6）：FOUR_DIRECTION=现行主轴塌缩四向档；
## HORIZONTAL_ONLY=出手向恒取 facing_x 水平记忆（与跳跃同源，spec §2.2 分流）。
enum AttackAxisMode { FOUR_DIRECTION, HORIZONTAL_ONLY }

#--- constants ------------------------------------------------------------------------------------

## 起飞保底冲量（统一模型 2026-09-18）：任何击飞的最小初速度，
## 语义=保证击飞链状态机不踩空（绊倒也要完整走完 起飞→弹地→起身）。
const LAUNCH_MIN_IMPULSE := 50.0

#--- public variables - order: export > normal var > onready --------------------------------------

@export_group("Display")
@export var display_name := ""
@export var profile_texture: Texture2D = null
@export var life_bar_gradient := GradientTexture1D.new()

@export_group("Base Stats")
## Max health for the character, when their life bar is full.
@export_range(0, 1, 1, "or_greater") var health_max := 100

## Max mana for the character (spell casting resource).
@export_range(0, 1, 1, "or_greater") var mana_max := 100

## 抗击打上限 R（统一模型）：招式击打值先从本额度扣减，扣穿即击飞；
## 回气（回到移动/落地）时回满。每角色独立定价（小兵低、精英高）。
@export_range(0, 0, 1, "or_greater") var knockout_resistance_max := 600.0

## Max movement speed for the character (also used as Run speed).
@export_range(0, 1000, 1, "or_greater") var move_speed := 600

## Walk speed for the character. When the "walk" input is held, the character
## moves at this speed instead of move_speed. Independent from move_speed, each
## character can configure its own walk/run speeds.
@export_range(0, 1000, 1, "or_greater") var walk_speed := 300

## Max influence for player controlled movement on air.
## If 1.0 player's will be able to freely control character's direction on air, just as on the
## ground, and at 0.0 player input will have no influence on a character's air trajectory.
@export_range(0.0, 1.0, 0.01, "or_greater") var air_control := 0.6

## Character's jump force. The heavier the character more jump force they'll need to reach the
## same jump height as a lighter character.
@export_range(0, 0, 1, "or_less") var jump_force := -1200

## 击飞权重（受击方体质）：起飞冲量的全局乘数，>1 飞更远、<1 飞更近。
## 本字段为属性手填值（原『动画首帧 speed_X 标注自动设置』的说法失实，
## 该机制从未存在，2026-09-18 注释诚实化）；动态增减走 add_modifier 通道。
@export_range(0.0, 10.0, 0.1, "or_greater") var knockback_weight := 1.0

## If you need to make the hit lanes broader or narrower for a specifi character you can use
## this property. Positive values will add to the default hit lane size defined in the Project
## Setting, while negative values will subtract from it. 
## [br][br]
## Note that the hit lane size is how many pixels the character should still be able to receive
## a hit from, so a value of 60 for example, means that they will be hurt by any attacks 
## from another character whose base is between 60 pixels above or 60 pixels below 
## this character's y position.
@export var hit_lane_offset := 0

@export_group("Modifiers")
## This can be toggled on or off in animations to create invincibility frames.
@export var is_invulnerable := false

## This can be toggled on or off in animations to create animations that can't be interrupted
## but still should allow damage to be received.
## 霸体=击打值完全无效（统一模型 G2 归零制，见 apply_knock）。
@export var has_superarmor := false

@export var can_be_grabbed := true

## 弹反窗物理帧数（盾反批 B3）：格挡开局后严格 delta < 本值 的打击判弹反。
## 受管字段单写者纪律：入册（首个修饰捕获 base）后只准走修饰 API，
## 裸写=重算锚漂移（执行手段同 _modifier_bases 处注释）。
@export var parry_window_frames: int = 6

## 格挡伤害系数（盾反批 B3）：Block 态受击的结算伤害=原伤害×本值。受管同上。
@export var block_damage_ratio: float = 0.4

## 自身输出乘算（盾反批 B3）：本角色出招伤害的全局乘数，
## 护人态等增益以修饰表达而非裸写。受管同上。
@export var attack_output: float = 1.0

@export_group("Behavior")
## 地面攻击朝向模式（行为路由设置，单写者=创建面板/Inspector；只读不进修饰域，
## reset() 不清——它是档案配置非运行时状态。合法旗论证见 spec §5）。
## 代码默认=横向：一切无本字段的既有 tres（chen/spar/vendor/模板）加载即横，
## 零迁移（S2-B4.6 用户裁决②）。
@export var attack_axis_mode: AttackAxisMode = AttackAxisMode.HORIZONTAL_ONLY

## Character's current health. What the health bar will be showing.
var health_current := health_max:
	set=_set_health_current

## Character's current mana. Used for spell casting.
var mana_current := mana_max:
	set=_set_mana_current

## 运行时抗击打余量 R_current（apply_knock 扣减/破线清零/refill_resistance 回满）。
var resistance_current := 0.0

## 击飞链生命周期旗（弹墙豁免门的唯一判据，2026-09-19 状态门定档）：
## 击飞链父状态 QuiverActionAirKnockout 的 enter/exit 是唯一写入者
## （与 _launch_count 同括弧，天然成对）；受击盒用它决定"现在撞墙是否
## 结算弹墙"。墙不再是阵营（皮肤上的 area2d:wall 组与墙盒挂组同批退役），
## 走路贴墙免结算由本旗默认 false 保证。
var in_knockout := false

## 出手方向镜像（2026-09-19 车道换轴批）：QuiverActionAttack.enter 在主轴塌缩后
## 把皮肤 skin_direction 的快照写到这里，exit/中断清零。受击车道据此选比较轴：
## 横攻比双方"排"（Y/ground_level），纵攻比双方"列"（X，is_in_same_column_as）。
## 零向量=当前非已出手态（空攻/法术/抓取/待机恒零，旧 Y 语义零扰动）。
var skin_direction := Vector2.ZERO

## 格挡状态闸门（盾反批 B3，非数值不进 tres）：Block 姿态状态的 enter/exit
## 是唯一写入者（与 in_knockout 同款生命周期旗），判定缝据此分流结算。
var is_blocking: bool = false

## 弹反窗时基（盾反批 B3）：进入 Block 当帧的 Engine.get_physics_frames() 读数，
## 判定缝比较 当前帧 − 本值 < parry_window_frames（严格小于）。
## 与 is_blocking 成对写入（同 enter/exit 括弧）。
var block_started_frame: int = 0

## This character's current y value that represents their current ground level.
var ground_level := 0.0

var character_node: QuiverCharacter = null
var grabbed_offset: Marker2D = null

# Modifier system for buffs/debuffs
var _modifier_records: Array[Dictionary] = []
## 方式 B′（2026-09-23 手术）配套账本：attribute → {value: float, is_int: bool}。
## base 只在该属性**首个修饰到来时**捕获一次（此后重算永远以此为锚，不再读现场值），
## 摘除/清账均回写到锚上——旧方式 B 的"入册即抄走当时的被污染值"踩踏链从此断根。
## 受管字段单写者纪律：属性入册（首个修饰捕获 base）后只准走修饰 API，
## 裸写=重算锚漂移（现行执行手段为本注释+契约哨兵，运行时守卫按 plan 从简未建；
## AGENTS 立法随 T6 落条目）。
var _modifier_bases := {}

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _init() -> void:
	resistance_current = knockout_resistance_max
	QuiverEditorHelper.connect_between(Events.characters_reseted, reset)


func _to_string() -> String:
	var dict = {
		resource_path = resource_path,
		grabbed_offset = grabbed_offset.get_path() if grabbed_offset != null else "none",
		ground_level = ground_level,
	}
	return "QuiverAttributes: %s"%[JSON.stringify(dict, "\t")]

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## 击飞统一结算——整套规则的唯一判定点（2026-09-18 统一模型，档位表退役）。
## 入参为招式击打值 K，返回 {launched, impulse, swallow}，由
## [method CombatSystem.apply_knockback] 按结果分发信号：
## · 无敌/霸体：击打值完全无效（霸体归零制——不扣额度、不播受击）；
## · 死亡：绕过抗击打强制起飞，冲量 = K + 保底（G4）；
## · 空中（含弹跳阶段，is_on_air=true）：额度视作已空，冲量 = K + 保底；
##   K≤0 的零击打值攻击不打断弹道（swallow，G5 火球穿身案）；
## · 地面：K ≥ 余量 → 破线起飞，冲量 =（K − 余量）+ 保底，余量清空；
##   K < 余量 → 受击硬直，余量扣减。
func apply_knock(knock_value: float) -> Dictionary:
	if is_invulnerable:
		# 无敌自守保留：绕过 CombatSystem 的直调者（测试/工具）防线
		return {launched = false, impulse = 0.0, swallow = false}
	if has_superarmor:
		# 霸体=交易整体作废走 swallow（2026-09-18 毛边整理：旧形态是这里判
		# "不起飞"+分发器 elif 再判"不播受击"，同一问题两处答案；现语义自含）
		return {launched = false, impulse = 0.0, swallow = true}
	if not is_alive():
		return {launched = true, impulse = knock_value + LAUNCH_MIN_IMPULSE, swallow = false}
	var on_air: bool = character_node != null and character_node.is_on_air
	if on_air:
		if knock_value <= 0.0:
			return {launched = false, impulse = 0.0, swallow = true}
		return {launched = true, impulse = knock_value + LAUNCH_MIN_IMPULSE, swallow = false}
	if knock_value >= resistance_current:
		var impulse := knock_value - resistance_current + LAUNCH_MIN_IMPULSE
		resistance_current = 0.0
		return {launched = true, impulse = impulse, swallow = false}
	resistance_current = maxf(0.0, resistance_current - knock_value)
	return {launched = false, impulse = 0.0, swallow = false}


## 抗击打回满（回气）。额度上限的瞬时变化（法术增益走修饰器改
## knockout_resistance_max）在下一次回满时生效，不追溯半途余量。
func refill_resistance() -> void:
	resistance_current = maxf(0.0, knockout_resistance_max)


## Returns the character's current health as percentage.
func get_health_as_percentage() -> float:
	var value := health_current / float(health_max)
	return value


## 车道窗口工厂：默认以 ground_level（"排"）为中心；纵攻换轴判定传 p_center
## 覆盖（此时语义是"列"中心 x，见 CombatSystem.is_in_same_column_as）。
func get_hit_lane_limits(p_center: float = INF) -> HitLaneLimits:
	var center: float = ground_level if is_inf(p_center) else p_center
	var limits = HitLaneLimits.new(hit_lane_offset, center)
	return limits


func is_alive() -> bool:
	return get_health_as_percentage() > 0


func reset() -> void:
	health_current = health_max
	refill_resistance()
	is_invulnerable = false
	has_superarmor = false
	can_be_grabbed = true
	in_knockout = false
	skin_direction = Vector2.ZERO
	is_blocking = false
	block_started_frame = 0
	# 清账判据（2026-09-23 B′ 手术）：护人/locomotion 等修饰不跨死亡——
	# reset 一律作废全部记录并还原 base，防止上一命的增益/减速尸体泄漏到下世。
	_clear_all_modifiers()

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _set_health_current(value: int) -> void:
	var has_changed = value != health_current
	health_current = clamp(value, 0, health_max)
	if has_changed:
		if health_current > 0:
			health_changed.emit()
		else:
			health_depleted.emit()

func _set_mana_current(value: float) -> void:
	var has_changed = value != mana_current
	mana_current = clamp(value, 0.0, float(mana_max))
	if has_changed:
		if mana_current > 0:
			mana_changed.emit()
		else:
			mana_depleted.emit()

### Public Methods --------------------------------------------------------------------------------

## 属性修饰器三件套（公开签名自法术时代起逐字未动，调用方零改动=宪法）。
## 设计源流：docs/SPELL_SYSTEM_DESIGN.md §11.1 定案的"方式 B"（记录 base_value、
## 添加即裸改、移除写回记录值）——本实现升级为**方式 B′**：属性值永远是
## "base+Σ加"×"Π乘"的**重算回写**（读路径零改动）；base 只在该属性首个修饰
## 到来时捕获一次。叠挂踩踏、乱序摘除踩踏、跨 reset 尸体账三类旧世界风险
## 在结构上不可能（回归锁 tools/block_parry_contract M 流）。
func add_modifier(mod_id: StringName, attribute: StringName, type: String, value: float, source: Node = null) -> void:
	if type != "add" and type != "multiply":
		push_warning("未知修饰操作型: %s（%s→%s 被拒）" % [type, mod_id, attribute])
		return
	remove_modifier(mod_id)   # 同 id 刷新=替换（M3），杜绝叠乘踩踏
	if not _modifier_bases.has(attribute):
		# is_int 必须在任何改动之前从现场类型捕获（move_speed 等 int 型 @export
		# 回写走 roundi，防类型漂移）
		_modifier_bases[attribute] = {
			"value": float(get(attribute)),
			"is_int": typeof(get(attribute)) == TYPE_INT,
		}
	_modifier_records.append({
		"id": mod_id,
		"attribute": attribute,
		"type": type,
		"value": value,
		"source": source,
	})
	_recompute(attribute)


func remove_modifier(mod_id: StringName) -> void:
	for i in range(_modifier_records.size() - 1, -1, -1):
		if StringName(_modifier_records[i]["id"]) == mod_id:
			var attr: StringName = _modifier_records[i]["attribute"]
			_modifier_records.remove_at(i)
			_recompute(attr)
			return   # id 唯一（add 已强制），摘一个就够


func remove_modifiers_from_source(source: Node) -> void:
	var touched := {}
	for i in range(_modifier_records.size() - 1, -1, -1):
		if _modifier_records[i]["source"] == source:
			var attr: StringName = _modifier_records[i]["attribute"]
			_modifier_records.remove_at(i)
			touched[attr] = true
	for attr in touched:
		_recompute(attr)


## 展示用快照，非第二真相（B3 dock 账本）：逐条深拷贝全部在册修饰记录，
## 外部读改不回流 _modifier_records；写入仍只认修饰 API（单写者纪律）。
func modifier_snapshot() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in _modifier_records:
		out.append((r as Dictionary).duplicate(true))
	return out


### Private Methods --------------------------------------------------------------------------------

## 单一重算点：属性值=按全部在册修饰重算的回写结果，永不读现场值做增量。
func _recompute(attribute: StringName) -> void:
	var base_d: Dictionary = _modifier_bases.get(attribute, {})
	if base_d.is_empty():
		return
	var sum := 0.0
	var prod := 1.0
	for r in _modifier_records:
		if r["attribute"] == attribute:
			if r["type"] == "add":
				sum += float(r["value"])
			else:
				prod *= float(r["value"])
	var out: float = (float(base_d["value"]) + sum) * prod
	set(attribute, roundi(out) if base_d["is_int"] else out)


## 清账（reset 与死亡重跑共用）：全记录作废+受管属性回 base。
func _clear_all_modifiers() -> void:
	var bases := _modifier_bases.duplicate(true)   # 先快照（回写要读表，防清序陷阱）
	_modifier_records.clear()
	_modifier_bases.clear()
	for attr in bases:
		var base_d: Dictionary = bases[attr]
		set(attr, roundi(float(base_d["value"])) if base_d["is_int"] else float(base_d["value"]))

### -----------------------------------------------------------------------------------------------

class HitLaneLimits:
	extends RefCounted
	
	var lane_size: int = ProjectSettings.get_setting(QuiverBeatEmUpPlugin.SETTINGS_DEFAULT_HIT_LANE_SIZE)
	
	var upper_limit := 0
	var lower_limit := 0
	
	## 对轴无感：p_center 传 y 即"排"窗口、传 x 即"列"窗口（车道换轴复用同一家族）
	func _init(p_increment, p_center):
		upper_limit = p_center - lane_size - p_increment
		lower_limit = p_center + lane_size + p_increment
	
	
	func is_value_inside_lane(y_position: float) -> bool:
		var value := y_position >= upper_limit and y_position <= lower_limit
		return value
