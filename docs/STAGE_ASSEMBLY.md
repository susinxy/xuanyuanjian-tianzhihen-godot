# 关卡装配指南（STAGE_ASSEMBLY）

> **5b 单轨定档（2026-09-28）**：`base_stage` 单地点轨已下线（stage_contract 142→126
> 转世壳形、validator base 臂退役、法定样板转世 chapter_ref_a/b 壳段四件）。
> 一切地点=章节壳+段。

> S1 立法的装配法典：**要造新地点 → 直接看第〇章食谱**；第一章装配十一条、后续各批
> 补充条款（至条 17）与第二、三章是干完活后的审稿清单。**新关卡必过校验器才有 F5 资格**（流程法律）：
> `godot --headless --path . -s tools/stage_validator/validator.gd`
> （在施章节可在目录放 `.wip` 空文件整树豁免扫描并打 NOTICE——执法针对成品地点，
> WIP 中间态不替回归矩阵红灯背书。）

## 〇、新地点食谱（先照此施工，再回下文审稿）

**总原则**：造一个正式地点**零新代码**——若发现"非改代码不可"，说明需求在 S1
能力面外（如互动触发件），回设计会立项，别在场景里手写胶水。

### 0.1 实例化 chapter_shell 即免费所得（什么都不用配）

| 能力 | 提供者 | 场景侧动作 |
|---|---|---|
| 壳树（Players/HudLayer{HUD+暂停+死亡休眠件+终点面板}/Ambient{CanvasModulate+KeyLight+Controller}/Segments） | `chapter_shell.tscn` 骨架 | 无 |
| 主角注入（`playable_override` 正门）+歧义/空场红护栏+`area2d:player` 身份链 | ChapterShell 三来源解析 | 放一个玩家档角色 |
| 跟随相机自动补挂（`camera_host_path` 可改挂+运行时 `set_camera_host`） | ChapterShell 相机服务 | 无 |
| 章级+段级检查点、死亡=段重跑、暂停壳回跳、读档落位 | ChapterShell+SessionRules+GameSave | 填 `chapter_id` |
| 段生命周期（判清自动推进、缓存复用/丢弃重建、chapter_finished 闩） | ChapterShell | 摆段+填 `segment_scenes` |
| 段内波次聚合解锁（房内 setup 扩权演出保留）+ segment_cleared | ChapterShell 实源并集 | 填对检测器（0.3） |
| 相机边缘全家桶：四面实体墙+四弹墙带+锁房收口钳位+zoom 归一 | `QuiverLevelCamera` + `QuiverFightRoom` | 挂房 |
| 高度层碰撞、阵营免伤、击飞/受击全套语义 | `QuiverCharacter` 运行时下发 | 无 |
| 昼夜三件套（空数据=自禁定格白天）+段入场 `lighting_color` 复位 | 壳 Ambient + StageContent | 可选挂 SceneTimeData |
| 软边阴影合成层（法定档 z=-1，专家覆写走壳根 `shadow_composite_override`） | `ShadowSoftEdge.derived_z_for` | 无 |
| 调试重载（debug_restart） | `ChapterShell._unhandled_input` | 无 |

### 0.2 每章节亲手做的事（5b 单轨装配序）

1. **建壳**：新建场景→把 `scenes/chapter/chapter_shell.tscn` **实例化进场景树**
   （实例化子场景即可）后另存 `scenes/stages/<章节包>/chapter_x.tscn`；壳文件
   两种合法出生=工程侧生成"根=壳实例"同构形 / 编辑器"场景另存为"拷贝形
   （R1 臂⑤承认，代价=模板升级不自动跟随）；
2. **壳根导出**：`chapter_id`（StringName 全局唯一，检查点主键——R2 执法）；
   `playable_override` 放主角（**推荐正门**：拖玩家档角色 .tscn；Players 下
   摆实例=来源②；多角色用 `playable_path` 裁决③——空场/歧义运行必红+R14 静态拦）；
   `segment_scenes`=段数组（顺序=推进序）；`camera_host_path` 一般留空；
