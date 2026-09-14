extends Node

## 【临时诊断探针——幽灵案结案后整文件连同模板注入一并 revert，勿演化】
##
## 每物理帧监视场上所有角色的精灵渲染链，异常（贴图空/动画名非法）时打印
## 全字段快照 + 最近 12 次状态变化环形记录；移动期按心跳行输出，供肉眼轨迹。
## 输出全部以 [GHOST-PROBE] 前缀，控制台搜这个即可。

const HEARTBEAT_EVERY := 30          ## 移动中的心跳采样间隔（物理帧）
const RING_SIZE := 12                ## 异常前史保留条数
const MAX_ANOMALY_PRINTS := 60       ## 异常打印熔断（防刷屏）

var _watched: Array[Dictionary] = []
var _frame := 0
var _anomaly_prints := 0


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	_collect.call_deferred()


func _collect() -> void:
	_watched = []
	_walk(get_tree().current_scene)
	print("[GHOST-PROBE] armed: %d 个角色被监视: %s" % [
		_watched.size(), str(_watched.map(func(w): return w["label"]))])


func _walk(node: Node) -> void:
	for child in node.get_children():
		if child is QuiverCharacter:
			_register(child)
		_walk(child)


func _register(character: QuiverCharacter) -> void:
	var skin: Node = character._skin
	if skin == null:
		return
	var sprite := _find_sprite(skin)
	if sprite == null:
		push_warning("[GHOST-PROBE] %s 找不到 AnimatedSprite2D" % character.name)
		return
	_watched.append({
		"label": "%s@%s" % [character.name,
				character.get_parent().name if character.get_parent() else "?"],
		"character": character,
		"skin": skin,
		"sprite": sprite,
		"ring": [],
		"last_sig": "",
		"anomaly_streak": 0,
	})


func _find_sprite(skin: Node) -> AnimatedSprite2D:
	for child in skin.get_children():
		if child is AnimatedSprite2D:
			return child as AnimatedSprite2D
	return null


func _physics_process(_delta: float) -> void:
	_frame += 1
	for w in _watched:
		_check(w)


func _check(w: Dictionary) -> void:
	var character: QuiverCharacter = w["character"]
	var skin: Node = w["skin"]
	var sprite: AnimatedSprite2D = w["sprite"]
	if not is_instance_valid(character) or not is_instance_valid(sprite):
		return

	var frames: SpriteFrames = sprite.sprite_frames
	var anim_name: StringName = sprite.animation
	var legit_name := frames != null and frames.has_animation(anim_name)
	# 帧索引合法性替代"当前贴图"检查（headless 无 texture 查询 API）：
	# 名字合法但当前帧越界 → SpriteFrames::get_frame_texture 返回空 = 隐形
	var frame_idx := sprite.frame
	var frame_count := frames.get_frame_count(anim_name) \
			if frames != null and legit_name else 0
	var tex_ok := legit_name and frame_idx >= 0 and frame_idx < frame_count
	var chain_visible := sprite.visible and sprite.modulate.a > 0.001
	var parent := sprite.get_parent()
	while parent is CanvasItem and chain_visible:
		chain_visible = parent.visible and parent.modulate.a > 0.001
		parent = parent.get_parent()
	# 异常 = 应该"在演"却拿不到像素：名字非法，或名字合法但当前贴图空
	var anomaly := legit_name == false or (not tex_ok and anim_name != &"")
	var moving: bool = character.channel != null \
			and character.channel.axis.length_squared() > 0.0001
	var tree_state: String = _tree_state(skin)

	# ── 状态签名变化 → 环形历史 ──
	var sig := "%s|%s|%s|%s" % [anim_name, tree_state, str(legit_name), str(tex_ok)]
	if sig != String(w["last_sig"]):
		var ring: Array = w["ring"]
		ring.append("[f%d] anim:%s tree:%s 名合法:%s 帧可显示:%s 状态机:%s" % [
				_frame, anim_name, tree_state, legit_name, tex_ok,
				str(character.state_machine.state_name)])
		if ring.size() > RING_SIZE:
			ring.pop_front()
		w["last_sig"] = sig

	# ── 异常处理 ──
	if anomaly:
		w["anomaly_streak"] = int(w["anomaly_streak"]) + 1
		if int(w["anomaly_streak"]) == 1 or int(w["anomaly_streak"]) % 30 == 0:
			if _anomaly_prints < MAX_ANOMALY_PRINTS:
				_anomaly_prints += 1
				print("[GHOST-PROBE] ★ANOMALY f=%d %s 连续第%d帧" % [
						_frame, w["label"], w["anomaly_streak"]])
				print("    anim=%s 名合法=%s sprite_frames=%s frames内名=%d" % [
						String(anim_name), legit_name, frames != null,
						frames.get_animation_names().size() if frames != null else -1])
				print("    frame=%d/%d 帧可显示=%s 可见链=%s modulate.a=%s" % [
						frame_idx, frame_count, tex_ok, chain_visible,
						sprite.modulate.a])
				print("    树状态=%s 状态机=%s" % [tree_state,
						str(character.state_machine.state_name)])
				print("    axis=%s skin_direction=%s facing_x=%s pos=%s" % [
						str(character.channel.axis), str(skin.skin_direction),
						str(skin.facing_x), str(character.global_position)])
				for line in w["ring"]:
					print("    前史 " + String(line))
	else:
		w["anomaly_streak"] = 0

	# ── 移动心跳（只给会动的角色，避免刷屏） ──
	if moving and _frame % HEARTBEAT_EVERY == 0 and not anomaly:
		print("[GHOST-PROBE] ♥ f=%d %s anim=%s 树=%s 状态机=%s axis=%s blend=%s" % [
				_frame, w["label"], String(anim_name), tree_state,
				str(character.state_machine.state_name), str(character.channel.axis),
				_blend_summary(skin)])


func _tree_state(skin: Node) -> String:
	var playback = skin.get("_playback")
	if playback is AnimationNodeStateMachinePlayback and playback != null:
		var current := str(playback.get_current_node())
		var fading := str(playback.get_fading_position())
		return current + ("⇄" + fading if not fading.is_empty() else "")
	return "?"


func _blend_summary(skin: Node) -> String:
	var tree = skin.get("_animation_tree")
	if tree == null or not (tree is AnimationTree):
		return "?"
	var parts := []
	for path in skin.get("_blend_positions_2d"):
		parts.append("%s=%s" % [String(path).replace("parameters/", ""),
				str(tree.get(path))])
	return ",".join(parts) if not parts.is_empty() else "-"
