# S2-B3 盾反/格挡 + 修饰核心归一 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 玩家按住 K 架盾站桩（格挡减伤 / 6 物理帧弹反窗免伤顶硬），并把既有属性修饰器核心从"改值还原式"升级为"重算回写式"，护人态以两条修饰表达（模式旗标消亡）。

**Architecture:** 判定缝唯一插在 `QuiverHurtBox._handle_hit_box`（`_can_be_attacked_by` 通过后）；格挡姿态=自研动作状态（引擎 `_physics_process` 虚函数自选进出，零插件核心手术）；数值全走受管导出+修饰容器；反馈=modulate 过亮脉冲+HitFreeze 加强拍，零动画开销。

**Tech Stack:** Godot 4.7 GDScript；契约=场景 runner（lane 骨架血统）+ headless；`Engine.get_physics_frames()` 时基。

**Spec:** `docs/superpowers/specs/2026-09-23-s2-b3-block-parry-design.md`（判定表/时间轴/§5.2 手术规格/§10 改案是法源；冲突以 spec 为准）。

## Global Constraints

- GDScript 4；**注释一律中文**；提交 `feat:/fix:/docs:/test:` 中文；**逐路径点名 add，永久禁 `git add -A`**（用户 WIP：`project.godot`、`scenes/stages/xuanyuan-chapter-1/**`、`characters/playable/chen/**`——chen.tscn 属非 git 生产资产：**动前必须 tar 备份**，判例 2026-09-14）。
- **本批插件触点清单（评审红线，超出即上报）**：`quiver_attributes.gd`（修饰手术+五字段+reset 清账）、`quiver_hurt_box.gd`（判定缝）、`quiver_combat_system.gd`（apply_damage_value 入口+apply_damage 薄委托）。**除此之外 addons/ 零改动**；同批义务=`docs/PLUGIN_ARCHITECTURE.md` 同步 + 根 `PLUGIN_CHANGES.md` 案卷（非 git，落盘即算）。
- 基线哨兵：全矩阵在 T7 一跑 **23 套=24 跑**（22 存量+本批新套；validator 双模计 2 跑）；`locomotion` 的 `add_modifier/remove_modifier` 调用点 **一字不动**（API 稳定是本批宪法）。
- 数值三档归位（spec §4 数值治理法）：角色域=受管导出；规则常量=hurtbox/attributes 顶部 const 单一出处；**禁模式旗标**。受管字段单写者=只走修饰 API。
- 时基铁律：`delta = Engine.get_physics_frames() - block_started_frame`，弹反条件**严格 `delta < parry_window_frames`**。`HitFreeze.start(6)` 必须写在弹反分支（免伤路不经过 apply_damage=现行唯一生产定格调用点）。弹反/格挡分支**仍须执行** `hit_box.on_target_hit` 回执（穿体判例）。
- headless 判例全套：新 class_name 后 `--import` 一次；raw 键注入 `Input.parse_input_event`（physical 匹配、`is_action_pressed` 非 exact）；独立完成旗防静默跳段；轮询已释放预存 id；`.tscn` 无注释、`&"…"`、load_steps=ext+sub；`project.godot` 动前备份+告知 Windows 重启编辑器。
- `Engine.get_physics_frames()` 在 `tree.paused` 期间是否停走=**T4 Step 0 探针先行**（spec 风险 3），据实写 P3 的边界帧号（探针结论入代码注释）。

---

## 文件总图

