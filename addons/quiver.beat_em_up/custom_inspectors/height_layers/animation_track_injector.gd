@tool
class_name AnimationTrackInjector
extends RefCounted
## 动画轨道注入器
##
## 从 SpriteFrames 读取动画帧文件名，解析高度标注，生成 value tracks 和 method tracks。
## 将生成的轨道写入 Animation 资源并保存。
##
## 工作流程：
## 1. 从 Skin 节点的 AnimatedSprite2D 获取 SpriteFrames
## 2. 从 Skin 节点的 AnimationPlayer 获取 AnimationLibrary
## 3. 用 CharacterHeightData.parse_height_from_filename 解析 SpriteFrames 的每个帧文件名
## 4. 对 AnimationLibrary 中每个 Animation：
##    a. 找到它引用的 SpriteFrames 子动画名（通过 AnimatedSprite2D:animation track）
##    b. 根据子动画帧数和 fps 生成时间轴
##    c. 插入 physical_height / attack_heights 轨道
## 5. 保存修改后的 Animation 资源

### Member Variables and Dependencies -------------------------------------------------------------

const CharacterHeightData = preload(
	"res://addons/quiver.beat_em_up/custom_inspectors/height_layers/"
	+ "character_height_data.gd"
)

# 高度轨道路径
# 高度层数据存放在 QuiverCharacterSkin 节点（AnimationPlayer 的根节点目标）
# 在 chen_jingchou_skin.tscn 中 AnimationPlayer 是 ChenJingchouSkin 的子节点
# root_node 默认值 = ".."（AnimationPlayer 的父节点 = ChenJingchouSkin）
# track path 相对 root_node 解析：无前缀直接访问 Skin 节点自身的属性
const TRACK_PATH_PHYSICAL_HEIGHT := ".:physical_height"
const TRACK_PATH_ATTACK_HEIGHTS := ".:attack_heights"
const TRACK_PATH_CAPSULE_HEIGHT := "../../Collision:shape.height"  # CapsuleShape2D 的 height 属性
const TRACK_PATH_BASE_HEIGHT_METHOD := "."  # method 调用 Skin 节点自身
const METHOD_NAME_SYNC_BASE_HEIGHT := "_sync_base_height"

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## 执行扫描和注入
## skin_node: QuiverCharacterSkinAnimTree 节点
## dry_run: 如果为 true，只预览不实际写入文件
## 返回: { anim_count: int, frame_count: int, errors: Array[String], height_data: CharacterHeightData, animations_to_modify: Array[String] }
func run(skin_node: Node, dry_run: bool = false) -> Dictionary:
	var result := {
		"anim_count": 0,
		"frame_count": 0,
		"errors": [] as Array[String],
		"height_data": CharacterHeightData.new(),
		"animations_to_modify": [] as Array[String],
		"jump_speed_info": {},
	}
	
	# 1. 获取 AnimatedSprite2D.sprite_frames
	var sprite_frames := _get_sprite_frames(skin_node, result.errors)
	if sprite_frames == null:
		return result
	
	# 2. 获取 AnimationPlayer
	var anim_player := _get_animation_player(skin_node, result.errors)
	if anim_player == null:
		return result
	
	# 3. 验证场景树结构并设置 AnimationPlayer.root_node
	if not _validate_and_set_root_node(anim_player, result.errors):
		return result
	
	# 4. 预解析 SpriteFrames 里所有子动画的帧文件名
	_collect_sprite_frame_heights(sprite_frames, result.height_data, result.errors)
	result.anim_count = sprite_frames.get_animation_names().size()
	for anim_name in sprite_frames.get_animation_names():
		result.frame_count += sprite_frames.get_frame_count(anim_name)
	
	# 5. 注入轨道到每个 Animation 资源
	_inject_to_library(anim_player, sprite_frames, result.height_data, result.errors, result.animations_to_modify, dry_run)
	
	# 6. 提取跳跃动画的 speed 值并写入 QuiverAttributes.jump_force
	result.jump_speed_info = _extract_and_apply_speed_values(skin_node, result.height_data, result.errors, dry_run)
	
	return result


