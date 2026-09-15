# 开发状态说明

> **生效日期**: 2026-08-11
> **最后更新**: 2026-09-14

## 决策：xuanyuan-sword 正式从零开始

本目录（`xuanyuan-sword/`）下的已有工作**全部视为阶段 1-4 的学习验证产物**，**不作为正式游戏代码的基础**。

| 已有文件/目录 | 处置 |
|---|---|
| `legacy/` | 保留为学习资料存档，不要复用 |
| `characters/playable/chen/` | **模板之源**（2026-08-16 重建，2026-09 起为 `_template` 快照之源）。完整状态机 + 高度层碰撞 + 通道化输入（见"角色体系补全"） |
| ~~`characters/playable/chenjianchou_new/`~~ | 已移除（工具开发期临时角色） |
| ~~`characters/playable/enemy/`~~ | **已退役**（2026-09-14，"魔法替身"旧敌人；职责由 AI 档正式角色 `characters/enemies/spar_enemy/` 承接） |
| `characters/enemies|allies|neutrals/` | **正式角色内容资产，进 git**（创建器按阵营输出；`spar_enemy`=Run Test 常驻陪练，勿删） |
| `scenes/test_stage.tscn` | 无标准 stage 结构、无 FightRoom、无 HUD、使用普通 Camera2D。**不继续，重建标准 stage**（下一步） |
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

## 后续开发路线

1. ~~重新建立 chen 角色~~ ✅ 已完成
2. ~~角色体系补全（玩家+非玩家统一模板流水线）~~ ✅ 已完成（2026-09-14）
3. 建立 `base_stage.tscn` 标准关卡场景结构（**下一步**；头脑风暴已开局，
   遗留决策：HUD 来源 A/B/C）
4. **第一个可玩切片设计会**（战斗手感四选、首批敌人/兵种、掉落与法术接入……
   敌人 AI 深度〔黑板/仇恨/兵种资源〕从这场会自然导出，不再由工程侧预设）
5. 按 `story/bible.md`（天之痕剧情）分阶段开发

详细架构见:
- `docs/PLUGIN_ARCHITECTURE.md` — Quiver 插件源码分析（已更新碰撞系统重构 + 轮廓转换工具内容）
- `docs/TEMPLATE_IMPLEMENTATION.md` — template-beat-em-up 实际实现参考（原版碰撞系统，用于对比）
