@tool
class_name AnimationTrackInjector
extends RefCounted
## 动画轨道注入器
##
## 从 PNG 图像提取轮廓多边形，生成碰撞形状 tracks 并写入 Animation 资源。
## 支持 Body（HurtShape）和 Attack（AttackShape）两种模式。
##
## 工作流程：
## 1. 从 Skin 节点的 AnimatedSprite2D 获取 SpriteFrames
## 2. 从 Skin 节点的 AnimationPlayer 获取 AnimationLibrary
## 3. 扫描 PNG 图像，提取轮廓（支持 mask 过滤）
## 4. 对每个动画注入碰撞形状 tracks（polygon/capsule/rectangle）
## 5. 修改场景树中的 shape 节点类型
## 6. 保存修改后的 Animation 资源

### Member Variables and Dependencies -------------------------------------------------------------

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

# ShadowBox 阴影遮挡物路径（AnimatedSprite2D 下的 LightOccluder2D，参与 SDF 纹理生成）
# 阴影始终使用独立扫描的原始 polygon 顶点，与 body 的 shape_type（Polygon/Capsule/Rectangle）无关
const SHADOW_OCCLUDER_PATH := "AnimatedSprite2D/ShadowBox"
const TRACK_PATH_SHADOW_OCCLUDER_POLYGON := SHADOW_OCCLUDER_PATH + ":occluder:polygon"

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


## 清除 track 的所有关键帧（不删除 track 本身）
func _clear_track_keys(anim: Animation, track_idx: int) -> void:
	for i in range(anim.track_get_key_count(track_idx) - 1, -1, -1):
		anim.track_remove_key(track_idx, i)




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
## - callback_obj: 拥有 _on_contour_progress(current, total, filename, phase="") 方法的对象
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
	erosion_radius: int = 0,
	shared_image_cache: Dictionary = {},
	scan_phase: String = ""
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
			
			frames_to_process.append({
				"sprite_anim_name": sprite_anim_name,
				"frame_idx": frame_idx,
				"png_path": png_path,
			})
	
	var total_frames := frames_to_process.size()
	
	# 轮廓结果缓存（key: png_path）— 避免同 scan 内相同 PNG 重复提取轮廓
	var contour_cache := {}
	
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
		
		# 进度回调（传入正确的 total 和扫描阶段）
		if callback_obj != null and callback_obj.has_method("_on_contour_progress"):
			callback_obj._on_contour_progress(current, total_frames, png_path.get_file(), scan_phase)
		
		# 轮廓缓存命中：同 scan 内相同 PNG 不重复提取轮廓
		if contour_cache.has(png_path):
			var cached: Dictionary = contour_cache[png_path]
			frames_data[sprite_anim_name][frame_idx] = {
				"raw_contours": cached["raw_contours"],
				"image_size": cached["image_size"],
				"png_path": png_path,
			}
			continue
		
		# 图像缓存：跨 scan 共享已加载的 PNG 和 mask，避免重复磁盘 I/O
		var image: Image
		var mask: Image
		if shared_image_cache.has(png_path):
			var cached_img: Dictionary = shared_image_cache[png_path]
			image = cached_img["image"]
			mask = cached_img["mask"]
		else:
			image = Image.load_from_file(ProjectSettings.globalize_path(png_path))
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
			
			mask = null
			if FileAccess.file_exists(specific_mask_path):
				mask = Image.load_from_file(ProjectSettings.globalize_path(specific_mask_path))
			elif FileAccess.file_exists(generic_mask_path):
				mask = Image.load_from_file(ProjectSettings.globalize_path(generic_mask_path))
			
			shared_image_cache[png_path] = {"image": image, "mask": mask}
		
		# 提取轮廓（原始像素坐标）— 不同 scan 可能用不同参数，不缓存轮廓结果
		var contours := ContourTracer.trace_contours(image, mask, alpha_threshold, simplify_tolerance, 512, min_area_ratio, erosion_radius)
		if contours.is_empty():
			errors.append("未提取到轮廓: %s" % png_path.get_file())
			continue
		
		frames_data[sprite_anim_name][frame_idx] = {
			"raw_contours": contours,
			"image_size": Vector2(image.get_width(), image.get_height()),
			"png_path": png_path,
		}
		
		# 写入轮廓缓存
		contour_cache[png_path] = {
			"raw_contours": contours,
			"image_size": Vector2(image.get_width(), image.get_height()),
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
	shadow_simplify_tolerance: float = -1.0,
	shadow_min_area_ratio: float = -1.0
) -> Dictionary:
	return await _convert_contours_common(
		skin_node, alpha_threshold, simplify_tolerance, min_area_ratio,
		erosion_radius, shape_type, dry_run, callback_obj,
		"body",
		Callable(self, "_pre_postprocess_body"),
		Callable(self, "_postprocess_body_frame"),
		Callable(self, "_needs_body_tscn_wrapper"),
		"未发现 body 形状节点",
		shadow_simplify_tolerance, shadow_min_area_ratio
	)


