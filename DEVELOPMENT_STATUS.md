# 开发状态说明

> **生效日期**: 2026-08-11
> **最后更新**: 2026-09-18

## 决策：xuanyuan-sword 正式从零开始

本目录（`xuanyuan-sword/`）下的已有工作**全部视为阶段 1-4 的学习验证产物**，**不作为正式游戏代码的基础**。

| 已有文件/目录 | 处置 |
|---|---|
| `legacy/` | 保留为学习资料存档，不要复用 |
| `characters/playable/chen/` | **模板之源**（2026-08-16 重建，2026-09 起为 `_template` 快照之源）。完整状态机 + 高度层碰撞 + 通道化输入（见"角色体系补全"） |
| ~~`characters/playable/chenjianchou_new/`~~ | 已移除（工具开发期临时角色） |
| ~~`characters/playable/enemy/`~~ | **已退役**（2026-09-14，"魔法替身"旧敌人；职责由 AI 档正式角色 `characters/enemies/spar_enemy/` 承接） |
| `characters/enemies|allies|neutrals/` | **正式角色内容资产，进 git**（创建器按阵营输出；`spar_enemy`=Run Test 常驻陪练，勿删） |
| ~~`scenes/test_stage.tscn`~~ | **已随 S1 重建退役**（2026-09-18 删除）：正式地基 = `scenes/base/base_stage.*` + `scenes/stages/ref/` 参考地点 A/B |
| `addons/quiver.beat_em_up/` | **保留**；上游快照 + 本项目独立扩展（碰撞重构、单壳行为脚本、蒙版/轮廓/缩放工具链等，权威描述见 `docs/PLUGIN_ARCHITECTURE.md`） |
| `docs/` | **保留**，内含学习资源链接和 README |

## 已完成的工作

### 碰撞系统重构（2026-08-16）

- 删除 `character_type` 枚举和 `QuiverCollisionTypes` 碰撞预设系统
- 统一使用高度层（layers 15-24）作为物理检测通道
- 统一使用 faction group（`area2d:` 前缀）作为逻辑过滤机制
- QuiverLevelCamera 添加四方向屏幕边界碰撞（使用高度层 bitmask）
- 墙壁反弹系统改用 `area2d:wall` faction group 控制

### 角色重建（2026-08-16）

- `chen_jingqiu/` 角色已重建，继承 `quiver_character_base.tscn`
- 完整状态机（Ground/Air/Die），HurtBox/HitBox 配置正确
- 使用高度层碰撞系统，无需手动设置 combat layer

### 测试场景增强（2026-08-16）

- 测试场景模板支持自定义攻击数据、敌人朝向、combo 模式
- 墙壁反弹测试验证通过
- 高度层碰撞可视化调试工具

### 轮廓转换工具系统（2026-08-17~20）

- Inspector 面板新增轮廓转换功能，支持三种碰撞形状：Polygon（精确轮廓）、Capsule（MABR 推导胶囊）、Rectangle（MABR 推导矩形）
- ContourTracer 静态工具类：轮廓提取（BitMap API）、MABR 算法（O(n²) 凸包投影）、形态学腐蚀（去除武器/披风突出）
- MaskEditorDialog 交互式蒙版绘制工具：3 种蒙版类型（Generic/Body/Attack），SubViewport 绘制，轮廓预览
- AnimationTrackInjector 轮廓转换管道：13 步统一流程，场景树操作替代直接写文件，用户 Ctrl+S 统一保存
- Height Layers Widget UI：双参数集（预览/转换独立）、异步执行、SubViewport 渲染预览
- chenjianchou_new 角色已通过 Polygon 模式生成 body/attack 碰撞形状数据

### 法术系统（2026-08-22~23）