3. **建段**：复制 `scenes/chapter/segment_template.tscn`（v2：盒+双形态示范）改件——`segment_id`
   （章内唯一）；`entry_points.default` **必须放第一检测线西侧前场区**（几何承重墙，
   雷区 i 的容器化；含盒段另受 R13③ 入口在盒硬查）；房三件套/遭遇带字段卡见 0.3
   （房与带容器均直接挂段根，生成器 `path_spawn_parent=../../../../Players`
   段挂壳 Segments 下恒 4 级）；
4. **场地几何=摆盒（盒轨批 2026-10-07，法源 spec 2026-10-07-playfield-box）**：
   段的第一件家具=拖 `PlayfieldBox`（`scripts/chapter/playfield_box.gd`，
   ReferenceRect 形制，范本 x:-80..2000、y:-280..600）——框矩形（段局部坐标，
   anchors 勿动，offset 四值即盒界）=**可移动区闭区间**；四边实体墙带+地板色块
   由盒**运行时派生**（外贴不吃可行走面积，配方 layer=16760832/mask=0 与 R7
   同款但**不落 .tscn 文本**，校验器管辖外）。单边可关（`north_wall` 等，北界
   常交相机动态带接管时关，雷 k）；`band_depth` 默认 400。**新段禁手摆场地几何**；
   旧形手摆地面/墙 StaticBody=兼容通道（仅存量段，R7 照管，ref/demo 不迁移判例
   在册，新段勿抄）。背景/道具摆段内（Background CanvasLayer `layer` 必须 <0，R10）；
5. **光照可选**：壳 `Ambient/DayNightController.scene_time_data`（起步件
   `resources/lighting/day_neutral|day_cycle_default.tres`，留空=定格白天；
   demo 档=60 秒快循环）；段根 `lighting_color`=入场画布色；性能需要时段内摆
   `ShadowRegion` 框（禁重叠，实配=seg_ref_b1）——细则见 docs/guides/GUIDE_光照.md；
6. **【合流】让章节可被进入**：试跑可临时改 `title_screen.gd` 的
   `GAMEPLAY_SCENE` 或在编辑器用 F6 单跑壳文件——**段文件不能单独 F6**（段里
   没有玩家），验完还原，不合流不提交；章与章的串接件=StageExit（摆段内，
   `next_stage_path` 指向下一章节 .tscn，参考 chapter_ref_a 段尾→chapter_ref_b）。

### 0.3 FightRoom 三件套字段卡（逐项来源=ref A/B 实测绿）

**房（ReferenceRect + quiver_fight_room.gd）**
- `offset_left/top/right/bottom` 与 `limit_left/top/right/bottom` **同值**（offset=编辑器可视、limit=运行时执法）；
- `zoom` 锁房全览缩放——照抄样板后 F5 校手感（validator 不管）；
- 战后扩权：`after_fight_use_new_room=true` + 四 `after_fight_limit_*`（串场活动区，通常向东扩）+ `after_fight_zoom` + `after_fight_transition_duration=0.8`；
- `preview_camera/preview_after_room=true` 仅编辑器预览着色。

**生成器（Marker2D + quiver_enemy_spawner.gd）**
- `path_spawn_parent = NodePath("../../../../Players")` —— **必改**（上游默认值是错的，R5 白名单唯一形，5b 单轨）；
- `spawn_waves = [[SD, SD, ...], [SD, ...]]` —— 外层=波序、内层=同波并发；SD 子资源形态照抄样板（`enemy_scene` 指真实存在的敌人 .tscn=R6；`spawn_mode=1`+`use_spawner_position=true`=参考默认，语义要调时查插件 Inspector 面板）；
- `position` 是**相对房左上角**的落点（雷区 a）。

**检测器（Area2D + quiver_player_detector.gd）**
- 掩码配方三件套：`collision_layer = 0`、`collision_mask = 16760832`、`monitorable = false`（雷区 b）；
- `path_fight_room = NodePath("..")`；`paths_enemy_spawners = Array[NodePath]([NodePath("../EnemySpawner1"), ...])` ——列**全本房**生成器，跨房重引=R9 红；
- `is_one_shot` 默认 true 可不写（重复触发房属未立法需求，先回设计会）；
- 触发线用竖 SegmentShape（样板 a=(0,-400) b=(0,700)），放点在玩家必经之路。

