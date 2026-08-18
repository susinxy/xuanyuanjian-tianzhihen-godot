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


## 计算最小面积包围矩形 (MABR)
##
## 使用 O(n²) 投影法：遍历凸包每条边，将所有顶点投影到该边方向，
## 计算投影的 axis-aligned bbox，取面积最小的矩形。
##
## 基于 Freeman & Shapira (1975) 定理：最小面积包围矩形至少有一条边
## 与凸包的某条边共线。
##
## 参数:
## - points: 多边形顶点数组（任意坐标系）
##
## 返回: {
##   center: Vector2,              # 矩形中心（与输入同坐标系）
##   size: Vector2,                # (width, height) 完整尺寸
##   angle: float,                 # 旋转角度（弧度，atan2(u.y, u.x)）
##   area: float,                  # 矩形面积
##   corners: PackedVector2Array   # 4 个角点（用于绘制，顺序：左下→右下→右上→左上）
## }
static func calc_mabr(points: PackedVector2Array) -> Dictionary:
	var empty_result := {
		"center": Vector2.ZERO,
		"size": Vector2.ZERO,
		"angle": 0.0,
		"area": 0.0,
		"corners": PackedVector2Array(),
	}
	
	if points.size() == 0:
		return empty_result
	
	if points.size() == 1:
		return {
			"center": points[0],
			"size": Vector2.ZERO,
			"angle": 0.0,
			"area": 0.0,
			"corners": PackedVector2Array([points[0], points[0], points[0], points[0]]),
		}
	
	# 计算凸包（返回 CCW 顺序，最后一个点 == 第一个点）
	var hull := Geometry2D.convex_hull(points)
	
	# 去除闭合点
	if hull.size() > 1 and hull[0].distance_to(hull[hull.size() - 1]) < 1e-6:
		hull.resize(hull.size() - 1)
	
	var n := hull.size()
	
	# 退化：凸包顶点 < 2
	if n < 2:
		var p: Vector2 = hull[0] if n == 1 else points[0]
		return {
			"center": p,
			"size": Vector2.ZERO,
			"angle": 0.0,
			"area": 0.0,
			"corners": PackedVector2Array([p, p, p, p]),
		}
	
	# 退化：只有 2 个顶点（共线）
	if n == 2:
		var mid: Vector2 = (hull[0] + hull[1]) / 2.0
		var edge := hull[1] - hull[0]
		var dist := edge.length()
		var angle := atan2(edge.y, edge.x)
		return {
			"center": mid,
			"size": Vector2(dist, 0.0),
			"angle": angle,
			"area": 0.0,
			"corners": PackedVector2Array([hull[0], hull[1], hull[1], hull[0]]),
		}
	
	# 主循环：遍历每条凸包边，投影所有顶点
	var best_area := INF
	var best_min_u := 0.0
	var best_min_v := 0.0
	var best_max_u := 0.0
	var best_max_v := 0.0
	var best_u := Vector2.RIGHT
	var best_v := Vector2.UP
	
	var epsilon := 1e-6
	
	for i in range(n):
		var a: Vector2 = hull[i]
		var b: Vector2 = hull[(i + 1) % n]
		var edge := b - a
		var edge_len := edge.length()
		
		if edge_len < epsilon:
			continue
		
		var u := edge / edge_len
		var v := Vector2(-u.y, u.x)
		
		var min_u := INF
		var max_u := -INF
		var min_v := INF
		var max_v := -INF
		
		for p in hull:
			var proj_u := p.dot(u)
			var proj_v := p.dot(v)
			if proj_u < min_u:
				min_u = proj_u
			if proj_u > max_u:
				max_u = proj_u
			if proj_v < min_v:
				min_v = proj_v
			if proj_v > max_v:
				max_v = proj_v
		
		var width := max_u - min_u
		var height := max_v - min_v
		var area := width * height
		
		if area < best_area:
			best_area = area
			best_min_u = min_u
			best_min_v = min_v
			best_max_u = max_u
			best_max_v = max_v
			best_u = u
			best_v = v
	
	# 主循环后检查：如果所有边都退化（共线或重合点），用 AABB 兜底
	if best_area >= INF:
		var aabb := calc_aabb(points)
		var aabb_size: Vector2 = aabb.size
		var aabb_center: Vector2 = aabb.center
		return {
			"center": aabb_center,
			"size": aabb_size,
			"angle": 0.0,
			"area": aabb_size.x * aabb_size.y,
			"corners": PackedVector2Array([
				Vector2(aabb_center.x - aabb_size.x / 2.0, aabb_center.y - aabb_size.y / 2.0),
				Vector2(aabb_center.x + aabb_size.x / 2.0, aabb_center.y - aabb_size.y / 2.0),
				Vector2(aabb_center.x + aabb_size.x / 2.0, aabb_center.y + aabb_size.y / 2.0),
				Vector2(aabb_center.x - aabb_size.x / 2.0, aabb_center.y + aabb_size.y / 2.0),
			]),
		}
	
	# 计算中心点（从投影坐标转回原坐标系）
	var center_uv := Vector2(
		(best_min_u + best_max_u) / 2.0,
		(best_min_v + best_max_v) / 2.0
	)
	var center := center_uv.x * best_u + center_uv.y * best_v
	
	# 计算 4 个角点
	var corners := PackedVector2Array([
		best_min_u * best_u + best_min_v * best_v,
		best_max_u * best_u + best_min_v * best_v,
		best_max_u * best_u + best_max_v * best_v,
		best_min_u * best_u + best_max_v * best_v,
	])
	
	var size := Vector2(best_max_u - best_min_u, best_max_v - best_min_v)
	var angle := atan2(best_u.y, best_u.x)
	
	return {
		"center": center,
		"size": size,
		"angle": angle,
		"area": best_area,
		"corners": corners,
	}


