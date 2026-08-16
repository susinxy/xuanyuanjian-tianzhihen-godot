# Character Variants Design Schemes

This document records 5 different approaches for implementing character variants (different appearances/abilities of the same character across game stages). These schemes are documented for future reference when specific character variant needs arise.

---

## Context

During the Chen Jingchou character implementation, we identified the need for the same character to have different:
- **Appearance**: Body type, skin, animations (e.g., youth vs adult)
- **Attributes**: HP, speed, jump force (growth over time)
- **Abilities**: Skill set, spells (unlocking new abilities)
- **Physics**: Collision shapes, hitboxes (body size changes)

Example timeline for Chen Jingchou:
- **Dayanling (youth)**: Basic swordplay, 100 HP, smaller hitbox
- **Jiangnan (young adult)**: Advanced swordplay + 2 spells, 120 HP
- **Capital (adult)**: Full spell book, 150 HP, larger hitbox

---

## Scheme A: Resource File Override

**Concept**: Create different `.tres` resource files (QuiverAttributes, SpriteFrames, AttackData) for each variant. Override them in stage scripts at runtime.

**Implementation**:
```gdscript
# dayan_ling.gd
@onready var _chen = $Level/Characters/ChenJingchou

func _ready():
    var variant_attrs = preload("res://stages/dayan_ling/chen_jingchou_youth_attributes.tres")
    _chen.attributes = variant_attrs.duplicate()
    
    var variant_sprites = preload("res://stages/dayan_ling/chen_jingchou_youth_spriteframes.tres")
    _chen._skin.sprite_frames = variant_sprites
```

**Pros**:
- ✅ Simplest to implement
- ✅ Leverages existing Quiver Resource architecture
- ✅ Data-driven, easy to adjust in editor

**Cons**:
- ❌ Cannot change script logic per variant
- ❌ Cannot change scene structure per variant

**Applicable when**: Only attributes and visual appearance differ between variants.

---

## Scheme B: Scene Inheritance

**Concept**: Create a base character scene, then inherit to create stage-specific variants.

**Structure**:
```
characters/playable/chen_jingchou/
├── chen_jingchou_base.tscn
└── variants/
    ├── chen_jingchou_youth.tscn  # inherits from base
    └── chen_jingchou_adult.tscn  # inherits from base
```

In Godot editor: Right-click base .tscn → "New Inherited Scene" → modify inherited properties.

**Implementation** (stage script):
```gdscript
# dayan_ling.gd
func _ready():
    var chen = preload("res://characters/playable/chen_jingchou/variants/chen_jingchou_youth.tscn").instantiate()
    $Level/Characters.add_child(chen)
```

**Pros**:
- ✅ Can override everything (script, structure, properties, collision)
- ✅ Native Godot support with mature editor UI

**Cons**:
- ❌ File count explosion (one variant per stage)
- ❌ Maintenance burden (editing base affects all variants)

**Applicable when**: Variants need fundamentally different structures (e.g., adult form has completely different state machine tree than youth).

---

## Scheme C: GDScript Dynamic Configuration

**Concept**: Modify character properties directly in stage scripts at runtime.

**Implementation**:
```gdscript
# dayan_ling.gd
@onready var _chen = $Level/Characters/ChenJingchou

func _ready():
    # Direct property modifications
    _chen.attributes.health_max = 80
    _chen.attributes.move_speed = 400
    _chen._skin.modulate = Color(0.8, 0.8, 1.0)
    
    # Dynamic ability unlocking
    if GameState.chapter >= 5:
        _chen.state_machine.enable_transition("Combo4", true)
```

**Pros**:
- ✅ Maximum flexibility
- ✅ Can implement complex conditional logic

**Cons**:
- ❌ Data and logic coupling (values scattered across scripts)
- ❌ Hard to track all variants in one place
- ❌ Not editor-friendly

**Applicable when**: Need dynamic runtime changes (progressive ability unlocking, temporary buffs, etc).

---

## Scheme D: Config Data Table (Resource-Based)

**Concept**: Create a `CharacterStageConfig` Resource file describing "all changes to apply to the character in this stage". Use a unified `ConfigApplier` utility to apply the config.