**遭遇带字段卡（无房合法形，盒轨批 2026-10-07；范本=段模板 v2 `Encounter1` +
fixture `no_room_band.tscn`——房 demotion 后的核心示范，条 17）**

```
段根
└── EncounterN（Node2D 带容器，位置随意——整条带可一拖就走）
    ├── Detector（Area2D + quiver_player_detector.gd）
    │   —— 三掩码配方同款；**不写 path_fight_room 行**（吃导出默认=空）=无房合法形
    └── EnemySpawnerN（Marker2D + quiver_enemy_spawner.gd）
        —— path_spawn_parent = NodePath("../../../../Players")（四级，从生成器起算恒成立）
```

- **带容器不可省**：生成器直挂段根+四级路径=运行时非法形（`get_node_or_null` 静默
  null→刷怪即裸崩；实施勘误实锤，见 T3 报告 §五.1 与 spec §四勘误注）；生成器挂
  检测器之下同样不行（`is_one_shot` 检测器触发后 `queue_free` 自己会连坐吞掉子树
  生成器→段永不判清=推进死锁）；
- 检测器 `path_fight_room` 空**且** spawner 列表也空=R4 哑检测器红；带内生成器
  不被任何检测器引用=R4 孤儿生成器红（波永不刷）；
- R13③ 入口在盒、R9 共引查重等对遭遇带一视同仁（判据已去房化）。

**光照与阴影（骨架预置件 + 可选 ShadowRegion）**
- `Ambient/DayNightController`：唯一要动的导出是 `scene_time_data`（null=自禁）；
  `point_lights_paths` 留给灯笼类场景道具（DUSK/NIGHT 自动开关）；
- `Ambient/KeyLight`：`shadow_enabled=false` **法典级禁改**（双重阴影）；无贴图=纯参数载体；
- `ShadowRegion`（ReferenceRect 挂脚本，可选）：阴影只留框内；**0 个=全屏回退、多框并集、
  重叠处双倍变暗禁止**；`debug_preview` 正式关卡保持 false（零绘制）；
- Background CanvasLayer 换件时 **layer 必须 <0**（R10+canary，≥0 连角色一起盖掉）。

### 0.4 复制改件（日常最快）

复制 `chapter_ref_a.tscn`+`seg_ref_a1/a2.tscn`（法定满配：两段串场+房×3+出口+
双敌聚合）→ 换名换 `chapter_id`/`segment_id`（撞键=检查点合并回跳错位）→
改几何/波次/出口 → 校验器。**纪律：复制免手续不免审稿——装配十一条+雷区仍逐条过**
（validator 只保红线，手感布局它不管）。
**新段一律以 `scenes/chapter/segment_template.tscn` v2 为底**（盒+锁房/遭遇带
双形态示范；ref 段是旧形手摆几何的存量兼容样本，勿作为新段场地几何的抄本）。

### 0.5 验收三件套

1. 校验器：默认扫 `scenes/stages/**`，你的地点出现在 `违例 0` 里；
2. 冒烟：`godot --headless --path . res://scenes/stages/<包>/<你的地点>.tscn` 跑 ~8 秒零 SCRIPT ERROR；
3. Windows F5：走/打左右墙（弹回+掉 5 血只在击飞时）、上下边缘 2/3 档、穿线开战、
   段全清→自动推进/章终点、死亡→段重跑复位、暂停回跳含本章。
   （新段（v2 模板底）此处验的是**盒界**：四边贴界停步、击飞反弹不穿带；
   左右实体墙+弹墙带现由盒运行时派生，文件里改不到——查盒框。）
（stage_contract 的 126 断言只绑 chapter_ref A/B 两台法定壳段样板（含 A负B正 光照
 对偶锁 LC 组）；新章节由以上三件套+回归时顺扫的校验器保护。）

## 一、装配十一条（校验器规则的法律来源；R8 随 5b 退役，R13 法源=文末条 17）

