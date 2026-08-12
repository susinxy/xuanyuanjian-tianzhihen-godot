# 角色模板 (Character Template)

本目录包含创建新角色的模板和 Inspector 工具。

## 创建新角色

在 Godot 编辑器中使用 **Character Creator Inspector**：

1. 打开 `characters/playable/_template/character_template.tscn`
2. 选中根节点 `CharacterTemplate`
3. 在右侧 Inspector 面板中找到 "Create New Character" 区域
4. 填写表单：
   - **English Name** (snake_case)：例如 `yu_xiaoxue`
   - **Class Name** (PascalCase)：自动生成，例如 `YuXiaoxue`（可手动修改）
   - **Display Name**：例如 `于小雪`
5. 验证通过后点击 "Create Character ▶"
6. 等待创建完成，文件系统会自动刷新

### 命名约定

- **English Name**：使用 snake_case（如 `yu_xiaoxue`），用于文件名和 `@tool class_name` 声明
- **Class Name**：使用 PascalCase（如 `YuXiaoxue`），用于 GDScript 类名
- **Display Name**：使用中文全名（如 `于小雪`），用于游戏内显示

### 验证规则

- **English Name**：必须是小写字母和下划线的组合，以字母开头，不能连续下划线
  - ✅ 正确：`yu_xiaoxue`, `chen_jingchou`, `tax_man`
  - ❌ 错误：`YuXiaoxue`, `yu-xiaoxue`, `123_character`, `_name`, `_yu__xiao`

- **Class Name**：必须是字母数字的组合，以大写开头
  - ✅ 正确：`YuXiaoxue`, `ChenJingchou`, `TaxMan`
  - ❌ 错误：`yuXiaoxue`, `yu_xiaoxue`, `123Character`

- **Display Name**：任意非空字符串
  - ✅ 正确：`于小雪`, `陈靖仇`, `税吏`

## 删除角色

在 Inspector 的 "Delete Character" 区域：

1. 从下拉菜单选择要删除的角色
2. 点击 "Delete 🗑️" 按钮
3. 在确认对话框中确认删除

⚠️ **警告**：删除操作不可逆，建议在删除前备份重要资源！

## 创建后的文件结构

创建成功后会生成以下结构：

```
characters/playable/yu_xiaoxue/
├── yu_xiaoxue.tscn              # 角色场景文件
├── yu_xiaoxue_skin.tscn         # 皮肤场景文件
├── yu_xiaoxue.gd                # 角色脚本
├── yu_xiaoxue_skin.gd           # 皮肤脚本
└── resources/
    ├── animations/              # 动画文件（idle、walk、attack 等的 .tres 关键帧）
    ├── attacks/                 # 攻击数据
    │   ├── punch1_attack_data.tres
    │   ├── punch2_attack_data.tres
    │   ├── punch3_attack_data.tres
    │   └── air_kick_attack_data.tres
    ├── sprites/                 # 占位图片素材（需要替换）
    ├── yu_xiaoxue_attributes.tres  # 角色属性 Resource
    ├── yu_xiaoxue_gradient.tres    # HP 条颜色渐变
    ├── anim_library_yu_xiaoxue.tres # 动画库 Resource
    └── spriteframes_yu_xiaoxue.tres # SpriteFrames Resource
```

## 各部分职责

### 通用部分（所有角色共享，不需要改）

| 内容 | 文件 | 说明 |
|------|------|------|
| 角色基类 | `quiver_character_base.tscn` | Quiver 插件提供，不要修改 |
| 皮肤基类 | `quiver_character_skin_base.tscn` | Quiver 插件提供，不要修改 |
| 动作状态机 | `yu_xiaoxue.tscn` 中 `StateMachine` 节点 | 完整的行为树（Ground/Air/Die），所有角色结构一样 |
| 各 action state 脚本 | Quiver 插件提供 | 移动、攻击、击飞等通用逻辑 |

### 每个角色需要定制的部分

