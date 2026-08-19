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

# 碰撞形状类型
enum ShapeType {
	POLYGON = 0,    # CollisionPolygon2D + :polygon track（精确轮廓）
	CAPSULE = 1,    # CollisionShape2D + CapsuleShape2D（从 MABR 推导）
	RECTANGLE = 2   # CollisionShape2D + RectangleShape2D（从 MABR 推导）
}

# 形状类型配置（数据驱动）
# 每种形状需要写入哪些 track 属性
const SHAPE_CONFIGS := {
	ShapeType.POLYGON: {
		"node_type": "CollisionPolygon2D",
		"tracks": ["polygon", "position", "rotation"],
	},
	ShapeType.CAPSULE: {
		"node_type": "CollisionShape2D",
		"tracks": ["shape:radius", "shape:height", "position", "rotation"],
	},
	ShapeType.RECTANGLE: {
		"node_type": "CollisionShape2D",
		"tracks": ["shape:size", "position", "rotation"],
	},
}

# 场景树发现路径（仅有的硬编码）
const BODY_BOX_PATH := "AnimatedSprite2D/HurtBox"
const ATTACKS_PATH := "Attacks"

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


## 查找或创建 value track
## 如果 track 已存在，返回其索引；否则创建新的
func _find_or_add_value_track(anim: Animation, track_path: String) -> int:
	# 查找现有 track
	for i in range(anim.get_track_count()):
		if anim.track_get_type(i) == Animation.TYPE_VALUE:
			if str(anim.track_get_path(i)) == track_path:
				return i
	
	# 不存在则创建新的
	return _add_value_track(anim, track_path)


## 删除指定时间点的关键帧（如果存在）
## 使用容差 0.001 秒来匹配时间点
func _remove_key_at_time(anim: Animation, track_idx: int, time: float) -> void:
	var epsilon := 0.001
	var key_count := anim.track_get_key_count(track_idx)
	
	# 从后往前遍历，避免删除时索引变化
	for i in range(key_count - 1, -1, -1):
		var key_time := anim.track_get_key_time(track_idx, i)
		if abs(key_time - time) < epsilon:
			anim.track_remove_key(track_idx, i)
			break


## 清除 track 的所有关键帧（不删除 track 本身）
func _clear_track_keys(anim: Animation, track_idx: int) -> void:
	for i in range(anim.track_get_key_count(track_idx) - 1, -1, -1):
		anim.track_remove_key(track_idx, i)


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

## 从 SpriteFrames 提取所有帧的轮廓数据（共享扫描逻辑）
##
## 统一的扫描逻辑：遍历帧 → 加载 PNG → 检查 mask → 提取轮廓
## mask 处理统一：有 mask 用 mask，无 mask 全图扫描
##
## 参数:
## - sprite_frames: SpriteFrames 资源
## - alpha_threshold: alpha 阈值
## - simplify_tolerance: 简化容差
## - filter_anims: 只处理这些动画名（空 = 处理全部）
## - frame_filter: 帧过滤 { "anim_name": { "enabled_frames": null/[]/[1,2] } }
##   null = 全部跳过, [] = 全部处理, [1,2] = 只处理指定帧
## - callback_obj: 进度回调对象
## - errors: 错误数组
##
## 返回: { sprite_anim_name: { frame_idx: { raw_contours, image_size, png_path } } }
func _scan_frames_contours(
	sprite_frames: SpriteFrames,
	alpha_threshold: float,
	simplify_tolerance: float,
	min_area_ratio: float,
	filter_anims: Array[String],
	frame_filter: Dictionary,
	mask_suffix: String,
	callback_obj: Object,
	errors: Array[String],
	target_file_path: String = "",
	erosion_radius: int = 0
) -> Dictionary:
	var frames_data := {}
	
	# 第一遍：预统计要处理的帧列表
	var frames_to_process := []
	for sprite_anim_name in sprite_frames.get_animation_names():
		# 过滤：只处理 filter_anims 中的动画
		# 如果 filter_anims 为空，则不处理任何动画
		if sprite_anim_name not in filter_anims:
			continue
		
		# 帧过滤：检查 enabled_frames
		var enabled_frames = null
		if frame_filter.has(sprite_anim_name):
			var filter_info: Dictionary = frame_filter[sprite_anim_name]
			enabled_frames = filter_info.get("enabled_frames", null)
			# null = 全部跳过
			if enabled_frames == null:
				continue
		
		var frame_count := sprite_frames.get_frame_count(sprite_anim_name)
		
		for frame_idx in range(frame_count):
			# 如果有 enabled_frames 列表且非空，只处理列表中的帧
			if enabled_frames is Array and not enabled_frames.is_empty() and frame_idx not in enabled_frames:
				continue
			
			var texture := sprite_frames.get_frame_texture(sprite_anim_name, frame_idx)
			if texture == null:
				continue
			
			var png_path := texture.resource_path
			
			# 如果指定了目标文件，跳过其他文件
			if not target_file_path.is_empty() and png_path != target_file_path:
				continue
			
			frames_to_process.append({
				"sprite_anim_name": sprite_anim_name,
				"frame_idx": frame_idx,
				"png_path": png_path,
			})
	
	var total_frames := frames_to_process.size()
	
	# 第二遍：增量处理每帧
	var current := 0
	for item in frames_to_process:
		current += 1
		var sprite_anim_name: String = item["sprite_anim_name"]
		var frame_idx: int = item["frame_idx"]
		var png_path: String = item["png_path"]
		
		# 确保 frames_data 中有这个动画的字典
		if not frames_data.has(sprite_anim_name):
			frames_data[sprite_anim_name] = {}
		
		# 进度回调（传入正确的 total）
		if callback_obj != null and callback_obj.has_method("_on_contour_progress"):
			callback_obj._on_contour_progress(current, total_frames, png_path.get_file())
		
		# 加载 PNG
		var image := Image.load_from_file(ProjectSettings.globalize_path(png_path))
		if image == null:
			errors.append("无法加载图片: %s" % png_path)
			continue
		
		# 检查 mask（优先级：专用 > 通用 > 无）
		# 1. {name}.{suffix}.mask.png  （专用 mask）
		# 2. {name}.mask.png           （通用 mask，向后兼容）
		# 3. 无 mask → 全图扫描
		var base_path := png_path.replace(".png", "")
		var specific_mask_path := base_path + "." + mask_suffix + ".mask.png"
		var generic_mask_path := base_path + ".mask.png"
		
		var mask: Image = null
		if FileAccess.file_exists(specific_mask_path):
			mask = Image.load_from_file(ProjectSettings.globalize_path(specific_mask_path))
		elif FileAccess.file_exists(generic_mask_path):
			mask = Image.load_from_file(ProjectSettings.globalize_path(generic_mask_path))
		
		# 提取轮廓（原始像素坐标）
		var contours := ContourTracer.trace_contours(image, mask, alpha_threshold, simplify_tolerance, 512, min_area_ratio, erosion_radius)
		if contours.is_empty():
			errors.append("未提取到轮廓: %s" % png_path.get_file())
			continue
		
		frames_data[sprite_anim_name][frame_idx] = {
			"raw_contours": contours,
			"image_size": Vector2(image.get_width(), image.get_height()),
			"png_path": png_path,
		}
		
		# 让出控制权，让编辑器更新界面
		if callback_obj != null and callback_obj.has_method("get_tree"):
			var tree = callback_obj.get_tree()
			if tree != null:
				await tree.process_frame
	
	return frames_data