- [ ] **1. 相机=壳的服务（5b 起自动）**：壳解析主角后自动补挂 LevelCamera
      到其名下并掌电流；`camera_host_path` 可改挂任意节点（演出段跟 NPC），
      运行时 `set_camera_host()`；limit 初值给宽，由 FightRoom 运行时收束。
      （单地点旧制"装配者手挂相机"随 base_stage 退役。）
- [ ] **2. 检测器三导出显式填**：`path_fight_room=NodePath("..")`、
      `paths_enemy_spawners` 列全本房生成器、`is_one_shot=true`；
      身份判定走 `area2d:player` 组（本项目已迁，勿再找 `players` 组）。
- [ ] **3. 生成器必改 `path_spawn_parent`** = R5 白名单唯一形（5b 单轨）
      `../../../../Players`（段挂壳 Segments 下恒 4 级）——上游默认值
      `../../Characters` 是错的，base 三级形已退役。
- [ ] **4. 碰撞配层走高度层**：Collisions 的 StaticBody `collision_layer` 配
      高度层（全段=16760832，bit15-24），**障碍层 2 允许出现**（校验器 R7
      只执 12 位）；**禁手配旧层 3/4 掩码**（屏限/顶限归相机高度层，由
      LevelCamera 运行时接管，上游旧制勿抄）。盒轨批注：新段场地几何=摆
      PlayfieldBox（墙带运行时派生不落文本，本条 R7 只照管旧形手摆几何/存量段），
      房 demotion 见条 17。
- [ ] **5. 波次数据形态**：`spawn_waves` 用插件自定义 Inspector 填
      （波=QuiverSpawnData 数组）；敌人场景引用必须盘上存在（校验器 R6）。
- [ ] **6. 检查点约定**：壳根 `chapter_id`+段 `segment_id` 双键，进章/进段即以
      (chapter_id, scene_path, segment, entry) 自动注册；回跳=重载场景+段级落位，
      死亡=段重跑（D4），无多入口标记体系（YAGNI）。
- [ ] **7. 多生成器聚合读检测器导出**：ChapterShell 段接线期据
      `paths_enemy_spawners` 并集建实源集，全 `is_completed` 才段判清——
      `setup_after_fight_room()`（房内扩权演出保留）+ `segment_cleared` +
      自动推进——场景连线表达不了"与"逻辑，**禁逐房手写胶水**。
      （base 房级 room_cleared 聚合随 5b 退役。）
- [ ] **8. 推进机制只有三种**：房→房 = after_fight_limit 扩权步行串场（同段内）；
      段→段 = 段判清自动推进（壳构造）；跨章 = StageExit 触发件
      （`next_stage_path` 指向另一章节 .tscn；**必须摆在永不判清的过场段**，
      参考 seg_ref_a3——末段判清即弹面板冻结，出口失效）。不设第四种。
- [ ] **9. 背景负档+光照空禁**：段内 Background CanvasLayer `layer` 必须 <0
      （R10 文本执法；BaseStage runtime canary 随 5b 退役）；昼夜三件套壳骨架预置，
      `scene_time_data` 留空=自禁定格白天（装配合法态，非违例）。