**File Structure**:
```
stages/dayan_ling/
├── dayan_ling.tscn
├── dayan_ling.gd
└── config/
    └── chen_jingchou_config.tres
```

**Config Resource Structure**:
```gdscript
# character_stage_config.gd
extends Resource
class_name CharacterStageConfig

@export var attributes_override: QuiverAttributes  # optional
@export var sprite_frames_override: SpriteFrames   # optional
@export var script_override: Script                # optional
@export var hitbox_shapes: Dictionary              # { "Attack1": Vector2(80,60), ... }
@export var disabled_actions: Array[String]        # states to disable
@export var custom_properties: Dictionary          # extensible key-value
```

**Config Applier Tool**:
```gdscript
# character_config_applier.gd
class_name CharacterConfigApplier

static func apply(character: QuiverCharacter, config: CharacterStageConfig):
    if config.attributes_override:
        character.attributes = config.attributes_override.duplicate()
    if config.sprite_frames_override:
        character._skin.sprite_frames = config.sprite_frames_override
    if config.script_override:
        character.set_script(config.script_override)
    for action_name in config.disabled_actions:
        character.state_machine.get_node(action_name).set_disabled(true)

# dayan_ling.gd
func _ready():
    var config = preload("res://stages/dayan_ling/config/chen_jingchou_config.tres")
    CharacterConfigApplier.apply(_chen, config)
```

**Pros**:
- ✅ Centralized data management
- ✅ Editor-friendly (Resource has Inspector)
- ✅ Unified apply mechanism
- ✅ Extensible (custom_properties Dictionary)

**Cons**:
- ❌ Requires additional tool development
- ❌ More complex than direct GDScript

**Applicable when**: Large project with multiple character variants across stages.

---

## Scheme E: Variant Scene + Script Wrapper

**Concept**: Keep one base character scene unchanged. For each stage, create a thin wrapper scene that contains the base character + a variant manager script.

**Structure**:
```
characters/playable/chen_jingchou/
└── chen_jingchou.tscn  # only one, kept pristine

stages/dayan_ling/
└── ChenJingchouVariant.tscn
    ├── ChenJingchou (instance of base)
    └── DayanlingVariant (Node, script: dayanling_variant.gd)
```

**Variant Manager Script**:
```gdscript
# dayanling_variant.gd
extends Node

@export var variant_config: Resource
@onready var character = $"../ChenJingchou"

func _ready():
    if variant_config:
        CharacterConfigApplier.apply(character, variant_config)
```

**Pros**:
- ✅ Can see variant structure in scene tree
- ✅ Can preserve stage-specific state (not just data)
- ✅ Editor-friendly

**Cons**:
- ❌ Deep nesting complexity
- ❌ Maintenance of multiple wrapper scenes

**Applicable when**: Variants have distinct scene-level behaviors or state that need preserving beyond Resource data.

---

## Decision Guide

| Scenario | Recommended Scheme | Rationale |
|---|---|---|
| Only HP/speed values differ | **A** (Resource) | Simplest, Quiver supports it natively |
| Appearance completely changes (youth vs adult) | **B** (Inherit) or **D** (Config) | Different visual structures |
| Dynamic runtime changes (ability unlocking) | **C** (GDScript) | Needs complex conditional logic |
| Multiple variant types in one place | **D** (Config) | Centralized management |
| Variant-level behaviors/state | **E** (Wrapper) | Scene-level preservation |

For the Xuanyuan Sword project (with youth→adult evolution):
- **Primary**: Scheme D (Config-based) for 90% of changes
- **Secondary**: Scheme B (Inheritance) for major structural changes
- **Supplementary**: Scheme C (GDScript) for dynamic runtime conditions

---

## Notes

- These schemes are independent design choices, recorded for future specific needs
- When implementing a specific character variant, refer to this document and choose based on actual requirements
- Schemes can be combined (e.g., A + C = Resource override + dynamic GDScript tweaking)

---

**Document created**: 2026-08-11  
**Last updated**: 2026-08-11
