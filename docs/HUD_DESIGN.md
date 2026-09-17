# HUD 设计（2026-09-16 定稿并实现）

## 一、需求与裁决记录

需求：正式 HUD（当前操控者状态）+ 可隐藏的系统/角色调试信息，调试量大时
"一个窗口 + 多标签 + 半透明"，不抢占游戏画面；并整合现有散装调试面板。

架构分类：新增子系统（新契约 + 重构旧面板归置）→ 完整流程走查后定案。

**丙方案（已采纳）**：按职责分家——
- 正式 HUD = **场景组件**（美术资产属性，随关卡风格演化、被未来菜单/角色切换认领）
- 调试坞 = **全局 Autoload**（开发工具属性，一处一份、跨场景常驻）

否决记录：甲（全塞单例）= 正式界面与开发工具搅在一个类，违背单元单一职责；
乙（全场景内嵌，上游 HudLayer 路线）= 调试坞要全局随叫随到，场景各摆一份=
状态各存各的；混合变体（Dock 全局 + HUD 场景内）胜出。

**旧面板归置裁决（用户，含一次澄清修正）**：凡**文字**显示信息一律入左下
Dock 按页签分类、页内纵向滚动；**图形**保留原位置——最终只有"高度层竖条"
（屏幕右缘的角色占高条）属图形。据此：击倒面板（解剖确认为纯文字，含
knockout_requested 信号快照采集）整体迁入后退役删除；高度层面板瘦身为只画
竖条；Run Test 操作说明牌 DebugLabel 留在场景但 `visible=false`，由
Dock[帮助]页读出显示（场景自改说明文字的 kit 机制零改动）。

## 二、目录决策（UI 领域户）

```
ui/
  debug_dock.gd + debug_dock.tscn    调试坞骨架（通用容器，零领域知识）
  debug_dock_tabs.gd                 内容层 Autoload（四页签 provider 集中地）
  debug_text_tab.gd                  文字页签控件
  game_hud.gd + game_hud.tscn        正式 HUD（场景组件）
```
`scripts/` 只住纯脚本；UI 资产（场景+脚本）按领域进 `ui/`（与 characters/、
spells/ 的布局语法一致；未来 main_menu/pause/对话框皮肤同一户口）。

## 三、DebugDock 规格

- 形态：CanvasLayer(layer 90) → PanelContainer 半透明圆角（rgba 0.05,0.05,0.08,
  0.72），TabContainer 页签，页内纵向滚动；**自由拖拽摆放**：顶部为醒目
  把手带——亮于坞身的横带+下缘分隔线+`⣿⣿⣿` 点阵+13px 亮白标题+右靠键位
  小字，高 26px 整条可抓、悬停整条提亮、光标"可移动"型（枚举写进脚本，
  编译即验证）；位置存 `user://debug_dock.cfg` 跨启动记忆，越界自动夹回
  视口，无档时默认左下角；页签区保持纯点选职责。可见性断言只认几何
  （标题条 size.y>=24 入 dock_test，延续"锚点/属性不算数"纪律）。
  页签滚动三契约（2026-09-16 滚轮悬案定案，dock-wheel 回归套锁死）：
  ①标签 `mouse_filter=IGNORE` 不吞事件；②**`fit_content=true` 是真凶级
  契约**——false 时 RichTextLabel 自报最小高 0，容器判零溢出，滚动条
  不出现+滚轮无范围（曾误诊为穿透问题）；③`scroll_active=false` 让容器
  做滚动。取证沉淀：headless 投真实滚轮用 `Window.push_input`，坐标必须
  过 `get_screen_transform()` 换算，否则指针飞出 pick 域（首版取证套现场）。
- 键位：`debug_dock_toggle`（主键盘 =/小键盘 + 双绑）显隐；
  `debug_dock_next_tab`（Tab）仅窗口打开时消费。
- **默认开=场景声明制**：场景内任意节点挂组 `debug_dock_default_open` → 入场
  自开；Run Test 底版统一注入声明节点，正式场景不写=默认关。
- 页签注册制：`add_tab(title, control)` / `add_text_tab(title, provider)`；
  provider 返回 Array[String]/String，Dock 以 **0.15s 拉取**节奏刷新（绝无每帧，
  窗口永不拖帧率）。