- [ ] **10. 互动触发件走通用件（S2-M1-B2 开账，R11 执法）**：段内 E 键互动一律
      实例化 `scenes/chapter/interact_trigger.tscn`（`InteractTrigger`），**禁手写
      Area2D+按键胶水**。装配五条：
      ① **触发件挂段内**——它是 StageContent 的子节点（不挂壳、不另起节点），
        感应盒世界坐标即落位点；`_ready` 自配 `collision_mask` 全高度层 +
        `monitorable=false`（雷区 b 同款掩码配方），无需装配方填；
      ② **感应形状必有实体矩形**——触发件本体自带 160×160 `RectangleShape2D`
        （`Shape` 子节点），**零宽/缺形 = 不可交互**（发丝线不判交判例的交互侧翻版）：
        校验器 **R11** 对"script 尾缀 `interact_trigger.gd` 却无 `CollisionShape2D`
        后代"的节点直接红（instance 引入的触发件形状在其本体文件自证，不误伤）；
      ③ **入口与触发件同址要 ≥2 帧后判在距**——落位屏蔽窗（R8 同族）内 Area 检测
        尚未对既成重叠结算，装配上"进段即期望 interacted"是错的，反应件须等
        `body_entered` 计数稳定（契约 I 组按此设时序）；
      ④ **旗标门经壳 session**——`requires_flag` 非空时触发件走
        `find_shell().session.has_flag()` 判定，无旗**静默拒发**（不吃键、不置消耗）；
        （R11 只证"形状存在"；disabled/零尺寸形状=可过校验但不可交互，归 F5 肉眼契约。）
        解锁靠别处 `session.add_flag(同旗)`，段间旗标随壳 session 存续；
      ⑤ **反应件是 trigger 子节点、连 `interacted` 信号**——宝箱/NPC 对话/门等
        反馈逻辑挂为 InteractTrigger 的子 Area/Node，`_ready` 里
        `get_parent().interacted.connect(...)`，一次性反应在链尾显式
        `get_parent().consume()` 收口（Prompt 永久隐身 + 后续 E 不再响应）。
      ⑥ **反应件重演语义三分（B2 定档；B4 改判注：重演语义已改判为"新档=清账"，spec §2——
        重跑/回跳/换章/重载一律不碰账，唯一清账口 `new_profile()`；本三分形态不变，
        判据主语换成"账保留下的缓存复用/丢弃重建"，规程见条 11）**——同段被"判清缓存摘树"后重入：
        宝箱=session 真值（可重演按开过处理，零副作用）；**缓存重入的宝箱段其实已无
        宝箱节点**——成功链尾触发件自 `queue_free`，重入靠 session 旗标而非现场物件。
        门=**赢链消耗后静默**（非 repeatable 触发件首次 emit 即 consume，缓存重入时
        E 已死、门体保持开启，无从"再按可再开倒计时"）；仅未判清腿走**丢弃重建**
        才可再演。repeatable=true 有双推跳段雷（首链落位后第二枚倒计时又推进已 settle
        的新段），此雷已由 `InteractGate._armed` 闩封死（每实例至多开一次倒计时）；
        **循环类（QTE 族）=判清后永久哑**（出树即终门）。另注：**勿把 QTE 放在章节
        终点段**——成功时先 `_phase=DONE` 再 `force_advance_current`，终点段无后继
        （F-2）推进失败→无落位无链、钟恒 DONE、段永不清，"悲剧只延迟不否决"沦为
        永久否决；非要放须监听 `segment_advance_failed` 回拨相位（DONE 闩另见本条门段）。
        给同一**段**叠加 QTE 与任何其他判清路（auto_complete/检测器/spawner 聚合）
        的作者**必须书面声明期望哪种重演**，否则循环钟语义由 QTE 侧抢先判清说了算。
      出口语义不变：互动件**不是**推进机制（条 8 的 StageExit / 段清链才是），
      它只驱动"宝箱开/对话起/机关动"这类会话状态反应。
- [ ] **11. 内容件挂账与申报（S2-B4 开账，R12 执法；账本纪律见根 AGENTS「账本纪律法」
      与 spec §2/§3）**：装配者三步规程——
      ① **选账本户**——一切要跨存档记住的事实只经 GameSave 门洞写
        （`record/has_record/ids`，销账只走合法销账门洞 `erase_record`：测试复原/
        未来剧情复位）；既有户表 = `flags / chests / cleared_segments / spells_known`
        （系统户由 GameSave 自开）；新内容类型要新户必须先
        `GameSave.claim_namespace(ns, owner)` 开户——未开户写入=push_error+拒写（S 流锁）；
      ② **新内容件挂基类填申报单**——反应件挂 InteractTrigger 子节点并 extends
        `InteractReaction`、如实填 `save_claim()`（persists=写入的户 / resets=豁免户）；
        填表思考工具=spec §2.1「判定三连问」（游玩中会变吗/不存能推导吗/重演能接受吗），
        申报理由写件头注；忘挂基类/忘申报=X 流②静态红，每类必须被 G/R/E 至少一根腿
        点名=X 流③报表执法；
      ③ **validator 自查**——R12 执"章节轨内反应件账本键非空（chest_id / spell_id；
        manual_id 若设则为账本键、空=回落 spell_id）+ **同户**全章唯一"：两件争一笔账=红；
        **跨户撞名不算撞**（chests 的 `ch_a` 与 spells_known 的 `ch_a` 各记各账，
        r12_ok_seg_b 夹具钉死判例）。
       附注：判项表（什么存什么不存的总表）以 spell_save_contract **X 流③运行时打印**
       为准，**本文档不手抄**（防漂移，spec §2.1"文档是报表不是公约"）。
       **B4.5 读档三通道装配面（T4 补注）**：读档=「死亡重跑/暂停回跳/读档」三通道
       共用同一检查点数据的第三通道（spec §4）——装配者义务**零新增**：段内入口标记
       `entry_position` 的契约不变（读档落位吃的就是它），段场景文件路径由壳自动记入
       检查点（`enter_segment` 生产行），无需装配登记。**秘籍件值维语义一句话**（B4.5-T4
       立法）：`manual_id` 分户时账本**键=拾得事件（户名）、值=教什么（spell_id）**——
       重建节点补学经 `GameSave.value_of` 值优先回落键解析科目，故分户件必须如实填
       `spell_id`（R12 户名查重口径不变）。