- SpellDefinition / SpellSlot / SpellManager / SpellBase / SpellSkin / SpellSkinAnimTree
- 模板创建 Inspector（5 步管道 + 程序化动画生成）
- 轮廓转换 Widget（attack only）
- fire_ball 示例法术（碰撞验证通过）
- 输入映射 spell_1/2/3/4（数字键 1-4）
- QuiverAttributes 扩展（mana + Modifier 系统）
- QuiverCharacter 新增 3 个 public static 高度层方法
- QuiverHurtBox 命中通知（hit_box.owner.on_hit）
- UID 冲突问题已修复（.uid 排除 + 嵌入 UID 剥离）
- 角色集成 SpellManager（进行中）

### 角色资产生产线（2026-08-24 ~ 09-14）

- 阴影渲染系统（ShadowBox 投影 + 软边 + 区域裁剪 + 灯笼点光）
- 轮廓转换工具体系增强：帧级标记（`.mask.png`/`.no.png`）、蒙版母版双写、
  PNG 缩放管线（母版 960→成品 288、账本、同构校验）、双栏预览、内嵌图片浏览器
- attack 数据结构治愈 + chen 资源重排（`attack1|2|3/{up,down,right}/` +
  `{动画名}_{槽号}.png` 命名规范，362 帧三方对齐）
- 角色模板基座切换：`_template/` = chen 占位符化快照（`tools/sync_template_from_chen.py`
  幂等刷新 + 污染守卫断言）

### 角色体系补全：单壳 + 行为脚本（2026-09-14，WP1-WP3）✅

- **WP1 输入通道**：每角色私有 `QuiverInputChannel`（摇杆+按住表+帧戳边沿），
  状态机拆除物理键盘 OS 监听改 `deliver_event` 注入口，玩家/AI/被动三种行为脚本
  （`characters/behaviors/`），`behavior_mode` 导出 + `switch_behavior()` 操控权
  交接接口——键盘串台漏洞结构性灭绝，连段/空攻窗口对玩家与 AI 同构
- **WP2 生产线**：创建器"控制方式"三档 × 阵营联动（`CharacterCreator.resolve_layout`），
  阵营包目录 enemies/allies/neutrals 进 git，默认策略小抄随模板出生
  （约定路径 `<场景名>_ai.gd` 自动加载），Run Test 编排器 `QuiverRunTestSceneBuilder`
- **WP3 旧敌退役**：魔法替身 enemy 整目录删除；正式验证角色 `spar_enemy`（AI 档，
  headless 实测逼近 450→90px 并打出伤害）与 `street_vendor`（被动站桩）入库
- headless 断言 71 项全绿（17+30+6+13+5）；详见 `docs/PLUGIN_ARCHITECTURE.md` 5.0

### 法术键权与施法动作（2026-09-15）✅

- **键权修复**：光照调试相位键 1-4→5-8，数字键 1-4 只属法术；法术测试助手
  重构为"注入脚本"（只教给被测角色，单消费者），并留引擎级双消费者回归锁
- **施法动作系统**：`SpellDefinition.caster_cast_time`（循环动画锁时长、到点出手、
  0=瞬发向后兼容）+ 游戏层自定义状态 `QuiverActionCast`（攻击同款骨架无连段，
  chen/模板均已挂，新角色出生即有）+ 法力起手扣、打断不退还 + 空中拒施
- **契约测试顺带挖出并修复三个存量静默 bug**：
  1. 状态白/黑名单拿全路径比短名（死亡免施禁令从未生效）→ 改任意段匹配
  2. 法术从未真正继承施法者阵营（根节点无 area2d 组 + typed 调用绕过
     add_to_group override 双重原因）→ 后代扫描 + 插件公开
     `add_faction_group()`；表现为法术贴身自伤施法者
  3. 出手方向/体型读取硬走 `get_node("Skin")` 路径（chen 实名 ChenSkin）→
     恒默认右 → 改 `_skin` 公开引用，并升级四向出手（上/下/左/右同攻击）
