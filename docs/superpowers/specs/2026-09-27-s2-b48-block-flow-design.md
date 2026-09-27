# S2-B4.8 格挡流程与格挡动画专题设计

日期：2026-09-27（M3 首位批，路线见 2026-09-27-m3-roadmap.md §3-①）
性质：机制改道（长按制→点按序列制）+ 专职动画资产接入 + 方向格挡 + 判定现代化（帧窗→相位）
法源：本批全部由用户蓝图定义（2026-09-27 专题讨论逐轮裁决），无工程侧预设

## 0. 裁决记录（用户原话对齐）

| # | 裁决 | 轮次 |
|---|---|---|
| R1 | 格挡**不支持长按**：按下 block 即播格挡动画序列，自动回 idle | 蓝图 |
| R2 | 动画两段：`block_out`（起手架盾段）与 `block`（持盾段） | 蓝图 |
| R3 | 动画树链：`idle → block_out → block → idle` | 蓝图 |
| R4 | **弹反时段 = block_out 动画全程**；判定从"数帧"改为"受击瞬间处于哪段动画" | 蓝图 |
| R5 | 格挡**只有左右模式**（与 attack_axis_mode 无关，恒水平） | 方向轮 |
| R6 | 方向判定算法=**接触点 x 符号**：受击点在人物左侧算左来、右侧算右来（x 相等瞬间归右） | 方向轮 |
| R7 | 所有防路判定必须在 **hit lane 之后**（Area2D 重叠≠受击处理）——机检确认现行门序天然满足，方向门/相位分流落在 `_can_be_attacked_by` 下游 | 方向轮 |
| R8 | 弹反成功 → 我不中断，block_out 余程继续播完进 GUARD（防"弹成功反而裸奔"） | 清账"可以了" |
| R9 | 格挡段挡下攻击 → 序列保持继续（无盾硬直，B3 现语义延续） | 同上 |
| R10 | 进入白名单**+地面攻击态**（攻击中/后摇可按 K 取消进格挡） | 同上 |
| R11 | 弹反/格挡各有专属火花卡：`parry`（蓝白金属）、`block`（暗金闷挡） | 同上 |

## 1. 设计基线（防未来翻案，与既有裁决并列）

- **格挡恒左右**：纵深（上/下来）攻击按其 x 偏移归入左/右一侧——`x 一票制`的已知语义，挡得住挡不住只看攻击者横向站位；这是简化选择不是 bug。
- **动画即规则**：弹反窗=block_out 动画长、持盾窗=block 动画长、序列总长=两段之和——**美术调动画时长=调战斗平衡**，入 GUIDE_格挡 的排产纪律；无动画资产时走 §2.3 兜底帧数。
- 相位枚举是**路由表达非数值推导**（数值治理法合法旗判例：block_parry 判例"legal behavior routing"同款）：枚举内零数字推导，判定缝只读。

## 2. 机制规格

### 2.1 QuiverAttributes 变更

```gdscript
enum BlockPhase { NONE, OUT, GUARD }
## 格挡相位（运行时态，reset() 清）：唯一写方=Block 序列态 enter/exit/信标（R4 宪章续命）
var block_phase: BlockPhase = BlockPhase.NONE
## 盾面朝向快照（运行时态）：enter 时取 facing_x 单位向量 (±1, 0)，序列期钉死
var block_facing: Vector2 = Vector2.ZERO
```

- **退役**：`parry_window_frames`（受管导出，含创建面板字段与"13 项"属性域）、`block_started_frame`（成对旗计时字段）。案卷：两者系长按制遗留；相位制下弹反窗由动画长表达。存量角色 tres 中的旧属性行由 Godot 载入时静默忽略，零迁移。
- `is_blocking` **保留不动**：仍是防路总闸（序列全程 true）。

### 2.2 Block 序列态重写（`_beat_em_up/action_states/quiver_action_block.gd`）

```
enter(msg):
    姿态起势（同帧）：is_blocking=true；block_facing=(sign(facing_x),0)；
    block_phase=OUT；velocity=ZERO；input_window_open=false
    皮肤 play("block_out")；挂 skin_animation_finished 监听
信标·block_out 毕:  block_phase=GUARD；皮肤 play("block")
信标·block 毕:      transition → Idle（exit 链清闸）
exit():  保证式收口——is_blocking=false、block_phase=NONE、输入窗归还、
    监听摘除；hurt/knockout/grab 任何打断走同一出口（单写者+全路径覆盖）
物理拍自选进出（§5.11 形制保留）：白名单 = {Idle, Walk, Run, Attack}（R10）；
    按下的接触点/朝向计算全部发生在 enter，序列中不重定向
```

- 序列中再按 K：当前态=Block 不在白名单 → 天然不可重入。
- **信标链风险知情**：AnimTree 自回访不倒带判例——本序列 idle→block_out→block→idle 每步皆新目的地，天然绕开；`start()` 重入仅在同名再进时触发（不会发生）。

### 2.3 无动画兜底（test_actor/占位产线期）

`_skin.has_anim_state()` 缺 block_out 或 block 槽时：走**固定帧数兜底时序**——
`_BLOCK_OUT_FALLBACK := 12` 拍（200ms 弹反窗）、`_BLOCK_FALLBACK := 30` 拍（500ms 持盾窗），
常量注释单一出处；缺槽告警每皮肤一次（`_warn_missing_once` 现形制沿用）。兜底期间相位机照常运转（物理拍自计数替代信标）。

