# S1 细案 · 地点制关卡骨架与流程壳 设计文档

- 日期：2026-09-18
- 状态：设计已获用户认可（七节逐节呈审通过），待终审
- 上游文档：`2026-09-18-stage-infrastructure-master-design.md`（总纲）之 S1 子项目
- 对标依据：上游 template-beat-em-up 的 `base_stage`/`stage_01` 精读报告（2026-09-18 两会话调查，本文吸收其全部结论）

---

## 1. 使命与验收定义

把"零件齐全但从未组装"的关卡体系第一次在正式结构里装配起来，并立起游戏流程壳，
使本项目第一次拥有可 F5 走通的完整游戏环：**标题 → 进关 → 锁房战斗 → 清场解锁 →
出口切场 → 终点；中途可暂停、死亡可回检查点、随时可回标题**。
S1 是此后一切内容（对话/掉落/成长/存档/音频）的验收宿主。

**范围外**（只留接口，出现实现即范围违规）：真背景美术、Dialogic 接线、
掉落拾取、成长数值、持久存档、音频管线、设置页、玩法说明页。

## 2. 已裁定决策（含被否选项，防复议）

| 决策 | 裁定 | 理由/被否项 |
|---|---|---|
| 关卡地理形态 | **地点制**：一地点=一 stage 场景，房内锁镜头清波，出口触发件切场 | 被否：长走廊制（与"地点=章节节点"叙事打架、内存/美术压力）、地图选关（第一章过度建设） |
| 死亡结算语义 | **检查点列表（新→旧）+ 返回标题**，无"重开本关"独立按钮 | 用户裁定：死亡=回到旅程的某节点；"重开"由最新检查点天然覆盖 |
| 胜利结算 | **不存在**。剧情终点由剧情批实现；S1 参考关终点=清场后极简出口面板 | 用户裁定："都是剧情类的" |
| 检查点机制 | S1 立会话内存版（进地点自动注册），S5 换持久数据源，接口不变 | 从用户对存档形态的规格反推的最小预演 |
| 设置页 | 不做 | 用户裁定：后来添加 |
| 玩家获取 | base_stage 运行时查 `area2d:player` 组首位，**不硬编码节点路径** | 修正上游 `$Level/Characters/Chad` 硬编码 |
| 相机跟随 | LevelCamera 实例挂在玩家角色节点之下（父子变换） | 插件契约：相机零跟随代码 |
| 多生成器聚合 | 收进 base_stage.gd 通用机制（组约定） | 上游每房手写胶水，升格为机制 |
| 死亡重试落点 | 检查点跳转为场景级重建（transitions） | S5 后升级为快照回滚，UI 不变 |
| R 键 debug 重开 | 保留（debug 构建） | 上游惯例 |

## 3. 目录与文件

```
scenes/base/base_stage.tscn            关卡父场景（骨架+件位）
scenes/base/base_stage.gd              BaseStage（class_name）：聚合/接线/检查点注册/R键
scenes/stages/ref/stage_ref_a.tscn     参考地点A：双战斗房（房2双生成器）+出口→B
scenes/stages/ref/stage_ref_b.tscn     参考地点B：单战斗房，清场→终点面板
ui/menus/title_screen.tscn|gd          标题壳
ui/menus/pause_menu.tscn|gd            暂停壳（ESC）
ui/menus/death_screen.tscn|gd          死亡结算（检查点列表）
scripts/game_events.gd                 GameEvents autoload（项目事件总线+检查点注册表）
scripts/stage_exit.gd                  StageExit 出口触发件（Area2D）
scripts/stage_end_panel.gd 或内嵌于 B 场景  终点极简面板
tools/stage_validator/validator.gd     装配校验器（矩阵第 21 项，-s headless）
tools/stage_contract/…                 流程契约套（矩阵第 22 项，场景 runner）
docs/STAGE_ASSEMBLY.md                 装配指南（§5 规范全文+雷区），AGENTS 挂引用
```

## 4. 结构与契约

### 4.1 base_stage 节点树（继承即得）