| 动作 | 路径 | 责任 |
|---|---|---|
| Modify | `addons/quiver.beat_em_up/characters/quiver_attributes.gd` | 修饰 B′ 手术 + 五字段 + reset 清账（T1/T3） |
| Create | `tools/block_parry_contract/{block_parry_contract.gd,.tscn}` | 新契约套（M/P 流逐任务生长；矩阵第 23 套） |
| Modify | `project.godot` | jump 解绑 K；新 `block`=K（T2） |
| Modify | `addons/.../create_new_character/character_creator.gd` + `tools/wp2_creation_test/wp2_runner.gd` | 三件套扩容 3 字段（T3） |
| Modify | `ui/debug_dock_tabs.gd` | 受管字段+修饰记录展示（T3） |
| Modify | `addons/quiver.beat_em_up/utilities/helpers/autoload/quiver_combat_system.gd` | apply_damage_value + apply_damage 薄委托（T4） |
| Modify | `addons/.../collision_areas/quiver_hurt_box.gd` | 判定缝三分支 + 白闪 helper + 规则常量（T4） |
| Create | `_beat_em_up/action_states/quiver_action_block.gd` | 格挡姿态状态（T5） |
| Modify | `characters/playable/chen/chen.tscn`（非 git！）+ `templates/character/`（同步工具） | Block 状态节点装配（T5） |
| Modify | `tools/matrix_runner/run_matrix.sh` | 名册+ATTEST（T6）；根 `AGENTS.md`（非 git）数值治理法+矩阵 23/24（T6） |
| Modify | `docs/PLUGIN_ARCHITECTURE.md`、`docs/SPELL_SYSTEM_DESIGN.md` §11、根 `PLUGIN_CHANGES.md` | 文档三件套（T7） |
| Create | `docs/superpowers/plans/2026-09-23-s2-b3-block-parry-f5.md` | F5 单（T7） |

---

### Task 1: 修饰核心 B′ 手术 + 契约套骨架（M 流）

**Files:**
- Modify: `addons/quiver.beat_em_up/characters/quiver_attributes.gd`（`add_modifier`/`remove_modifier`/`remove_modifiers_from_source` 重写 + `reset()` 加清账行；`_modifier_records` 声明处 `:136` 旁增 `_modifier_bases := {}`）
- Create: `tools/block_parry_contract/block_parry_contract.gd` + `.tscn`（单 Node 根挂脚本，仿 container_contract.tscn 十行形制）

**Interfaces:**
- Produces（T3/T4/T6 依赖）：`add_modifier(mod_id: StringName, attribute: StringName, type: String, value: float, source: Node = null)` 语义=重算回写；`remove_modifier(mod_id)`；`remove_modifiers_from_source(source)`；`reset()` 清全部修饰并还原 base。int 型属性重算结果 `roundi` 回写。同 id 再挂=替换。
- 行为宪法：**属性值永远=重算结果**（读路径零改动）；base 只在该属性第一个修饰到来时捕获。

- [ ] **Step 1: 写 M 流失败断言**（`_flow_modifiers()` 纯 RefCounted，不建场景）：

```gdscript
const A_AT := "res://addons/quiver.beat_em_up/characters/quiver_attributes.gd"
const M_BASE_MOVE := 600.0

func _fresh_attrs() -> QuiverAttributes:
	var a: QuiverAttributes = load(A_AT).new()
	return a

func _flow_modifiers() -> void:
	var a := _fresh_attrs()
	# M1 base 捕获+重算：×0.5 → +100 → (600+100)×0.5=350（旧世界=400，必红）
	a.add_modifier(&"m_mult", &"move_speed", "multiply", 0.5)
	_check(a.move_speed == 300, "M1a 单乘回写=300（两世界同值，护住 locomotion）")
	a.add_modifier(&"m_add", &"move_speed", "add", 100.0)
	_check(a.move_speed == 350, "M1b 加乘复合按序重算=350")
	# M2 乱序摘除（旧世界：先摘 m_mult 会把 600 写回、再摘 m_add 落 300——必红）
	a.remove_modifier(&"m_mult")
	_check(a.move_speed == 700, "M2a 摘乘余加=700")
	a.remove_modifier(&"m_add")
	_check(a.move_speed == 600, "M2b 全摘归 base")
	# M3 同 id 刷新（replace）
	a.add_modifier(&"m_dup", &"move_speed", "multiply", 0.5)
	a.add_modifier(&"m_dup", &"move_speed", "multiply", 0.5)
	_check(a.move_speed == 300, "M3a 同 id 再挂=替换非叠乘（600 非 150）")
	a.remove_modifier(&"m_dup")
	_check(a.move_speed == 600, "M3b 一次摘净")
	# M4 非法 type：告警+不入账
	a.add_modifier(&"m_bad", &"move_speed", "wat", 2.0)
	_check(a.move_speed == 600, "M4a 非法操作型不改值")
	# M5 reset 清账（护人/locomotion 修饰不跨死亡）
	a.add_modifier(&"m_life", &"move_speed", "multiply", 0.5)
	a.reset()
	_check(a.move_speed == 600, "M5a reset 后受管值=base（旧世界：记录残留）")
	a.remove_modifier(&"m_life")
	_check(a.move_speed == 600, "M5b 死账摘除=无操作（记录已清）")
	_finished_m = true
```

