@tool
extends EditorInspectorPlugin
## Inspector plugin for spell management (create and delete spells)
## 
## This plugin activates when the user selects a SpellTemplate node,
## which is located at spells/_template/spell_template.tscn
##
## Provides a widget with:
## - Create spell form (name, class name, display name)
## - Delete spell dropdown (lists all existing spells)

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const CreateNewSpellWidget = preload(
	"res://addons/quiver.beat_em_up/custom_inspectors/create_new_spell/"
	+"create_new_spell_widget.gd"
)
const SCENE_WIDGET = preload(
	"res://addons/quiver.beat_em_up/custom_inspectors/create_new_spell/"
	+"create_new_spell_widget.tscn"
)

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var & onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _can_handle(object) -> bool:
	if object is Node and object.get_script():
		var script = object.get_script()
		if script and script.get_global_name() == "SpellTemplate":
			return true
	return object is SpellTemplate


func _parse_begin(object: Object) -> void:
	var widget := SCENE_WIDGET.instantiate() as CreateNewSpellWidget
	QuiverEditorHelper.connect_between(widget.spell_created, _on_spell_created)
	QuiverEditorHelper.connect_between(widget.spell_deleted, _on_spell_deleted)
	QuiverEditorHelper.connect_between(widget.spell_test_requested, _on_spell_test_requested)
	add_custom_control(widget)


func _on_spell_created(spell_name: String) -> void:
	EditorInterface.get_resource_filesystem().scan()
	print("[SpellCreator] Spell '%s' created successfully!" % spell_name)


func _on_spell_deleted(spell_name: String) -> void:
	EditorInterface.get_resource_filesystem().scan()
	print("[SpellCreator] Spell '%s' deleted successfully!" % spell_name)


func _on_spell_test_requested(char_name: String, spell_name: String) -> void:
	var test_scene_path = "res://test_scenes/_test_spell_" + spell_name + ".tscn"
	var character_scene_path = "res://characters/playable/" + char_name + "/" + char_name + ".tscn"
	var spell_definition_path = "res://spells/" + spell_name + "/resources/" + spell_name + "_definition.tres"
	var spell_scene_path = "res://spells/" + spell_name + "/" + spell_name + ".tscn"
	
	if not FileAccess.file_exists(character_scene_path):
		push_error("[SpellTest] Character scene not found: %s" % character_scene_path)
		return
	
	if not FileAccess.file_exists(spell_definition_path):
		push_error("[SpellTest] Spell definition not found: %s" % spell_definition_path)
		return
	
	# 测试场景 = 角色底版 + 法术套件（单一底版，见 QuiverRunTestSceneBuilder）
	
	var helper_script_content = """extends Node

## 法术注入脚本（测试场景生成物）：唯一职责是把被测法术教给被测角色本人；
## 按键轮询/扣蓝/冷却/施法全部由角色壳自己的既有链路统一负责。
## 历史教训（2026-09）：私有输入通道的按键边沿"读一次即消费"，且父节点
## （角色壳）先于子节点轮询——助手若自建管理器自听键，永远抢不到按键。

var _taught := false

func _ready():
	# 子节点 _ready 早于父节点，而角色壳的法术管理器要到父 _ready 才创建
	# → 延后一帧再教。
	call_deferred("_teach")

func _teach():
	var host = get_parent()
	if not host.has_method("learn_spell"):
		push_error("[SpellTest] 宿主角色缺少 learn_spell，无法注入")
		return
	var spell_def: SpellDefinition = load("{{SPELL_DEF_PATH}}")
	spell_def.spell_scene = load("{{SPELL_SCENE_PATH}}")
	_taught = host.learn_spell(spell_def)
	if not _taught:
		push_error("[SpellTest] 法术注入失败（手册已满或定义加载失败）")
"""
	
	# 组装 helper 脚本内容与测试场景内容（生成物统一落 test_scenes/，幂等写盘：
	# 内容未变不写盘/不扫描/不 await，避免编辑器"硬盘变动"弹窗与 filesystem_changed 卡死）
	helper_script_content = helper_script_content\
		.replace("{{SPELL_DEF_PATH}}", spell_definition_path)\
		.replace("{{SPELL_SCENE_PATH}}", spell_scene_path)
	var helper_script_path = "res://test_scenes/_test_spell_helper_" + spell_name + ".gd"
	if not DirAccess.dir_exists_absolute("res://test_scenes"):
		DirAccess.make_dir_recursive_absolute("res://test_scenes")
	var helper_written := _write_if_changed(helper_script_path, helper_script_content)
	
	# 装配：角色底版 → 法术套件（helper+面板+右列避让） → 统一编排 compose
	var test_scene_content := QuiverRunTestSceneBuilder.base_scene_text()\
			.replace("{{CHAR_PATH}}", character_scene_path)\
			.replace("{{CHAR_NAME}}", char_name)
	test_scene_content = QuiverRunTestSceneBuilder.add_spell_test_kit(
			test_scene_content, spell_name, helper_script_path)
	var subject_mode := QuiverRunTestSceneBuilder.scene_behavior_mode(character_scene_path)
	test_scene_content = QuiverRunTestSceneBuilder.compose(
			test_scene_content, character_scene_path, subject_mode)
	var scene_written := _write_if_changed(test_scene_path, test_scene_content)
	if helper_written == false and scene_written == false:
		EditorInterface.play_custom_scene(test_scene_path)
		print("[SpellTest] Testing spell '%s' with character '%s' - test scene unchanged, launched directly." % [spell_name, char_name])
		return
	
	# Refresh filesystem and run the scene
	EditorInterface.get_resource_filesystem().scan()
	
	await EditorInterface.get_resource_filesystem().filesystem_changed
	EditorInterface.play_custom_scene(test_scene_path)
	print("[SpellTest] Testing spell '%s' with character '%s' - test scene: %s" % [spell_name, char_name, test_scene_path])

## 内容不同才写盘；返回是否写入（false=内容一致跳过 / 写失败由调用方经 play 报错兜底）
func _write_if_changed(path: String, content: String) -> bool:
	if FileAccess.file_exists(path) and FileAccess.get_file_as_string(path) == content:
		return false
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[SpellTest] Failed to write: %s" % path)
		return false
	f.store_string(content)
	f.close()
	return true

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
