# GUIDE_关卡搭建 —— 搭一章可玩内容的说明书

> 谁该看：用 Godot 编辑器搭关卡的内容贡献者，不需要开代码编辑器。
> 不懂的词（壳/段/判清/户……或校验器报的 R 编号）：查同目录 `术语表.md`。
> 规矩的原始出处是 `docs/STAGE_ASSEMBLY.md`（工程审稿用），本手册只讲"怎么点"，
> 不重复条文——两处都写必然会写歪，以一处为准。

---

## 〇、先弄明白：一章 = 两类文件

```
chapter_1.tscn（壳 = 整章共用的东西）          seg01.tscn（段 = 其中一幕）
 ├─ 主角：你把角色文件拖给壳（见下）           ├─ 地面、墙
 ├─ HUD、暂停菜单、死亡界面、章终点面板        ├─ 战斗房（虚线框）+ 刷怪点 + 触发检测器
 ├─ 跟随相机（壳自动装在你放的主角身上）       ├─ 宝箱/秘籍/门 等互动件
 ├─ 昼夜光照（不设置=一直白天）                ├─ 出生点 entry_points
 └─ segment_scenes = [段1, 段2, ...]          └─ （不放玩家，玩家归壳管）
      ↑ 连接就在这里：把段文件拖进这个数组
```

| 常见疑问 | 回答 |
|---|---|
| 壳建完就能跑吗？ | 还不能。壳是空场地基：没主角、没段。壳 + 放主角 + 段 + 挂接，**是一件事的四道工序**，下面第 1-3 步做完才算一章 |
| 为什么不把所有东西画在壳里？ | 死亡后只重跑当前段、每段独立保存独立测试——都靠"一章切成多段"。全塞壳里这套机制就没了 |
| 段里为什么没有玩家？ | 故意的：玩家/相机/HUD 整章只要一份，归壳。段只管"这一幕长什么样"。往段里拖玩家会出双份问题（下面常见病有救法） |

两条硬规矩，校验器会拦：
1. **段里不放壳的东西**（玩家/相机/HUD/昼夜色调节点）；
2. **段的出生点必须在第一道触发线的左边**（段模板默认值已合法，挪触发线就要挪出生点）。

## 一、第一次搭章（照做即可，约 15 分钟）

### 第 1 步｜建壳

1. **打开模板**：编辑器底部 FileSystem 面板 → `scenes/chapter/` → 双击
   `chapter_shell.tscn`。
   ✅ 你应该看到：根节点 `ChapterShell`，下面四棵子树——`Players`（**空的**，
   正常，第 3 步给它主角）、`HudLayer`、`Ambient`、`Segments`。
   相机在模板里也看不到——运行时壳会自动装在主角身上。
2. **另存为你的章**：菜单 **场景 → 场景另存为…** → 进入
   `scenes/stages/<你的章包>/`（没有就右键新建文件夹；全小写下划线命名，
   一章一个文件夹）→ 文件名 `chapter_1.tscn` → 保存。
   ✅ 编辑器标题栏变成 `chapter_1.tscn` 即成；**原模板不会被改动**。
   （手滑 Ctrl+S 存到模板路径上了？告诉工程侧，一条命令还原，别慌。）
3. **填身份 + 指定主角**：点选根节点 `ChapterShell`，右侧 Inspector 往下滚：
   | 字段 | 填什么 |
   |---|---|
   | `chapter_id` | 本章全游戏唯一的编号，如 `&"ch1"`（漏了第 4 步校验器会点名 R2） |
   | `playable_override` | **把想当主角的角色 .tscn 从 FileSystem 拖进来**（比如 `characters/playable/chen/chen.tscn`）。这就是"本章玩家是谁"，想换主角换这文件 |
   | `playable_path` | 留空。只有场上同时有两个"玩家身份"角色时才用它二选一 |
   | `camera_host_path` | 留空=相机跟着主角。想让镜头跟着某个 NPC（演出位）才填它 |
   | `segment_scenes` | 留空，第 3 步填 |