（runner 主链：`await _flow_modifiers()` → `_check(_finished_m, "M 流全序列执行完成")` → PASS 横幅+quit；`_check/_frames` 仿 container_contract。）

- [ ] **Step 2: 跑 `godot --headless --path . res://tools/block_parry_contract/block_parry_contract.tscn` 确认 M1b/M2a/M2b/M3a/M5* 红**（旧世界行为对表：add 后=400、乱序摘后=300、dup=150、reset 残留=300），红据入报告。
- [ ] **Step 3: 重写三函数 + reset**：

```gdscript
## 方式 B′（2026-09-23 手术）：属性值永远是"base+Σ加"×"Π乘"的重算回写——
## locomotion 等全部读路径零改动；叠挂/乱序摘除/跨 reset 踩踏在结构上不可能。
## base 只在该属性首个修饰到来时捕获（受管字段单写者纪律：入册后禁裸写，AGENTS 立法）。
func add_modifier(mod_id: StringName, attribute: StringName, type: String,
		value: float, source: Node = null) -> void:
	if type != "add" and type != "multiply":
		push_warning("未知修饰操作型: %s（%s→%s 被拒）" % [type, mod_id, attribute])
		return
	remove_modifier(mod_id)   # 同 id 刷新=替换（M3）
	if not _modifier_bases.has(attribute):
		_modifier_bases[attribute] = {
			"value": float(get(attribute)),
			"is_int": typeof(get(attribute)) == TYPE_INT,
		}
	_modifier_records.append({id = mod_id, attribute = attribute,
			type = type, value = value, source = source})
	_recompute(attribute)

func remove_modifier(mod_id: StringName) -> void:
	for i in range(_modifier_records.size() - 1, -1, -1):
		if StringName(_modifier_records[i]["id"]) == mod_id:
			var attr: StringName = _modifier_records[i]["attribute"]
			_modifier_records.remove_at(i)
			_recompute(attr)
			return   # id 唯一（add 已强制），摘一个就够

func remove_modifiers_from_source(source: Node) -> void:
	var touched := {}
	for i in range(_modifier_records.size() - 1, -1, -1):
		if _modifier_records[i]["source"] == source:
			var attr: StringName = _modifier_records[i]["attribute"]
			_modifier_records.remove_at(i)
			touched[attr] = true
	for attr in touched:
		_recompute(attr)

func _recompute(attribute: StringName) -> void:
	var base_d: Dictionary = _modifier_bases.get(attribute, {})
	if base_d.is_empty():
		return
	var sum := 0.0
	var prod := 1.0
	for r in _modifier_records:
		if r["attribute"] == attribute:
			if r["type"] == "add": sum += float(r["value"])
			else: prod *= float(r["value"])
	var out: float = (float(base_d["value"]) + sum) * prod
	set(attribute, roundi(out) if base_d["is_int"] else out)

## 清账（reset 与死亡重跑共用）：全记录作废+受管属性回 base。
func _clear_all_modifiers() -> void:
	var attrs := _modifier_bases.keys()
	_modifier_records.clear()
	_modifier_bases.clear()
	for attr in attrs:
		set(attr, _restored_base... )   # 注意：base 表已清，先取后清——见下
```

**实施修正**（防把上面注释当代码抄）：`_clear_all_modifiers` 先快照 `var bases := _modifier_bases.duplicate(true)`，再 clear 两表，最后按快照逐项回写（int 属性回写 `roundi`）。`reset()` 体内追加 `_clear_all_modifiers()` 一行，注中文判据（护人态不跨死亡）。

