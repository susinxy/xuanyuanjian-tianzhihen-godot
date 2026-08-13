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
	# 调试：记录被选中的对象
	if object is Node:
		var node := object as Node
		var script = node.get_script()
		var script_class := ""
		if script:
			script_class = script.get_global_name()
		print("[HeightLayers] _can_handle - node: %s, class: %s" % [node.name, script_class])
	
	# 选中 QuiverCharacterSkinAnimTree 节点时激活
	# 通过 class_name 检查，避免脚本未扫描时的失败
	if object is Node and object.get_script():
		var script = object.get_script()
		if script and script.get_global_name() == "QuiverCharacterSkinAnimTree":
			print("[HeightLayers] ✓ 匹配 QuiverCharacterSkinAnimTree")
			return true
	# Fallback type check
	if object is QuiverCharacterSkinAnimTree:
		print("[HeightLayers] ✓ 类型匹配 QuiverCharacterSkinAnimTree")
		return true
	return false


func _parse_begin(object: Object) -> void:
	print("[HeightLayers] _parse_begin 被调用")
	var widget := SCENE_WIDGET.instantiate() as HeightLayersWidget
	if widget == null:
		print("[HeightLayers] ✗ Widget 实例化失败")
		return
	print("[HeightLayers] ✓ Widget 实例化成功")
	# 先添加到场景树触发 _ready()，再调用 set_skin_node()
	QuiverEditorHelper.connect_between(widget.scan_completed, _on_scan_completed)
	add_custom_control(widget)
	widget.set_skin_node(object)


func _on_scan_completed(anim_count: int, frame_count: int, error_count: int) -> void:
	# 扫描完成后刷新文件系统，让资源更新可见
	EditorInterface.get_resource_filesystem().scan()
	print("[HeightLayers] 扫描完成 - %d 个动画，%d 帧，%d 个错误" % [
		anim_count, frame_count, error_count
	])
