# 盒轨搭建批设计（PlayfieldBox：2.5D 可移动区盒子与房 demotion 修法）

- 日期：2026-10-07
- 状态：**已批准并实施 2026-10-07**（五任务流水：T1 组件+契约 / T2 校验器修法 /
  T3 模板 v2 / T4 文档 / T5 终核；F5 实机验收待用户）
- 法源对话：用户三条口径（①fighting room 主要是特写镜头+特殊战斗区，**不是战斗的前提**；
  ②阴影可生成区域功能要一并纳入盒世界观；③"一个盒子对于 2.5D 来说就是一个矩形，
  往里面放组件就是搭建场景"）+ 追加裁决（"为什么要用形状来限制装配？"→ 校验器
  **只罚机械死锁/静默失败，不罚配方形状**）。

## 〇、问题定性（现状核查结论）

1. **运行时早已无"地面"概念**：`QuiverActionGround.ground_level` 每帧=角色自身 Y
   （纯记账，供击飞抛物线回落），无落地检测、无重力贴地；角色在自由平面上 8 向移动，
   仅被"四面界"阻挡。"地面"残留在**施工表达层**：段模板手摆 `GroundBody`（实为南边界
   墙带）+`WallL/WallR`，与房矩形、相机动态界、检测线、入口点、Vis 色块共 3 套矩形
   人肉对齐。
2. **现行法与"按需布局"冲突**（均为 S1"配方唯一合法形"时代的形状核对遗迹）：
   - **R4**：检测器 `path_fight_room` 必须非空 → "无锁房的遭遇刷怪带"违法（插件本体
     `quiver_player_detector.gd:56` 实有 null 守卫，纯粹是法拦路）；
   - **R3**：房必须含 ≥1 检测器且 ≥1 生成器 → "纯特写镜头房"违法；
   - 两法都防的是当年真实危害（忘连线=静默失败），但判据选错了——罚形状而非后果。
3. **阴影现行默认已是盒世界观**（本批零改动，只改叙事）：无启用 ShadowRegion 时
   投影多边形原样返回不裁剪（`character_shadow_controller.gd:112`）、合成缓冲按相机
   视矩形对齐（`shadow_soft_edge.gd:111`"旧全屏行为"）。**盒即视觉边界，默认什么都不用摆**。

## 一、目标与非目标

**目标**
- G1 `PlayfieldBox` 组件：段的第一件家具，编辑器拖框=可移动区；运行时派生四边实体
  墙带+可选 Vis 色块；游戏仓侧新代码，**不动插件**。
- G2 校验器修法：R3 降黄、R4 拆形状核对改**接线核对**（含补上真正漏防的孤儿生成器
  检查）、新立 **R13 盒轨**；对"摆不摆房、锁不锁镜、刷不刷遭遇怪"完全自由。
- G3 段模板 v2：盒必做第一件+**双形态并排示范**（锁房三件套/无房遭遇带）。
- G4 法典与 GUIDE 重写"盒+盒内装修"叙事；ShadowRegion 标注"默认不摆"。
- G5 新契约 box_contract（R8 体检红据在册）。

**非目标（棘轮：暴露真痛点再立项）**
- 纯特写房的**自动解锁时机**机制缺口（无人触发/无波可赢=镜头锁死）——本批只保证
  法律不拦（R3 降黄），机制写进法典"待立项"，不做。
- 旧段迁移：`chapter_ref_a/b`（stage_contract 126 断言法定锚）、`demo_control` 全部
  **不迁移**，走旧形兼容通道（R7 照管手摆几何，R13 只管辖含盒文件）。
- 盒与房/相机矩形的派生统一（乙案单矩形源，前轮已裁"先甲后乙"，乙不立项）。
- "全部家具在盒内"的严格坐标核对（雷区 a 使生成器坐标=房局部，机械量大误伤多）——
  R13 只硬查入口，其余出盒靠 F5 手感与盒的可视边界。

## 二、`PlayfieldBox` 组件契约

文件：`scripts/chapter/playfield_box.gd`，`@tool class_name PlayfieldBox extends ReferenceRect`
（形态沿用 `QuiverFightRoom`/`ShadowRegion` 的 ReferenceRect 惯例：编辑器拖框、
`Engine.is_editor_hint()` 守卫运行时逻辑、`QuiverEditorHelper.disable_all_processing`）。

**几何语义**：框矩形（段局部坐标，节点自身 position 必须为零——R13 执法）
= **可移动区的闭区间**；四条实体墙带矩形**外贴**（占 `rect ~ rect+band_depth`），
不吃可行走面积。角色停于边界线=旧"站在地板线上"语义的忠实替身。

**导出面**