## Attack 轮廓转换
func convert_attack_contours(
	skin_node: Node,
	alpha_threshold: float,
	simplify_tolerance: float,
	min_area_ratio: float,
	erosion_radius: int,
	shape_type: int,
	dry_run: bool,
	callback_obj: Object
) -> Dictionary:
	return await _convert_contours_common(
		skin_node, alpha_threshold, simplify_tolerance, min_area_ratio,
		erosion_radius, shape_type, dry_run, callback_obj,
		"attack",
		Callable(self, "_pre_postprocess_attack"),
		Callable(self, "_postprocess_attack_frame"),
		Callable(self, "_needs_attack_tscn_wrapper"),
		""
	)


## 通用轮廓转换核心流程
##
## shadow_simplify_tolerance / shadow_min_area_ratio：ShadowBox 专用扫描参数（仅 body category）。
## 两者均 >= 0 时启用第二次独立扫描，生成 shadow_contours 并注入 :occluder:polygon track。
## -1 表示禁用（attack category 或旧调用方式）。
func _convert_contours_common(
	skin_node: Node,
	alpha_threshold: float,
	simplify_tolerance: float,
	min_area_ratio: float,
	erosion_radius: int,
	shape_type: int,
	dry_run: bool,
	callback_obj: Object,
	category: String,
	pre_postprocess_callback: Callable,
	postprocess_frame_callback: Callable,
	needs_tscn_conversion: Callable,
	empty_error_message: String = "",
	shadow_simplify_tolerance: float = -1.0,
	shadow_min_area_ratio: float = -1.0
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
	
	# 3. 发现 shape 节点
	var all_shape_nodes := _discover_shape_nodes(skin_node)
	var shape_nodes: Array = all_shape_nodes.filter(func(n): return n["category"] == category)
	
	if shape_nodes.is_empty():
		if not empty_error_message.is_empty():
			result.errors.append(empty_error_message)
		return result
	
	var skin_scene_path := skin_node.scene_file_path
	
	# 4. 构建统一帧过滤 + 找出所有相关动画
	var unified_filter := {}
	var relevant_anims: Array[String] = []
	if anim_player != null:
		unified_filter = _build_unified_frame_filter(shape_nodes, anim_player, skin_node)
		relevant_anims = _find_all_relevant_anims(shape_nodes, anim_player)
	
	# 5. 扫描一次（body 轮廓）+ 共享图像缓存避免重复磁盘 I/O
	var image_cache := {}
	var scan_erosion: int = erosion_radius if shape_type != ShapeType.POLYGON else 0
	var frames_data := await _scan_frames_contours(
		sprite_frames, alpha_threshold, simplify_tolerance, min_area_ratio,
		relevant_anims, unified_filter, category, callback_obj, result.errors, scan_erosion,
		image_cache, "Body"
	)
	
	# 5b. ShadowBox 第二次独立扫描（仅 body category，参数独立）
	# 阴影不需要形态学腐蚀（erosion_radius = 0），不执行 MABR/Capsule/Rectangle 转换，
	# 不计算 physical_height/width，只保留原始 polygon 顶点
	# 共享 image_cache，同一张 PNG 的磁盘 I/O 只执行一次
	var shadow_scan_enabled := category == "body" \
		and shadow_simplify_tolerance >= 0.0 and shadow_min_area_ratio >= 0.0
	if shadow_scan_enabled:
		var shadow_frames_data := await _scan_frames_contours(
			sprite_frames, alpha_threshold, shadow_simplify_tolerance, shadow_min_area_ratio,
			relevant_anims, unified_filter, category, callback_obj, result.errors, 0,
			image_cache, "Shadow"
		)
		for shadow_anim_name in shadow_frames_data:
			if not frames_data.has(shadow_anim_name):
				continue
			for shadow_frame_idx in shadow_frames_data[shadow_anim_name]:
				if frames_data[shadow_anim_name].has(shadow_frame_idx):
					frames_data[shadow_anim_name][shadow_frame_idx]["shadow_raw_contours"] = \
						shadow_frames_data[shadow_anim_name][shadow_frame_idx]["raw_contours"]
	
	# 6. 预处理（如构建 attack 映射表）
	var preprocess_data: Dictionary = pre_postprocess_callback.call(shape_nodes, anim_player, skin_node)
	
	# 7. 后处理一次（纯计算）
	for sprite_anim_name in frames_data:
		for frame_idx in frames_data[sprite_anim_name]:
			var frame: Dictionary = frames_data[sprite_anim_name][frame_idx]
			var raw: Array = frame["raw_contours"]
			var img_w := int(frame["image_size"].x)
			var img_h := int(frame["image_size"].y)
			
			# 7a. 调用回调设置 category 特有字段
			postprocess_frame_callback.call(frame, raw, img_w, img_h, sprite_anim_name, preprocess_data)
			
			# 7b. 公共处理：坐标变换
			var local_contours: Array[PackedVector2Array] = []
			for contour in raw:
				local_contours.append(ContourTracer.pixels_to_shape_local(contour, img_w, img_h))
			frame["contours"] = local_contours
			
			# 7c. 公共处理：MABR + capsule + rectangle
			if local_contours.size() > 0 and local_contours[0].size() >= 3:
				var mabr := ContourTracer.calc_mabr(local_contours[0])
				frame["mabr"] = mabr
				frame["capsule"] = ContourTracer.calc_capsule_from_mabr(mabr)
				frame["rectangle"] = {
					"size": mabr.size,
					"angle": mabr.angle,
				}
			
			# 7d. ShadowBox 轮廓坐标变换（仅 body，独立扫描数据）
			# 只取原始轮廓做坐标变换，不计算 MABR/capsule/rectangle
			if frame.has("shadow_raw_contours"):
				var shadow_local: Array[PackedVector2Array] = []
				for shadow_contour in frame["shadow_raw_contours"]:
					shadow_local.append(ContourTracer.pixels_to_shape_local(shadow_contour, img_w, img_h))
				frame["shadow_contours"] = shadow_local
				frame.erase("shadow_raw_contours")
			
			frame.erase("raw_contours")
			result.frame_count += 1
	
	# 8. dry_run
	if dry_run:
		result.frames_info = frames_data
		return result
	
	# 9. 预计算 shape type 变更状态（在修改场景树之前，从场景树读取）
	var shape_type_changed := {}
	for node_info in shape_nodes:
		var shape_node := skin_node.get_node_or_null(node_info["shape_path"])
		var current_type := _detect_shape_type_from_node(shape_node)
		shape_type_changed[node_info["shape_name"]] = current_type != -1 and current_type != shape_type
	
	# 11. 修改场景树节点（仅类型不匹配时，不直接写 .tscn 文件）
	if needs_tscn_conversion.call(skin_node, shape_type, shape_nodes):
		for node_info in shape_nodes:
			var first_frame_data := _get_first_frame_data(frames_data)
			_modify_scene_tree_node(skin_node, node_info, shape_type, first_frame_data, result.errors)
	
	# 11b. 确保 ShadowBox 节点存在（仅 body 且启用了 shadow 扫描时）
	# 旧模板创建的角色可能没有 ShadowBox，此处自动补建
	if shadow_scan_enabled:
		_ensure_shadow_occluder_exists(skin_node)
	
	# 12. 构建 per-shape 过滤映射
	var per_shape_filters := {}
	if anim_player != null:
		for node_info in shape_nodes:
			per_shape_filters[node_info["shape_path"]] = _build_frame_filter_for_node(node_info, anim_player, skin_node)
	
	# 13. 统一注入 tracks（遍历动画一次，内层按 shape 分发）
	if anim_player != null:
		_inject_all_tracks(anim_player, sprite_frames, shape_nodes, shape_type, frames_data, per_shape_filters, result.errors, skin_scene_path, shape_type_changed)
	
	result.frames_info = frames_data
	return result


## Body 预处理：无操作
func _pre_postprocess_body(shape_nodes: Array, anim_player: AnimationPlayer, skin_node: Node) -> Dictionary:
	return {}


## Attack 预处理：构建 sprite_anim → attack_node 映射表
func _pre_postprocess_attack(shape_nodes: Array, anim_player: AnimationPlayer, skin_node: Node) -> Dictionary:
	var sprite_to_attack_node := {}
	if anim_player == null:
		return sprite_to_attack_node
	
	for lib_name in anim_player.get_animation_library_list():
		var library := anim_player.get_animation_library(lib_name)
		if library == null:
			continue
		for anim_name in library.get_animation_list():
			var anim := library.get_animation(anim_name)
			if anim == null:
				continue
			var san := _find_sprite_anim_name(anim)
			if not san.is_empty() and not sprite_to_attack_node.has(san):
				sprite_to_attack_node[san] = _find_attack_node_for_anim(anim, shape_nodes, san, skin_node)
	
	return sprite_to_attack_node


## Body 帧后处理：设置 physical_height + width
func _postprocess_body_frame(frame: Dictionary, raw: Array, img_w: int, img_h: int, sprite_anim_name: String, preprocess_data: Dictionary) -> void:
	frame["physical_height"] = ContourTracer.calc_physical_height(raw, img_h)
	frame["width"] = ContourTracer.calc_contour_width(raw)


## Attack 帧后处理：设置 attack_heights + attack_node
func _postprocess_attack_frame(frame: Dictionary, raw: Array, img_w: int, img_h: int, sprite_anim_name: String, preprocess_data: Dictionary) -> void:
	var height_definitions := QuiverCharacter._build_height_definitions()
	frame["attack_heights"] = ContourTracer.calc_attack_heights(raw, img_h, height_definitions)
	frame["attack_node"] = preprocess_data.get(sprite_anim_name, "")


## Body .tscn 判断
func _needs_body_tscn_wrapper(skin_node: Node, shape_type: int, shape_nodes: Array) -> bool:
	return _needs_body_tscn_conversion(skin_node, shape_type)


## Attack .tscn 判断
func _needs_attack_tscn_wrapper(skin_node: Node, shape_type: int, shape_nodes: Array) -> bool:
	return _needs_attack_tscn_conversion(skin_node, shape_type, shape_nodes)


## 获取 frames_data 中第一帧的数据
func _get_first_frame_data(frames_data: Dictionary) -> Dictionary:
	for sprite_anim_name in frames_data.keys():
		var frame_dict: Dictionary = frames_data[sprite_anim_name]
		for frame_idx in frame_dict.keys():
			return frame_dict[frame_idx]
	return {}


## 从场景树节点检测 shape 类型
## 返回 ShapeType 枚举值，-1 表示无法识别
func _detect_shape_type_from_node(shape_node: Node) -> int:
	if shape_node == null:
		return -1
	if shape_node is CollisionPolygon2D:
		return ShapeType.POLYGON
	if shape_node is CollisionShape2D:
		var shape = shape_node.shape
		if shape is CapsuleShape2D:
			return ShapeType.CAPSULE
		if shape is RectangleShape2D:
			return ShapeType.RECTANGLE
	return -1


## 检测 Body 是否需要转换（从场景树读取）
func _needs_body_tscn_conversion(skin_node: Node, target_shape_type: int) -> bool:
	var hurt_shape := skin_node.get_node_or_null("AnimatedSprite2D/HurtBox/HurtShape")
	var current_type := _detect_shape_type_from_node(hurt_shape)
	if current_type == -1:
		return true
	return current_type != target_shape_type


## 检测 Attack 是否需要转换（从场景树读取）
func _needs_attack_tscn_conversion(skin_node: Node, target_shape_type: int, shape_nodes: Array) -> bool:
	for node_info in shape_nodes:
		var shape_node := skin_node.get_node_or_null(node_info["shape_path"])
		var current_type := _detect_shape_type_from_node(shape_node)
		if current_type == -1:
			continue
		if current_type != target_shape_type:
			return true
	return false






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


## 清除所有匹配路径前缀的 track 的 keyframe（不删除 track 本身，确保 track 顺序稳定）
## 排除 disabled track（用于帧过滤）
func _clear_tracks_by_path_prefix(anim: Animation, prefix: String) -> void:
	for track_idx in range(anim.get_track_count()):
		var track_path := str(anim.track_get_path(track_idx))
		if track_path.begins_with(prefix):
			if track_path.ends_with(":disabled"):
				continue
			_clear_track_keys(anim, track_idx)


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


## 找出引用了任一 shape 节点的动画的 sprite_anim_name 列表
func _find_all_relevant_anims(
	shape_nodes: Array,
	anim_player: AnimationPlayer
) -> Array[String]:
	var relevant_anims: Array[String] = []
	if anim_player == null:
		return relevant_anims
	for lib_name in anim_player.get_animation_library_list():
		var library := anim_player.get_animation_library(lib_name)
		if library == null:
			continue
		for anim_name in library.get_animation_list():
			var anim := library.get_animation(anim_name)
			if anim == null:
				continue
			for node_info in shape_nodes:
				if _animation_references_shape(anim, node_info):
					var sprite_anim_name := _find_sprite_anim_name(anim)
					if not sprite_anim_name.is_empty() and sprite_anim_name not in relevant_anims:
						relevant_anims.append(sprite_anim_name)
					break
	return relevant_anims


## 构建统一的帧过滤映射（合并所有 shape 的过滤信息）
##
## 对每个动画，取所有 shape 的 enabled_frames 的并集
## - 如果所有 shape 都返回 null → 跳过该动画
## - 如果任一 shape 返回 [] → 处理所有帧
## - 否则 → 取所有非 null 的 enabled_frames 的并集
##
## 返回: { sprite_anim_name: { "enabled_frames": Array/null } }
func _build_unified_frame_filter(
	shape_nodes: Array,
	anim_player: AnimationPlayer,
	skin_node: Node
) -> Dictionary:
	var unified := {}
	
	for node_info in shape_nodes:
		var node_filter := _build_frame_filter_for_node(node_info, anim_player, skin_node)
		for sprite_anim in node_filter:
			var new_enabled = node_filter[sprite_anim]["enabled_frames"]
			
			if not unified.has(sprite_anim):
				unified[sprite_anim] = { "enabled_frames": new_enabled }
				continue
			
			var existing = unified[sprite_anim]["enabled_frames"]
			
			if existing == null:
				unified[sprite_anim]["enabled_frames"] = new_enabled
			elif new_enabled == null:
				pass
			elif existing is Array and existing.is_empty():
				pass
			elif new_enabled is Array and new_enabled.is_empty():
				unified[sprite_anim]["enabled_frames"] = []
			elif existing is Array and new_enabled is Array:
				for f in new_enabled:
					if f not in existing:
						existing.append(f)
	
	return unified


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
			if sprite_anim_name.is_empty():
				continue
			
			# 查找该 shape 的 disabled track
			var disabled_path: String = shape_info["shape_path"] + ":disabled"
			var disabled_track_idx := anim.find_track(disabled_path, Animation.TYPE_VALUE)
			
			var new_enabled_frames
			if disabled_track_idx >= 0:
				# 有 disabled track：解析离散模式，返回 disabled=false 的帧
				var enabled_frames: Array = _parse_disabled_track(anim, disabled_track_idx, sprite_anim_name, skin_node)
				if enabled_frames.is_empty():
					# 有 disabled track 但所有帧都是 disabled=true → 跳过
					new_enabled_frames = null
				else:
					new_enabled_frames = enabled_frames
			else:
				# 没有 disabled track：读取节点初始 disabled 值
				if not shape_info["initial_disabled"]:
					# 初始 disabled=false → 处理所有帧
					new_enabled_frames = []
				else:
					# 初始 disabled=true → 跳过
					new_enabled_frames = null
			
			# 合并或新增 filter entry
			if filter.has(sprite_anim_name):
				var existing = filter[sprite_anim_name]["enabled_frames"]
				filter[sprite_anim_name]["enabled_frames"] = _merge_enabled_frames(existing, new_enabled_frames)
			else:
				filter[sprite_anim_name] = { "enabled_frames": new_enabled_frames }
	
	return filter


## 合并两个 enabled_frames 值（取并集，优先选择更宽松的）
## null = 全部跳过（空集）
## [] = 全部处理（全集）
## [0, 1] = 只处理指定帧（子集）
static func _merge_enabled_frames(existing, new_frames):
	# []（全集）∪ 任何 = []（全集）
	if existing is Array and existing.is_empty():
		return []
	if new_frames is Array and new_frames.is_empty():
		return []
	
	# null（空集）∪ X = X
	if existing == null:
		return new_frames
	if new_frames == null:
		return existing
	
	# 两个都是具体数组，取并集
	var merged = existing.duplicate()
	for f in new_frames:
		if f not in merged:
			merged.append(f)
	return merged


## 确定动画映射到哪个 attack 节点（通过检查哪个 shape 有 enabled 帧）
func _find_attack_node_for_anim(
	anim: Animation,
	attack_nodes: Array,
	sprite_anim_name: String,
	skin_node: Node
) -> String:
	for node_info in attack_nodes:
		if not _animation_references_shape(anim, node_info):
			continue
		var disabled_path: String = node_info["shape_path"] + ":disabled"
		var disabled_idx := anim.find_track(disabled_path, Animation.TYPE_VALUE)
		if disabled_idx >= 0:
			var enabled_frames := _parse_disabled_track(anim, disabled_idx, sprite_anim_name, skin_node)
			if not enabled_frames.is_empty():
				return node_info["area_node_name"]
		elif not node_info["initial_disabled"]:
			return node_info["area_node_name"]
	return ""


## 统一 track 注入函数（遍历动画一次，内层按 shape 分发）
##
## 遍历所有动画，对每个动画：
##   1. 按 shape 写入 per-shape tracks（polygon/position/rotation + visible + attack_node_position）
##   2. 写入共享 tracks（physical_width/height 或 attack_heights）
##   3. 保存一次
##
## per_shape_filters: { shape_path: { sprite_anim: { "enabled_frames": null/[]/[1,2] } } }
## shape_type_changed: { shape_name: bool }
func _inject_all_tracks(
	anim_player: AnimationPlayer,
	sprite_frames: SpriteFrames,
	shape_nodes: Array,
	shape_type: int,
	frames_data: Dictionary,
	per_shape_filters: Dictionary,
	errors: Array[String],
	tscn_path: String,
	shape_type_changed: Dictionary
) -> void:
	var config: Dictionary = SHAPE_CONFIGS[shape_type]
	var shape_tracks: Array = config["tracks"]
	var category: String = shape_nodes[0]["category"] if shape_nodes.size() > 0 else ""
	
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
			
			var anim_modified := false
			var flip_track_data := _extract_flip_h_track(anim)
			var sprite_fps := sprite_frames.get_animation_speed(sprite_anim_name)
			var frame_duration: float = 1.0 / max(1.0, sprite_fps)
			
			# 内层：按 shape 写入 per-shape tracks
			for node_info in shape_nodes:
				# shape type 变更时删除旧 tracks，否则只清除 keyframe
				# 必须在 enabled_frames 检查之前执行，确保即使所有帧都 disabled 也会清除旧 tracks
				if shape_type_changed.get(node_info["shape_name"], false):
					_remove_tracks_by_path_prefix(anim, node_info["shape_path"] + ":")
				else:
					_clear_tracks_by_path_prefix(anim, node_info["shape_path"] + ":")
				
				var shape_filter: Dictionary = per_shape_filters.get(node_info["shape_path"], {})
				var filter_info: Dictionary = shape_filter.get(sprite_anim_name, {})
				var enabled_frames = filter_info.get("enabled_frames", null)
				if enabled_frames == null:
					continue
				
				# Attack node position
				if category == "attack":
					_inject_attack_node_position(anim, node_info)
				
				# 创建 shape tracks
				var track_indices := {}
				for prop in shape_tracks:
					var path: String = node_info["shape_path"] + ":" + prop
					track_indices[prop] = _find_or_add_value_track(anim, path)
				
				# 逐帧插入关键帧
				var prev_values := {}
				for frame_idx in range(sprite_frames.get_frame_count(sprite_anim_name)):
					if not frame_dict.has(frame_idx):
						continue
					if enabled_frames is Array and not enabled_frames.is_empty() and frame_idx not in enabled_frames:
						continue
					
					var frame_info: Dictionary = frame_dict[frame_idx]
					var time: float = float(frame_idx) * frame_duration
					
					for prop in shape_tracks:
						var value := _get_track_value(prop, frame_info, shape_type, flip_track_data, time)
						if value == null:
							continue
						if value != prev_values.get(prop):
							anim.track_insert_key(track_indices[prop], time, value)
							prev_values[prop] = value
				
				# Visible track（attack only）
				if category == "attack":
					_inject_visible_track(anim, node_info)
				
				anim_modified = true
			
			# 共享 tracks
			if category == "body":
				_inject_width_track(anim, frame_dict, sprite_fps)
				_inject_physical_height_track(anim, frame_dict, sprite_fps)
				if _frame_dict_has_shadow_contours(frame_dict):
					_inject_occluder_polygon_tracks(anim, frame_dict, sprite_fps, flip_track_data)
				anim_modified = true
			elif category == "attack":
				var heights_frame_dict := {}
				for fi in frame_dict:
					heights_frame_dict[fi] = { "attack_heights": frame_dict[fi].get("attack_heights", []) }
				_inject_attack_heights_track(anim, heights_frame_dict, sprite_fps)
				anim_modified = true
			
			# 每个动画标记为已修改并立即保存到磁盘
			if anim_modified:
				anim.emit_changed()
				var resource_path := anim.resource_path
				if not resource_path.is_empty():
					var err := ResourceSaver.save(anim, resource_path)
					if err != OK:
						errors.append("动画 '%s' 保存失败 (error=%d)" % [anim_name, err])


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
	sprite_fps: float
) -> void:
	var width_track_idx := _find_or_add_value_track(anim, TRACK_PATH_PHYSICAL_WIDTH)
	_clear_track_keys(anim, width_track_idx)
	
	var prev_width: float = -1.0
	
	for frame_idx in frame_dict.keys():
		var frame_info: Dictionary = frame_dict[frame_idx]
		var current_width: float = frame_info.get("width", 0.0)
		
		if current_width != prev_width:
			var time: float = float(frame_idx) * (1.0 / sprite_fps)
			anim.track_insert_key(width_track_idx, time, current_width)
			prev_width = current_width


