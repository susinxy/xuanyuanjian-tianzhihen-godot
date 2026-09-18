extends CanvasLayer

## 正式 HUD（游戏层，2026-09-16 HUD 设计丙方案批 3）：
## 左上横排——头像 | 名字 + 血/蓝条 + 法术槽。
## 槽格数以 SpellManager 公开面（slot_count）为唯一来源，每帧自校准——
## 容量变化即时跟随；本文件不复制任何容量常数（2026-09-17 加固批）。
## 绑定策略：跟随 players 组首个角色——现在=被操作主角；
## 三期角色切换系统"换人"时组内首位易主，HUD 零改动自动跟手。
## 一期为克制占位样式（半透明底+纯色条），《天之痕》正式美术风格留给替换批。

const SLOT_SIZE := 56.0

const SpellIconResolver := preload("res://ui/spell_icon_resolver.gd")

var _bound: QuiverCharacter = null
var _slot_panels: Array[Panel] = []
var _slot_icons: Array[TextureRect] = []
var _slot_labels: Array[Label] = []
var _slot_covers: Array[ColorRect] = []

@onready var _frame: PanelContainer = $Frame
@onready var _portrait: TextureRect = $Frame/Row/Portrait
@onready var _name_label: Label = $Frame/Row/Info/Name
@onready var _hp: ProgressBar = $Frame/Row/Info/Hp
@onready var _mp: ProgressBar = $Frame/Row/Info/Mp
@onready var _slots_row: HBoxContainer = $Frame/Row/Info/Slots


func _ready() -> void:
	layer = 5
	_hp.self_modulate = Color(1.0, 0.38, 0.32)
	_mp.self_modulate = Color(0.38, 0.62, 1.0)
	# 默认主题黑字压暗色 Panel=隐形（与调试坞同案的预防修复）
	_name_label.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))


func _process(_delta: float) -> void:
	var ch := _current_player()
	_frame.visible = ch != null
	if ch == null:
		return
	var a := ch.attributes
	_hp.max_value = a.health_max
	_hp.value = a.health_current
	_mp.max_value = a.mana_max
	_mp.value = a.mana_current
	if ch != _bound:
		_bound = ch
		_name_label.text = a.display_name.strip_edges()
		_portrait.texture = a.profile_texture
	_ensure_slot_count()
	_refresh_slots()


## 每帧自校准：格数与 manager 公开计数不符即重建（罕见事件——启动或容量变化；
## 相等时一次整数比较即返回）。
func _ensure_slot_count() -> void:
	var sm = _bound.get("_spell_manager")
	var want: int = sm.slot_count() if sm != null else 0
	if want == _slot_panels.size():
		return
	for old in _slot_panels:
		old.free()
	_slot_panels.clear()
	_slot_icons.clear()
	_slot_labels.clear()
	_slot_covers.clear()
	for i in want:
		_build_slot(i)


func _build_slot(i: int) -> void:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)
	var label := Label.new()
	label.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot.add_child(label)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.62)
	cover.set_anchor(SIDE_LEFT, 0.0)
	cover.set_anchor(SIDE_RIGHT, 1.0)
	cover.set_anchor(SIDE_TOP, 0.0)
	cover.set_anchor(SIDE_BOTTOM, 0.0, true)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(cover)
	_slots_row.add_child(slot)
	_slot_panels.append(slot)
	_slot_icons.append(icon)
	_slot_labels.append(label)
	_slot_covers.append(cover)


func _current_player() -> QuiverCharacter:
	for n in get_tree().get_nodes_in_group("area2d:player"):
		if n is QuiverCharacter:
			return n
	return null


func _refresh_slots() -> void:
	var sm = _bound.get("_spell_manager")
	for i in _slot_panels.size():
		var slot = sm.get_spell_slot(i) if sm != null else null
		if slot == null or slot.is_empty():
			_slot_icons[i].texture = null
			_slot_panels[i].tooltip_text = ""
			_slot_labels[i].text = str(i + 1)
			_slot_labels[i].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_slot_labels[i].vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_slot_labels[i].remove_theme_font_size_override("font_size")
			_slot_covers[i].set_anchor(SIDE_BOTTOM, 0.0, true)
			continue
		var defn: SpellDefinition = slot.definition
		var frac := 0.0
		if defn.cooldown > 0.0:
			frac = clampf(slot.cooldown_remaining / defn.cooldown, 0.0, 1.0)
		# 图标为主：有 icon 用 icon，无则派生 right 动画首帧（resolver 三级链+缓存）；
		# 名字进 tooltip，键位数字退居右下角小角标
		_slot_icons[i].texture = SpellIconResolver.icon_for(defn)
		_slot_panels[i].tooltip_text = defn.display_name.strip_edges()
		_slot_labels[i].text = str(i + 1)
		_slot_labels[i].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_slot_labels[i].vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_slot_labels[i].add_theme_font_size_override("font_size", 11)
		# keep_offsets=true 才会让矩形底边真正跟随锚点（默认 false=引擎反向修
		# offset 保持视觉不动——冷却遮罩隐身事故根因，2026-09-16 探针实锤）
		_slot_covers[i].set_anchor(SIDE_BOTTOM, frac, true)