### 2.4 HurtBox 防路手术（quiver_hurt_box.gd :209-239 区）

门序（机检锚点）：阵营门(_on_area_entered) → **车道门(_can_be_attacked_by)** → 防路。新增只在最内层：

```gdscript
if defender_attrs.is_blocking:
    # R6 方向门：接触点=两盒中点，与自身 x 比符号（车道门已保证同排/同列合法重叠）
    var contact_x := (hit_box.global_position.x + global_position.x) * 0.5
    var threat_sign := 1.0 if contact_x >= global_position.x else -1.0
    if threat_sign == defender_attrs.block_facing.x:
        if defender_attrs.block_phase == QuiverAttributes.BlockPhase.OUT:
            → 弹反支（B4.7 现行全保留：攻罚站封形+双白闪+顶退；+R8 己方不中断）
        else:
            → 格挡支（现行：×ratio、击退作废；+R11 block 火花）
    else:
        → 落入常规支（满伤+慢放+火花，视同没架——D12 二元）
```

- 弹反/格挡两支现**不发** `Events.hit_landed`（B4.7 知情收窄）——本批 R11 改判：**发**，style 分别 `&"parry"`/`&"block"`；接触点同一公式（x 一票制与其同源）。§17.9 决策记录同步勘误。

## 3. 动画与资产（可生产性铁律样板）

- 皮肤侧：AnimTree 状态机新增 `block_out`/`block` 两节点（**BlendSpace1D 左右两向**，与 hurt_mid/hurt_high 同构），`_skin_state` 导出改对（新增 `block_out` 槽名导出；缺槽兜底 §2.3）。
- 产线：`resources/sprites/block_out/{left,right}/`、`block/{left,right}/` 同名覆盖规范入模板 README；**占位素材由工程生成**（从 idle 帧复制+一次性 12/30 拍动画），真素材到货美术只换图。
- 模板同步：`templates/character/` 快照含 block 节点与占位图 → 新角色出生即带格挡动画链；`sync_template_from_chen.py` 守卫范围扩两处动画（工具回归跑证）。
- 参数卡：`spark_parry.tres`（蓝白金属，高初速小散布——金铁相击短促）、`spark_block.tres`（暗金大闪光低初速——闷挡）。

## 4. 契约与测试

- **block_parry_contract 大手术**：①全部时序腿从"帧窗"改"相位"制（P 流重写，`parry_window_frames` 配置腿退役）；②新增方向族（同面挡成/背面满伤/纵深攻击按 x 划侧挡成=R6 已知行为锁）；③新增序列族（点按→OUT→GUARD→自动回 Idle 全程相位采样；R8 弹反后续播；R9 格挡后序列保持；R10 攻击后摇取消进格挡）；④兜底时序族（缺动画皮肤走 12/30 拍，test_actor 天然踩此路=免费覆盖）；⑤R11 两支 hit_landed 发射断言（转 hit_feedback E 族）。
- **hit_feedback_contract**：新增 E 族两腿（parry/block 卡在对应支发射、style 路由可证）。
- R8 体检：手术前先出红档（旧帧窗断言在相位制下必红=改判见证），逐族贴报告。
- 矩阵：套件数不变（两既有套改内瓤）；block_parry 断言总数会变，批终核记档。

## 5. 风险与知情清单

- **弹反窗被挡后重开**：格挡段（GUARD）受击不再产生弹反（相位只此一次），"长按连架刷弹反"在本制下不存在（点按天然一序列一窗）。
- **定格×相位解耦（改良申报）**：B3 判例"全局定格蚕食帧窗"在相位制下消亡——弹反窗=防守者动画时钟，与攻击侧时间操纵（慢放/罚站）彻底解耦；HitFreeze 若未来复活只影响双方时钟。
- 攻击取消进格挡（R10）复用 B4.7 封形的**释放双路**通道之外的常规 exit——攻击态 exit 的开窗/信标清理链现成；加"空中攻击后摇不可架"（地面态专属，D6 裁不做的延伸）。
- 白名单加 Attack 后，**AI 敌我无关**（AI 行为档不调 block）；玩家侧"攻击中被击中仍可取消进格挡"——车道门保证假重叠不误判。
- 创建面板"四招/13 项"域删 `parry_window_frames` 后，wp2_creation_test 逐行核对同步改。

## 6. 施工分段（SDD 五段）

- T0 attributes 相位域+Block 序列态重写（含兜底时序）——单测走 block_parry 新族雏形；
- T1 HurtBox 方向门+相位分流+防路发射（含两新卡）——契约方向族/序列族落地；
- T2 动画资产接线：模板 AnimTree/spriteframes/占位图+chen 同名+test_actor 产线+sync 工具守卫扩容；
- T3 block_parry 全手术+hit_feedback E 族+R8 红档+wp2/面板退役；
- T4 文档收口：§17 格挡节+`GUIDE_格挡.md`（含"动画时长=平衡"排产纪律）+状态单+F5 感官单（点按手感/方向可读性/两新卡观感/弹反后续播观感）。
