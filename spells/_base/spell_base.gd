class_name SpellBase
extends Area2D

enum SpellState { INACTIVE, ACTIVE, ENDING, DEAD }

var definition: SpellDefinition = null
var caster: Node = null
var caster_attributes: QuiverAttributes = null
var direction: Vector2 = Vector2.RIGHT
var state: SpellState = SpellState.INACTIVE
var _elapsed_time: float = 0.0
var _cached_hitbox_height_bits: int = -1

@export_node_path("SpellSkin") var _path_skin := ^"Skin"

@onready var _skin: SpellSkin = get_node_or_null(_path_skin)

signal spell_cast
signal spell_hit(target: Area2D)
signal spell_activated
signal spell_ending
signal spell_destroyed
signal spell_timeout

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	if _skin:
		_skin.spell_animation_finished.connect(_on_skin_animation_finished)
		_skin.spell_hitbox_activated.connect(_on_skin_hitbox_activated)
		_skin.spell_hitbox_deactivated.connect(_on_skin_hitbox_deactivated)
		_skin.spell_effect_triggered.connect(_on_skin_effect_triggered)
		_skin.spell_spawn_requested.connect(_on_skin_spawn_requested)
		_skin.spell_ended.connect(_on_skin_spell_ended)
	
	set_physics_process(false)
	_on_ready()

func cast(p_caster: Node, p_definition: SpellDefinition, p_direction: Vector2) -> void:
	if not is_inside_tree():
		await ready
	
	caster = p_caster
	definition = p_definition
	direction = p_direction.normalized()
	
	if caster.get("attributes") != null:
		caster_attributes = caster.attributes
	
	# 阵营身份必须完整跟随施法者：法术体的 hitbox 若无施法者的 area2d: 阵营组，
	# 施法者自己的 HurtBox 会把贴身生成的法术当敌人打（实测 2026-09-15 契约测试）。
	# 注意阵营组挂在角色各战斗 Area2D（皮肤内）上，CharacterBody2D 根节点未必有，
	# 须扫描后代 Area2D 收集 area2d: 前缀组。
	# 修订（2026-09-15 复现定罪）：**只复制阵营组，不复制施法者根节点上的
	# 阵营包组（players/enemies 等）**——法术体混进 players 组会污染
	# 一切按组查询角色的逻辑（调试面板把火球当角色赋值直接崩、
	# 未来 AI 索敌同理）。阵营过滤只比对 area2d: 前缀，语义完备。
	var faction_groups := _collect_caster_faction_groups(caster)
	
	for group in faction_groups:
		add_to_group(group)
	
	if _skin:
		for hitbox in _skin.hitboxes:
			for group in faction_groups:
				# 必须走显式刷新入口：typed 调用绕过 add_to_group 的脚本 override
				hitbox.add_faction_group(group)
			hitbox.character_attributes = caster_attributes
			# 命中回执注入（Callable 一等公民，绑定点类型可查；契约见
			# QuiverHitBox.on_target_hit 注释——同步调用，严禁延迟化）
			hitbox.on_target_hit = Callable(self, "on_hit")
	
	if _skin:
		_skin.skin_direction = SpellManager.snap_to_four_direction(direction)
	
	_on_cast()
	
	state = SpellState.ACTIVE
	set_physics_process(true)
	spell_cast.emit()
	spell_activated.emit()
	
	if _skin and _skin.has_anim_state(&"active"):
		_skin.transition_to(&"active")

## 扫描施法者后代中的 Area2D，收集其 area2d: 前缀阵营组（去重）。
## 注意：Node.get_children(true) 的参数是"含内部节点"而非递归（Godot 4 陷阱），
## 递归遍历一律用 find_children("*", "", true)。
## 排除 area2d:wall（2026-09-16 法术打不中敌人定罪）：wall 是受击盒的弹墙行为
## 旗标，不是阵营身份——抄进法术攻击盒后，所有带 wall 受击盒的目标（即一切角色）
## 都与法术"同阵营"而被免伤；近战 hitbox 从不带 wall 所以互殴无恙。
## 施法者自保不依赖 wall：双方共享 area2d:<角色名> 即已放行拦截。
static func _collect_caster_faction_groups(caster: Node) -> Array[String]:
	var seen: Array[String] = []
	for node in caster.find_children("*", "", true):
		var area := node as Area2D
		if area == null:
			continue
		for g in area.get_groups():
			var gs := String(g)
			if gs.begins_with("area2d:") and gs != "area2d:wall" and not seen.has(gs):
				seen.append(gs)
	return seen


func _physics_process(delta: float) -> void:
	if state != SpellState.ACTIVE:
		return
	
	_elapsed_time += delta
	
	if definition and definition.max_lifetime > 0.0 and _elapsed_time >= definition.max_lifetime:
		spell_timeout.emit()
		end()
		return
	
	_update_hitbox_layers()
	_on_active(delta)

