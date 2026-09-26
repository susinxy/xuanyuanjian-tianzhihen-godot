# S2-B4.7 命中反馈专题实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 普通命中从"全局定格"升级为"命中者自慢放（逐角色档案、按动画长度百分比）+ 接触点零美术程序化特效（可 F8 热开关）"，弹反定格改"攻击者罚站、防守方自由"。

**Architecture:** 单角色时间控制原语（HitFreeze autoload 扩展：协程+代数令牌，表在宿主不在被慢者）+ 攻击盒出生时下发 `attacker` 引用（弹体天生无下发=结构性排除慢放）+ `Events.hit_landed` 信号总线 → 游戏侧 HitFx autoload 消费出特效。法源 spec：`docs/superpowers/specs/2026-09-26-s2-b47-hit-feedback-design.md`（裁决 R1-R5 全部在册，冲突时以 spec 为准）。

**Tech Stack:** Godot 4.7.1 / GDScript；测试=场景 runner 契约（tools/ 惯例）+ headless `-s` 探针（场景 runner 形制，判例：`-s` 里 add_child 即断言=假现场）。

## Global Constraints

- **插件改动必须同 commit 更新 `docs/PLUGIN_ARCHITECTURE.md`**（AGENTS 铁律）；非 git 侧同步记 `PLUGIN_CHANGES.md`（仓库根，直接编辑文件，不入 commit）。
- **git 逐路径点名，禁 `git add -A`**；用户 WIP（`scenes/stages/xuanyuan-chapter-1/**`、`spells/fire_ball/fire_ball_skin.tscn`、untracked dll 幽灵）不碰不提交。
- 全部注释中文；`.tscn/.tres` 手写守则（load_steps=资源数、`&"..."` 键、复合属性完整构造式、UID 唯一或不写）。
- **project.godot 是同步点**：T3 要写 `[autoload] HitFx` 与 `[input] hit_fx_toggle`——动手前须用户口令"关了"（编辑器回写吞改判例）；T1/T2 不碰 project.godot。
- **测试主权**：契约角色一律 TestActorKit（`test_actor`），单跑前先 `bash tools/matrix_runner/run_matrix.sh --ensure-only`；套件首行落盘重定向 `SaveSystem.slot_path` → `user://b47_hf_scratch.json`（五套在册判例）。
- 长 godot 进程一律 `setsid nohup godot ... > log 2>&1 < /dev/null &` + 轮询。
- chen `characters/playable/*` 不入 git；本批**不需要改 chen 任何 tres**（新字段默认值即生效，零迁移——与 B4.6"全局横拳"同理）。
- 协程静默报错=永久慢：H 流"窗口毕恢复"断言是本体防线；引擎 API 零信任=T0 探针先行。

---

### Task 0: 引擎探针（P1-P5）——定实现通道，纯 headless 零口令

**Files:**
- Create: `/tmp/opencode/b47_t0/probe.tscn` + `/tmp/opencode/b47_t0/probe.gd`（一次性，不入仓）
- Create: `/tmp/opencode/b47_t0/report.md`（裁决记录，不入仓）

**Interfaces:**
- Produces: 主/备通道选型结论（T1 的 `_set_tree_custom_speed` 实现形态、T1 动画长度取数路径）

- [ ] **Step 1: 写探针场景**（正常 runner 形制：`_ready` + `await get_tree().physics_frame`，判例库条款）。构建：`CharacterBody2D`（速度 (200,0) + `move_and_slide`）+ 子节点 `AnimationPlayer`（一条 1s 非循环动画 `A`，method 键在 0.9s 记时刻）+ 独立计数子 Node（`_physics_process` 回报 received delta）+ 独立 `AnimationTree`（ Animation 输出指向 A，验证树通路也验一遍）。宿主脚本对 body 设 `process_custom_speed`。

- [ ] **Step 2: 测五问**，每项打印 PASS/FAIL 事实行：
  - **P1** `process_custom_speed = 0.0/0.2` 对 `_physics_process` 是否生效：看计数子节点收到的 delta（子节点不设 custom_speed 时是否被父级带慢 → 顺带答 **P2 级联与否**）；看 `move_and_slide` 位移率（0.2 时每秒应 ~40px）。
  - **P3** AnimationPlayer 动画时钟：0.2 速下 method 键到达拍（约 45 物理拍）与 1.0 速（~54 拍=0.9s）对比，判定动画是否随 custom_speed 慢（若不随：T1 需同时设 `player.speed_scale`）。
  - **P4** `get_tree().paused=true` 且调度协程 `await physics_frame` 是否照续火（block_parry 判例复验：应照响）。
  - **P5** 攻击动画长度取数：`AnimationPlayer.get_current_animation()` 于 `play("A")` 后返回名 + `lib.get_animation(name).length` 可读（T1 的 `current_anim_length_ms()` 依此实现）。
