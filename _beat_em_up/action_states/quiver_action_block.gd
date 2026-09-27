@tool
class_name QuiverActionBlock
extends QuiverCharacterAction

## 地面格挡序列态（S2-B4.8 点按制）：按下 block 起序列
## block_out（弹反窗，相位=OUT）→〔未弹反〕block（持盾窗，GUARD）→ 回 Idle；
## 〔R12 弹反直返〕OUT 全程弹反成功 → block_out 余程放完（R8 不中断不裸奔）
## → OUT 信标到点**跳过 GUARD 直回 Idle**（弹成即自由=主动权奖励）。
## 不支持长按（评审 F3/裁决 D：起按边沿锁——序列收口后仍持键不起二段，
## 必须松开重按）、序列中再按无效（Block 不在白名单）。
## 转移图（spec §2.2）：Idle/Walk/Run/地面三连段 →（点按 K）→ 本态 →（信标/
## 兜底推进两段）→ Idle；序列全程不重定向（按下瞬间钉死盾面朝向）。
##
## 单写者宪章续命：`is_blocking`/`block_phase`/`block_facing` 三件套唯一生产
## 写方=本态 enter（同帧起笔，R4 宪章）/信标推进/exit 保证式清闸——
## hurt/knockout/grab 任何打断走同一出口（Ground 挂线继承，判定缝只读）。
## R12 案卷式扩展：`parried_this_sequence` 旗唯一置位方=HurtBox 弹反支，
## 唯一清除方=本态 enter/exit 括弧（与 reset()）——本态读旗于 OUT 推进口分叉。
##
## 兜底（缺动画槽的过渡期皮肤，spec §2.3）：OUT=12 拍/GUARD=30 拍自计数；
## 真动画到货以信标为准（占位资产帧长按同数制作——"动画即规则"的平滑桥）。
## 信标无参（skin_animation_finished 不带名，判例 quiver_character_skin.gd:21）：
## 序列每相位只播一段动画，相位自身即消歧器。
## ⚠ 兜底拍信标免疫（评审 F1）：进 Block 前在途攻击的末帧信标晚响会打中
## 本态推进器——`_beats_left>0` 即自计数专用拍，信标一律丢弃（真动画拍
## _beats_left 恒 0 照常受信标驱动；兜底时钟到点自调推进口时已清零，不误伤）。
## 回归锁=契约 P23a（出招取消起架后实测 OUT 窗宽 ∈[8,18]，腐蚀即穿帮——上缘 18
## 系收口波 M2 余量备案；腐蚀红恒在下缘 6 拍，判别力不损）。
##
## 引擎虚拟 _physics_process 自选进出（B3 判例续，PLUGIN_ARCHITECTURE §5.11）：
## 白名单含地面攻击态（R10 后摇可架）。⚠ 白名单以**节点名**比较（B3 形制），
## 本仓地面三连段实测名=Combo1/Combo2/Combo3——不能写 "Attack"：那是空中
## 跳攻节点的名字（Air/Jump/Attack），纳入即违反 spec §5"空中攻击后摇不可架"。
##
## 伤害结算不在本状态——方向门+相位三分支在 QuiverHurtBox 判定缝（spec §2.4）。

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

## 兜底帧数单一出处（spec §2.3）：无槽皮肤期 OUT 弹反窗 12 拍（≈200ms）、
## GUARD 持盾窗 30 拍（≈500ms）；真动画到货后由动画长接管（占位资产帧长
## 按同数制作），本对常量退居保险丝。
const _BLOCK_OUT_FALLBACK_BEATS := 12
const _BLOCK_HOLD_FALLBACK_BEATS := 30

#--- public variables - order: export > normal var > onready --------------------------------------

## 弹反段皮肤动画槽名（真资产=仅改此导出，同名替换纪律）
@export var _skin_state_out: StringName = &"block_out"

## 持盾段皮肤动画槽名
@export var _skin_state_hold: StringName = &"block"

## 序列毕回位路径
@export var _path_idle_state: NodePath = ^"Ground/Move/Idle"

## 进入白名单（R10）：locomotion 三态 + 地面三连段（攻击中/后摇可按 K 取消
## 进格挡）；节点名比较形制见文件头（空中 Attack/受击/击飞子树恒拒）。
@export var _entry_whitelist: Array[StringName] = [
		&"Idle", &"Walk", &"Run", &"Combo1", &"Combo2", &"Combo3"]

## 父链三开关（Cast 形制同款 tscn 键名与值；本档不引入 custom inspector 机制）
@export var parent_should_enter := true
@export var parent_should_exit := true
@export var parent_should_process := true

#--- private variables - order: export > normal var > onready -------------------------------------

