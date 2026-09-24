class_name SpellRegistry
extends RefCounted

## 法术 id→definition 的单一解析点（S2-B4，spec §4）：全项目按 id 找法术定义
## 资源一律经本门，消费方不再手拼路径。**约定路径 = SpellCreator 产线纪律的
## 镜像**（addons/quiver.beat_em_up/custom_inspectors/create_new_spell/ 的
## spell_creator.gd / inspector_plugin.gd 硬编码同款 `spells/<id>/resources/
## <id>_definition.tres`）——创建器改路径必须同改此处，两边漂移=出生补学与
## 秘籍学习集体哑火。
## 缺件降级：null + 中文 push_warning（调用方自行判空早退，本门不崩不抛）。


## 按 id 解析法术定义；缺件/类型不符返回 null（push_warning=被试行为）
static func definition_for(spell_id: StringName) -> SpellDefinition:
	var path := "res://spells/%s/resources/%s_definition.tres" % [spell_id, spell_id]
	# 存在性判据与产线自检同源（inspector_plugin.gd 同款 FileAccess.file_exists；
	# 不用 ResourceLoader.exists——其对未导入资源也可能给真值，Kit 判例同族）
	if not FileAccess.file_exists(path):
		push_warning("SpellRegistry: 法术 %s 定义缺件（约定路径 %s 不存在）"
				% [spell_id, path])
		return null
	var def := load(path) as SpellDefinition
	if def == null:
		push_warning("SpellRegistry: %s 存在但加载/类型非 SpellDefinition，按缺件降级" % path)
	return def
