@tool
class_name DebugSpellTestOverlay
extends CanvasLayer

## 法术测试调试面板
## 显示 player、enemy、fireball 的关键信息用于诊断碰撞问题

@export var player_path: NodePath
@export var enemy_path: NodePath

var _player: QuiverCharacter
var _enemy: QuiverCharacter
var _player_skin: QuiverCharacterSkin
var _enemy_skin: QuiverCharacterSkin
var _player_hurtbox: QuiverHurtBox
var _enemy_hurtbox: QuiverHurtBox

var _label: Label
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.1  # 每 100ms 更新一次


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_setup_label()
	_find_nodes()


func _setup_label() -> void:
	_label = Label.new()
	_label.position = Vector2(20, 20)
	_label.size = Vector2(800, 600)
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color.YELLOW)
	
	var panel = Panel.new()
	panel.position = Vector2(10, 10)
	panel.size = Vector2(820, 620)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.border_color = Color(1, 1, 0, 0.5)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	
	add_child(panel)
	add_child(_label)


func _find_nodes() -> void:
	# 查找 Player
	if not player_path.is_empty():
		_player = get_node_or_null(player_path)
	else:
		_player = get_tree().get_first_node_in_group("players")
	
	if _player:
		_player_skin = _player.get_node_or_null("Skin")
		_player_hurtbox = _player.get_node_or_null("Skin/AnimatedSprite2D/HurtBox")
		print("[Debug] Player found: ", _player.name)
	else:
		print("[Debug] Player NOT found")
	
	# 查找 Enemy
	if not enemy_path.is_empty():
		_enemy = get_node_or_null(enemy_path)
	else:
		_enemy = get_tree().get_first_node_in_group("enemies")
	
	if _enemy:
		_enemy_skin = _enemy.get_node_or_null("EnemySkin")
		if not _enemy_skin:
			_enemy_skin = _enemy.get_node_or_null("Skin")
		_enemy_hurtbox = _enemy.get_node_or_null("EnemySkin/AnimatedSprite2D/HurtBox")
		if not _enemy_hurtbox:
			_enemy_hurtbox = _enemy.get_node_or_null("Skin/AnimatedSprite2D/HurtBox")
		print("[Debug] Enemy found: ", _enemy.name)
	else:
		print("[Debug] Enemy NOT found")


func _find_all_spells() -> Array:
	var spells = []
	if get_tree().current_scene:
		_search_tree_recursive(get_tree().current_scene, spells)
	return spells


func _search_tree_recursive(node: Node, result: Array):
	if node is SpellBase:
		result.append(node)
	for child in node.get_children():
		_search_tree_recursive(child, result)


func _find_hitboxes_recursive(node: Node) -> Array:
	var result = []
	if node is QuiverHitBox:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_hitboxes_recursive(child))
	return result


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	_update_timer += delta
	if _update_timer < UPDATE_INTERVAL:
		return
	_update_timer = 0.0
	
	_update_display()


