@tool
class_name QuiverHurtBox
extends Area2D

## Write your doc string for this file here

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

## 阵营过滤前缀：同一 area2d: 组的双方视为同阵营，攻击不造成伤害
const FACTION_PREFIX = "area2d:"

## ── 判定缝规则常量（S2-B3 spec §4 第 2 档：单一出处，禁散落魔数）────────────
## 弹反顶硬击打值 K：打进攻击者自己的抗击打池，走统一弹退模型（无新机制）。
const _PARRY_STUN_KNOCK := 60.0
## 弹反加强定格帧数。**必须自发拍**：免伤路不经 apply_damage_value，现行唯一
## 生产定格调用发生在扣血处——遗忘本拍=静默无反馈假绿族（spec §10 警条）。
## 时基实锤（2026-09-23 Step0 探针，tools/tmp_b3probe 已毁尸，逐字记录见
## task-4-report）：定格期间 Engine.get_physics_frames() **照走**（定格 12 帧
## → 帧号 +12）、physics_frame 信号照响，Area 回调被暂停门扣到恢复帧才发。
## ⇒ 弹反窗按全局物理帧计，在途定格会蚕食窗口——Block 态 enter 写
## block_started_frame（按下瞬间读数），蚕食属规则本意（spec §10 帧计数定案）。
const _PARRY_FREEZE_FRAMES := 6
## 白闪双档峰值（混白 amount 0→峰值→0；弹反=防守强档+攻击同拍弱档，
## 格挡=防守弱档。spec §2.4 时长/色单一出处；2026-09-24 LDR 修订：
## 旧 over-bright modulate 峰值色被钳制不可见，改合成器混白量）
const _FLASH_PEAK_STRONG := 1.0
const _FLASH_PEAK_WEAK := 0.55
## 白闪总时长（秒）：弹反 ≈0.12 亮档 / 格挡 ≈0.07 微档，升/降段统一 40/60 拆分
const _FLASH_STRONG_DUR := 0.12
const _FLASH_WEAK_DUR := 0.07
const _FLASH_UP_RATIO := 0.4

#--- public variables - order: export > normal var > onready --------------------------------------

var character_attributes: QuiverAttributes = null

#--- private variables - order: export > normal var > onready -------------------------------------

## 阵营 group 缓存（Dictionary 格式，key 为 faction name，value 为 true）
## 使用 Dictionary 实现 O(1) 查找，比 Array 遍历更快
var _faction_dict: Dictionary = {}

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	if Engine.is_editor_hint():
		QuiverEditorHelper.disable_all_processing(self)
		return
	
	var owner_path := owner.get_path()
	add_to_group(StringName(owner_path))
	_refresh_faction_cache()
	
	QuiverEditorHelper.connect_between(area_entered, _on_area_entered)


## 运行时加入阵营组并刷新缓存。**外部动态加 faction 组一律走本方法。**
## 引擎陷阱（2026-09-15 实测）：GDScript 对"已知静态类型变量"的方法调用直连
## Node 原生 add_to_group 绑定，**绕过**下方脚本层 override——只有 Variant
## 动态调用才会进 override。依赖 override 刷新缓存会让 typed 调用点静默失效。
func add_faction_group(group: StringName) -> void:
	add_to_group(group)
	_refresh_faction_cache()


## 重写 add_to_group：捕获运行时的 faction group 变更
## （仅对 Variant 动态调用生效；typed 调用请改用 [method add_faction_group]）
func add_to_group(group: StringName, persistent: bool = false) -> void:
	super(group, persistent)
	if str(group).begins_with(FACTION_PREFIX):
		_refresh_faction_cache()


## 重写 remove_from_group：捕获运行时的 faction group 变更
func remove_from_group(group: StringName) -> void:
	super(group)
	if str(group).begins_with(FACTION_PREFIX):
		_refresh_faction_cache()


### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## 阵营检查：同一 area2d: 组的双方视为同阵营，攻击不造成伤害
## 使用 Dictionary 缓存实现 O(1) 查找，自动选择小集合遍历
static func are_factions_equal(hit_box: Area2D, hurt_box: Area2D) -> bool:
	# 获取两侧的 faction Dictionary
	var hit_dict := _get_faction_dict(hit_box)
	var hurt_dict := _get_faction_dict(hurt_box)
	
	# 快速路径：任一方无 faction group，直接返回 false
	if hit_dict.is_empty() or hurt_dict.is_empty():
		return false
	
	# 遍历小集合，查找大集合（优化性能）
	if hit_dict.size() <= hurt_dict.size():
		for faction in hit_dict:
			if hurt_dict.has(faction):
				return true
	else:
		for faction in hurt_dict:
			if hit_dict.has(faction):
				return true
	
	return false


## 辅助函数：获取节点的 faction Dictionary
## 如果是 QuiverHitBox/QuiverHurtBox，使用缓存；否则实时构建
static func _get_faction_dict(node: Area2D) -> Dictionary:
	if node is QuiverHitBox:
		return node._faction_dict
	elif node is QuiverHurtBox:
		return node._faction_dict
	else:
		# 回退：非 Quiver 类型，实时构建 Dictionary
		var dict := {}
		for group in node.get_groups():
			if str(group).begins_with(FACTION_PREFIX):
				dict[group] = true
		return dict

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

## 刷新阵营 group 缓存（只缓存 area2d: 前缀的 group，使用 Dictionary 存储）
func _refresh_faction_cache() -> void:
	_faction_dict.clear()
	for group in get_groups():
		if str(group).begins_with(FACTION_PREFIX):
			_faction_dict[group] = true


func _on_area_entered(area: Area2D) -> void:
	if are_factions_equal(area, self):
		return
	
	if area is WallHitBox:
		_handle_wall_hit_box(area)
	elif area is QuiverHitBox:
		_handle_hit_box(area)
	elif area is QuiverGrabBox:
		_handle_grab_box(area)
	else:
		push_error("Unrecognized collision between: %s and %s"%[self, area])
		return


func _can_be_attacked_by(attacker: QuiverAttributes, hit_box: Area2D) -> bool:
	var value := false
	
	if not character_attributes.is_invulnerable:
		# 车道换轴（2026-09-19）：出手镜像为纵向→比"列"（双方盒 x）；
		# 否则（横攻/镜像零=非出手态）→现行"比排"(Y)语义一字不动
		var mirror := attacker.skin_direction
		if mirror != Vector2.ZERO and absf(mirror.y) > absf(mirror.x):
			value = CombatSystem.is_in_same_column_as(
					character_attributes, attacker,
					global_position.x, hit_box.global_position.x
			)
		else:
			value = CombatSystem.is_in_same_lane_as(character_attributes, attacker)
	
	return value


func _can_be_grabbed_by(grabber: QuiverAttributes) -> bool:
	var value := false
	
	if (
		not character_attributes.is_invulnerable 
		and not character_attributes.has_superarmor
		and character_attributes.can_be_grabbed
	):
		value = CombatSystem.is_in_same_lane_as(character_attributes, grabber)
	
	return value