| 内容 | 文件 | 说明 |
|------|------|------|
| **角色属性** | `resources/yu_xiaoxue_attributes.tres` | 名字、HP、速度、跳跃力等 |
| **攻击数据** | `resources/attacks/*.tres` | 每次攻击的伤害、击退强度、发射方向 |
| **Sprite 动画** | `resources/sprites/*/*.png` | 所有动作的图片资源 |
| **动画文件** | `resources/animations/*.tres` | 每个动作的动画曲线（帧数、关键帧） |
| **SpriteFrames** | `resources/spriteframes_yu_xiaoxue.tres` | 动作名 → 图片动画的映射 |
| **动画库** | `resources/anim_library_yu_xiaoxue.tres` | AnimationLibrary（所有动画注册） |
| **AnimationTree** | `resources/animations/animation_tree_root.tres` | 动画树的 BlendSpace 配置 |
| **HitBox 形状** | `yu_xiaoxue_skin.tscn` | Attack1/2/3/Air 的 CollisionBox 大小和位置 |
| **碰撞胶囊** | `yu_xiaoxue.tscn` | Collision (CapsuleShape2D) 的 size |
| **角色脚本** | `yu_xiaoxue.gd` | 通常保留模板内容，仅加角色特有逻辑（如特殊法术信号） |
| **皮肤脚本** | `yu_xiaoxue_skin.gd` | 通常保留模板内容，仅加皮肤特有信号/方法 |

## 替换 Sprite 图片指南

### 图片命名规范（必须严格遵守）

```
resources/sprites/
├── idle/
│   ├── idle_00.png   # 待机 4 帧
│   ├── idle_01.png
│   ├── idle_02.png
│   └── idle_03.png
├── walk/
│   └── walk_00.png ~ walk_11.png   # 行走 12 帧
├── jump/
│   └── jump_01.png ~ jump_04.png   # 跳跃 4 帧
├── punches/
│   ├── punch1_00.png, punch1_01.png  # 第一拳 2 帧
│   ├── punch2_00.png, punch2_01.png  # 第二拳 2 帧
│   └── punch3_00.png, punch3_01.png, punch3_02.png, punch3_04.png  # 第三拳 4 帧
├── air_attack/
│   └── air_attack_00.png, air_attack_01.png  # 空中攻击 2 帧
├── hurt/
│   ├── hurt_high.png    # 高打硬直
│   └── hurt_mid.png     # 中打硬直
├── knock_out/
│   └── knockout_00.png ~ knockout_05.png  # 击飞倒地 6 帧
└── turn_around/
    └── turnaround_00.png ~ turnaround_02.png  # 转身 3 帧
```

### 素材要求

- **格式**：PNG，透明背景
- **尺寸**：参考 chen_jingchou 的素材（~400×600 px）
- **风格**：保持一致的画风（天之痕水墨风）
- **方向**：所有图片画面朝左（由动画的 `flip_h` 控制翻转向右）

## 调整角色属性

编辑 `resources/yu_xiaoxue_attributes.tres`：

```
@export var display_name := "于小雪"      # UI 显示名
@export var health_max := 100             # 最大 HP
@export var speed_max := 500.0            # 移动速度（像素/秒）
@export var jump_force := -800.0          # 跳跃初速度（负数向上）
@export var max_hp_regen := 0.0           # HP 回复（0 = 无回复）
```

### 数值参考

| 角色 | speed_max | jump_force | health_max |
|------|-----------|------------|------------|
| 陈靖仇 | 500 | -800 | 100 |
| Chad（模板）| 500 | -800 | 100 |
| 推荐轻快型 | 600 | -900 | 80 |
| 推荐重装型 | 350 | -700 | 150 |

## 故障排除

### 角色创建失败

1. 检查 Godot 控制台输出错误信息
2. 确认 `characters/playable/` 目录存在且可写
3. 确认模板文件完整（`_template/` 目录下应有所有必需文件）

### Inspector 没有显示

1. 确认已打开 `character_template.tscn`
2. 确认已选中根节点 `CharacterTemplate`
3. 确认 Quiver Beat-em Up 插件已启用（Project Settings > Plugins 中 `Quiver Beat'em Up` 和 `Dialogic` 都应为 Enabled）

### 文件系统没有刷新

1. 点击 FileSystem 面板的刷新按钮
2. 或使用菜单：Project > Tools > File System > Refresh

## 更多资源

- 查看完整角色示例：`characters/playable/chen_jingchou/`
- 了解 Quiver 插件：`addons/quiver.beat_em_up/`
- 阅读插件架构文档：`docs/PLUGIN_ARCHITECTURE.md`

---

**最后更新**：2026-08-11