func _update_display() -> void:
	if not _label:
		return
	
	var text = "=== 法术测试调试面板 ===\n\n"
	
	# Player 信息
	text += "【PLAYER】\n"
	if _player and _player_skin:
		text += "position: %s\n" % str(_player.global_position)
		text += "skin.position.y: %.1f\n" % _player_skin.position.y
		text += "base_height: %.1f\n" % _player_skin.base_height
		text += "physical_height: %.1f\n" % _player_skin.physical_height
		text += "collision_layer: 0x%X (二进制: %s)\n" % [_player.collision_layer, _format_binary(_player.collision_layer)]
		text += "collision_mask: 0x%X (二进制: %s)\n" % [_player.collision_mask, _format_binary(_player.collision_mask)]
		text += "高度层: %s\n" % _format_height_layers(_player.collision_layer)
		
		if _player_hurtbox:
			text += "HurtBox layer: 0x%X\n" % _player_hurtbox.collision_layer
			text += "HurtBox mask: 0x%X\n" % _player_hurtbox.collision_mask
		else:
			text += "HurtBox: NOT FOUND\n"
	else:
		text += "NOT FOUND\n"
	
	text += "\n"
	
	# Enemy 信息
	text += "【ENEMY】\n"
	if _enemy and _enemy_skin:
		text += "position: %s\n" % str(_enemy.global_position)
		text += "skin.position.y: %.1f\n" % _enemy_skin.position.y
		text += "base_height: %.1f\n" % _enemy_skin.base_height
		text += "physical_height: %.1f\n" % _enemy_skin.physical_height
		text += "collision_layer: 0x%X (二进制: %s)\n" % [_enemy.collision_layer, _format_binary(_enemy.collision_layer)]
		text += "collision_mask: 0x%X (二进制: %s)\n" % [_enemy.collision_mask, _format_binary(_enemy.collision_mask)]
		text += "高度层: %s\n" % _format_height_layers(_enemy.collision_layer)
		
		if _enemy_hurtbox:
			text += "HurtBox layer: 0x%X\n" % _enemy_hurtbox.collision_layer
			text += "HurtBox mask: 0x%X\n" % _enemy_hurtbox.collision_mask
			text += "HurtBox monitoring: %s\n" % str(_enemy_hurtbox.monitoring)
		else:
			text += "HurtBox: NOT FOUND\n"
	else:
		text += "NOT FOUND\n"
	
	text += "\n"
	
	# Fireball 信息
	var fireballs = _find_all_spells()
	text += "【FIREBALLS】 (数量: %d)\n" % fireballs.size()
	for i in range(min(3, fireballs.size())):  # 最多显示 3 个
		var fb = fireballs[i]
		text += "  [%d] position: %s\n" % [i, str(fb.global_position)]
		text += "      collision_layer: 0x%X\n" % fb.collision_layer
		text += "      collision_mask: 0x%X\n" % fb.collision_mask
		text += "      高度层: %s\n" % _format_height_layers(fb.collision_layer)
		
		# 显示 skin 信息
		var skin = fb.get("_skin")
		if skin:
			text += "      skin.attack_heights: %s\n" % str(skin.attack_heights)
			text += "      skin.hitboxes 数量: %d\n" % skin.hitboxes.size()
			
			# 显示动画状态信息
			var animation_list = skin.get("_animation_list")
			if animation_list != null:
				text += "      skin._animation_list: %s\n" % str(animation_list)
			else:
				text += "      skin._animation_list: NOT FOUND\n"
			
			var animation_tree = skin.get("_animation_tree")
			if animation_tree:
				text += "      AnimationTree.active: %s\n" % str(animation_tree.active)
				var playback = skin.get("_playback")
				if playback:
					var current_node = playback.get_current_node()
					text += "      当前播放节点: %s\n" % str(current_node)
				else:
					text += "      _playback: NOT FOUND\n"
			else:
				text += "      AnimationTree: NOT FOUND\n"
		
		# 递归查找 hitboxes
		var hitboxes = _find_hitboxes_recursive(fb)
		if hitboxes.size() > 0:
			var hb = hitboxes[0]
			text += "      HitBox layer: 0x%X 高度层:%s\n" % [hb.collision_layer, _format_height_layers(hb.collision_layer)]
			text += "      HitBox mask: 0x%X 高度层:%s\n" % [hb.collision_mask, _format_height_layers(hb.collision_mask)]
			text += "      HitBox monitoring: %s\n" % str(hb.monitoring)
		else:
			text += "      HitBox: NOT FOUND\n"
	
	# 碰撞检测分析
	text += "\n【碰撞分析】\n"
	if _enemy_hurtbox and fireballs.size() > 0:
		var fb = fireballs[0]
		var hitboxes = _find_hitboxes_recursive(fb)
		if hitboxes.size() > 0:
			var hb = hitboxes[0]
			var can_detect = (hb.collision_layer & _enemy_hurtbox.collision_mask) != 0
			text += "Fireball HitBox → Enemy HurtBox: %s\n" % ("✓ 可以检测" if can_detect else "✗ 无法检测")
			text += "  HitBox layer & HurtBox mask = 0x%X\n" % (hb.collision_layer & _enemy_hurtbox.collision_mask)
			
			var can_detect_reverse = (_enemy_hurtbox.collision_layer & hb.collision_mask) != 0
			text += "Enemy HurtBox → Fireball HitBox: %s\n" % ("✓ 可以检测" if can_detect_reverse else "✗ 无法检测")
			text += "  HurtBox layer & HitBox mask = 0x%X\n" % (_enemy_hurtbox.collision_layer & hb.collision_mask)
	
	_label.text = text


func _format_binary(value: int) -> String:
	var result = ""
	for i in range(31, -1, -1):
		if value & (1 << i):
			result += "1"
		else:
			result += "0"
		if i % 4 == 0 and i > 0:
			result += " "
	return result


func _format_height_layers(collision_layer: int) -> String:
	var layers = []
	for i in range(15, 25):  # Layer 15-24
		if collision_layer & (1 << (i - 1)):
			layers.append(str(i))
	return "[" + ", ".join(layers) + "]" if layers.size() > 0 else "无"