## 计算 axis-aligned 包围盒 (AABB)
##
## 返回: { center: Vector2, size: Vector2, area: float }
static func calc_aabb(points: PackedVector2Array) -> Dictionary:
	if points.size() == 0:
		return { "center": Vector2.ZERO, "size": Vector2.ZERO, "area": 0.0 }
	
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	
	for p in points:
		if p.x < min_x:
			min_x = p.x
		if p.x > max_x:
			max_x = p.x
		if p.y < min_y:
			min_y = p.y
		if p.y > max_y:
			max_y = p.y
	
	var size := Vector2(max_x - min_x, max_y - min_y)
	var center := Vector2((min_x + max_x) / 2.0, (min_y + max_y) / 2.0)
	
	return {
		"center": center,
		"size": size,
		"area": size.x * size.y,
	}


## 检查点是否在 MABR 内部（含容差）
static func is_point_in_mabr(point: Vector2, mabr: Dictionary, tolerance: float = 0.01) -> bool:
	var center: Vector2 = mabr.center
	var size: Vector2 = mabr.size
	var angle: float = mabr.angle
	
	var cos_a := cos(-angle)
	var sin_a := sin(-angle)
	var dx := point.x - center.x
	var dy := point.y - center.y
	var local_x := dx * cos_a - dy * sin_a
	var local_y := dx * sin_a + dy * cos_a
	
	var half_w := size.x / 2.0 + tolerance
	var half_h := size.y / 2.0 + tolerance
	
	return abs(local_x) <= half_w and abs(local_y) <= half_h


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


# ============================================================================
# MABR 测试（临时，验证后可删除）
# ============================================================================