- [ ] **Step 3: 跑**：`setsid nohup godot --headless --path /home/susinxy/code/games/xuanyuan/xuanyuan-sword res://../../tmp 场景不可用——改用 --path + --scene 直跑绝对路径场景 > /tmp/opencode/b47_t0/probe.log 2>&1 &`，读 log。
- [ ] **Step 4: 写 report.md 裁决**：默认预期=P1 生效/P2 不级联（则 `_set_tree_custom_speed` 递归目标+全部子 Node）/P3 不随（则动画通道加设 `speed_scale`）/P4 照响/P5 可得。**若 P1 全红**（custom_speed 对 physics 无效）：启用备胎通道——`AnimationPlayer.speed_scale` + 位移缩放（`velocity *= _slow_scale` 侵入 locomotion），此时 T1 的接口与契约行为断言不变，实现细节按 report 裁决走。
- [ ] **Step 5: 无 commit**（探针不入仓），report 贴批次报告。

---

### Task 1: 原语+普通命中——数值域三字段 / HitFreeze 单角色扩展 / 近战自慢放 / 全局定格归零（R1+R3）

**Files:**
- Modify: `addons/quiver.beat_em_up/characters/quiver_attributes.gd`（受管导出区，仿 `knockout_resistance_max` 摆放）
- Modify: `addons/quiver.beat_em_up/utilities/helpers/autoload/hit_freeze/hit_freeze.gd`（+调度器）与 `hit_freeze.tscn`（`freeze_frames = 0`）
- Modify: `addons/quiver.beat_em_up/combat/collision_areas/quiver_hit_box.gd`（+`var attacker`）
- Modify: `addons/quiver.beat_em_up/characters/quiver_character.gd:171`（收集处 stamp）
- Modify: `addons/quiver.beat_em_up/characters/quiver_character_skin.gd`（+`current_anim_length_ms()`）
- Modify: `addons/quiver.beat_em_up/combat/collision_areas/quiver_hurt_box.gd`（常规支尾钩子）
- Create: `tools/hit_feedback_contract/hit_feedback_contract.tscn/.gd`（H/S 流首版）
- Modify: `docs/PLUGIN_ARCHITECTURE.md`（同 commit）

**Interfaces:**
- Consumes: Task 0 通道裁决
- Produces: `HitFreeze.apply_character_slow(target: Node, rate: float, duration_ms: float)`（rate≥1 或 ms≤0 = no-op；重入覆盖）；`QuiverAttributes.hit_slow_factor: float(0.2) / hit_slow_anim_pct: float(0.15) / parry_stun_frames: int(6)`；`QuiverHitBox.attacker: QuiverCharacter`（近战=角色，弹体=null）；`QuiverCharacter.attack_anim_length_ms() -> float`（门面，不可得=-1.0）

- [ ] **Step 1: attributes 三字段**（数值域；档案配置非运行时态，`reset()` **不清**——B4.6 `attack_axis_mode` 同族注例）：

```gdscript
## 命中自慢放倍率（B4.7 攻击者数值域）：近战命中瞬间自己按此倍速慢放；
## 1.0=自然不慢（零禁用旗）。恢复窗口时长见 hit_slow_anim_pct。
@export_range(0.0, 1.0, 0.05) var hit_slow_factor: float = 0.2
## 慢放窗口=本次攻击动画总长×此比例：跨招节奏扰动恒为 pct×(1-factor)，
## 快拳/重击咬合深度均匀（绝对 ms 制会让快拳扰动 4 倍于重击）。
@export_range(0.0, 1.0, 0.01) var hit_slow_anim_pct: float = 0.15
## 弹反定格帧数（防守方数值域，B4.7 自 _PARRY_FREEZE_FRAMES 魔数升格；
## 消费点在 T2 弹反改道，T1 仅落字段）。
@export_range(0, 60, 1) var parry_stun_frames: int = 6
```

- [ ] **Step 2: HitFreeze 扩展**（现文件头保留，成员区追加；`freeze_frames` 默认 3→**0** 且 tscn 属性行写 0，双保险）：

