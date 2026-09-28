# GUIDE_关卡搭建 —— 章节与场景的内容生产说明书

> 读者：用 Godot 编辑器搭关卡的内容贡献者（不需要开代码编辑器）。
> 法源：红线与法律条款在 `docs/STAGE_ASSEMBLY.md`（本手册只讲"怎么点"，条款号
> 指过去，不复抄——防两处真相漂移）。战斗手感见 `GUIDE_格挡.md`，光照细则见
> `GUIDE_光照.md`。
> 版本：2026-09-28 r2（5a 壳清空批：壳=空场地基，主角由 `playable_override` 放；
> 此前版本=段模板立形批）。

## 〇、先立心智模型：壳与段是两个文件，不是一件事

```
chapter_1.tscn（壳=剧场本身，空场地基）      seg01_opening.tscn（段=第一幕戏）
 ├─ 主角位：你放的角色（见下方"放主角"）     ├─ 地面/墙/战斗房/触发线/刷怪点
 ├─ HUD/暂停/死亡/终点面板                  ├─ 入口点 entry_points
 ├─ 昼夜光照                                └─ （不放玩家——玩家归壳管）
 ├─ 跟随相机（壳自动补挂在你放的主角身上）    ← 你也不用摆相机
 └─ segment_scenes = [段1, 段2, ...] ← 连接就在这一行：拖段文件进来
```

> **壳里没有默认主角**（5a 清空批，2026-09-28）：模板不内嵌任何角色——
> "玩家"就是**你放进场地的任何带 `area2d:player` 标签的角色**，想换谁当主角
> 换谁的 .tscn，敌/友/NPC 都只是标签与行为档的组合。相机由壳负责补挂。

| 疑问 | 答案 |
|---|---|
| 壳建完就能玩吗？ | 还不能——壳是空场：没放主角跑起来会红字"空场无主角"（这是护栏不是故障），`segment_scenes` 也空着。壳+放主角+段+挂接是**一件事的几道工序**（第 1 步内含放主角） |
| 内容为什么不直接画在壳里？ | 一章 N 个段要独立保存、独立重跑（死亡=只重跑当前段）；全画壳里=整个结构锁不上检查点 |
| 段模板里怎么没有玩家？ | 故意没有（**零壳件铁律**）：玩家/相机/HUD 全章一份归壳；段只有"这段场景长什么样、打什么、捡什么" |

两条铁律，违反必回炉：
1. **段里禁放任何壳件**（玩家/相机/HUD/CanvasModulate）——段模板里本来就没有，别手滑拖进去；
2. **段的入口必须放第一道检测线西侧**（段模板默认值已合法，挪线就要挪入口）。

## 一、工作流 A：从零跑通一章（首战照抄）

### 第 1 步｜建壳（3 分钟，全程编辑器鼠标操作）

> 法定样板（ref_a 等）的"根=壳实例"文件形制由工程侧生成；内容贡献者在编辑器里
> 建壳的**唯一正规操作**是下面的"场景另存为"，校验器对两种形制都放行，并且
> 会替你盯着别忘了填 `chapter_id`（实测：漏填=R2 响亮红）。

1. **开模板**：编辑器底部 FileSystem 面板 → `scenes/chapter/` → **双击**
   `chapter_shell.tscn`。
   ✅ 成功判据：左侧场景树出现根节点 `ChapterShell`，下有
   `Players/Chen(+LevelCamera)`、`HudLayer`、`Ambient`、`Segments` 四棵子树。
2. **另存为你的章**：顶部菜单 **场景 → 场景另存为…**（Scene → Save Scene As…）
   → 在文件对话框里进入 `scenes/stages/<你的章包>/`（没有就右键 → 新建文件夹，
   snake_case 命名，一章一个）→ 文件名 `chapter_1.tscn` → 保存。
   ✅ 成功判据：编辑器标题栏变为 `chapter_1.tscn`；**原模板没被动过**
   （另存自动切换工作对象；手滑 Ctrl+S 到 `scenes/chapter/` 旧路径则去
   git 还原模板，别慌）。
3. **填身份+放主角**：左侧点选根节点 `ChapterShell` → 右侧 Inspector 向下滚到导出属性：
   | 字段 | 填什么 | 注意 |
   |---|---|---|
   | `chapter_id` | 如 `&"ch1"` | **全局唯一**，死亡检查点认它；**忘填校验器 R2 会红** |
   | `playable_override` | **从 FileSystem 拖一个玩家档角色 .tscn 进来**（如 `chen.tscn`） | 这就是"主角"——想换主角换这个文件；留空且 Players 里也没摆角色 → 跑起来红字"空场无主角"，校验器 R14 也会拦 |
   | `playable_path` | 一般留空 | 只有当场上同时有 ≥2 个玩家标签角色时才需要显式指定其中一个（歧义裁决槽） |
   | `camera_host_path` | 一般留空 | 留空=相机自动挂在主角身上；想拍 NPC（演出位）可显式指它；运行时脚本用 `set_camera_host()` 改挂 |
   | `segment_scenes` | 留空 | 第 3 步再填 |