- [ ] **Step 4: M 流全绿复跑**（含 Step1 里两条"两世界同值"哨兵 M1a 未漂移）。
- [ ] **Step 5: 等价哨兵复跑两旧套**（locomotion 是手术区唯一活体消费方）：`... res://tools/input_channel_test/test_runner.tscn` 与 `... res://tools/stage_contract/stage_contract.tscn` → 17/17 与 128/128。任一红=手术动了语义，回炉。
- [ ] **Step 6: 提交**（attributes + 契约两文件点名）：`feat: 修饰核心 B′ 手术——重算回写封死叠挂/乱序/reset 三类踩踏（M 流 11 断言）`。

---

### Task 2: 输入绑定（block=K，jump 让位）

**Files:**
- Modify: `project.godot`（`[input]` jump 块去 K；新增 block 块）

- [ ] **Step 0: 备份** `cp project.godot /tmp/opencode/b3_t2/project.godot.bak`（git 跟踪但按判例双保险）。
- [ ] **Step 1: 全仓找裸键 K 依赖**：`grep -rn "physical_keycode\":75\|KEY_K\b" tools/ scripts/ _beat_em_up/ ui/ --include='*.gd' --include='*.tscn'` ——预期命中=jump 注入腿（如 input_channel/hud 若有 KEY_K 注入，改 KEY_SPACE 或保留 Space 事件即可；**逐处记录**）。
- [ ] **Step 2:** 编辑 `[input]`：jump `events` 数组裁至只剩 Space(32) 一枚；新增：

```
block={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":75,"key_label":0,"unicode":107,"location":0,"echo":false,"script":null)
]
}
```

- [ ] **Step 3: 验证探针**（一次性 `-s`：`InputMap.has_action(&"block")`、`action_get_events(&"block")[0].physical_keycode==KEY_K`、`jump` 事件数=1 且 physical==KEY_SPACE；顺带 `is_action_pressed` raw 注入两键各走一遍——判例：物理通道匹配）。
- [ ] **Step 4:** 若 Step 1 有迁移，复跑受影响套全绿。提交（project.godot+迁移文件点名）：`feat: block=K 输入动作上轴，jump 让位只留 Space（分镜 J刀K盾 对齐）`。报告置顶标注 **Windows 须重启编辑器**。

---

### Task 3: 五字段 + 创建器三件套 + dock 展示

**Files:**
- Modify: `quiver_attributes.gd`（`:127` skin_direction 快照附近插五字段；`reset()` 补两运行时字段复位）
- Modify: `character_creator.gd`（DEFAULT_STATS + `_synthesize_attributes` 各 +3）
- Modify: `tools/wp2_creation_test/wp2_runner.gd`（stats/expect_attrs 各 +3 特征值行）
- Modify: `ui/debug_dock_tabs.gd`（数值页 +3 行 + 修饰记录一行列表）

**Interfaces（T4/T5/T6 依赖，命名钉死）：**
`is_blocking: bool`（运行时，不进 tres）、`block_started_frame: int`（运行时）、`@export parry_window_frames: int = 6`、`@export block_damage_ratio: float = 0.4`、`@export attack_output: float = 1.0`。三导出进受管名单（文档注释标"受管：只走修饰 API"）。

- [ ] **Step 1:** 失败测试先行（wp2）：`wp2_runner` 玩家行 stats 加 `"parry_window_frames": 6.0, "block_damage_ratio": 0.4, "attack_output": 1.0` 特征值 5/0.25/0.66，`expect_attrs` 对应三行 → 跑 `godot --headless --path . -s tools/wp2_creation_test/wp2_runner.gd`（入口以该文件为准，两拍制）→ 合成缺行必红。
- [ ] **Step 2:** attributes 插入五字段（中文 doc：状态闸门非数值/受管域/时基）；`reset()` 里 `is_blocking = false`、`block_started_frame = 0`；creator DEFAULT_STATS + 合成器三行（照 `has_superarmor = %s` 行的风格：两 bool 无、三数值走 `_num`）。
- [ ] **Step 3:** dock 数值页：仿 `is_invulnerable` 展示行（`:207-209`）追加三受管字段实时值 + 一段"修饰：来源id→字段(型·值)"逐行（读 `_modifier_records`——若私有不可读则加只读访问器 `func modifier_snapshot() -> Array`，入 attributes 手术区尾巴，中文注明"展示用快照非第二真相"）。
- [ ] **Step 4:** wp2 全绿 + `interact_contract`（消费替身产线）复绿；提交。`feat: 盾反数据面五字段入册+创建器三件套同步+dock 修饰账本可见`。