## 二、实证雷区（S1 施工期尸检报告，逐条真踩过）

- [ ] **a. FightRoom 是 Control**：其子节点（检测器/生成器/落点 Marker）坐标是
      **房局部坐标**，世界坐标 = 房间 offset + 局部值。按世界坐标直填 = 检测器
      飘出房外、玩家永远踩不到触发线。
- [ ] **b. 检测器/出口件掩码配方**：`collision_layer=0`、
      `collision_mask=16760832`（全高度层，玩家身体动态持有）、
      `monitorable=false`。少一项检测器静默失灵（玩家组 body 进不了区域）。
- [ ] **c. Collisions 静态件不带屏/顶旧位**：标准配方 `collision_layer=16760832`、
      `collision_mask=0`，**不带旧位 4/8**（屏限/顶限）——二者会让高度层过滤
      逻辑（`_update_collision_layers` 的掩码保留策略）产生双重身份；
      障碍位 2 允许出现（校验器 R7 只执 12 位）。
- [ ] **d. 生成器换基契约**：`QuiverEnemySpawner` 把敌人场景根 cast 为
      `QuiverEnemyCharacter`——**任何可刷敌人的脚本必须 extends 它**，否则运行期
      静默不刷。多实例敌人须在 `_ready` 里 `attributes = attributes.duplicate()`
      防共享资源互踩血量。
- [ ] **e. 纯水平 launch 即刻触地**：击飞向量竖直分量为 0 → 生成当帧就判"已落地"
      进 Bounce 而非滞空；测试敌人死亡要给带竖直分量的向量（如
      `Vector2(0.866, -0.5)`）。
- [ ] **f. 浅杀不死**：只把 `health_current=0` 的敌人**不会走死亡演出链**，
      spawner 的 `tree_exited` await 挂到场景 teardown 才放行；真击杀必须过
      `CombatSystem.apply_knockback`（扣血+致死强飞→弹地→Die→离场）。
- [ ] **g. 同场景重载骗轮询**：检查点回跳原地点时 `scene_file_path` 全程不变，
      按路径轮询必假绿；要盯**实例 id 更换**（`get_instance_id()` 比对旧根）。
- [ ] **h. 先校验后 F5**：装配完的 .tscn 先跑上文校验器命令（0 违例），再进
      编辑器 F5。新装配未过校验器 = F5 免谈。
- [ ] **i. 锁房收口已机制化（2026-09-19 批）**：过渡完成时界外玩家被插件
      自动钳回（矩形=房界外扩 40，与墙外挪 60 联动定档，m=−40），装配侧无需为
      "扫掠吞人"负责；但**出生点落在首房界外**（参考关 A/B 的 300<380 即如此）
      时，玩家首次锁房结束会被拉一把位置——不想要的装配就把出生点摆进首房左界
      之内。隐形墙三连修（mask 双向/左右实体/_ready 初帧定位）+墙面外挪（贴墙
      出镜 3/4 身=设计定档）背景见 PLUGIN_ARCHITECTURE 相机章。
