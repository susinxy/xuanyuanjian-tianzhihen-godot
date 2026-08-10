# 轩辕剑叁外传：天之痕 - Godot 4 ARPG 学习项目

> 从零开始学习 Godot 4，重制经典 RPG《天之痕》

---

## 📖 项目简介

本项目是 Godot 4 学习项目，目标是：
1. **学习 Godot 4 基础**：场景、节点、信号、物理系统
2. **掌握 ARPG 开发模式**：移动、战斗、对话、关卡
3. **重制天之痕序章**：伏魔山场景（3-5分钟可玩）
4. **引入 Downtown Beatdown 架构**：学习专业级代码组织

最终目标是创建一个完整的 ARPG 游戏，致敬经典之作《轩辕剑叁外传：天之痕》。

---

## 🎯 当前进度

### ✅ Phase 0：Windows F5 验证（已完成）
- 成功在 Windows 运行 F5
- 看到灰色方块（Player）
- WASD 可移动
- 无报错

### 🔄 Phase 1 Week 1：地图碰撞 + Player 抽场景（进行中）
详细任务见 [TODO.md](../TODO.md)

---

## 📁 项目结构

```
xuanyuan-sword/
├── docs/                    # 文档目录
│   ├── README.md           # 本文件
│   └── learning_resources.md # 学习资源链接
├── scenes/                  # 场景文件
│   ├── main.tscn           # 主场景
│   └── player.tscn         # 玩家场景（待创建）
├── scripts/                 # 脚本目录
│   ├── player.gd           # 玩家脚本
│   └── player.gd.uid       # Godot 自动生成的 UID
├── project.godot           # Godot 项目配置
├── TODO.md                 # 任务追踪
└── addons/
    └── quiver.beat_em_up/  # Downtown Beatdown 模板（参考用）
```

---

## 🚀 快速开始

### 环境要求
- **Godot 4.7**：[下载地址](https://godotengine.org/download)
- **Windows/macOS/Linux**：Godot 跨平台
- **代码编辑器**：Godot 内置 / VSCode + Godot Tools

### 运行项目
1. 打开 Godot 4.7
2. 导入本项目（选择 `xuanyuan-sword/` 目录）
3. 按 **F5** 运行

### 当前功能
- ✅ 玩家移动（WASD / 方向键）
- ⏳ 地图碰撞（Week 1 目标）
- ⏳ 镜头跟随（Week 2 目标）
- ⏳ 基础动画（Week 2 目标）

---

## 📚 学习路线

### Phase 1：基础巩固（Week 1-2）
- **Week 1**：地图碰撞、Player 抽场景
- **Week 2**：Camera2D、AnimationPlayer

### Phase 2：战斗系统（Week 3-4）
- **Week 3**：攻击系统（HitBox）
- **Week 4**：敌人 AI、HP 系统

### Phase 3：天之痕序章（Week 5-8）
- **Week 5**：伏魔山场景
- **Week 6**：对话系统
- **Week 7**：饕餮 Boss 战
- **Week 8**：陈辅封印 + 下山

### Phase 4：架构升级（Week 9-12）
- **Week 9**：分层状态机
- **Week 10**：Resource 数据驱动
- **Week 11**：Events 信号总线
- **Week 12**：代码迁移决策

详细时间线见 [TODO.md](../TODO.md)

---

## 🎮 游戏设计

### 核心玩法
- **视角**：斜 45° 俯视（2.5D）
- **移动**：键盘控制，平滑跟随
- **战斗**：近战攻击 + 五行法术
- **对话**：剧情驱动，选项分支

### 技术架构
- **引擎**：Godot 4.7
- **物理**：CharacterBody2D + move_and_slide()
- **状态机**：参考 Downtown Beatdown 模板
- **数据驱动**：Resource 文件管理游戏数据

### 美术风格
- **初期**：占位方块（快速迭代）
- **后期**：AI 生成素材（ComfyUI）
- **目标**：水墨画风格，致敬经典

---

## 📖 相关文档

### 项目文档
- [任务追踪](../TODO.md)
- [学习资源](learning_resources.md)

### 设计文档
- [天之痕剧情圣经](../../story/bible.md) - 完整剧情参考
- [ARPG 设计方法论](../../docs/ARPG_DESIGN_RESEARCH.md) - 游戏设计指导
- [Godot ARPG 最佳实践](../../godot-games/docs/godot4_arpg_research.md) - 技术实现

### 参考项目
- [Downtown Beatdown 模板](../../godot-games/) - 成熟 ARPG 架构

---

## 🛠️ 开发工具

### 必需工具
- **Godot 4.7**：游戏引擎
- **Git**：版本控制（已初始化）
- **Syncthing**：文件同步（Linux ↔ Windows）

### 推荐工具
- **VSCode**：代码编辑器 + Godot Tools 插件
- **Tiled**：地图编辑器（后期使用）
- **ComfyUI**：AI 美术素材生成

---

## 📝 开发规范

### 代码规范
- **GDScript**：遵循 Godot 官方风格指南
- **命名约定**：
  - 场景文件：`snake_case.tscn`
  - 脚本文件：`snake_case.gd`
  - 节点名：`PascalCase`
- **注释语言**：中文
- **代码注释**：使用 `#` 或 `##`（文档注释）

### 场景组织
- **根节点**：使用场景名称（如 `Player`、`Main`）
- **子节点**：按功能分组（如 `Sprites`、`Collision`）
- **层级清晰**：不超过 3 层嵌套

### 版本控制
- **提交频率**：每完成一个功能就提交
- **提交信息**：中文，格式为 `功能类型：简要描述`
  - 示例：`feat: 添加地图碰撞`、`fix: 修复移动卡顿`

---

## 🤝 协作说明

### 开发流程
1. **Linux**：代码编辑（OpenCode agent）
2. **Windows**：运行测试（用户 Godot 编辑器）
3. **文件同步**：Syncthing 双向同步

### 测试验证
- **Linux**：无法运行 Godot（所有测试必须由用户在 Windows 完成）
- **Windows**：按 F5 运行游戏
- **反馈**：截图或描述问题

---

## 📊 项目状态

| 模块 | 状态 | 说明 |
|------|------|------|
| 移动系统 | ✅ | 基础移动完成 |
| 碰撞系统 | 🔄 | Week 1 目标 |
| 镜头系统 | ⏳ | Week 2 目标 |
| 动画系统 | ⏳ | Week 2 目标 |
| 战斗系统 | ⏳ | Phase 2 目标 |
| 对话系统 | ⏳ | Phase 3 目标 |
| 关卡设计 | ⏳ | Phase 3 目标 |

---

## 🎯 下一步

当前目标：**Phase 1 Week 1 - 地图碰撞 + Player 抽场景**

详细任务见 [TODO.md](../TODO.md)

---

## 📞 联系方式

如有疑问或建议，请在项目中提出。

---

**最后更新**：2026-08-08