- 详见 docs/SPELL_CAST_PLAN.md、docs/SPELL_SYSTEM_DESIGN.md 阵营修订、PLUGIN_CHANGES.md
- **验收反噬复盘（同日）**：程序化组装 + 直注通道的测试全绿，真实场景却按 1
  无反应——定罪出第三个真 bug：**引擎未处理输入流不广播 InputEventAction**，
  行为盖戳只认该类 → 真键盘法术键自单壳改造起从未生效（AGENTS 记两条陷阱：
  未处理流事件形态；headless 测试必须含 OS 注入全链路断言）。修复后
  helper_e2e 新增 `_os_key_full_chain` 回归锁
- 法术模板晋升（2026-09-16）：fire_ball 真帧快照经契约体检进 spells/_template；
  随附三层修复（出手点 release_ratio 数据化、轮廓面积降序契约、体检复活）与
  法术侧 sync 工具 tools/sync_spell_template_from_fireball.py（详见 fix 8fa600d 与模板 README 契约段）
- 阶段 2.5 两段式（同日）：起手=角色资产必完整播（尾帧信标）、引导=法术计时；
  chen 真帧美术完成并经 F5 验收，已 sync 进模板；总线机制复核维持通用通道（单听众结构性保证，专用信号否决留档）
- 发令台迁入 `QuiverRunTestSceneBuilder.compose()` 统一注入（法术测试场景
  曾被遗漏：chen 被陪练白打死且无法暂停）；法术面板 NOT FOUND 修复
  （解析重试 + 弃用实名皮肤路径）；法术体不再复制 players/enemies 阵营包组
  （防按组查询污染，此前面板把火球当角色直接赋值崩溃）
- **阶段 2（同日完成，用户 F5 验收通过）**：施法者 `spell` 动画槽（四点混合暂指
  单一动画+占位循环，已 sync 进模板全员出生即有）；法术体四向（SpellSkin 方向
  向量四正量化、fire_ball active 四点、创建工具模板四点化）；动画树**中枢接线
  原则**确立（动作态只连 idle、walk↔run 等冗余边清除、attack2 缺回连真 bug 修复）
  + `tools/tree_connectivity_test` 全态回 idle 永久扫描网
- **遗留**：施法者/法术体真美术帧（左右中性约定见 SPELL_SYSTEM_DESIGN 17.1）；
  转换工具对"单动画"类别的支持届时再定

### 产线统一审计与整改（2026-09-15）✅

- 四机制×两产线全量审计（详见 docs/PIPELINE_AUDIT_2026-09-15.md）：法术模板创建
  **单权威化**（删 spell_creator 全部内嵌字符串，动画件物化进 _template，与角色线
  同构）；轮廓体检按产线分名单（法术 active 进体检门）；法术测试场景补高度/击倒
  数据窗口；镜像工具加同族校验防误毁；6 颗雷处置归档（L3 查重按用户裁定撤销）
- 新回归网：`tools/spell_creation_test`（创建流 29 断言）、`tools/test_scene_parity`
  （测试场景功能对等清单）
- 挂账入审计文档第三节：阵营组粒度（切片设计会议题）、法术真四向几何/缩放（美术
  排期议题）

### S1 关卡骨架与流程壳（2026-09-18）✅

- **地基**：`scenes/base/base_stage.tscn|gd`（四段式节点树 + 检查点注册 + 波次聚合
  解锁机制化 + player_died→DeathScreen 转交 + R 键 debug 重开）；
  参考地点 `scenes/stages/ref/stage_ref_a|b.tscn`（双房/单房、双生成器聚合、
  StageExit 跨地点、终点面板）；旧 `scenes/test_stage.tscn` 删除
- **流程壳三件**：`ui/menus/` title/pause/death（三层节点+open/close 信号+theme
  单点的视觉替换契约，spec §4.6）；`scripts/game_events.gd` 会话检查点总线；
  `scripts/stage_exit.gd` 出口触发件（防重入+`area2d:player` 过滤+全高度层掩码）
