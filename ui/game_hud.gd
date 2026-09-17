extends CanvasLayer

## 正式 HUD（游戏层，2026-09-16 HUD 设计丙方案批 3）：
## 左上横排——头像 | 名字 + 血/蓝条 + 4 法术槽。
## 绑定策略：跟随 players 组首个角色——现在=被操作主角；
## 三期角色切换系统"换人"时组内首位易主，HUD 零改动自动跟手。
## 一期为克制占位样式（半透明底+纯色条），《天之痕》正式美术风格留给替换批。

const SLOT_COUNT := 4
const SLOT_SIZE := 56.0

var _bound: QuiverCharacter = null
var _slot_panels: Array[Panel] = []
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
	for i in SLOT_COUNT:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
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
		cover.set_anchor(SIDE_BOTTOM, 0.0)
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(cover)
		_slots_row.add_child(slot)
		_slot_panels.append(slot)
		_slot_labels.append(label)
		_slot_covers.append(cover)


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
	_refresh_slots()


func _current_player() -> QuiverCharacter:
	return get_tree().get_first_node_in_group("players") as QuiverCharacter


func _refresh_slots() -> void:
	var sm = _bound.get("_spell_manager")
	var slots: Array = sm._slots if sm != null and "_slots" in sm else []
	for i in SLOT_COUNT:
		if i >= slots.size() or slots[i].definition == null or slots[i].is_empty():
			_slot_labels[i].text = str(i + 1)
			_slot_covers[i].set_anchor(SIDE_BOTTOM, 0.0)
			continue
		var defn: SpellDefinition = slots[i].definition
		var frac := 0.0
		if defn.cooldown > 0.0:
			frac = clampf(slots[i].cooldown_remaining / defn.cooldown, 0.0, 1.0)
		_slot_labels[i].text = defn.display_name.strip_edges()
		_slot_covers[i].set_anchor(SIDE_BOTTOM, frac)
