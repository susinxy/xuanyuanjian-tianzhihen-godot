class_name QuiverLevelCamera
extends Camera2D

## Write your doc string for this file here

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

## 实体墙外挪量（px）：墙面从"房界∧视口沿"取紧者再向界外挪 O——角色贴墙停住时
## 身体中心≈线−O+半身宽（负值=越线出镜），"被拦住"的观感保留、场内空间完整还给玩法。
const WALL_OUTSET := 60.0

## 弹墙带场内探出量（px）：带盒=[线+b−80, 线+b]（内沿只入线 b）。
## 命中提前量预算由 b 与 O 分摊（定和 ≥74）：触发余量 = b+O−受击盒内缩(8)
## ≥ 2 物理帧 × 最大弹速步 33.3px（2000px/s÷60）。现值 20+60=80 → 余量 72px=2.2 帧。
## 带墙同心旧案（镜像输入被墙清零）与本常数家族同源——改任一值须同步 D8 几何锁。
const BAND_REACH := 20.0

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


## 四面墙+四弹墙带统一定位（_ready 与 _process 各跑，先于任何物理帧）。
## 每面"线"= min/max(房界, 视口沿) 的取紧者（与旧公式同语义）；
## 墙盒外挪 WALL_OUTSET、带盒内探 BAND_REACH——带墙肩并肩不重叠（旧 RT2D
## 同心布局让撞墙清零永远先于带命中，镜像输入恒 0，2026-09-19 终案废除）。
func _place_collision_limits() -> void:
	var half_col := collision_width / 2.0
	var half_vis := get_viewport_rect().size / zoom / 2.0
	var center := get_screen_center_position()
	
	var line_l := minf(float(limit_left), center.x - half_vis.x)
	var line_r := maxf(float(limit_right), center.x + half_vis.x)
	var line_t := minf(float(limit_top), center.y - half_vis.y)
	var line_b := maxf(float(limit_bottom), center.y + half_vis.y)
	
	_limit_left.global_position = Vector2(line_l - half_col - WALL_OUTSET, center.y)
	_limit_right.global_position = Vector2(line_r + half_col + WALL_OUTSET, center.y)
	_limit_top.global_position = Vector2(center.x, line_t - half_col - WALL_OUTSET)
	_limit_bottom.global_position = Vector2(center.x, line_b + half_col + WALL_OUTSET)
	
	_bounce_left.global_position = Vector2(line_l + BAND_REACH - half_col, center.y)
	_bounce_right.global_position = Vector2(line_r - BAND_REACH + half_col, center.y)
	_bounce_top.global_position = Vector2(center.x, line_t + BAND_REACH - half_col)
	_bounce_bottom.global_position = Vector2(center.x, line_b - BAND_REACH + half_col)
	
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
