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

## 按组集合找最近角色本体：并集去重 + is QuiverCharacter 过滤混入的战斗盒 +
## 排除自己。索敌的唯一实现入口（2026-10 索敌配置批：旧 find_closest_player_to
## 写死 area2d:player 的形态随考古件清剿删除，杜绝第二真相）。
static func find_closest_in_groups(
		node_2d: Node2D, groups: Array[StringName]
) -> QuiverCharacter:
	var candidates: Array[QuiverCharacter] = []
	for g in groups:
		for n in node_2d.get_tree().get_nodes_in_group(g):
			if n is QuiverCharacter and n != node_2d and not candidates.has(n):
				candidates.append(n)
	var best: QuiverCharacter = null
	var min_d := INF
	for c in candidates:
		var d := node_2d.global_position.distance_squared_to(c.global_position)
		if d < min_d:
			min_d = d
			best = c
	return best
### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