```
BaseLevel(Node2D, base_stage.gd)
├── Background(Node2D, z_index=5)          子节点们放视差/Sprite2D/ColorRect（S1 占位）
├── Level(Node2D, z_index=15, y_sort)
│   ├── Characters(Node2D, y_sort)         玩家实例（场景内摆放）+ 敌人挂入点
│   │   ├── <玩家>.tscn 实例
│   │   │   └── LevelCamera(插件 quiver_level_camera.tscn 实例)
│   │   └── SpawnA(Marker2D)               检查点出生标记（命名约定 Spawn<id>）
│   ├── Objects(Node2D, y_sort)            装饰/道具
│   └── Collisions(StaticBody 群)          地面/边界（高度层规范配层，见 §5-4）
├── Ambient(Node2D)                        CanvasModulate + DirectionalLight2D 位 +
│                                          DayNightController（S1 可选挂，默认正午 SceneTimeData）
├── Foreground(Node2D, z_index=25)
├── FightRooms(Node2D, z_index=30)         每战斗房一个 QuiverFightRoom 子树（§5）
└── HudLayer(CanvasLayer, layer=2)
    ├── GameHUD(ui/game_hud.tscn 实例)     自带 players 组跟随，无需注入
    ├── PauseLayer(Control)                PauseMenu 与 DeathScreen 的父，
    │                                      process_mode=WHEN_PAUSED
    └── StageEndPanel(参考关终点面板, 隐藏)
```

### 4.2 GameEvents（项目总线，autoload，`scripts/game_events.gd`）

S1 信号面（只建 S1 消费得动的，flag API 占位声明但空装）：

- `room_cleared(room_id: StringName)` —— 某房全部生成器聚合完成
- `story_checkpoint(id: StringName)` —— 进地点时 base_stage 发；GameEvents 自订阅落注册表
- `stage_exited(stage_id: StringName)` —— StageExit 触发，切场前发
- 检查点注册表：`Array[{id, stage_path, spawn_point: NodePath}]`，新进入追加；
  **复位时机：返回标题画面时清空**（同会话死亡重试保留全部历史）；
  `get_checkpoints()` 供 DeathScreen 渲染。
- S2-S5 未来信号（`flag_set`/`item_picked`/`xp_gained` 等）**不预建**——用到再加
  （YAGNI；总线文件存在即扩展点）。

### 4.3 房间三件套（每战斗房的标准子树，装配模板）

```
FightRooms/FightRoom1(QuiverFightRoom, ReferenceRect)   limit_*/zoom + after_fight_*
├── PlayerDetector(Area2D)                              段形碰撞竖切一地
│     is_one_shot=true; path_fight_room=NodePath("..");
│     paths_enemy_spawners=[NodePath("../EnemySpawner1"), ...]
├── EnemySpawner1(Marker2D)                             path_spawn_parent 必改写
├── EnemySpawner2(Marker2D)（多波房才有）                同上
└── <落点 Marker 若干>                                   WALK_TO_POSITION 的目标
```

进房锁相机→刷怪由插件检测器 `_ready` 自接线完成（顺序有保证）；
**解锁方向**：base_stage.gd 聚合（§5-3），房清 → `setup_after_fight_room()`
→ 发 `room_cleared`。

### 4.4 地点衔接

- StageExit（Area2D，玩家组判定 `area2d:player`）：`body_entered` → 防重入旗 →
  `GameEvents.stage_exited(id)` → `ScreenTransitions.transition_to_scene(next_stage_path)`
  （导出 `next_stage_path: String`）。
- 地点 B 清场后（房 `room_cleared` → base_stage 判定"本关无出口件"）→
  显示 StageEndPanel（两按钮：返回标题 / 重走一遍=重载 A 并清检查点）。
- 标题→地点 A：`BackgroundLoader.load_resource` 预热 + `transition_to_scene`
  （上游 main_menu 链路原样，动画 method-track 驱动**不抄**——S1 无动画，按钮直连）。

### 4.5 流程壳行为

| 界面 | 结构 | 行为契约 |
|---|---|---|
| title_screen（`run/main_scene`） | 文字 VBox：开始游戏 / 读取存档(disabled，S5 亮) / 退出 | 开始→预热→转场 A；启动时 `ScreenTransitions.fade_out_transition()` 淡入 |
| pause_menu | 继续 / 回本地点入口 / 返回标题 / 退出游戏 | ESC（新输入动作 `pause`）toggle；开=树 paused+`process_mode=WHEN_PAUSED`；关/跳转前必须显式解冻（三条路径逐一处理，上游教训） |
| death_screen | 订阅 `Events.player_died`（在 base_stage 中转交）→ 检查点按钮动态生成（新→旧，显示 id）+ 返回标题 | 选检查点 → `transition_to_scene(对应 stage_path)` 并携带目标 spawn 标记；"重走一遍"重置 registry |

回本地点入口 = 跳转检查点列表最新项（同一管道，不另设逻辑）。

## 5. 装配规范（校验器的法律；全文入 docs/STAGE_ASSEMBLY.md）

