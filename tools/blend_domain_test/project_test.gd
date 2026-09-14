extends SceneTree

## skin_direction 投影契约的性质断言（纯几何，全函数语义）。
## 运行：godot --headless --path . -s tools/blend_domain_test/project_test.gd

const EPS := 0.0001


func _angle(v: Vector2) -> float:
	return atan2(v.y, v.x)


func _same_angle(a: Vector2, b: Vector2) -> bool:
	var d: float = abs(_angle(a) - _angle(b))
	if d > PI:
		d = 2.0 * PI - d
	return d < 0.0001


func _in_domain(v: Vector2) -> bool:
	var angle: float = abs(_angle(v))
	var to_vertex: float = fmod(angle, PI / 4.0)
	to_vertex = min(to_vertex, PI / 4.0 - to_vertex)
	var boundary: float = cos(PI / 8.0) / cos(PI / 8.0 - to_vertex)
	return v.length() <= boundary + EPS


func _initialize() -> void:
	var p := load("res://addons/quiver.beat_em_up/characters/quiver_character_skin.gd")
	var pass_n := 0
	var fail_n := 0
	var checks: Array = []
	
	# 1. 玩家离散键输入经 locomotion normalized 后的 8 个精确顶点：数学恒等（零扰动证明）
	for k in 8:
		var v := Vector2.from_angle(PI / 4.0 * k)
		var out: Vector2 = p.project_to_blend_domain(v)
		checks.append([v.distance_to(out) < EPS,
				"玩家八向顶点恒等 (%.3f,%.3f)" % [v.x, v.y]])
	
	# 2. 任意角度单位向量：角度保持 + 落在域内（360° 全扫）
	var bad := 0
	for deg in 360:
		var dir := Vector2.from_angle(deg * PI / 180.0)
		var out2: Vector2 = p.project_to_blend_domain(dir)
		if not _same_angle(dir, out2) or not _in_domain(out2):
			bad += 1
	checks.append([bad == 0, "360° 全扫：角度保持且全部落入混合域（违例 %d）" % bad])
	
	# 3. 小幅度输入原样通过（慢速意图不被放大）
	for probe in [Vector2(0.3, 0.1), Vector2(0.4, -0.6), Vector2(-0.8, 0.05)]:
		var out3: Vector2 = p.project_to_blend_domain(probe)
		checks.append([probe.distance_to(out3) < EPS,
				"域内小向量恒等 (%.2f,%.2f)" % [probe.x, probe.y]])
	
	# 4. 零向量恒等
	checks.append([p.project_to_blend_domain(Vector2.ZERO) == Vector2.ZERO, "零向量恒等"])
	
	# 5. 幂等（投影再投影不动）
	var probe5 := Vector2(1.6, -1.1)
	var one: Vector2 = p.project_to_blend_domain(probe5)
	checks.append([one.distance_to(p.project_to_blend_domain(one)) < EPS, "幂等性"])
	
	# 6. 斜 45° 超界（手柄对角满推 (1,1) 不 normalized 的直达场景）→ 精确落顶点
	var corner: Vector2 = p.project_to_blend_domain(Vector2(1, 1))
	checks.append([corner.distance_to(Vector2(0.7071068, 0.7071068)) < EPS,
			"角落向量 (1,1) 投影到对角顶点"])
	
	# 7. 边中点方向（22.5°）单位向量 → 半径 cos22.5=0.9239（两节点 50/50 混合处）
	var edge_mid: Vector2 = p.project_to_blend_domain(Vector2.from_angle(PI / 8.0))
	checks.append([abs(edge_mid.length() - cos(PI / 8.0)) < EPS,
			"边中点方向投影到边（0.924）"])
	
	for c in checks:
		if c[0]:
			pass_n += 1
			print("  PASS: ", c[1])
		else:
			fail_n += 1
			print("  FAIL: ", c[1])
	print("════════ blend-domain: %d PASS / %d FAIL ════════" % [pass_n, fail_n])
	quit(0 if fail_n == 0 else 1)
