# S2-B4.6 攻击朝向模式（Attack Axis Mode）· 设计文档

日期：2026-09-26 ｜ 状态：设计对话定档（§7 裁决记录），随批评审
输入：2026-09-26 用户四轮讨论（原为 B5 插入事务，终裁独立成批先行）；
本仓 `2.5D 车道判定`（attack_lane 契约家族）与 `facing_x 朝向记忆`（locomotion/mid_air）机制。

## 0. 定位

角色级可配置的两种**地面攻击定向**：`HORIZONTAL_ONLY`（只有左右，**全局默认**，
含所有既有角色）与 `FOUR_DIRECTION`（上下左右）。横向模式下面朝上/下出手时，
攻击方向取"最近一次朝向左右的方向"——与跳跃的方向选择是**同一份记忆、同一条
规则**（`skin.facing_x`），本批不发明第三种方向裁决。B5 兵种装配（刀手/纵火兵/
都尉逐兵选档）消费本能力，故独立微批先行于 B5。

## 1. 范围

**本批做**：`QuiverAttributes` 枚举+导出字段（代码默认=横向）；`QuiverActionAttack.enter`
方向解析分流；创建器三件套+表单下拉（默认"只有左右"）+wp2 逐行核对；lane 契约
H 腿组（横模语义+跳跃同源直证）+纵向机制腿的运行时覆写自洁形制；全矩阵；文档。
**本批不做**：空中攻击改造（现状即恒横、吃 facing_x，与本模式同构，零扰动）；
法术施放方向（`SpellManager.snap_to_four_direction` 独立解析，知情不吃本旗）；
敌人 AI 选向逻辑（AI 只决定"打不打"，方向归本旗裁决）；上下攻击动画资产处置
（闲置=美术零损失，档案保留）。

## 2. 机制

### 2.1 数据面（`quiver_attributes.gd`）

```gdscript
enum AttackAxisMode { FOUR_DIRECTION, HORIZONTAL_ONLY }
## 地面攻击朝向模式（行为路由设置，单写者=创建面板/Inspector；只读不进修饰域，
## reset() 不清——它是档案配置非运行时状态。治理法合法旗注例见 spec §5）
@export var attack_axis_mode: AttackAxisMode = AttackAxisMode.HORIZONTAL_ONLY
```

**默认语义定档（用户裁决②）**：代码导出默认=横向 ⇒ 一切**无该字段的既有 tres**
（chen/spar_enemy/street_vendor/模板演示值）加载即横——"以前的角色也都调整为
左右方向"零迁移实现；Inspector 勾选即手动调档（用户裁决①，@export 天然通道）。

### 2.2 行为面（`quiver_action_attack.gd::enter` 方向解析分流）

现状（`:89-93`）：八向 `skin.skin_direction` 主轴塌缩到四向。改为：

```gdscript
var dir := _skin.skin_direction
if _attributes.attack_axis_mode == QuiverAttributes.AttackAxisMode.HORIZONTAL_ONLY:
    # 横向模式：出手向=跳跃同源——吃 facing_x 持久记忆。
    # 记忆由 locomotion（输入水平分量=0 绝不改写，quiver_action_locomotion.gd:88-90）
    # 与 mid_air（空中水平速度≠0 才覆写，quiver_action_mid_air.gd:130-138）维护，
    # 故"面朝正上/正下出手"=最近一次左右朝向，与面朝正上起跳播同向跳姿同一数据源。
    _skin.skin_direction = Vector2(_skin.facing_x, 0)
else:
    # 四向模式：现行两分支逐字保留（含斜向主轴裁决与纵向档）
    if abs(dir.x) >= abs(dir.y):
        _skin.skin_direction = Vector2(sign(dir.x), 0)
    else:
        _skin.skin_direction = Vector2(0, sign(dir.y))
# 快照行 attributes.skin_direction 与 exit 清零：两模式共用，不动
```

**连锁（全免费零特判）**：快照恒横 → `QuiverHurtBox` 车道轴选择自动比排 →
纵向"比列"判定对横模招式永不触发；皮肤攻击动画混合恒落左/右档。

## 3. 面板产线（创建时配置，用户裁决①）

- `create_new_character_widget.gd`：数值区加下拉"攻击朝向模式"（`只有左右`/
  `上下左右`），**默认选中"只有左右"**；
- `character_creator.gd`：`DEFAULT_STATS` 加 `"attack_axis_mode": 1`（=枚举
  HORIZONTAL_ONLY）；`_synthesize_attributes` 加落盘行
  `attack_axis_mode = %d`（int 直写，不走 `_num` 浮点通道——枚举非数值域，中文注）；
- `wp2_creation_test`：出生值与显式选四向各一行核对（面板→tres→运行时三段一致）。

## 4. 契约（`tools/attack_lane_contract` 主战场）

