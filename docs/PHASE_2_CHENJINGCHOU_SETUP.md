# Phase 2: ChenJingchou Character Setup

> **⚠️ 已过时**：本文档描述的是旧方案（独立 HeightLayerSystem 节点），已被方案 C 替代。
> 
> **当前实现**：高度层属性直接集成到 `QuiverCharacterSkin` 基类，无需独立节点。
> 
> 请参考：
> - `docs/HEIGHT_LAYER_DESIGN.md` — 最新设计文档（v3.0，方案 C）
> - `docs/PLUGIN_ARCHITECTURE.md` — 插件架构（已更新）
> - `PLUGIN_CHANGES.md` — 插件修改记录（已更新）

## 概述（已过时）

Phase 2 完成了将高度层系统（HeightLayerSystem）集成到陈靖仇（ChenJingchou）角色中。
**注意**：此方案已被废弃，实际采用方案 C（属性在 Skin）。

## 完成的工作

### 1. HeightLayerSystem 脚本优化

**文件**: `scripts/height_layers/HeightLayerSystem.gd`

主要改进：
- ✅ 修正了碰撞框查找逻辑，适配实际的场景结构
- ✅ 修复了 HurtBox 引用路径（`AnimatedSprite2D/HurtBox`）
- ✅ 修复了 HitBox 引用路径（`Attacks/HitBox1` ~ `HitBox4`）
- ✅ 添加了完整的中文注释和 docstrings
- ✅ 简化了 API：`set_base_height()` 和 `set_attack_heights()`
- ✅ 在 `_ready()` 中自动初始化碰撞层

### 2. ChenJingchou 场景集成

**文件**: `characters/playable/chen_jingchou/chen_jingchou.tscn`

修改内容：
- ✅ 添加 HeightLayerSystem 脚本引用（ID: `23_hls01`）
- ✅ 在场景树中添加 HeightLayerSystem 节点（位置：index 2）
- ✅ 调整了 StateMachine 节点的索引（从 index 2 更新为 index 3）

**场景结构**:
```
ChenJingchou (CharacterBody2D)
├── [0] Collision
├── [1] ChenJingchouSkin
│   ├── AnimatedSprite2D
│   │   └── HurtBox
│   ├── Attacks
│   │   ├── HitBox1
│   │   ├── HitBox2
│   │   ├── HitBox3
│   │   └── HitBox4
│   └── ...
├── [2] HeightLayerSystem (新增)
└── [3] StateMachine
```

## 工作流程

### 动画控制碰撞层的基本流程

1. **动画编辑**: 在 Godot 编辑器中编辑动画
2. **添加 method track**: 在动画中添加方法轨道，调用 HeightLayerSystem 的方法
3. **运行时**: 动画播放时自动调用方法，HeightLayerSystem 更新碰撞层

### API 使用

#### `set_base_height(value: float)`
- **调用时机**: 每帧由动画轨道调用
- **作用**: 设置当前基础高度，自动更新碰撞层
- **示例**: 跳跃动画中，从 0 到 150 再回到 0

#### `set_attack_heights(heights: Array[float])`
- **调用时机**: 攻击动画中调用
- **作用**: 设置攻击高度列表，更新攻击碰撞层
- **示例**: `[80.0]` 或 `[50.0, 150.0]`（多段攻击）

### 动画轨道配置示例

#### 跳跃动画 (jump.tres)

```gdscript
# 每帧添加方法轨道
Track Type: Method
Node Path: ../HeightLayerSystem
Method: set_base_height
Key Times: 0, 0.1, 0.2, 0.3, 0.4, 0.5
Key Values: [0.0, 30.0, 80.0, 150.0, 80.0, 0.0]
```

#### 攻击动画 (attack1.tres)

```gdscript
# 在攻击帧处调用
Track Type: Method
Node Path: ../HeightLayerSystem
Method: set_attack_heights
Key Times: 0.3
Key Values: [[80.0]]  # 单次攻击
```

### 高度层定义

**配置文件**: `project.godot`

| Layer | 名称 | 高度范围 | Bit |
|-------|------|----------|-----|
| 15 | ground | 0-99.99 | 15 |
| 16 | low_air | 100-199.99 | 16 |
| 17 | mid_air | 200-299.99 | 17 |
| 18 | high_air | 300-399.99 | 18 |
| 19 | very_high | 400+ | 19 |

## 调试方法

### 在 Godot 编辑器中测试

