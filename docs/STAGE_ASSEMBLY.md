# 关卡装配指南（STAGE_ASSEMBLY）

> S1 立法的装配法典：**要造新地点 → 直接看第〇章食谱**；第一章八条与第二、三章
> 是干完活后的审稿清单。**新关卡必过校验器才有 F5 资格**（流程法律）：
> `godot --headless --path . -s tools/stage_validator/validator.gd`

## 〇、新地点食谱（先照此施工，再回下文审稿）

**总原则**：造一个正式地点**零新代码**——若发现"非改代码不可"，说明需求在 S1
能力面外（如互动触发件），回设计会立项，别在场景里手写胶水。

### 0.1 实例化 base_stage 即免费所得（什么都不用配）

| 能力 | 提供者 | 场景侧动作 |
|---|---|---|
| 四段式树（Background/Level{Characters,Objects,Collisions}/Foreground/FightRooms/HudLayer+HUD+暂停/死亡壳+通关面板） | `base_stage.tscn` 骨架 | 无 |
| 检查点自动注册（死亡/暂停菜单可回跳本地点） | `BaseStage._ready → GameEvents.add_checkpoint` | 填 `stage_id` 即生效 |
| 波次聚合解锁（房内全部生成器 is_completed → 扩权 after_fight + 发 `room_cleared`） | BaseStage 聚合读检测器导出 | 只需填对检测器（0.3） |
| 死亡→死亡壳、ESC→暂停壳（含冻结态防叠开） | BaseStage 转交 + 壳 ALWAYS 纪律 | 无 |
| 通关面板（全房清且 `ends_after_last_room=true` → 返回标题/重走一遍） | `BaseStage._show_end_panel` | 填该导出 |
| 相机边缘全家桶：四面实体墙+四弹墙带（横竖分档）+出生初帧定位+锁房收口钳位+zoom 归一 | `QuiverLevelCamera` + `QuiverFightRoom` | 挂相机+配房 |
| 高度层碰撞、阵营免伤、击飞/受击全套语义 | `QuiverCharacter` 运行时下发 | 无 |
| 昼夜三件套预置（CanvasModulate+KeyLight+Controller；**空数据=自禁定格白天**） | `base_stage.tscn` Ambient 子树（2026-09-20 收编） | 可选：挂 SceneTimeData（0.2 第 6 件） |
| 软边阴影合成层自动落位（z=Level-1 派生，随动） | `ShadowSoftEdge.derived_z_for` | 无（覆写=专家通道） |
| 调试重载（debug_restart 动作 → reload_prototype） | `BaseStage._unhandled_input` | 无 |

### 0.2 每地点亲手做的五件事（+一条合流）

1. **建文件**：新建场景→实例化 `scenes/base/base_stage.tscn` 为根→另存
   `scenes/stages/<章节包>/stage_<名>.tscn`（最小样板=`scenes/stages/ref/stage_c.tscn`）；
2. **根两导出**：`stage_id`（StringName 全局唯一，检查点主键）；
   `ends_after_last_room`（true=全房清演出通关面板；false=必须摆 StageExit——R8 二选一）；
3. **生玩家+挂相机**：`Level/Characters` 实例 chen.tscn，其下实例
   `quiver_level_camera.tscn`（装配一条：相机必须是玩家子节点）；limits 初值给宽
   （样板只填 top=-280/right/bottom=1200，左右界由 FightRoom 运行时收束）；
   **出生点放第一房检测线西侧几十 px**（放线东=落地即开战；放界外=首次锁房被收口拉一把，雷区 i）；
4. **场地几何**：`Level/Collisions` 地面板+左右实体墙 StaticBody（配方照抄样板：
   `collision_layer=16760832`、`collision_mask=0`，雷区 c）；背景/道具摆 `Objects`/`Background`；
5. **FightRoom 三件套×N**：字段卡见 0.3（房=ReferenceRect，**子节点坐标相对房左上角**，雷区 a）；
6. **【可选】光照两件套**：`Ambient/DayNightController.scene_time_data` 挂时间数据
   （起步件 `resources/lighting/day_neutral|day_cycle_default.tres`，留空=定格白天）；
   性能需要时在地点根摆 `ShadowRegion` 框（禁重叠，参考实配=stage_c）——细则见 LIGHTING_SETUP_GUIDE；
7. **【合流】让地点可被进入**：上关 `StageExit.next_stage_path` 指过来；试跑可临时
   改 `title_screen.gd` 的 `GAMEPLAY_SCENE` 或在编辑器**用 F6 单跑本场景**——验完还原，不合流不提交。

### 0.3 FightRoom 三件套字段卡（逐项来源=stage_c 实测绿）

**房（ReferenceRect + quiver_fight_room.gd）**
- `offset_left/top/right/bottom` 与 `limit_left/top/right/bottom` **同值**（offset=编辑器可视、limit=运行时执法）；
- `zoom` 锁房全览缩放——照抄样板后 F5 校手感（validator 不管）；
- 战后扩权：`after_fight_use_new_room=true` + 四 `after_fight_limit_*`（串场活动区，通常向东扩）+ `after_fight_zoom` + `after_fight_transition_duration=0.8`；
- `preview_camera/preview_after_room=true` 仅编辑器预览着色。

**生成器（Marker2D + quiver_enemy_spawner.gd）**
- `path_spawn_parent = NodePath("../../../Level/Characters")` —— **必改**（上游默认值是错的，R5 红）；
- `spawn_waves = [[SD, SD, ...], [SD, ...]]` —— 外层=波序、内层=同波并发；SD 子资源形态照抄样板（`enemy_scene` 指真实存在的敌人 .tscn=R6；`spawn_mode=1`+`use_spawner_position=true`=参考默认，语义要调时查插件 Inspector 面板）；
- `position` 是**相对房左上角**的落点（雷区 a）。