- **默认翻转的第一波连锁是契约自身**：lane 的 B 组纵向机制腿（纵攻比列、B9 受击
  不改 facing_x、快照生命周期纵档）活在 test_actor 四向行为上——默认翻横后必红。
  形制=**纵向腿就地覆写自洁**：腿前 `actor.attributes.attack_axis_mode =
  QuiverAttributes.AttackAxisMode.FOUR_DIRECTION`，腿组尾恢复默认——机制覆盖与
  角色配置解耦（契约夹具构造自清标准形，中文注引 spec §4）；
- **H 腿组（新增，先红后绿）**：
  - H1 横模+面向正上（skin_direction=(0,-1)、facing_x=-1）出手 → 快照恰 `(-1,0)`；
  - H2 **跳跃同源直证**：正上行走全程（输入 x=0）→ facing_x 不动 → 出手=上一次
    左右向；对照同状态起跳方向（同值断言）；
  - H3 端到端：横模出手同排可中、邻列免疫（列比对形迹为零）；
  - H4 切换无残影：同角色先后两模式各出手，快照/exit 生命周期对称；
  - H5 零向量静止出手（正上站立无移动）→ 吃 facing_x 现值（默认 1=右）不崩；
- block_parry / knockout / spell 等套：分层复跑，若有吃纵档的腿按同款覆写形制
  就地自清（实跑清点，报告列腿号）；R8 先红后绿（H1 对旧代码必红——旧代码无
  本旗，横向塌缩=现状纵档红）。
- 矩阵 24 套=25 跑口径不变（lane 同套扩流），T2 批内全矩阵终核。

## 5. 边界与治理自证

- **合法旗论证（入 AGENTS 数值治理法注例）**：本旗是**行为路由选择器**（方向解析
  走哪条既定路径），不藏任何数值推导、不参与伤害/池/窗计算——与 guard_mode 型
  违例（旗内推数值）分界清晰；类比先例=`is_invulnerable`/`auto_complete`。
- **默认翻转代价清单（知情定档，用户裁决②明示接受）**：chen/spar 等全部人形角色
  攻击恒出横拳（已 F5 验收的纵向拳行为改变）；上下攻击动画资产闲置；AI 行为不变
  只是招式恒横。回收通道=Inspector 逐角色改回。
- 空中攻击/法术不吃本旗（§1）；`attributes.reset()` 不清本字段（配置非状态）。

## 6. 文件总图与接口

| 动作 | 路径 | 责任 |
|---|---|---|
| Modify | `addons/quiver.beat_em_up/characters/quiver_attributes.gd` | 枚举+导出字段（T0） |
| Modify | `addons/quiver.beat_em_up/characters/action_states/quiver_action_attack.gd` | enter 分流（T0） |
| Modify | `tools/attack_lane_contract/attack_lane_contract.gd` | H 腿组+纵向腿覆写自洁（T0） |
| Modify | `addons/.../create_new_character/create_new_character_widget.gd` + `character_creator.gd` | 面板下拉+三件套（T1） |
| Modify | `tools/wp2_creation_test/*` | 逐行核对（T1） |
| Modify | `docs/PLUGIN_ARCHITECTURE.md`（攻击章）、根 `PLUGIN_CHANGES.md`（非 git）、根 `AGENTS.md`（治理法注例）、`DEVELOPMENT_STATUS.md` | T2 |
| Create | `docs/superpowers/plans/2026-09-26-s2-b46-attack-axis-mode-f5.md` | F5 两眼（T2） |

**接口钉名**：`QuiverAttributes.AttackAxisMode {FOUR_DIRECTION=0, HORIZONTAL_ONLY=1}`；
`attack_axis_mode`（导出，默认 1）；lane 契约辅助 `_use_4dir(actor) -> int`（返回
覆写前原值供还原，或直接腿内成对赋值——实施者择，报告注）。插件触点清单=
`quiver_attributes.gd` + `quiver_action_attack.gd` 两处（红线，超出上报）。

## 7. 裁决记录（2026-09-26，用户签字）

1. 攻击模式**角色创建时配置**（创建面板字段），且**编辑器 Inspector 可改**
   ——据此废弃"攻击状态节点级开关"早期方案；
2. **全局默认=只有左右，所有既有角色一并翻横**（代码默认值承载，零 tres 迁移）；
3. 面向上下出手=**跳跃同源**：吃 `facing_x` 记忆（"最近一次左右朝向"由
   locomotion/mid_air 既有规则维护，本批不新增方向裁决）；
4. 都尉等 B5 兵种选档属装配期普通参数，本机制零预判（撤销"依赖"提问）；
5. 不并入 B5，**独立成批先行**（本批 B4.6）。

## 8. 风险

1. **契约纵向腿雪崩**（默认翻转即红）——预期内，T0 就地覆写自洁形制收编，
   红→绿留档为"机制/配置解耦"改造的活证据；
2. test_actor 是生成物：模板/产线未变则矩阵重建自动带新默认，无需手工迁移；
3. 斜向输入（如右上）横模下不再出斜拳——与正上/正下同语义（facing_x 本就取
   水平分量），行为一致性说明写进 H 腿标签；
4. Inspector 改档后 `--import`/tres 重存属 Windows 常规面，F5 眼②顺带验证。