4. **Ctrl+S** 保存。
5. （可选先跑为快）**F6** 单跑这个壳：你放的角色能走能动（J/K 键有反馈）、ESC 有暂停菜单=壳建成。此刻没段、没场地，走到哪都空旷——**正常**。

> **已知代价（知情条款）**："场景另存为"=结构拷贝。将来壳模板升级（HUD/暂停/
> 相机服务）不会自动进你的章节文件，由工程侧同步（后续批次将提供一键生成面板
> 免除本代价）。单章生命周期内无影响，放心用。

壳自带玩家+相机+HUD+暂停/死亡/终点面板+昼夜三件套（不挂数据=定格白天），
**第 1 步里什么都不用摆**。

### 第 2 步｜建第一段（5 分钟）
1. FileSystem 面板右键 `scenes/chapter/segment_template.tscn` → **复制** →
   粘贴到你的章包目录 → 重命名 `seg01_opening.tscn`；
2. 双击打开 → 选中根 `StageSegment` → Inspector：
   - `segment_id` = `seg01`（章内唯一；**漏填校验器 R2 会红**，重复了也会红）；
   - `entry_points` 保持默认 `{&"default": (500, 600)}`（已在检测线西，合法）；
3. 想改房间大小：拖 `Room1`（白色虚线框）四边把手 → 然后**手动把 Inspector 里
   `limit_left/top/right/bottom` 改成与 offset 四值同数**（offset=编辑器可视，
   limit=运行时执法，引擎不代你同步）；
4. 存盘。红线清单全文钉在根节点 Inspector 最底部 `_装配须知`（metadata），
   施工时点开对照。

### 第 3 步｜段上壳
打开 `chapter_1.tscn` → 根 `segment_scenes` 数组 → 加元素 → 从 FileSystem
**把段文件拖进数组槽**（可拖多个，顺序=推进顺序）。

### 第 4 步｜验收三件套（每轮改动后，固定动作）
1. **校验器**（Windows PowerShell 示例）：
   ```
   godot.exe --headless --path . -s tools/stage_validator/validator.gd
   ```
   输出里你的新文件要出现且"**违例 0**"才算数；每条违例自带处方，先读处方。
2. **跑壳**：编辑器选中 `chapter_1.tscn` 按 **F6**（跳过标题页直接进章）。
   注意：**段文件不能单独 F6**——段里没有玩家，跑了没法操控。
3. **眼检清单**：
   - 向右走撞绿色触发带 → 相机锁房 + 刷出敌人；
   - J 攻击把敌人打掉 → 全灭后相机向东扩权（能继续往右走一段）；
   - 撞左右实体墙 → 行走无感、击飞状态撞墙弹回（掉 5 血只在击飞时=设计）；
   - ESC → 暂停菜单；死亡 → 回跳检查点应含本章；
   - **全部段清完后停在末段没有演出=预期**（`chapter_finished` 的消费口在
     过场批 B7，尚未接线）。

### 第 5 步｜合流
想让标题页能进来：改 `ui/menus/title_screen.gd` 顶部
`const GAMEPLAY_SCENE` 指向你的 chapter_1.tscn，从 F5 全流程走一遍，**验完还原**
（法典纪律：不合流不提交；每段独立提交可以）。

## 二、工作流 B：任务配方卡（"我想…" → 动作）