## 注入 Body 的 physical_height track
func _inject_physical_height_track(
	anim: Animation,
	frame_dict: Dictionary,
	sprite_fps: float
) -> void:
	var height_track_idx := _find_or_add_value_track(anim, TRACK_PATH_PHYSICAL_HEIGHT)
	_clear_track_keys(anim, height_track_idx)
	
	var prev_height: float = -1.0
	
	for frame_idx in frame_dict.keys():
		var frame_info: Dictionary = frame_dict[frame_idx]
		var current_height: float = frame_info.get("physical_height", 0.0)
		
		if current_height != prev_height:
			var time: float = float(frame_idx) * (1.0 / sprite_fps)
			anim.track_insert_key(height_track_idx, time, current_height)
			prev_height = current_height


## 检查 frame_dict 中是否有任何帧包含 shadow_contours 数据
## 用于决定是否注入 ShadowBox track（无 shadow 扫描数据时跳过，避免创建空 track）
func _frame_dict_has_shadow_contours(frame_dict: Dictionary) -> bool:
	for frame_idx in frame_dict:
		var frame_info: Dictionary = frame_dict[frame_idx]
		if not frame_info.get("shadow_contours", []).is_empty():
			return true
	return false


## 注入 ShadowBox 的 occluder:polygon track（封装复用）
##
## 每帧写入 shadow_contours[0]（OccluderPolygon2D.polygon 只支持单一 PackedVector2Array，
## 与 CollisionPolygon2D.polygon 同限制；多分离部分时只取第一个轮廓 = 最大面积）。
## 复用调用方已提取的 flip_track_data，flip_h 时对 polygon 做 X 镜像，不重复提取。
## 相邻帧 polygon 相同时去重，减少关键帧数量。
func _inject_occluder_polygon_tracks(
	anim: Animation,
	frame_dict: Dictionary,
	sprite_fps: float,
	flip_track_data: Array
) -> void:
	var polygon_track_idx := _find_or_add_value_track(anim, TRACK_PATH_SHADOW_OCCLUDER_POLYGON)
	_clear_track_keys(anim, polygon_track_idx)
	
	var prev_polygon: PackedVector2Array = PackedVector2Array()
	var has_prev := false
	
	for frame_idx in frame_dict.keys():
		var frame_info: Dictionary = frame_dict[frame_idx]
		var shadow_contours: Array = frame_info.get("shadow_contours", [])
		if shadow_contours.is_empty():
			continue
		
		var polygon: PackedVector2Array = shadow_contours[0]
		var time: float = float(frame_idx) * (1.0 / sprite_fps)
		
		# 复用调用方已提取的 flip_track_data
		if _is_flipped_at_time(flip_track_data, time):
			polygon = _mirror_polygon_x(polygon)
		
		if not has_prev or polygon != prev_polygon:
			anim.track_insert_key(polygon_track_idx, time, polygon)
			prev_polygon = polygon
			has_prev = true