**检测器（Area2D + quiver_player_detector.gd）**
- 掩码配方三件套：`collision_layer = 0`、`collision_mask = 16760832`、`monitorable = false`（雷区 b）；
- `path_fight_room = NodePath("..")`；`paths_enemy_spawners = Array[NodePath]([NodePath("../EnemySpawner1"), ...])` ——列**全本房**生成器，跨房重引=R9 红；
- `is_one_shot` 默认 true 可不写（重复触发房属未立法需求，先回设计会）；
- 触发线用竖 SegmentShape（样板 a=(0,-400) b=(0,700)），放点在玩家必经之路。

**光照与阴影（骨架预置件 + 可选 ShadowRegion）**
- `Ambient/DayNightController`：唯一要动的导出是 `scene_time_data`（null=自禁）；
  `point_lights_paths` 留给灯笼类场景道具（DUSK/NIGHT 自动开关）；
- `Ambient/KeyLight`：`shadow_enabled=false` **法典级禁改**（双重阴影）；无贴图=纯参数载体；
- `ShadowRegion`（ReferenceRect 挂脚本，可选）：阴影只留框内；**0 个=全屏回退、多框并集、
  重叠处双倍变暗禁止**；`debug_preview` 正式关卡保持 false（零绘制）；
- Background CanvasLayer 换件时 **layer 必须 <0**（R10+canary，≥0 连角色一起盖掉）。

### 0.4 路线 B——复制改件（日常最快）

复制 `stage_c.tscn`（最小：1 房 1 波通关收尾）或 `stage_ref_a.tscn`（两房串场+出口）→
换文件名+根名 → **改 `stage_id` 与检查点主键**（撞键=两地点在检查点表合并，回跳错位）→
改几何/波次/出口 → 校验器。**纪律：复制改件免的是手续、不免审稿——八条+雷区 a-j 仍须逐条过**
（validator 只保红线，手感与布局它不管）。

### 0.5 验收三件套

1. 校验器：默认扫 `scenes/stages/**`，你的地点出现在 `违例 0` 里；
2. 冒烟：`godot --headless --path . res://scenes/stages/<包>/<你的地点>.tscn` 跑 ~8 秒零 SCRIPT ERROR；
3. Windows F5：走/打左右墙（弹回+掉 5 血只在击飞时）、上下边缘 2/3 档、穿线开战、
   全清→通关面板、死亡→检查点表含本地点。
（stage_contract 的 117 断言只绑 ref A/B 两台法定样板；新地点由以上三件套+回归时顺扫的校验器保护。）

## 一、装配九条（校验器 R1-R10 的法律来源）

- [ ] **1. 相机挂玩家下**：LevelCamera 实例是玩家角色节点的子节点（插件无目标
      查找，跟随=父子变换）；limit 初值给宽，由 FightRoom 运行时收束。
- [ ] **2. 检测器三导出显式填**：`path_fight_room=NodePath("..")`、
      `paths_enemy_spawners` 列全本房生成器、`is_one_shot=true`；
      身份判定走 `area2d:player` 组（本项目已迁，勿再找 `players` 组）。
- [ ] **3. 生成器必改 `path_spawn_parent`** 为 `../../../Level/Characters` 形态
      （上游默认值 `../../Characters` 在标准层级下是错的——校验器 R5 红色项）。
- [ ] **4. 碰撞配层走高度层**：Collisions 的 StaticBody `collision_layer` 配
      高度层（全段=16760832，bit15-24），**障碍层 2 允许出现**（校验器 R7
      只执 12 位）；**禁手配旧层 3/4 掩码**（屏限/顶限归相机高度层，由
      LevelCamera 运行时接管，上游旧制勿抄）。
- [ ] **5. 波次数据形态**：`spawn_waves` 用插件自定义 Inspector 填
      （波=QuiverSpawnData 数组）；敌人场景引用必须盘上存在（校验器 R6）。
- [ ] **6. 检查点约定**：覆写 BaseStage 导出 `stage_id`，进地点即以
      (stage_id, scene_path) 自动注册；回跳=重载场景，无多入口标记体系（YAGNI）。
- [ ] **7. 多生成器聚合读检测器导出**：base_stage 据 `paths_enemy_spawners`
      聚合，全 `is_completed` 才 `setup_after_fight_room()` + 发 `room_cleared`
      ——场景连线表达不了"与"逻辑，**禁逐房手写胶水**（上游每房手写的债已升格为机制）。
- [ ] **8. 推进机制只有两种**：房→房 = after_fight_limit 扩权步行串场（同地点内）；
      跨地点 = StageExit 触发件（`next_stage_path` 导出）。不设第三种。
- [ ] **9. 背景负档+光照空禁**：正式地点 Background CanvasLayer `layer` 必须 <0
      （R10 文本执法 + BaseStage canary 兜"默认 1"缺失案）；昼夜三件套骨架预置，
      `scene_time_data` 留空=自禁定格白天（装配合法态，非违例）。

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

## 三、上游禁抄项（template-beat-em-up 旧制，本项目已有替代）

- 屏限/顶限手动配层（层 3/4）→ 已死，见一-4；
- 每房手写 `all_waves_completed` 胶水（stage_01.gd 模式）→ 已死，见一-7；
- `$Level/Characters/Chad` 硬编码取玩家 → base_stage 运行时查 `area2d:player`；
- main_menu 转场动画 method-track 驱动 → S1 起按钮直连，动画经 `opened/closed`
  信号解耦（spec §4.6 视觉契约）。
