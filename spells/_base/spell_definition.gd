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
## 引导时长（秒）：起手动画（槽 spell_start，角色资产、自然时长、必完整播放）结束后，
## 保持姿势循环（槽 spelling）倒数满本字段才释放法术体；实际总硬直=起手动画长+本值。
## 0 = 无施法动作瞬发（旧行为，向后兼容）。
@export var caster_cast_time: float = 0.0