| 想做的事 | 操作卡 |
|---|---|
| 加一个**宝箱** | 段内实例化 `scenes/chapter/interact_trigger.tscn` → 摆位（站在框里才生效）→ 改 `prompt_text`；在它上面右键 **添加子节点 → Node** → 附脚本 `InteractChest` → 填 `chest_id`（**全章唯一**，撞了校验器会点名）。开箱记录自动跨存档，零代码 |
| 宝箱给**法术秘籍** | 同上，子节点附脚本改 `InteractSpellBook`，`spell_id`=`fire_ball`（现成）→ 玩家捡起即会，施法键 1 释放 |
| **锁着的门** | 子节点附 `InteractGate`；在 trigger 上填 `requires_flag`，用某宝箱的 `grants_flag` 喂它（箱→钥匙→门链） |
| **加一波怪** | 选 `EnemySpawner1` → Inspector `spawn_waves`：外层=波序，内层=同波并发；每张 SpawnData 卡：`enemy_scene` 下拉选角色 `.tscn`，`spawn_mode=1`+`use_spawner_position=true` 照抄 |
| **新兵种** | 打开 `templates/character/character_template.tscn` → Inspector 的创建面板 → 控制方式选 **AI 自动战斗**（自动进 `characters/enemies/` 并挂"歇→追→三连段"策略小抄）→ 出生数值在面板填 → Create → 回 spawner 卡选它 |
| **新法术** | SpellCreator 面板（`templates/spell/`，fire_ball 为参照件）；给玩家学会=摆秘籍件 |
| **过场/占位段** | 复制段模板 → **删 Room1 整棵** → 根 `auto_complete=true`（进段即判清推进）。对话段将来接 S3 时改造此类段，现在先占位 |
| **黑夜段** | 壳的 `Ambient/DayNightController.scene_time_data` 挂 `resources/lighting/day_cycle_default.tres`（正式 24h）或 `day_cycle_demo.tres`（60 秒快进试机）；段根 `lighting_color`=该段入场画布色；细则见 GUIDE_光照 |
| **阴影只在场地内** | 段内加 ReferenceRect → 附脚本 `ShadowRegion`，框住可玩地面；**多框禁重叠**（重叠=双倍变暗）。软边已默认开，L 键调试对比 |
| **战后向东续一段** | 段模板已预置该形（`after_fight_use_new_room=true`+四 `after_fight_limit_*`），改 limit 值即可 |
| **NPC 站摊** | `characters/neutrals/street_vendor/street_vendor.tscn` 直接摆段里（被动档，不逃不打） |

## 三、零件库速查

| 类 | 现成件 | 路径 |
|---|---|---|
| 玩家 | 陈靖仇（全动作+格挡真图） | `characters/playable/chen/chen.tscn`（壳已自带，勿重复摆） |
| 敌兵 | 对练敌人（AI 三连段样板） | `characters/enemies/spar_enemy/spar_enemy.tscn` |
| 被动 NPC | 街头小贩 | `characters/neutrals/street_vendor/street_vendor.tscn` |
| 法术 | 火球（秘籍学习链已通） | `spells/fire_ball/` |
| 互动 | 触发件+反应四件 | `scenes/chapter/interact_trigger.tscn` + `scripts/chapter/reactions/` |
| 光照数据 | 中性/正式昼夜/60s 演示 | `resources/lighting/*.tres` |
| 特效参数 | 命中火花五风格卡 | `scripts/effects/presets/spark_*.tres`（自动路由，无需摆） |

**键位**：J 攻击 / K 格挡弹反 / E 互动 / 1 法术 / L 软边开关（调试）/
V 特效开关（调试）/ ESC 暂停 / F8 快速重开（调试）。

## 四、常见病 → 处方（校验器没拦住的）

| 症状 | 大概率根因 | 动作 |
|---|---|---|
| 出生瞬间被瞬移/拉位置 | 入口在检测线东侧，首帧锁房收口 | 入口挪回线西几十 px |
| 穿线不刷怪 | 生成器 `path_spawn_parent`≠`../../../../Players`，或 `enemy_scene` 空 | 照段模板原值改回 |
| 打完全灭不扩权/不推进 | 检测器 `paths_enemy_spawners` 漏列本房生成器 | 补齐数组 |
| 走路贴边被弹开+掉血 | 场地 StaticBody 配方被改 | layer=`16760832`、mask=`0` 改回 |
| 角色脚下双层阴影 | KeyLight 勾了 `shadow_enabled` | **取消勾选**（法典级禁令） |
| 按 E 宝箱没反应 | 没站进触发框 / 忘了挂 Reaction 子节点 / 子节点没附脚本 | 三查 |
| 段里背景盖住角色 | Background 换件后 layer≥0 | CanvasLayer 的 `layer` 必须 <0 |
| Ctrl+S 后外部改动"复活回旧版" | 编辑器长会话吞改（Syncthing 判例） | 重启编辑器再来；`git diff` 机检 |
| 校验器报 ID 撞名 | 多件争一笔账 | 改 `chest_id`/`segment_id` 至唯一 |

## 五、还没有的（别自己造轮子）

- **对话**：Dialogic 选型已定，S3 批接线——现在需要对话的段用"过场占位段"；
- **过场/视频/章节间跳转演出**：B7 批；
- **音频**：S4 批；
- **新种类互动机制**（商店/任务板之类）：回设计会立项，**别在段里手写胶水**
  （法典条 10）。

## 六、单地点轨（了解即可）

`scenes/base/base_stage.tscn` 轨=旧"一个场景一个地点"形制（ref_a/b 属这类）。
**新章节一律走壳轨**；单地点原型（试验一个独立大竞技场）才用 base_stage 轨，
五件事流程见 STAGE_ASSEMBLY §0.2。两轨能力等值、互不混装。