- [ ] **j. 关卡侧"伤人弹墙道具"若用 WallHitBox：带内墙外、轴匹配、带领先量**。
      弹墙带（Area）必须摆在实体墙（StaticBody）的场内一侧且领先 ≥2 物理帧行程
      （相机四带的定和公式 b+O≥74 分横竖两档：左右 b=20/O=60 和 80（贴横墙 3/4
      出镜=定档）、上下 b=45/O=30 和 75（深度轴收紧到 2/3））——带墙同心时，
      撞墙清零先于带命中，
      镜像拿到恒 0 输入；`mirror_axis` 按墙面朝向配（竖墙 UP、横墙 RIGHT）。
      参考实现=quiver_level_camera；几何锁=knockout_contract D8。
- [ ] **k. 盒南北界与相机动态带是两层墙**（盒轨批，法源 spec §五）：相机
      ScreenLimits 上下带跟随视口（锁房 zoom-fit 时=房矩形，常态=可视高），
      盒南北墙是静态外贴，**可走竖界=两者较紧者**。盒竖向范围大于常态视口时，
      角色先撞相机的"隐形场界"（无感停步，0.5 验收"上下边缘 2/3 档"即此）——
      盒墙在视野外则永不被撞（无害）；**盒竖向范围明显小于视口**才会撞出
      "场上无因停步"观感（对策：关对应单边墙 `north_wall/south_wall`，
      或把房矩形铺满盒的可视诉求）。
- [ ] **l. 房矩形越出盒界**（盒轨批，法源 spec §五；R13④ 黄判据）：锁房全景
      （zoom-fit 房）时界外地面可见但不可走——要么收房进盒，要么视为有意的
      "远景装饰"（黄警告不拦）。段模板 v2 的 Room1 已收界进盒（bottom 600）。

## 三、上游禁抄项（template-beat-em-up 旧制，本项目已有替代）

- 屏限/顶限手动配层（层 3/4）→ 已死，见一-4；
- 每房手写 `all_waves_completed` 胶水（stage_01.gd 模式）→ 已死，见一-7；
- `$Level/Characters/Chad` 硬编码取玩家 → base_stage 运行时查 `area2d:player`；
- main_menu 转场动画 method-track 驱动 → S1 起按钮直连，动画经 `opened/closed`
  信号解耦（spec §4.6 视觉契约）。

## 接管批补充条款（2026-10，被控角色系统）

- **条 12** 段申报制（读法一）：段根 `control_target_path` / `camera_host_path`
  非空=入场即应用（**先接管后落位**：入口点写给了新被控者，旧体原地留守）；
  留空=回正（被控者=壳初始申报体，相机=跟被控者）。跨段连控=逐段申报，
  幽灵延续结构性不可能。申报路径解析域=段树。
- **接管=行为维度**：阵营标签（出身）不随接管迁移；`area2d:player` 身份暗号
  退役为**回落形**（无 controlled 组的单跑/Run-Test 场景兼容用）。身份唯一
  权威=壳 `playable` 引用 + `&"controlled"` 活性组（壳维护，只挂角色根）。
- **悬垂交接守卫**：未判清段丢弃重建会带走段内接管目标——回正/接管链对已释放
  旧体免疫（`is_instance_valid` 判据；control_contract C4 抓获定档）。
- **敌兵接管=技术可行、体验待设计**：出身 enemies 标签的互免关系不随控制转移
  （被控敌兵打不动敌营也挨敌营打不了），夺舍类玩法需专门阵营敌意设计批，
  勿在段里手改标签绕。

## 锚点批补充条款（2026-10，终局锚点/护送机制）

- **条 13** 终局锚点申报：段根 `defeat_anchor_path`（段内解析，**段申报优先**）
  与壳根同名导出（全程兜底，按壳树路径写）声明"剧情不能死的人"——其被击飞致死
  与**被控者之死同闸**（慢放+终局+回检查点重跑；败北集合=锚∪被控）。皆空=仅
  被控者算败北（默认形态现状零漂移）。运行时 `add/remove_defeat_anchor` 临时态，
  入场即被下一段申报重刷（读法一同款申报驱动）；锚点随未清段重建还魂=重挂自愈。