| 导出 | 默认 | 语义 |
|---|---|---|
| `band_depth: float` | 400 | 墙带外延厚度（致死击飞 ≤2000px/s ≈ 33px/拍，400 深冗余封锁） |
| `gen_bands: bool` | true | 生成四边实体墙带（配方 `collision_layer=16760832`、`mask=0`——与 R7 同配方；运行时生成**不落 .tscn 文本**，校验器管辖外，防被手改） |
| `north_wall / south_wall / east_wall / west_wall: bool` | true | 单边关闭开关（北界常交相机动态带接管时关，避免"场上无因停步"雷，见 §五） |
| `gen_vis: bool` | true | 运行时生成地板/边沿色块（`z_index=-10`，Vis 惯例；不入文本=投产无需删） |

**运行时行为**（`_ready`，非 editor hint）：
1. 自身 `add_to_group(&"playfield_box")`；
2. 依开关生成墙带子节点（命名 `BandNorth/BandSouth/BandEast/BandWest`，
   StaticBody2D+CollisionShape2D RectangleShape2D）；
3. `gen_vis` 时生成 `VisFloor/VisEdge*` Polygon2D 子节点。

**编辑器行为**：`_get_configuration_warnings()`——anchors 非默认或 scale≠1 时黄字
"盒矩形坐标系将失配（R13②）"；`border_color` 保持 ReferenceRect 默认可见。

**明确不做**：不碰阴影组（用户裁：ShadowRegion 为平级家具，默认不摆；盒不注册
shadow_region——两功能间无任何暗线）。

## 三、校验器修法（`tools/stage_validator/validator.gd`）

| 规则 | 旧文 | 新文 |
|---|---|---|
| **R3** | 房必须含 ≥1 检测器且 ≥1 生成器（红） | **降为 NOTICE 警告**（"房未被任何检测器触发/无波次=空特写房，允许但注意解锁缺口"），不列违例数 |
| **R4** | 检测器 room 路径与 spawner 列表**都**非空（红） | 拆两条后果核对：①**哑检测器红**——检测器 `path_fight_room` 空**且** spawner 列表空（触发了无人应答）；②**孤儿生成器红**——段内每个生成器必须被 ≥1 个检测器 `paths_enemy_spawners` 引用（复用 `_resolve` 反查表），否则波永不刷+壳实源集缺员=**推进死锁**（这才是当年 R4 想防的真危害） |
| **R9** | 同一 spawner 被 ≥2 个**房**的检测器共引=红 | 判据去"房"化：同一 spawner 被 ≥2 个**检测器**共引=红（无房带纳入管辖） |
| **R13**（新立·盒轨） | — | 管辖=含 `playfield_box.gd` ext_resource 的段文件：**①盒唯一**（>1 红：双盒=模型破产）；**②盒守坐标系契约**（盒节点出现 `anchor_*`/`scale` 非默认属性行=红；缺行走默认
 anchors=(0,0,0,0)+scale 单位=合规——ReferenceRect 是 Control，矩形=段局部坐标全靠
 anchors 保持默认、offset 四值即盒矩形（雷区 a 同源语义），勿按 Node2D position 理解）；**③入口在盒**（`entry_points` 各值 ∈ 盒矩形闭区间，红）；**④房越盒警告**（任一 FightRoom 矩形超出盒界→NOTICE：锁房全景时界外可见不可走，多为摆错）；旧形段（无盒）不查=兼容通道 |
| **R7** | 全树 StaticBody2D 配方核对 | **一字不改**（旧形手摆几何继续合法；新盒墙带运行时生成不在文本域，天然豁免） |

fixtures 新判例（`expect=` 声明制）：`box_ok_seg`（绿）、`box_double`（R13）、
`box_anchored`（R13② anchors 非默认）、`box_entry_outside`（R13③）、`no_room_band`（**绿——房
demotion 核心判例**：检测器无房+有 spawner 合法）、`dumb_detector`（R4）、
`orphan_spawner`（R4）、`room_untriggered`（绿+NOTICE，R3 降黄判例）、
`shared_spawner_no_room`（R9）。
`--fixtures` 声明制即红/绿闭环，另按 R8 惯例手术前先出一档红据归档（旧校验器跑新
fixtures：`no_room_band` 必红 R4=形状法还在的铁证，修法后绿）。

## 四、段模板 v2（`scenes/chapter/segment_template.tscn` 重造）

```
StageSegment (StageContent，metadata 配方注重写)
├── PlayfieldBox        ← 第一件：拖框=可移动区（范本 x:-80..2000, y:-280..600）
├── Room1 (房三件套形)  ← 形态A示范：锁房特写战（房+生成器+检测器 path_fight_room=".."）
├── Encounter1 (遭遇带形)← 形态B示范：Node2D 带容器内含检测器（path_fight_room 空）+ 生成器（触发线色块 VisEncLine 挂段根）
└── VisSign 等
```
- **删除** `GroundBody/WallL/WallR` 与 Vis 场地件（盒派生接管）；
- 遭遇带的**生成器与检测器同挂 Node2D 带容器**（容器挂段根；非房 Control 子→
  普通 Node2D 坐标语义，雷区 a 不适用，`path_spawn_parent=../../../../Players`
  四级白名单从生成器起算恒成立）（实施勘误：原稿"生成器直挂段根"四级路径解析越界、
  运行时静默 null=刷怪裸崩，挂检测器之下又会被 one-shot 自删吞掉=推进死锁，
  见 ledger/T3 报告 §五.1 Ruling）；
