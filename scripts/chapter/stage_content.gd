class_name StageContent
extends Node2D

## 段内容件基类（S2-M1-B1）：一段的可玩空间=几何+三件套+背景（+可选光照子树）。
## 零壳件（spec §3.1）；生命周期归 ChapterShell（未清场丢弃重建/已清场缓存）。

@export var segment_id: StringName
## 命名入口 → 段内局部坐标；&"default" 必有（spec §3.2 C4：一律放检测线前场区）
@export var entry_points: Dictionary = {&"default": Vector2(500, 600)}
## 段入场画布色（光照复位责任归壳的输入，spec §3.4 C5）
@export var lighting_color: Color = Color.WHITE
## 非战斗段（过场/尾声）标记：进段即视为清场推进
@export var auto_complete := false


func entry_position(entry: StringName) -> Vector2:
	return entry_points.get(entry, entry_points.get(&"default", Vector2.ZERO))
