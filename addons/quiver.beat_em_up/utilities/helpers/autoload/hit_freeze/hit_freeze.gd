extends Node

## 命中反馈的时间控制中枢：全局定格（freeze_frames，B4.7 起默认 0=退役，
## 机制保留一个数即可复活）+ 单角色慢放/定格调度（apply_character_slow，
## 协程+代数令牌；通道由皮肤门面封装=树驱动皮肤走 AnimationNodeTimeScale、
## 直驱皮肤走 player.speed_scale，判例链见 docs/PLUGIN_ARCHITECTURE.md §17）。

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

## 全局定格帧数（R1 裁决 2026-09-26）：3→0 退役——普通/格挡伤害流从此
## 不停世界（start() 对 0 天然安全）；弹反支旧显式 start(6) 已于 T2 改道
## 单角色定格（apply_character_slow + 防守方数值域 parry_stun_frames），
## 本 autoload 现无任何全局定格的在途调用方。
@export_range(0, 60, 1, "or_greater" ) var freeze_frames := 0

#--- private variables - order: export > normal var > onready -------------------------------------

var _frames_to_wait := 0

## 单角色慢放的代数令牌表（B4.7）：{被慢者实例 id → 请求号}。
## 新请求号 +1 并开窗；旧协程醒来发现令牌不符即静默让位（绝不抢新协程的
## 恢复笔）。条目由协程尾清除；目标中途释放同样协程尾弃笔。
var _slow_generations: Dictionary = {}

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	_frames_to_wait -= 1
#	print("frames_to_wait: %s"%[_frames_to_wait])
	if _frames_to_wait <= 0:
		get_tree().paused = false
		set_physics_process(false)

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func start(custom_wait := INF) -> void:
	_frames_to_wait = freeze_frames if custom_wait == INF else custom_wait
	if _frames_to_wait > 0:
		get_tree().paused = true
		set_physics_process(true)


## 单角色动画慢放/定格（B4.7 R2/R3 共用原语；rate=0 即定格，~0.2 即慢放）：
## · 通道经皮肤门面路由（本构建无 process_custom_speed，T0 探针 P0）：
##   树驱动皮肤=树内 AnimationNodeTimeScale 参数（正解，T1 probe4 真皮肤实锤
##   player.speed_scale 档不通电），直驱皮肤=player.speed_scale 备胎；
##   判例链见 PLUGIN_ARCHITECTURE §17.1。物理位移通道本期不做——近战双方
##   攻击态锁移动+受击不位移设计基线，若 F5 判"脚滑"再回炉加位移通道；
## · 每次请求=一条独立协程（宿主=本 autoload，PAUSE_ALWAYS、满速）——
##   恢复计时表绝不挂被慢者自己的表（慢放越慢越出不来的经典大坑）；
##   physics_frame"暂停期照响、帧号照走"是 block_parry/Step0 探针实证判例；
## · 重入=代数令牌（见 _slow_generations）；目标中途释放=is_instance_valid
##   守卫弃笔；
## · rate≥1 或 duration_ms≤0 → no-op（1.0=自然不慢的零禁用旗语义在调用侧
##   天然短路）；rate 合法域 [0,1]，越界负值按 0（定格）保守处理。
func apply_character_slow(char: QuiverCharacter, rate: float, duration_ms: float) -> void:
	if char == null or not is_instance_valid(char):
		return
	if rate >= 1.0 or duration_ms <= 0.0:
		return
	var effective_rate := maxf(0.0, rate)
	var fps := Engine.get_physics_ticks_per_second()
	var frames := maxi(1, int(round(duration_ms * fps / 1000.0)))
	char.set_anim_time_scale(effective_rate)
	var id := char.get_instance_id()
	_slow_generations[id] = int(_slow_generations.get(id, 0)) + 1
	_run_slow(char, id, _slow_generations[id], frames)


### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

## 慢放协程本体：数 frames 个物理帧（表挂宿主，与满速者同拍），醒来先验
## 令牌再动笔——过期请求静默让位（新协程 owns 恢复笔）。协程半途报错=
## 目标永久慢（本仓库协程判例），防线=契约 H 流"命中→生效→恢复"闭环。
func _run_slow(char: QuiverCharacter, id: int, gen: int, frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame
	if int(_slow_generations.get(id, -1)) != gen:
		return
	_slow_generations.erase(id)
	if is_instance_valid(char):
		char.set_anim_time_scale(1.0)

### -----------------------------------------------------------------------------------------------
