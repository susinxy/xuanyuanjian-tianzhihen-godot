class_name QuiverCharacterHelper
extends RefCounted

## Static Helper for situations involving QuiverCharacters

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

static func find_closest_player_to(node_2d: Node2D) -> QuiverCharacter:
	var value: QuiverCharacter = null
	var raw: Array = node_2d.get_tree().get_nodes_in_group("area2d:player")
	var players: Array = []
	for n in raw:
		# 单一存放点体系下 area2d:player 组同时含角色本体与其战斗盒
		# （运行时下发）——索敌只认活的角色本体
		if n is QuiverCharacter and n != node_2d:
			players.append(n)
	
	if players.size() == 1:
		value = players.front()
	elif players.size() > 1:
		var min_distance := INF
		for player in players:
			if player == node_2d:
				continue  # 同标签同伴（如切磋对象）也持 area2d:player——排除自己
			var distance = node_2d.global_position.distance_squared_to(player.global_position)
			if distance < min_distance:
				min_distance = distance
				value = player
	
	return value

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

