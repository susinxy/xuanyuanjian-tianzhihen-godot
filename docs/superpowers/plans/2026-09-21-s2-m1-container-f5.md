# S2-M1-B1 容器批 · F5 人工验收单（Windows）

批范围 headless 已全绿（24/24）。本单只做机器测不了的三件事，随下次编辑器会话顺做。

**前置纪律（本仓铁律）**：
- 同步到 `s2-m1-b1-done` 之后，**重启 Godot 编辑器**（长会话缓存吞外改判例）；
- 首次打开工程让编辑器扫一遍（新建脚本/场景的 `.uid` 自生，随后可提交）；
- 工作树中你的 WIP（project.godot / scenes/stages/xuanyuan-chapter-1/**）本批一律未代收，照常自管。

## 验收点

1. **容器契约真机复跑**：编辑器里运行 `res://tools/container_contract/container_contract.tscn`
   （或 F6）——重点看 **E7 探针的 Windows 分支**（`cmd /c` 引号嵌套未实测，Linux 分支已证；
   若 E7 红而其余绿＝Windows 探针启动方式问题，非功能问题，报我即可，改 .bat 中转一步收口）。
2. **壳手感三拍**：跑 `res://tools/container_contract/fixtures/chapter_fix.tscn`（F6）——
   段间切换应有约 1.5 秒"停顿→（若有战）敌人消失→新段落位"的换段感；死亡重跑看角色回段首满血。
3. **法典双轨不破**：ref_a/ref_b 照常 F5 一跑（旧地点轨完全未动，纯确认无回退感）。

任何一条异常：截图/日志发回，按 SDD 修复轮回炉；全绿则本批在 `DEVELOPMENT_STATUS` 记 F5 关账。
