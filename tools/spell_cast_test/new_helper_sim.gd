extends Node
## 复刻"新助手模板"的行为形态：只把法术教给被测角色（host.learn_spell），
## 不建管理器、不轮询按键。子节点 _ready 早于父节点 → call_deferred 一帧，
## 等角色壳的法术管理器就绪。施法由角色壳自身的键轮询统一触发（单消费者）。

var taught := false

const DEF_PATH := "res://spells/fire_ball/resources/fire_ball_definition.tres"
const SCENE_PATH := "res://spells/fire_ball/fire_ball.tscn"


func _ready() -> void:
	call_deferred("_teach")


func _teach() -> void:
	var host = get_parent()
	if not host.has_method("learn_spell"):
		push_error("宿主不支持 learn_spell")
		return
	var spell_def: SpellDefinition = load(DEF_PATH)
	spell_def.spell_scene = load(SCENE_PATH)
	taught = host.learn_spell(spell_def)