---

### Task 4: 判定缝（三分支 + apply_damage_value + 白闪/定格）

**Step 0（探针先行，spec 风险 3）：** 一次性脚本对比 `HitFreeze.start(12)` 前后 `Engine.get_physics_frames()` 是否推进（暂停期间物理帧号语义实锤），结论写进 hurtbox 常量注释与报告；若帧号照走，P3 边界断言改用"定格前起跳"构造规避歧义并注明。

**Files:**
- Modify: `quiver_combat_system.gd`（`apply_damage` 薄委托化 + 新 `apply_damage_value(p_damage: float, target: QuiverAttributes)`，体=原三行：invuln 守卫/扣血/`HitFreeze.start()`；**float 参数不取整**，保持两世界算术逐位同构）
- Modify: `quiver_hurt_box.gd`（`_handle_hit_box` 重构为 spec §2.3 三分支 + 顶部常量 `_PARRY_STUN_KNOCK := 60.0`、`_PARRY_FREEZE_FRAMES := 6`、`_FLASH_STRONG := Color(2.5,2.5,2.5,1)`、`_FLASH_WEAK := Color(1.8,1.8,1.8,1)`、时长 0.12/0.07s + `static func _flash(target_attrs, strong)`：`target_attrs.character_node` 上 `create_tween().bind_node(node)` 双段 modulate，null 安全）
- Modify: `tools/block_parry_contract/block_parry_contract.gd`（+P1/P2/P3/P6 流；场景段仿 lane：`ACTOR_SCENE`+`VENDOR`+地面+`_attack/_place/_watch_hit` 三 helper **逐字移植**自 lane:99-107）

- [ ] **Step 1:** 写 P 流失败断言：
  - **P1 回归**：A 出拳打无防 V → `hp0-10±ε`（ε=1 吸收 float/int），V 曾入 `Ground/Hurt`（`_watch_visual` 移植）；
  - **P2 格挡**：`V.attributes.is_blocking=true; V.attributes.block_started_frame = Engine.get_physics_frames()-99`（超窗内部捷径，中文注记"判定缝测试豁免 OS 链——E2E 归 P7"）→ 出拳 → 掉血**恰 4**（`_watch_hit` 帽 120 后取精确差），V 不入 Hurt、V `resistance_current==600` 不动、A 无变化；
  - **P3 窗界**：预置 `is_blocking` 真+`block_started_frame=now-3`（delta=3<6）出拳 → V 掉血 0、V 池 600、**A 池 540 且 A 入其 Hurt 态**；再一发预置 delta=6（严格 `<` 归格挡）→ 掉血 4；
  - **P6 弹体被挡**：V `is_blocking` 超窗，投 lane/法术既有弹体（复用 spell_hit 的 fire_ball 发射 helper 或 A 的 air 弹——以 spell_cast_test 现行发射形制最小移植），断言弹体命中走格挡支（掉血=弹伤×0.4；若弹体 `hit_box.character_attributes` 实测为 null → `attack_output` 按 1.0 生效的探针结论进注释）。
- [ ] **Step 2:** 红据入报告（is_blocking 尚不存在=parse 级红亦可算红，注明）。
- [ ] **Step 3:** 实施两插件文件（**代码以 spec §2.3 时间轴表为准绳**；hurtbox 重构后原 else 支保持原三行语义、只把 `apply_damage` 换成经 `apply_damage_value(attack.attack_damage * out_mult, ...)` 且 `out_mult := 1.0 if atk_attrs == null else atk_attrs.attack_output`；`_flash(V attrs, true)` / `_flash(A attrs, false)` 两挂点按 spec 三件套）。
- [ ] **Step 4:** P 流全绿；复跑 `knockout_contract`（apply_damage 委托化动了它的地基）与 `spell_cast/spell_hit`（弹体回调路）+ `container 57`。红即回炉。
- [ ] **Step 5:** 提交（三文件点名）：`feat: 判定缝三分支——格挡吞击退值/弹反反顶攻击者池（apply_damage_value 入口+白闪 helper）`。