## 注入 Attack 的 attack_heights track
func _inject_attack_heights_track(
	anim: Animation,
	frame_dict: Dictionary,
	sprite_fps: float
) -> void:
	var heights_track_idx := _find_or_add_value_track(anim, TRACK_PATH_ATTACK_HEIGHTS)
	_clear_track_keys(anim, heights_track_idx)
	
	var prev_heights: Array = []
	
	for frame_idx in frame_dict.keys():
		var frame_info: Dictionary = frame_dict[frame_idx]
		var current_heights: Array = frame_info.get("attack_heights", [])
		
		if current_heights != prev_heights:
			var time: float = float(frame_idx) * (1.0 / sprite_fps)
			anim.track_insert_key(heights_track_idx, time, current_heights)
			prev_heights = current_heights


## 注入 Attack 节点的 position track（跟随 sprite 位置）
func _inject_attack_node_position(
	anim: Animation,
	shape_info: Dictionary
) -> void:
	var attack_node_path: String = shape_info["parent_path"] + ":position"
	var attack_pos_track_idx := _find_or_add_value_track(anim, attack_node_path)
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
	shape_info: Dictionary
) -> void:
	var visible_path: String = shape_info["parent_path"] + ":visible"
	var disabled_path: String = shape_info["shape_path"] + ":disabled"
	
	var visible_track_idx := _find_or_add_value_track(anim, visible_path)
	_clear_track_keys(anim, visible_track_idx)
	
	# 查找已有的 disabled track
	var disabled_track_idx := anim.find_track(disabled_path, Animation.TYPE_VALUE)
	
	if disabled_track_idx >= 0:
		# 有 disabled track：逐帧镜像，值取反
		var key_count := anim.track_get_key_count(disabled_track_idx)
		for i in key_count:
			var time := anim.track_get_key_time(disabled_track_idx, i)
			var disabled_value: bool = anim.track_get_key_value(disabled_track_idx, i)
			anim.track_insert_key(visible_track_idx, time, not disabled_value)
	else:
		# 没有 disabled track：默认 visible = false
		anim.track_insert_key(visible_track_idx, 0.0, false)