- 过场/占位段配方更新：删两件留盒+`auto_complete=true`。

## 五、实证雷区增补（入法典第二章）

- **k. 盒南北界与相机动态带是两层墙**：相机 ScreenLimits 上下带跟随视口（锁房 zoom-fit
  时=房矩形，常态=可视高），盒南北墙是静态外贴。**可走竖界=两者较紧者**。盒竖向范围
  大于常态视口时，角色会先撞相机的"隐形场界"（无感停步，0.5 验收"上下边缘 2/3 档"
  即此）——盒墙在视野外则永不被撞（无害）；**盒竖向范围明显小于视口**时才会撞出
  "场上无因停步"观感（对策：关对应单边墙，或把房矩形铺满盒的可视诉求）。
- **l. 房矩形越出盒界**：锁房全景（zoom-fit 房）时界外地面可见但不可走——要么收房
  进盒，要么视为有意的"远景装饰"（R13④ 警告不拦）。

## 六、文档口径重写清单

- `docs/STAGE_ASSEMBLY.md`：0.2 步 4 改"摆盒（旧形手摆地墙降兼容通道，新段禁用手摆
  场地几何）"；0.3 加**遭遇带字段卡**；第一章**条 4 改写**（房=demoted 可选镜头/
  锁战家具，开战与战斗不依赖房）；新**条 17 盒轨**（R13 法源+§五两雷）；雷区补 k/l。
- `docs/guides/GUIDE_关卡搭建.md`：场地件表（82-84 行）重写为盒叙事；新"盒配方卡"
  （拖框→摆家具三步）；排障表"走路被弹开"行改口径（配方改不回=旧形专属；新形查盒框）；
  ShadowRegion 条目标注"**默认不摆**（无区域=全区域生成，盒即视觉边界），仅性能收口/
  局部去影时才摆"。
- 根 `AGENTS.md` Stage Structure 段的段结构图（`地面/墙 StaticBody` 行→`PlayfieldBox`）。
- `DEVELOPMENT_STATUS.md` 批条目；`docs/PLUGIN_ARCHITECTURE.md` **不动**（零插件改动）。

## 七、契约与验收

1. **box_contract**（`tools/box_contract/`，场景 runner，矩阵第 33 套/34 跑）：
   腿组——A 盒装配自证（实例化含盒段进法定壳：四墙带节点在位、配方 layer=16760832/
   mask=0、组注册）；B 行走封锁（test_actor 走到盒南/东界外不越界——速度清零/贴界）;
   C 击飞封锁（apply_knockback 起飞撞盒墙带反弹，不穿带）；D Vis 独立性（gen_vis
   关闭无装饰件、不影响物理）；E 兼容通道（旧形段照跑=不误伤）。
   **R8 体检红据**：术前拆墙带生成（注释掉）跑 B/C 红档；拆 R13②坐标契约执法跑
   validator 红档——归档后复原。
2. **stage_validator 套**扩 fixtures（矩阵既有条目，计数自然增长）；默认模式须
   证明 ref/demo 现有段零新红（孤儿生成器检查上线前，先跑一遍盘点存量——若 ref 段
   存在历史孤儿 spawner，属**真死锁存量**，修复而非豁免）。
3. stage_contract / control_contract 等其余 31 套不动语义；终核全矩阵 34 跑 RED=0。
4. **F5 验收（用户）**：在 `xuanyuan-chapter-1` 用新模板摆一段真实关——拖框、放怪、
   走盒界、锁房/遭遇两形态各验一次（这才是"盒搭建"的终审）。

## 八、裁决记录（本批已裁，含默认已裁）

| 决策 | 裁决 |
|---|---|
| 房 demotion 修法（R3/R4/R9 改写） | 用户"按需布局，为何限制"→ **裁：只罚死锁** |
| 旧段迁移 | 默认已裁：不迁移（法定锚+契约成本），双轨兼容 |
| ShadowRegion 与盒关系 | 用户"独立组件为什么不能往盒里放"→ **裁：平级家具，默认不摆（全区域回退=现行机制），盒零阴影暗线** |
| 盒南北墙 | 默认已裁：四边生成+单边开关（相机带双层墙事实写入法典雷 k） |
| 纯特写房解锁 | 默认已裁：本批不立项，法放行+机制缺口标注 |
