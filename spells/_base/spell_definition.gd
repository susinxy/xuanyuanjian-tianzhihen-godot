class_name SpellDefinition
extends Resource

@export var spell_id: StringName
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var spell_scene: PackedScene
@export var mana_cost: float = 0.0
@export var max_lifetime: float = 5.0
@export var cooldown: float = 0.0
@export var allowed_states: Array[StringName] = []
@export var disallowed_states: Array[StringName] = [&"Die", &"Knockout"]
## 引导时长（秒）：起手动画（槽 spell_start，角色资产、自然时长、必完整播放）结束后，
## 保持姿势循环（槽 spelling）倒数满本字段才释放法术体；实际总硬直=起手动画长+本值。
## 0 = 无引导段：起手势照播且必完整（尾帧信标到达即出手），2026-09-16 起废止
## 旧"无动作瞬发"语义（那是单一计时器时代的条款，与两段式契约冲突）。
@export var caster_cast_time: float = 0.0
## 出手点（法术自身数据，单位=施法者身体比例）：x=身宽倍数（朝向前自动取号），
## y=身高倍数（0=脚底，1=头顶）。默认 (1.0, 0.6)≈旧经验公式（半宽+30px、0.6 身高）。
## 由每个法术自定：贴地刺填 0.0、胸部火球约 0.55、头顶落雷 1.2。
@export var release_ratio: Vector2 = Vector2(1.0, 0.6)

## 淡入时长（秒）：弹体出生后 alpha 0→1 的渐亮窗口（_physics_process 倒计时驱动）。
## 淡入期间攻击盒碰撞层被门控为 0——物理意义上"不存在"，杜绝出生帧贴身秒杀。
## 0 = 不淡入（即时全亮，判定同帧开门）。
@export var fade_in_time: float = 0.12

## 淡出时长（秒）：命中/超时后弹体原地渐熄的窗口，熄完才真删；期间判定门同样关闭。
## 皮肤树里有 ending 告别动画时美术信标接管销毁，系统淡出让位（不双重谢幕）。
## 0 = 立删（旧行为）。淡入未毕即被打断时，淡出从当前亮度起算，不闪跳。
@export var fade_out_time: float = 0.2
