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
	fails += _check_anim_dual_clock()
	print("════════ editor-scripts: %d 脚本 / %d FAIL ════════" % [TOOL_SCRIPTS.size(), fails])
	quit(0 if fails == 0 else 1)


## 动画资产双钟一致性哨兵（2026-09-27 用户"来龙去脉"质询的机械化答复）：
## 本仓皮肤=双层资产——Animation 资源（时段 length+末帧信标）包着
## SpriteFrames 胶片（帧数÷fps）。玩法只读时段（信标定相位切换/状态收口），
## 画面按胶片自转；**凡带信标的动画，胶片必须能在时段内放完**
## （超出 1.5 帧即红），否则动作被腰斩（历史实锤：施法起手 17 帧@5fps
## 挤 0.333s 时段，玩家只看到 1.7 帧）。无信标态（rising/falling 悬停等）
## 豁免——定格尾帧是设计语汇。修法二选一：提 fps 让画面追上时段（零玩法
## 变动，本次全库 18 处即此法）或改时段（=改平衡，须设计裁决+契约联动）。
const ANIM_DIRS := [
	"res://templates/character/resources",
	"res://characters/playable/chen/resources",
	"res://characters/enemies/spar_enemy/resources",
	"res://characters/neutrals/street_vendor/resources",
]

## 动画资产双钟一致性哨兵（2026-09-27 用户"来龙去脉"质询的机械化答复）：
## 皮肤动画=双层资产——Animation 资源（时段 length+末帧信标）包着
## SpriteFrames 胶片（帧数÷fps）。玩法只读时段（信标定状态收口），画面按
## 胶片自转；凡带信标的动画，胶片必须能在时段内放完（超出 1.5 帧即红），
## 否则动作被腰斩（历史实锤：施法起手 17 帧@5fps 挤 0.333s 时段=只见 1.7 帧）。
## 无信标态（rising/falling 悬停族）豁免——定格尾帧是设计语汇。
## 修法二选一：提 fps 让画面追上时段（零玩法变动，本次全库 18 处即此法）；
## 或改时段（=改平衡，须设计裁决+契约联动，GUIDE_格挡"动画即规则"在册）。
func _check_anim_dual_clock() -> int:
	var fails := 0
	for dir in ANIM_DIRS:
		var sf_path := ""
		for f in DirAccess.get_files_at(dir):
			if f.begins_with("spriteframes_") and f.ends_with(".tres"):
				sf_path = dir.path_join(f)
		if sf_path == "":
			continue
		var sf := FileAccess.get_file_as_string(sf_path)
		var adir: String = dir.path_join("animations")
		if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(adir)):
			continue
		for f in DirAccess.get_files_at(adir):
			if not f.ends_with(".tres"):
				continue
			var t := FileAccess.get_file_as_string(adir.path_join(f))
			if not t.contains('"method"'):
				continue
			var nm := f.trim_suffix(".tres")
			var name_at := sf.find('"name": &"' + nm + '"')
			var frames_at := sf.rfind('"frames": [', name_at)
			var loop_at := sf.find('"loop"', name_at)
			var len_m := RegEx.create_from_string("length = ([0-9.]+)").search(t)
			var spd_m := RegEx.create_from_string('"speed": ([0-9.]+)').search(sf, name_at)
			if name_at < 0 or frames_at < 0 or loop_at < 0 or len_m == null or spd_m == null:
				continue
			var frames := RegEx.create_from_string("ExtResource\\(").search_all(
					sf.substr(frames_at, name_at - frames_at)).size()
			var fps := float(spd_m.get_string(1))
			if fps <= 0.0 or frames == 0:
				continue
			var natural := float(frames) / fps
			var slot := float(len_m.get_string(1))
			if natural - slot > 1.5 / fps:
				print("  FAIL: %s/%s 胶片放不完：帧数 %d ÷ fps %.0f = %s s > 时段 %s s（修法：fps 提至 %d 或按设计改时段+契约联动）" % [
					dir.get_file(), nm, frames, fps,
					("%.3f" % natural), ("%.3f" % slot), int(round(float(frames) / slot))])
				fails += 1
	return fails
