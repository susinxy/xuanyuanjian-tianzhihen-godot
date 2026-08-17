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

const ContourTracer = preload(
	"res://addons/quiver.beat_em_up/custom_inspectors/height_layers/"
	+ "contour_tracer.gd"
)

# 高度轨道路径
# 高度层数据存放在 QuiverCharacterSkin 节点（AnimationPlayer 的根节点目标）
# 在 chen_jingchou_skin.tscn 中 AnimationPlayer 是 ChenJingchouSkin 的子节点
# root_node 默认值 = ".."（AnimationPlayer 的父节点 = ChenJingchouSkin）
# track path 相对 root_node 解析：无前缀直接访问 Skin 节点自身的属性
const TRACK_PATH_PHYSICAL_HEIGHT := ".:physical_height"
const TRACK_PATH_ATTACK_HEIGHTS := ".:attack_heights"
const TRACK_PATH_PHYSICAL_WIDTH := ".:physical_width"  # Skin 的 physical_width 属性，由 QuiverCharacter 读取后设置 CapsuleShape2D.height
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
	var width_track_idx := _add_value_track(anim, TRACK_PATH_PHYSICAL_WIDTH)
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
		TRACK_PATH_PHYSICAL_WIDTH,       # ".:physical_width"
		# 历史版本路径 1：无前缀但缺少 . 前缀
		"physical_height",
		"attack_heights",
		# 历史版本路径 2：../ 前缀
		"../physical_height",
		"../attack_heights",
		"../Collision:shape.height",
		# 历史版本路径 3：../../ 前缀
		"../../physical_height",
		"../../attack_heights",
		"../../Collision:shape.height",
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


### Contour Conversion Methods -------------------------------------------------------------------

## Body 轮廓转换
##
## 从 PNG 提取轮廓多边形，替换 HurtShape 的 CollisionShape2D 为 CollisionPolygon2D
## 自动计算 physical_height，更新动画 tracks，重命名 PNG 文件
##
## 参数:
## - skin_node: QuiverCharacterSkinAnimTree 节点
## - alpha_threshold: alpha 阈值（0.0-1.0）
## - simplify_tolerance: Douglas-Peucker 简化容差（像素）
## - dry_run: 如果为 true，只预览不实际修改
## - callback_obj: 拥有 _on_contour_progress(current, total, filename) 方法的对象
##
## 返回: { frame_count: int, errors: Array[String], frames_info: Dictionary, png_renames: Dictionary }
func convert_body_contours(
	skin_node: Node,
	alpha_threshold: float,
	simplify_tolerance: float,
	dry_run: bool,
	callback_obj: Object
) -> Dictionary:
	var result := {
		"frame_count": 0,
		"errors": [] as Array[String],
		"frames_info": {},
		"png_renames": {},
	}
	
	# 1. 获取 SpriteFrames
	var sprite_frames := _get_sprite_frames(skin_node, result.errors)
	if sprite_frames == null:
		return result
	
	# 2. 获取 skin 场景路径（用于后续修改 .tscn）
	var skin_scene_path := skin_node.scene_file_path
	
	# 3. 遍历所有帧，提取轮廓数据
	var frames_data := {}
	var total_frames := 0
	
	for sprite_anim_name in sprite_frames.get_animation_names():
		var frame_count := sprite_frames.get_frame_count(sprite_anim_name)
		frames_data[sprite_anim_name] = {}
		
		for frame_idx in range(frame_count):
			var texture := sprite_frames.get_frame_texture(sprite_anim_name, frame_idx)
			if texture == null:
				continue
			
			var png_path := texture.resource_path
			
			total_frames += 1
			if callback_obj != null and callback_obj.has_method("_on_contour_progress"):
				callback_obj._on_contour_progress(total_frames, -1, png_path.get_file())
			
			# 加载 PNG
			var image := Image.load_from_file(ProjectSettings.globalize_path(png_path))
			if image == null:
				result.errors.append("无法加载图片: %s" % png_path)
				continue
			
			# 检查 mask
			var mask_path := png_path.replace(".png", ".mask.png")
			var mask: Image = null
			if FileAccess.file_exists(mask_path):
				mask = Image.load_from_file(ProjectSettings.globalize_path(mask_path))
			
			# 提取轮廓
			var contours := ContourTracer.trace_contours(image, mask, alpha_threshold, simplify_tolerance, 512)
			if contours.is_empty():
				result.errors.append("未提取到轮廓: %s" % png_path.get_file())
				continue
			
			# 计算 physical_height
			var physical_height := ContourTracer.calc_physical_height(contours, image.get_height())
			
			# 计算轮廓宽度（用于物理体碰撞胶囊的 height）
			var contour_width := ContourTracer.calc_contour_width(contours)
			
			# 坐标转换（以图片中心为原点，不依赖 HurtShape.position）
			var local_contours: Array[PackedVector2Array] = []
			for contour in contours:
				var local := ContourTracer.pixels_to_shape_local(contour, image.get_width(), image.get_height())
				local_contours.append(local)
			
			frames_data[sprite_anim_name][frame_idx] = {
				"contours": local_contours,
				"physical_height": physical_height,
				"width": contour_width,
				"png_path": png_path,
			}
			
			result.frame_count += 1
	
	# 4. 如果 dry_run，返回预览结果
	if dry_run:
		result.frames_info = frames_data
		return result
	
	# 5. 修改 skin .tscn
	_modify_skin_tscn_for_body(skin_scene_path, frames_data, result.errors)
	
	# 6. 注入 Animation tracks
	var anim_player := _get_animation_player(skin_node, result.errors)
	if anim_player != null:
		_inject_polygon_tracks_for_body(anim_player, sprite_frames, frames_data, result.errors)
	
	result.frames_info = frames_data
	return result


