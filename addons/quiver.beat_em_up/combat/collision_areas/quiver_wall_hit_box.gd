@tool
class_name WallHitBox
extends QuiverHitBox

## Write your doc string for this file here

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	super()
	# 墙不入阵营系统（2026-09-19 定档）：旧机制在这里挂 area2d:wall 组、
	# 靠"与皮肤受击盒同组"实现走路免撞墙——typed 裸调绕过缓存刷新即全链
	# 失效（走路撞墙掉血 F5 定罪），且"伪阵营"三处溃伤在案。现免撞墙由
	# QuiverHurtBox._handle_wall_hit_box 的 in_knockout 状态门承担。
	attack_data.changed.connect(update_configuration_warnings)


func _get_configuration_warnings() -> PackedStringArray:
	const ERROR_KNOCKBACK = "WallHitBox have their own rules for knockback, and attack data's" \
			+ " knockback properties will be ignored"
	
	var warnings := PackedStringArray()
	
	if (
			attack_data.knock_strength > 0.0
			or attack_data.launch_angle != 0
	):
		warnings.append(ERROR_KNOCKBACK)
	
	return warnings

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
