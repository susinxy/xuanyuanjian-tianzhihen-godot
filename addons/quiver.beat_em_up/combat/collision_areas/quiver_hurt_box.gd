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


func _can_be_attacked_by(attacker: QuiverAttributes) -> bool:
	var value := false
	
	if not character_attributes.is_invulnerable:
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


func _handle_hit_box(hit_box: QuiverHitBox) -> void:
	if _can_be_attacked_by(hit_box.character_attributes):
#		print("hit_box: %s"%[hit_box.get_path()])
		CombatSystem.apply_damage(hit_box.attack_data, character_attributes)
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
		if hit_box.on_target_hit.is_valid():
			hit_box.on_target_hit.call(self)


func _handle_wall_hit_box(wall_hit_box: WallHitBox) -> void:
	# 弹墙豁免门（状态生命周期驱动，2026-09-19 定档）：只有击飞链内
	# （in_knockout 由 QuiverActionAirKnockout enter/exit 唯一写入）才与
	# 相机弹墙带结算"撞墙扣血+反弹"；走路/受击等一切其他状态贴墙静默。
	# 前置条件归处理器自持与本文件 _can_be_attacked_by 家族同款分工，
	# _on_area_entered 保持纯类型路由。
	if not character_attributes.in_knockout:
		return
	CombatSystem.apply_damage(wall_hit_box.attack_data, character_attributes)
	character_attributes.wall_bounced.emit()


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