## Attack 轮廓转换
##
## 从 PNG 提取轮廓多边形，替换 AttackShape 的 CollisionShape2D 为 CollisionPolygon2D
## 自动计算 attack_heights，更新动画 tracks，重命名 PNG 文件
##
## 参数:
## - skin_node: QuiverCharacterSkinAnimTree 节点
## - alpha_threshold: alpha 阈值（0.0-1.0）
## - simplify_tolerance: Douglas-Peucker 简化容差（像素）
## - dry_run: 如果为 true，只预览不实际修改
## - callback_obj: 拥有 _on_contour_progress(current, total, filename) 方法的对象
##
## 返回: { frame_count: int, errors: Array[String], frames_info: Dictionary, png_renames: Dictionary }
func convert_attack_contours(
	skin_node: Node,
	alpha_threshold: float,
	simplify_tolerance: float,
	dry_run: bool,
	callback_obj: Object
) -> Dictionary:
	var result := {
		"frame_count": 0,
		"errors": [] as Array[String],
		"frames_info": {},
		"png_renames": {},
	}
	
	# 1. 获取 SpriteFrames
	var sprite_frames := _get_sprite_frames(skin_node, result.errors)
	if sprite_frames == null:
		return result
	
	# 2. 获取高度层定义（用于 attack_heights 计算）
	var height_definitions := QuiverCharacter._build_height_definitions()
	
	# 3. 从动画 track 动态确定 sprite_anim_name → attack_node 映射
	var skin_scene_path := skin_node.scene_file_path
	var anim_player := _get_animation_player(skin_node, result.errors)
	var sprite_to_attack := {}
	if anim_player != null:
		sprite_to_attack = _find_attack_mapping_from_tracks(anim_player)
	
	# 4. 遍历所有帧，提取轮廓数据
	var frames_data := {}
	var total_frames := 0
	var skipped_count := 0
	
	for sprite_anim_name in sprite_frames.get_animation_names():
		var frame_count := sprite_frames.get_frame_count(sprite_anim_name)
		frames_data[sprite_anim_name] = {}
		
		# 只处理在映射表中的 sprite 动画（即攻击动画）
		if not sprite_to_attack.has(sprite_anim_name):
			continue
		var attack_node: String = sprite_to_attack[sprite_anim_name]
		
		for frame_idx in range(frame_count):
			var texture := sprite_frames.get_frame_texture(sprite_anim_name, frame_idx)
			if texture == null:
				continue
			
			var png_path := texture.resource_path
			
			total_frames += 1
			if callback_obj != null and callback_obj.has_method("_on_contour_progress"):
				callback_obj._on_contour_progress(total_frames, -1, png_path.get_file())
			
			# 检查 mask（Attack 必须有 mask 才处理）
			var mask_path := png_path.replace(".png", ".mask.png")
			if not FileAccess.file_exists(mask_path):
				skipped_count += 1
				continue
			
			# 加载 PNG 和 mask
			var image := Image.load_from_file(ProjectSettings.globalize_path(png_path))
			if image == null:
				result.errors.append("无法加载图片: %s" % png_path)
				continue
			
			var mask := Image.load_from_file(ProjectSettings.globalize_path(mask_path))
			
			# 提取轮廓
			var contours := ContourTracer.trace_contours(image, mask, alpha_threshold, simplify_tolerance, 512)
			if contours.is_empty():
				result.errors.append("未提取到轮廓: %s" % png_path.get_file())
				continue
			
			# 计算 attack_heights
			var attack_heights := ContourTracer.calc_attack_heights(contours, image.get_height(), height_definitions)
			
			# 坐标转换（以图片中心为原点，不依赖 AttackShape.position）
			var local_contours: Array[PackedVector2Array] = []
			for contour in contours:
				var local := ContourTracer.pixels_to_shape_local(contour, image.get_width(), image.get_height())
				local_contours.append(local)
			
			frames_data[sprite_anim_name][frame_idx] = {
				"contours": local_contours,
				"attack_heights": attack_heights,
				"attack_node": attack_node,
				"png_path": png_path,
			}
			
			result.frame_count += 1
	
	# 记录跳过的帧数
	result["skipped_count"] = skipped_count
	
	# 5. 如果 dry_run，返回预览结果
	if dry_run:
		result.frames_info = frames_data
		return result
	
	# 6. 修改 skin .tscn
	_modify_skin_tscn_for_attack(skin_scene_path, frames_data, result.errors)
	
	# 7. 注入 Animation tracks（复用步骤 3 已获取的 anim_player）
	if anim_player != null:
		_inject_polygon_tracks_for_attack(anim_player, sprite_frames, frames_data, result.errors)
	
	result.frames_info = frames_data
	return result


