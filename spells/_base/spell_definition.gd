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
## 施法时长（秒）：施法者以循环动画施法，锁满此时长后才释放法术体；
## 0.0 = 无施法动作瞬发（旧行为，向后兼容）。
## 施法动作本身在角色皮肤动画树里固定槽名 "spell"（与 attack1 同风格约定）。
@export var caster_cast_time: float = 0.0