var _beats_left := 0            # >0=兜底倒计时在用；0=信标驱动
var _warned_missing: bool = false
# 起按边沿锁（评审 F3/裁决 D，R1"不支持长按"）：进场只认"松→按"新边沿，
# 序列收口后仍持键不起二段（_armed=裁决 D 预留闸位，现恒真，语义由边沿判
# 承担；enter 不动 _armed——归一复位在松键拍）。
var _armed := true
var _was_held := false

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

	# 三件套唯一生产写入点：与姿态起势同帧（R4 宪章续命，判定缝成对读取）；
	# 盾面朝向取 facing_x 快照，x 平局归右（R6），序列期钉死不重定向
	_attributes.is_blocking = true
	# R12：开括弧清"已弹反"旗——上一序列弹没弹过不得泄漏到本序列
	_attributes.parried_this_sequence = false
	_attributes.block_phase = QuiverAttributes.BlockPhase.OUT
	var fx := 1.0 if _skin.facing_x >= 0.0 else -1.0
	_attributes.block_facing = Vector2(fx, 0.0)

	_play_slot(_skin_state_out, _BLOCK_OUT_FALLBACK_BEATS)


func exit() -> void:
	# 保证式清闸：正常收口与 hurt/knockout/grab 打断同口（单写者闭环）
	_attributes.is_blocking = false
	_attributes.block_phase = QuiverAttributes.BlockPhase.NONE
	_attributes.block_facing = Vector2.ZERO
	# R12：闭括弧清旗（正常收口与 hurt/knockout 异面穿盾打断同口）
	_attributes.parried_this_sequence = false
	_state_machine.input_window_open = true

	super()
	if parent_should_exit:
		get_parent().exit()


func unhandled_input(_event: InputEvent) -> void:
	# 序列不消费任何事件（输入窗口已在 enter 关闭）
	pass


func physics_process(delta: float) -> void:
	if parent_should_process:
		get_parent().physics_process(delta)
	# 站桩钉死（Ground 链只跟 ground_level，本状态无 move_and_slide）
	_character.velocity = Vector2.ZERO


### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _connect_signals() -> void:
	super()
	if _skin != null:
		QuiverEditorHelper.connect_between(
				_skin.skin_animation_finished, _on_skin_animation_finished)


func _disconnect_signals() -> void:
	super()
	if _skin != null:
		QuiverEditorHelper.disconnect_between(
				_skin.skin_animation_finished, _on_skin_animation_finished)


## 相位信标：任何一段播完按当前相位推进（信标无参——序列每相位只播一段
## 动画，相位自身即消歧器）；兜底时钟到点也走本口（两驱动共一推进器）
func _on_skin_animation_finished() -> void:
	if _attributes == null or not _attributes.is_blocking:
		return
	# F1（评审 Important-1）：兜底拍信标免疫——`_beats_left>0`=本相位走自计数
	# 时钟（缺槽过渡期），此时任何信标（含进 Block 前在途攻击的末帧晚响）
	# 一律丢弃，不得打中本态推进器腐蚀窗宽；兜底时钟到点自调本口时
	# _beats_left 已归零不误伤；真动画拍 _play_slot 成功 transition 恒置 0，
	# 照常受信标驱动（回归锁=契约 P23a）。
	if _beats_left > 0:
		return
	if _attributes.block_phase == QuiverAttributes.BlockPhase.OUT:
		# R12 弹反直返分叉（真槽信标与兜底自调共享本口）：本序列弹反成功
		# → 跳过 GUARD 段直回 Idle（block_out 已放完=R8 不裸奔语义保留）；
		# GUARD 段自此只属于"弹空者的保险"（未弹反才持盾）。
		if _attributes.parried_this_sequence:
			_state_machine.transition_to(_path_idle_state)
		else:
			_attributes.block_phase = QuiverAttributes.BlockPhase.GUARD
			_play_slot(_skin_state_hold, _BLOCK_HOLD_FALLBACK_BEATS)
	elif _attributes.block_phase == QuiverAttributes.BlockPhase.GUARD:
		_state_machine.transition_to(_path_idle_state)


## 皮肤播槽；缺槽→占位姿势+兜底计数（告警每实例一次，Cast 阶梯同款精神）
func _play_slot(slot: StringName, fallback_beats: int) -> void:
	_beats_left = 0
	if _skin.has_anim_state(slot):
		_skin.transition_to(slot)
	else:
		_beats_left = fallback_beats
		if not _warned_missing:
			_warned_missing = true
			push_warning("B4.8: 皮肤 %s 缺格挡动画槽，走兜底帧数时序" % _skin.name)


## 引擎虚拟：在场管兜底时钟（§5.11 判例续——本方法无论激活与否每物理拍跑），
## 不在场管进（**起按新边沿** + 白名单，白名单外禁入）。
## F3（评审裁决 D，R1"不支持长按"）：进场只认"松→按"边沿——序列收口后仍
## 持键不起二段，必须松开重按（旧 is_held 电平制=长按自动连架违语义，废止）。
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
		if _beats_left > 0:
			_beats_left -= 1
			if _beats_left == 0 and _attributes != null and _attributes.is_blocking:
				# 兜底时钟到点：手动走与信标同一推进口
				_on_skin_animation_finished()
		return
	var held := _character.channel.is_held(&"block")
	if not held:
		_armed = true
	if held and held != _was_held and _armed \
			and StringName(str(sm.state.name)) in _entry_whitelist:
		sm.transition_to(sm.get_path_to(self))
	_was_held = held

### -----------------------------------------------------------------------------------------------
