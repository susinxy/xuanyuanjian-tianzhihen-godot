@tool
class_name ContourTracer
extends RefCounted

## 轮廓追踪器
##
## 从 PNG 图片提取轮廓多边形，用于生成精确的碰撞形状。
## 使用 Godot 内置 BitMap API（Marching Squares + Ramer-Douglas-Peucker）。

## 从图片提取轮廓
##
## 参数:
## - image: 原始图片
## - mask: 可选的遮罩图片（只处理 mask 不透明区域）
## - alpha_threshold: alpha 阈值（0.0-1.0）
## - simplify_tolerance: RDP 简化容差（像素），0.0=像素级精确
## - max_size: 最大处理尺寸（超过则等比缩放）
##
## 返回: Array[PackedVector2Array]，每个元素是一个多边形（图片像素坐标）
static func trace_contours(
	image: Image,
	mask: Image,
	alpha_threshold: float,
	simplify_tolerance: float,
	max_size: int,
	min_area_ratio: float = 0.3
) -> Array[PackedVector2Array]:
	var work_image := image
	var scale_factor := 1.0
	
	# 1. 缩放图片（如果需要）
	if image.get_width() > max_size or image.get_height() > max_size:
		var max_dim := max(image.get_width(), image.get_height())
		scale_factor = float(max_size) / float(max_dim)
		var new_w := int(image.get_width() * scale_factor)
		var new_h := int(image.get_height() * scale_factor)
		
		work_image = image.duplicate()
		work_image.resize(new_w, new_h, Image.INTERPOLATE_LANCZOS)
	
	# 2. 应用 mask（如果有）：将 mask 的 alpha 乘到 image 的 alpha 上
	if mask != null:
		work_image = _apply_mask(work_image, mask)
	
	# 3. 使用 Godot 内置 BitMap API 提取多边形（带自适应保障）
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(work_image, alpha_threshold)
	
	var rect := Rect2i(Vector2i.ZERO, bitmap.get_size())
	var true_rect := _get_bitmap_true_rect(bitmap)
	
	# bitmap 没有不透明像素 → 直接返回空
	if true_rect.size.x == 0 or true_rect.size.y == 0:
		return []
	
	# 最小面积阈值：true_rect 面积的 min_area_ratio
	var min_area := float(true_rect.size.x) * float(true_rect.size.y) * min_area_ratio
	
	var polygons: Array = bitmap.opaque_to_polygons(rect, simplify_tolerance)
	var has_valid := _has_valid_polygon(polygons, min_area)
	
	# 退化则逐步减半容差重试
	if not has_valid:
		var retry_tolerance := simplify_tolerance / 2.0
		while retry_tolerance >= 0.5:
			polygons = bitmap.opaque_to_polygons(rect, retry_tolerance)
			if _has_valid_polygon(polygons, min_area):
				has_valid = true
				break
			retry_tolerance /= 2.0
	
	# 4. 缩放回原始尺寸（如果之前缩放过）
	if scale_factor != 1.0:
		var inv_scale := 1.0 / scale_factor
		polygons = _scale_polygons(polygons, inv_scale)
	
	# 5. 过滤掉顶点数不足 3 的多边形
	var result: Array[PackedVector2Array] = []
	for poly in polygons:
		if poly.size() >= 3:
			result.append(poly)
	
	return result


## 计算 physical_height
##
## 找到所有轮廓中最高点（Y 值最小）距图片底边的距离
static func calc_physical_height(contours: Array[PackedVector2Array], image_height: int) -> float:
	var min_y := float(image_height)
	for contour in contours:
		for vertex in contour:
			min_y = min(min_y, vertex.y)
	return float(image_height) - min_y


## 计算轮廓宽度
##
## 找到所有轮廓中最左边和最右边的点，计算水平距离
static func calc_contour_width(contours: Array[PackedVector2Array]) -> float:
	var min_x := INF
	var max_x := -INF
	for contour in contours:
		for vertex in contour:
			min_x = min(min_x, vertex.x)
			max_x = max(max_x, vertex.x)
	return max_x - min_x


## 计算 attack_heights
##
## 对每个轮廓计算中点高度，按高度层分组，同层只保留最小值
static func calc_attack_heights(
	contours: Array[PackedVector2Array],
	image_height: int,
	height_definitions: Array
) -> Array:
	var attack_heights: Array[float] = []
	
	for contour in contours:
		var min_y := float(image_height)
		var max_y := 0.0
		for vertex in contour:
			min_y = min(min_y, vertex.y)
			max_y = max(max_y, vertex.y)
		
		var h_n := float(image_height) - min_y
		var l_n := float(image_height) - max_y
		var ah_n := l_n + (h_n - l_n) / 2.0
		attack_heights.append(ah_n)
	
	# 按高度层分组，同层只保留最小值
	var layer_min_values := {}
	for ah in attack_heights:
		var layer := _find_height_layer(ah, height_definitions)
		if not layer_min_values.has(layer) or ah < layer_min_values[layer]:
			layer_min_values[layer] = ah
	
	var result: Array = []
	for layer in layer_min_values.keys():
		result.append(layer_min_values[layer])
	result.sort()
	
	return result