- **护送关零代码配方**：段申报锚 +（可选）敌人 `ai_target_groups` 含
  `defeat_anchor` 组=怪攻护送对象。索敌/接管/锚三维度正交，自由组合。
- **条 13b 慢放集申报**（2026-10 死亡演出批）：段/壳 `death_slowmo_paths` 数组
  声明"死了值得给一段慢镜头的人"；**空=跟随结算集**（默认两事件同角色）。待遇、
  败北两功能各自成集；判定在致死击飞（或非击飞死亡的 die 入场）瞬间一次性写
  凭据，换段改集不回改已开的凭据。
- **条 16 相机随段清算**（2026-10 G6，用户灰屏事故定罪）：锁房/战后扩权改的
  limits/zoom 属**本段局部约定**——每段入场，壳在申报应用前 `reset_room_lock()`
  （kill 在途 tween+五值回初值，弹墙带自动跟随）。旧形态跨段残留把新段落位者
  "质在界外"=画面纯灰+人"消失"。禁止段脚本自行改相机边界跨段存活。

## 捞人批补充条款（2026-10，用户 F5 纯灰事故定罪）

- **条 14** 被控者段生命周期豁免（不变量）：**被控者永不随段离场**——段移除
  （判清缓存保活 / 未清丢弃重建两腿）之前，壳先把挂在段树内的被控者（含其身上
  reparent 的相机）捞回 Players（保全局变换）。接管段内 NPC 后判清换段/死亡重跑
  均不得出现"角色消失/镜头虚空/输入死"（control_contract C14/C15a/b 三腿锁，
  修前红据 S6 四档=事故复刻原件）。重建段同名新体由申报接管=合法孪生
  （旧获救体让位旁观，不持 controlled）。
- **条 15** 判清账章维度：`cleared_segments` 键 = `chapter_id/segment_id`
  （GameSave.mark_cleared/is_cleared 带 chapter 形参；省略=旧纯键兼容形）。
  段 id 仅章内唯一（R2），纯 id 全局键=跨章串扰（章二清过的 seg01 令章一误判
  已清→缓存腿错走/终点误弹）——C15b/C15c 双腿锁；旧档纯 id 判清记录一次性作废
  （开发期无实档负担）。

## 盒轨批补充条款（2026-10-07，PlayfieldBox 与房 demotion）

- **条 17 盒轨（法源 spec 2026-10-07-playfield-box；校验器 R13 执法）**：
  **法理两行**——①校验只罚**机械死锁/静默失败**（双盒、坐标系失配、入口穿墙、
  哑检测器、孤儿生成器、共引争波），**不罚配方形状**（摆不摆房、锁不锁镜、
  刷不刷遭遇怪完全自由）；②**房=可选的特写镜头/锁战家具**，开战与战斗不依赖房
  （R3 降黄=纯特写房合法、R4 接线化、R9 去房化三改同批，见 0.3 遭遇带字段卡）。
  **R13 四查**（管辖=含 `playfield_box.gd` 的段文件，旧形无盒段不查=兼容通道）——
  ①**盒唯一**（>1 红：双盒=模型破产，一段一界）；②**坐标系契约**（盒必须直挂
  段根；盒节点写 `anchor_*`/`scale`/`position` 行=红：ReferenceRect 是 Control，
  矩形全靠默认 anchors+offset 四值=段局部坐标，雷区 a 同源；零面积盒红并早退）；③**入口在盒**
  （根 `entry_points` 各值须落在盒矩形闭区间，红：落位必穿墙带）；④**房越盒黄**
  （任一 FightRoom 矩形超出盒界=NOTICE：锁房全景时界外可见不可走，雷 l，多为
  摆错但不拦）。盒导出面与墙带派生语义见 0.2 步 4；组件契约细则在 spec §二
  （`band_depth` 默认 400、`gen_bands`/四单边开关/`gen_vis`，均运行时派生不落文本）。
  纯特写房的自动解锁时机=机制缺口，本批法放行、待立项（spec 非目标）。