- 页签七页（内容层注册）：
  | 页 | 内容 |
  |---|---|
  | 角色 | 全员：HP/蓝、状态机路径、位置/物理高/基准/高度层、阵营组、槽位（法术/冷却/蓝量/引导） |
  | 弹体 | 每发：state、方向、位置、剩余寿命、亮度、判定门层位、阵营、施法者 |
  | 诊断 | 旧法术测试面板移植：角色/弹体碰撞层掩码 HEX、HurtBox monitoring、HitBox 形状 disabled |
  | 高度层 | 旧高度面板文字移植：全员占高区间/attack_heights/层位表/skin.y |
  | 击飞 | 旧击倒面板移植：knockback 计量/该飞判定/无敌霸体/信号快照击飞记录 |
  | 帮助 | 场景 DebugLabel 操作说明牌内容（场景内不可见，纯经此页呈现） |
  | 系统 | FPS、角色/弹体计数、昼夜相位、窗口状态、Godot 版本 |
- **引擎报错流不做**：运行时捕获 push_error 无干净通道（logging_hook 是编辑器
  专属），Output 窗口职责不变。

### 环境级发现（本轮探针定罪，全局纪律）

`--headless` **不派发 idle 帧**：Dock 与任意节点的 `_process` 在 headless 下
0 tick（is_processing 仍为 true 具迷惑性）。→ 调试坞心跳/未来一切要被
headless 测试驱动的逻辑，一律 `_physics_process`。

## 四、GameHUD 规格

- 布局（定稿横排的架构理由）：**头像 | 名字+血条+蓝条+槽行** 左起横排——
  三期角色切换的"队伍条"扩展=左列并排更多头像，竖排会被迫重构。
- 数据源全部现成字段（零新增 schema）：`attributes.profile_texture`（当年
  建好的管线首次消费）、`display_name`、`health/mana_current|max`、
  `_spell_manager._slots[i].definition`（显示名/冷却剩余/比例遮罩）。
- 绑定策略：跟随 `players` 组首位——换人即换脸（CharacterManager 零改动契约）。
  注意：**players 组由行为档延迟挂接**（晚于 _ready 若干物理帧），消费方要
  等跟手（测试用带上限轮询，不断言即时绑定）。
- 无玩家在场时 HUD 自隐；一期克制的占位样式，正式美术风格随
  《天之痕ARPG美术风格指南》替换批。

## 五、测试与数据脆性纪律

- 锚点语义陷阱（探针实锤）：`Control.set_anchor(dir, v)` 默认 keep_offsets=false=
  **保持视觉矩形不动**（引擎反向修 offset）；要矩形真跟随锚点必须显式
  `set_anchor(dir, v, true)`——HUD 冷却遮罩"属性在变、画面不动"即栽在此。
  由此定档：**用户可见性断言只认几何（size/position/rect/颜色），锚点等
  中间属性不算数**。
- 显示级断言上限：headless 读不到像素，但能读**布局头寸**——TabContainer
  非当前页签不经排版（尺寸恒 0 属引擎本性），量宽度前必须先切到该页；
  TextTab 撑开宽度 >50px 与字色 override 双断言锁死"黑纸黑字/宽度塌陷"两类回归。
- 新套：`debug_dock_test`（12 断言：声明自开/键切换往返/OS 原始键链路/注册制/
  拉取送达/Tab 循环/完成旗）、`hud_test`（8 断言：跟手/名/头像/血同步/学名/
  冷却遮罩比例/自隐/完成旗）。
- **定义调参免疫（本轮实战教训）**：用户 Windows 手感调参（cooldown 3s、
  引导 0.5、淡入 0.3/淡出 0.35）经 Syncthing 回流曾击落 contract/projectile
  全线——测试从此 a) 自带定义副本强制清冷却，b) 帧窗从磁盘定义派生+定格余量，
  绝不假设默认值（9/15 既有纪律的执行化）。
- parity/scene-gen 随 builder 变更同步（kit 不再注入诊断面板，基座新增
  DebugDockOpen/GameHUD 声明，load_steps 期望改 +1）。

## 六、遗留与后续挂靠

- 暂停菜单/主菜单/游戏流程壳：HUD 的邻居，随 base_stage 设计会一并规划
  （HUD 已给 Frame 预留显隐总开关位）。
- CharacterManager 换人：HUD 侧零改动（组语义），坞[角色]页天然全员列表。
- HUD 正式美术（九宫格边框/字体/头像框）：随美术替换批，接口不变。
