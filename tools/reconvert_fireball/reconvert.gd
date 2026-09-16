extends Node

## 一次性：headless 重跑 fire_ball 的 Attack 轮廓转换（胶囊参数），
## 验证"面积排序修"消除针帧。落盘：动画 .tres 由注入器自动保存；
## 场景静态默认值从活体节点打印，由外层文本手术同步进 .tscn。
## 运行：godot --headless --path . res://tools/reconvert_fireball/reconvert.tscn

const SKIN_TSCN := "res://spells/fire_ball/fire_ball_skin.tscn"
const AnimationTrackInjector = preload(
	"res://addons/quiver.beat_em_up/custom_inspectors/height_layers/animation_track_injector.gd")

func _ready() -> void:
	await get_tree().physics_frame
	var skin: Node = (load(SKIN_TSCN) as PackedScene).instantiate()
	add_child(skin)
	for _i in 3:
		await get_tree().physics_frame
	
	var injector = AnimationTrackInjector.new()
	var result: Dictionary = await injector.convert_attack_contours(
			skin, 0.5, 100.0, 0.3, 0, 1, false, self)
	
	print("════════ reconvert: errors=", result.get("errors", []), " frames=", result.get("frame_count", 0))
	var shape_node := skin.get_node_or_null("Attacks/Attack1/Attack1Shape")
	if shape_node != null:
		var sh = shape_node.shape
		print("STATIC Attack1Shape type=", shape_node.get_class(),
				" pos=", shape_node.position, " rot=", shape_node.rotation,
				" radius=", sh.radius if sh is CapsuleShape2D else "n/a",
				" height=", sh.height if sh is CapsuleShape2D else "n/a")
		if bool(shape_node.disabled):
			print("WARN: 活体 disabled=true（轨道首键才是运行时真相）")
	print("STATIC Attack1:position=", (skin.get_node_or_null("Attacks/Attack1") as Node2D).position)
	print("STATIC attack_heights=", skin.attack_heights)
	
	# 循环信标摘除（2026-09-16 定罪）：飞行动画上的 end_of_spell_animation 是
	# 每圈误响的死线，删除并保存（injector 不写方法轨道，摘除是永久的）。
	var aplayer := skin.get_node("AnimationPlayer") as AnimationPlayer
	var stripped := 0
	for lib_name in aplayer.get_animation_library_list():
		var lib := aplayer.get_animation_library(lib_name)
		if lib == null:
			continue
		for anim_name in lib.get_animation_list():
			var anim := lib.get_animation(anim_name)
			if anim == null or not String(anim_name).begins_with("active"):
				continue
			if anim.loop_mode == Animation.LOOP_NONE:
				continue
			var doomed: Array[int] = []
			for ti in range(anim.get_track_count()):
				if anim.track_get_type(ti) != Animation.TYPE_METHOD:
					continue
				for k in range(anim.track_get_key_count(ti)):
					if String(anim.method_track_get_name(ti, k)) == "end_of_spell_animation":
						doomed.append(ti)
						break
			for ti in doomed:
				anim.remove_track(ti)
				stripped += 1
			if not doomed.is_empty():
				var err := ResourceSaver.save(anim, anim.resource_path)
				print("摘除 %s 信标 %d 条 保存=%s" % [anim_name, doomed.size(), err])
	print("════════ 信标摘除完成（本次共 %d 条）" % stripped)
	
	# 针帧复检（库名不假设，遍历找 active_right）
	var player := skin.get_node("AnimationPlayer") as AnimationPlayer
	var anim: Animation = null
	for lib_name in player.get_animation_library_list():
		var lib := player.get_animation_library(lib_name)
		if lib != null and lib.has_animation(&"active_right"):
			anim = lib.get_animation(&"active_right")
			break
	if anim == null:
		print("════════ 针帧复检: 找不到 active_right ✗")
		get_tree().quit(1)
		return
	var min_r := INF
	var seen := false
	for i in range(anim.get_track_count()):
		if str(anim.track_get_path(i)).ends_with("shape:radius"):
			seen = true
			for k in range(anim.track_get_key_count(i)):
				min_r = min(min_r, float(anim.track_get_key_value(i, k)))
	if not seen:
		print("════════ 针帧复检: 无 radius 轨道 ✗（转换或轨道布局异常）")
		get_tree().quit(1)
		return
	print("════════ 针帧复检: 最小半径=%.2f（阈值 10px） %s" % [
			min_r, "无针帧 ✓" if min_r >= 10.0 else "仍有针 ✗"])
	get_tree().quit(0 if min_r >= 10.0 else 1)