```gdscript
## 单角色慢放/定格调度（B4.7）：协程+代数令牌。每次请求=一条独立协程，
## 恢复计时表挂宿主（本 autoload，PAUSE_ALWAYS、满速）——绝不挂被慢者
## 自己的表（慢放越慢越出不来的经典大坑）。同目标重入：请求号+1，旧协程
## 醒来令牌不符即静默让位。目标中途释放：is_instance_valid 守卫+条目自清。
var _generations: Dictionary = {}

func apply_character_slow(target: Node, rate: float, duration_ms: float) -> void:
	if target == null or rate >= 1.0 or duration_ms <= 0.0:
		return
	var fps := Engine.get_physics_ticks_per_second()
	var frames := maxi(1, int(round(duration_ms * fps / 1000.0)))
	_set_tree_custom_speed(target, rate)
	var id := target.get_instance_id()
	_generations[id] = int(_generations.get(id, 0)) + 1
	_run_slow(target, id, _generations[id], frames)

func _run_slow(target: Node, id: int, gen: int, frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame
	if int(_generations.get(id, -1)) != gen:
		return
	_generations.erase(id)
	if is_instance_valid(target):
		_set_tree_custom_speed(target, 1.0)

func _set_tree_custom_speed(target: Node, rate: float) -> void:
	# 形态按 T0 report 裁决：不级联则递归（含目标本体）；
	# 动画不随速则递归内对 AnimationPlayer 同设 speed_scale=rate。
	target.process_custom_speed = rate
	for n in target.find_children("*", "Node", true):
		(n as Node).process_custom_speed = rate
```

- [ ] **Step 3: attacker 下发链**：QuiverHitBox 成员区 `var attacker: QuiverCharacter = null`（运行时下发非导出，同 character_attributes 形制）；quiver_character.gd :171 收集循环改：

```gdscript
		_hitboxes = _skin.hitboxes
		for hb in _hitboxes:
			hb.attacker = self   # B4.7：弹体皮肤不走此路，attacker 恒 null
```

skin 的 `current_anim_length_ms()`：经 P5 探明的 AnimationPlayer 路径 `get_current_animation()` → `anim_library.get_animation(name).length * 1000.0`，取不到返回 `-1.0`（调用方兜底）。QuiverCharacter 加公共门面（`_skin` 私有，跨类不得裸戳）：`func attack_anim_length_ms() -> float: return _skin.current_anim_length_ms() if _skin else -1.0`。

- [ ] **Step 4: HurtBox 常规支挂点**（`_handle_hit_box` else 常规支 `apply_knockback(...)` 之后、命中回执之前）：

```gdscript
		# —— B4.7 命中时间反馈：近战命中者自慢放（弹体 attacker=null 结构性
		# 排除，绝不慢施法者）；窗口=本次攻击动画长×档案 pct，取不到动画长
		# 兜底 500ms×pct 并 push_warning 一次。
		if hit_box.attacker != null:
			var anim_ms := hit_box.attacker.attack_anim_length_ms()
			if anim_ms < 0.0:
				push_warning("B4.7: 攻击动画长度不可得，慢放窗口走兜底 500ms")
				anim_ms = 500.0
			HitFreeze.apply_character_slow(
					hit_box.attacker, atk_attrs.hit_slow_factor,
					anim_ms * atk_attrs.hit_slow_anim_pct)
```

（`atk_attrs` 即函数头部既有的 `hit_box.character_attributes` 局部量；attacker 非空时其 attributes 归属成立。）

- [ ] **Step 5: 契约首版**（仿 `tools/block_parry_contract/` 的 runner 形制与 actor 装配，执行前先读它）：断言——
  - **S1** 普通命中当帧及后续帧 `not get_tree().paused`（R1 归零行为锁）；
  - **H1** 近战命中后 1 拍内攻击者 `process_custom_speed < 1.0`；
  - **H2** 窗口毕（按动画长×0.15 折算拍数 +3 裕量）`== 1.0` 恢复；
  - **H3** 挥空（无目标出全招）全程 `== 1.0` 不触发；
  - **H4** 合成弹体形制命中（手建 hit_box **不做 attacker stamp**=弹体结构语义）→ 无人被慢放；
  - **H5** 双向：敌人命中玩家→敌人被慢；
  - **H6** 慢放不破连段：首拳命中触发慢放后，三连段仍完整衔接至终结收招（spec §2.3 节奏均匀性的行为锁）；
  - 行为级副锁：慢放期攻击者动画位置推进率显著低于满速对照（防主通道属性断言独证）。
  协程独立完成旗+汇总前 `_check(_finished, ...)` 判例形制照抄。
