# 角色模板（_template）

> 2026-09-14 起：模板内容 = **chen 的占位符化快照**（旧"骨架模板"退役）。
> 新角色创建出来即自带完整可跑状态：全动画结构 + 演示图（chen 的图）+ 属性/攻击演示值。

## 创建新角色（单壳+行为脚本，2026-09 起）

Inspector 面板：打开 `character_template.tscn` → 填英文名/类名/显示名 → 选**控制方式**与**阵营** → Create。
占位符：`__NAME__`（snake）、`__CLASS__`（Pascal）、`__DISPLAY_NAME__`、`__PKG__`（阵营包目录）、
`__BODY_GROUP__`（根节点 body group）、`__BEHAVIOR_MODE__`（行为档）。

| 控制方式 | 阵营 | 输出目录 | behavior_mode | 出生即有何行为 |
|---|---|---|---|---|
| 玩家操控 | players（锁定） | `characters/playable/` | 0 | 键盘采集（含法术键） |
| AI 自动战斗 | enemies（锁定） | `characters/enemies/` | 1 | 挂 `<名字>_ai.gd` 小抄：歇→追→三连段 |
| 被动站立 | 四选自由 | `playable/ · enemies/ · allies/ · neutrals/` | 2 | 站桩；受击/死亡反应完好 |

所有档位共用同一具身体与同一套动作树（`docs/PLUGIN_ARCHITECTURE.md` 5.0）。
玩家/AI/被动角色一律进 git 内容管理（playable 仍按旧例外规则忽略）。

## 改动路由表（每次想改东西，先查这张表）

| 想改什么 | 改哪里 | 动壳吗 |
|---|---|---|
| 美术图、动画、伤害、阴影 | 身体资源（同名覆盖/轮廓面板） | 否 |
| 这只 AI 怪的节奏/攻击距离/休息时长 | 它自己的 `<名字>_ai.gd`（常量 `ATTACK_RANGE/REST_DURATION`，逻辑在 `tick()`） | 否 |
| 个别怪的特异功能（逃跑/远程/多阶段） | 写它自己的小抄子类逻辑（工具方法在 `QuiverBehaviorAI`） | 否 |
| 一群怪共用的新能力 | 插件 `characters/behaviors/` 或状态积木 → 全体受益 | 插件层 |
| 剧情让它反过来受玩家操控 | 运行时 `character.switch_behavior(0)` | 否 |

## 创建后的三步工作流

1. **换图 = 同名覆盖**。目录结构即 chen 规范：
   - `resources/sprites/<attackN|idle|walk|run|hurt|jump|knock_out|air_attack>/<方向>/<动画名>_<槽号两位>.png`
   - 新角色画好的图用**相同文件名**盖掉占位图即可，所有引用零改动
   - `__NAME___profile.png` 是头像（被 attributes 引用），同样同名覆盖
2. **跑两类轮廓转换**（Body + Attack，Inspector 高度层面板）：
   轮廓/身高/攻击窗口/时间轴全部按新图重算——占位图带来的 chen 数据会被自动冲掉
3. **体检归零**（面板"attack 结构体检"无告警）+ 按需在编辑器调属性/攻击数值

可选：若走"大图画、缩着进游戏"的缩放管线，创建后自行建 `resources/sprites_master/`
（模板**不带**母版目录、账本、蒙版和跳过标记——新角色自己产生）。

## 刷新模板（chen 更新后）

```
python3 tools/sync_template_from_chen.py
```

从 chen 目录一键重拍"标准照"（复制→占位命名→身份替换→内部引用去 uid→残留断言），
可反复执行；`character_template.*` 触发文件与 `__NAME___ai.gd` 默认小抄（模板自维护、
非 chen 来源）永不删除；主场景的 `__BODY_GROUP__`/`behavior_mode` 注入由脚本自动补齐并
有正向断言防丢。脚本失败（残留非零）时勿提交。

## 施法动画补帧通道（阶段 2 预留）
- 施法者：动画树 `spell` 槽四点混合暂全部指向单一动画 `spell.tres`（占位=attack1 循环）。
  真帧要求**左右中性姿势**；到位后替换 spell.tres 引用即可，若将来分方向再逐点改动画名。
- 动画树接线纪律：任何新动作态只连 idle 两条边（进出各一）；禁止 walk/run→动作 的
  交叉边（travel 经 idle 同帧中转，无观感差异）。tools/tree_connectivity_test 强制。
