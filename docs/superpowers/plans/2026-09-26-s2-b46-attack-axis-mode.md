# S2-B4.6 攻击朝向模式 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 角色级两档地面攻击定向（`HORIZONTAL_ONLY` 全局默认含既有角色 / `FOUR_DIRECTION`），横向模式出手向与跳跃同源吃 `facing_x` 记忆；创建面板可配、Inspector 可改、契约机制与角色配置解耦。

**Architecture:** 数据=QuiverAttributes 枚举导出（行为路由旗，reset 不清）；行为=`QuiverActionAttack.enter` 一处分流（横模恒 `skin_direction=(facing_x,0)`，快照/exit 家族共用零特判）；车道轴选择、动画混合、格挡弹反判定全部经既有快照通道自动生效；契约纵向腿以"腿内覆写自洁"形制保机制覆盖。

**Tech Stack:** Godot 4.7；lane 场景 runner 契约扩 H 腿组；creator 三件套/wp2 产线核对；全矩阵 24 套=25 跑口径不变。

**Spec:** `docs/superpowers/specs/2026-09-26-s2-b46-attack-axis-mode-design.md`（§2 机制/§4 契约形制/§5 治理自证/§7 五裁决是法源）。

## Global Constraints

- 逐路径点名 add，永久禁 `git add -A`；用户 WIP（`scenes/stages/xuanyuan-chapter-1/**`、untracked dll 幽灵）不碰；注释全中文；提交 `feat:/test:/docs:` 中文。
- **插件触点红线=两处**：`quiver_attributes.gd`（枚举+字段）、`quiver_action_attack.gd`（enter 分流）。超出即停上报。同批义务：`docs/PLUGIN_ARCHITECTURE.md` 攻击章 + 根 `PLUGIN_CHANGES.md`（非 git 落盘即算）。
- 本批**零 project.godot 触点**（无新 autoload/输入动作）；零 chen/皮肤资产触点（attributes tres 均不写新字段——代码默认承载语义；chen_attributes.tres 若被顺手动=违规）。
- `attack_axis_mode` 是档案配置非运行时状态：`reset()` **不得**清它；不进修饰域、不加受管写口（写点=创建面板合成器/Inspector 手改）。
- 契约纵向腿覆写形制：腿组前 `actor.attributes.attack_axis_mode = QuiverAttributes.AttackAxisMode.FOUR_DIRECTION`，腿组尾恢复 `HORIZONTAL_ONLY`（成对括弧纪律，中文注引 spec §4）；**禁止**改 test_actor 落盘 tres 来"修"契约（生成物+共享替身）。
- headless 判例全套：`--import` 于新类型后；独立完成旗；`.tscn` 规则；改判先红后绿留档 `/tmp/opencode/b46_t*/`。
- 分层复跑规约：T0 动 attributes/attack 状态 → `attack_lane_contract`+`block_parry_contract`+`knockout_contract`+`spell_save_contract`；T1 动 creator → `wp2_creation_test`+`wp3_formal`+`test_scene_parity`；全矩阵仅 T2 批内一次。
- 已知行为变更（预期非缺陷）：默认翻横后 lane 的 B 组纵向腿首跑必红（活在四向行为上）——那不是回归，是 §4 收编对象。

---

## 文件总图

| 动作 | 路径 | 责任 |
|---|---|---|
| Modify | `addons/quiver.beat_em_up/characters/quiver_attributes.gd` | 枚举+导出（T0） |
| Modify | `addons/quiver.beat_em_up/characters/action_states/quiver_action_attack.gd` | enter 分流（T0） |
| Modify | `tools/attack_lane_contract/attack_lane_contract.gd` | H 腿组先红→纵向腿覆写自洁→全绿（T0） |
| Modify | `addons/quiver.beat_em_up/custom_inspectors/create_new_character/{create_new_character_widget.gd,character_creator.gd}` | 面板下拉+三件套（T1） |
| Modify | `tools/wp2_creation_test/wp2_runner.gd` | 模式行×2（T1） |
| Modify | `docs/PLUGIN_ARCHITECTURE.md`、根 `PLUGIN_CHANGES.md`、根 `AGENTS.md`、`DEVELOPMENT_STATUS.md` | T2 |
| Create | `docs/superpowers/plans/2026-09-26-s2-b46-attack-axis-mode-f5.md` | F5 两眼（T2） |

**Interfaces（钉名）：**

```gdscript
# quiver_attributes.gd
enum AttackAxisMode { FOUR_DIRECTION, HORIZONTAL_ONLY }
@export var attack_axis_mode: AttackAxisMode = AttackAxisMode.HORIZONTAL_ONLY
# quiver_action_attack.gd enter：按 _attributes.attack_axis_mode 分流（spec §2.2 代码）
# character_creator DEFAULT_STATS 新增键："attack_axis_mode": 1
# 合成落盘行：attack_axis_mode = 1（int 直写）
# widget：OptionButton 下拉"攻击朝向模式"，item0="只有左右"（默认选中），item1="上下左右"
```

---

