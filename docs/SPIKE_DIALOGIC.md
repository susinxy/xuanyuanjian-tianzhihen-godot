# Dialogic 风险探测备忘（spike，2026-09-21）

> 一次性耗材批：`tools/dialogic_spike/`（runner+probe.dtl）**不进 23 套回归矩阵**，
> 红字≠否决——处置分级见文末。目的：为"S2 切片先行、S3 对话后接"换序决定上保险。

## 四问四答（✅ 2026-09-21 腿 4 真机目视后全部闭合，spike 结案）

| # | 问题 | 结论 | 证据 |
|---|---|---|---|
| Q1 | CJK 渲染 | ✅ **绿**：Windows 真机两段中文清晰（系统字体回退在工作）；显式字体槽降级为跨平台一致性小事 | 腿 4 目视 |
| Q2 | 输入互斥 | **游戏输入会漏进对话**（对话中 chen 收 raw D 键位移 110px）；好消息：移动键不会误推进对话（仅 default action 推进）→ 剧情态门（冻结输入通道）**必须做且够用** | L2 真值表 |
| Q3 | 暂停语义 | **自洽无冲突**：`tree.paused=true` 时 Dialogic 随树冻结（不吃推进输入）；我们暂停壳（ALWAYS）照常可操作；解除后对话恢复并实际走完（工具收尾成功为旁证） | L3 + L3x PASS |
| Q4 | 冷启动回环 | ✅ **绿**：真机 L1c PASS（两行推进→timeline_ended 送达→runner 正常收尾）。headless 曾未捕获的悬案归因**注入保真度**：raw Enter 被 Dialogic 的 exact 匹配拒收（绑定 keycode=Enter/physical=0，注入事件 physical 非零），鼠标 LMB 路可通——非被测系统缺陷 | 腿 4 日志 + 本备忘判例条 |

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

## 腿 4 执行记录（2026-09-21，用户真机）

F6 单跑 spike_probe.tscn：全程零人工（runner 自动注入推进），目视确认两段中文
清晰、chen 出现并右移（L2 现场）、场景自动收尾；日志 L1c PASS、L2/L3 与 headless
一致。**综合判定不变且加固：S3 维持 Dialogic 选型，四问无遗留。**
耗材处置：`tools/dialogic_spike/` 保留作证据（不进矩阵）；用户章节素材与根目录
mp4 按用户表态一律不关心、不代管、暂存逐路径绕开。