## 从 .tscn 文件读取节点的 position
func _read_shape_position_from_tscn(tscn_path: String, node_name: String) -> Vector2:
	if not FileAccess.file_exists(tscn_path):
		return Vector2.ZERO
	
	var file := FileAccess.open(tscn_path, FileAccess.READ)
	if file == null:
		return Vector2.ZERO
	
	var content := file.get_as_text()
	file.close()
	
	# 查找节点定义
	var node_pattern := RegEx.new()
	node_pattern.compile('\\[node name="%s"[^\\]]*\\]' % node_name)
	var node_match := node_pattern.search(content)
	if node_match == null:
		return Vector2.ZERO
	
	# 在节点定义之后查找 position 属性
	var search_start := node_match.get_end()
	var next_node_start := content.find("[node ", search_start)
	if next_node_start == -1:
		next_node_start = content.length()
	
	var node_content := content.substr(search_start, next_node_start - search_start)
	
	var pos_pattern := RegEx.new()
	pos_pattern.compile('position = Vector2\\(([^,]+), ([^)]+)\\)')
	var pos_match := pos_pattern.search(node_content)
	if pos_match == null:
		return Vector2.ZERO
	
	var x := float(pos_match.get_string(1))
	var y := float(pos_match.get_string(2))
	return Vector2(x, y)


## 修改 skin .tscn（Body 转换）
func _modify_skin_tscn_for_body(tscn_path: String, frames_data: Dictionary, errors: Array[String]) -> void:
	if not FileAccess.file_exists(tscn_path):
		errors.append("skin .tscn 文件不存在: %s" % tscn_path)
		return
	
	var file := FileAccess.open(tscn_path, FileAccess.READ)
	if file == null:
		errors.append("无法读取 skin .tscn: %s" % tscn_path)
		return
	
	var content := file.get_as_text()
	file.close()
	
	# 获取第一帧的轮廓数据（用于初始 polygon）
	var first_polygon := PackedVector2Array()
	for sprite_anim_name in frames_data.keys():
		var frame_dict: Dictionary = frames_data[sprite_anim_name]
		for frame_idx in frame_dict.keys():
			var frame_info: Dictionary = frame_dict[frame_idx]
			var contours: Array = frame_info["contours"]
			if not contours.is_empty():
				first_polygon = contours[0]
				break
		if not first_polygon.is_empty():
			break
	
	# 替换 HurtShape 节点：CollisionShape2D → CollisionPolygon2D
	var polygon_str := ContourTracer.format_polygon_array(first_polygon)
	
	# 用正则匹配整个 HurtShape 节点定义块（兼容 CollisionShape2D 和 CollisionPolygon2D）
	var old_node_pattern := RegEx.new()
	old_node_pattern.compile('\\[node name="HurtShape" type="Collision(?:Shape2D|Polygon2D)"[^\\]]*\\](?:\\n(?!\\[node ).*)*')
	
	var new_node := '[node name="HurtShape" type="CollisionPolygon2D" parent="AnimatedSprite2D/HurtBox" index="0" unique_id=1852356286]\nmodulate = Color(0, 0.0666667, 0.701961, 1)\nposition = Vector2(0, 0)\npolygon = %s\n\n' % polygon_str
	
	content = old_node_pattern.sub(content, new_node)
	
	# 删除不再使用的 RectangleShape2D SubResource (HurtBox 的)
	var subresource_pattern := RegEx.new()
	subresource_pattern.compile('\\[sub_resource type="RectangleShape2D" id="RectangleShape2D_75u0j"\\]\\nsize = Vector2\\([^)]+\\)\\n\\n')
	content = subresource_pattern.sub(content, "")
	
	# 写回文件
	file = FileAccess.open(tscn_path, FileAccess.WRITE)
	if file == null:
		errors.append("无法写入 skin .tscn: %s" % tscn_path)
		return
	
	file.store_string(content)
	file.close()


