@tool
extends EditorInspectorPlugin
## Inspector plugin 入口：法术轮廓转换工具
##
## 在选中 SpellSkinAnimTree 节点（法术皮肤节点）时显示，
## 提供 "攻击轮廓转换" 功能，用于从 PNG 提取攻击轮廓并生成碰撞形状。
##
## 设计文档：docs/SPELL_SYSTEM_DESIGN.md

const SpellContourWidget = preload(
	"res://addons/quiver.beat_em_up/custom_inspectors/spell_contour/"
	+ "spell_contour_widget.gd"
)
const SCENE_WIDGET = preload(
	"res://addons/quiver.beat_em_up/custom_inspectors/spell_contour/"
	+ "spell_contour_widget.tscn"
)


func _can_handle(object: Object) -> bool:
	# 选中 SpellSkinAnimTree 节点时激活
	# 通过 class_name 检查，避免脚本未扫描时的失败
	if object is Node and object.get_script():
		var script = object.get_script()
		if script and script.get_global_name() == "SpellSkinAnimTree":
			return true
	# Fallback type check
	if object is SpellSkinAnimTree:
		return true
	return false


func _parse_begin(object: Object) -> void:
	var widget := SCENE_WIDGET.instantiate() as SpellContourWidget
	if widget == null:
		return
	# 先添加到场景树触发 _ready()，再调用 set_skin_node()
	QuiverEditorHelper.connect_between(widget.conversion_completed, _on_conversion_completed)
	add_custom_control(widget)
	widget.set_skin_node(object)


func _on_conversion_completed(frame_count: int, error_count: int) -> void:
	# 转换完成后刷新文件系统，让资源更新可见
	EditorInterface.get_resource_filesystem().scan()
