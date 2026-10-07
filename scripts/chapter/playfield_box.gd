@tool
class_name PlayfieldBox
extends ReferenceRect

## 可移动区盒（2026-10 盒轨搭建批 G1，法源 specs/2026-10-07-playfield-box-design §二）：
## 编辑器拖框=段的可行走闭区间；运行时派生四边实体墙带（**外贴**，不吞可行走面积）
## 与可选 Vis 地板。墙带为运行时生成，不落 .tscn 文本（校验器管辖外，防手改）。
## 坐标系契约（R13②）：anchors 保持默认、offset 四值即段局部矩形（雷区 a 同源）。
## 单一职责：只管边界，不碰阴影（ShadowRegion 为平级家具，默认不摆=全区域回退）。

const HEIGHT_ALL := 16760832  # = QuiverCharacter.get_all_height_layers_mask()，同 R7 配方

## 墙带外延厚度（致死击飞 ≤2000px/s ≈33px/拍，400 深冗余封锁）
@export var band_depth := 400.0
## 总开关：生成四边实体墙带
@export var gen_bands := true
## 单边墙开关（法典雷 k：盒南北界与相机动态带是两层墙，竖向大于视口时外圈墙永不被撞）
@export var north_wall := true
@export var south_wall := true
@export var east_wall := true
@export var west_wall := true
## 运行时生成地板色块（纯装饰，z=-10 Vis 惯例）
@export var gen_vis := true


func _ready() -> void:
	if Engine.is_editor_hint():
		QuiverEditorHelper.disable_all_processing(self)
		return
	add_to_group(&"playfield_box")
	# 盒矩形（段局部坐标）=anchors 默认下 offset 四值直读（勿用 get_global_rect——
	# 子节点局部计算与全局变换解耦，见 _band 的 origin 换算）
	var origin := Vector2(offset_left, offset_top)
	var size := Vector2(offset_right - offset_left, offset_bottom - offset_top)
	if size.x <= 0.0 or size.y <= 0.0:
		push_warning("PlayfieldBox %s 矩形零面积（offset 未摆正），墙带/地板不生成" % get_path())
		return
	if gen_bands:
		_make_band(&"BandNorth", Rect2(origin.x, origin.y - band_depth, size.x, band_depth))
		_make_band(&"BandSouth", Rect2(origin.x, origin.y + size.y, size.x, band_depth))
		_make_band(&"BandEast", Rect2(origin.x + size.x, origin.y - band_depth,
				band_depth, size.y + 2.0 * band_depth))
		_make_band(&"BandWest", Rect2(origin.x - band_depth, origin.y - band_depth,
				band_depth, size.y + 2.0 * band_depth))
	if gen_vis:
		_make_vis(origin, size)


func _get_configuration_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	if anchor_left != 0.0 or anchor_top != 0.0 or anchor_right != 0.0 or anchor_bottom != 0.0:
		w.append("盒矩形坐标系将失配（R13②）：anchors 须保持默认，矩形全靠 offset 四值")
	return w


## 单边墙带：开关关则不建。body 挂盒下，局部坐标=世界矩形-盒原点（保全局变换
## 显式换算——add_child 第二参不是保形义务，判例见 AGENTS 手改 tscn 节）
func _make_band(p_name: StringName, world_seg_rect: Rect2) -> void:
	var enabled := north_wall if p_name == &"BandNorth" else (
			south_wall if p_name == &"BandSouth" else (
			east_wall if p_name == &"BandEast" else west_wall))
	if not enabled:
		return
	var body := StaticBody2D.new()
	body.name = p_name
	body.collision_layer = HEIGHT_ALL
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = world_seg_rect.size
	shape.shape = rs
	body.add_child(shape)
	add_child(body)
	var origin := Vector2(offset_left, offset_top)
	body.position = world_seg_rect.get_center() - origin


func _make_vis(origin: Vector2, size: Vector2) -> void:
	var floor_v := Polygon2D.new()
	floor_v.name = "VisFloor"
	floor_v.z_index = -10
	floor_v.color = Color(0.55, 0.43, 0.25, 1.0)
	floor_v.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)])
	add_child(floor_v)
