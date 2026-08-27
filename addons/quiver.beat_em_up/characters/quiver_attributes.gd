class_name QuiverAttributes
extends Resource

## Resource to store characters or other objects attributes.
##
## The purpose of this is to separate Data from Animations/Behavior/Feedback as much as possible.
## When two characters are fighting we want the Character Scenes worry about the "how" while
## the data resources will take of the "what", and will be able to guide the scenes. 
## [br][br]
## It is also easier to pass resources around than nodes, or node references. So for example,
## with resources a HitBox that is nested deeply on character skin to follow it's animation can
## collide with a deeply nested HurtBox of another charater and they can just trade attribute
## resources to resolve the damage, and the resource will notify the appropriate node.
## [br][br]
## It is a more modular way of architecturing the game, where you can use the best of nodes
## and node hierarchies without worrying about complex structures making your life harder as
## the most important logic can happen between simple resources.

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

signal health_changed
signal health_depleted
signal mana_changed
signal mana_depleted
signal hurt_requested(knockback: QuiverKnockbackData)
signal knockout_requested(knockback: QuiverKnockbackData)
signal wall_bounced
signal grab_requested(grabbed_character: QuiverAttributes)
signal grab_released
signal grabbed(ground_level: float)
signal grab_denied

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const KNOCKBACK_VALUES = {
	CombatSystem.KnockbackStrength.NONE: 0,
	CombatSystem.KnockbackStrength.WEAK: 60, # Doesn't launch the target, but builds up
	CombatSystem.KnockbackStrength.MEDIUM: 600, # Should launch target
	CombatSystem.KnockbackStrength.STRONG: 1200,
	CombatSystem.KnockbackStrength.MASSIVE: 2400,
}

#--- public variables - order: export > normal var > onready --------------------------------------

@export_group("Display")
@export var display_name := ""
@export var profile_texture: Texture2D = null
@export var life_bar_gradient := GradientTexture1D.new()

@export_group("Base Stats")
## Max health for the character, when their life bar is full.
@export_range(0, 1, 1, "or_greater") var health_max := 100

## Max mana for the character (spell casting resource).
@export_range(0, 1, 1, "or_greater") var mana_max := 100

## Max movement speed for the character (also used as Run speed).
@export_range(0, 1000, 1, "or_greater") var move_speed := 600

## Walk speed for the character. When the "walk" input is held, the character
## moves at this speed instead of move_speed. Independent from move_speed, each
## character can configure its own walk/run speeds.
@export_range(0, 1000, 1, "or_greater") var walk_speed := 300

## Max influence for player controlled movement on air.
## If 1.0 player's will be able to freely control character's direction on air, just as on the
## ground, and at 0.0 player input will have no influence on a character's air trajectory.
@export_range(0.0, 1.0, 0.01, "or_greater") var air_control := 0.6

## Character's jump force. The heavier the character more jump force they'll need to reach the
## same jump height as a lighter character.
@export_range(0, 0, 1, "or_less") var jump_force := -1200

## 击飞权重，影响被击飞时的速度
## 默认值 1.0 保持原有行为，大于 1.0 增加击飞距离，小于 1.0 减少击飞距离
## 由 knockout 动画首帧的 speed_X 标注自动设置
@export_range(0.0, 10.0, 0.1, "or_greater") var knockback_weight := 1.0

## If you need to make the hit lanes broader or narrower for a specifi character you can use
## this property. Positive values will add to the default hit lane size defined in the Project
## Setting, while negative values will subtract from it. 
## [br][br]
## Note that the hit lane size is how many pixels the character should still be able to receive
## a hit from, so a value of 60 for example, means that they will be hurt by any attacks 
## from another character whose base is between 60 pixels above or 60 pixels below 
## this character's y position.
@export var hit_lane_offset := 0

@export_group("Modifiers")
## This can be toggled on or off in animations to create invincibility frames.
@export var is_invulnerable := false:
	set(value):
		var has_changed = value != is_invulnerable
		is_invulnerable = value
		if has_changed and is_invulnerable:
			reset_knockback()

## This can be toggled on or off in animations to create animations that can't be interrupted
## but still should allow damage to be received.
@export var has_superarmor := false:
	set(value):
		var has_changed = value != has_superarmor
		has_superarmor = value
		if has_changed and has_superarmor:
			reset_knockback()

@export var can_be_grabbed := true

## Character's current health. What the health bar will be showing.
var health_current := health_max:
	set=_set_health_current