4. Ctrl+S 保存。
5. **先单独跑一把壳**：选中 `chapter_1.tscn` 按 **F6**。
   ✅ 能动、J 攻击有反馈、ESC 出暂停菜单 = 壳建成。场地空旷、走到头有看不见的墙 = 正常（段还没挂）。
   ❌ 红字"空场无主角"：说明 `playable_override` 没拖上，回第 3 步。

> 说明：以后工程侧升级壳模板（HUD/暂停/相机）时，已另存的章节文件**不会自动
> 跟上**，由工程侧统一同步。单章使用期间不受影响。

### 第 2 步｜建第一段

1. FileSystem 里右键 `scenes/chapter/segment_template.tscn` → **复制** →
   粘贴到你的章包目录 → 改名 `seg01.tscn`；
2. 双击打开，选中根 `StageSegment`，Inspector 里：
   - `segment_id` = `seg01`（本章内唯一；漏了/重了校验器点名 R2）；
   - `entry_points` 不用动（默认出生点已在触发线左边，合法）；
3. 想改房间大小：拖 `Room1`（虚线框）的四边把手 → 然后把 Inspector 里
   `limit_left / limit_top / limit_right / limit_bottom` 四个数**改成和框一致的数**
   （框是给你看的，运行时只认 limit 四个数，引擎不替你对齐——这是最容易忘的一步）；
4. 想换怪的组成：选中 `Room1/EnemySpawner1`，Inspector 的 `spawn_waves`：
   外层一项 = 一波，内层一项 = 这波里的一只怪；每张卡的 `enemy_scene`
   下拉选角色文件（现成的敌兵：`characters/enemies/spar_enemy/spar_enemy.tscn`）；
5. 存盘。施工红线清单一直钉在这个文件的根节点 Inspector 最底部
   （`_assembly_notes`），忘了随时点开对照。

段模板里各节点是干什么的（都在场时它们长这样）：

| 节点 | 作用 |
|---|---|
| `GroundBody` / `WallL` / `WallR` | 真·物理：地面和左右两堵看不见的实体墙（别删；配方被校验器盯着） |
| `Room1`（及其下的 `EnemySpawner1`、`PlayerDetector`） | 战斗房：触发线在房左边，玩家撞线→锁镜头刷怪，全灭→向东放行 |
| `Vis*` 几件 | 纯摆设的示意色块（地板/墙/触发线颜色）+ 一块提示文字，删了不影响玩法 |

### 第 3 步｜把段挂上壳

打开 `chapter_1.tscn` → 根节点 → `segment_scenes` 数组 → 加元素 →
**把 `seg01.tscn` 从 FileSystem 拖进槽**。多段就继续加，数组顺序 = 玩家推进顺序。

### 第 4 步｜每轮改完的固定验收（3 件事）

1. **跑校验器**（在 xuanyuan-sword 目录下的 PowerShell）：
   ```
   godot.exe --headless --path . -s tools/stage_validator/validator.gd
   ```
   ✅ 你的新文件要出现在输出里，且最后一行"**违例 0**"才算数。
   每条违例自带修改提示；看不懂编号就查 `术语表.md` 第二节。
2. **跑起来**：编辑器选中 `chapter_1.tscn` 按 **F6**（段文件不能单跑——段里没有玩家）。
3. **用眼睛过一遍**：
   - 向右走撞进绿色触发带 → 镜头收进房间 + 敌人刷出；
   - J 把敌人全打掉 → 镜头向东放开，能继续向右走；
   - 走路撞到场地边缘无感停下；被击飞撞到看不见的弹回（掉 5 血只发生在被击飞撞墙时，是设计）；
   - ESC 出暂停；故意送死 → 从本章检查点复活；
   - 最后一段打完 → **自动弹出章终点面板**（返回标题/重走一遍）并定格。
     "重走一遍"保留你的宝箱/学习记录（账本不重置）。

### 第 5 步｜想标题画面直接能进来？

标题页现在入口指向参考章（`scenes/stages/ref/chapter_ref_a.tscn`）。换成你的章
需要改一个代码文件（`ui/menus/title_screen.gd` 第一行常量）——**这属于工程侧动作，
找工程侧改**，你不用自己开代码编辑器。改完从 F5 全流程走一遍即可。