## 增量执行扫描和注入（异步，不会阻塞编辑器界面）
## skin_node: QuiverCharacterSkinAnimTree 节点
## dry_run: 如果为 true，只预览不实际写入文件
## callback_obj: 拥有 _on_progress(current, total, anim_name) 方法的对象，用于进度更新
## 返回: { anim_count: int, frame_count: int, errors: Array[String], height_data: CharacterHeightData, animations_to_modify: Array[String] }
func run_incremental(skin_node: Node, dry_run: bool = false, callback_obj: Object = null) -> Dictionary:
	var result := {
		"anim_count": 0,
		"frame_count": 0,
		"errors": [] as Array[String],
		"height_data": CharacterHeightData.new(),
		"animations_to_modify": [] as Array[String],
		"jump_speed_info": {},
	}
	
	# 1. 获取 AnimatedSprite2D.sprite_frames
	var sprite_frames := _get_sprite_frames(skin_node, result.errors)
	if sprite_frames == null:
		return result
	
	# 2. 获取 AnimationPlayer
	var anim_player := _get_animation_player(skin_node, result.errors)
	if anim_player == null:
		return result
	
	# 3. 验证场景树结构并设置 AnimationPlayer.root_node
	if not _validate_and_set_root_node(anim_player, result.errors):
		return result
	
	# 4. 预解析 SpriteFrames 里所有子动画的帧文件名
	_collect_sprite_frame_heights(sprite_frames, result.height_data, result.errors)
	result.anim_count = sprite_frames.get_animation_names().size()
	for anim_name in sprite_frames.get_animation_names():
		result.frame_count += sprite_frames.get_frame_count(anim_name)
	
	# 5. 增量注入轨道到每个 Animation 资源（异步）
	await _inject_to_library_incremental(anim_player, sprite_frames, result.height_data, result.errors, result.animations_to_modify, dry_run, callback_obj)
	
	# 6. 提取跳跃动画的 speed 值并写入 QuiverAttributes.jump_force
	result.jump_speed_info = _extract_and_apply_speed_values(skin_node, result.height_data, result.errors, dry_run)
	
	return result


### Private Methods -------------------------------------------------------------------------------

## 获取 SpriteFrames
func _get_sprite_frames(skin_node: Node, errors: Array[String]) -> SpriteFrames:
	var sprite_node := skin_node.get_node_or_null("AnimatedSprite2D")
	if sprite_node == null:
		errors.append("未找到 AnimatedSprite2D 子节点")
		return null
	
	var sprite_frames: SpriteFrames = sprite_node.sprite_frames
	if sprite_frames == null:
		errors.append("AnimatedSprite2D 未配置 sprite_frames")
		return null
	
	return sprite_frames


## 获取 AnimationPlayer
func _get_animation_player(skin_node: Node, errors: Array[String]) -> AnimationPlayer:
	var anim_player := skin_node.get_node_or_null("AnimationPlayer")
	if anim_player == null:
		errors.append("未找到 AnimationPlayer 子节点")
		return null
	return anim_player


## 验证场景树结构（不修改 root_node）
## 
## 预期结构：
##   Parent (任意节点或场景根) -> Skin (QuiverCharacterSkin) -> AnimationPlayer
## 
## 验证逻辑：
##   1. AnimationPlayer 必须有父节点（即 Skin 节点）
##   2. 该父节点必须是 QuiverCharacterSkin 或其子类
## 
## 不再要求 Skin 必须有 QuiverCharacter 父节点，因为：
##   - 方案 C 使用无前缀路径（如 "physical_height"）
##   - AnimationPlayer 默认 root_node = ".."（AnimationPlayer 的直接父节点）
##   - 所以无前缀路径相对 Skin 解析，能直接访问 Skin 上的属性
func _validate_and_set_root_node(anim_player: AnimationPlayer, errors: Array[String]) -> bool:
	# 获取 AnimationPlayer 的父节点（应该是 Skin）
	var skin_node := anim_player.get_parent()
	if skin_node == null:
		errors.append("AnimationPlayer 没有父节点（预期：QuiverCharacterSkin 节点）")
		return false
	
	# 验证父节点是 QuiverCharacterSkin 或其子类
	if not (skin_node is QuiverCharacterSkin):
		errors.append("AnimationPlayer 的父节点不是 QuiverCharacterSkin（实际类型：%s）" % 
			str(skin_node.get_class()))
		return false
	
	return true


