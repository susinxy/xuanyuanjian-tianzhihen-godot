extends Node

## 接触点特效调度（B4.7 R4/R5）：Events.hit_landed → 按风格路由参数卡 →
## 实例化 HitSparkFx 两层挂 current_scene。宿主形态：autoload（登记适配波
## 已入账：controller 完成 [autoload] HitFx + [input] hit_fx_toggle；键位沿革：
## 原绑 F8 撞 Godot 编辑器 Debug>停止项目 默认快捷键（F5 实测被杀进程，
## 2026-09-27 改绑 V=86，动作名不变）；
## 契约 E/K 流单点装配优先复用本单例，缺席回退手建保旧世界兼容——双消费者
## 形态=K2a 假红判例，见契约 FX-GATE）。
## R5 运行时开关：`enabled` 直翻 + `toggle()` 公开入口；开关键判定按
## "动作登记后自动通电"预铺（hit_fx_toggle 缺席时 InputMap.has_action 短路，
## 零报错零行为；controller 登记 [input] 后本 _process 立刻开始接单）。
## headless 判例（T3 探针2）：动态 InputMap 注册 + raw 直投喂不饱
## is_action_just_pressed 轮询——契约 K 流因此走 toggle 注入等价 + 本文件
## 预铺形制源码锁，不搞动作注册舞。
## 调试坞（spec §3.5）：_ready 注册"命中反馈"文字页（dock 缺席防御跳过，
## provider 由 dock 0.15s 物理心跳拉取——拉取制判例，headless 可达）。

## 参数卡注册表（单一出处）：风格名→卡。缺卡/default 键互保——任何命中
## 都有火花（spec §3.4"未配置=default 兜底"）。键为常量值必须冒号形
## （AGENTS 字典字面量判例：`{K = v}` 键=标识符字面名）。
const PRESETS: Dictionary = {
	&"default": preload("res://scripts/effects/presets/spark_default.tres"),
	&"heavy": preload("res://scripts/effects/presets/spark_heavy.tres"),
	&"fire": preload("res://scripts/effects/presets/spark_fire.tres"),
}

const SPARK_SCRIPT := preload("res://scripts/effects/hit_spark_fx.gd")

## 视觉腿总开关（R5）：只关视觉不关时间腿（慢放/定格在 HurtBox 侧，与本位
## 无耦合——K2 双腿独立锁的结构性保证）。
var enabled: bool = true


func _ready() -> void:
	Events.hit_landed.connect(_on_hit_landed)
	var dock := get_tree().root.get_node_or_null(^"DebugDock")
	if dock != null and dock.has_method("add_text_tab"):
		dock.add_text_tab("命中反馈", _provide_hit_fx_lines)


func _process(_delta: float) -> void:
	# 开关键预铺（R5 判例形制，shadow_region.gd:43 同款"动作→翻旗"）：
	# 动作缺席时 has_action 短路，零报错零行为；登记即自动通电。
	# K 流另有源码锁腿盯本三行形制（探针2 判例：headless 喂不饱轮询，
	# 端到端腿归 F5 感官单）。
	if InputMap.has_action(&"hit_fx_toggle") and Input.is_action_just_pressed("hit_fx_toggle"):
		toggle()


## R5 公开翻转入口（开关键接线走 InputMap 判定连到这里；
## 契约 K 流经此注入=toggle 语义真身）。
func toggle() -> void:
	enabled = not enabled
	print("[HITFEEL] 特效开关 → %s" % ("开" if enabled else "关"))


func _on_hit_landed(point: Vector2, style: StringName, _strength: float, dir: Vector2) -> void:
	if not enabled:
		print("[HITFEEL] 特效被开关拦截 style=%s pos=%s" % [style, point])
		return
	var preset: HitSparkPreset = PRESETS.get(style, PRESETS[&"default"])
	var fx := SPARK_SCRIPT.new()  # Variant 动态调用（宿主脚本无 class_name 判例）
	fx.configure(preset, dir)
	fx.position = point
	# 夹层判例规避：背景 z=5 / Level z=15 / Foreground z=25——特效 z=20
	fx.z_index = 20
	var host := get_tree().current_scene
	if host == null:
		host = get_tree().root
	host.add_child(fx)
	print("[HITFEEL] 特效出生 style=%s pos=%s dir=%s host=%s" % [style, point, dir, host.name])


## 调试坞状态行（开关状态不许失踪，spec §3.5）
func _provide_hit_fx_lines() -> Array[String]:
	return ["命中特效：%s（V 切换）" % ("开" if enabled else "关")]
