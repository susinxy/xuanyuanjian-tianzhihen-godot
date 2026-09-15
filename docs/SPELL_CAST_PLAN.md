# 法术键权修复 + 施法动作系统 实施计划（定稿）

日期：2026-09-15 · 状态：执行中 · 决策人：susinxy

## 背景问题
1. Run Test 场景按 1-4：可见反馈只有光照切换（调试节点硬编码 1-4），法术"被光照取代"；
   深层回归：法术测试助手与角色壳 chen 双消费者争抢私有输入通道边沿（读一次即消费，
   父先子后 → chen 空手册吃掉按键），助手永不触键，施法链路实际已断。
2. 施法没有"施法者动作"：SpellDefinition 无相关字段，SpellManager 直接上场法术体，角色站桩。

## 已拍板决策
- 键权：1-4 = 法术（InputMap 不动）；光照调试相位改数字键 **5/6/7/8**（O 覆盖不动）
- 助手目标形态 = "法术注入脚本（仅测试场景生成物）"：只 `host.learn_spell()` 教给被测角色
  （子节点 _ready 先于父 → call_deferred），按键/扣蓝/冷却/施法唯一归角色壳
- 施法者与攻击**同款架构**：动画固定槽名 `spell`、方向选择复制攻击机制（上/下/左/右归一化）、
  父链委托、hurt 信号链打断；差异仅在：无连段 + **循环动画**由时长计时收尾
- 数据：SpellDefinition 仅新增 `caster_cast_time: float = 0.0`（0=瞬发=旧行为，向后兼容）
- 出手时机：动画（循环）播满足时长后出法术体；动画缺失（当前真实情况）→ 仍锁满时长（节奏一致）
- 法力/冷却起手即扣，打断不退还（承诺制）
- 施法中关输入窗口（J 不能切入攻击）；空中起手本轮静默拒绝（Cast 挂 Ground）
- 角色改动必须进模板：chen 手术 → sync_template_from_chen.py 扩散（新角色出生即有 Cast）

## 阶段 0（键权 + 注入脚本重构）
1. `tools/spell_cast_test/helper_e2e` 红测试：a) 模板字符串含 `SpellManager.new(`＝红；
   b) 引擎级复现"双消费者 chen 先吃键"（永久回归锁）；c) 新路径（教给宿主→注入→法术体上场）
2. `create_new_spell/inspector_plugin.gd` helper 模板改"教给宿主"
3. `scripts/debug_day_night_input.gd` KEY_1..4 → KEY_5..8 + 注释
4. 文档键位：LIGHTING_SETUP_GUIDE、PLUGIN_ARCHITECTURE（历史 PLAN 不改）
5. 全矩阵 + 提交

## 阶段 1（施法动作系统）
1. chen 备份包（非 git）→ `SpellDefinition` 加 `caster_cast_time`
2. `SpellManager`：cast_time>0 且 Ground 时 `transition_to("Ground/Cast", msg)` 出手延迟；
   修 `_is_state_allowed` 全路径比较 bug（改末段名）；咏唱中防再起手
3. `_beat_em_up/action_states/quiver_action_cast.gd`：enter 收 {slot, release callable}，
   方向归一化同攻击、关输入窗口、循环动画（skin 缺 `spell` 槽时降级不播但计时不豁免）、
   计时到出手、回 Ground/Move/Idle
4. skin 加公开 `has_anim_state()`（无副作用）→ PLUGIN_CHANGES.md + 架构文档
5. chen.tscn 挂 Cast 节点（_skin_state=&"spell"）→ sync 扩散 → git diff 审模板
6. 契约测试：未到点无实体/到点有实体且归 Idle/起手扣蓝/打断不退还/咏唱中二次注入被拒
7. 文档 + 全矩阵 + 提交

## 阶段 2（2026-09-15 已完成）+ 阶段 2.5 两段式（同日定稿：起手角色资产必完整播+引导法术计时，契约见 SPELL_SYSTEM_DESIGN 17.1）
- 施法者：`spell` 槽四点混合暂指单一动画（用户设计，见 SPELL_SYSTEM_DESIGN 17.1/17.2）；
  占位=attack1_right 复制删方法轨+循环；run→attack1 保险边被否——中枢原则确立、
  walk↔run/walk→attack1 一并清理；attack2 缺回连 idle 真 bug 顺带修复
- 法术体：SpellSkin 方向向量四正量化 + fire_ball active 四点 + creator 模板四点化（17.3）
- 回归网：tree_connectivity（7 边断言+19 态回 idle）、契约 I 段升级为"活动态=spell"、
  wp2 创建流"+3 断言=33"（出生即有槽）；模板已 sync 进 _template
- 遗留：真帧管线待美术（左右中性约定）；`_beat_em_up` 转换工具对"单动画"类别的支持
  届时再定