## 预解析 SpriteFrames 的所有子动画帧文件名，填充到 CharacterHeightData
## 数据结构：{ sprite_anim_name: { frame_idx: parsed_data, ... }, ... }
func _collect_sprite_frame_heights(
	sprite_frames: SpriteFrames,
	height_data: CharacterHeightData,
	errors: Array[String]
) -> void:
	for sprite_anim_name in sprite_frames.get_animation_names():
		var frame_count := sprite_frames.get_frame_count(sprite_anim_name)
		for frame_idx in range(frame_count):
			var texture := sprite_frames.get_frame_texture(sprite_anim_name, frame_idx)
			if texture == null:
				errors.append("SpriteFrames 动画 '%s' 帧 %d: 缺少纹理" % [
					sprite_anim_name, frame_idx
				])
				continue
			
			var file_path := texture.resource_path
			var parsed: Dictionary = CharacterHeightData.parse_height_from_filename(file_path)
			
			# 检查是否有有效的 physical_height
			if parsed.get("physical", -1.0) < 0.0:
				errors.append("SpriteFrames 动画 '%s' 帧 %d: 文件名无 physical 标注 (%s)" % [
					sprite_anim_name, frame_idx, file_path.get_file()
				])
				continue
			
			height_data.add_frame_data(sprite_anim_name, frame_idx, parsed)


## 注入轨道到 AnimationLibrary 中所有 Animation 资源
## animations_to_modify: 输出参数，记录会被修改的动画名称
## dry_run: 如果为 true，只记录不实际修改
func _inject_to_library(
	anim_player: AnimationPlayer,
	sprite_frames: SpriteFrames,
	height_data: CharacterHeightData,
	errors: Array[String],
	animations_to_modify: Array[String],
	dry_run: bool
) -> void:
	var lib_names := anim_player.get_animation_library_list()
	if lib_names.is_empty():
		errors.append("AnimationPlayer 无任何 AnimationLibrary")
		return
	
	var modified_count := 0
	
	for lib_name in lib_names:
		var library: AnimationLibrary = anim_player.get_animation_library(lib_name)
		if library == null:
			continue
		
		var anim_names := library.get_animation_list()
		for anim_name in anim_names:
			var anim := library.get_animation(anim_name)
			if anim == null:
				continue
			
			# 找到此 Animation 引用的 SpriteFrames 子动画名
			var sprite_anim_name := _find_sprite_anim_name(anim)
			if sprite_anim_name.is_empty():
				# 没有 AnimatedSprite2D:animation track，跳过
				continue
			
			# 检查是否有高度数据
			if not height_data.has_animation(sprite_anim_name):
				continue
			
			# 记录会被修改的动画
			animations_to_modify.append(anim_name)
			
			# 如果不是 dry_run，实际注入轨道
			if not dry_run:
				# 注入轨道
				_inject_single_animation(
					anim,
					sprite_anim_name,
					sprite_frames.get_animation_speed(sprite_anim_name),
					sprite_frames.get_frame_count(sprite_anim_name),
					height_data.get_animation_data(sprite_anim_name),
					errors
				)
			modified_count += 1
	
	if modified_count == 0:
		errors.append("无 Animation 被修改（可能无 AnimatedSprite2D:animation track 或缺少高度标注）")


