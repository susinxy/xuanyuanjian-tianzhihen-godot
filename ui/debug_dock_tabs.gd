extends Node

## 调试坞内容层（批 2）：向通用 DebugDock 注册四个文字页签。
## Dock 本体保持零领域知识，一切取数集中此处；provider 由 Dock 以
## 0.15s 拉取节奏驱动（物理心跳，headless 可靠）。
## [诊断] 页系旧 scripts/debug_spell_test_overlay 面板移植——该面板原用
## _process 刷新，在 headless 永不派发 idle 帧的环境下从不出活（2026-09-16
## 探针实证），迁入拉取制后测试可达。

const ROSTER_GROUP := "quiver_characters"  # 角色名册组（阵营新体系下按名册枚举）


func _ready() -> void:
	var dock := get_tree().root.get_node_or_null("DebugDock")
	if dock == null:
		push_error("DebugDockTabs: 未找到 DebugDock autoload")
		return
	dock.add_text_tab("角色", _provide_characters)
	dock.add_text_tab("弹体", _provide_spells)
	dock.add_text_tab("诊断", _provide_collision)
	dock.add_text_tab("高度层", _provide_height)
	dock.add_text_tab("击飞", _provide_knockout)
	dock.add_text_tab("帮助", _provide_help)
	dock.add_text_tab("系统", _provide_system)


func _all_chars() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group(ROSTER_GROUP):
		if n is CharacterBody2D:
			out.append(n)
	return out


func _all_spells() -> Array:
	var out: Array = []
	if get_tree().current_scene:
		_walk(get_tree().current_scene, out)
	return out


func _walk(node: Node, out: Array) -> void:
	if node is SpellBase:
		out.append(node)
	for c in node.get_children():
		_walk(c, out)


func _height_layer_names(bits: int) -> String:
	var out := ""
	for i in range(15, 25):
		if bits & (1 << (i - 1)) != 0:
			out += String(ProjectSettings.get_setting(
					"layer_names/2d_physics/layer_%d" % i)) + " "
	return out.strip_edges() if not out.is_empty() else "-"


func _factions_of(node: Node) -> String:
	var parts := PackedStringArray()
	for grp in node.get_groups():
		if String(grp).begins_with("area2d:"):
			parts.append(String(grp).trim_prefix("area2d:"))
	return ", ".join(parts) if not parts.is_empty() else "-"


func _slot_lines(ch: CharacterBody2D) -> Array[String]:
	var out: Array[String] = []
	var sm = ch.get("_spell_manager")
	if sm == null or not ("_slots" in sm):
		return ["    （无施法槽：AI/被动档）"]
	for i in sm._slots.size():
		var slot = sm._slots[i]
		var defn = slot.definition
		if defn == null or slot.is_empty():
			out.append("    槽%d: -" % (i + 1))
			continue
		var cd := "就绪" if slot.cooldown_remaining <= 0.0 \
				else "冷却 %.1fs" % slot.cooldown_remaining
		var mana := "蓝够" if ch.attributes.mana_current >= defn.mana_cost else "缺蓝"
		out.append("    槽%d: %s | %s | %s | 引导%.2fs" % [
				i + 1, String(defn.spell_id), cd, mana, defn.caster_cast_time])
	return out


func _provide_characters() -> Array[String]:
	var out: Array[String] = []
	for ch in _all_chars():
		var a: QuiverAttributes = ch.attributes
		var skin = ch.get("_skin")
		var st := "-"
		if "state_machine" in ch and ch.state_machine != null:
			st = str(ch.state_machine.state_name)
		out.append("【%s】组=%s" % [a.display_name.strip_edges(), _root_groups(ch)])
		out.append("  HP %.0f/%.0f  蓝 %.0f/%.0f  状态=%s" % [
				a.health_current, a.health_max, a.mana_current, a.mana_max, st])
		if skin != null:
			out.append("  位置(%s)  物理高 %.0f  基准 %.0f  高度层[%s]" % [
					str((ch as Node2D).global_position).pad_zeros(1),
					skin.physical_height, skin.base_height,
					_height_layer_names(ch.collision_layer)])
		out.append_array(_slot_lines(ch))
	return out


func _root_groups(ch: Node) -> String:
	var parts := PackedStringArray()
	for grp in ch.get_groups():
		if not String(grp).begins_with("area2d:"):
			parts.append(String(grp))
	return ",".join(parts) if not parts.is_empty() else "-"


func _provide_spells() -> Array[String]:
	var out: Array[String] = []
	var spells := _all_spells()
	out.append("场上弹体: %d" % spells.size())
	for i in spells.size():
		var sp: SpellBase = spells[i]
		var life := "-"
		if sp.definition != null and sp.definition.max_lifetime > 0.0:
			life = "%.1fs" % maxf(0.0, sp.definition.max_lifetime - sp._elapsed_time)
		out.append("【%s】%s 方向=%s 剩余寿命=%s" % [i, sp.name,
				str(sp.direction), life])
		out.append("  state=%s 位置=%s 亮度=%.2f 高度层[%s]" % [
				str(sp.state), str(sp.global_position), sp.modulate.a,
				_height_layer_names(sp.collision_layer)])
		var skin = sp.get("_skin")
		if skin != null:
			out.append("  阵营=%s 攻击层位=[%s] gate=%s" % [
					_factions_of(sp), _height_layer_names(
							skin.hitboxes[0].collision_layer
							if skin.hitboxes.size() > 0 else 0),
					"开" if sp.state == SpellBase.SpellState.ACTIVE
					and sp._fade_in_left <= 0.0 else "关"])
	return out