- [ ] **Step 6: 跑**：`--ensure-only` 建替身后单跑 `hit_feedback_contract`（setsid，全绿）。既有回归只受定格归零影响面=block_parry（弹反支显式 start(6) 不受 freeze_frames 影响，**格挡支走 apply_damage_value→start() 拿 0=定格消失**——跑 block_parry 确认其格挡腿是否断言了暂停；若红，那是合法改判，红因记报告，T2 一并手术）。
- [ ] **Step 7: 文档+提交**：PLUGIN_ARCHITECTURE 增"B4.7 单角色时间控制"节（HitFreeze 新方法/三字段/attacker 下发链/归零裁决）；PLUGIN_CHANGES 记条目。

```bash
git add addons/quiver.beat_em_up/characters/quiver_attributes.gd \
  addons/quiver.beat_em_up/utilities/helpers/autoload/hit_freeze/ \
  addons/quiver.beat_em_up/combat/collision_areas/quiver_hit_box.gd \
  addons/quiver.beat_em_up/combat/collision_areas/quiver_hurt_box.gd \
  addons/quiver.beat_em_up/characters/quiver_character.gd \
  addons/quiver.beat_em_up/characters/quiver_character_skin.gd \
  tools/hit_feedback_contract/ docs/PLUGIN_ARCHITECTURE.md
git commit -m "feat: B4.7 单角色慢放原语落地——HitFreeze 协程+令牌调度、attributes 命中数值域三字段、近战自慢放挂点（弹体 attacker=null 结构排除）、全局定格归零（R1/R3）"
```

---

### Task 2: 弹反改道——"敌罚站我自由"（R2）+ block_parry 契约手术

**Files:**
- Modify: `addons/quiver.beat_em_up/combat/collision_areas/quiver_hurt_box.gd`（弹反支换道，删 `HitFreeze.start(_PARRY_FREEZE_FRAMES)` 与魔数常量）
- Modify: `tools/block_parry_contract/block_parry_contract.gd`（定格腿断言改写；T1 遗留的格挡支暂停断言若红一并改判）
- Modify: `tools/hit_feedback_contract/`（+P 流）
- Modify: `docs/PLUGIN_ARCHITECTURE.md`（弹反节勘误：B3"全局 6 帧"→"单角色定格，用户澄清 2026-09-26"）

**Interfaces:**
- Consumes: `apply_character_slow`、`parry_stun_frames`
- Produces: P 流契约断言组

- [ ] **Step 1: 弹反支改道**（原 :216 一行 `HitFreeze.start(_PARRY_FREEZE_FRAMES)` 替换为）：

```gdscript
			# —— 弹反支：…（原注释保留，定格语义改单角色，B4.7 R2）——
			# 定格只罚被弹反的攻击者（防守方数值域 parry_stun_frames），
			# 玩家全程可动=奖励窗口成立；白闪双档与顶退派发照旧。
			if hit_box.attacker != null:
				HitFreeze.apply_character_slow(
						hit_box.attacker, 0.0,
						defender_attrs.parry_stun_frames * 1000.0
						/ Engine.get_physics_ticks_per_second())
```

- [ ] **Step 2: 攻击者角色节点取用**：弹反支内攻击者未必走 `hit_box.attacker`（弹体也能被弹反吗——现行弹反判定近战语义，但 `hit_box.attacker` 恒可用面更干净）：**用 `hit_box.attacker`**，null 时跳定格仅保留其余反馈（兜底不崩，弹体弹反=无罚站，spec 无此内容，防御性写明）。
- [ ] **Step 3: P 流断言**（hit_feedback_contract）：弹反成功当帧起——**P1** `not tree.paused` 连续观察至窗口毕；**P2** 攻击者 `process_custom_speed == 0.0` 且其动画位置两拍采样相等（罚站实证）；**P3** 防守方玩家位移/换态活跃（注入方向键后位置变化）；**P4** 冻结毕攻击者受击动画完整播完（信标链不死，spec §5 风险 2 的锁）。
- [ ] **Step 4: block_parry 手术**：`paused_seen` 采集族与 `_drain_freeze()` 相关断言改判（"世界暂停"→"攻击者被冻"）；改动区带中文注记勘误理由。
- [ ] **Step 5: 跑** hit_feedback + block_parry 两套全绿；stage_contract/spell_save 快跑确认无涟漪。
- [ ] **Step 6: 提交**（PLUGIN_CHANGES 同步）：

