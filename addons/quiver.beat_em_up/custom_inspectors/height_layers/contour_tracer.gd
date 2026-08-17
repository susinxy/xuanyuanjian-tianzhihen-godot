@tool
class_name ContourTracer
extends RefCounted

## 轮廓追踪器
##
## 从 PNG 图片提取轮廓多边形，用于生成精确的碰撞形状。
## 核心算法：Marching Squares 轮廓追踪 + Douglas-Peucker 多边形简化。

# Marching Squares 的 16 种情况
# 每个 case 是一个数组，包含边的索引对
# 边的定义：0=上, 1=右, 2=下, 3=左
const MARCHING_SQUARES_CASES = [
	[],                    # 0: 全空白
	[[3, 0]],              # 1: 左上
	[[0, 1]],              # 2: 右上
	[[3, 1]],              # 3: 左上+右上
	[[1, 2]],              # 4: 右下
	[[3, 0], [1, 2]],      # 5: 左上+右下（歧义）
	[[0, 2]],              # 6: 右上+右下
	[[3, 2]],              # 7: 左上+右上+右下
	[[2, 3]],              # 8: 左下
	[[2, 0]],              # 9: 左上+左下
	[[0, 1], [2, 3]],      # 10: 右上+左下（歧义）
	[[2, 1]],              # 11: 左上+右上+左下
	[[1, 3]],              # 12: 右下+左下
	[[1, 0]],              # 13: 左上+右下+左下
	[[0, 3]],              # 14: 右上+右下+左下
	[],                    # 15: 全实体
]


## 从图片提取轮廓
##
## 参数:
## - image: 原始图片
## - mask: 可选的遮罩图片（只处理 mask 不透明区域）
## - alpha_threshold: alpha 阈值（0.0-1.0）
## - simplify_tolerance: Douglas-Peucker 简化容差（像素）
## - max_size: 最大处理尺寸（超过则缩放）
##
## 返回: Array[PackedVector2Array]，每个元素是一个轮廓的顶点数组（图片像素坐标）
static func trace_contours(
	image: Image,
	mask: Image,
	alpha_threshold: float,
	simplify_tolerance: float,
	max_size: int
) -> Array[PackedVector2Array]:
	# 1. 缩放图片（如果需要）
	var work_image := image
	var work_mask := mask
	var scale_factor := 1.0
	
	if image.get_width() > max_size or image.get_height() > max_size:
		var max_dim := max(image.get_width(), image.get_height())
		scale_factor = float(max_size) / float(max_dim)
		var new_w := int(image.get_width() * scale_factor)
		var new_h := int(image.get_height() * scale_factor)
		
		work_image = image.duplicate()
		work_image.resize(new_w, new_h, Image.INTERPOLATE_LANCZOS)
		
		if mask != null:
			work_mask = mask.duplicate()
			work_mask.resize(new_w, new_h, Image.INTERPOLATE_LANCZOS)
	
	# 2. 二值化
	var binary := _binarize_image(work_image, work_mask, alpha_threshold)
	var w: int = binary[0].size()  # 宽度（列数）
	var h: int = binary.size()     # 高度（行数）
	
	# 3. Marching Squares 追踪
	var contours := _marching_squares(binary, w, h)
	
	# 4. Douglas-Peucker 简化
	var simplified: Array[PackedVector2Array] = []
	for contour in contours:
		var simplified_contour := _simplify(contour, simplify_tolerance)
		if simplified_contour.size() >= 3:
			simplified.append(simplified_contour)
	
	# 5. 缩放回原始尺寸
	if scale_factor != 1.0:
		var inv_scale := 1.0 / scale_factor
		for i in range(simplified.size()):
			var contour := simplified[i]
			for j in range(contour.size()):
				contour[j] *= inv_scale
	
	return simplified