func _provide_collision() -> Array[String]:
	var out: Array[String] = []
	for ch in _all_chars():
		out.append("【%s】root 层=0x%X 掩码=0x%X" % [
				ch.attributes.display_name.strip_edges(),
				ch.collision_layer, ch.collision_mask])
		var hb := ch.find_child("HurtBox", true, false) as QuiverHurtBox
		if hb != null:
			out.append("  HurtBox 层=0x%X 掩码=0x%X monitoring=%s 阵营=%s" % [
					hb.collision_layer, hb.collision_mask,
					str(hb.monitoring), _factions_of(hb)])
		else:
			out.append("  HurtBox: 未找到")
	for sp in _all_spells():
		var skin = sp.get("_skin")
		if skin == null or skin.hitboxes.size() == 0:
			continue
		out.append("【弹体 %s】" % sp.name)
		for hb in skin.hitboxes:
			var shapes := PackedStringArray()
			for cs in hb.get_children():
				if cs is CollisionShape2D or cs is CollisionPolygon2D:
					shapes.append("%s.disabled=%s" % [cs.name, str(cs.disabled)])
			out.append("  %s 层=0x%X 高度层[%s] 阵营=%s | %s" % [
					hb.name, hb.collision_layer,
					_height_layer_names(hb.collision_layer),
					_factions_of(hb), " ".join(shapes)])
	return out


## [高度层]：旧高度层面板的文字部分移植（图形竖条按设计留在原地）。
func _provide_height() -> Array[String]:
	var out: Array[String] = []
	for ch in _all_chars():
		var skin = ch.get("_skin")
		if skin == null:
			continue
		var bh: float = skin.base_height
		var ph: float = skin.physical_height
		out.append("【%s】占位区间 [%.0f, %.0f]" % [
				ch.attributes.display_name.strip_edges(), bh, bh + ph])
		out.append("  physical_height %.0f  attack_heights %s" % [ph, str(skin.attack_heights)])
		out.append("  高度层[%s]  位置 %s  skin.y %.1f" % [
				_height_layer_names(ch.collision_layer),
				str((ch as Node2D).global_position), skin.position.y])
	return out


## [击飞]：旧击倒面板整体移植（纯文字面板退役）。快照采集器保留原信号监听
## 语义（knockout_requested 瞬间存值），挂接幂等、按属性实例去重。
var _knock_snapshots: Dictionary = {}
var _wired_attributes: Dictionary = {}


func _provide_knockout() -> Array[String]:
	var out: Array[String] = []
	for ch in _all_chars():
		var a: QuiverAttributes = ch.attributes
		if a == null:
			continue
		_wire_attributes(a)
		var st := "-"
		if "state_machine" in ch and ch.state_machine != null:
			st = str(ch.state_machine.state_name)
		out.append("【%s】击退 %d/600  重量 %.1f  该飞=%s" % [
				a.display_name.strip_edges(), a.knockback_amount,
				a.knockback_weight, str(a.should_knockout())])
		out.append("  无敌=%s 霸体=%s HP %.0f/%.0f 状态=%s" % [
				str(a.is_invulnerable), str(a.has_superarmor),
				a.health_current, a.health_max, st])
		var snap: Dictionary = _knock_snapshots.get(a.get_instance_id(), {})
		if not snap.is_empty():
			out.append("  [击飞记录] %d × %.1f  launch=%s  计算速度=%s" % [
					snap.knockback_amount, snap.knockback_weight,
					str(snap.launch_vector), str(snap.computed_velocity)])
	return out


func _wire_attributes(a: QuiverAttributes) -> void:
	var id := a.get_instance_id()
	if _wired_attributes.has(id):
		return
	_wired_attributes[id] = a
	a.knockout_requested.connect(
			func(kb: QuiverKnockbackData):
				_knock_snapshots[id] = {
						"knockback_amount": a.knockback_amount,
						"knockback_weight": a.knockback_weight,
						"launch_vector": kb.launch_vector,
						"computed_velocity": kb.launch_vector * a.knockback_amount * a.knockback_weight})


## [帮助]：场景操作说明牌（节点仍在底版、visible=false 不占画面）由本页读出。
## 场景各自改写说明文字的既有机制（kit 标题/键位替换）零改动。
## 引擎陷阱（2026-09-16 实机定罪）：String.split() 返回 PackedStringArray，
## 与 Array[String] 是两种类型——必须逐行搬运，直返在刷新期每 0.15s 报一次。
func _provide_help() -> Array[String]:
	var scene := get_tree().current_scene
	if scene == null:
		return ["（无在场场景）"]
	var lbl := scene.find_child("DebugLabel", true, false) as Label
	if lbl == null or lbl.text.strip_edges().is_empty():
		return ["（本场景无操作说明牌）"]
	var out: Array[String] = []
	for line in lbl.text.split("\n"):
		out.append(str(line))
	return out


func _provide_system() -> Array[String]:
	var dn := get_tree().root.get_node_or_null("DayNightManager")
	var phase := "-"
	if dn != null:
		var p = dn.get("current_phase")
		phase = str(p) if p != null else "?"
	return [
		"FPS %d（物理 tick %d）" % [Engine.get_frames_per_second(),
				Engine.get_physics_ticks_per_second()],
		"角色 %d | 弹体 %d" % [_all_chars().size(), _all_spells().size()],
		"昼夜相位: %s" % phase,
		"窗口: %s | 页签: Tab 循环" % ("开" if _dock_visible() else "关"),
		"版本: Godot %s" % Engine.get_version_info().string,
	]


func _dock_visible() -> bool:
	var dock := get_tree().root.get_node_or_null("DebugDock")
	return dock != null and dock.visible