## 修改 skin .tscn（Attack 转换）
func _modify_skin_tscn_for_attack(tscn_path: String, frames_data: Dictionary, errors: Array[String]) -> void:
	if not FileAccess.file_exists(tscn_path):
		errors.append("skin .tscn 文件不存在: %s" % tscn_path)
		return
	
	var file := FileAccess.open(tscn_path, FileAccess.READ)
	if file == null:
		errors.append("无法读取 skin .tscn: %s" % tscn_path)
		return
	
	var content := file.get_as_text()
	file.close()
	
	# 收集每个 Attack 节点的第一帧轮廓数据和 position
	var attack_first_polygons := {}
	for sprite_anim_name in frames_data.keys():
		var frame_dict: Dictionary = frames_data[sprite_anim_name]
		for frame_idx in frame_dict.keys():
			var frame_info: Dictionary = frame_dict[frame_idx]
			var attack_node: String = frame_info["attack_node"]
			if not attack_first_polygons.has(attack_node):
				var contours: Array = frame_info["contours"]
				if not contours.is_empty():
					attack_first_polygons[attack_node] = contours[0]
	
	# 替换各 AttackShape 节点定义（position 写 (0,0)，polygon 以图片中心为原点）
	for attack_node in attack_first_polygons.keys():
		var shape_name: String = attack_node + "Shape"
		var first_polygon: PackedVector2Array = attack_first_polygons[attack_node]
		
		var polygon_str := ContourTracer.format_polygon_array(first_polygon)
		
		var old_node_pattern := RegEx.new()
		old_node_pattern.compile('\\[node name="%s" type="Collision(?:Shape2D|Polygon2D)"[^\\]]*\\](?:\\n(?!\\[node ).*)*' % shape_name)
		
		var new_node := '[node name="%s" type="CollisionPolygon2D" parent="Attacks/%s" index="0"]\nmodulate = Color(1, 0.2, 0.101961, 1)\nposition = Vector2(0, 0)\npolygon = %s\ndisabled = true\n\n' % [shape_name, attack_node, polygon_str]
		
		content = old_node_pattern.sub(content, new_node)
	
	# 删除不再使用的 RectangleShape2D SubResources
	var subresource_ids := ["RectangleShape2D_once2", "RectangleShape2D_tcrug", "RectangleShape2D_vo5ct", "RectangleShape2D_e0e1l"]
	for sub_id in subresource_ids:
		var subresource_pattern := RegEx.new()
		subresource_pattern.compile('\\[sub_resource type="RectangleShape2D" id="%s"\\]\\nsize = Vector2\\([^)]+\\)\\n\\n' % sub_id)
		content = subresource_pattern.sub(content, "")
	
	# 写回文件
	file = FileAccess.open(tscn_path, FileAccess.WRITE)
	if file == null:
		errors.append("无法写入 skin .tscn: %s" % tscn_path)
		return
	
	file.store_string(content)
	file.close()


