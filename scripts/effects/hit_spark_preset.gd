class_name HitSparkPreset
extends Resource

## 接触点火花参数卡（B4.7 R4，spec §3.4）：一张卡=一种"手感语言"。
## 全部是纯描述参数——数值治理法第 2 档（单一出处=卡本体 tres），消费方
## （HitSparkFx）只搬运不推导；风格路由由 QuiverAttackData.hit_effect_style
## 声明（合法路由旗）。色带不入库（LDR 判例族：贴图通道件零美术），
## 由消费方按 color_hot/color_cool 运行时构造 Gradient（T3 探针：本构建
## CPUParticles2D.color_ramp 收裸 Gradient，CurveTexture/贴图通道件拒收）。

#--- public variables - order: export > normal var > onready --------------------------------------

@export var amount: int = 10
## 喷散布角（度，锥半角；T5 观感升级新增——针形拖尾沿击向散开的扇形宽度）
@export_range(1.0, 180.0, 1.0) var spread_deg: float = 34.0
## 粒子出生色（热）
@export var color_hot: Color = Color(1, 1, 1, 1)
## 粒子死亡色（冷，alpha 通常归 0 完成淡出）
@export var color_cool: Color = Color(1, 0.87, 0.55, 0)
## 初速下限/上限（随机均匀）
@export var speed_min: float = 60.0
@export var speed_max: float = 180.0
## 粒子重力（fire 卡用负 y 做火星上浮）
@export var gravity: Vector2 = Vector2(0, 300)
## 粒子寿命（秒）；本件总生命周期=max(此值, 闪光时长)
@export var lifetime: float = 0.35
## 闪光半径乘数（heavy 大闪光/默认小闪光的唯一差异位）
@export var flash_scale: float = 1.0
## 闪光色（alpha 由消费方跑 1→0 衰减）
@export var flash_color: Color = Color(1, 1, 1, 1)
