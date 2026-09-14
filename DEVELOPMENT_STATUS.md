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
