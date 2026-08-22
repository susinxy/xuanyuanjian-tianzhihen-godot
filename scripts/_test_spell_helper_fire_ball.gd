extends Node

var _spell_manager: SpellManager
var _spell_def: SpellDefinition

func _ready():
	var char_node = get_parent()
	_spell_manager = SpellManager.new(char_node)
	_spell_def = load("res://spells/fire_ball/resources/fire_ball_definition.tres")
	_spell_def.spell_scene = load("res://spells/fire_ball/fire_ball.tscn")
	_spell_manager.learn_spell(_spell_def)

func _physics_process(delta):
	_spell_manager.tick(delta)

func _unhandled_input(event):
	if event.is_action_pressed("spell_1"):
		_spell_manager.cast_spell_by_index(0)
