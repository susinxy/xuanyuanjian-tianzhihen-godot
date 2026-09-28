extends SceneTree

## 编辑器脚本编译巡检（2026-09-17 补网）：@tool 的 Inspector 插件/widget/创建器
## 不在运行时 headless 场景的加载路径里，运行时矩阵对它们的解析错误全盲
## （实例：阵营改造后 widget 残引 _faction_option 编译挂 → 信号消失 →
## Windows 编辑器每帧报 Invalid access 'character_created'）。
## 本脚本 load 全部项目岛编辑脚本并断言关键信号在位，任一 FAIL 整红。

const TOOL_SCRIPTS := [
	"res://addons/quiver.beat_em_up/custom_inspectors/create_new_character/create_new_character_widget.gd",
	"res://addons/quiver.beat_em_up/custom_inspectors/create_new_character/character_creator.gd",
	"res://addons/quiver.beat_em_up/custom_inspectors/create_new_character/character_deleter.gd",
	"res://addons/quiver.beat_em_up/custom_inspectors/create_new_character/inspector_plugin.gd",
	"res://addons/quiver.beat_em_up/custom_inspectors/create_new_character/run_test_scene_builder.gd",
	"res://addons/quiver.beat_em_up/custom_inspectors/_shared/template_cloner.gd",
	"res://addons/quiver.beat_em_up/custom_inspectors/create_new_spell/create_new_spell_widget.gd",
	"res://addons/quiver.beat_em_up/custom_inspectors/create_new_spell/spell_creator.gd",
	"res://addons/quiver.beat_em_up/custom_inspectors/create_new_spell/spell_deleter.gd",
	"res://addons/quiver.beat_em_up/custom_inspectors/create_new_spell/inspector_plugin.gd",
	"res://templates/character/character_template.gd",
	"res://templates/spell/spell_template.gd",
]

## 信号契约：脚本 -> 必须声明的信号名（inspector_plugin 按这些接线）
const SIGNAL_CONTRACTS := {
	"res://addons/quiver.beat_em_up/custom_inspectors/create_new_character/create_new_character_widget.gd":
		["character_created", "character_test_requested", "character_deleted"],
	"res://addons/quiver.beat_em_up/custom_inspectors/create_new_spell/create_new_spell_widget.gd":
		["spell_created", "spell_deleted", "spell_test_requested"],
}


func _init() -> void:
	var fails := 0
	for p in TOOL_SCRIPTS:
		var scr: Script = load(p)
		if scr == null or not scr.can_instantiate():
			print("  FAIL: 编译失败 ", p)
			fails += 1
			continue
		for sig in SIGNAL_CONTRACTS.get(p, []):
			var found := false
			for declared in scr.get_script_signal_list():
				if declared.name == sig:
					found = true
					break
			if not found:
				print("  FAIL: %s 缺信号 %s" % [p.get_file(), sig])
				fails += 1
	# 注册表守卫（2026-09-27 max hub 事故补网）：编辑器长会话回写曾三次吞掉
	# 外部登记的 [autoload]/[input] 条目（本次连 GameSave/SaveSystem/HitFx 与
	# hit_fx_toggle 一起被吞，另一台机 F5 直接 "GameSave not declared"）——
	# Linux 端矩阵看不见 Windows 的 project.godot 吞改，但被吞版本终会同步回来；
	# 本锁让"注册表完整性"每轮矩阵必检，吞改回流当场响亮红。
	var proj := FileAccess.get_file_as_string("res://project.godot")
	for autoload in ["GameEvents", "GameSave", "SaveSystem", "HitFx"]:
		if not proj.contains('\n%s="' % autoload):
			print("  FAIL: project.godot [autoload] 缺 %s（疑似编辑器回写吞改，git restore project.godot）" % autoload)
			fails += 1
	for action in ["block", "hit_fx_toggle", "shadow_region_toggle"]:
		if not proj.contains("\n%s={" % action):
			print("  FAIL: project.godot [input] 缺动作 %s（同上吞改处方）" % action)
			fails += 1
	print("════════ editor-scripts: %d 脚本 / %d FAIL ════════" % [TOOL_SCRIPTS.size(), fails])
	quit(0 if fails == 0 else 1)