- **main_scene** 已落 `res://ui/menus/title_screen.tscn`（编辑器关闭窗口期改）
- **矩阵注册 22 项**：新增第 21 项 `tools/stage_validator`（R1-R9 机械执法，
  装配法典见 `docs/STAGE_ASSEMBLY.md`）+ 第 22 项 `tools/stage_contract`
  （全流程环 111 断言，A→B→死亡回跳全链路机器验证）；18 项存量套保持数
- **验收状态**：✅ **已关账（2026-09-20）**——headless 全矩阵绿 + F5 九项通过；
  验收期内 F5 肉眼揪出的四个机制缺陷当场立法并补断言（下列批次）
- **验收期追加批次（2026-09-19~20，S1 打磨到完成态）**：
  - 弹墙去阵营化：`area2d:wall` 伪阵营退役 → `in_knockout` 状态门（走路贴墙零误伤）
  - 相机隐形墙三连哑修复（mask 互叠/左右实体/初帧定位）+ 锁房收口钳位 + zoom 归一
  - 弹墙终案：带墙分离四环 + `mirror_axis` 真镜像 reflect + 横竖分档（80/75 定档）
  - 受击车道排/列换轴（上下攻击可用）+ 四向攻击几何确认 + "纵向受击朝向=上次
    水平 facing"决策定档
  - 矩阵 22→23（新增 `tools/attack_lane_contract` 19 断言）；stage_contract 111→117
  - **光照收编批（同日关账审视产出）**：L3 昼夜三件套预置进 base_stage 骨架
    （空数据自禁零扰动）；软边阴影合成层自动档（z=Level-1 派生+地点侧哨兵覆写，
    装配者零感知）；ShadowRegion 升格为可选装配件（禁重叠军规）；起步数据
    `resources/lighting/`；法典扩**九条/R10**（背景 CanvasLayer 负档，含 runtime
    canary）；LIGHTING_SETUP_GUIDE 重写；stage_contract 117→126（LC1-LC7）
  - **调试面板正式化批（同夜）**：DebugDock 新增"光照"交互页（相位/倍速/覆盖演示+
    高度条与阴影调试线开关，拉取刷新状态随现实）；5-8/O 键 dock 内置（正式地点与
    测试场景同键同能；场景自带 DebugDayNightInput 时整体让位防覆盖双压栈）；阴影
    调试线节点改常建默认隐身；manager 循环倍速/覆盖栈计数接口；dock_test 扩至
    八页签+交互页+共存让位+无实物回弹断言
  - **S2-M1-B1 容器批 ✅ 已交付（2026-09-22，headless 24/24，终审 ready-to-merge）**：
    ChapterShell/StageContent/ChapterSession/SessionRules + validator 双轨（R1/R2 条件化/
    R5 白名单/R8 壳豁免）+ container_contract（S/E/D/H 四组）+ 法典 0.2b。**B2 开账三件
    （终审裁定，进 B2 首步）**：①切换链 `_settle_before_switch` 的 await-self 收口
    （pause 菜单换场景可达窗）②`mark_cleared` 落点终裁（登记时 vs 落地时——船闸
    force_advance×死亡竞态的前置裁决）③段文件 validator 第三形态（root=stage_content
    识别，R3-R7 对段执法）④夹具视觉皮肤化（seg 三段+chapter_fix：色块地面/段名牌/可视
    触发线，纯装饰零碰撞；B2 触发件肉眼验收场地，2026-09-22 实机确认毛坯不可辨后定档）。
    同批顺带：content_ready 死信号清理、终点双信号拆分、
    E7 Windows .bat 中转预备。措辞修正：BaseStage 为"快乐路径逐位等价+两处受 blessed
    偏差（reload 解冻 bug 修、错类型静默跳过属改进）"。
    **实机关账（2026-09-22）**：用户 Windows F6 真跑 container_contract 50+ 全绿，E7 `cmd /c`
    引号分支证实可用（.bat 中转预案作废）；chapter_fix 人眼手感验收项**撤销**（夹具系测试台
    毛坯、换段无视觉信号属实——节拍裁决移交 B6 实段，夹具皮肤化移交 B2 首步场地建设）。B1 结清。
    **互动游乐场人工定案（2026-09-23）**：宝箱消耗、跳河成功链、E 键响应均获用户 Windows 实机
    实证；船闸由契约 G 流负责（人工不可达系夹具本性）。用户裁决：夹具不皮肤化/不铺通路/不调窗参
    ——人工体验归 B6 实段。两批 F5 单就此关账。
  - **S2-M1-B2 互动触发件批 ✅ 已交付（2026-09-22，SDD 8 任务全过双审查门）**：
    `InteractTrigger` 通用件（E 键 `interact` 动作/一次性/冷却/旗标门/consume 收口）
    + 三反应件（宝箱 session 判重、船闸限时→T2 强制链残血带段、跳河 QTE 循环窗×钳伤
    不死×出树即终门）+ 法典条 10（含⑥重演语义三分）+ validator R11/空根守卫 +
    段/壳模板双判形 + **契约套 `tools/interact_contract`（矩阵第 25 套，85 断言）** +
    B1 开账四件全清（SwitchFlow await-self 收口/E8 结构锁、mark_cleared 落点终裁/D5、
    段文件执法、夹具视觉皮肤化——B1 撤销的人眼验收项由 it2/it3 游乐场复活进 F5 单）。
    headless 23 跑 22 绿 + 1 红归因用户侧 chen 资产回写（input_channel AI 路，非本批）。
  - **S2-M1-B2.5 测试主权批 ✅ 已交付（2026-09-23，SDD 6 任务）**：回归矩阵与生产角色
    chen 断绑——`TestActorKit`（替身 test_actor 全套创建/销毁走**真实产线**
    CharacterCreator/CharacterDeleter；导入判据=头像 sidecar+`.ctex` 实体双核验，
    破 Syncthing 半同步假就绪）+ `tools/matrix_runner/run_matrix.sh` 通跑编排器
    （每轮 destroy 先行→ensure(42)→--import→ensure(0)→22 套 23 跑→末销毁零残余；
    ATTEST 身份见证封"静默跳腿假绿"；Task6 修正：同套多标记缺席并**一条**红判定，
    不再虚增 RED）。消费面：直载类测试套全迁替身 + `base_stage`/`chapter_shell`
    新增 `playable_override` 接缝（默认 null=生产逐位不变）；豁免申报入文件头
    （wp2 产线镜像腿、spell_cast 在册外取证台等）。诚实化两件：**R8**
    `attack_freeze_repro` 转正为在册断言台——判红必退 rc=1（旧取证台设计红也退 0；
    破坏演练实证 绿→rc0 / 强红→rc1）；**R9** `overlay_e2e._check` 改失败计数
    唯一存放点（旧版第二腿 FAIL 只打印不计数=判绿盲区）。**打击感定案备案**：
    chen attack1=0.1s 为用户有意创作，矩阵验证模板血统、**有意不覆盖 live 手感；
    模板回刷=控制器决策，届时 H3 pos≥0.30 停摆窗判据同批随动**。R10 三方告警
    对比裁决（Task6 探针）：产线新建 probe_throw / 驻留 test_actor / chen 在同 harness
    下**各报 3× "AnimationNode is null"**——"chen 不告警"前提不成立，定性为插件（消音批注：告警源为**双生 walker**——quiver_character_skin_anim_tree 与 spells/_base/spell_skin_anim_tree 同型 null 槽白名单问题，将来消音须两处同治）
    anim tree walker（quiver_character_skin_anim_tree.gd `_handle_animation_node`）
    撞引擎空槽属性（BlendTree/TimeScale/StateMachine 的名为 `AnimationNode` 的
    AnimationNode 型属性）的**预存噪音**（入册备案，非产线缺陷，不立案；addons
    只读未触；皮肤每入树一次报 3，编辑器+运行时双入树形态下即见报的 6×）。
    批末全矩阵首通 **23 跑 RED=0**、末销毁后 `characters/playable/` 仅剩 chen+testme。
    F5 腿见 `docs/superpowers/plans/2026-09-22-s2-m1-b25-test-sovereignty-f5.md`。
  - **S2-B3 盾反批 ✅ 已交付（2026-09-23，SDD 7 任务全过审查门）**：修饰内核
    **方式 B′ 手术**（base 首捕一次+`(base+Σ加)×Π乘` 重算回写+int roundi 类型锁+
    同 id 替换+reset 清账——叠挂/乱序/尸体账三类踩踏结构性消灭）+ 受管三导出
    （parry_window_frames/block_damage_ratio/attack_output）与格挡成对旗入册 +
    判定缝三分支（弹反=免伤反顶攻击者池+6 帧定格自发拍+白闪；格挡=×0.4 且
    **击退值整颗作废**"飞天变站桩"；常规=out_mult 乘算 1.0 逐字等价哨兵；
    `on_target_hit` 升格公共义务）+ `apply_damage_value` 数值伤害唯一入口 +
    **姿态状态 QuiverActionBlock**（引擎虚 `_physics_process` 自武装新判例、
    单写者成对旗、locomotion 进入白名单；chen/模板/替身三处落地，block=K
    上轴 jump 让位 Space）+ **契约套 `tools/block_parry_contract`（矩阵第 23 套
    =24 跑，79 断言+横幅=80 口径，M/P/Q 三流）** + 数值治理法入 AGENTS。
    T7 收口三件：**测试强度强化**（P11c 全录像判停破窗盲、P6c/P8e 命中帧起
    ≤15 帧回执护栏堵 300f 窗缘假绿）、**R11 hotfix**（`quiver_enemy_character`
    attributes 浅拷→深拷，B′ 账本个体隔离，knockout_contract 多 spar 实例为
    直接消费腿）、H3 停摆窗随模板基线迁长**按 B2.5 预批随动**重校准（比率锚
    0.7×length+停摆机构换生产 HitFreeze 同款 paused，红判据不变）。
    批末**全矩阵 24/24 绿**。挂账移交 B5 设计会前置清单（三件）：
    ① AI 档隔离×spawner 硬转型双头死结裁决（make_attributes_local() 双写
    vs 创建器改产 QuiverCharacterEnemy 壳，二选一立案，账本 R11③）；
    ② 短动画×≥4 帧定格浅位信标死格异象——B5 开工前读探针案卷
    `/tmp/opencode/b3_t7/h3probe*.log` 并补 F5 眼"被弹反方连段窗不死"；
    ③ 深拷账本隔离锁已由 iso_leg 入 knockout 契约（本波）。F5 单三眼见
    `docs/superpowers/plans/2026-09-23-s2-b3-block-parry-f5.md`。
  - **同夜价值复审**：临时示范场地 stage_c 退役删除（R8 另一腿系 ref_b 既有覆盖、
    "食谱自证"于建造时消费完毕）；光照/区域实配迁入 ref_b 成"A 负 B 正"法定对偶
    （ref_b 挂 60 秒活循环 day_cycle_demo+全战区区域框，LC8/LC9 锁，126→128）
  - **S2-M1-B1 容器批（2026-09-22）**：ChapterShell/StageContent/ChapterSession/
    SessionRules + validator 双轨（R1 两形态/R2 条件化/R5 白名单双形/R8 壳豁免）+
    契约 container_contract（矩阵 23→24）