## Character's current mana. Used for spell casting.
var mana_current := mana_max:
	set=_set_mana_current

## Amount of knockback character has received, will be used to calculate bounce the next time
## it hits a wall or the ground.
var knockback_amount := 0:
	set(value):
		knockback_amount = max(0, value)

## This character's current y value that represents their current ground level.
var ground_level := 0.0

var character_node: QuiverCharacter = null
var grabbed_offset: Marker2D = null

# Modifier system for buffs/debuffs
var _modifier_records: Array[Dictionary] = []

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _init() -> void:
	QuiverEditorHelper.connect_between(Events.characters_reseted, reset)


func _to_string() -> String:
	var dict = {
		resource_path = resource_path,
		grabbed_offset = grabbed_offset.get_path() if grabbed_offset != null else "none",
		ground_level = ground_level,
	}
	return "QuiverAttributes: %s"%[JSON.stringify(dict, "\t")]

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func add_death_knockback() -> void:
	if (
			not is_alive()
			and knockback_amount < KNOCKBACK_VALUES[CombatSystem.KnockbackStrength.MEDIUM]
	):
		add_knockback(CombatSystem.KnockbackStrength.MEDIUM)


func add_knockback(strength: CombatSystem.KnockbackStrength) -> void:
	knockback_amount += KNOCKBACK_VALUES[strength]


func reset_knockback() -> void:
	if knockback_amount != 0:
		knockback_amount = 0


func should_knockout() -> bool:
	var has_enough_knockback: bool = \
			knockback_amount >= KNOCKBACK_VALUES[CombatSystem.KnockbackStrength.MEDIUM]
	return not is_alive() or (not has_superarmor and has_enough_knockback)


## Returns the character's current health as percentage.
func get_health_as_percentage() -> float:
	var value := health_current / float(health_max)
	return value


func get_hit_lane_limits() -> HitLaneLimits:
	var limits = HitLaneLimits.new(hit_lane_offset, ground_level)
	return limits


func is_alive() -> bool:
	return get_health_as_percentage() > 0


func reset() -> void:
	health_current = health_max
	is_invulnerable = false
	has_superarmor = false
	can_be_grabbed = true

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _set_health_current(value: int) -> void:
	var has_changed = value != health_current
	health_current = clamp(value, 0, health_max)
	if has_changed:
		if health_current > 0:
			health_changed.emit()
		else:
			health_depleted.emit()

func _set_mana_current(value: float) -> void:
	var has_changed = value != mana_current
	mana_current = clamp(value, 0.0, float(mana_max))
	if has_changed:
		if mana_current > 0:
			mana_changed.emit()
		else:
			mana_depleted.emit()

### Public Methods --------------------------------------------------------------------------------

func add_modifier(mod_id: StringName, attribute: StringName, type: String, value: float, source: Node = null) -> void:
	var base_value: float = get(attribute)
	_modifier_records.append({
		"id": mod_id,
		"attribute": attribute,
		"type": type,
		"value": value,
		"source": source,
		"base_value": base_value,
	})
	if type == "add":
		set(attribute, base_value + value)
	elif type == "multiply":
		set(attribute, base_value * value)

func remove_modifier(mod_id: StringName) -> void:
	for i in range(_modifier_records.size() - 1, -1, -1):
		if _modifier_records[i]["id"] == mod_id:
			var record: Dictionary = _modifier_records[i]
			set(record["attribute"], record["base_value"])
			_modifier_records.remove_at(i)
			break

func remove_modifiers_from_source(source: Node) -> void:
	for i in range(_modifier_records.size() - 1, -1, -1):
		if _modifier_records[i]["source"] == source:
			var record: Dictionary = _modifier_records[i]
			set(record["attribute"], record["base_value"])
			_modifier_records.remove_at(i)

### -----------------------------------------------------------------------------------------------

class HitLaneLimits:
	extends RefCounted
	
	var lane_size: int = ProjectSettings.get_setting(QuiverBeatEmUpPlugin.SETTINGS_DEFAULT_HIT_LANE_SIZE)
	
	var upper_limit := 0
	var lower_limit := 0
	
	func _init(p_increment, p_ground_level):
		upper_limit = p_ground_level - lane_size - p_increment
		lower_limit = p_ground_level + lane_size + p_increment
	
	
	func is_value_inside_lane(y_position: float) -> bool:
		var value := y_position >= upper_limit and y_position <= lower_limit
		return value
