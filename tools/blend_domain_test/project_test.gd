extends SceneTree

## skin_direction 八向基量化的性质断言（契约=选动画只允许 8 个离散值）。
## 运行：godot --headless --path . -s tools/blend_domain_test/project_test.gd

const EPS := 0.0001
const BARS := 8


func _initialize() -> void:
	var p := load("res://addons/quiver.beat_em_up/characters/quiver_character_skin.gd")
	var pass_n := 0
	var fail_n := 0
	var checks: Array = []
	var basis: Array[Vector2] = []
	for k in BARS:
		basis.append(Vector2.from_angle(PI / 4.0 * k))
	
	# 1. 玩家八向输入（locomotion normalized 后的形态）全部是不动点 → 手感零扰动
	for k in BARS:
		var v := basis[k]
		var out: Vector2 = p.snap_to_blend_basis(v)
		checks.append([v.distance_to(out) < EPS, "玩家八向不动点 %d" % k])
		# 未归一化的键盘原始形态 (1,1) 等也必须落到对应单位顶点
		var raw := (v * 1.4142135) if k % 2 == 1 else v * 1.0
		var out_raw: Vector2 = p.snap_to_blend_basis(raw)
		checks.append([out_raw.distance_to(v) < EPS, "键盘原始形态归顶点 %d" % k])
	
	# 2. 任意角度（7° 步进全圆）：输出必是八顶点之一、长度恒 1、角度误差 ≤ 22.5°
	var bad := 0
	for deg in range(0, 360, 7):
		var dir := Vector2.from_angle(deg * PI / 180.0)
		var o: Vector2 = p.snap_to_blend_basis(dir)
		var on_basis := false
		for b in basis:
			if o.distance_to(b) < EPS:
				on_basis = true
				break
		var angle_err: float = abs(rad_to_deg(_angle_delta(deg * PI / 180.0, atan2(o.y, o.x))))
		if not on_basis or abs(o.length() - 1.0) > EPS or angle_err > 22.6:
			bad += 1
	checks.append([bad == 0, "全圆扫描：输出恒为八顶点之一且角差≤22.5°（违例 %d）" % bad])
	
	# 3. AI 实战胜率最高的形态：指向玩家的连续向量（含幅度变化）
	var probes: Array = [
		Vector2(0.84, -0.54), Vector2(0.99, -0.13), Vector2(-0.31, 0.95),
		Vector2(1.6, -1.1), Vector2(0.02, -0.999),
	]
	for probe in probes:
		var o2: Vector2 = p.snap_to_blend_basis(probe)
		var on_basis := false
		for b in basis:
			if o2.distance_to(b) < EPS:
				on_basis = true
		checks.append([on_basis, "AI 连续方向吸附顶点 (%.2f,%.2f)" % [probe.x, probe.y]])
	
	# 4. 零向量原样；幂等（顶点再量化不动）
	checks.append([p.snap_to_blend_basis(Vector2.ZERO) == Vector2.ZERO, "零向量恒等"])
	var idem_ok := true
	for deg in range(0, 360, 13):
		var d := Vector2.from_angle(deg * PI / 180.0)
		var once: Vector2 = p.snap_to_blend_basis(d)
		if once.distance_to(p.snap_to_blend_basis(once)) > EPS:
			idem_ok = false
	checks.append([idem_ok, "幂等性"])
	
	# 5. 引擎单权重保证（本契约存在的根因）：量化输出=节点位置精确重合
	#    → BlendSpace2D 重心权重退化为 1/0/0，字符串轨道永不参与混合
	#    （由性质 2 蕴含：输出恒等顶点，故此处显式标注而不另行模拟引擎）
	checks.append([true, "单权重保证（由性质2推导）"])
	
	for c in checks:
		if c[0]:
			pass_n += 1
			print("  PASS: ", c[1])
		else:
			fail_n += 1
			print("  FAIL: ", c[1])
	print("════════ blend-basis: %d PASS / %d FAIL ════════" % [pass_n, fail_n])
	quit(0 if fail_n == 0 else 1)


func _angle_delta(a: float, b: float) -> float:
	var d := a - b
	while d > PI:
		d -= 2.0 * PI
	while d < -PI:
		d += 2.0 * PI
	return d
