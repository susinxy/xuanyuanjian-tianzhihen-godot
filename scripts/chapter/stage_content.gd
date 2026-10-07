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
## 段申报·接管（2026-10 被控角色批，读法一严格申报制）：入场时壳先接管
## 本路径指认的角色（段树内解析）再落位；留空=回正壳初始被控者。跨段连控
## 需逐段申报（无幽灵延续，见 GUIDE_关卡搭建配方卡）。
@export_node_path("QuiverCharacter") var control_target_path := NodePath("")
## 段申报·相机宿主（同批复）：入场镜头挂本路径指认的段内 Node2D（拍 NPC/
## 物件演出）；留空=回正跟被控角色。运行时即席改挂走壳 set_camera_host()。
@export_node_path("Node2D") var camera_host_path := NodePath("")
## 段申报·终局锚点（锚点批；死亡演出批升级数组=多护送对象）：本段"剧情上
## 不能死的人"——其被击飞致死与**被控者之死同闸**（败北结算集=锚∪被控）。
## 空=改用壳全程申报（壳也空=仅被控者算败北，默认形态现状零漂移）。
@export var defeat_anchor_paths: Array[NodePath] = []
## 段申报·死亡慢放集（2026-10 死亡演出批 G2，独立于结算集的第二挂点）：
## "死了值得给一段慢镜头的人"。空=跟随结算集（现状两事件同角色）；非空=
## 只认申报成员（两功能正交：旁观者可只慢不结算，主角可只结算不慢）。
## 运行时增删走壳 add/remove_death_slowmo（临时态，换段被申报重刷）。
@export var death_slowmo_paths: Array[NodePath] = []


func entry_position(entry: StringName) -> Vector2:
	return entry_points.get(entry, entry_points.get(&"default", Vector2.ZERO))