## 增量注入轨道到 AnimationLibrary 中的所有 Animation 资源（异步，不会阻塞界面）
## 每处理一个动画就 yield 一次，让编辑器有机会更新界面
## callback_obj: 拥有 _on_progress(current, total, anim_name) 方法的对象，用于进度更新
func _inject_to_library_incremental(
	anim_player: AnimationPlayer,
	sprite_frames: SpriteFrames,
	height_data: CharacterHeightData,
	errors: Array[String],
	animations_to_modify: Array[String],
	dry_run: bool,
	callback_obj: Object
) -> void:
	var lib_names := anim_player.get_animation_library_list()
	if lib_names.is_empty():
		errors.append("AnimationPlayer 无任何 AnimationLibrary")
		return
	
	# 先统计要处理的动画总数
	var total_animations := 0
	var animations_to_process := []
	
	for lib_name in lib_names:
		var library: AnimationLibrary = anim_player.get_animation_library(lib_name)
		if library == null:
			continue
		
		var anim_names := library.get_animation_list()
		for anim_name in anim_names:
			var anim := library.get_animation(anim_name)
			if anim == null:
				continue
			
			# 找到此 Animation 引用的 SpriteFrames 子动画名
			var sprite_anim_name := _find_sprite_anim_name(anim)
			if sprite_anim_name.is_empty():
				continue
			
			# 检查是否有高度数据
			if not height_data.has_animation(sprite_anim_name):
				continue
			
			animations_to_process.append({
				"anim_name": anim_name,
				"anim": anim,
				"sprite_anim_name": sprite_anim_name
			})
			total_animations += 1
	
	if total_animations == 0:
		errors.append("无 Animation 被修改（可能无 AnimatedSprite2D:animation track 或缺少高度标注）")
		return
	
	# 增量处理每个动画
	var current := 0
	for anim_info in animations_to_process:
		current += 1
		
		# 调用进度回调
		if callback_obj != null and callback_obj.has_method("_on_progress"):
			callback_obj._on_progress(current, total_animations, anim_info.anim_name)
		
		# 记录会被修改的动画
		animations_to_modify.append(anim_info.anim_name)
		
		# 如果不是 dry_run，实际注入轨道
		if not dry_run:
			_inject_single_animation(
				anim_info.anim,
				anim_info.sprite_anim_name,
				sprite_frames.get_animation_speed(anim_info.sprite_anim_name),
				sprite_frames.get_frame_count(anim_info.sprite_anim_name),
				height_data.get_animation_data(anim_info.sprite_anim_name),
				errors
			)
		
		# yield 一次，让编辑器有机会更新界面和响应用户输入
		if callback_obj != null and callback_obj.has_method("get_tree"):
			var tree = callback_obj.get_tree()
			if tree != null:
				await tree.process_frame


## 找到 Animation 引用的 SpriteFrames 子动画名
## 通过查找 tracks[?] 的 path 是 AnimatedSprite2D:animation 的 track，
## 取其第一个 StringName value
func _find_sprite_anim_name(anim: Animation) -> String:
	for track_idx in range(anim.get_track_count()):
		if anim.track_get_type(track_idx) != Animation.TYPE_VALUE:
			continue
		var track_path := anim.track_get_path(track_idx)
		if str(track_path) == "AnimatedSprite2D:animation":
			# 取第一个 key（通常每帧动画只切换一次子动画）
			if anim.track_get_key_count(track_idx) > 0:
				var value = anim.track_get_key_value(track_idx, 0)
				if value is StringName:
					return String(value)
				elif value is String:
					return value
	return ""


