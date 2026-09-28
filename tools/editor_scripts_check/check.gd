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

## 动画资源自洽哨兵 v2（2026-09-28，用户纠错后的正确模型）：
## 皮肤动画的播放真相=Animation 资源内部三条轨——`animation` 名轨 +
## `AnimatedSprite2D:frame` 帧号轨（按时间把帧号从 0 插值到末帧，这才是
## "按时间设置帧编号"）+ `method` 信标轨（呼叫 end_of_skin_animation 定状态
## 收口）。SpriteFrames 的 fps 字段只影响编辑器时间轴，运行期不参与帧轨动画。
## 因此不检查任何"每角色本就各异"的具体数值（帧数/时长/fps），只查四条
## 关系不变量（全库存量扫描实测零违例）：
##   ① 信标键时刻 ≤ length（越界=信标永不响，序列静默挂死，P24b 同族源头）
##   ② 帧轨末键时刻 ≤ length（越界=时段内放不完，尾帧截断）
##   ③ 帧轨末键的帧号 ≥ 该动画在 SpriteFrames 的帧数-1（不足=尾帧没人看）
##   ④ 多帧动画必须有帧轨（缺轨=运行期回退名驱动，帧推进失联）
func _check_anim_dual_clock() -> int:
	var fails := 0
	for dir in ANIM_DIRS:
		var sf := ""
		for f in DirAccess.get_files_at(dir):
			if f.begins_with("spriteframes_") and f.ends_with(".tres"):
				sf = FileAccess.get_file_as_string(dir.path_join(f))
		var adir: String = dir.path_join("animations")
		if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(adir)):
			continue
		for f in DirAccess.get_files_at(adir):
			if not f.ends_with(".tres"):
				continue
			var t := FileAccess.get_file_as_string(adir.path_join(f))
			var nm := f.trim_suffix(".tres")
			var times := _track_times(t, 'path = NodePath(".")')
			if times.is_empty():
				continue  # 无信标轨=收口不靠本轨（悬停/循环族），全豁免
			var length := 1.0
			var lm := RegEx.create_from_string("length = ([0-9.]+)").search(t)
			if lm != null:
				length = float(lm.get_string(1))
			for mt in times:
				if mt > length + 0.001:
					print("  FAIL: %s/%s 信标键 %.3fs 超出时段 %.3fs（永不敲钟=序列挂死；修法：键拖到 length 处或按设计延长时段）" % [dir.get_file(), nm, mt, length])
					fails += 1
			var frames := _sf_frames(sf, nm)
			var ftimes := _track_times(t, 'path = NodePath("AnimatedSprite2D:frame")')
			if ftimes.is_empty():
				if frames > 1:
					print("  FAIL: %s/%s 多帧动画(%d 帧)缺 frame 帧轨——运行期帧推进失联（修法：动画编辑器补轨 0→%d 铺满时段）" % [dir.get_file(), nm, frames, frames - 1])
					fails += 1
				continue
			if ftimes.back() > length + 0.001:
				print("  FAIL: %s/%s 帧轨末键 %.3fs 超出时段 %.3fs（尾帧截断）" % [dir.get_file(), nm, ftimes.back(), length])
				fails += 1
			var fvals := _track_values(t, 'path = NodePath("AnimatedSprite2D:frame")')
			if not fvals.is_empty() and frames > 0 and int(fvals.back()) < frames - 1:
				print("  FAIL: %s/%s 帧轨只铺到第 %d 帧、SpriteFrames 实有 %d 帧（尾帧无人看见；修法：帧轨末键值提至 %d）" % [dir.get_file(), nm, int(fvals.back()), frames, frames - 1])
				fails += 1
	return fails


## 从 Animation 文本提取指定轨的 keys.times（升序浮点数组）
func _track_times(t: String, marker: String) -> Array[float]:
	var out: Array[float] = []
	var at := t.find(marker)
	if at < 0:
		return out
	var ts := _paren_array(t, '"times": PackedFloat32Array(', at)
	for x in ts:
		out.append(float(x))
	return out


## 同轨 keys.values 的末段数值（frame 轨为整型帧号）
func _track_values(t: String, marker: String) -> Array[String]:
	var at := t.find(marker)
	if at < 0:
		return []
	var ts := _paren_array(t, '"times": PackedFloat32Array(', at)
	if ts.is_empty():
		return []
	# values 块在 times 之后
	var vfrom := t.find('"values": [', at)
	if vfrom < 0:
		return []
	var vend := t.find("]", vfrom)
	var body := t.substr(vfrom + 10, vend - vfrom - 10)
	var out: Array[String] = []
	for v in body.split(","):
		out.append(v.strip_edges())
	return out


func _paren_array(text: String, prefix: String, from: int) -> PackedStringArray:
	var at := text.find(prefix, from)
	if at < 0:
		return PackedStringArray()
	var start := at + prefix.length()
	var end := text.find(")", start)
	if end < 0:
		return PackedStringArray()
	var body := text.substr(start, end - start).strip_edges()
	if body.is_empty():
		return PackedStringArray()
	return body.split(",")


## spriteframes 里某动画的帧条目数
func _sf_frames(sf: String, nm: String) -> int:
	var at := sf.find('"name": &"' + nm + '"')
	if at < 0:
		return 0
	var fst := sf.rfind('"frames": [', at)
	if fst < 0:
		return 0
	return RegEx.create_from_string("ExtResource\\(").search_all(sf.substr(fst, at - fst)).size()