- **S1 能力总评**：装配法典化/推进二态/事件总线/检查点自动注册四个设计决定全部
  经受住验收期考验；爆过的雷都在新机制缝里（相机/车道），且均已固化为断言。
  **能力使用手册 = `docs/STAGE_ASSEMBLY.md` 第〇章食谱**（新地点=五件事+免费清单，
  法定样板 ref A/B=一负一正光照对偶）
- **关账时点 backlog（审视产出，未立项）**：
  ① 互动/对话触发件缺失——S3 对话第一刀须补（装配法典加条+validator 新规则，
    别让胶水进场景）；② 自切片起"新机制契约套随交付同批"入验收定义（本轮教训：
    相机/车道全靠事后补锁）；③ 检查点粒度=地点级（房内恢复/续谈归位→S2 容器
    设计会裁决）；④ 音频管道=零（S2/S3 至少埋 BGM 槽位）；⑤ 死亡壳无"重试
    当前房"（S2 切片议题）；
  ⑥ 全矩阵 23 套无分层执行脚本（低优先）；
  ⑦ ~~光照 L3 未收进 S1~~ **当夜即收编**（见上"光照收编批"）——教训并入②：
    法典范围审视必须把旧系统资产（scripts/ 全目录）过一遍点名，防"文档里活着、
    骨架里断线"的暗账

