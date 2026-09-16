extends SceneTree

## 轮廓排序契约测试（headless 直跑）：
##   多分量图（大主体+顶部小碎片）经 trace_contours 后，[0] 必须是面积最大轮廓。
##   这是 2026-09-16 火球针帧事故的根修复的防回归桩。
## 运行：godot --headless --path . -s tools/contour_sort_test/trace_sort.gd

func _init() -> void:
	var fails := 0
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# 主体：下方 32x32 实心块
	for y in range(30, 62):
		for x in range(16, 48):
			img.set_pixel(x, y, Color(1, 1, 1, 1))
	# 碎片：上方 4x4 小块（像素扫描顺序它在前，模拟火苗）
	for y in range(4, 8):
		for x in range(30, 34):
			img.set_pixel(x, y, Color(1, 1, 1, 1))
	
	var contours := ContourTracer.trace_contours(img, null, 0.5, 1.0, 512, 0.001, 0)
	if contours.size() < 2:
		prints("FAIL: 应至少两条轮廓，实得", contours.size())
		fails += 1
	else:
		var a0 := absf(_shoelace(contours[0]))
		var a1 := absf(_shoelace(contours[1]))
		var ok := a0 >= a1
		prints("PASS:" if ok else "FAIL:", " contours[0] 面积=%.0f >= [1] 面积=%.0f（共 %d 条）" % [a0, a1, contours.size()])
		if not ok:
			fails += 1
	
	print("════════ trace-sort: %s ════════" % ("PASS" if fails == 0 else "FAIL"))
	quit(0 if fails == 0 else 1)


func _shoelace(poly: PackedVector2Array) -> float:
	var area := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		area += a.x * b.y - b.x * a.y
	return area / 2.0
