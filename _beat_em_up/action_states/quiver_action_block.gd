@tool
class_name QuiverActionBlock
extends QuiverCharacterAction

## 地面格挡姿态（S2-B3 spec §2.2）：按住 block 即架盾站桩，松开回 Idle；
## 进出全由本状态的引擎 `_physics_process` 虚函数自选——引擎虚处理无论本状态
## "在场/不在场"都每帧跑（quiver_state 仅在编辑器 hint 下关处理，运行期虚拟
## 处理独立于 SM 派发，2026-09-23 实锤），零插件核心手术。
##
## 单写者纪律：`is_blocking`/`block_started_frame` 成对旗标的**唯一生产写方**
## 就是本状态的 enter/exit（判定缝只读）；成对写入与姿态起势同帧（R4 宪章）。
## HitFreeze 期间物理帧号照走 ⇒ 在途定格真会蚕食姿态窗口帧——这是 spec 定档
## 的既定语义（宪章详见 quiver_hurt_box.gd 常量注释），手感疑案先疑此勿疑缝。
##
## 受击/击飞/抓取打断继承 Ground 挂线（hurt_requested 全程武装）；本状态不
## 处理任何伤害——三分支判定在 QuiverHurtBox 缝（spec §2.3）。
## 进入白名单=三个 locomotion 状态（转移图=代码约定，AGENTS 状态机章口径）。

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

## 皮肤动画槽名（真防御动画到货=仅改此导出，同名替换纪律）
@export var _skin_state: StringName = &"idle"

## 松键回位路径
@export var _path_idle_state: NodePath = ^"Ground/Move/Idle"

## 进入白名单：仅这些状态（节点名）允许起架
@export var _entry_whitelist: Array[StringName] = [&"Idle", &"Walk", &"Run"]

## 父链三开关（Cast 形制同款 tscn 键名与值；本档不引入 custom inspector 机制）
@export var parent_should_enter := true
@export var parent_should_exit := true
@export var parent_should_process := true

#--- private variables - order: export > normal var > onready -------------------------------------

static var _warned_missing_anim: Dictionary = {}

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func enter(msg: = {}) -> void:
	super(msg)
	if parent_should_enter:
		get_parent().enter(msg)
	
	# 姿态期间关闭输入窗口（与施法/攻击 _can_combo=false 同语义）
	_state_machine.input_window_open = false
	_character.velocity = Vector2.ZERO
	
	# 成对旗标唯一生产写入点：与姿态起势同帧（R4 宪章，判定缝成对读取）
	_attributes.is_blocking = true
	_attributes.block_started_frame = Engine.get_physics_frames()
	
	if _skin.has_anim_state(_skin_state):
		_skin.transition_to(_skin_state)
	else:
		_warn_missing_once()


func unhandled_input(_event: InputEvent) -> void:
	# 姿态不消费任何事件（输入窗口已在 enter 关闭）
	pass


func physics_process(delta: float) -> void:
	if parent_should_process:
		get_parent().physics_process(delta)
	# 站桩钉死（Ground 链只跟 ground_level，本状态无 move_and_slide）
	_character.velocity = Vector2.ZERO


func exit() -> void:
	_attributes.is_blocking = false
	_state_machine.input_window_open = true
	
	super()
	if parent_should_exit:
		get_parent().exit()

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

## 引擎虚拟：在场管出（松键回 Idle），不在场管进（按住 + 白名单，白名单外禁入）。
## StringName 显式转换：sm.state.name 转回 StringName 再入白名单比较，
## 类型不匹配的裸 in 恒假（类型陷阱）。
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var sm := _state_machine
	# 建树早期 _character/channel/sm.state 均可能未就绪（owner.ready 链在路上）
	if sm == null or _character == null or _character.channel == null or sm.state == null:
		return
	if sm.state == self:
		if not _character.channel.is_held(&"block"):
			sm.transition_to(_path_idle_state)
	elif _character.channel.is_held(&"block") \
			and StringName(str(sm.state.name)) in _entry_whitelist:
		sm.transition_to(sm.get_path_to(self))


## 缺槽降级（Cast 阶梯同款精神）：只告警一次，姿态逻辑照常可用
func _warn_missing_once() -> void:
	var key := str(_skin.name) + ":" + str(_skin_state)
	if _warned_missing_anim.has(key):
		return
	_warned_missing_anim[key] = true
	push_warning("皮肤 %s 缺少格挡动画槽 %s，姿态保持当前姿势" % [_skin.name, _skin_state])

### -----------------------------------------------------------------------------------------------