## 判定缝三分支（S2-B3 spec §2.3，唯一插入点=_can_be_attacked_by 通过后）：
## delta = 当前物理帧 − block_started_frame；窗=防守方受管字段（重算回写模型
## 使本代码零感知修饰存在）。弹反严格 `<`（按下帧 delta=0 起算共窗帧数，
## delta==窗 归格挡）。读到的三个字段皆为当前合成值。
func _handle_hit_box(hit_box: QuiverHitBox) -> void:
	if not _can_be_attacked_by(hit_box.character_attributes, hit_box):
		return
	var atk_attrs := hit_box.character_attributes
	var defender_attrs := character_attributes
	# 输出乘数=攻击方受管字段（护人阶段 0.3 之类全由修饰表达）；弹体的
	# character_attributes 实测绑施法者属性（spell_base.gd:74，P6 探针实锤），
	# null 仅防御性兜底——_can_be_attacked_by 已解引用攻击者，走到此处恒非 null。
	var out_mult := 1.0 if atk_attrs == null else atk_attrs.attack_output
	if defender_attrs.is_blocking:
		var delta := Engine.get_physics_frames() - defender_attrs.block_started_frame
		if delta < defender_attrs.parry_window_frames:
			# —— 弹反支：免伤免退，防守方池一分不扣、不进受击态 ——
			# 定格自发（见 _PARRY_FREEZE_FRAMES 警条注释）；双方白闪同拍
			# （防守强档+攻击弱档=spec §2.4 三件套之视觉两件，第三件=攻击者
			# 自己的受击动画，由下面的反顶派发）。伤害与击退派发均不发生。
			HitFreeze.start(_PARRY_FREEZE_FRAMES)
			_flash(defender_attrs, true)
			_flash(atk_attrs, false)
			if atk_attrs != null:
				# 顶回去=对攻击者本人跑同一统一弹退模型（launch 零向量，位移
				# 仅其受击动画自带小退步；其池将破则现行判则自动升格 knockout，
				# 腾空者按空中判则被轰下——全是旧机制，无新分支）。
				var counter := QuiverKnockbackData.new(
						_PARRY_STUN_KNOCK, CombatSystem.HurtTypes.MID, Vector2.ZERO
				)
				CombatSystem.apply_knockback(counter, atk_attrs)
				# 霸体鼠洞（spec §2.3 知情条款，勿私斗）：apply_knock 归零制吞 K
				# 且不发任何信号 ⇒ 对护甲敌人弹反空转。当前内容库零使用者；
				# B5 都尉若发护甲须正式裁决"弹反与护甲互相无效"，届时改规则不改这里。
		else:
			# —— 格挡支：伤害=原伤害×输出乘数×系数；该击击退值**整颗作废**
			# （不回池、不派发、不换算）——"重击变轻拳、飞天变站桩"的全部真相。
			CombatSystem.apply_damage_value(
					hit_box.attack_data.attack_damage * out_mult * defender_attrs.block_damage_ratio,
					defender_attrs
			)
			_flash(defender_attrs, false)
	else:
		# —— 常规支：out_mult==1.0 时与改造前逐字等价（lane 契约 P1 哨兵锁）；
		# 击退构建与派发块保持原样（仅伤害入口换成 apply_damage_value）。
		CombatSystem.apply_damage_value(
				hit_box.attack_data.attack_damage * out_mult, defender_attrs)
		var knockback: QuiverKnockbackData = QuiverKnockbackData.new(
				hit_box.attack_data.knock_strength,
				hit_box.attack_data.hurt_type,
				_get_treated_launch_vector(hit_box)
		)
		CombatSystem.apply_knockback(knockback, character_attributes)

	# 命中回执：走攻击盒自带的注入式回调（QuiverHitBox.on_target_hit 注释含
	# 完整决策史）。旧实现 `hit_box.owner.has_method("on_hit")` 反射已废除：
	# owner 只跨一道场景边界，弹体攻击盒的 owner 是皮肤非弹体，通知从诞生
	# 即静默丢弃（2026-09-16 用户 F5 定罪：弹体扣血后穿体飞到超时）。
	# 判定缝公共义务（spec §2.3.4）：三分支一律照常送达——绕过=穿体飞到判例同族。
	if hit_box.on_target_hit.is_valid():
		hit_box.on_target_hit.call(self)


## 白闪合成器着色器（惰性构建一次全体复用；脚本热重载丢 static 后下次
## 闪白自动重建，主帧单线程无竞态）。
static var _flash_shader: Shader

## 闪白互踩防线 meta 键：闪白 material 携带"true 原底材"、sprite 携带在途 tween
const _FLASH_PREV_META := &"b3_flash_prev_material"
const _FLASH_TWEEN_META := &"b3_flash_tween"


