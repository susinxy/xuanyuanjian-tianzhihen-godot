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
##    c. 插入 physical_height / attack_heights / _sync_base_height 轨道
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
	var attack_track_idx := _add_value_track(anim, TRACK_PATH_ATTACK_HEIGHTS)
	var method_track_idx := _add_method_track(anim, TRACK_PATH_BASE_HEIGHT_METHOD)
	
	# 3. 计算 sprite 的帧间隔
	var frame_duration: float = 1.0 / max(1.0, sprite_fps)
	
	# 4. 逐帧插入 keys
	var inserted_count := 0
	for frame_idx in range(sprite_frame_count):
		var data: Dictionary = frame_data.get(frame_idx, {})
		if data.is_empty():
			continue
		
		var time: float = float(frame_idx) * frame_duration
		
		# physical_height 关键帧
		if data.has("physical"):
			anim.track_insert_key(physical_track_idx, time, data["physical"])
		
		# attack_heights 关键帧（即使为空也插入，表示非攻击帧）
		var attack_arr: Array = data.get("attack_heights", [])
		anim.track_insert_key(attack_track_idx, time, attack_arr)
		
		# 每帧插入 _sync_base_height method call
		# method track 键值格式: {"args": [], "method": "method_name"}
		anim.track_insert_key(method_track_idx, time, {
			"args": [],
			"method": StringName(METHOD_NAME_SYNC_BASE_HEIGHT)
		})
		
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


## 移除旧的 height tracks（通过 path 匹配）
## 同时清理当前版本路径和历史版本路径，避免残留
func _remove_old_height_tracks(anim: Animation) -> void:
	var tracks_to_remove := []
	var target_paths := [
		# 当前版本路径（.: 前缀，访问 root_node 自身属性）
		TRACK_PATH_PHYSICAL_HEIGHT,      # ".:physical_height"
		TRACK_PATH_ATTACK_HEIGHTS,       # ".:attack_heights"
		TRACK_PATH_BASE_HEIGHT_METHOD,   # "."
		# 历史版本路径 1：无前缀但缺少 . 前缀（当前错误）
		"physical_height",
		"attack_heights",
		# 历史版本路径 2：../ 前缀（曾尝试 root_node=".."）
		"../physical_height",
		"../attack_heights",
		"..",
		# 历史版本路径 3：../../ 前缀（错误推导 root_node）
		"../../physical_height",
		"../../attack_heights",
		"../..",
	]
	
	for track_idx in range(anim.get_track_count()):
		var track_path_str := str(anim.track_get_path(track_idx))
		if track_path_str in target_paths:
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


## 添加 method track
## method track 不需要设置 update mode 或插值类型
func _add_method_track(anim: Animation, track_path: String) -> int:
	var track_idx := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(track_idx, track_path)
	return track_idx

### -----------------------------------------------------------------------------------------------