## 注入 Body 的 polygon tracks
func _inject_polygon_tracks_for_body(
	anim_player: AnimationPlayer,
	sprite_frames: SpriteFrames,
	frames_data: Dictionary,
	errors: Array[String]
) -> void:
	var lib_names := anim_player.get_animation_library_list()
	
	for lib_name in lib_names:
		var library: AnimationLibrary = anim_player.get_animation_library(lib_name)
		if library == null:
			continue
		
		for anim_name in library.get_animation_list():
			var anim := library.get_animation(anim_name)
			if anim == null:
				continue
			
			var sprite_anim_name := _find_sprite_anim_name(anim)
			if sprite_anim_name.is_empty() or not frames_data.has(sprite_anim_name):
				continue
			
			var frame_dict: Dictionary = frames_data[sprite_anim_name]
			if frame_dict.is_empty():
				continue
			
			# 删除旧的 CollisionShape2D 属性 tracks 和新的 polygon/physical_width tracks
			_remove_tracks_by_path(anim, [
				"AnimatedSprite2D/HurtBox/HurtShape:shape:size",
				"AnimatedSprite2D/HurtBox/HurtShape:polygon",
				"AnimatedSprite2D/HurtBox/HurtShape:position",
				"AnimatedSprite2D/HurtBox/HurtShape:rotation",
				"AnimatedSprite2D/HurtBox:position",
				TRACK_PATH_PHYSICAL_WIDTH,
				"../Collision:shape.height",
				"../../Collision:shape.height",
			])
			
			# 添加 polygon track 和 width track
			var polygon_track_idx := _add_value_track(anim, "AnimatedSprite2D/HurtBox/HurtShape:polygon")
			var width_track_idx := _add_value_track(anim, TRACK_PATH_PHYSICAL_WIDTH)
			
			# 添加 position/rotation tracks，覆盖动画中原有的值
			# 轮廓多边形以图片中心为原点，HurtShape 的 position 必须为 (0,0)，rotation 必须为 0
			var hurt_shape_pos_track_idx := _add_value_track(anim, "AnimatedSprite2D/HurtBox/HurtShape:position")
			anim.track_insert_key(hurt_shape_pos_track_idx, 0.0, Vector2(0, 0))
			
			var hurt_shape_rot_track_idx := _add_value_track(anim, "AnimatedSprite2D/HurtBox/HurtShape:rotation")
			anim.track_insert_key(hurt_shape_rot_track_idx, 0.0, 0.0)
			
			var hurt_box_pos_track_idx := _add_value_track(anim, "AnimatedSprite2D/HurtBox:position")
			anim.track_insert_key(hurt_box_pos_track_idx, 0.0, Vector2(0, 0))
			
			# 提取 flip_h track 数据（用于 polygon 镜像）
			var flip_track_data := _extract_flip_h_track(anim)
			
			# 逐帧插入 keyframe（只在值变化时）
			var sprite_fps := sprite_frames.get_animation_speed(sprite_anim_name)
			var frame_duration: float = 1.0 / max(1.0, sprite_fps)
			var prev_polygon := PackedVector2Array()
			var prev_width: float = -1.0
			
			for frame_idx in range(sprite_frames.get_frame_count(sprite_anim_name)):
				if not frame_dict.has(frame_idx):
					continue
				
				var frame_info: Dictionary = frame_dict[frame_idx]
				var contours: Array = frame_info["contours"]
				var current_polygon: PackedVector2Array = contours[0] if not contours.is_empty() else PackedVector2Array()
				
				var time: float = float(frame_idx) * frame_duration
				
				# 宽度 track（逐帧，值变化时插入）
				var current_width: float = frame_info.get("width", 0.0)
				if current_width != prev_width:
					anim.track_insert_key(width_track_idx, time, current_width)
					prev_width = current_width
				
				# polygon 镜像（根据 flip_h 状态）
				if _is_flipped_at_time(flip_track_data, time):
					current_polygon = _mirror_polygon_x(current_polygon)
				
				if current_polygon != prev_polygon:
					anim.track_insert_key(polygon_track_idx, time, current_polygon)
					prev_polygon = current_polygon
			
			# 保存 Animation
			var resource_path := anim.resource_path
			if not resource_path.is_empty():
				var err := ResourceSaver.save(anim, resource_path)
				if err != OK:
					errors.append("动画 '%s' 保存失败 (error=%d)" % [anim.resource_name, err])


