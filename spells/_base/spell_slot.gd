class_name SpellSlot
extends RefCounted

var definition: SpellDefinition = null
var cooldown_remaining: float = 0.0

func is_empty() -> bool:
    return definition == null

func is_ready() -> bool:
    return cooldown_remaining <= 0.0

func start_cooldown() -> void:
    cooldown_remaining = definition.cooldown

func tick(delta: float) -> void:
    cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