## 白闪 helper（spec §2.4 修订形制，弹反/格挡共用，出处定档一处）：
## LDR-2D 判例（2026-09-24 用户 F5 定罪）：modulate>1 在光栅化处钳回 1，
## 乘法调不来白——闪白必须走合成器；且本构建（4.7.1 headless 探针实锤）
## CanvasItem **没有** material_overlay 属性，合成通道 = `material` 换挂：
## 皮肤精灵挂运行时构建的混白 ShaderMaterial，amount 双段 tween（升 40%/
## 降 60%）跑完摘回原底材（皮肤场景资产零改动、不开全局 HDR）。
## 连续闪白：新闪接管——旧 tween kill，"true 原底材"经闪白 material 的 meta
## 接力传递，摘除恒回正本尊。bind_node 让节点中途释放时 tween 自动夭折
## （击飞链 free 判例防线）；null/失效率安全——反馈件永无资格炸结算链。
static func _flash(target_attrs: QuiverAttributes, strong: bool) -> void:
	if target_attrs == null:
		return
	var node := target_attrs.character_node
	if node == null or not is_instance_valid(node):
		return
	if _flash_shader == null:
		_flash_shader = Shader.new()
		_flash_shader.code = """shader_type canvas_item;
uniform float amount: hint_range(0.0, 1.0) = 0.0;
void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), amount);
}"""
	# 皮肤精灵=角色子树第一个 AnimatedSprite2D（chen 系皮肤形制=Skin/
	# AnimatedSprite2D，find_children 抗路径改动）
	var sprites := node.find_children("*", "AnimatedSprite2D", true, false)
	if sprites.is_empty():
		return
	var sprite: CanvasItem = sprites[0]
	# 原底材快照：当前已是闪白 material（连续闪白）→ 从其 meta 挖出真原版
	var prev: Material = sprite.material
	if prev is ShaderMaterial and (prev as ShaderMaterial).shader == _flash_shader:
		prev = prev.get_meta(_FLASH_PREV_META)
	var mat := ShaderMaterial.new()
	mat.shader = _flash_shader
	mat.set_meta(_FLASH_PREV_META, prev)
	# 掐掉在途旧闪（防其收尾回调摘走新闪的 baton）
	if sprite.has_meta(_FLASH_TWEEN_META):
		var old: Tween = sprite.get_meta(_FLASH_TWEEN_META)
		if old != null and old.is_valid():
			old.kill()
	sprite.material = mat
	var total: float = _FLASH_STRONG_DUR if strong else _FLASH_WEAK_DUR
	var peak: float = _FLASH_PEAK_STRONG if strong else _FLASH_PEAK_WEAK
	var tw := sprite.create_tween()
	tw.bind_node(sprite)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("amount", v),
			0.0, peak, total * _FLASH_UP_RATIO)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("amount", v),
			peak, 0.0, total * (1.0 - _FLASH_UP_RATIO))
	tw.tween_callback(func() -> void:
		if is_instance_valid(sprite) and sprite.material == mat:
			sprite.material = prev)
	sprite.set_meta(_FLASH_TWEEN_META, tw)


func _handle_wall_hit_box(wall_hit_box: WallHitBox) -> void:
	# 弹墙豁免门（状态生命周期驱动，2026-09-19 定档）：只有击飞链内
	# （in_knockout 由 QuiverActionAirKnockout enter/exit 唯一写入）才与
	# 相机弹墙带结算"撞墙扣血+反弹"；走路/受击等一切其他状态贴墙静默。
	# 前置条件归处理器自持与本文件 _can_be_attacked_by 家族同款分工，
	# _on_area_entered 保持纯类型路由。
	if not character_attributes.in_knockout:
		return
	CombatSystem.apply_damage(wall_hit_box.attack_data, character_attributes)
	# 镜像轴是墙自带数据（左右墙 UP=翻水平、上下墙 RIGHT=翻竖直），判定端
	# 不做任何几何发明；击飞链据此对"尚未被实体墙清零"的完整撞击速度做真镜像
	# （带墙分离布局保证命中先于碰撞，见 QuiverLevelCamera.WALL_OUTSET_*/BAND_REACH_*）。
	character_attributes.wall_bounced.emit(wall_hit_box.mirror_axis)


func _handle_grab_box(grab_box: QuiverGrabBox) -> void:
	if _can_be_grabbed_by(grab_box.character_attributes):
		grab_box.character_attributes.grab_requested.emit(character_attributes)


func _get_treated_launch_vector(hit_box: QuiverHitBox) -> Vector2:
	var launch_vector := hit_box.attack_data.launch_vector
	if _attack_is_coming_from_right(hit_box):
		launch_vector = launch_vector.reflect(Vector2.UP)
	return launch_vector


func _attack_is_coming_from_right(hit_box: QuiverHitBox) -> bool:
	return hit_box.global_position.x > global_position.x


### -----------------------------------------------------------------------------------------------
