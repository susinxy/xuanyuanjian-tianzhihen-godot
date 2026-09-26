# S2-B4.6 攻击朝向模式 · F5 人工验收单（Windows）

**★全局行为变更（知情报头，用户裁决②）**：本批落地后，**所有既有角色**
（chen/spar_enemy/street_vendor/模板产线——凡 tres 未写 `attack_axis_mode`
行的）地面攻击**自此恒为横拳**：出手向=最近一次左右朝向 `facing_x`（与跳跃
同源），朝正上/正下不再出纵拳。这是已 F5 验收的纵向拳手感的默认翻横、知情
定档——验收中若觉得"上攻没了"，那正是本批行为，不是回归。回收通道=Inspector
逐角色改回"上下左右"（眼②走一遍）。

批范围 headless 已跑：**全矩阵 24 套 = 25 跑 RED=0**（终核快照
`/tmp/opencode/b46_matrix/`；attack_lane_contract 扩至 **42 断言**含 H 腿组
+ 纵向腿括弧自洁）。机器看不到的是：真键手感、Inspector 真改档写回、
创建面板 widget 真实点选（T1 移交明言：UI 点选腿=机器化之外唯一缺口）——
三眼归 Windows。

## 头部纪律

1. **本批零 `project.godot` 触点、零吞改高危面**（无新 autoload/输入动作；
   插件触点只有两枚 .gd：`quiver_attributes.gd` + `quiver_action_attack.gd`，
   外加创建器两件套与文档）——但外部改过多份脚本后，按长会话吞脚本判例
   （2026-09-17）**重开编辑器再动资源**，首开等常规扫盘编译完毕。
2. 眼②/眼③是本批在 Windows 侧仅有的两处合法落盘（chen tres 加行、临时角色
   目录），**测毕按各眼清场步骤复原**——chen 不回横不会污染 headless 矩阵
   （契约吃代码默认+替身），但会污染后续批次的 F5 基线。

## 场地与前置

- 场地 = F6 直跑 `res://scenes/stages/ref/stage_ref_a.tscn`（chen 在场的
  法定样板地；走标题壳 F5 进场亦可）。
- 键位：**WASD** 移动 · **J** 攻击 · **Space** 跳跃。
- 替身 test_actor 无需前置（本单不用夹具场景）。

## 验收三眼

每眼预期按契约/实现实读写死；「实际」「过不过」由验收人填。

### 眼① 默认横模手感（chen，零配置即横——裁决②③行为面）

1. 按 **D** 向右走几步 → 转按 **W** 朝正北上行几步（输入 x=0）→ 按 **J** 出手；
2. 按 **A** 向左走几步 → 转 **W** 正北上行 → 再出手；
3. 对照腿：接第 2 步站位（最后水平朝向=左）直接按 **Space** 正北起跳，
   看腾空起跳姿势朝向。

| 预期 | 实际 | 过不过 |
|---|---|---|
| 第一次出手=**横拳朝右**（W 上行前最后一次左右向=facing_x 记忆） |  |  |
| 第二次出手=**横拳朝左**（拳不随上行输入转向北） |  |  |
| 正北起跳姿势朝向=**左**（与第二次出手同向）——跳/拳同值对照属**人眼独占的字面级**；契约面按实现实况只锁"快照 x==facing_x"直证+传递等值（两者措辞差异见 spec §4 H2 字面 vs 实现的批评审 INFO#2） |  |  |

### 眼② Inspector 真通道 + 四向路径未死（测毕必回档）

编辑器 Inspector 打开 `characters/playable/chen/resources/chen_attributes.tres`，
Behavior 组下找 `attack_axis_mode`
（当前 tres **无该行**=代码默认横模，Inspector 仍显示枚举下拉）→ 改
`上下左右`（FOUR_DIRECTION）→ Ctrl+S → F6 重跑，重复眼①第 2 步（左行后正北出手）：

| 预期 | 实际 | 过不过 |
|---|---|---|
| 正北出手=**纵拳朝上**复活（四向模式主轴塌缩路径健在） |  |  |
| 保存后 tres 出现 `attack_axis_mode = 0` 行（Inspector→写回通道实证） |  |  |
| **改回** `HORIZONTAL_ONLY` 并保存，重跑=横拳回来了；tres 回档（行删掉或 =1 均可）——清场义务 |  |  |

### 眼③ 创建面板下拉真实点选（widget 机器化之外缺口；测毕清场）

打开 `templates/character/character_template.tscn` → 选根节点 → Inspector
"Create New Character" 表单：

1. 找**"攻击朝向模式"**下拉：默认选中=**"只有左右"**；
2. 临时角色：英文名 `b46_probe`，下拉改选**"上下左右"**，其余默认 → Create；
3. 出生后进 Inspector 看 `characters/playable/b46_probe/resources/b46_probe_attributes.tres`；
4. （可选加验）F6 直跑该角色出场场景正北出手应为纵拳=四向档出生自证；
5. 测毕在表单 "Delete Character" 区删除 `b46_probe` 并确认。

| 预期 | 实际 | 过不过 |
|---|---|---|
| 下拉在数值区可见可点，默认"只有左右"；改选"上下左右"不被校验/焦点吞 |  |  |
| 新角色 tres 带 `attack_axis_mode = 0` 行（面板→stats 字典→合成落盘全链；wp2 已 headless 锁死后半段，本眼验**真实点选→字典**前半段） |  |  |
| 删除后目录消失、编辑器无红错（测毕清场，防矩阵外残角） |  |  |

## 回执

三眼表填毕回贴本文件或转述；任一眼"实际"与预期语义不符即开案卷回炉
（报症状即可，Linux 端带契约回放定位）。