## 二、任务配方卡（"我想…" → 怎么做）

| 想做的事 | 怎么做 |
|---|---|
| 加一个**宝箱** | 段内实例化 `scenes/chapter/interact_trigger.tscn`（右键段根 → 实例化子节点）→ 摆位（玩家要能站进那个框）→ 改 `prompt_text`（按 E 时显示的提示语）→ 选中 trigger 右键 **添加子节点 → Node** → 属性 Inspector 里"附加脚本"选 `scripts/chapter/reactions/interact_chest.gd`（显示名 InteractChest）→ 填 `chest_id`（本章内唯一，重名校验器点名）。玩家开箱后东西**永久记录**，重玩不复活，全程零代码 |
| 宝箱给**法术秘籍** | 同上，附加脚本换成 `interact_spell_book.gd`（InteractSpellBook），`spell_id` 填 `fire_ball`（现成法术）。玩家捡起就会放，按 1 释放 |
| **锁着的门** | 附加脚本换 `interact_gate.gd`（InteractGate）：在 trigger 上填 `requires_flag`（需要的通行证名）；再让某个宝箱的 `grants_flag` 填同一个名——形成"开宝箱→得钥匙→开门"链 |
| **加一波怪** | 选 `EnemySpawner1` → `spawn_waves` 数组加一项（=追加一波），内层加条目（=这波多几只并发）。每张卡 `enemy_scene` 下拉选角色；`spawn_mode=1` + `use_spawner_position=true` 照段模板抄 |
| **造一个新敌兵** | 打开 `templates/character/character_template.tscn` → 右侧 Inspector 的创建面板 → "控制方式"选 **AI 自动战斗**（自动进 `characters/enemies/`，自带"待机→靠近→三连段"默认打法）→ 填名字和出生数值 → Create → 回 spawner 的下拉里选它 |
| **做一个新法术** | 同样走 Inspector 创建面板（模板 `templates/spell/`，参照现成的 `fire_ball`）。想让玩家学会它 = 摆一个秘籍宝箱（见上两行） |
| **过场段（不打怪，直接往下走）** | 复制段模板 → 把 `Room1` 整棵删掉 → 根上勾 `auto_complete`（一进段就算打完自动推进）。以后放对话/剧情就走这类段 |
| **想让某段有夜晚** | 壳的 `Ambient/DayNightController` 的 `scene_time_data` 挂一份时间数据（现成文件在 `resources/lighting/`：`day_cycle_default.tres` 正式昼夜 / `day_cycle_demo.tres` 60 秒一圈看效果 / `day_neutral.tres` 恒定白天）；想要"每一段固定不同天色"用段根的 `lighting_color`。详见 `GUIDE_光照.md` |
| **阴影只在场地内**（性能+好看） | 段根加一个 ReferenceRect → 附加脚本 `scripts/shadow_region.gd`（ShadowRegion）→ 框住可行走地面。**两个框不许重叠**（重叠处会双倍变暗）。脚下阴影的柔化效果默认已开，按 L 对比 |
| **打完后能继续向右走多远** | 段模板预置了"战后向东放开到 x=1900"。想改成别的数：Inspector 里看不到这四个属性（尚未开放，工程侧待办），**找工程侧改** |
| **摆个不打的 NPC** | `characters/neutrals/street_vendor/street_vendor.tscn` 直接实例化进段里（站摊型，不追不逃） |
| **这段镜头拍特定目标**（NPC/物件/被控者） | 选中段根 `StageSegment` → `camera_host_path` 填该段里某节点的**路径**（如 `Npc`）→ 玩家一进这段镜头就挂上去；**下一段没填就自动跟回当前被控角色**（严格申报制，不会"忘了换回来"）。镜头只换"挂谁"，操作照常。想代码即席改：`壳.set_camera_host(节点)` |
| **这段换人操控**（剧情接管） | 段根 `control_target_path` 填该段里某个角色节点路径（谁都能被接管：友军、小贩，甚至敌兵——敌兵接管后阵营照旧、互相打不动属已知局限，找工程侧立项）→ 进场那刻：新角色变你操控、旧角色留在原地替他原先的立场（行为互换）；**下一段没申报=自动换回壳定的初始角色**。要敌人围攻新被控者：给敌人填索敌组 `ai_target_groups`（默认打玩家标签；填 `controlled` 就打"当前被控者"）。工程细节与局限见 STATUS 接管批案卷 |
| **跨章出口** | `scripts/stage_exit.gd`——**只能摆在永不打完的过场段**（最后一段打完会弹面板定格，出口就没机会碰到了；抄参考章 `seg_ref_a3.tscn` 的做法） |

