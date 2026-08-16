# 开发状态说明

> **生效日期**: 2026-08-11
> **最后更新**: 2026-08-16

## 决策：xuanyuan-sword 正式从零开始

本目录（`xuanyuan-sword/`）下的已有工作**全部视为阶段 1-4 的学习验证产物**，**不作为正式游戏代码的基础**。

| 已有文件/目录 | 处置 |
|---|---|
| `legacy/` | 保留为学习资料存档，不要复用 |
| `characters/playable/chen_jingqiu/` | **已完成重建**（2026-08-16）。继承 `quiver_character_base.tscn`，完整状态机，HurtBox/HitBox 配置正确，使用高度层碰撞系统 |
| `scenes/test_stage.tscn` | 无标准 stage 结构、无 FightRoom、无 HUD、使用普通 Camera2D。**不继续，重建标准 stage** |
| `addons/quiver.beat_em_up/` | **保留**，不要删除；这是上游插件的快照副本，已进行碰撞系统重构（移除 character_type、碰撞预设，统一使用高度层 + faction group） |
| `docs/` | **保留**，内含学习资源链接和 README |

## 已完成的工作

### 碰撞系统重构（2026-08-16）

- 删除 `character_type` 枚举和 `QuiverCollisionTypes` 碰撞预设系统
- 统一使用高度层（layers 15-24）作为物理检测通道
- 统一使用 faction group（`area2d:` 前缀）作为逻辑过滤机制
- QuiverLevelCamera 添加四方向屏幕边界碰撞（使用高度层 bitmask）
- 墙壁反弹系统改用 `area2d:wall` faction group 控制

### 角色重建（2026-08-16）

- `chen_jingqiu/` 角色已重建，继承 `quiver_character_base.tscn`
- 完整状态机（Ground/Air/Die），HurtBox/HitBox 配置正确
- 使用高度层碰撞系统，无需手动设置 combat layer

### 测试场景增强（2026-08-16）

- 测试场景模板支持自定义攻击数据、敌人朝向、combo 模式
- 墙壁反弹测试验证通过
- 高度层碰撞可视化调试工具

## 后续开发路线

以 `template-beat-em-up/` 为架构样板，在 xuanyuan-sword 下继续搭建:

1. ~~重新建立 `chen_jingqiu/` 角色~~ ✅ 已完成
2. 建立 `base_stage.tscn` 标准关卡场景结构（**下一步**）
3. 按 `story/bible.md`（天之痕剧情）分阶段开发

详细架构见:
- `docs/PLUGIN_ARCHITECTURE.md` — Quiver 插件源码分析（已更新碰撞系统重构内容）
- `docs/TEMPLATE_IMPLEMENTATION.md` — template-beat-em-up 实际实现参考（原版碰撞系统，用于对比）
