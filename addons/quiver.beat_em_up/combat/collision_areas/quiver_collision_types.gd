class_name QuiverCollisionTypes
extends RefCounted

## Write your doc string for this file here

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const META_KEY = "collision_type"

const PRESETS = { 
	"default": { 
		META_KEY: "default",
		"modulate": Color("0099b3"),
		"monitoring": true,
		"monitorable": true,
		"collision_layer": 1,
		"collision_mask": 1,
	},
	"world_hit_box": { 
		META_KEY: "world_hit_box",
		"modulate": Color("ff1167"),
		"monitoring": false,
		"monitorable": true,
		"collision_layer": 128,
		"collision_mask": 0,
	},
	"player_detector": { 
		META_KEY: "player_detector",
		"modulate": Color("ffff00"),
		"monitoring": true,
		"monitorable": false,
	},
	"custom": {
		META_KEY: "custom",
		"modulate": Color("0099b3"),
	}
}

const COLLISION_LAYER_WORLD_HIT_BOX = 8

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

static func apply_preset_to(dict: Dictionary, node: Node2D) -> void:
	if node is CollisionShape2D:
		node.set_meta(META_KEY, dict[META_KEY])
		node.modulate = dict.modulate
	elif node is Area2D:
		for key in dict:
			if key == META_KEY:
				node.set_meta(META_KEY, dict[META_KEY])
			elif key == "modulate":
				continue
			else:
				node.set(key, dict[key])
		
		for child in node.get_children():
			if child is CollisionShape2D:
				QuiverCollisionTypes.apply_preset_to(dict, child)
	
	node.update_configuration_warnings()

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

