@tool
class_name CharacterHeightData
extends Resource
## 高度数据 Resource - 存储动画帧的高度标注信息
##
## 用作 Inspector 扫描工具的输出预览，便于人工查阅和验证。
## 数据结构：{ animation_name: { frame_idx: { physical, attack_heights, speed } } }
##
## 文件命名规范（参见 docs/HEIGHT_LAYER_DESIGN.md Section 5）：
## - physical_<P>   必填，物理身高（像素）
## - attack_<Z1>_<Z2>...   可选，攻击高度偏移列表
## - speed_<S>   可选，跳跃/击飞的初速度（仅在跳跃动画首帧出现）
##
## 命名顺序约定：speed 在前（可选），physical 在中，attack 在后。
## 示例：
##   attack1_02_physical_180_attack_30.png
##   jump_00_speed_-1200_physical_180.png
##   air_attack_01_physical_170_attack_80_120.png

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

# 各 marker 的长度（含前导下划线）
const LEN_PHYSICAL := 10  # "_physical_"
const LEN_ATTACK := 8     # "_attack_"
const LEN_SPEED := 7      # "_speed_"

#--- public variables - order: export > normal var & onready --------------------------------------

## 动画帧高度数据字典：{ anim_name: { frame_idx: { physical: float, attack_heights: Array[float], speed: float|null } } }
@export var frame_heights: Dictionary = {}

## 扫描过程中收集的错误信息
@export var parse_errors: Array[String] = []

#--- private variables - order: export > normal var & onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## 添加一帧的高度数据到字典
func add_frame_data(anim_name: String, frame_idx: int, data: Dictionary) -> void:
	if not frame_heights.has(anim_name):
		frame_heights[anim_name] = {}
	frame_heights[anim_name][frame_idx] = data


## 获取某一帧的高度数据，找不到则返回空字典
func get_frame_data(anim_name: String, frame_idx: int) -> Dictionary:
	if not frame_heights.has(anim_name):
		return {}
	if not frame_heights[anim_name].has(frame_idx):
		return {}
	return frame_heights[anim_name][frame_idx]


## 获取某个动画的所有帧数据：{ frame_idx: parsed_data, ... }
## 找不到或无数据返回空字典
func get_animation_data(anim_name: String) -> Dictionary:
	if not frame_heights.has(anim_name):
		return {}
	return frame_heights[anim_name]


## 判断指定动画是否有数据
func has_animation(anim_name: String) -> bool:
	return frame_heights.has(anim_name)


## 清空所有数据（用于重新扫描前重置）
func clear() -> void:
	frame_heights.clear()
	parse_errors.clear()


## 从文件名解析出高度标注数据
##
## 设计要点：
## 1. 用 rfind 找最后一个 marker，避免"air_attack" 等 action 名的干扰
## 2. 从 marker 起始位置截取到下一个 marker 起始位置，作为该 marker 的 value 部分
## 3. 按顺序约束（speed < physical < attack）确定 value 的结束位置
##
## 示例：
##   idle_00_physical_180.png                       → { physical=180, attack_heights=[], speed=null }
##   attack1_02_physical_180_attack_30.png          → { physical=180, attack_heights=[30], speed=null }
##   jump_00_speed_-1200_physical_180.png           → { physical=180, attack_heights=[], speed=-1200 }
##   air_attack_01_physical_170_attack_80_120.png   → { physical=170, attack_heights=[80, 120], speed=null }
static func parse_height_from_filename(filename: String) -> Dictionary:
	# 去掉路径前缀和 .png 扩展名，只保留文件名主体
	var name_only := filename.get_file()
	if name_only.ends_with(".png"):
		name_only = name_only.substr(0, name_only.length() - 4)
	
	var result := {
		"physical": -1.0,
		"attack_heights": [],  # 用 untyped Array，避免 Dictionary 中类型推断问题
		"speed": null,
	}
	
	# 用 rfind 找每个 marker 的最后一次出现（rfind 避免 action 名含有的干扰）
	# rfind 返回 -1 表示未找到
	var idx_phys := name_only.rfind("_physical_")
	var idx_attack := name_only.rfind("_attack_")
	var idx_speed := name_only.rfind("_speed_")
	
	# 提取 physical_<P>
	if idx_phys != -1:
		var value_start := idx_phys + LEN_PHYSICAL
		# 结束位置：下一个按顺序的 marker 位置（attack 在 physical 之后）
		var value_end := name_only.length()
		if idx_attack > idx_phys:
			value_end = idx_attack
		var value_str := name_only.substr(value_start, value_end - value_start)
		if value_str.is_valid_float():
			result["physical"] = float(value_str)
	
	# 提取 speed_<S>（允许负数）
	if idx_speed != -1:
		var value_start := idx_speed + LEN_SPEED
		var value_end := name_only.length()
		# speed 在 physical 之前，physical 在 attack 之前
		# 结束位置：下一个按顺序的 marker 位置
		if idx_phys > idx_speed:
			value_end = idx_phys
		elif idx_attack > idx_speed:
			value_end = idx_attack
		var value_str := name_only.substr(value_start, value_end - value_start)
		if value_str.is_valid_float():
			result["speed"] = float(value_str)
	
	# 提取 attack_<Z1>_<Z2>... （攻击高度列表，以 "_" 分隔多个数字）
	if idx_attack != -1:
		var value_start := idx_attack + LEN_ATTACK
		var value_str := name_only.substr(value_start)
		if not value_str.is_empty():
			var attack_arr: Array = result["attack_heights"]  # 用 untyped Array，引用 dict 内同一个数组
			for part in value_str.split("_"):
				if part.is_valid_float():
					attack_arr.append(float(part))
			# 不需重新赋值：attack_arr 与 result["attack_heights"] 是同一引用
	
	return result


## 验证数据完整性
## 返回是否完整（每个动画每帧都有 physical 标注）
func validate(required_physical_per_frame := true) -> bool:
	if required_physical_per_frame:
		for anim_name in frame_heights:
			for frame_idx in frame_heights[anim_name]:
				var data: Dictionary = frame_heights[anim_name][frame_idx]
				if data.get("physical", -1.0) < 0.0:
					var msg := "[Validation] %s frame %d: missing physical_height" % [
						anim_name, frame_idx
					]
					parse_errors.append(msg)
	
	return parse_errors.is_empty()

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