## 为单个 Animation 注入 height tracks
## frame_data: { frame_idx: parsed_data, ... }
func _inject_single_animation(
	anim: Animation,
	sprite_anim_name: String,
	sprite_fps: float,
	sprite_frame_count: int,
	frame_data: Dictionary,
	errors: Array[String]
) -> void:
	# 1. 移除旧的 height tracks
	_remove_old_height_tracks(anim)
	
	# 2. 添加新的 tracks
	var physical_track_idx := _add_value_track(anim, TRACK_PATH_PHYSICAL_HEIGHT)
	var width_track_idx := _add_value_track(anim, TRACK_PATH_CAPSULE_HEIGHT)
	var attack_track_idx := _add_value_track(anim, TRACK_PATH_ATTACK_HEIGHTS)
	
	# 3. 计算 sprite 的帧间隔
	var frame_duration: float = 1.0 / max(1.0, sprite_fps)
	
	# 4. 逐帧插入 keys（优化：只在值变化时添加 keyframe）
	var inserted_count := 0
	var prev_physical = null  # 用于检测 physical_height 变化
	var prev_width = null     # 用于检测 width 变化
	var prev_attack = null    # 用于检测 attack_heights 变化
	
	for frame_idx in range(sprite_frame_count):
		var data: Dictionary = frame_data.get(frame_idx, {})
		if data.is_empty():
			continue
		
		var time: float = float(frame_idx) * frame_duration
		
		# physical_height 关键帧（只在值变化时插入）
		if data.has("physical"):
			var current_physical = data["physical"]
			if current_physical != prev_physical:
				anim.track_insert_key(physical_track_idx, time, current_physical)
				prev_physical = current_physical
		
		# width (CapsuleShape2D.height) 关键帧（只在值变化时插入）
		if data.has("width"):
			var current_width = data["width"]
			if current_width != prev_width:
				anim.track_insert_key(width_track_idx, time, current_width)
				prev_width = current_width
		
		# attack_heights 关键帧（只在值变化时插入）
		var current_attack: Array = data.get("attack_heights", [])
		if current_attack != prev_attack:
			anim.track_insert_key(attack_track_idx, time, current_attack)
			prev_attack = current_attack
		
		inserted_count += 1
	
	if inserted_count == 0:
		errors.append("动画 '%s': 无帧数据被注入" % anim.resource_name)
		return
	
	# 5. 保存 Animation 资源（必须在文件系统内）
	var resource_path := anim.resource_path
	if resource_path.is_empty():
		errors.append("动画 '%s' 无资源路径，无法保存" % anim.resource_name)
		return
	
	var err := ResourceSaver.save(anim, resource_path)
	if err != OK:
		errors.append("动画 '%s' 保存失败 (error=%d)" % [anim.resource_name, err])


## 移除旧的 height tracks
## 对于 value tracks：通过路径匹配删除
## 对于 method tracks：通过路径 + 方法名匹配，删除已废弃的 _sync_base_height tracks（保留原始方法）
func _remove_old_height_tracks(anim: Animation) -> void:
	var tracks_to_remove := []
	
	# value track 路径列表（当前版本 + 历史版本）
	var value_track_paths := [
		# 当前版本路径（.: 前缀，访问 root_node 自身属性）
		TRACK_PATH_PHYSICAL_HEIGHT,      # ".:physical_height"
		TRACK_PATH_ATTACK_HEIGHTS,       # ".:attack_heights"
		TRACK_PATH_CAPSULE_HEIGHT,       # "../../Collision:shape.height"
		# 历史版本路径 1：无前缀但缺少 . 前缀
		"physical_height",
		"attack_heights",
		# 历史版本路径 2：../ 前缀
		"../physical_height",
		"../attack_heights",
		# 历史版本路径 3：../../ 前缀
		"../../physical_height",
		"../../attack_heights",
	]
	
	# method track 路径列表（当前版本 + 历史版本）
	var method_track_paths := [
		TRACK_PATH_BASE_HEIGHT_METHOD,   # "."
		"..",
		"../..",
	]
	
	for track_idx in range(anim.get_track_count()):
		var track_path_str := str(anim.track_get_path(track_idx))
		var track_type := anim.track_get_type(track_idx)
		
		# 对于 value tracks，通过路径匹配
		if track_type == Animation.TYPE_VALUE and track_path_str in value_track_paths:
			tracks_to_remove.append(track_idx)
			continue
		
		# 对于 method tracks，需要额外检查方法名
		# 只删除我们的 _sync_base_height，保留原始方法（end_of_input_frames, end_of_skin_animation 等）
		if track_type == Animation.TYPE_METHOD and track_path_str in method_track_paths:
			var should_remove := false
			for key_idx in range(anim.track_get_key_count(track_idx)):
				var method_dict = anim.track_get_key_value(track_idx, key_idx)
				if method_dict.get("method") == METHOD_NAME_SYNC_BASE_HEIGHT:
					should_remove = true
					break
			if should_remove:
				tracks_to_remove.append(track_idx)
	
	# 从后往前删除避免索引偏移
	for i in range(tracks_to_remove.size() - 1, -1, -1):
		anim.remove_track(tracks_to_remove[i])


