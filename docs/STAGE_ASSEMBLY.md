# 关卡装配指南（STAGE_ASSEMBLY）

> S1 立法的装配法典：spec §5 八条规范 + 本计划施工期实证雷区。
> 建真关卡前先通读本文件；**新关卡必过校验器才有 F5 资格**（流程法律）：
> `godot --headless --path . -s tools/stage_validator/validator.gd`

## 一、装配八条（校验器 R1-R9 的法律来源）

- [ ] **1. 相机挂玩家下**：LevelCamera 实例是玩家角色节点的子节点（插件无目标
      查找，跟随=父子变换）；limit 初值给宽，由 FightRoom 运行时收束。
- [ ] **2. 检测器三导出显式填**：`path_fight_room=NodePath("..")`、
      `paths_enemy_spawners` 列全本房生成器、`is_one_shot=true`；
      身份判定走 `area2d:player` 组（本项目已迁，勿再找 `players` 组）。
- [ ] **3. 生成器必改 `path_spawn_parent`** 为 `../../../Level/Characters` 形态
      （上游默认值 `../../Characters` 在标准层级下是错的——校验器 R5 红色项）。
- [ ] **4. 碰撞配层走高度层**：Collisions 的 StaticBody `collision_layer` 只配
      高度层（全段=16760832，bit15-24）；**禁手配旧层 3/4 掩码**（屏限/顶限由
      LevelCamera 高度层运行时接管，上游旧制勿抄）。
- [ ] **5. 波次数据形态**：`spawn_waves` 用插件自定义 Inspector 填
      （波=QuiverSpawnData 数组）；敌人场景引用必须盘上存在（校验器 R6）。
- [ ] **6. 检查点约定**：覆写 BaseStage 导出 `stage_id`，进地点即以
      (stage_id, scene_path) 自动注册；回跳=重载场景，无多入口标记体系（YAGNI）。
- [ ] **7. 多生成器聚合读检测器导出**：base_stage 据 `paths_enemy_spawners`
      聚合，全 `is_completed` 才 `setup_after_fight_room()` + 发 `room_cleared`
      ——场景连线表达不了"与"逻辑，**禁逐房手写胶水**（上游每房手写的债已升格为机制）。
- [ ] **8. 推进机制只有两种**：房→房 = after_fight_limit 扩权步行串场（同地点内）；
      跨地点 = StageExit 触发件（`next_stage_path` 导出）。不设第三种。

## 二、实证雷区（S1 施工期尸检报告，逐条真踩过）

- [ ] **a. FightRoom 是 Control**：其子节点（检测器/生成器/落点 Marker）坐标是
      **房局部坐标**，世界坐标 = 房间 offset + 局部值。按世界坐标直填 = 检测器
      飘出房外、玩家永远踩不到触发线。
- [ ] **b. 检测器/出口件掩码配方**：`collision_layer=0`、
      `collision_mask=16760832`（全高度层，玩家身体动态持有）、
      `monitorable=false`。少一项检测器静默失灵（玩家组 body 进不了区域）。
- [ ] **c. Collisions 静态件只挂高度层**：`collision_layer=16760832`、
      `collision_mask=0`，**不带旧位 2/4/8**（障碍/屏限/顶限）——旧位会让
      高度层过滤逻辑（`_update_collision_layers` 的掩码保留策略）产生双重身份。
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

## 三、上游禁抄项（template-beat-em-up 旧制，本项目已有替代）

- 屏限/顶限手动配层（层 3/4）→ 已死，见一-4；
- 每房手写 `all_waves_completed` 胶水（stage_01.gd 模式）→ 已死，见一-7；
- `$Level/Characters/Chad` 硬编码取玩家 → base_stage 运行时查 `area2d:player`；
- main_menu 转场动画 method-track 驱动 → S1 起按钮直连，动画经 `opened/closed`
  信号解耦（spec §4.6 视觉契约）。