---

### Task 5: QuiverActionBlock 状态 + chen/模板装配 + P7 真键盘腿

**Files:**
- Create: `_beat_em_up/action_states/quiver_action_block.gd`
- Modify: `characters/playable/chen/chen.tscn`（**动前 tar 备份**）+ 跑 `python3 tools/sync_template_from_chen.py`（模板随动，幂等）
- Modify: `tools/block_parry_contract/block_parry_contract.gd`（+P7）

- [ ] **Step 1:** 装配先行测试（P7 红）：spawn 替身 A 于地面 → raw 注入 `InputEventKey`（physical KEY_K, pressed=true）→ `_wait_until(state=="Ground/Block", 30)` 必红（无状态节点）。
- [ ] **Step 2:** 写状态（全文骨架，仿 cast 档头纪律）：

```gdscript
@tool
class_name QuiverActionBlock
extends QuiverCharacterAction

## 格挡姿态（S2-B3）：按住 block 即架盾站桩，松开回 Idle；进出全由本状态
## 引擎 _physics_process 虚函数自选——quiver_state 仅在编辑器 hint 下关处理，
## 运行期节点虚拟处理独立于 SM 派发（2026-09-23 实锤），零插件核心手术。
## 受击/击飞打断继承 Ground 挂线（hurt_requested 全程武装，攻击半途换台判例）；
## 本状态不处理伤害——判定在 QuiverHurtBox 缝（spec §2.3）。
## 进入白名单=三个 locomotion 状态（转移图=代码约定，AGENTS 状态机章口径）。

@export var _skin_state: StringName = &"idle"   ## 真防御动画到货=改此导出（同名替换纪律）
@export var _path_idle_state: NodePath = "Ground/Move/Idle"
@export var _entry_whitelist: Array[StringName] = [&"Idle", &"Walk", &"Run"]

func enter(msg: = {}) -> void:
	super(msg)
	if _should_enter_parent:
		get_parent().enter(msg)
	_state_machine.input_window_open = false
	_character.velocity = Vector2.ZERO
	_character.attributes.is_blocking = true
	_character.attributes.block_started_frame = Engine.get_physics_frames()
	if _skin.has_anim_state(_skin_state):
		_skin.transition_to(_skin_state)

func unhandled_input(_event: InputEvent) -> void:
	pass   # 输入窗已关，姿态不消费任何事件

func physics_process(delta: float) -> void:
	if _should_process_parent:
		get_parent().physics_process(delta)
	_character.velocity = Vector2.ZERO   # 站桩钉死（Ground 链只跟 ground_level）

func _physics_process(_delta: float) -> void:
	# 引擎虚拟：无论本状态在不在场都每帧跑——在场管出，不在场管进（白名单外禁入）
	if Engine.is_editor_hint():
		return
	var sm := _state_machine
	if sm == null or _character == null:
		return
	if sm.state == self:
		if not _character.channel.is_held(&"block"):
			sm.transition_to(_path_idle_state)
	else:
		if _character.channel.is_held(&"block") \
				and sm.state.name in _entry_whitelist:
			sm.transition_to("Ground/Block")

func exit() -> void:
	_character.attributes.is_blocking = false
	_state_machine.input_window_open = true
	super()
	if _should_exit_parent:
		get_parent().exit()
```

（`_state_machine/_character/_skin/_should_*` 成员名以 `quiver_character_action.gd`/cast 实文件为准，装配前先读一眼。）