## 添加 value track（discrete interp，update mode discontinuous）
func _add_value_track(anim: Animation, track_path: String) -> int:
	var track_idx := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track_idx, track_path)
	anim.track_set_interpolation_type(track_idx, Animation.INTERPOLATION_NEAREST)
	anim.value_track_set_update_mode(track_idx, Animation.UPDATE_DISCRETE)
	return track_idx


## 从跳跃和击飞动画首帧提取 speed 值，写入 QuiverAttributes
##
## 逻辑：
## 1. 遍历 height_data，找到名称含 "jump" 或 "knockout" 的 SpriteFrames 子动画
## 2. 检查首帧（frame 0）是否有 speed 标注
## 3. jump 动画：设置 jump_force = -speed（正数 speed → 负数 jump_force）
## 4. knockout 动画：设置 knockback_weight = speed（直接作为权重）
## 5. 保存 QuiverAttributes 资源
##
## 返回：{ "jump": {...}, "knockout": {...} } 或空字典
func _extract_and_apply_speed_values(
	skin_node: Node,
	height_data: CharacterHeightData,
	errors: Array[String],
	dry_run: bool
) -> Dictionary:
	var info := {}
	
	# 收集 jump 和 knockout 的 speed 值
	var jump_data := {}
	var knockout_data := {}
	
	for sprite_anim_name in height_data.frame_heights.keys():
		var is_jump: bool = sprite_anim_name.contains("jump") and not sprite_anim_name.contains("knockout")
		var is_knockout: bool = sprite_anim_name.contains("knockout")
		
		if not is_jump and not is_knockout:
			continue
		
		# 检查首帧（frame 0）的 speed 值
		var frame_data: Dictionary = height_data.frame_heights[sprite_anim_name]
		var frame_0: Dictionary = frame_data.get(0, {})
		if frame_0.is_empty():
			continue
		
		var speed = frame_0.get("speed", null)
		if speed == null:
			continue  # 静默跳过，不报错（speed 是可选的）
		
		var speed_value: float = float(speed)
		
		if is_jump:
			jump_data = {
				"anim_name": sprite_anim_name,
				"speed": speed_value,
				"jump_force": -abs(speed_value),
			}
		elif is_knockout:
			knockout_data = {
				"anim_name": sprite_anim_name,
				"speed": speed_value,
				"knockback_weight": speed_value,
			}
	
	# 如果没有找到任何 speed 标注，直接返回
	if jump_data.is_empty() and knockout_data.is_empty():
		return info
	
	# 记录 speed 信息（无论 dry_run 与否都返回）
	if not jump_data.is_empty():
		info["jump"] = jump_data
	if not knockout_data.is_empty():
		info["knockout"] = knockout_data
	
	if dry_run:
		# dry_run 模式只记录，不实际修改
		return info
	
	# 导航到 QuiverAttributes：skin_node -> QuiverCharacter -> attributes
	var character := skin_node.get_parent() as QuiverCharacter
	if character == null:
		errors.append("无法获取 QuiverCharacter（Skin 的父节点不是 QuiverCharacter）")
		return info
	
	var attributes: QuiverAttributes = character.attributes
	if attributes == null:
		errors.append("QuiverCharacter.attributes 未配置")
		return info
	
	var needs_save := false
	
	# 设置 jump_force
	if not jump_data.is_empty():
		var new_jump_force: float = -abs(jump_data["speed"])
		if not is_equal_approx(attributes.jump_force, new_jump_force):
			attributes.jump_force = new_jump_force
			needs_save = true
	
	# 设置 knockback_weight
	if not knockout_data.is_empty():
		var new_weight: float = knockout_data["speed"]
		if not is_equal_approx(attributes.knockback_weight, new_weight):
			attributes.knockback_weight = new_weight
			needs_save = true
	
	# 保存 QuiverAttributes 资源
	if needs_save:
		var resource_path := attributes.resource_path
		if resource_path.is_empty():
			errors.append("QuiverAttributes 无资源路径，无法保存 speed 值")
			return info
		
		var err := ResourceSaver.save(attributes, resource_path)
		if err != OK:
			errors.append("QuiverAttributes 保存失败 (error=%d)" % err)
	
	return info

### -----------------------------------------------------------------------------------------------
