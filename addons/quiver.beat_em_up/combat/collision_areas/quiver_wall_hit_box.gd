@tool
class_name WallHitBox
extends QuiverHitBox

## Write your doc string for this file here

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

## 弹墙镜像轴（数据在墙上，判定端零发明）：reflect(n) 依引擎源码为 2(v·n)n−v，
## 翻转**垂直于 n** 的分量——左/右竖墙配 Vector2.UP（翻水平），上/下横墙配
## Vector2.RIGHT（翻竖直）。语义由 knockout_contract D6 真值表断言在引擎里钉死
## （2026-09-19 弹墙终案，上游原行 reflect(Vector2.UP) 至此恢复并四边补全）。
@export var mirror_axis: Vector2 = Vector2.UP

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
