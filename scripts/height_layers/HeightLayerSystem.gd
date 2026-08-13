extends Node
class_name HeightLayerSystem

## 高度层系统 - 管理角色的碰撞层和高度信息
## 
## 功能:
## - 从皮肤节点自动获取碰撞框引用（HurtBox 和 HitBox）
## - 根据当前 base_height 动态调整角色的碰撞层
## - 支持多高度攻击判定
## 
## 使用流程:
## 1. 将此脚本添加到角色的皮肤节点
## 2. 在编辑器中设置基础高度参数
## 3. 动画轨道通过调用 set_attack_heights() 更新攻击高度
## 4. 系统自动根据高度变化调整碰撞层

# 基础高度（从地面算起，0 表示站在地面上）
@export var base_height: float = 0.0

# 物理身高（用于计算 total_height = base_height + physical_height）
@export var physical_height: float = 180.0

# 攻击高度列表（相对于 base_height 的偏移量）
var attack_heights: Array[float] = []

# 内部状态
var previous_base_height: float = 999999.0  # 用于检测变化

# 节点引用
@onready var character: CharacterBody2D = get_parent() as CharacterBody2D

# 碰撞框引用（从皮肤节点获取，在 _ready 中初始化）
var skin: Node2D = null
var hurt_box: Area2D = null
var hit_boxes: Array[Area2D] = []

# 高度层定义（与 project.godot 中的 layer 15-19 对应）
# 每个层定义包含:
#   - bit: 对应的位编号 (15-19)
#   - start: 起始高度（包含）
#   - end: 结束高度（不包含）
const HeightLayers = {
	"ground": { "bit": 15, "start": 0, "end": 100 },
	"low_air": { "bit": 16, "start": 100, "end": 200 },
	"mid_air": { "bit": 17, "start": 200, "end": 300 },
	"high_air": { "bit": 18, "start": 300, "end": 400 },
	"very_high": { "bit": 19, "start": 400, "end": 999999 },
}


func _ready() -> void:
	# 验证父节点是 CharacterBody2D
	if not character:
		push_error("HeightLayerSystem: 父节点必须是 CharacterBody2D")
		return
	
	# 动态查找皮肤节点（以 Skin 结尾的 Node2D）
	for child in character.get_children():
		if child.name.ends_with("Skin") and child is Node2D:
			skin = child
			break
	
	if not skin:
		push_warning("HeightLayerSystem: 未找到皮肤节点")
		return
	
	# 从皮肤节点获取碰撞框引用
	_find_collision_boxes()
	
	# 初始化碰撞层
	_update_collision_layers()
	
	# 打印初始化信息
	print("[HeightLayerSystem] Initialized for ", character.name)
	if hurt_box:
		print("  - HurtBox: ", hurt_box.name)
	else:
		push_warning("  - HurtBox: Not found")
	
	if hit_boxes.size() > 0:
		print("  - HitBoxes: ", hit_boxes.size(), " found")
		for hit_box in hit_boxes:
			print("    - ", hit_box.name)
	else:
		push_warning("  - HitBoxes: Not found")


## 从皮肤节点查找所有碰撞框
func _find_collision_boxes() -> void:
	# 查找 HurtBox（在 AnimatedSprite2D 下）
	var animated_sprite = skin.get_node_or_null("AnimatedSprite2D")
	if animated_sprite:
		hurt_box = animated_sprite.get_node_or_null("HurtBox")
		if not hurt_box:
			push_warning("HeightLayerSystem: HurtBox not found in AnimatedSprite2D")
	
	# 查找所有 HitBox（在 Attacks 节点下）
	var attacks_node = skin.get_node_or_null("Attacks")
	if attacks_node:
		for child in attacks_node.get_children():
			if child is Area2D:
				hit_boxes.append(child)
	else:
		push_warning("HeightLayerSystem: Attacks node not found")


func _physics_process(_delta: float) -> void:
	# 检测 base_height 变化，只在变化时更新碰撞层
	if abs(base_height - previous_base_height) > 0.1:
		_update_collision_layers()
		previous_base_height = base_height


## 设置攻击高度（由动画轨道调用）
## 
## 参数:
##   heights: 攻击高度偏移列表（相对于 base_height）
## 
## 示例:
##   set_attack_heights([80.0])  # 单次攻击，高度为 base_height + 80
##   set_attack_heights([50.0, 150.0])  # 多段攻击，不同高度
func set_attack_heights(heights: Array[float]) -> void:
	attack_heights = heights.duplicate()
	previous_base_height = 999999.0  # 强制更新


## 设置基础高度（由动画轨道调用）
## 
## 参数:
##   height: 新的基础高度
func set_base_height(height: float) -> void:
	base_height = height


## 计算当前高度覆盖的角色碰撞层
## 
## 参数:
##   current_height: 当前基础高度
## 
## 返回: 覆盖的层名称列表
func _get_covered_layers(current_height: float) -> Array[String]:
	var covered: Array[String] = []
	var total_height = current_height + physical_height
	
	for layer_name in HeightLayers.keys():
		var layer_info = HeightLayers[layer_name]
		# [start, end) 左闭右开
		if total_height >= layer_info["start"] and total_height < layer_info["end"]:
			covered.append(layer_name)
	
	return covered


## 计算攻击覆盖的碰撞层
## 
## 参数:
##   current_height: 当前基础高度
## 
## 返回: 攻击覆盖的层名称列表（去重）
func _get_attack_covered_layers(current_height: float) -> Array[String]:
	var covered: Array[String] = []
	
	for attack_offset in attack_heights:
		var attack_height: float = current_height + attack_offset
		for layer_name in HeightLayers.keys():
			var layer_info = HeightLayers[layer_name]
			if attack_height >= layer_info["start"] and attack_height < layer_info["end"]:
				if layer_name not in covered:
					covered.append(layer_name)
	
	return covered


## 更新所有碰撞对象的碰撞层
func _update_collision_layers() -> void:
	var body_layers = _get_covered_layers(base_height)
	var attack_layers = _get_attack_covered_layers(base_height)
	
	# 更新角色碰撞层
	if character:
		for layer_name in HeightLayers.keys():
			var bit = HeightLayers[layer_name]["bit"]
			character.set_collision_layer_value(bit, layer_name in body_layers)
	
	# 更新 HurtBox 碰撞层
	if hurt_box:
		for layer_name in HeightLayers.keys():
			var bit = HeightLayers[layer_name]["bit"]
			hurt_box.set_collision_layer_value(bit, layer_name in body_layers)
	
	# 更新所有 HitBox 碰撞层
	for hit_box in hit_boxes:
		for layer_name in HeightLayers.keys():
			var bit = HeightLayers[layer_name]["bit"]
			hit_box.set_collision_layer_value(bit, layer_name in attack_layers)


## 获取当前覆盖的所有碰撞层位（用于调试）
## 
## 返回: 字典包含基础高度、总高度、角色碰撞层、攻击碰撞层
func get_current_layers() -> Dictionary:
	return {
		"base_height": base_height,
		"total_height": base_height + physical_height,
		"body_layers": _get_covered_layers(base_height),
		"attack_layers": _get_attack_covered_layers(base_height),
	}
