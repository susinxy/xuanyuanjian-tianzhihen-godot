@tool
extends EditorInspectorPlugin
## Inspector plugin 入口：高度层动画扫描工具
##
## 在选中 QuiverCharacterSkinAnimTree 节点（皮肤节点）时显示，
## 提供 "扫描动画高度数据" 按钮，用于解析动画帧文件名并生成
## value tracks / method tracks 写入 Animation 资源。
##
## 设计文档：docs/HEIGHT_LAYER_DESIGN.md

const HeightLayersWidget = preload(
	"res://addons/quiver.beat_em_up/custom_inspectors/height_layers/"
	+ "height_layers_widget.gd"
)
const SCENE_WIDGET = preload(
	"res://addons/quiver.beat_em_up/custom_inspectors/height_layers/"
	+ "height_layers_widget.tscn"
)


func _can_handle(object: Object) -> bool:
	# 选中 QuiverCharacterSkinAnimTree 节点时激活
	# 通过 class_name 检查，避免脚本未扫描时的失败
	if object is Node and object.get_script():
		var script = object.get_script()
		if script and script.get_global_name() == "QuiverCharacterSkinAnimTree":
			return true
	return object is QuiverCharacterSkinAnimTree


func _parse_begin(object: Object) -> void:
	var widget := SCENE_WIDGET.instantiate() as HeightLayersWidget
	widget.set_skin_node(object)
	QuiverEditorHelper.connect_between(widget.scan_completed, _on_scan_completed)
	add_custom_control(widget)


func _on_scan_completed(anim_count: int, frame_count: int, error_count: int) -> void:
	# 扫描完成后刷新文件系统，让资源更新可见
	EditorInterface.get_resource_filesystem().scan()
	print("[HeightLayers] 扫描完成 - %d 个动画，%d 帧，%d 个错误" % [
		anim_count, frame_count, error_count
	])
