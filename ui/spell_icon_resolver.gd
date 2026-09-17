extends RefCounted

## 法术槽图标解析器（2026-09-17）：三级回退链，结果按定义缓存（HUD 零逐帧开销）。
## ①definition.icon（美术提供即优先；约定落点 spells/<name>/resources/icons/）
## ②派生：法术皮肤 SpriteFrames 里名字含 right 的动画第 0 帧；没有则查
##    AnimationPlayer 库动画（四向产线的 FireBall/active_right 是"帧号轨"：
##    SpriteFrames 只有一条 `active` 帧序列，方向动画靠 :frame 轨道索引帧号——
##    取首键帧号定位贴图）；再退取任一动画第 0 帧
## ③null：槽位退回纯数字显示
## 引用方式 preload（class_name 全局缓存 headless 不登记，WheelProbe 同源教训）。

static var _cache: Dictionary = {}


static func icon_for(def: SpellDefinition) -> Texture2D:
	if def == null:
		return null
	if _cache.has(def):
		return _cache[def]
	var tex := _resolve(def)
	_cache[def] = tex
	return tex


static func _resolve(def: SpellDefinition) -> Texture2D:
	if def.icon != null:
		return def.icon
	if def.spell_scene == null:
		return null
	var inst := def.spell_scene.instantiate()
	if inst == null:
		return null
	var tex := _derive(inst)
	inst.free()
	return tex


static func _derive(inst: Node) -> Texture2D:
	var sprite := _find_sprite(inst)
	if sprite == null or sprite.sprite_frames == null:
		return null
	var sf: SpriteFrames = sprite.sprite_frames
	var names := _sf_anim_names(sf)
	# ②a SpriteFrames 自带 right 向动画（active 型优先，hit/ending 不抓）
	for want_active in [true, false]:
		for n in names:
			if "right" not in n or sf.get_frame_count(n) <= 0:
				continue
			if want_active != ("active" in n):
				continue
			return sf.get_frame_texture(n, 0)
	# ②b 四向产线：right 藏在 AnimationPlayer 库动画的帧号轨里
	var via_lib := _from_frame_track(inst, sf, names)
	if via_lib != null:
		return via_lib
	# ②c 任一动画第 0 帧
	for n in names:
		if sf.get_frame_count(n) > 0:
			return sf.get_frame_texture(n, 0)
	return null


static func _from_frame_track(inst: Node, sf: SpriteFrames, names: PackedStringArray) -> Texture2D:
	for p in inst.find_children("*", "AnimationPlayer", true, false):
		var ap := p as AnimationPlayer
		var lib_names: PackedStringArray = ap.get_animation_list()
		var target := ""
		for want_active in [true, false]:
			for an_name in lib_names:
				var n := String(an_name)
				if "right" not in n or n.ends_with("hit_right") or "hit" in n or "ending" in n:
					continue
				if want_active != ("active" in n):
					continue
				target = n
				break
			if not target.is_empty():
				break
		if target.is_empty():
			continue
		var anim: Animation = ap.get_animation(target)
		for i in anim.get_track_count():
			if anim.track_get_type(i) != Animation.TYPE_VALUE:
				continue
			if not String(anim.track_get_path(i)).ends_with(":frame"):
				continue
			if anim.track_get_key_count(i) == 0:
				continue
			var frame_idx := int(anim.track_get_key_value(i, 0))
			var host := "active" if names.has("active") else (names[0] if not names.is_empty() else "")
			if host.is_empty() or frame_idx >= sf.get_frame_count(host):
				continue
			return sf.get_frame_texture(host, frame_idx)
	return null


static func _sf_anim_names(sf: SpriteFrames) -> PackedStringArray:
	if sf.has_method("get_animation_names"):
		return sf.get_animation_names()
	return sf.get_animation_list()


static func _find_sprite(n: Node) -> AnimatedSprite2D:
	if n is AnimatedSprite2D:
		return n
	for c in n.get_children():
		var r = _find_sprite(c)
		if r != null:
			return r
	return null


static func _find_anim_tree(n: Node) -> AnimationTree:
	if n is AnimationTree:
		return n
	for c in n.get_children():
		var r = _find_anim_tree(c)
		if r != null:
			return r
	return null
