@tool
extends EditorInspectorPlugin
## Inspector plugin 入口：法术轮廓转换工具
##
## 在选中 SpellSkinAnimTree 节点（法术皮肤节点）时显示，
## 复用 height_layers_widget，通过 hide_body_button() 隐藏 Body 按钮。
##
## 设计文档：docs/SPELL_SYSTEM_DESIGN.md

const HeightLayersWidget = preload(
	"res://addons/quiver.beat_em_up/custom_inspectors/height_layers/"
	+ "height_layers_widget.gd"
)
const SCENE_WIDGET = preload(
	"res://addons/quiver.beat_em_up/custom_inspectors/height_layers/"
	+ "height_layers_widget.tscn"
)


func _can_handle(object: Object) -> bool:
	# 选中 SpellSkinAnimTree 节点时激活
	if object is Node and object.get_script():
		var script = object.get_script()
		if script and script.get_global_name() == "SpellSkinAnimTree":
			return true
	if object is SpellSkinAnimTree:
		return true
	return false


func _parse_begin(object: Object) -> void:
	var widget := SCENE_WIDGET.instantiate() as HeightLayersWidget
	if widget == null:
		return
	widget.hide_body_button()
	add_custom_control(widget)
	widget.set_skin_node(object)