1. **相机挂玩家下**（插件无目标查找；跟随=父子变换），limit 初值给宽由 FightRoom 运行时收束。
2. **检测器三导出显式填**：`path_fight_room` 指父房框、`paths_enemy_spawners` 列全、
   `is_one_shot=true`；身份判定走 `area2d:player`（本项目已迁，勿再找 players 组）。
3. **Spawner 必改 `path_spawn_parent`** 为 `../../../Level/Characters` 形态（默认值
   `../../Characters` 在标准层级下错误——上游埋雷，校验器红色项）。
4. **碰撞配层走高度层**：Collisions 的 StaticBody `collision_layer` 只配高度层
   （15-24 区间按需）；**禁手配旧层 2/3/4 掩码**（屏限/顶限由 LevelCamera 高度层
   运行时接管，上游旧制勿抄）。
5. **波次数据形态**：`spawn_waves` 用插件自定义 Inspector 填（波=QuiverSpawnData 数组）；
   敌人场景引用必须存在（S1 全用 spar_enemy）。
6. **检查点标记约定**：每地点至少一个 `Spawn<id>` Marker2D 于 Characters 下；
   地点根脚本或场景备注 checkpoint_id。
7. **多生成器房打组** `<房名>_spawners`；base_stage 遍历组聚合，全 `is_completed`
   才解锁（场景连线表达不了"与"逻辑，禁逐房手写）。
8. 房→房推进=**after_fight_limit 扩权步行串场**（同地点内）；跨地点=StageExit。
   不设"关卡出口节点"以外的推进机制。

## 6. 校验器（tools/stage_validator，矩阵第 21 项）

headless `-s`：遍历 `scenes/stages/**/*.tscn` 文本+加载断言，规则对 §5 逐条机械化：
 FightRoom 子树缺检测器 / 导出路径为空 / spawn_parent 用默认值 / 波次空表 /
 敌人场景不存在 / 旧掩码违例 / 地点无 Spawn 标记 / 无出口且不可达终点 →
 逐条打印违例+文件行线索，`RESULT: x PASS / y FAIL`。
新装配未过校验器 = F5 免谈（流程法律）。

## 7. stage_contract 测试套（矩阵第 22 项）

场景 runner（`_ready`+physics_frame 纪律），自动断言链：
加载 A → 玩家注入移动进房（`Input.parse_input_event` 至少一条全链路）→
相机 limit 收到房间值域 + 波次敌人生成数=配置 → 逐个 kill（attributes 直伤）→
聚合解锁（limit 扩到 after_fight 值）+ `room_cleared` 计数 → 走到 StageExit →
`stage_exited` + 切场到 B → B 清场 → EndPanel 显示；
死亡路径：spawn 新敌杀玩家 → `player_died` → death_screen 列表含已访检查点 →
点击回跳 → 场景重建+玩家位于对应 Spawn 标记。
协程 `_finished` 防跳段旗、断言标签展开值——按仓库 runner 模板。

## 8. 施工风险与对策

1. **project.godot 三处改动**（main_scene、`pause` 输入动作、GameEvents autoload）
   撞"编辑器回写"纪律：施工窗口请 Windows 端关编辑器；改毕重启编辑器验证；
   新输入动作优先让 Windows 端在 Input Map 加（AGENTS 既定策略），Linux 侧只做
   代码消费。
2. 占位美术用现成件：`scripts/debug_background.gd` 渐变 + ColorRect 地面条，
   零新素材。
3. 检查点跳转与 ScreenTransitions 的重入/加载竞态：StageExit 防重入旗 +
   跳转携带参数经 GameEvents 单点传渡（不靠场景全局变量）。
4. `player_died` 转交链在 HURT/KNOCKOUT 动画时序敏感：die 状态发射点已有测试
   （tree-connectivity/knockout_contract 护栏），stage_contract 再兜一层。
5. 参考关两处"以后要换"：StageEndPanel（剧情批换演出）、读取存档灰按钮
   （S5 点亮）——代码内注释挂 TODO 指向子项目编号。

## 9. 完成判据（三条缺一即未完工）

1. stage_validator + stage_contract 两套件入矩阵（20→22）全绿；
2. F5 人工清单：标题→A→两房→B→终点；暂停四钮；死亡→列表→回跳正确出生位；
   R 键 debug 重开；
3. 文档：`docs/STAGE_ASSEMBLY.md` 成文、AGENTS.md 目录/流程节更新、
   DEVELOPMENT_STATUS 路线图 S1 划线、总纲文档状态字段更新。
（未碰 addons/ ⇒ PLUGIN_ARCHITECTURE/PLUGIN_CHANGES 义务不触发。）