func _update_hitbox_layers() -> void:
	if _skin == null or caster == null:
		return
	
	var ah: Array = _skin.attack_heights
	var all_mask := QuiverCharacter.get_all_height_layers_mask()
	
	var target_bits := 0
	if not ah.is_empty():
		var base_h: float = _skin.base_height
		var height_defs := QuiverCharacter.get_height_definitions()
		for h in ah:
			var absolute_h: float = base_h + h
			var layer := QuiverCharacter.height_to_layer(absolute_h, height_defs)
			target_bits |= (1 << (layer - 1))
	
	if target_bits != _cached_hitbox_height_bits:
		_cached_hitbox_height_bits = target_bits
		for hitbox in _skin.hitboxes:
			hitbox.collision_layer = (hitbox.collision_layer & ~all_mask) | target_bits
			hitbox.collision_mask = (hitbox.collision_mask & ~all_mask) | all_mask

func end() -> void:
	if state == SpellState.DEAD or state == SpellState.ENDING:
		return
	
	state = SpellState.ENDING
	spell_ending.emit()
	_on_ending()
	
	if _skin and _skin.has_anim_state(&"ending"):
		_skin.transition_to(&"ending")
	else:
		destroy()

func destroy() -> void:
	if state == SpellState.DEAD:
		return
	
	state = SpellState.DEAD
	set_physics_process(false)
	spell_destroyed.emit()
	queue_free()

func on_hit(hurtbox: QuiverHurtBox) -> void:
	# 状态守卫（2026-09-16 僵尸回执定罪）：多敌同帧重叠时，后续回执在首击
	# destroy() 之后到达；非 ACTIVE 弹体不得再对外宣告"我被命中"。
	if state != SpellState.ACTIVE:
		return
	spell_hit.emit(hurtbox)
	_on_hit(hurtbox)

func _on_hit(hurtbox: QuiverHurtBox) -> void:
	end()

## 出手点=法术自身数据（definition.release_ratio，身体比例）× 施法者实际尺寸。
## p_caster / p_definition 允许在 cast() 之前由 SpellManager 放体时直接传入（站位先于
## 身份）——2026-09-16 底账测试抓获：漏传 caster 时读成员恒 null，静默落回 40×160
## 兜底尺寸，正确体型换算从未生效（"出手偏高"的另一半真凶）。
## 纵向朝上再抬 0.4H / 朝下再压 0.2H 为基类惯例（与出手高度数据无关）。
func get_spawn_offset(direction: Vector2, p_caster: Node = null,
		p_definition: SpellDefinition = null) -> Vector2:
	var char_height: float = 160.0
	var char_width: float = 40.0
	# 修复：旧实现硬走 get_node("Skin") 路径，角色皮肤实名各异（如 ChenSkin），
	# 取不到时静默用兜底尺寸（2026-09-15 契约测试牵出）。改读 QuiverCharacter._skin。
	var who: Node = p_caster if p_caster != null else caster
	var skin = who.get("_skin") if who != null else null
	if skin != null:
		if skin.get("physical_height") != null:
			char_height = skin.physical_height
		if skin.get("physical_width") != null:
			char_width = skin.physical_width
	
	var def: SpellDefinition = p_definition if p_definition != null else definition
	var ratio := def.release_ratio if def != null else Vector2(1.0, 0.6)
	var x_offset := char_width * ratio.x * direction.x
	var y_offset := -char_height * ratio.y
	# 四向出手：纵向再按方向抬升/压低出手点
	if direction.y < 0.0:
		y_offset -= char_height * 0.4
	elif direction.y > 0.0:
		y_offset += char_height * 0.2
	return Vector2(x_offset, y_offset)

func _on_ready() -> void:
	pass

func _on_cast() -> void:
	pass

func _on_active(delta: float) -> void:
	position += direction * 400.0 * delta

func _on_ending() -> void:
	pass

func _on_skin_animation_finished() -> void:
	pass

func _on_skin_hitbox_activated() -> void:
	if _skin:
		for hitbox in _skin.hitboxes:
			for child in hitbox.get_children():
				if child is CollisionShape2D or child is CollisionPolygon2D:
					child.disabled = false

func _on_skin_hitbox_deactivated() -> void:
	if _skin:
		for hitbox in _skin.hitboxes:
			for child in hitbox.get_children():
				if child is CollisionShape2D or child is CollisionPolygon2D:
					child.disabled = true

func _on_skin_effect_triggered() -> void:
	pass

func _on_skin_spawn_requested(marker_name: String) -> void:
	pass

func _on_skin_spell_ended() -> void:
	end()