## 三、现成零件清单

| 类 | 有什么 | 在哪 |
|---|---|---|
| 玩家 | 陈靖仇（完整动作+格挡） | `characters/playable/chen/chen.tscn`（拖进壳根 `playable_override` 当主角） |
| 敌兵 | 对练敌人（AI 三连段样板） | `characters/enemies/spar_enemy/spar_enemy.tscn` |
| 被动 NPC | 街头小贩 | `characters/neutrals/street_vendor/street_vendor.tscn` |
| 法术 | 火球（含秘籍学习链） | `spells/fire_ball/` |
| 互动 | 触发件 + 宝箱/秘籍/门/QTE 四反应脚本 | `scenes/chapter/interact_trigger.tscn` + `scripts/chapter/reactions/` |
| 光照数据 | 恒定白天 / 正式昼夜 / 60 秒演示 | `resources/lighting/*.tres` |
| 命中火花 | 五种风格参数卡（按攻击类型自动用，不用摆） | `scripts/effects/presets/` |
| 活教材 | 一个完整两章参考（含过场段出口+黑夜正例） | F6 跑 `scenes/stages/ref/chapter_ref_a.tscn` 和 `chapter_ref_b.tscn` |

键位速查在 `术语表.md` 第四节。

## 四、常见病 → 自救（校验器没拦住的）

| 症状 | 大概率原因 | 怎么办 |
|---|---|---|
| 出生瞬间被"瞬移" | 出生点在触发线右边，开局第一帧就被拉进锁房 | 出生点挪回触发线左边几十像素 |
| 撞进触发带不刷怪 | 刷怪点的 `path_spawn_parent` 被改过，或 `enemy_scene` 没选 | 改回段模板原值 `../../../../Players`；重选角色文件 |
| 怪全灭但不推进 | 检测器的 `paths_enemy_spawners` 数组漏了某个刷怪点 | 把本房所有 spawner 都列进这个数组 |
| 走路被弹开+掉血 | 地面/墙的物理配方被改了 | `collision_layer=16760832`、`collision_mask=0` 改回 |
| 角色脚下阴影有两层 | KeyLight 的 `shadow_enabled` 被勾上了 | 取消勾选（这个灯不产阴影，阴影另有系统） |
| 按 E 宝箱没反应 | 三查：人没站进框 / trigger 下没挂反应子节点 / 子节点没附加脚本 | 逐个补 |
| 背景图把角色盖住了 | 背景 CanvasLayer 的 `layer` 写了 0 或正数 | 改成负数（如 -1） |
| 明明外部改过，编辑器一保存又变回旧版 | Godot 编辑器长时间开着会把旧版本"盖"回文件 | 重启编辑器再继续；改得多的话提交前先跑校验器 |
| 校验器说编号重名 | 两个宝箱/秘籍想记同一笔账 | 各起各的唯一名 |

## 五、现在还没有的（别自己造）

- **对话**：在做下一批，需要对话的段先用"过场段"占位；
- **过场动画/章节间演出、音频**：都在后续批次；
- **新的互动玩法**（商店、任务板之类）：先提出来一起定方案，**别在段里写胶水代码**——
  现成的四件反应件不覆盖的需求，值得立项做，不值得绕。

## 六、版本注记（工程侧）

2026-10 文档整改批通俗化重写（事实基线：5a 壳清空、5b 单轨后现状）。
批次案卷在 DEVELOPMENT_STATUS / 根目录 PLUGIN_CHANGES，此处不抄。