## 将图片像素坐标转换为 CollisionPolygon2D 本地坐标
##
## 轮廓多边形就是角色在图片中的轮廓，与精灵图片始终重合。
## 因此 polygon 顶点直接以图片中心为原点：
## 公式: local = (px - img_w/2 - shape_pos.x, py - img_h/2 - shape_pos.y)
## shape_pos 默认为 (0,0)，Body 转换时不需要传；Attack 转换时传入 AttackShape 的 position
static func pixels_to_shape_local(
	vertices: PackedVector2Array,
	img_w: int,
	img_h: int,
	shape_pos: Vector2 = Vector2.ZERO
) -> PackedVector2Array:
	var result := PackedVector2Array()
	var offset_x := float(img_w) / 2.0 + shape_pos.x
	var offset_y := float(img_h) / 2.0 + shape_pos.y
	
	for vertex in vertices:
		result.append(Vector2(vertex.x - offset_x, vertex.y - offset_y))
	
	return result


## 将 PackedVector2Array 格式化为 .tscn 文本格式
static func format_polygon_array(vertices: PackedVector2Array) -> String:
	if vertices.size() == 0:
		return "PackedVector2Array()"
	
	var parts: PackedStringArray = []
	for vertex in vertices:
		parts.append("%.2f, %.2f" % [vertex.x, vertex.y])
	
	return "PackedVector2Array(%s)" % ", ".join(parts)


# ============================================================================
# 私有方法
# ============================================================================

## 应用 mask：将 mask 的 alpha 通道乘到 image 的 alpha 通道上
##
## 效果：mask 透明的区域，image 也变透明
static func _apply_mask(image: Image, mask: Image) -> Image:
	var result := image.duplicate()
	
	# 如果 mask 尺寸不同，缩放 mask 到 image 尺寸
	var work_mask := mask
	if mask.get_width() != image.get_width() or mask.get_height() != image.get_height():
		work_mask = mask.duplicate()
		work_mask.resize(image.get_width(), image.get_height(), Image.INTERPOLATE_LANCZOS)
	
	# 逐像素：将 mask 的 alpha 乘到 image 的 alpha 上
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var img_color: Color = result.get_pixel(x, y)
			var mask_alpha: float = work_mask.get_pixel(x, y).a
			img_color.a *= mask_alpha
			result.set_pixel(x, y, img_color)
	
	return result


## 缩放多边形数组
static func _scale_polygons(polygons: Array, scale: float) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for poly in polygons:
		var scaled := PackedVector2Array()
		for vertex in poly:
			scaled.append(vertex * scale)
		result.append(scaled)
	return result


## 用 Shoelace 公式计算多边形面积
static func _calc_polygon_area(vertices: PackedVector2Array) -> float:
	var area := 0.0
	var n := vertices.size()
	for i in n:
		var j := (i + 1) % n
		area += vertices[i].x * vertices[j].y
		area -= vertices[j].x * vertices[i].y
	return abs(area) / 2.0


## 检查多边形数组中是否有有效多边形（顶点 >= 3 且面积 >= min_area）
static func _has_valid_polygon(polygons: Array, min_area: float) -> bool:
	for poly in polygons:
		if poly.size() < 3:
			continue
		if _calc_polygon_area(poly) >= min_area:
			return true
	return false


## 计算 BitMap 中不透明像素的包围盒
static func _get_bitmap_true_rect(bitmap: BitMap) -> Rect2i:
	var size := bitmap.get_size()
	var min_x := size.x
	var min_y := size.y
	var max_x := -1
	var max_y := -1
	
	for y in range(size.y):
		for x in range(size.x):
			if bitmap.get_bit(x, y):
				if x < min_x:
					min_x = x
				if y < min_y:
					min_y = y
				if x > max_x:
					max_x = x
				if y > max_y:
					max_y = y
	
	if max_x < 0 or max_y < 0:
		return Rect2i()
	
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


## 根据高度值找到对应的高度层
static func _find_height_layer(height: float, height_definitions: Array) -> int:
	for def in height_definitions:
		if height >= def.min and height < def.max:
			return def.layer
	# 如果超出范围，返回最后一层
	if height_definitions.size() > 0:
		return height_definitions[-1].layer
	return 15