## 修改场景树中的 shape 节点（不直接写 .tscn 文件）
## 编辑器会自动标记场景为"已修改"，用户 Ctrl+S 时保存
func _modify_scene_tree_node(
	skin_node: Node,
	shape_info: Dictionary,
	shape_type: int,
	first_frame_data: Dictionary,
	errors: Array[String]
) -> void:
	var parent := skin_node.get_node_or_null(shape_info["parent_path"])
	if parent == null:
		errors.append("父节点不存在: %s" % shape_info["parent_path"])
		return
	
	var shape_name: String = shape_info["shape_name"]
	var old_node := parent.get_node_or_null(shape_name)
	
	# 删除旧节点
	if old_node != null:
		parent.remove_child(old_node)  # 立即从父节点移除，避免命名冲突
		old_node.queue_free()  # 延迟释放内存
	
	# 创建新节点
	var new_node: Node
	match shape_type:
		ShapeType.POLYGON:
			new_node = CollisionPolygon2D.new()
			new_node.name = shape_name
			if first_frame_data.has("contours") and not first_frame_data["contours"].is_empty():
				new_node.polygon = first_frame_data["contours"][0]
		
		ShapeType.CAPSULE:
			new_node = CollisionShape2D.new()
			new_node.name = shape_name
			var capsule := CapsuleShape2D.new()
			capsule.radius = 40.0
			capsule.height = 160.0 if shape_info["category"] == "body" else 120.0
			if first_frame_data.has("capsule"):
				capsule.radius = first_frame_data["capsule"]["radius"]
				capsule.height = first_frame_data["capsule"]["height"]
			new_node.shape = capsule
		
		ShapeType.RECTANGLE:
			new_node = CollisionShape2D.new()
			new_node.name = shape_name
			var rect := RectangleShape2D.new()
			rect.size = Vector2(80, 160) if shape_info["category"] == "body" else Vector2(80, 120)
			if first_frame_data.has("rectangle"):
				rect.size = first_frame_data["rectangle"]["size"]
			new_node.shape = rect
	
	# 设置通用属性
	new_node.modulate = Color(0, 0.0666667, 0.701961, 1) if shape_info["category"] == "body" else Color(1, 0.2, 0.101961, 1)
	if shape_info["category"] == "attack":
		new_node.disabled = true
	
	# 添加到父节点
	parent.add_child(new_node)
	# 确保节点被场景拥有，Ctrl+S 时会保存
	# 当 skin_node 是场景根节点时，owner 为 null，使用 skin_node 自身作为 owner
	new_node.owner = skin_node.owner if skin_node.owner else skin_node


## 确保 AnimatedSprite2D 下存在 ShadowBox (LightOccluder2D) 节点
## 不存在则创建：LightOccluder2D（name="ShadowBox", sdf_collision=true）
## + OccluderPolygon2D（closed=true，空 polygon，由动画 track 逐帧驱动）
## 已存在则不做任何操作（保留现有 occluder，track 注入会覆盖 polygon）
func _ensure_shadow_occluder_exists(skin_node: Node) -> void:
	var sprite_node := skin_node.get_node_or_null("AnimatedSprite2D")
	if sprite_node == null:
		return
	if sprite_node.has_node("ShadowBox"):
		return
	
	var occluder_polygon := OccluderPolygon2D.new()
	occluder_polygon.closed = true
	
	var shadow_box := LightOccluder2D.new()
	shadow_box.name = "ShadowBox"
	shadow_box.sdf_collision = true
	shadow_box.occluder = occluder_polygon
	
	sprite_node.add_child(shadow_box)
	# 确保节点被场景拥有，Ctrl+S 时会保存（与 _modify_scene_tree_node 相同处理）
	shadow_box.owner = skin_node.owner if skin_node.owner else skin_node


### -----------------------------------------------------------------------------------------------
