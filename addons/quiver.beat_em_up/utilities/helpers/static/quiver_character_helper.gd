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
			# 将死者不入靶（2026-10 G4）：hp≤0 已在死亡链上的角色不再被索敌
			# 选中，杜绝"补刀打断死亡演出"的观感与凭据竞态。
			if n is QuiverCharacter and n != node_2d and not candidates.has(n):
				var cand := n as QuiverCharacter
				if cand.attributes != null and cand.attributes.health_current > 0.0:
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


## ── 被控角色身份判据（2026-10 接管批，用户裁决三章）──────────────────────
## 控制权=行为维度（谁挂 PLAYER_INPUT），阵营标签=出身维度，两者解耦——
## "玩家身份"的唯一权威从写死的 area2d:player 标签迁移为：
## 树内存在 controlled 组成员（有壳接管体系在管理）→ 该组说了算；
## 不存在（单跑/Run-Test/无壳场景）→ 回落 area2d:player 现状兼容形
## （既有场景语义零漂移）。controlled 组只挂角色根本体（不经
## add_faction_group 下发战斗盒），零阵营免疫副作用。
const CONTROLLED_GROUP := &"controlled"
const PLAYER_FACTION_GROUP := &"area2d:player"


## 节点是否为"当前玩家身份"（判据见上）。
static func is_player_identity(node: Node) -> bool:
	if node == null:
		return false
	var tree := node.get_tree()
	if tree != null and not tree.get_nodes_in_group(CONTROLLED_GROUP).is_empty():
		return node.is_in_group(CONTROLLED_GROUP)
	return node.is_in_group(PLAYER_FACTION_GROUP)


## 败北演出判据（锚点批，用户裁决：死亡演出与终局的触发者约束到一个可
## 设置维度上）：败北集合 = {终局锚点} ∪ {被控者}——树内两者任一存在即
## 走集合制；皆无（单跑/Run-Test 无壳）回落 area2d:player 现状兼容形。
## 消费点唯一：die 终局分支 + launch 慢放门（演出与终局单门同闸）。
## 与 is_player_identity 分工：identity=互动身份（触发带/HUD 认被控者），
## defeat_bound=败北演出集合（锚是"剧情不能死的人"，与操作无关）。
const DEFEAT_ANCHOR_GROUP := &"defeat_anchor"
## 慢放集（2026-10 死亡演出批）：独立于结算集的演出挂载——"死了值得给一段
## 慢镜头的人"。树内无人显式挂本组时**默认跟随结算集**（=现状两事件同角色，
## 零漂移）；一旦有任何申报则只认申报成员（两功能正交：可只慢不结算、
## 可只结算不慢）。
const DEATH_SLOWMO_GROUP := &"death_slowmo"


## 慢放判据（申报式）：无申报=跟随 defeat_bound。
static func is_death_slowmo_bound(node: Node) -> bool:
	if node == null:
		return false
	var tree := node.get_tree()
	if tree == null:
		return false
	if tree.get_nodes_in_group(DEATH_SLOWMO_GROUP).is_empty():
		return is_defeat_bound(node)
	return node.is_in_group(DEATH_SLOWMO_GROUP)


static func is_defeat_bound(node: Node) -> bool:
	if node == null:
		return false
	var tree := node.get_tree()
	if tree == null:
		return false
	var has_anchor := not tree.get_nodes_in_group(DEFEAT_ANCHOR_GROUP).is_empty()
	var has_controlled := not tree.get_nodes_in_group(CONTROLLED_GROUP).is_empty()
	if has_anchor or has_controlled:
		return node.is_in_group(DEFEAT_ANCHOR_GROUP) or node.is_in_group(CONTROLLED_GROUP)
	return node.is_in_group(PLAYER_FACTION_GROUP)


## 找当前玩家身份的角色本体；歧义（多枚）返回 null，由调用方处置。
static func find_player_identity(from: Node) -> QuiverCharacter:
	var tree := from.get_tree()
	if tree == null:
		return null
	var group := CONTROLLED_GROUP
	if tree.get_nodes_in_group(CONTROLLED_GROUP).is_empty():
		group = PLAYER_FACTION_GROUP
	var hits: Array = []
	for n in tree.get_nodes_in_group(group):
		if n is QuiverCharacter:
			hits.append(n)
	return hits[0] if hits.size() == 1 else null