### Task 0: 运行时（枚举+分流）+ lane 收编（H 腿组/纵向覆写自洁）

**Files:** quiver_attributes.gd、quiver_action_attack.gd、tools/attack_lane_contract/attack_lane_contract.gd

- [ ] **Step 1: 先红——H 腿组失败测试**（`_flow` 注册 `H` 组，替身守卫后、B 组前）：
  - H1：`actor._skin.facing_x = -1`、`actor._skin.skin_direction = Vector2.UP…` 正上镜像 → `_attack(actor, Vector2.UP)` → 快照 `is_equal_approx(Vector2(-1, 0))`（横模默认下必红：现状纵档 (0,1/-1…实际旧代码→(0,-1))）；
  - H2 跳跃同源直证：正上行走输入（`actor.channel.axis = Vector2.UP` 喂 locomotion 两帧）→ 断言 `facing_x` 仍=覆写前值 → 出手=同向横拳；对照腿：`_attack` 前记录 `facing_x`，出手后 `skin_direction.x == facing_x`；
  - H5：静止（dir=默认 RIGHT→改 (0,-1) 站立无输入）出手吃 facing_x 现值不崩；
  - 跑套：H1/H2 红 → `/tmp/opencode/b46_t0/red_h.log`。
- [ ] **Step 2:** attributes 枚举行+导出（spec §2.1 原文，中文注全）；attack.gd enter 分流（spec §2.2 原文）；`--import`。
- [ ] **Step 3: 收编纵向机制腿**——跑全套：B 组纵攻腿（B1/B2/B8/B9/比列家族/w_cal 校准）预期红；对每根红腿按 §4 形制加"腿前覆写 FOUR_DIRECTION/腿尾恢复"成对括弧（辅助函数 `func _force_4dir(on: bool)` 形制，实施者定，报告注）；H 组保持横模默认。全绿后**再跑一遍**确认稳定（防覆写泄漏串腿）。
- [ ] **Step 4:** 分层复跑 `block_parry_contract`（84+，找纵档腿同款自洁——预期 P 组 w_cal 与车道比列相关腿会红，同形制收编）、`knockout_contract`、`spell_save_contract` 四套 rc=0；红→绿过程档在报告。
- [ ] **Step 5:** Commit `feat: 攻击朝向模式落地——横模出手向=跳跃 facing_x 记忆，lane 纵向机制腿覆写自洁收编+H 腿组入册`（触点=红线两文件+契约）。

---

### Task 1: 创建面板产线（下拉+三件套+wp2）

**Files:** widget、character_creator、wp2_runner

- [ ] **Step 1:** 先红——wp2 加两行：默认出生 `expect_attrs.attack_axis_mode == 1`；显式选四向的角色 ==0。跑 wp2 必红（DEFAULT_STATS 无键）。
- [ ] **Step 2:** DEFAULT_STATS 加 `"attack_axis_mode": 1`；`_synthesize_attributes` 加 `attack_axis_mode = %d`（int 直写中文注"枚举非数值域，不走 _num"）；widget 数值区加 OptionButton（label"攻击朝向模式"，两项，默认选中 item0="只有左右"，取值为 stats 字典键）；表单校验零新增（枚举恒合法）。
- [ ] **Step 3:** wp2 全绿；分层复跑 `wp3_formal`+`test_scene_parity`+`editor_scripts_check`（widget/creator 静态面）；**矩阵重建 test_actor**（`run_matrix.sh --ensure-only`）验证新产线出生=横模。Commit `feat: 攻击朝向模式入创建面板——三件套扩容+wp2 逐行核对（默认只有左右）`。

---

### Task 2: 终核 + 文档 + F5 + tag

- [ ] **Step 1:** 全矩阵 24 套=25 跑终核 RED=0（test_actor 用毕末销毁照旧）。
- [ ] **Step 2:** 文档四件：PLUGIN_ARCHITECTURE 攻击章加模式段（分流代码引用行号+facing_x 同源链）；PLUGIN_CHANGES 案卷行；AGENTS 数值治理法加"合法行为路由旗"注例（本旗 vs guard_mode 违例分界一句话）；DEVELOPMENT_STATUS B4.6 交付行（五裁决+红绿档路径）。
- [ ] **Step 3:** F5 单（两眼+头部纪律零项——本批无 project.godot/无新 autoload，编辑器仅需常规重启扫脚本）：①chen（默认横模）：朝正上走几步出手→打横拳、方向=最后一次左右朝向；同位置起跳方向对照应一致；②Inspector 打开 `chen_attributes.tres` 改 `attack_axis_mode=上下左右` → 重跑 → 纵拳复活（验 Inspector 通道+四向路径未死）；改回 HORIZONTAL_ONLY 存档。**报用户注意**：这是全局手感变更（所有角色攻击恒横直至逐档改回）。
- [ ] **Step 4:** Commit `docs: B4.6 收口——架构文档攻击模式段/治理法合法旗注例/状态单/F5 两眼`；tag `s2-b46-done` 推送；批报告（含默认已裁清单：lane 辅助形制选择、w_cal 收编腿号、AGENTS 注例句式）。
