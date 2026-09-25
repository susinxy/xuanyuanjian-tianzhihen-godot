# S2-B4 法术接入 + 存档账本体制 · F5 人工验收单（Windows）

批范围 headless 已跑：**全矩阵 24 套 = 25 跑 RED=0**（commit `28b2391`，含新套
spell_save_contract 124 断言，日志快照 `/tmp/opencode/b4_t3b/matrix_full.log`）。
本单只做机器看不到/不可靠的事：**施法命中的观感**（E6 敌血下降腿 headless 全窗
未捕获，人眼终审）+ 吞改纪律复查。

## 头部纪律（必读，两条都是本仓库判例）

1. **GameSave autoload 入册核验**：本批 `project.godot` 的 `[autoload]` 新增了
   `GameSave="*res://scripts/save/game_save.gd"`（T0 改动时编辑器已关）——
   **重开编辑器后**去 Project Settings → Autoload 列表确认 **GameSave 在位**。
   列表缺席=`project.godot` 被编辑器旧内存回写吞过（本月判例），报回勿硬跑。
2. **首开可能"内容不变重存"若干 .tscn/.tres——勿误判吞改**：本批新夹具
   （`tools/spell_save_contract/fixtures/*.tscn`、r12 七夹具）与
   `fire_ball_definition.tres` 新增的 ext_resource 行**未带 inline uid**（与全部
   既有夹具同惯例，headless 不生成 sidecar）——Windows 编辑器首开会给它们
   **自动补写 uid 并重存**（伴随症状=同会话所有加载过的资源被批量刷 mtime）。
   这是"内容不变重存"指纹，不是外部改动被吞；**git status 复核内容 diff 即可**
   （只多 uid=行内容未变则正常；出现语义变化才报案）。改完资源后不要再在
   Windows 端手存这些文件，防与 Linux 端后续手术互相覆写。

## 场地与前置

- **场地 = 编辑器打开并 F5 直跑章壳夹具**
  `res://tools/spell_save_contract/fixtures/chapter_b4.tscn`
  （路径实读自 `spell_save_contract.gd` 的 `FIX_B4_CHAPTER`——与 E 流同场；
  单段 `seg_b4_manual`：秘籍触发件在段内 (520,600)，小练 spar_enemy 在 (820,600)）。
- **替身前置（先做再 F5）**：夹具 `playable_override` 指向
  `res://characters/playable/test_actor/test_actor.tscn`——test_actor 是矩阵
  代管产物，**每轮真建真删**（上轮矩阵批末跑完已销毁），且 Syncthing 侧建议
  忽略 `characters/playable/test_actor*`。缺席时 F5 该夹具会报 ext_resource
  打不开——那是前置未做，不是交付缺陷。处方：**Linux 端跑
  `bash tools/matrix_runner/run_matrix.sh --ensure-only`**（只建替身不跑名册、
  建后不销毁）→ Syncthing 送达 Windows（若忽略规则已设，临时解除拉一次再恢复）
  → 编辑器扫盘就绪后再 F5。
- 键位（实读 `project.godot [input]`）：**E**=拾取（interact）· **1**=法术槽1
  （spell_1，物理键）· **R**=原型重载（debug_restart，仅 debug 构建）·
  **ESC**=暂停壳。

## 验收五眼

每眼三栏：预期已按契约/夹具实读写死；「实际」「过不过」由验收人填。

### 眼① 拾得即学：火球出手 + 命中观感（E6 人眼终审项）

进夹具后主角（替身，chen 占位画）向右走几步到秘籍提示处按 E，再按 1：

| 预期 | 实际 | 过不过 |
|---|---|---|
| 按 E：秘籍触发件 0.4s 缩小消失（触发件自毁）；按 1：角色进施法姿势、火球弹体出手飞向小练并命中，**小练血条肉眼可见下降**（此为 headless 从未捕获的 E6 面）；小练还手正常 |  |  |

### 眼② 走出再回：仍会、秘籍不再出现

沿路向左走开（离开原触发区一段距离）再走回秘籍原址：

| 预期 | 实际 | 过不过 |
|---|---|---|
| 秘籍**不再出现**（已被消耗、节点已释放，段未重建时不复活）；按 1 仍响——火球照常出手（学习跟着角色走，与场地无关） |  |  |

### 眼③ 死亡段重跑：仍会

故意站桩让小练打死：

| 预期 | 实际 | 过不过 |
|---|---|---|
| 死亡→段重跑（D4，落回出生位）后按 1 **仍会**（出生补学块查账回填）；重跑=未判清段丢弃重建，**秘籍会重新出现在 (520,600)**——属设计知情（件不做外观级判重，二次 E 仍会消耗消失、**不重学、槽位不超发**），勿按红报 |  |  |

### 眼④ 原型重载：仍会（重载不清账）

按 **R**（debug_restart）做整场景原型重载，再走 E→1 或径直按 1：

| 预期 | 实际 | 过不过 |
|---|---|---|
| 重载后按 1 **仍会**——B4 新语义"重演不碰账"（spec §2）：账随进程，重载/重跑一律不清账，唯一清账口是标题"开始游戏"的 new_profile |  |  |

### 眼⑤ 新档=清账：回标题点"开始游戏"→重进夹具

ESC→暂停壳"返回标题"；在标题点 **"开始游戏"**（该钮=GameSave.new_profile()
建档清账；顺带观察：此进程内被送进 ref_a 后按 1 **无反应**=清账已在同进程实发）。
再回编辑器 F5 重跑夹具（内存账本随进程生灭，新进程起点天然=新档态）：

| 预期 | 实际 | 过不过 |
|---|---|---|
| 秘籍**回到原处**（520,600、提示在）；按 1 **无反应**（spells_known 空账、出生补学无账可补）；重新按 E 可再学（新档重新来过） |  |  |

（说明：标题→夹具无游戏内路由，"重进夹具"以编辑器重跑 F5 承载；同进程清账的
机器面已由契约 R2 腿 v3 全 false 锁死，本眼验的是观感。）

## 附注：spell_scene 生产缺口复查（T3a 实锤移交项）

`fire_ball_definition.tres` 此前**从未挂 `spell_scene`**（E2E 首抓的真生产缺口：
缺件+spell_manager 无守卫=游戏内按 1 必崩，曾被测试套运行时打补丁掩盖）。
T3a 已补接线（现盘上第 4/10 行：ext_resource → `res://spells/fire_ball/fire_ball.tscn`）。
**请重开编辑器后**打开 `res://spells/fire_ball/resources/fire_ball_definition.tres`，
在 Inspector 确认 `spell_scene` 字段在位且指向 `fire_ball.tscn`（吞改判例：
编辑器长会话旧内存对象下一次保存整文件覆写——确认在位前勿顺手 Ctrl+S 该资源）。

## 判项表获取方式（本单刻意不手抄）

判项表（哪些事实存、哪些不存的总表）= **spell_save_contract X 流③运行时打印**：

```
godot --headless --path . res://tools/spell_save_contract/spell_save_contract.tscn
```

看输出中 `── X3 申报名册（判项表=报表，spec §2.1/§3 门三）──` 起的逐类
`类名 | persists | resets` 块。**文档是报表不是公约**（spec §2.1），防漂移禁手抄。

---

任何一条异常：截图/日志发回，按 SDD 修复轮回炉。
