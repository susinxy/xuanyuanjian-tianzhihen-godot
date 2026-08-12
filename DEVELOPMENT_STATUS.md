# 开发状态说明

> **生效日期**: 2026-08-11

## 决策：xuanyuan-sword 正式从零开始

本目录（`xuanyuan-sword/`）下的已有工作**全部视为阶段 1-4 的学习验证产物**，**不作为正式游戏代码的基础**。

| 已有文件/目录 | 处置 |
|---|---|
| `legacy/` | 保留为学习资料存档，不要复用 |
| `characters/playable/chen_jingqiu/` | 已有部分 Quiver 实践，但存在 bug（如 `collision_mask=2`）、状态机不全（无 HurtBox、HitBox、Air、Die）、未继承 `quiver_character_base.tscn`、skin_state 为空。**不继续在此基础上开发，重新建一个干净的陈靖仇角色场景** |
| `scenes/test_stage.tscn` | 无标准 stage 结构、无 FightRoom、无 HUD、使用普通 Camera2D。**不继续，重建标准 stage** |
| `addons/quiver.beat_em_up/` | **保留**，不要删除；这是上游插件的快照副本 |
| `docs/` | **保留**，内含学习资源链接和 README |

## 后续开发路线

以 `template-beat-em-up/` 为架构样板，在 xuanyuan-sword 下从零搭建:

1. 重新建立 `chen_jingqiu/` 角色（干净的 .gd + .tscn，继承 quiver_character_base.tscn）
2. 建立 `base_stage.tscn` 标准关卡场景结构
3. 按 `story/bible.md`（天之痕剧情）分阶段开发

详细架构见:
- `docs/PLUGIN_ARCHITECTURE.md` — Quiver 插件源码分析
- `docs/TEMPLATE_IMPLEMENTATION.md` — template-beat-em-up 实际实现参考