## 后续开发路线

1. ~~重新建立 chen 角色~~ ✅ 已完成
2. ~~角色体系补全（玩家+非玩家统一模板流水线）~~ ✅ 已完成（2026-09-14）
3. ~~建立 `base_stage.tscn` 标准关卡场景结构~~ ✅ **S1 已交付（2026-09-18）**：
   HUD 丙方案（游戏 HUD 组件 + 全局 DebugDock，docs/HUD_DESIGN.md）随 S1 入位；
   装配法典 `docs/STAGE_ASSEMBLY.md`（第〇章食谱+ref A/B 负正对偶样板），**验收关账 2026-09-20**
4. **S2 第一个可玩切片**（2026-09-21 换序定档：切片先行、对话后接——理由：
   对话的边界案例需要活着的世界才可验证；外部 alpha 依赖晚引入保降级选项）。
   **会前 spike ✅ 双完成（2026-09-21）**：① Dialogic 风险探测（`docs/
   SPIKE_DIALOGIC.md`：核心通路全活、选型维持 Dialogic；输入漏=预期内剧情门
   修复；暂停语义自洽；CJK/ended 终验交 Windows 腿 4）；② 舞台容器原型探测
   （`docs/SPIKE_CONTAINER.md`：迁移物理白送（玩家/相机/清场持久实测）、
   六条裂缝全部复现并给对策原型，四个待裁决议题入设计会）。耗材在
   `tools/dialogic_spike|container_prototype/`，均不进回归矩阵。
   **设计会议题**：战斗手感四选、首批敌人兵种与 AI 深度（黑板/仇恨/兵种资源
   由设计导出勿工程预设）、掉落、法术接入、**舞台容器与跨地点状态延续裁决**
   （状态包内容/舞台复位与清场持久/单地点场景兼容策略）。
   **施工序：容器批第一位**（骨架拆分内容层/会话层+法典双轨+契约重建），
   随后手感/敌人/波次。
5. **S3 对话接入竖切**（接进切片活世界）：触发件入装配法典（新条目+validator
   新规则）、剧情态门放 attributes 实例层（随玩家走，容器友好）、CJK 主题落地、
   契约套随交付同批；若 spike 探出结构性冲突，届时选型复议（自研简版对话框）。
6. 剧情内容按 `story/原创章节大纲_折旗.md`（史实骨架原创底稿）分阶段开发；
   `story/bible.md` 仅作结构参照，不直接投产（版权安全线，见该大纲自检节）

详细架构见:
- `docs/PLUGIN_ARCHITECTURE.md` — Quiver 插件源码分析（已更新碰撞系统重构 + 轮廓转换工具内容）
- `docs/TEMPLATE_IMPLEMENTATION.md` — template-beat-em-up 实际实现参考（原版碰撞系统，用于对比）