- [ ] **Step 3:** chen.tscn 装配 Block 节点（Cast 形制同款：`[node name="Block" type="Node" parent="StateMachine/Ground"]` + script + `parent_should_*` 三真）；`--import`；`python3 tools/sync_template_from_chen.py` 后 `bash tools/matrix_runner/run_matrix.sh --ensure-only` 重建替身带入 Block。
- [ ] **Step 4:** P7 补全绿：K 按下→Block 态；B（第二个替身，内部捷径出手）打 A → A 掉血 4（格挡支生效，非 10）；raw 注入 K up → `_wait_until(state=="Ground/Move/Idle")`；再验 P7d：Block 期间注入 Space（跳跃键）**无反应**（输入窗关=姿态不吞别的键，让位判据）。
- [ ] **Step 5:** 复跑 `interact_contract`（其 X 流用 chen/替身树，防装配回归）与 `input_channel`；提交（新状态+chen.tscn+templates 变更+契约，点名；报告附 chen 备份路径）。`feat: QuiverActionBlock 姿态状态自选进出，chen/模板/替身三处落地+真键盘 K E2E`。

---

### Task 6: 护人态修饰示范（P5）+ run_matrix 名册 + 数值治理法入规

**Files:**
- Modify: `tools/block_parry_contract/block_parry_contract.gd`（+P5）
- Modify: `tools/matrix_runner/run_matrix.sh`（ROSTER+`block_parry_contract`；ATTEST 表 +`ACTOR-GATE` 见证，套件守卫腿须打）
- Modify: 根 `AGENTS.md`（非 git）——数值治理法一条 + 矩阵计数 22/23→**23 套=24 跑** + 受管字段单写者纪律。

- [ ] **Step 1:** P5 断言（B2/B5 复用件示范）：给 A（防守侧）挂 `add_modifier(&"escort_window", &"parry_window_frames","multiply",2.0)`、B（攻击侧）挂 `add_modifier(&"escort_power", &"attack_output","multiply",0.3)`；① B 出拳打**无防** A → A 掉血 **3**（10×0.3 精确）；② A 预置 delta=8 被 B 拳 → **窗 12 内弹反成立**（0 伤+B 池-60）；③ 双 `remove_modifiers_from_source` 后复测 → 掉血回 10、delta8 变格挡掉 4。红先行（attack_output 未接线时①红——T4 已接线则本步直绿，绿亦贴据）。
- [ ] **Step 2:** 名册/ATTEST 落进 run_matrix.sh；`bash tools/matrix_runner/run_matrix.sh --only block_parry_contract` 全绿自证。
- [ ] **Step 3:** AGENTS 三处小段（法源抄 spec §4 精简版）；提交。`feat: 护人态两条修饰示范入账（P5 三断言），block_parry_contract 入矩阵名册+ATTEST`。

---

### Task 7: 收口——全矩阵 + 文档三件套 + F5 + tag + 终审

- [ ] **Step 1:** `bash tools/matrix_runner/run_matrix.sh` → **24 跑全绿**（含新套）；汇总表入报告。
- [ ] **Step 2:** 文档：PLUGIN_ARCHITECTURE（判定三分支图+受管字段表+B′ 语义章，替换方式 B 旧述；状态图加 Block 节点线）；SPELL_SYSTEM_DESIGN §11（方式 B 段就地升格 B′，"挂/撤直改属性值"旧句作废）；根 PLUGIN_CHANGES（三触点案卷）。
- [ ] **Step 3:** F5 单 `…-f5.md` 三眼：弹反白闪+顶硬+6 帧定格手感（对照不防）；K 让位后 Space 跳跃无恙；格挡吞拳3 飞天（重击站桩判据）。
- [ ] **Step 4:** DEVELOPMENT_STATUS B3 行；提交+tag `s2-b3-done`+push。
- [ ] **Step 5:** 终审（whole-branch，附账本挂账分诊）→ 一波修（如需）→ 报告含 Rulings 全录。

---

## Deferred/挂账池（随批滚）

- `attack_output` 只活近战缝（弹体伤害不归本批，B4 若需再论）；
- 弹反无音效（全工程无音频层）；
- 都尉"正面减伤+护甲"届时裁决（spec §2.3.2 例外条 + 风险 5）；
- P6 弹体 `character_attributes` 绑定探针结论（T4 Step1 产出）若 null → 记"弹体无攻击者属性，attack_output 对其恒 1.0"为既有边界。
