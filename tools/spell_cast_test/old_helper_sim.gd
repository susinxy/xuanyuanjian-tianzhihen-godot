extends Node
## 复刻"旧助手模板"的行为形态（自建管理器+自建轮询），用于在引擎里
## 永久锁定"双消费者抢通道边沿"的现场：父（角色壳）先轮询先吃键，
## 本节点永远看不到按键。这是 2026-09 法术键回归事故的机制证据。

var seen := false
var _spell_manager: SpellManager


func _ready() -> void:
	_spell_manager = SpellManager.new(get_parent())


func _physics_process(_delta: float) -> void:
	var host = get_parent()
	if host.channel != null and host.channel.just_pressed("spell_1"):
		seen = true