```bash
git add addons/quiver.beat_em_up/combat/collision_areas/quiver_hurt_box.gd \
  tools/block_parry_contract/ tools/hit_feedback_contract/ \
  docs/PLUGIN_ARCHITECTURE.md docs/superpowers/specs/2026-09-23-s2-b3-block-parry-design.md
git commit -m "feat: 弹反定格改道单角色——敌罚站我自由（B4.7 R2），block_parry 契约同步手术，B3 spec 勘误（当时实现=全局，用户澄清原意=单角色）"
```

（勘误写法：B3 spec 文件头追加"后续修订"节，不改正文历史。）

---

### Task 3: 接触点特效+F8 开关（R4/R5）——含 project.godot 口令同步点

**前置：向用户取"关了"口令**（本任务写 project.godot `[autoload]`+`[input]` 两处）。

**Files:**
- Modify: `addons/quiver.beat_em_up/utilities/helpers/autoload/quiver_events.gd`（+signal）
- Modify: HurtBox 挂点（emit hit_landed）
- Create: `scripts/effects/hit_fx.gd`、`scripts/effects/hit_spark_fx.gd`、`scripts/effects/hit_spark_preset.gd`、`scripts/effects/presets/spark_default.tres`、`spark_heavy.tres`、`spark_fire.tres`
- Modify: `project.godot`（两节）、`spells/fire_ball/resources/*attack*.tres`（`hit_effect_style = &"fire"`）、`characters/playable/chen/resources/attacks/punch3*.tres`+`templates/character/attacks/` 同名卡（heavy 风格，chen 侧先 tar 备份判例）
- Create/Modify: `tools/hit_feedback_contract/`（E/K 流）
- Modify: `tools/matrix_runner/run_matrix.sh`（25 套=26 跑+ATTEST）
- Modify: `docs/PLUGIN_ARCHITECTURE.md`、PLUGIN_CHANGES

**Interfaces:**
- Consumes: T1 挂点
- Produces: `Events.hit_landed(point: Vector2, style: StringName, strength: float, dir: Vector2)`；`QuiverAttackData.hit_effect_style: StringName = &"default"`；`HitFx`（autoload，`enabled: bool` 运行时可翻）

- [ ] **Step 1: 信号与字段**：Events `+signal hit_landed(...)`；`quiver_attack_data.gd` `@export var hit_effect_style: StringName = &"default"`（路由旗零数值推导，合法形制注例）。HurtBox T1 钩子旁追加（近战+弹体一视同仁）：

```gdscript
		Events.hit_landed.emit(
				(hit_box.global_position + global_position) * 0.5,
				hit_box.attack_data.hit_effect_style,
				hit_box.attack_data.knock_strength,
				(global_position - hit_box.global_position).normalized())
```

- [ ] **Step 2: 特效本体（零美术两层）**——`hit_fx.gd`（autoload）：`_ready` 连 Events 信号；`_process` 查 `Input.is_action_just_pressed("hit_fx_toggle")` 翻 `enabled`（shadow_region.gd:43 判例形制）；回调 `enabled` 早退，否则实例化 fx（`z_index = 20`，背景 z=5/Level z=15 夹层的判例规避）、`configure(preset, dir)` 后挂 `get_tree().current_scene`。`hit_spark_fx.gd extends Node2D`：子节点 `CPUParticles2D`（**不设 texture=无贴图方块**；`one_shot=true`；`direction=dir` 旋转；`explosiveness=1.0`；`gravity`/`amount`/`lifetime` 取参数卡；`color_ramp`=运行时构造 `Gradient`（热色→冷色，零文件））+ `Polygon2D`（`_ready` 16 顶点程序圆，r=6）+ Tween：flash scale 0.3→1.2 / alpha 1→0（0.08s）+ 粒子后 `await lifetime` → `queue_free()`。参数卡类 `hit_spark_preset.gd`：`@export amount:int=10, color_hot/color_cool:Color, speed_min/max, gravity:Vector2, lifetime, flash_scale:float, flash_color:Color`。三张 tres 手写（default=白→浅金小散角；heavy=18 粒金→橙大散角大闪光；fire=橙红+`gravity = Vector2(0, -220)` 上浮）。
- [ ] **Step 3: project.godot**（口令后）：`[autoload]` 追加 `HitFx="*res://scripts/effects/hit_fx.gd"`；`[input]` 追加 `hit_fx_toggle`（physical_keycode 4194339=F8）。改完 `git diff project.godot` 机检自证。
- [ ] **Step 4: 调试坞状态行**：HitFx `_ready` 内按 `ui/debug_dock.gd` 的 `add_text_tab(标题, 行生产者)` 注册"命中反馈"页（生产一行 `命中特效：%s（F8 切换）"`；dock 缺失时防御跳过）。
- [ ] **Step 5: 风格配置**：fire_ball 弹体攻击 tres +`hit_effect_style = &"fire"`；chen punch3 与模板 `__NAME__` punch3 卡 `&"heavy"`（chen 侧操作前 tar 备份判例）。
- [ ] **Step 6: E/K 流契约**：E1 命中后 current_scene 出现特效节点且距接触点 <40px；E2 生命周期毕计数归零（自动清理）；E3 弹体命中同样出生；E4 挥空零出生；E5 风格路由（fire 弹体消费 fire 卡——参数断言经由节点属性）。K1 raw F8 直投（`InputEventKey` keycode+physical 双填、pressed 显式，判例）→ `enabled` 翻转；K2 关闭态命中：零特效节点**但慢放照常**（双腿独立锁）。
- [ ] **Step 7: R8 入册体检**（红据落 `/tmp/opencode/b47_t3/`）：①注释 T1 慢放钩子→H1 红；②注释 hit_landed 连接→E1 红；③freeze_frames 改回 3→S1 红；④摘 F8 判定→K1 红。复原全绿后挂进 `run_matrix.sh`（25 套=26 跑，ATTEST 表登记）。
- [ ] **Step 8: 提交**：

