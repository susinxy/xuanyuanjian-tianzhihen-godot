class_name SpellDefinition
extends Resource

@export var spell_id: StringName
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var spell_scene: PackedScene
@export var mana_cost: float = 0.0
@export var max_lifetime: float = 5.0
@export var cooldown: float = 0.0
@export var allowed_states: Array[StringName] = []
@export var disallowed_states: Array[StringName] = [&"Die", &"Knockout"]