## 注入 Attack 的 polygon tracks
func _inject_polygon_tracks_for_attack(
	anim_player: AnimationPlayer,
	sprite_frames: SpriteFrames,
	frames_data: Dictionary,
	errors: Array[String]
) -> void:
	var lib_names := anim_player.get_animation_library_list()
	
	for lib_name in lib_names:
		var library: AnimationLibrary = anim_player.get_animation_library(lib_name)
		if library == null:
			continue
		
		for anim_name in library.get_animation_list():
			var anim := library.get_animation(anim_name)
			if anim == null:
				continue
			
			var sprite_anim_name := _find_sprite_anim_name(anim)
			if sprite_anim_name.is_empty() or not frames_data.has(sprite_anim_name):
				continue
			
			var frame_dict: Dictionary = frames_data[sprite_anim_name]
			if frame_dict.is_empty():
				continue
			
			# 获取 attack_node
			var first_frame: Dictionary = frame_dict.values()[0]
			var attack_node: String = first_frame["attack_node"]
			var shape_name: String = attack_node + "Shape"
			
			# 删除旧的 CollisionShape2D 属性 tracks 和新的 polygon track，再添加新的
			var polygon_path := "Attacks/%s/%s:polygon" % [attack_node, shape_name]
			var position_path := "Attacks/%s/%s:position" % [attack_node, shape_name]
			var rotation_path := "Attacks/%s/%s:rotation" % [attack_node, shape_name]
			var shape_size_path := "Attacks/%s/%s:shape:size" % [attack_node, shape_name]
			var attack_node_path := "Attacks/%s:position" % attack_node
			_remove_tracks_by_path(anim, [polygon_path, position_path, rotation_path, shape_size_path, attack_node_path])
			var polygon_track_idx := _add_value_track(anim, polygon_path)
			
			# 添加 position/rotation tracks，覆盖动画中原有的值
			# 轮廓多边形以图片中心为原点，AttackShape 的 position 必须为 (0,0)，rotation 必须为 0
			var position_track_idx := _add_value_track(anim, position_path)
			anim.track_insert_key(position_track_idx, 0.0, Vector2(0, 0))
			
			var rotation_track_idx := _add_value_track(anim, rotation_path)
			anim.track_insert_key(rotation_track_idx, 0.0, 0.0)
			
			# 添加 Attack 节点的 position track，跟随 AnimatedSprite2D 的位置
			# 这样 AttackShape 的世界坐标 = Skin + Sprite.pos + Attack.pos + Shape.pos + polygon
			# 由于 Shape.pos = (0,0)，Attack.pos = Sprite.pos，所以世界坐标 = Sprite.pos + polygon
			# 和 HurtBox 的逻辑一致：polygon 以图片中心为原点，跟随 sprite 移动
			var attack_pos_track_idx := _add_value_track(anim, attack_node_path)
			var sprite_pos_track_idx := anim.find_track("AnimatedSprite2D:position", Animation.TYPE_VALUE)
			if sprite_pos_track_idx >= 0:
				var key_count := anim.track_get_key_count(sprite_pos_track_idx)
				for i in key_count:
					var time := anim.track_get_key_time(sprite_pos_track_idx, i)
					var value := anim.track_get_key_value(sprite_pos_track_idx, i)
					anim.track_insert_key(attack_pos_track_idx, time, value)
			else:
				anim.track_insert_key(attack_pos_track_idx, 0.0, Vector2(0, 0))
			
			# 提取 flip_h track 数据（用于 polygon 镜像）
			var flip_track_data := _extract_flip_h_track(anim)
			
			# 逐帧插入 keyframe（只在值变化时）
			var sprite_fps := sprite_frames.get_animation_speed(sprite_anim_name)
			var frame_duration: float = 1.0 / max(1.0, sprite_fps)
			var prev_polygon := PackedVector2Array()
			
			for frame_idx in range(sprite_frames.get_frame_count(sprite_anim_name)):
				if not frame_dict.has(frame_idx):
					continue
				
				var frame_info: Dictionary = frame_dict[frame_idx]
				var contours: Array = frame_info["contours"]
				var current_polygon: PackedVector2Array = contours[0] if not contours.is_empty() else PackedVector2Array()
				
				var time: float = float(frame_idx) * frame_duration
				
				# polygon 镜像（根据 flip_h 状态）
				if _is_flipped_at_time(flip_track_data, time):
					current_polygon = _mirror_polygon_x(current_polygon)
				
				if current_polygon != prev_polygon:
					anim.track_insert_key(polygon_track_idx, time, current_polygon)
					prev_polygon = current_polygon
			
			# 保存 Animation
			var resource_path := anim.resource_path
			if not resource_path.is_empty():
				var err := ResourceSaver.save(anim, resource_path)
				if err != OK:
					errors.append("动画 '%s' 保存失败 (error=%d)" % [anim.resource_name, err])


## 根据 sprite_anim_name 确定对应的 Attack 节点名
func _get_attack_node_name(sprite_anim_name: String) -> String:
	if sprite_anim_name.contains("punch1"):
		return "Attack1"
	elif sprite_anim_name.contains("punch2"):
		return "Attack2"
	elif sprite_anim_name.contains("punch3"):
		return "Attack3"
	elif sprite_anim_name.contains("air_attack"):
		return "AttackAir"
	return ""


## 从动画 track 中构建 sprite_anim_name → attack_node 的映射
##
## 判断依据：AttackXShape:disabled track 的值中是否包含 false
## （false = 碰撞体被启用 = 这是攻击动画）
## 非攻击动画（idle、hurt 等）的 Shape:disabled 值全是 [true]，不会被误判。
##
## 返回: { "attack_1": "Attack1", "attack_2": "Attack2", ... }
func _find_attack_mapping_from_tracks(anim_player: AnimationPlayer) -> Dictionary:
	var mapping := {}
	
	for lib_name in anim_player.get_animation_library_list():
		var library: AnimationLibrary = anim_player.get_animation_library(lib_name)
		if library == null:
			continue
		
		for anim_name in library.get_animation_list():
			var anim := library.get_animation(anim_name)
			if anim == null:
				continue
			
			var sprite_anim_name := _find_sprite_anim_name(anim)
			if sprite_anim_name.is_empty() or mapping.has(sprite_anim_name):
				continue
			
			for track_idx in range(anim.get_track_count()):
				if anim.track_get_type(track_idx) != Animation.TYPE_VALUE:
					continue
				var track_path := str(anim.track_get_path(track_idx))
				if not track_path.contains("Attacks/") or not track_path.ends_with("Shape:disabled"):
					continue
				
				# 检查关键帧值中是否有 false（碰撞体被启用）
				for key_idx in range(anim.track_get_key_count(track_idx)):
					if anim.track_get_key_value(track_idx, key_idx) == false:
						# 从路径提取 Attack 节点名：Attacks/Attack1/Attack1Shape:disabled → Attack1
						var parts := track_path.split("/")
						if parts.size() >= 2:
							mapping[sprite_anim_name] = parts[1]
						break
	
	return mapping