## 计算 physical_height
##
## 找到所有轮廓中最高点（Y 值最小）距图片底边的距离
static func calc_physical_height(contours: Array[PackedVector2Array], image_height: int) -> float:
	var min_y := float(image_height)
	for contour in contours:
		for vertex in contour:
			min_y = min(min_y, vertex.y)
	return float(image_height) - min_y


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
## 公式: local = (px - img_w/2 - shape_pos.x, py - img_h/2 - shape_pos.y)
static func pixels_to_shape_local(
	vertices: PackedVector2Array,
	img_w: int,
	img_h: int,
	shape_pos: Vector2
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

## 二值化图片
##
## 返回: Array[Array[int]]，0=空白，1=实体
static func _binarize_image(image: Image, mask: Image, threshold: float) -> Array:
	var w := image.get_width()
	var h := image.get_height()
	
	# 外围加一圈空白像素
	var binary := []
	for y in range(h + 2):
		var row := []
		for x in range(w + 2):
			row.append(0)
		binary.append(row)
	
	# 填充内部
	for y in range(h):
		for x in range(w):
			var is_solid := true
			
			# 检查 mask
			if mask != null:
				var mask_alpha := mask.get_pixel(x, y).a
				if mask_alpha < threshold:
					is_solid = false
			
			# 检查 alpha
			if is_solid:
				var alpha := image.get_pixel(x, y).a
				if alpha < threshold:
					is_solid = false
			
			binary[y + 1][x + 1] = 1 if is_solid else 0
	
	return binary


## Marching Squares 轮廓追踪
##
## 返回: Array[PackedVector2Array]，每个元素是一个轮廓
static func _marching_squares(binary: Array, w: int, h: int) -> Array[PackedVector2Array]:
	var contours: Array[PackedVector2Array] = []
	var visited_edges := {}  # key: "x,y,dir" -> true
	
	# 扫描所有像素，找到未访问的轮廓起点
	for y in range(h - 1):
		for x in range(w - 1):
			# 计算当前格子的 case
			var case_val := _get_case(binary, x, y)
			var edges: Array = MARCHING_SQUARES_CASES[case_val]
			
			# 遍历 case 中的所有轮廓边
			for pair in edges:
				for dir in pair:
					var edge_key := "%d,%d,%d" % [x, y, dir]
					if not visited_edges.has(edge_key):
						# 尝试从这个边开始追踪
						var contour := _trace_contour_from_edge(binary, w, h, x, y, dir, visited_edges)
						if contour.size() >= 3:
							contours.append(contour)
	
	return contours


## 检查一条边是否是轮廓边
##
## dir: 0=上, 1=右, 2=下, 3=左
static func _is_contour_edge(binary: Array, x: int, y: int, dir: int, w: int, h: int) -> bool:
	var val1: int
	var val2: int
	
	match dir:
		0:  # 上边：检查 (x,y) 和 (x+1,y)
			if x >= w - 1:
				return false
			val1 = binary[y][x]
			val2 = binary[y][x + 1]
		1:  # 右边：检查 (x+1,y) 和 (x+1,y+1)
			if x >= w - 1 or y >= h - 1:
				return false
			val1 = binary[y][x + 1]
			val2 = binary[y + 1][x + 1]
		2:  # 下边：检查 (x,y+1) 和 (x+1,y+1)
			if x >= w - 1 or y >= h - 1:
				return false
			val1 = binary[y + 1][x]
			val2 = binary[y + 1][x + 1]
		3:  # 左边：检查 (x,y) 和 (x,y+1)
			if y >= h - 1:
				return false
			val1 = binary[y][x]
			val2 = binary[y + 1][x]
		_:
			return false
	
	# 轮廓边：一边是实体，一边是空白
	return val1 != val2


## 从指定边开始追踪一个轮廓
static func _trace_contour_from_edge(
	binary: Array,
	w: int,
	h: int,
	start_x: int,
	start_y: int,
	start_dir: int,
	visited_edges: Dictionary
) -> PackedVector2Array:
	var contour := PackedVector2Array()
	var x := start_x
	var y := start_y
	var dir := start_dir
	
	var max_steps := w * h * 4  # 防止无限循环
	var steps := 0
	
	while steps < max_steps:
		steps += 1
		
		# 标记当前边为已访问
		var edge_key := "%d,%d,%d" % [x, y, dir]
		if visited_edges.has(edge_key):
			break
		visited_edges[edge_key] = true
		
		# 计算当前格子的 case
		var case_val := _get_case(binary, x, y)
		var edges: Array = MARCHING_SQUARES_CASES[case_val]
		
		# 找到包含当前 dir 的边对
		var found_pair := []
		for pair in edges:
			if pair[0] == dir or pair[1] == dir:
				found_pair = pair
				break
		
		if found_pair.is_empty():
			break
		
		# 计算当前边的中点坐标（图片像素坐标，需要减去 1 因为 binary 有外围一圈）
		var edge_mid := _get_edge_midpoint(x, y, dir)
		contour.append(Vector2(edge_mid.x - 1, edge_mid.y - 1))
		
		# 找到另一条边（轮廓线的另一端）
		var other_dir: int = found_pair[1] if found_pair[0] == dir else found_pair[0]
		
		# 标记另一条边为已访问
		var other_edge_key := "%d,%d,%d" % [x, y, other_dir]
		visited_edges[other_edge_key] = true
		
		# 移动到另一条边所在的格子
		var next_pos := _move_to_next_cell(x, y, other_dir)
		x = next_pos.x
		y = next_pos.y
		dir = _opposite_dir(other_dir)
		
		# 检查是否超出边界
		if x < 0 or x >= w - 1 or y < 0 or y >= h - 1:
			break
		
		# 检查是否回到起点
		if x == start_x and y == start_y and dir == start_dir:
			# 添加起点的中点，闭合轮廓
			var start_mid := _get_edge_midpoint(start_x, start_y, start_dir)
			contour.append(Vector2(start_mid.x - 1, start_mid.y - 1))
			break
	
	return contour


## 获取格子的 case（0-15）
##
## 4 个角：左上、右上、右下、左下
static func _get_case(binary: Array, x: int, y: int) -> int:
	var tl: int = binary[y][x]      # 左上
	var tr: int = binary[y][x + 1]  # 右上
	var br: int = binary[y + 1][x + 1]  # 右下
	var bl: int = binary[y + 1][x]  # 左下
	
	return (tl << 3) | (tr << 2) | (br << 1) | bl


## 获取边的中点坐标
##
## dir: 0=上, 1=右, 2=下, 3=左
static func _get_edge_midpoint(x: int, y: int, dir: int) -> Vector2:
	match dir:
		0:  # 上边
			return Vector2(x + 0.5, y)
		1:  # 右边
			return Vector2(x + 1, y + 0.5)
		2:  # 下边
			return Vector2(x + 0.5, y + 1)
		3:  # 左边
			return Vector2(x, y + 0.5)
	return Vector2.ZERO


## 移动到下一个格子
##
## dir: 0=上, 1=右, 2=下, 3=左
static func _move_to_next_cell(x: int, y: int, dir: int) -> Vector2i:
	match dir:
		0:  # 上边 -> 上面的格子
			return Vector2i(x, y - 1)
		1:  # 右边 -> 右边的格子
			return Vector2i(x + 1, y)
		2:  # 下边 -> 下面的格子
			return Vector2i(x, y + 1)
		3:  # 左边 -> 左边的格子
			return Vector2i(x - 1, y)
	return Vector2i(x, y)


## 获取相反方向
static func _opposite_dir(dir: int) -> int:
	return (dir + 2) % 4


## Douglas-Peucker 多边形简化
static func _simplify(points: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	if points.size() < 3:
		return points
	
	return _douglas_peucker(points, 0, points.size() - 1, tolerance)


## Douglas-Peucker 递归实现
static func _douglas_peucker(
	points: PackedVector2Array,
	start_idx: int,
	end_idx: int,
	tolerance: float
) -> PackedVector2Array:
	if end_idx - start_idx < 2:
		var result := PackedVector2Array()
		for i in range(start_idx, end_idx + 1):
			result.append(points[i])
		return result
	
	# 找到离首尾连线最远的点
	var start_point := points[start_idx]
	var end_point := points[end_idx]
	var max_dist := 0.0
	var max_idx := start_idx
	
	for i in range(start_idx + 1, end_idx):
		var dist := _point_to_line_distance(points[i], start_point, end_point)
		if dist > max_dist:
			max_dist = dist
			max_idx = i
	
	# 如果最远距离小于容差，丢弃中间所有点
	if max_dist <= tolerance:
		var result := PackedVector2Array()
		result.append(start_point)
		result.append(end_point)
		return result
	
	# 否则递归处理两侧
	var left := _douglas_peucker(points, start_idx, max_idx, tolerance)
	var right := _douglas_peucker(points, max_idx, end_idx, tolerance)
	
	# 合并结果（去掉 left 的最后一个点，因为和 right 的第一个点重复）
	var result := PackedVector2Array()
	for i in range(left.size() - 1):
		result.append(left[i])
	for i in range(right.size()):
		result.append(right[i])
	
	return result


## 计算点到线段的距离
static func _point_to_line_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_dir := line_end - line_start
	var line_len := line_dir.length()
	
	if line_len < 0.0001:
		return point.distance_to(line_start)
	
	var t := (point - line_start).dot(line_dir) / (line_len * line_len)
	t = clamp(t, 0.0, 1.0)
	
	var projection := line_start + line_dir * t
	return point.distance_to(projection)


## 根据高度值找到对应的高度层
static func _find_height_layer(height: float, height_definitions: Array) -> int:
	for def in height_definitions:
		if height >= def.min and height < def.max:
			return def.layer
	# 如果超出范围，返回最后一层
	if height_definitions.size() > 0:
		return height_definitions[-1].layer
	return 15