```bash
git add addons/quiver.beat_em_up/utilities/helpers/autoload/quiver_events.gd \
  addons/quiver.beat_em_up/combat/quiver_attack_data.gd \
  addons/quiver.beat_em_up/combat/collision_areas/quiver_hurt_box.gd \
  scripts/effects/ project.godot \
  spells/fire_ball/resources/ templates/character/attacks/ \
  tools/hit_feedback_contract/ tools/matrix_runner/run_matrix.sh \
  docs/PLUGIN_ARCHITECTURE.md
git commit -m "feat: B4.7 接触点程序化特效+F8 运行时开关——Events.hit_landed 信号、HitFx 双层零美术特效（参数卡分风格）、调试坞状态行，hit_feedback 契约入册 25 套=26 跑（R8 四档红据）"
```

---

### Task 4: 文档收口 + F5 合并单

**Files:**
- Modify: `DEVELOPMENT_STATUS.md`、`docs/PLUGIN_ARCHITECTURE.md`（查漏）、PLUGIN_CHANGES
- Create: `docs/superpowers/plans/2026-09-26-s2-b47-hit-feedback-f5.md`

- [ ] **Step 1: F5 合并单**（**并窗 B4.6 三眼欠账**，一次编辑器会话跑完）：①普通命中——手感"咬一下"但连段不断（慢放观感），F8 开关往返，火花出现与自动消失；②弹反——敌罚站我自由（白闪/顶退/受击动画照旧，世界不再卡）；③弹体命中——有火花无慢放；④格挡——确认归零后格挡手感无异常；⑤B4.6 眼①②③原文照录。场地=stage_ref_a（chen+spar 真打）。
- [ ] **Step 2: 全矩阵批终核**：`bash tools/matrix_runner/run_matrix.sh`（26 跑 RED=0），快照贴报告。
- [ ] **Step 3: 状态单+提交**：

```bash
git add DEVELOPMENT_STATUS.md docs/PLUGIN_ARCHITECTURE.md \
  docs/superpowers/plans/2026-09-26-s2-b47-hit-feedback-f5.md
git commit -m "docs: B4.7 收口——状态单、架构册查漏、F5 合并单（并 B4.6 三眼欠账一次会话跑完）" && git tag s2-b47-done && git push origin main --tags
```

---

## 默认已裁清单（本计划内，按口味级直接定案）

1. 调度器宿主=**扩展插件侧 HitFreeze autoload**（同域+零新注册触点+PAUSE_ALWAYS 就位；spec §2.2"宿主位置"留白的落锤）；
2. 弹体排除慢放=**attacker 下发结构**（弹体皮肤不走角色收集链，null 即排除；比新增 is_projectile 旗更防呆）；
3. 接触点=两盒中点；特效挂 current_scene + z_index=20；
4. F8 physical keycode 4194339，动作名 `hit_fx_toggle`；
5. 动画长不可得兜底=500ms + push_warning（spec §2.3 兜底条款落地值）；
6. `parry_stun_frames` 升格按采纳走（用户未否决）。
