class_name QuiverLevelCamera
extends Camera2D

## Write your doc string for this file here

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

## 弹墙带领先实墙的深度（px，向场内）：带盒 = [面+20, 面+100]（带宽与墙厚同为
## collision_width，中心+100 即外沿留 20 贴墙、内沿探入 100）。此深度保证
## "受击盒跨入带"的 enter 事件至少早于身体撞墙 2 物理帧（触发余量 ≥65+探出量，
## 最大弹速 2000px/s 每帧仅 33px）——镜像弹回拿到的永远是未被墙清零的完整
## 撞击速度（2026-09-19 弹墙终案：带墙同心=输入被引擎销毁，带墙分离=各司其职）。
const BAND_INSET := 100.0

#--- public variables - order: export > normal var > onready --------------------------------------

@export_range(0,1,1,"or_greater") var collision_width := 80.0:
	set(value):
		collision_width = value
		_update_collision_limits_width()

#--- private variables - order: export > normal var > onready -------------------------------------

@onready var _limit_left := $ScreenLimits/Left as CollisionShape2D
@onready var _limit_right := $ScreenLimits/Right as CollisionShape2D
@onready var _limit_top := $ScreenLimits/Top as CollisionShape2D
@onready var _limit_bottom := $ScreenLimits/Bottom as CollisionShape2D

@onready var _bounce_left := $LeftBounce as Area2D
@onready var _bounce_right := $RightBounce as Area2D
@onready var _bounce_top := $TopBounce as Area2D
@onready var _bounce_bottom := $BottomBounce as Area2D

@onready var _collision_limits: Array[CollisionShape2D] = [
	_limit_left,
	_limit_right,
	_limit_top,
	_limit_bottom,
]

var _tween: Tween

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	_update_collision_limits_length()
	get_viewport().size_changed.connect(_update_collision_limits_length)
	_setup_height_layer_collisions()
	# 出生帧定位铁律：墙在场景文件里的默认摆位是相对相机的老坐标，相机又是
	# 角色的子节点——不先定位，首物理帧 Spawn 点会正压在墙体内，实体墙
	# （2026-09-19 去 one_way 后）的穿透弹出把角色瞬移十几像素起步
	# （stage_contract C7 出生位漂移案实证）。_ready 先于任何物理帧执行。
	_place_collision_limits()


func _process(_delta: float) -> void:
	_place_collision_limits()
	if _tween and _tween.is_running():
		_update_collision_limits_length()


## 四块隐形墙贴视口边定位（原 _process 内联体，抽出供 _ready 先摆一次）。
func _place_collision_limits() -> void:
	for limit in _collision_limits:
		var half_collision_width := collision_width * Vector2.ONE /2.0
		var half_size := get_viewport_rect().size / zoom / 2.0 + half_collision_width
		var target_position := get_screen_center_position()
		if limit == _limit_left:
			target_position.x = minf(
					limit_left - half_collision_width.x , target_position.x - half_size.x
			)
		elif limit == _limit_right:
			target_position.x = maxf(
					limit_right + half_collision_width.x, target_position.x + half_size.x
			)
		elif limit == _limit_top:
			target_position.y = minf(
					limit_top - half_collision_width.y, target_position.y - half_size.y
			)
		elif limit == _limit_bottom:
			target_position.y = maxf(
					limit_bottom + half_collision_width.y, target_position.y + half_size.y
			)
		
		limit.global_position = target_position
	
	# 弹墙带"带内墙外"分离摆位：带中心=对应墙中心向场内 BAND_INSET。
	# 旧形态经 RemoteTransform2D 把带钉死在墙心（带墙同心），撞墙清零永远
	# 先于带的命中事件，弹墙镜像拿到的输入恒为 0——RT2D 已删，改由此处统一摆。
	_bounce_left.global_position = _limit_left.global_position + Vector2(BAND_INSET, 0)
	_bounce_right.global_position = _limit_right.global_position + Vector2(-BAND_INSET, 0)
	_bounce_top.global_position = _limit_top.global_position + Vector2(0, BAND_INSET)
	_bounce_bottom.global_position = _limit_bottom.global_position + Vector2(0, -BAND_INSET)
	
### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## 过渡镜头六参数到目标值。返回本次 Tween，调用方可挂 finished 做落位收尾
## （战斗房用它把"锁房期间被扫掠墙落在界外"的玩家钳回界内——扫掠吞人对策）。
func delimitate_room(
		p_limit_left: int, p_limit_top: int, p_limit_right: int, p_limit_bottom: int,
		p_zoom: float, p_duration: float
) -> Tween:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	_tween.tween_property(self, "zoom", Vector2.ONE * p_zoom, p_duration)
	_tween.tween_property(self, "limit_left", p_limit_left, p_duration)
	_tween.tween_property(self, "limit_top", p_limit_top, p_duration)
	_tween.tween_property(self, "limit_right", p_limit_right, p_duration)
	_tween.tween_property(self, "limit_bottom", p_limit_bottom, p_duration)
	return _tween

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _setup_height_layer_collisions() -> void:
	var height_mask := QuiverCharacter.get_all_height_layers_mask()
	$ScreenLimits.collision_layer = height_mask
	# 墙体间（CharacterBody↔StaticBody）碰撞要求两侧 mask/layer 互叠。
	# 高度层重构后角色 body 的 layer 只剩高度位（不再含 bit1 players），而本
	# 节点 mask 从未配置、停在默认 1 → 互检恒零 → 相机隐形墙物理上从未挡人
	# （2026-09-19"走出镜头"F5 案真凶；弹墙 Area 受害是单侧检测所以能扣血）。
	$ScreenLimits.collision_mask = height_mask
	$LeftBounce.collision_layer = height_mask
	$RightBounce.collision_layer = height_mask
	$TopBounce.collision_layer = height_mask
	$BottomBounce.collision_layer = height_mask


func _update_collision_limits_width() -> void:
	if not is_inside_tree():
		await self.ready
	
	for limit in _collision_limits:
		(limit.shape as RectangleShape2D).size.y = collision_width


func _update_collision_limits_length() -> void:
	if not is_inside_tree():
		await self.ready
	
	var rect_size := get_viewport_rect().size / zoom
	for limit in _collision_limits:
		if limit == _limit_left or limit == _limit_right:
			(limit.shape as RectangleShape2D).size.x = rect_size.y + collision_width
		else:
			(limit.shape as RectangleShape2D).size.x = rect_size.x + collision_width

### -----------------------------------------------------------------------------------------------
