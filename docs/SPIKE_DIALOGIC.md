# Dialogic 风险探测备忘（spike，2026-09-21）

> 一次性耗材批：`tools/dialogic_spike/`（runner+probe.dtl）**不进 23 套回归矩阵**，
> 红字≠否决——处置分级见文末。目的：为"S2 切片先行、S3 对话后接"换序决定上保险。

## 四问四答

| # | 问题 | 结论 | 证据 |
|---|---|---|---|
| Q1 | CJK 渲染 | **待 Windows**（headless 看不见字形） | 腿 4 清单见下 |
| Q2 | 输入互斥 | **游戏输入会漏进对话**（对话中 chen 收 raw D 键位移 110px）；好消息：移动键不会误推进对话（仅 default action 推进）→ 剧情态门（冻结输入通道）**必须做且够用** | L2 真值表 |
| Q3 | 暂停语义 | **自洽无冲突**：`tree.paused=true` 时 Dialogic 随树冻结（不吃推进输入）；我们暂停壳（ALWAYS）照常可操作；解除后对话恢复并实际走完（工具收尾成功为旁证） | L3 + L3x PASS |
| Q4 | 冷启动回环 | **核心通路全活**：autoload 在位、`start(DialogicTimeline资源)` 返回有效布局、事件处理推进、打字机 reveal 运行；`timeline_ended` 在 headless 有界按压内未捕获——直调 `Inputs.handle_input()` 可推事件（1→3）证明内部机制正常，堵点在事件传导/headless 时序面（疑似 reveal 完成计时依赖）。**终验转 Windows 腿 4** | L0-L1d |

## 钉到的判例（超出四问的收获）

1. **`.dtl` 是纯文本文件**（每行一事件，`名字: 文本`，`_:`=旁白）——时间轴资产可 Linux 端手写，**运行时自动创建缺失角色且不落盘**（腿 0 无需编辑器，B 案作废，A 案白送）；
2. `Dialogic.start()` 接受资源对象直传（identifier 注册表可绕开）；
3. 推进监听在 `_unhandled_input`——**AGENTS"合成 InputEventAction 不入 unhandled"判例在第三方插件适配上再次应验**，注入必须 raw 键/鼠标；
4. 推进动作绑定 = Enter + LMB（`dialogic_default_action`）；打字机模式下首按语义=跳显示；
5. 观测件：`event_handled` / `timeline_ended` / `current_state`(IDLE/ANIMATING…) / `current_event_idx`。

## 红字处置（按预案分级）

- Q2 = **预期内**，修复路径=剧情态门（S3 施工清单既有项，非否决项）；
- Q3 = 绿（原"结构性冲突"担忧不成立）；
- Q4 的 ended 悬案 = 工具级未钉死（**非否决**），腿 4 一条清单收口；
- 综合判定：**Dialogic alpha 与本项目运行时兼容面良好，S3 维持 Dialogic 选型，无需触发"自研简版"复议**。

## 腿 4（Windows F5 目视清单，随下次编辑器会话顺做）

1. 打开 `tools/dialogic_spike/spike_probe.tscn` F6 单跑：两行中文是字还是豆腐（Q1 收口）；
2. 按 Enter 推进：能否从第一行走到时间轴自然结束（Q4 终验；结束后日志应见 `timeline_ended`）；
3. 对话中按 ESC：暂停壳能否正常拉出/关闭（Q3 实机复认）。