## 构建 Body 的 PNG 重命名映射
func _build_body_png_renames(frames_data: Dictionary) -> Dictionary:
	var renames := {}
	for sprite_anim_name in frames_data.keys():
		var frame_dict: Dictionary = frames_data[sprite_anim_name]
		for frame_idx in frame_dict.keys():
			var frame_info: Dictionary = frame_dict[frame_idx]
			var old_path: String = frame_info["png_path"]
			var new_path := _remove_physical_tag(old_path)
			if new_path != old_path:
				renames[old_path] = new_path
	return renames


## 构建 Attack 的 PNG 重命名映射
func _build_attack_png_renames(frames_data: Dictionary) -> Dictionary:
	var renames := {}
	for sprite_anim_name in frames_data.keys():
		var frame_dict: Dictionary = frames_data[sprite_anim_name]
		for frame_idx in frame_dict.keys():
			var frame_info: Dictionary = frame_dict[frame_idx]
			var old_path: String = frame_info["png_path"]
			var new_path := _remove_attack_tags(old_path)
			if new_path != old_path:
				renames[old_path] = new_path
	return renames


## 移除文件名中的 _physical_<P> 标签
func _remove_physical_tag(path: String) -> String:
	var pattern := RegEx.new()
	pattern.compile('_physical_\\d+(\\.\\d+)?')
	return pattern.sub(path, "", true)


## 移除文件名中的 _attack_<Z1>_<Z2>... 标签
func _remove_attack_tags(path: String) -> String:
	var pattern := RegEx.new()
	pattern.compile('_attack_(\\d+(\\.\\d+)?_)*\\d+(\\.\\d+)?')
	return pattern.sub(path, "", true)


## 重命名 PNG 文件 + 更新 SpriteFrames
func _rename_pngs_and_update_spriteframes(renames: Dictionary, spriteframes_path: String, errors: Array[String]) -> void:
	if renames.is_empty():
		return
	
	# 1. 重命名 PNG 文件
	for old_path in renames.keys():
		var new_path: String = renames[old_path]
		var old_global := ProjectSettings.globalize_path(old_path)
		var new_global := ProjectSettings.globalize_path(new_path)
		
		var err := DirAccess.rename_absolute(old_global, new_global)
		if err != OK:
			errors.append("重命名失败: %s → %s (error=%d)" % [old_path.get_file(), new_path.get_file(), err])
	
	# 2. 文本替换 SpriteFrames .tres 中的路径
	if not FileAccess.file_exists(spriteframes_path):
		errors.append("SpriteFrames 文件不存在: %s" % spriteframes_path)
		return
	
	var file := FileAccess.open(spriteframes_path, FileAccess.READ)
	if file == null:
		errors.append("无法读取 SpriteFrames: %s" % spriteframes_path)
		return
	
	var content := file.get_as_text()
	file.close()
	
	for old_path in renames.keys():
		var new_path: String = renames[old_path]
		content = content.replace(old_path, new_path)
	
	file = FileAccess.open(spriteframes_path, FileAccess.WRITE)
	if file == null:
		errors.append("无法写入 SpriteFrames: %s" % spriteframes_path)
		return
	
	file.store_string(content)
	file.close()
	
	# 3. 触发文件系统扫描
	EditorInterface.get_resource_filesystem().scan()


## 删除指定路径的 tracks
func _remove_tracks_by_path(anim: Animation, paths: Array[String]) -> void:
	var tracks_to_remove := []
	
	for track_idx in range(anim.get_track_count()):
		var track_path := str(anim.track_get_path(track_idx))
		if track_path in paths:
			tracks_to_remove.append(track_idx)
	
	for i in range(tracks_to_remove.size() - 1, -1, -1):
		anim.remove_track(tracks_to_remove[i])


## 提取动画中 flip_h track 的所有 keyframe
##
## 返回: [{time: float, value: bool}, ...]
func _extract_flip_h_track(anim: Animation) -> Array:
	for track_idx in range(anim.get_track_count()):
		if anim.track_get_type(track_idx) != Animation.TYPE_VALUE:
			continue
		if str(anim.track_get_path(track_idx)) == "AnimatedSprite2D:flip_h":
			var data := []
			for key_idx in range(anim.track_get_key_count(track_idx)):
				data.append({
					"time": anim.track_get_key_time(track_idx, key_idx),
					"value": anim.track_get_key_value(track_idx, key_idx) == true,
				})
			return data
	return []


## 查询指定时间点的 flip_h 值
##
## 取该时间之前最近的 keyframe 的值
func _is_flipped_at_time(flip_track_data: Array, time: float) -> bool:
	var result := false
	for key in flip_track_data:
		if key.time <= time:
			result = key.value
		else:
			break
	return result