1. 打开 `scenes/test_scenes/test_height_jump.tscn`
2. 运行场景（F6）
3. 按下 J 键跳跃
4. 观察 Output 面板的调试信息

### 预期输出

```
[HeightLayerSystem] Initialized for ChenJingchou
  - HurtBox: HurtBox
  - HitBoxes: 4 found
    - HitBox1
    - HitBox2
    - HitBox3
    - HitBox4

[HeightLayerSystem] Base height: 0.0, Layers: [ground]
[HeightLayerSystem] Base height: 50.0, Layers: [ground]
[HeightLayerSystem] Base height: 100.0, Layers: [low_air, mid_air]
[HeightLayerSystem] Base height: 150.0, Layers: [mid_air, high_air]
[HeightLayerSystem] Base height: 100.0, Layers: [low_air, mid_air]
[HeightLayerSystem] Base height: 0.0, Layers: [ground]
```

## Phase 2 验证清单

### 技术验证

- [ ] HeightLayerSystem 脚本无语法错误
- [ ] ChenJingchou 场景可以正常加载
- [ ] HeightLayerSystem 节点正确初始化
- [ ] 成功找到并引用 HurtBox 和 4 个 HitBox
- [ ] 测试场景可以正常运行

### 功能验证（需要在 Godot 编辑器中进行）

- [ ] 运行 test_height_jump.tscn
- [ ] 按下 J 键，角色可以跳跃
- [ ] Output 面板显示正确的调试信息
- [ ] base_height 值在跳跃过程中从 0 到 150 再回到 0
- [ ] 碰撞层（layers）根据 base_height 正确切换

### 动画轨道验证（需要在 Godot 编辑器中配置）

- [ ] jump.tres 添加 method track 并调用 set_base_height()
- [ ] attack1.tres 添加 method track 并调用 set_attack_heights()
- [ ] 动画播放时，方法被正确调用
- [ ] 碰撞层根据动画轨道的设置更新

## 下一步：Phase 3

完成 Phase 2 的验证后，进入 Phase 3：

### Phase 3 目标
1. **碰撞层测试**: 测试不同高度层的物体之间的碰撞判定
2. **跳跃跳过矮墙**: 验证跳跃时可以通过矮墙
3. **跳跃撞上高墙**: 验证跳跃时撞上高墙会被阻挡
4. **多高度攻击**: 验证攻击可以跨越多个高度层

### Phase 3 需要创建的内容
1. 多个高度不同的障碍物
2. 测试跳跃跳过矮墙的场景
3. 测试跳跃撞上高墙的场景
4. 测试多高度攻击的场景

## 注意事项

### 性能优化

- ✅ `_physics_process()` 只在 `base_height` 变化时更新碰撞层
- ✅ 使用 `previous_base_height` 追踪变化，避免不必要的更新
- ✅ 变化阈值设置为 0.1，平衡精度和性能

### 已知问题

- ⚠️ 需要在 Godot 编辑器中手动配置动画轨道
- ⚠️ 动画轨道需要精确的时间点设置
- ⚠️ 如果动画帧数改变，需要重新配置轨道

### 后续优化方向

- 📝 考虑在编辑器中添加辅助工具，自动检测和配置动画轨道
- 📝 考虑添加编辑器可视化，显示当前碰撞层状态
- 📝 考虑在动画编辑器中添加高度曲线编辑器

## 文件清单

### 创建的脚本
- `scripts/height_layers/HeightLayerSystem.gd` - 高度层系统脚本

### 修改的场景
- `characters/playable/chen_jingchou/chen_jingchou.tscn` - 添加 HeightLayerSystem 节点

### 创建的文档
- `docs/PHASE_2_CHENJINGCHOU_SETUP.md` - 本文档

## 参考资源

### 相关文档
- `docs/HEIGHT_LAYER_DESIGN.md` - 高度层系统完整设计文档
- `docs/PHASE_1_HEIGHT_LAYER_TOOL.md` - Phase 1 开发文档
- `docs/PHASE_1_IMPLEMENTATION_SUMMARY.md` - Phase 1 实现总结

### 相关文件
- `project.godot` - 高度层配置（Layer 15-19）
- `scripts/height_layers/HeightLayerSystem.gd` - HeightLayerSystem 脚本
- `characters/playable/chen_jingchou/chen_jingchou.tscn` - ChenJingchou 场景
- `scenes/test_scenes/test_height_jump.tscn` - 跳跃测试场景

---

**文档创建时间**: Phase 2 完成
**文档更新时间**: 
**验证者**: 需要在 Godot 编辑器中验证