func convert_body_contours(
	skin_node: Node,
	alpha_threshold: float,
	simplify_tolerance: float,
	min_area_ratio: float,
	erosion_radius: int,
	shape_type: int,
	dry_run: bool,
	callback_obj: Object,
	target_file_path: String = ""
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
	
	# 2. 获取 AnimationPlayer
	var anim_player := _get_animation_player(skin_node, result.errors)
	
	# 3. 发现 body 形状节点
	var shape_nodes := _discover_shape_nodes(skin_node)
	var body_nodes: Array = shape_nodes.filter(func(n): return n["category"] == "body")
	
	if body_nodes.is_empty():
		result.errors.append("未发现 body 形状节点")
		return result
	
	# 4. 对每个 body shape 节点执行转换
	for node_info in body_nodes:
		# 4a. 找出引用了这个 shape_node 的动画
		var relevant_anims: Array[String] = []
		if anim_player != null:
			for lib_name in anim_player.get_animation_library_list():
				var library := anim_player.get_animation_library(lib_name)
				if library == null:
					continue
				for anim_name in library.get_animation_list():
					var anim := library.get_animation(anim_name)
					if anim == null:
						continue
					if _animation_references_shape(anim, node_info):
						var sprite_anim_name := _find_sprite_anim_name(anim)
						if not sprite_anim_name.is_empty():
							relevant_anims.append(sprite_anim_name)
		
		# 4b. 构建帧过滤映射（只针对相关动画）
		var frame_filter := {}
		if anim_player != null:
			frame_filter = _build_frame_filter_for_node(node_info, anim_player, skin_node)
		
		# 4c. 扫描轮廓（只扫描相关动画，始终使用 erosion=0，获取原始轮廓用于 polygon track）
		var frames_data := await _scan_frames_contours(
			sprite_frames, alpha_threshold, simplify_tolerance, min_area_ratio,
			relevant_anims, frame_filter, "body", callback_obj, result.errors, target_file_path, 0
		)
		
		# 4c. 后处理：计算 physical_height/width + 坐标转换 + MABR/Capsule/Rectangle
		for sprite_anim_name in frames_data:
			for frame_idx in frames_data[sprite_anim_name]:
				var frame: Dictionary = frames_data[sprite_anim_name][frame_idx]
				var raw: Array = frame["raw_contours"]
				var img_w := int(frame["image_size"].x)
				var img_h := int(frame["image_size"].y)
				
				frame["physical_height"] = ContourTracer.calc_physical_height(raw, img_h)
				frame["width"] = ContourTracer.calc_contour_width(raw)
				
				var local_contours: Array[PackedVector2Array] = []
				for contour in raw:
					local_contours.append(ContourTracer.pixels_to_shape_local(contour, img_w, img_h))
				frame["contours"] = local_contours
				
				# 如果 Capsule/Rectangle 模式且 erosion_radius > 0，提取腐蚀后的轮廓用于 MABR
				if shape_type != ShapeType.POLYGON and erosion_radius > 0:
					# 重新提取腐蚀后的轮廓
					var image := Image.load_from_file(ProjectSettings.globalize_path(frame["png_path"]))
					var mask: Image = null
					var base_path: String = str(frame["png_path"]).replace(".png", "")
					var specific_mask_path: String = base_path + ".body.mask.png"
					var generic_mask_path: String = base_path + ".mask.png"
					if FileAccess.file_exists(specific_mask_path):
						mask = Image.load_from_file(ProjectSettings.globalize_path(specific_mask_path))
					elif FileAccess.file_exists(generic_mask_path):
						mask = Image.load_from_file(ProjectSettings.globalize_path(generic_mask_path))
					
					var eroded_raw := ContourTracer.trace_contours(
						image, mask, alpha_threshold, simplify_tolerance, 512, min_area_ratio, erosion_radius
					)
					var eroded_local: Array[PackedVector2Array] = []
					for contour in eroded_raw:
						eroded_local.append(ContourTracer.pixels_to_shape_local(contour, img_w, img_h))
					
					if eroded_local.size() > 0 and eroded_local[0].size() >= 3:
						var mabr := ContourTracer.calc_mabr(eroded_local[0])
						frame["mabr"] = mabr
						frame["capsule"] = ContourTracer.calc_capsule_from_mabr(mabr)
						frame["rectangle"] = {
							"size": mabr.size,
							"angle": mabr.angle,
						}
				else:
					# Polygon 模式或无腐蚀，基于原始轮廓计算 MABR
					if local_contours.size() > 0 and local_contours[0].size() >= 3:
						var mabr := ContourTracer.calc_mabr(local_contours[0])
						frame["mabr"] = mabr
						frame["capsule"] = ContourTracer.calc_capsule_from_mabr(mabr)
						frame["rectangle"] = {
							"size": mabr.size,
							"angle": mabr.angle,
						}
				
				frame.erase("raw_contours")
				result.frame_count += 1
		
		# 4d. 如果 dry_run，返回预览结果
		if dry_run:
			result.frames_info = frames_data
			return result
		
		# 4e. 单文件模式检查：形状类型变更时禁止单文件操作
		var skin_scene_path := skin_node.scene_file_path
		var is_single_file_mode := not target_file_path.is_empty()
		if is_single_file_mode:
			var current_type := _detect_current_shape_type(skin_scene_path, node_info["shape_name"])
			if current_type != -1 and current_type != shape_type:
				result.errors.append("形状类型变更（%s → %s）时不支持单文件模式，请先执行全量转换" % [
					ShapeType.keys()[current_type], ShapeType.keys()[shape_type]
				])
				return result
		
		# 4f. 修改 skin .tscn（仅类型不匹配时）
		if _needs_body_tscn_conversion(skin_scene_path, shape_type):
			var first_frame_data := _get_first_frame_data(frames_data)
			_modify_tscn_node(skin_scene_path, node_info, shape_type, first_frame_data, result.errors)
		
		# 4g. 注入 Animation tracks（统一函数）
		if anim_player != null:
			_inject_tracks(anim_player, sprite_frames, node_info, shape_type, frames_data, is_single_file_mode, result.errors, skin_scene_path)
		
		# 4h. 保存当前节点的 frames_data
		result.frames_info = frames_data
	
	return result


## Attack 轮廓转换
##
## 从 PNG 提取轮廓多边形，替换 AttackShape 的 CollisionShape2D 为 CollisionPolygon2D
## 自动计算 attack_heights，更新动画 tracks
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
	min_area_ratio: float,
	erosion_radius: int,
	shape_type: int,
	dry_run: bool,
	callback_obj: Object,
	target_file_path: String = ""
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
	
	# 2. 获取 AnimationPlayer
	var anim_player := _get_animation_player(skin_node, result.errors)
	
	# 3. 发现 attack 形状节点
	var shape_nodes := _discover_shape_nodes(skin_node)
	var attack_nodes: Array = shape_nodes.filter(func(n): return n["category"] == "attack")
	
	if attack_nodes.is_empty():
		return result
	
	# 4. 对每个 attack shape 节点执行转换
	for node_info in attack_nodes:
		# 4a. 找出引用了这个 shape_node 的动画
		var relevant_anims: Array[String] = []
		if anim_player != null:
			for lib_name in anim_player.get_animation_library_list():
				var library := anim_player.get_animation_library(lib_name)
				if library == null:
					continue
				for anim_name in library.get_animation_list():
					var anim := library.get_animation(anim_name)
					if anim == null:
						continue
					if _animation_references_shape(anim, node_info):
						var sprite_anim_name := _find_sprite_anim_name(anim)
						if not sprite_anim_name.is_empty():
							relevant_anims.append(sprite_anim_name)
		
		# 4b. 构建帧过滤映射（只针对相关动画）
		var frame_filter := {}
		if anim_player != null:
			frame_filter = _build_frame_filter_for_node(node_info, anim_player, skin_node)
		
		# 4c. 扫描轮廓（只扫描相关动画，始终使用 erosion=0，获取原始轮廓用于 polygon track）
		var frames_data := await _scan_frames_contours(
			sprite_frames, alpha_threshold, simplify_tolerance, min_area_ratio,
			relevant_anims, frame_filter, "attack", callback_obj, result.errors, target_file_path, 0
		)
		
		# 4c. 后处理：计算 attack_heights + 坐标转换 + MABR/Capsule/Rectangle
		var height_definitions := QuiverCharacter._build_height_definitions()
		for sprite_anim_name in frames_data:
			for frame_idx in frames_data[sprite_anim_name]:
				var frame: Dictionary = frames_data[sprite_anim_name][frame_idx]
				var raw: Array = frame["raw_contours"]
				var img_w := int(frame["image_size"].x)
				var img_h := int(frame["image_size"].y)
				
				frame["attack_heights"] = ContourTracer.calc_attack_heights(raw, img_h, height_definitions)
				frame["attack_node"] = node_info["area_node_name"]
				
				var local_contours: Array[PackedVector2Array] = []
				for contour in raw:
					local_contours.append(ContourTracer.pixels_to_shape_local(contour, img_w, img_h))
				frame["contours"] = local_contours
				
				# 如果 Capsule/Rectangle 模式且 erosion_radius > 0，提取腐蚀后的轮廓用于 MABR
				if shape_type != ShapeType.POLYGON and erosion_radius > 0:
					# 重新提取腐蚀后的轮廓
					var image := Image.load_from_file(ProjectSettings.globalize_path(frame["png_path"]))
					var mask: Image = null
					var base_path: String = str(frame["png_path"]).replace(".png", "")
					var specific_mask_path: String = base_path + ".attack.mask.png"
					var generic_mask_path: String = base_path + ".mask.png"
					if FileAccess.file_exists(specific_mask_path):
						mask = Image.load_from_file(ProjectSettings.globalize_path(specific_mask_path))
					elif FileAccess.file_exists(generic_mask_path):
						mask = Image.load_from_file(ProjectSettings.globalize_path(generic_mask_path))
					
					var eroded_raw := ContourTracer.trace_contours(
						image, mask, alpha_threshold, simplify_tolerance, 512, min_area_ratio, erosion_radius
					)
					var eroded_local: Array[PackedVector2Array] = []
					for contour in eroded_raw:
						eroded_local.append(ContourTracer.pixels_to_shape_local(contour, img_w, img_h))
					
					if eroded_local.size() > 0 and eroded_local[0].size() >= 3:
						var mabr := ContourTracer.calc_mabr(eroded_local[0])
						frame["mabr"] = mabr
						frame["capsule"] = ContourTracer.calc_capsule_from_mabr(mabr)
						frame["rectangle"] = {
							"size": mabr.size,
							"angle": mabr.angle,
						}
				else:
					# Polygon 模式或无腐蚀，基于原始轮廓计算 MABR
					if local_contours.size() > 0 and local_contours[0].size() >= 3:
						var mabr := ContourTracer.calc_mabr(local_contours[0])
						frame["mabr"] = mabr
						frame["capsule"] = ContourTracer.calc_capsule_from_mabr(mabr)
						frame["rectangle"] = {
							"size": mabr.size,
							"angle": mabr.angle,
						}
				
				frame.erase("raw_contours")
				
				result.frame_count += 1
		
		# 4d. 如果 dry_run，返回预览结果
		if dry_run:
			result.frames_info = frames_data
			return result
		
		# 4e. 单文件模式检查：形状类型变更时禁止单文件操作
		var skin_scene_path := skin_node.scene_file_path
		var is_single_file_mode := not target_file_path.is_empty()
		if is_single_file_mode:
			var current_type := _detect_current_shape_type(skin_scene_path, node_info["shape_name"])
			if current_type != -1 and current_type != shape_type:
				result.errors.append("形状类型变更（%s → %s）时不支持单文件模式，请先执行全量转换" % [
					ShapeType.keys()[current_type], ShapeType.keys()[shape_type]
				])
				return result
		
		# 4f. 修改 skin .tscn（仅类型不匹配时）
		var attack_shape_names: Array[String] = []
		for attack_node_info in attack_nodes:
			attack_shape_names.append(attack_node_info["shape_name"])
		if _needs_attack_tscn_conversion(skin_scene_path, shape_type, attack_shape_names):
			var first_frame_data := _get_first_frame_data(frames_data)
			_modify_tscn_node(skin_scene_path, node_info, shape_type, first_frame_data, result.errors)
		
		# 4g. 注入 Animation tracks（统一函数）
		if anim_player != null:
			_inject_tracks(anim_player, sprite_frames, node_info, shape_type, frames_data, is_single_file_mode, result.errors, skin_scene_path)
		
		# 4h. 保存当前节点的 frames_data
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


## 获取 frames_data 中第一帧的数据
func _get_first_frame_data(frames_data: Dictionary) -> Dictionary:
	for sprite_anim_name in frames_data.keys():
		var frame_dict: Dictionary = frames_data[sprite_anim_name]
		for frame_idx in frame_dict.keys():
			return frame_dict[frame_idx]
	return {}


## 从 .tscn 内容中提取节点的 unique_id
## 返回: " unique_id=123456" 或 ""（如果没有）
func _extract_unique_id(content: String, node_name: String) -> String:
	var pattern := RegEx.new()
	pattern.compile('\\[node name="%s"[^\\]]*unique_id=(\\d+)' % node_name)
	var match := pattern.search(content)
	if match != null:
		return " unique_id=" + match.get_string(1)
	return ""


## 删除 .tscn 中所有 CapsuleShape2D 和 RectangleShape2D SubResources
func _remove_all_shape_subresources(content: String) -> String:
	# 删除 CapsuleShape2D SubResources
	var capsule_pattern := RegEx.new()
	capsule_pattern.compile('\\[sub_resource type="CapsuleShape2D" id="[^"]*"\\]\\nradius = [^\\n]+\\nheight = [^\\n]+\\n\\n')
	content = capsule_pattern.sub(content, "")
	
	# 删除 RectangleShape2D SubResources
	var rectangle_pattern := RegEx.new()
	rectangle_pattern.compile('\\[sub_resource type="RectangleShape2D" id="[^"]*"\\]\\nsize = Vector2\\([^)]+\\)\\n\\n')
	content = rectangle_pattern.sub(content, "")
	
	return content


## 在 .tscn 中插入 SubResource（在最后一个 SubResource 之后，或 [gd_scene] 之后）
func _insert_subresource(content: String, sub_resource: String) -> String:
	# 找到最后一个 SubResource 的末尾
	var pattern := RegEx.new()
	pattern.compile('\\[sub_resource[^\\]]*\\]\\n(?:.*\\n)*?\\n')
	var matches := pattern.search_all(content)
	
	if matches.size() > 0:
		var last_end: int = matches[-1].get_end()
		return content.insert(last_end, sub_resource)
	
	# 没有 SubResource，在 [gd_scene] 之后插入
	var gd_scene_pattern := RegEx.new()
	gd_scene_pattern.compile('\\[gd_scene[^\\]]*\\]\\n')
	var gd_scene_match := gd_scene_pattern.search(content)
	if gd_scene_match != null:
		return content.insert(gd_scene_match.get_end(), "\n" + sub_resource)
	
	# 兜底：在文件开头插入
	return sub_resource + content


## 在 .tscn 中插入节点（在父节点的所有子节点之后）
func _insert_node_after_parent(content: String, parent_name: String, new_node: String) -> String:
	# 找到父节点的位置
	var parent_pattern := RegEx.new()
	parent_pattern.compile('\\[node name="%s"[^\\]]*\\]' % parent_name)
	var parent_match := parent_pattern.search(content)
	
	if parent_match == null:
		# 找不到父节点，追加到文件末尾
		return content + new_node
	
	# 找到父节点之后的下一个节点位置
	var search_start: int = parent_match.get_end()
	var next_node_pattern := RegEx.new()
	next_node_pattern.compile('\\n\\[node ')
	var next_node_match := next_node_pattern.search(content, search_start)
	
	if next_node_match != null:
		# 在下一个节点之前插入
		return content.insert(next_node_match.get_start() + 1, new_node)
	
	# 没有后续节点，追加到文件末尾
	return content + "\n" + new_node


## 修改 skin .tscn（Body 转换）


## 检测 Attack 的 .tscn 是否需要转换
## 返回 true 表示至少有一个 AttackXShape 的类型与目标类型不匹配
func _needs_body_tscn_conversion(tscn_path: String, target_shape_type: int) -> bool:
	var current_type := _detect_current_shape_type(tscn_path, "HurtShape")
	if current_type == -1:
		return true  # 节点不存在，需要创建
	return current_type != target_shape_type


func _needs_attack_tscn_conversion(tscn_path: String, target_shape_type: int, attack_shape_names: Array[String]) -> bool:
	for shape_name in attack_shape_names:
		var current_type := _detect_current_shape_type(tscn_path, shape_name)
		if current_type == -1:
			continue  # 节点不存在，跳过（可能该攻击类型未使用）
		if current_type != target_shape_type:
			return true  # 至少有一个类型不匹配
	return false


## 检测 .tscn 中指定形状节点的当前类型
## 返回 ShapeType 枚举值，-1 表示未找到或无法识别
func _detect_current_shape_type(tscn_path: String, shape_name: String) -> int:
	if not FileAccess.file_exists(tscn_path):
		return -1
	
	var file := FileAccess.open(tscn_path, FileAccess.READ)
	if file == null:
		return -1
	
	var content := file.get_as_text()
	file.close()
	
	# 检查是否为 CollisionPolygon2D
	var polygon_pattern := RegEx.new()
	polygon_pattern.compile('\\[node name="%s" type="CollisionPolygon2D"' % shape_name)
	if polygon_pattern.search(content) != null:
		return ShapeType.POLYGON
	
	# 检查是否为 CollisionShape2D
	var shape_pattern := RegEx.new()
	shape_pattern.compile('\\[node name="%s" type="CollisionShape2D"[^\\]]*\\](?:\\n(?!\\[node ).*)*' % shape_name)
	var shape_match := shape_pattern.search(content)
	
	if shape_match != null:
		var node_content := shape_match.get_string(0)
		
		# 检查 shape 属性引用的 SubResource 类型
		var sub_ref_pattern := RegEx.new()
		sub_ref_pattern.compile('shape = SubResource\\("([^"]+)"\\)')
		var sub_ref_match := sub_ref_pattern.search(node_content)
		
		if sub_ref_match != null:
			var sub_id := sub_ref_match.get_string(1)
			
			# 查找对应的 SubResource 定义
			var capsule_pattern := RegEx.new()
			capsule_pattern.compile('\\[sub_resource type="CapsuleShape2D" id="%s"\\]' % sub_id)
			if capsule_pattern.search(content) != null:
				return ShapeType.CAPSULE
			
			var rectangle_pattern := RegEx.new()
			rectangle_pattern.compile('\\[sub_resource type="RectangleShape2D" id="%s"\\]' % sub_id)
			if rectangle_pattern.search(content) != null:
				return ShapeType.RECTANGLE
	
	return -1  # 未找到或无法识别


## 生成确定性的 SubResource ID
## 基于前缀和节点名生成唯一的 ID，确保多次运行结果一致
func _generate_subresource_id(prefix: String, node_name: String) -> String:
	return prefix + "_" + (prefix + "_" + node_name).sha1_text().substr(0, 16)



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




## 解析 disabled track 的离散模式，返回 disabled=false 的帧索引
##
## 离散模式（update=1）：每帧的 disabled 值 = 最后一个 <= 帧时间的 keyframe 值
func _parse_disabled_track(anim: Animation, track_idx: int, sprite_anim_name: String, skin_node: Node) -> Array:
	var enabled_frames: Array = []
	
	# 获取 SpriteFrames 的 FPS
	var sprite_frames := _get_sprite_frames(skin_node, [])
	if sprite_frames == null:
		return enabled_frames
	
	var fps := sprite_frames.get_animation_speed(sprite_anim_name)
	if fps <= 0:
		fps = 24.0
	
	var frame_count := sprite_frames.get_frame_count(sprite_anim_name)
	var frame_duration := 1.0 / fps
	
	# 读取所有 keyframe（按时间排序）
	var key_count := anim.track_get_key_count(track_idx)
	var keyframes: Array = []
	for i in range(key_count):
		keyframes.append({
			"time": anim.track_get_key_time(track_idx, i),
			"value": anim.track_get_key_value(track_idx, i),
		})
	
	# 对每帧采样（离散模式：取最后一个 <= 帧时间的 keyframe 值）
	# 使用小容差（0.0001秒）处理浮点数精度问题
	var epsilon := 0.0001
	for frame_idx in range(frame_count):
		var frame_time := float(frame_idx) * frame_duration
		
		var disabled_value: bool = true
		for keyframe in keyframes:
			var kf_time: float = keyframe["time"]
			if kf_time <= frame_time + epsilon:
				disabled_value = keyframe["value"]
			else:
				break
		
		if not disabled_value:
			enabled_frames.append(frame_idx)
	
	return enabled_frames


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


## 删除所有匹配路径前缀的 tracks（排除 disabled track）
## 例如：prefix = "Attacks/Attack1/Attack1Shape:" 会删除该 shape 的所有属性 tracks
## 但保留 disabled track（用于帧过滤）
func _remove_tracks_by_path_prefix(anim: Animation, prefix: String) -> void:
	var tracks_to_remove := []
	
	for track_idx in range(anim.get_track_count()):
		var track_path := str(anim.track_get_path(track_idx))
		if track_path.begins_with(prefix):
			# 保留 disabled track（用于帧过滤）
			if track_path.ends_with(":disabled"):
				continue
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
func preview_single_file(
	file_path: String,
	alpha_threshold: float,
	simplify_tolerance: float,
	min_area_ratio: float,
	erosion_radius: int = 0
) -> Dictionary:
	var result := {
		"file_name": file_path.get_file(),
		"image_size": Vector2.ZERO,
		"contour_count": 0,
		"total_vertices": 0,
		"physical_height": 0.0,
		"attack_heights": [],
		"attack_node": "",
		"bounding_box": Rect2(),
		"alpha_threshold": alpha_threshold,
		"simplify_tolerance": simplify_tolerance,
		"erosion_radius": erosion_radius,
		"has_mask": false,
		"error": "",
		"contours": [],
		"eroded_contours": [],
		"mabr": {},
		"capsule": {},
		"rectangle": {},
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
	
	# 3. 提取轮廓（原始，用于 polygon 显示）
	var contours := ContourTracer.trace_contours(image, mask, alpha_threshold, simplify_tolerance, 512, min_area_ratio, 0)
	if contours.is_empty():
		result.error = "未提取到轮廓"
		return result
	
	result.contour_count = contours.size()
	for contour in contours:
		result.total_vertices += contour.size()
	
	# 3.5 提取腐蚀后的轮廓（用于 MABR 计算）
	var eroded_contours := contours
	if erosion_radius > 0:
		eroded_contours = ContourTracer.trace_contours(image, mask, alpha_threshold, simplify_tolerance, 512, min_area_ratio, erosion_radius)
	
	# 保存轮廓和图片用于预览
	result.contours = contours
	result.eroded_contours = eroded_contours
	result.image = image
	
	# 3.6 计算 MABR/Capsule/Rectangle（基于腐蚀后的轮廓）
	if eroded_contours.size() > 0 and eroded_contours[0].size() >= 3:
		var mabr := ContourTracer.calc_mabr(eroded_contours[0])
		result.mabr = mabr
		result.capsule = ContourTracer.calc_capsule_from_mabr(mabr)
		result.rectangle = {
			"size": mabr.size,
			"angle": mabr.angle,
		}
	
	# 4. 计算 physical_height（始终计算）
	result.physical_height = ContourTracer.calc_physical_height(contours, image.get_height())
	
	# 5. 尝试计算 attack_heights（如果文件名包含 attack 相关信息）
	var sprite_anim_name := file_path.get_file().get_basename()
	var attack_node := _get_attack_node_name(sprite_anim_name)
	if not attack_node.is_empty():
		var height_definitions := QuiverCharacter._build_height_definitions()
		result.attack_heights = ContourTracer.calc_attack_heights(contours, image.get_height(), height_definitions)
		result.attack_node = attack_node
	
	# 6. 坐标转换 + bounding box
	var local_contours: Array[PackedVector2Array] = []
	for contour in contours:
		var local := ContourTracer.pixels_to_shape_local(contour, image.get_width(), image.get_height())
		local_contours.append(local)
	result.bounding_box = _calc_bounding_box(local_contours)
	
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


## 发现所有碰撞形状节点（双通道）
##
## 通道 1：从动画 track 发现（重新转换优先）
## 通道 2：从场景树发现（首次转换回退）
##
## 返回: Array[Dictionary]，每个元素包含：
## - shape_path: String         # 完整路径，如 "AnimatedSprite2D/HurtBox/HurtShape"
## - shape_name: String         # 节点名，如 "HurtShape"
## - parent_path: String        # 父节点路径，如 "AnimatedSprite2D/HurtBox"
## - category: String           # "body" 或 "attack"
## - area_node_name: String     # Area2D 节点名，如 "HurtBox" 或 "Attack1"
## - initial_disabled: bool     # 节点初始 disabled 值
## - node_type: String          # "CollisionPolygon2D" 或 "CollisionShape2D"
func _discover_shape_nodes(skin_node: Node) -> Array:
	return _discover_from_scene_tree(skin_node)


## 从场景树发现碰撞形状节点
##
## 遍历 AnimatedSprite2D/HurtBox 和 Attacks 下的 Area2D 子节点
func _discover_from_scene_tree(skin_node: Node) -> Array:
	var discovered := []
	
	# Body: AnimatedSprite2D/HurtBox 下的碰撞形状
	var hurt_box := skin_node.get_node_or_null(BODY_BOX_PATH)
	if hurt_box != null:
		for child in hurt_box.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				discovered.append(_build_info_from_node(child, "body", hurt_box, skin_node))
	
	# Attack: Attacks 下的 Area2D 子节点
	var attacks := skin_node.get_node_or_null(ATTACKS_PATH)
	if attacks != null:
		for child in attacks.get_children():
			if child is Area2D:
				for shape_child in child.get_children():
					if shape_child is CollisionShape2D or shape_child is CollisionPolygon2D:
						discovered.append(_build_info_from_node(shape_child, "attack", child, skin_node))
	
	return discovered


## 从场景树节点构建 ShapeNodeInfo
func _build_info_from_node(shape_node: Node, category: String, area_node: Node, skin_node: Node) -> Dictionary:
	var shape_name: String = shape_node.name
	var area_node_name: String = area_node.name
	
	# 手动拼接路径，确保与 track 路径格式一致（避免 get_path_to 产生 "./" 前缀）
	var parent_path: String
	if category == "body":
		parent_path = BODY_BOX_PATH  # "AnimatedSprite2D/HurtBox"
	else:
		parent_path = ATTACKS_PATH + "/" + area_node_name  # "Attacks/Attack1"
	
	var shape_path: String = parent_path + "/" + shape_name
	
	var initial_disabled := true
	if "disabled" in shape_node:
		initial_disabled = shape_node.disabled
	
	var node_type := "CollisionShape2D"
	if shape_node is CollisionPolygon2D:
		node_type = "CollisionPolygon2D"
	
	return {
		"shape_path": shape_path,
		"shape_name": shape_name,
		"parent_path": parent_path,
		"category": category,
		"area_node_name": area_node_name,
		"initial_disabled": initial_disabled,
		"node_type": node_type,
	}


## 检查动画是否有任何 track 引用了指定的 shape_node
##
## 遍历动画的所有 tracks，检查是否有任何 track 的路径以 shape_path: 开头
## 用于确定该动画是否应该被处理
func _animation_references_shape(anim: Animation, shape_info: Dictionary) -> bool:
	var shape_path_prefix: String = shape_info["shape_path"] + ":"
	
	for track_idx in range(anim.get_track_count()):
		var track_path := str(anim.track_get_path(track_idx))
		if track_path.begins_with(shape_path_prefix):
			return true
	
	return false


## 为指定形状节点构建帧过滤映射
##
## 遍历所有动画，确定每个动画需要处理的帧
##
## 返回: { sprite_anim_name: { "enabled_frames": Array/null } }
## - null = 跳过该动画
## - [] = 处理所有帧
## - [1,2,3] = 只处理指定帧
func _build_frame_filter_for_node(
	shape_info: Dictionary,
	anim_player: AnimationPlayer,
	skin_node: Node
) -> Dictionary:
	var filter := {}
	
	for lib_name in anim_player.get_animation_library_list():
		var library: AnimationLibrary = anim_player.get_animation_library(lib_name)
		if library == null:
			continue
		
		for anim_name in library.get_animation_list():
			var anim := library.get_animation(anim_name)
			if anim == null:
				continue
			
			var sprite_anim_name := _find_sprite_anim_name(anim)
			if sprite_anim_name.is_empty() or filter.has(sprite_anim_name):
				continue
			
			# 查找该 shape 的 disabled track
			var disabled_path: String = shape_info["shape_path"] + ":disabled"
			var disabled_track_idx := anim.find_track(disabled_path, Animation.TYPE_VALUE)
			
			if disabled_track_idx >= 0:
				# 有 disabled track：解析离散模式，返回 disabled=false 的帧
				var enabled_frames: Array = _parse_disabled_track(anim, disabled_track_idx, sprite_anim_name, skin_node)
				if enabled_frames.is_empty():
					# 有 disabled track 但所有帧都是 disabled=true → 跳过
					filter[sprite_anim_name] = { "enabled_frames": null }
				else:
					filter[sprite_anim_name] = { "enabled_frames": enabled_frames }
			else:
				# 没有 disabled track：读取节点初始 disabled 值
				if not shape_info["initial_disabled"]:
					# 初始 disabled=false → 处理所有帧
					filter[sprite_anim_name] = { "enabled_frames": [] }
				else:
					# 初始 disabled=true → 跳过
					filter[sprite_anim_name] = { "enabled_frames": null }
	
	return filter


## 统一 track 注入函数
##
## 根据 shape_type 和 ShapeNodeInfo 动态生成 track 路径并注入
func _inject_tracks(
	anim_player: AnimationPlayer,
	sprite_frames: SpriteFrames,
	shape_info: Dictionary,
	shape_type: int,
	frames_data: Dictionary,
	is_single_file_mode: bool,
	errors: Array[String],
	tscn_path: String
) -> void:
	var config: Dictionary = SHAPE_CONFIGS[shape_type]
	var shape_tracks: Array = config["tracks"]
	
	for lib_name in anim_player.get_animation_library_list():
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
			
			# 全量模式：删除该 shape 节点的所有 shape 相关 tracks
			# 不区分类型，删除所有可能的 shape 属性（polygon, position, rotation, shape:*）
			if not is_single_file_mode:
				_remove_tracks_by_path_prefix(anim, shape_info["shape_path"] + ":")
			
			# 额外 tracks（必须在 shape tracks 之前处理，避免删除操作影响 track_indices）
			if shape_info["category"] == "body":
				# physical_width track（Skin 节点自身属性）
				var sprite_fps := sprite_frames.get_animation_speed(sprite_anim_name)
				_inject_width_track(anim, frame_dict, sprite_fps, is_single_file_mode)
				_inject_physical_height_track(anim, frame_dict, sprite_fps, is_single_file_mode)
			
			if shape_info["category"] == "attack":
				_inject_attack_node_position(anim, shape_info, is_single_file_mode)
				var sprite_fps := sprite_frames.get_animation_speed(sprite_anim_name)
				_inject_attack_heights_track(anim, frame_dict, sprite_fps, is_single_file_mode)
			
			# 创建/查找当前形状类型的 track（必须在额外 tracks 之后，避免被删除操作影响）
			var track_indices := {}
			for prop in shape_tracks:
				var path: String = shape_info["shape_path"] + ":" + prop
				var track_idx: int
				if is_single_file_mode:
					track_idx = _find_or_add_value_track(anim, path)
				else:
					track_idx = _add_value_track(anim, path)
				track_indices[prop] = track_idx
			
			# 提取 flip_h track 数据
			var flip_track_data := _extract_flip_h_track(anim)
			
			# 逐帧插入关键帧（只在值变化时）
			var sprite_fps := sprite_frames.get_animation_speed(sprite_anim_name)
			var frame_duration: float = 1.0 / max(1.0, sprite_fps)
			var prev_values := {}
			
			for frame_idx in range(sprite_frames.get_frame_count(sprite_anim_name)):
				if not frame_dict.has(frame_idx):
					continue
				
				var frame_info: Dictionary = frame_dict[frame_idx]
				var time: float = float(frame_idx) * frame_duration
				
				for prop in shape_tracks:
					var value := _get_track_value(prop, frame_info, shape_type, flip_track_data, time)
					if value == null:
						continue
					
					if value != prev_values.get(prop):
						if is_single_file_mode:
							_remove_key_at_time(anim, track_indices[prop], time)
						anim.track_insert_key(track_indices[prop], time, value)
						prev_values[prop] = value
			
			# Attack 额外：注入 visible track
			if shape_info["category"] == "attack":
				_inject_visible_track(anim, shape_info, is_single_file_mode)
			
			# 保存 Animation
			var resource_path := anim.resource_path
			if not resource_path.is_empty():
				var err := ResourceSaver.save(anim, resource_path)
				if err != OK:
					errors.append("动画 '%s' 保存失败 (error=%d)" % [anim.resource_name, err])


## 获取 track 属性值（含 flip_h 镜像）
func _get_track_value(
	prop: String,
	frame_info: Dictionary,
	shape_type: int,
	flip_track_data: Array,
	time: float
) -> Variant:
	var is_flipped := _is_flipped_at_time(flip_track_data, time)
	
	match prop:
		"polygon":
			var contours: Array = frame_info.get("contours", [])
			if contours.is_empty():
				return PackedVector2Array()
			var polygon: PackedVector2Array = contours[0]
			return _mirror_polygon_x(polygon) if is_flipped else polygon
		
		"position":
			if shape_type == ShapeType.POLYGON:
				return Vector2(0, 0)  # Polygon 固定值
			elif shape_type == ShapeType.CAPSULE:
				if not frame_info.has("capsule"):
					return null
				var center: Vector2 = frame_info["capsule"]["center"]
				if is_flipped:
					center.x = -center.x
				return center
			else:  # RECTANGLE
				if not frame_info.has("mabr"):
					return null
				var center: Vector2 = frame_info["mabr"]["center"]
				if is_flipped:
					center.x = -center.x
				return center
		
		"rotation":
			if shape_type == ShapeType.POLYGON:
				return 0.0  # Polygon 固定值
			elif shape_type == ShapeType.CAPSULE:
				if not frame_info.has("capsule"):
					return null
				var angle: float = frame_info["capsule"]["angle"]
				return -angle if is_flipped else angle
			else:  # RECTANGLE
				if not frame_info.has("mabr"):
					return null
				var angle: float = frame_info["mabr"]["angle"]
				return -angle if is_flipped else angle
		
		"shape:radius":
			if not frame_info.has("capsule"):
				return null
			return frame_info["capsule"]["radius"]
		
		"shape:height":
			if not frame_info.has("capsule"):
				return null
			return frame_info["capsule"]["height"]
		
		"shape:size":
			if not frame_info.has("rectangle"):
				return null
			return frame_info["rectangle"]["size"]
	
	return null


## 注入 Body 的 physical_width track
func _inject_width_track(
	anim: Animation,
	frame_dict: Dictionary,
	sprite_fps: float,
	is_single_file_mode: bool
) -> void:
	var width_track_idx := _find_or_add_value_track(anim, TRACK_PATH_PHYSICAL_WIDTH)
	if not is_single_file_mode:
		_clear_track_keys(anim, width_track_idx)
	
	var prev_width: float = -1.0
	
	for frame_idx in frame_dict.keys():
		var frame_info: Dictionary = frame_dict[frame_idx]
		var current_width: float = frame_info.get("width", 0.0)
		
		if current_width != prev_width:
			var time: float = float(frame_idx) * (1.0 / sprite_fps)
			if is_single_file_mode:
				_remove_key_at_time(anim, width_track_idx, time)
			anim.track_insert_key(width_track_idx, time, current_width)
			prev_width = current_width


## 注入 Body 的 physical_height track
func _inject_physical_height_track(
	anim: Animation,
	frame_dict: Dictionary,
	sprite_fps: float,
	is_single_file_mode: bool
) -> void:
	var height_track_idx := _find_or_add_value_track(anim, TRACK_PATH_PHYSICAL_HEIGHT)
	if not is_single_file_mode:
		_clear_track_keys(anim, height_track_idx)
	
	var prev_height: float = -1.0
	
	for frame_idx in frame_dict.keys():
		var frame_info: Dictionary = frame_dict[frame_idx]
		var current_height: float = frame_info.get("physical_height", 0.0)
		
		if current_height != prev_height:
			var time: float = float(frame_idx) * (1.0 / sprite_fps)
			if is_single_file_mode:
				_remove_key_at_time(anim, height_track_idx, time)
			anim.track_insert_key(height_track_idx, time, current_height)
			prev_height = current_height


## 注入 Attack 的 attack_heights track
func _inject_attack_heights_track(
	anim: Animation,
	frame_dict: Dictionary,
	sprite_fps: float,
	is_single_file_mode: bool
) -> void:
	var heights_track_idx := _find_or_add_value_track(anim, TRACK_PATH_ATTACK_HEIGHTS)
	if not is_single_file_mode:
		_clear_track_keys(anim, heights_track_idx)
	
	var prev_heights: Array = []
	
	for frame_idx in frame_dict.keys():
		var frame_info: Dictionary = frame_dict[frame_idx]
		var current_heights: Array = frame_info.get("attack_heights", [])
		
		if current_heights != prev_heights:
			var time: float = float(frame_idx) * (1.0 / sprite_fps)
			if is_single_file_mode:
				_remove_key_at_time(anim, heights_track_idx, time)
			anim.track_insert_key(heights_track_idx, time, current_heights)
			prev_heights = current_heights


## 注入 Attack 节点的 position track（跟随 sprite 位置）
func _inject_attack_node_position(
	anim: Animation,
	shape_info: Dictionary,
	is_single_file_mode: bool
) -> void:
	var attack_node_path: String = shape_info["parent_path"] + ":position"
	var attack_pos_track_idx := _find_or_add_value_track(anim, attack_node_path)
	if not is_single_file_mode:
		_clear_track_keys(anim, attack_pos_track_idx)
	
	# 复制 sprite position
	var sprite_pos_track_idx := anim.find_track("AnimatedSprite2D:position", Animation.TYPE_VALUE)
	if sprite_pos_track_idx >= 0:
		var key_count := anim.track_get_key_count(sprite_pos_track_idx)
		for i in key_count:
			var time := anim.track_get_key_time(sprite_pos_track_idx, i)
			var value := anim.track_get_key_value(sprite_pos_track_idx, i)
			anim.track_insert_key(attack_pos_track_idx, time, value)
	else:
		anim.track_insert_key(attack_pos_track_idx, 0.0, Vector2(0, 0))


## 注入 Attack 的 visible track（与 Shape:disabled 反向同步）
func _inject_visible_track(
	anim: Animation,
	shape_info: Dictionary,
	is_single_file_mode: bool
) -> void:
	var visible_path: String = shape_info["parent_path"] + ":visible"
	var disabled_path: String = shape_info["shape_path"] + ":disabled"
	
	var visible_track_idx := _find_or_add_value_track(anim, visible_path)
	if not is_single_file_mode:
		_clear_track_keys(anim, visible_track_idx)
	
	# 查找已有的 disabled track
	var disabled_track_idx := anim.find_track(disabled_path, Animation.TYPE_VALUE)
	
	if disabled_track_idx >= 0:
		# 有 disabled track：逐帧镜像，值取反
		var key_count := anim.track_get_key_count(disabled_track_idx)
		for i in key_count:
			var time := anim.track_get_key_time(disabled_track_idx, i)
			var disabled_value: bool = anim.track_get_key_value(disabled_track_idx, i)
			if is_single_file_mode:
				_remove_key_at_time(anim, visible_track_idx, time)
			anim.track_insert_key(visible_track_idx, time, not disabled_value)
	else:
		# 没有 disabled track：默认 visible = false
		if not is_single_file_mode:
			anim.track_insert_key(visible_track_idx, 0.0, false)


## 统一 .tscn 节点修改函数
##
## 只在形状类型不匹配时修改，只改 type 不改路径
## 使用 shape_info 中的动态路径，不硬编码节点名
func _modify_tscn_node(
	tscn_path: String,
	shape_info: Dictionary,
	shape_type: int,
	first_frame_data: Dictionary,
	errors: Array[String]
) -> void:
	if not FileAccess.file_exists(tscn_path):
		errors.append("skin .tscn 文件不存在: %s" % tscn_path)
		return
	
	var file := FileAccess.open(tscn_path, FileAccess.READ)
	if file == null:
		errors.append("无法读取 skin .tscn: %s" % tscn_path)
		return
	
	var content := file.get_as_text()
	file.close()
	
	var shape_name: String = shape_info["shape_name"]
	var parent_path: String = shape_info["parent_path"]
	var category: String = shape_info["category"]
	
	# 提取现有 unique_id（如果有）
	var unique_id_str := _extract_unique_id(content, shape_name)
	
	# 删除旧节点（兼容 CollisionShape2D 和 CollisionPolygon2D）
	var old_node_pattern := RegEx.new()
	old_node_pattern.compile('\\[node name="%s" type="Collision(?:Shape2D|Polygon2D)"[^\\]]*\\](?:\\n(?!\\[node ).*)*' % shape_name)
	content = old_node_pattern.sub(content, "")
	
	# 删除所有旧的 CapsuleShape2D 和 RectangleShape2D SubResources
	content = _remove_all_shape_subresources(content)
	
	# 根据 shape_type 生成新节点
	var config: Dictionary = SHAPE_CONFIGS[shape_type]
	var node_type: String = config["node_type"]
	var new_content := ""
	
	# modulate 颜色：body 蓝色，attack 红色
	var modulate_color := "Color(0, 0.0666667, 0.701961, 1)" if category == "body" else "Color(1, 0.2, 0.101961, 1)"
	
	match shape_type:
		ShapeType.POLYGON:
			var polygon_str := ""
			if first_frame_data.has("contours") and not first_frame_data["contours"].is_empty():
				polygon_str = ContourTracer.format_polygon_array(first_frame_data["contours"][0])
			new_content = '[node name="%s" type="CollisionPolygon2D" parent="%s" index="0"%s]\nmodulate = %s\nposition = Vector2(0, 0)\npolygon = %s\n' % [shape_name, parent_path, unique_id_str, modulate_color, polygon_str]
			if category == "attack":
				new_content += "disabled = true\n"
			new_content += "\n"
		
		ShapeType.CAPSULE:
			var sub_id := _generate_subresource_id("CapsuleShape2D", shape_name)
			var radius: float = 40.0
			var height: float = 160.0 if category == "body" else 120.0
			if first_frame_data.has("capsule"):
				radius = round(first_frame_data["capsule"]["radius"] * 100.0) / 100.0
				height = round(first_frame_data["capsule"]["height"] * 100.0) / 100.0
			var sub_resource := '[sub_resource type="CapsuleShape2D" id="%s"]\nradius = %.2f\nheight = %.2f\n\n' % [sub_id, radius, height]
			content = _insert_subresource(content, sub_resource)
			new_content = '[node name="%s" type="CollisionShape2D" parent="%s" index="0"%s]\nmodulate = %s\nshape = SubResource("%s")\n' % [shape_name, parent_path, unique_id_str, modulate_color, sub_id]
			if category == "attack":
				new_content += "disabled = true\n"
			new_content += "\n"
		
		ShapeType.RECTANGLE:
			var sub_id := _generate_subresource_id("RectangleShape2D", shape_name)
			var size := Vector2(80, 160) if category == "body" else Vector2(80, 120)
			if first_frame_data.has("rectangle"):
				size = Vector2(
					round(first_frame_data["rectangle"]["size"].x * 100.0) / 100.0,
					round(first_frame_data["rectangle"]["size"].y * 100.0) / 100.0
				)
			var sub_resource := '[sub_resource type="RectangleShape2D" id="%s"]\nsize = Vector2(%.2f, %.2f)\n\n' % [sub_id, size.x, size.y]
			content = _insert_subresource(content, sub_resource)
			new_content = '[node name="%s" type="CollisionShape2D" parent="%s" index="0"%s]\nmodulate = %s\nshape = SubResource("%s")\n' % [shape_name, parent_path, unique_id_str, modulate_color, sub_id]
			if category == "attack":
				new_content += "disabled = true\n"
			new_content += "\n"
	
	# 在对应父节点之后插入新节点
	var area_node_name: String = shape_info["area_node_name"]
	content = _insert_node_after_parent(content, area_node_name, new_content)
	
	# 写回文件
	file = FileAccess.open(tscn_path, FileAccess.WRITE)
	if file == null:
		errors.append("无法写入 skin .tscn: %s" % tscn_path)
		return
	
	file.store_string(content)
	file.close()

### -----------------------------------------------------------------------------------------------