## 将 polygon 的所有顶点 X 坐标取反（水平镜像）
func _mirror_polygon_x(polygon: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for vertex in polygon:
		result.append(Vector2(-vertex.x, vertex.y))
	return result


## 测试单个 PNG 文件的轮廓提取效果（不修改任何文件）
##
## 参数:
## - file_path: PNG 文件路径
## - test_type: "body" 或 "attack"
## - alpha_threshold: alpha 阈值（0.0-1.0）
## - simplify_tolerance: Douglas-Peucker 简化容差（像素）
## - skin_node: QuiverCharacterSkinAnimTree 节点（用于读取 shape position）
##
## 返回: {
##   file_name: String,
##   image_size: Vector2,
##   contour_count: int,
##   total_vertices: int,
##   type: String,
##   physical_height: float,  # body 类型
##   attack_heights: Array,   # attack 类型
##   bounding_box: Rect2,
##   alpha_threshold: float,
##   simplify_tolerance: float,
##   has_mask: bool,
##   error: String  # 如果有错误
## }
func test_single_file(
	file_path: String,
	test_type: String,
	alpha_threshold: float,
	simplify_tolerance: float,
	skin_node: Node
) -> Dictionary:
	var result := {
		"file_name": file_path.get_file(),
		"image_size": Vector2.ZERO,
		"contour_count": 0,
		"total_vertices": 0,
		"type": test_type,
		"physical_height": 0.0,
		"attack_heights": [],
		"bounding_box": Rect2(),
		"alpha_threshold": alpha_threshold,
		"simplify_tolerance": simplify_tolerance,
		"has_mask": false,
		"error": "",
		"contours": [],
		"image": null,
	}
	
	# 1. 加载 PNG 文件
	var image := Image.load_from_file(ProjectSettings.globalize_path(file_path))
	if image == null:
		result.error = "无法加载图片: %s" % file_path
		return result
	
	result.image_size = Vector2(image.get_width(), image.get_height())
	
	# 2. 检查是否有对应的 .mask.png
	var mask_path := file_path.replace(".png", ".mask.png")
	var mask: Image = null
	if FileAccess.file_exists(mask_path):
		mask = Image.load_from_file(ProjectSettings.globalize_path(mask_path))
		result.has_mask = true
	
	# 3. 提取轮廓
	var contours := ContourTracer.trace_contours(image, mask, alpha_threshold, simplify_tolerance, 512)
	if contours.is_empty():
		result.error = "未提取到轮廓"
		return result
	
	result.contour_count = contours.size()
	for contour in contours:
		result.total_vertices += contour.size()
	
	# 保存轮廓和图片用于预览
	result.contours = contours
	result.image = image
	
	# 4. 根据 test_type 计算高度数据
	if test_type == "body":
		# 计算 physical_height
		result.physical_height = ContourTracer.calc_physical_height(contours, image.get_height())
		
		# 坐标转换（以图片中心为原点，不依赖 HurtShape.position）
		var local_contours: Array[PackedVector2Array] = []
		for contour in contours:
			var local := ContourTracer.pixels_to_shape_local(contour, image.get_width(), image.get_height())
			local_contours.append(local)
		
		# 计算 bounding box
		result.bounding_box = _calc_bounding_box(local_contours)
	
	elif test_type == "attack":
		# 从文件名解析 attack_heights
		var parsed: Dictionary = CharacterHeightData.parse_height_from_filename(file_path)
		var attack_heights_raw: Array = parsed.get("attack_heights", [])
		
		if attack_heights_raw.is_empty():
			result.error = "文件名中没有 attack 标签"
			return result
		
		# 计算 attack_heights（使用高度层定义）
		var height_definitions := QuiverCharacter._build_height_definitions()
		result.attack_heights = ContourTracer.calc_attack_heights(contours, image.get_height(), height_definitions)
		
		# 确定对应的 Attack 节点名
		var sprite_anim_name := file_path.get_file().get_basename()
		var attack_node := _get_attack_node_name(sprite_anim_name)
		
		if attack_node.is_empty():
			result.error = "无法从文件名确定 Attack 节点"
			return result
		
		# 坐标转换（以图片中心为原点，不依赖 AttackShape.position）
		var local_contours: Array[PackedVector2Array] = []
		for contour in contours:
			var local := ContourTracer.pixels_to_shape_local(contour, image.get_width(), image.get_height())
			local_contours.append(local)
		
		# 计算 bounding box
		result.bounding_box = _calc_bounding_box(local_contours)
	
	else:
		result.error = "未知的测试类型: %s" % test_type
		return result
	
	return result


## 计算多个轮廓的 bounding box
func _calc_bounding_box(contours: Array[PackedVector2Array]) -> Rect2:
	if contours.is_empty():
		return Rect2()
	
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	
	for contour in contours:
		for vertex in contour:
			min_x = min(min_x, vertex.x)
			min_y = min(min_y, vertex.y)
			max_x = max(max_x, vertex.x)
			max_y = max(max_y, vertex.y)
	
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

### -----------------------------------------------------------------------------------------------