## 运行 MABR 基础测试
##
## 返回: Array[String]，每条是测试结果（✅ 通过 / ❌ 失败 + 原因）
static func run_mabr_tests() -> Array[String]:
	var results: Array[String] = []
	var counts := [0, 0]  # [pass_count, fail_count]，用数组以便 lambda 修改
	
	# 辅助函数：比较浮点数
	var approx := func(a: float, b: float, tol: float = 0.1) -> bool:
		return abs(a - b) < tol
	
	# 辅助函数：运行单个测试并验证属性
	var run_test := func(name: String, points: PackedVector2Array, expected_size: Vector2, expected_area: float, expected_center: Vector2 = Vector2.INF) -> void:
		var mabr := calc_mabr(points)
		var aabb := calc_aabb(points)
		var errors: Array[String] = []
		
		# 检查 size（允许两个维度互换）
		var size_match: bool = (approx.call(mabr.size.x, expected_size.x) and approx.call(mabr.size.y, expected_size.y)) or \
		                       (approx.call(mabr.size.x, expected_size.y) and approx.call(mabr.size.y, expected_size.x))
		if not size_match:
			errors.append("size 不匹配: 期望 (%.2f, %.2f), 实际 (%.2f, %.2f)" % [
				expected_size.x, expected_size.y, mabr.size.x, mabr.size.y
			])
		
		# 检查 area
		if not approx.call(mabr.area, expected_area, 0.5):
			errors.append("area 不匹配: 期望 %.2f, 实际 %.2f" % [expected_area, mabr.area])
		
		# 检查 center（如果提供）
		if expected_center != Vector2.INF:
			if not approx.call(mabr.center.x, expected_center.x) or not approx.call(mabr.center.y, expected_center.y):
				errors.append("center 不匹配: 期望 (%.2f, %.2f), 实际 (%.2f, %.2f)" % [
					expected_center.x, expected_center.y, mabr.center.x, mabr.center.y
				])
		
		# 属性断言：MABR 面积 <= AABB 面积
		if mabr.area > aabb.area + 0.1:
			errors.append("MABR 面积 (%.2f) > AABB 面积 (%.2f)" % [mabr.area, aabb.area])
		
		# 属性断言：所有原始顶点在 MABR 内部
		for p in points:
			if not is_point_in_mabr(p, mabr):
				errors.append("顶点 (%.2f, %.2f) 不在 MABR 内部" % [p.x, p.y])
				break
		
		if errors.is_empty():
			results.append("✅ %s" % name)
			counts[0] += 1
		else:
			results.append("❌ %s: %s" % [name, "; ".join(errors)])
			counts[1] += 1
	
	# 测试 1: 正方形 (10x10)
	# 预期: size=(10,10), area=100, center=(5,5)
	run_test.call(
		"正方形 (10x10)",
		PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)]),
		Vector2(10, 10), 100.0, Vector2(5, 5)
	)
	
	# 测试 2: 45° 旋转正方形（菱形）
	# 顶点: (5,0), (10,5), (5,10), (0,5)
	# MABR 沿菱形边对齐，size = (5√2, 5√2) ≈ (7.07, 7.07), area = 50
	run_test.call(
		"45° 菱形",
		PackedVector2Array([Vector2(5, 0), Vector2(10, 5), Vector2(5, 10), Vector2(0, 5)]),
		Vector2(7.07, 7.07), 50.0, Vector2(5, 5)
	)
	
	# 测试 3: 细长矩形 (20x4)
	# 预期: size=(20,4), area=80, center=(10,2)
	run_test.call(
		"细长矩形 (20x4)",
		PackedVector2Array([Vector2(0, 0), Vector2(20, 0), Vector2(20, 4), Vector2(0, 4)]),
		Vector2(20, 4), 80.0, Vector2(10, 2)
	)
	
	# 测试 4: 单点
	var single_result := calc_mabr(PackedVector2Array([Vector2(5, 5)]))
	if single_result.center == Vector2(5, 5) and single_result.size == Vector2.ZERO and single_result.area == 0.0:
		results.append("✅ 单点")
		counts[0] += 1
	else:
		results.append("❌ 单点: center=%s, size=%s, area=%.2f" % [single_result.center, single_result.size, single_result.area])
		counts[1] += 1
	
	# 测试 5: 两点 (水平)
	var two_result := calc_mabr(PackedVector2Array([Vector2(0, 0), Vector2(10, 0)]))
	if approx.call(two_result.size.x, 10.0) and approx.call(two_result.size.y, 0.0) and two_result.area == 0.0 and two_result.center == Vector2(5, 0):
		results.append("✅ 两点 (水平)")
		counts[0] += 1
	else:
		results.append("❌ 两点: size=%s, center=%s, area=%.2f" % [two_result.size, two_result.center, two_result.area])
		counts[1] += 1
	
	# 测试 6: 共线三点
	# 预期: size=(10,0), area=0
	run_test.call(
		"共线三点",
		PackedVector2Array([Vector2(0, 0), Vector2(5, 0), Vector2(10, 0)]),
		Vector2(10, 0), 0.0, Vector2(5, 0)
	)
	
	# 测试 7: 斜三角形（仅验证属性，不检查具体值）
	# 对于大多数三角形，MABR = AABB，这是正确的行为
	var tri := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(8, 2)])
	var tri_mabr := calc_mabr(tri)
	var tri_aabb := calc_aabb(tri)
	var tri_errors: Array[String] = []
	
	if tri_mabr.area > tri_aabb.area + 0.1:
		tri_errors.append("MABR 面积 (%.2f) > AABB 面积 (%.2f)" % [tri_mabr.area, tri_aabb.area])
	
	for p in tri:
		if not is_point_in_mabr(p, tri_mabr):
			tri_errors.append("顶点 (%.2f, %.2f) 不在 MABR 内部" % [p.x, p.y])
			break
	
	if tri_errors.is_empty():
		results.append("✅ 斜三角形 (MABR=%.1f, AABB=%.1f)" % [tri_mabr.area, tri_aabb.area])
		counts[0] += 1
	else:
		results.append("❌ 斜三角形: %s" % "; ".join(tri_errors))
		counts[1] += 1
	
	# 测试 8: 空数组
	var empty_result := calc_mabr(PackedVector2Array())
	if empty_result.size == Vector2.ZERO and empty_result.area == 0.0:
		results.append("✅ 空数组")
		counts[0] += 1
	else:
		results.append("❌ 空数组: size=%s, area=%.2f" % [empty_result.size, empty_result.area])
		counts[1] += 1
	
	# 测试 9: 不规则多边形（验证所有顶点在 MABR 内 + 面积 <= AABB）
	var irregular := PackedVector2Array([
		Vector2(2, 1), Vector2(8, 0), Vector2(12, 3), Vector2(10, 9),
		Vector2(6, 11), Vector2(1, 8), Vector2(0, 4)
	])
	var irr_mabr := calc_mabr(irregular)
	var irr_aabb := calc_aabb(irregular)
	var irr_errors: Array[String] = []
	
	if irr_mabr.area > irr_aabb.area + 0.1:
		irr_errors.append("MABR 面积 (%.2f) > AABB 面积 (%.2f)" % [irr_mabr.area, irr_aabb.area])
	
	for p in irregular:
		if not is_point_in_mabr(p, irr_mabr):
			irr_errors.append("顶点 (%.2f, %.2f) 不在 MABR 内部" % [p.x, p.y])
			break
	
	if irr_errors.is_empty():
		results.append("✅ 不规则多边形 (MABR=%.1f, AABB=%.1f, 节省=%.1f%%)" % [
			irr_mabr.area, irr_aabb.area,
			(1.0 - irr_mabr.area / max(irr_aabb.area, 0.001)) * 100.0
		])
		counts[0] += 1
	else:
		results.append("❌ 不规则多边形: %s" % "; ".join(irr_errors))
		counts[1] += 1
	
	# 汇总
	results.append("")
	results.append("总计: %d 通过, %d 失败" % [counts[0], counts[1]])
	
	return results
