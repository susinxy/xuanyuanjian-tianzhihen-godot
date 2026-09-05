@tool
class_name ShadowRegion
extends ReferenceRect

## 场景级"阴影可生成区域"（编辑器可拖拽矩形，沿用 QuiverFightRoom 的 ReferenceRect 惯例）。
## 语义：投影阴影只保留与本区域相交的部分（完全在外 → 该帧无阴影）；
##       与软边开关无关——实心/软边都只在区域内生成。软边额外借它把离屏缓冲缩到区域 AABB。
## 场景中 0 个启用的本节点 → 全屏幕有效，行为与无区域版本逐像素一致。
## 多个区域 → 各自独立求交后叠加（并集语义；区域重叠处阴影会双倍变暗，应避免重叠）。
##
## 可视化设计：生产语义 = 零绘制（editor_only=true，编辑器里原生绿框可见即可）。
## 仅当 debug_preview=true（测试场景生成器模板会设置）才在运行时自绘边框+淡填充。
## 注意：ReferenceRect 的原生绘制在 _notification 里、**不存在 _draw 虚方法**，
##       子类的 _draw() 里不得调用 super._draw()（会每帧 Invalid call）。

const GROUP := &"shadow_region"

@export var enabled := true:
	set(v):
		enabled = v
		if not Engine.is_editor_hint() and is_node_ready():
			_set_group(v)

## 运行时可视化（调试用）。正式关卡保持 false = 游戏内零绘制。
@export var debug_preview := false:
	set(v):
		debug_preview = v
		queue_redraw()

var _drawn := 0

func _ready() -> void:
	if Engine.is_editor_hint():
		# 编辑器：原生边框即可见；关闭处理避免编辑器里误触发 T 键改场景数据
		QuiverEditorHelper.disable_all_processing(self)
		border_color = Color(0.2, 0.9, 0.4, 0.8)
		return
	_set_group(enabled)
	if debug_preview:
		print("[ShadowRegion] ready rect=", get_global_rect())

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("shadow_region_toggle"):
		enabled = not enabled
		print("[ShadowRegion] enabled=", enabled)

func _draw() -> void:
	if not debug_preview or Engine.is_editor_hint():
		return
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.1, 1.0, 0.25, 0.10), true)
	draw_rect(r, Color(0.1, 1.0, 0.25, 0.95), false, 3.0)
	_drawn += 1
	if _drawn <= 2:
		print("[ShadowRegion] draw #", _drawn, " size=", size)

func _set_group(on: bool) -> void:
	if on:
		add_to_group(GROUP)
	else:
		remove_from_group(GROUP)

## 世界空间区域多边形；尺寸无效时返回空（视为不存在）
func world_polygon() -> PackedVector2Array:
	var r := world_rect()
	if r.size.x <= 0.0:
		return PackedVector2Array()
	return PackedVector2Array([
		r.position,
		Vector2(r.end.x, r.position.y),
		r.end,
		Vector2(r.position.x, r.end.y),
	])

## 世界空间区域矩形（合成器缩缓冲用）；无效时返回空 Rect2
func world_rect() -> Rect2:
	var r := get_global_rect().abs()
	if r.size.x < 2.0 or r.size.y < 2.0:
		return Rect2()
	return r
