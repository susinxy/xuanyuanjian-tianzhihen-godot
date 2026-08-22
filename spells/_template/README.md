# 法术模板 (Spell Template)

本目录包含创建新法术的模板和 Inspector 工具。

## 创建新法术

在 Godot 编辑器中使用 **Spell Creator Inspector**（待实现，阶段 5）：

1. 打开 `spells/_template/spell_template.tscn`
2. 选中根节点 `SpellTemplate`
3. 在右侧 Inspector 面板中找到 "Create New Spell" 区域
4. 填写表单：
   - **English Name** (snake_case)：例如 `fire_ball`
   - **Class Name** (PascalCase)：自动生成，例如 `FireBall`（可手动修改）
   - **Display Name**：例如 `火球术`
5. 验证通过后点击 "Create Spell"
6. 等待创建完成，文件系统会自动刷新

### 命名约定

- **English Name**：使用 snake_case（如 `fire_ball`），用于文件名和 `@tool class_name` 声明
- **Class Name**：使用 PascalCase（如 `FireBall`），用于 GDScript 类名
- **Display Name**：使用中文全名（如 `火球术`），用于游戏内显示

### 验证规则

- **English Name**：必须是小写字母和下划线的组合，以字母开头，不能连续下划线
  - ✅ 正确：`fire_ball`, `ice_wall`, `lightning_strike`
  - ❌ 错误：`FireBall`, `fire-ball`, `123_spell`, `_name`, `_fire__ball`

- **Class Name**：必须是字母数字的组合，以大写开头
  - ✅ 正确：`FireBall`, `IceWall`, `LightningStrike`
  - ❌ 错误：`fireBall`, `fire_ball`, `123Spell`

- **Display Name**：任意非空字符串
  - ✅ 正确：`火球术`, `冰墙`, `闪电打击`

## 删除法术

在 Inspector 的 "Delete Spell" 区域（待实现，阶段 5）：

1. 从下拉菜单选择要删除的法术
2. 点击 "Delete 🗑️" 按钮
3. 在确认对话框中确认删除

⚠️ **警告**：删除操作不可逆，建议在删除前备份重要资源！

## 创建后的文件结构

创建成功后会生成以下结构：

```
spells/fire_ball/
├── fire_ball.tscn                    # 法术主场景
├── fire_ball_skin.tscn               # 法术皮肤场景
├── fire_ball.gd                      # 法术主脚本
├── fire_ball_skin.gd                 # 法术皮肤脚本
└── resources/
    ├── animations/                   # 动画文件（由 Inspector 工具自动生成）
    │   ├── animation_tree_root.tres
    │   ├── active_right.tres
    │   ├── active_left.tres
    │   ├── ending_right.tres
    │   ├── ending_left.tres
    │   └── RESET.tres
    ├── attacks/                      # 攻击数据
    │   └── fire_ball_attack_data.tres
    ├── sprites/                      # 占位图片素材（需要替换）
    │   └── placeholder.png
    ├── fire_ball_definition.tres     # 法术定义 Resource
    └── spriteframes_fire_ball.tres   # SpriteFrames Resource
```

## 各部分职责

### 通用部分（所有法术共享，不需要改）

| 内容 | 文件 | 说明 |
|------|------|------|
| 法术基类 | `spell_base.gd` | 法术核心逻辑（生命周期、高度层管理），不要修改 |
| 皮肤基类 | `spell_skin_base.tscn` | 法术皮肤基础场景，不要修改 |
| 动画树管理 | `spell_skin_anim_tree.gd` | AnimationTree 管理逻辑，不要修改 |
| 法术定义 | `spell_definition.gd` | 法术配置数据类，不要修改 |
| 法术管理器 | `spell_manager.gd` | 法术槽位和施放管理，不要修改 |

### 每个法术需要定制的部分

| 内容 | 文件 | 说明 |
|------|------|------|
| **法术定义** | `resources/fire_ball_definition.tres` | 名字、法力消耗、冷却时间、最大生命周期 |
| **攻击数据** | `resources/attacks/fire_ball_attack_data.tres` | 伤害、击退强度、击退角度 |
| **Sprite 动画** | `resources/sprites/active/*.png` | 法术激活时的图片资源 |
| **Sprite 动画** | `resources/sprites/ending/*.png` | 法术结束时的图片资源 |
| **动画文件** | `resources/animations/*.tres` | 每个动画的关键帧（由 Inspector 自动生成基础结构） |
| **SpriteFrames** | `resources/spriteframes_fire_ball.tres` | 动画名 → 图片动画的映射 |
| **HitBox 形状** | `fire_ball_skin.tscn` | Attack1 的 CollisionBox 大小和位置 |
| **法术脚本** | `fire_ball.gd` | 法术的具体行为逻辑（移动、碰撞、特效等） |
| **皮肤脚本** | `fire_ball_skin.gd` | 皮肤特有的信号处理逻辑 |

## 替换 Sprite 图片指南

### 图片命名规范

法术的 Sprite 图片命名比角色简单，不需要物理高度等标签：

```
resources/sprites/
├── active/
│   ├── active_00.png    # 法术激活动画帧
│   ├── active_01.png
│   └── active_02.png
└── ending/
    ├── ending_00.png    # 法术结束动画帧
    └── ending_01.png
```

### 素材要求

- **格式**：PNG，透明背景
- **尺寸**：根据法术类型调整（火球 ~80×80 px，冰墙 ~200×300 px）
- **风格**：保持一致的画风（天之痕水墨风）
- **方向**：所有图片画面朝右（由动画的 `flip_h` 控制翻转向左）

## 调整法术属性

编辑 `resources/fire_ball_definition.tres`：

```
spell_id = &"fire_ball"              # 法术唯一标识符
display_name = "火球术"               # UI 显示名
mana_cost = 20.0                     # 法力消耗
max_lifetime = 3.0                   # 最大生命周期（秒）
cooldown = 1.5                       # 冷却时间（秒）
```

### 编辑攻击数据

编辑 `resources/attacks/fire_ball_attack_data.tres`：

```
attack_damage = 15.0                 # 伤害值
hurt_type = 1                        # 硬直类型（1=中等，2=高）
knockback = 2                        # 击退强度（0=无，1=轻，2=中，3=重）
launch_angle = 30                    # 击退角度（度）
```

## 法术类型示例

### 1. 投射物法术（Projectile Spell）

**特点**：发射后沿直线移动，碰撞后消失

**需要修改的脚本**：
- `fire_ball.gd` 的 `_on_active(delta)`：
  ```gdscript
  func _on_active(delta: float) -> void:
      position += direction * 500.0 * delta  # 沿方向移动
  ```

- `fire_ball.gd` 的 `_on_hit(hurtbox)`：
  ```gdscript
  func _on_hit(hurtbox: QuiverHurtBox) -> void:
      end()  # 碰撞后立即结束
  ```

### 2. 区域法术（Area Spell）

**特点**：在指定位置创建，持续一段时间后消失

**需要修改的脚本**：
- `ice_wall.gd` 的 `_on_active(delta)`：
  ```gdscript
  func _on_active(delta: float) -> void:
      pass  # 不移动，保持静止
  ```

- `ice_wall.gd` 的 `_on_skin_animation_finished()`：
  ```gdscript
  func _on_skin_animation_finished() -> void:
      end()  # 动画播放完毕后结束
  ```

### 3. 召唤法术（Summon Spell）

**特点**：创建可移动的召唤物，由 AI 控制

**需要修改的脚本**：
- `summon_wolf.gd` 的 `_on_cast()`：
  ```gdscript
  func _on_cast() -> void:
      var wolf = preload("res://spells/summon_wolf/wolf.tscn").instantiate()
      add_child(wolf)
      wolf.summoner = caster
  ```

## 高度层碰撞系统

法术的 HitBox 会根据 `attack_heights` 数组自动设置碰撞层：

```gdscript
# 在 fire_ball_skin.tscn 的 Skin 节点中设置：
attack_heights = [100.0]  # 攻击高度偏移（相对于法术位置）
```

**高度层说明**：
- `attack_heights = [50.0]` — 低空攻击（脚踝高度）
- `attack_heights = [100.0]` — 中空攻击（腰部高度）
- `attack_heights = [150.0]` — 高空攻击（头部高度）
- `attack_heights = [100.0, 150.0]` — 同时覆盖中空和高空

**自动计算**：
- `base_height` = `-position.y`（法术的 Y 坐标取反）
- `absolute_height` = `base_height + attack_height`
- 根据 `absolute_height` 映射到高度层（15-24）

## 动画系统

### 动画状态机结构

法术的 AnimationTree 包含以下状态：

```
AnimationNodeBlendTree (tree_root)
└── state_machine (AnimationNodeStateMachine)
    ├── active      → BlendSpace1D (active_left @ blend=-1, active_right @ blend=+1)
    └── ending      → BlendSpace1D (ending_left @ blend=-1, ending_right @ blend=+1)
```

### 动画播放流程

1. **施放时**：`cast()` → `skin.transition_to(&"active")`
2. **动画结束**：`skin.spell_animation_finished` 信号 → 自动过渡到 `ending`
3. **法术结束**：`skin.spell_ended` 信号 → `destroy()`

### 自定义动画行为

在 `fire_ball_skin.gd` 中重写动画相关方法：

```gdscript
func _skin_direction_updated() -> void:
    super()
    # 自定义朝向逻辑

func _on_skin_animation_finished() -> void:
    # 动画播放完毕后的自定义逻辑
    pass
```

## 施放状态检查

法术可以在特定状态下施放，通过 `SpellDefinition` 配置：

```gdscript
# 允许施放的状态（白名单）
allowed_states = [&"Idle", &"Walk"]

# 禁止施放的状态（黑名单，优先级高于白名单）
disallowed_states = [&"Die", &"Knockout"]
```

**默认配置**：
- `allowed_states = []` — 空数组表示不限制（任何状态都可施放）
- `disallowed_states = [&"Die", &"Knockout"]` — 死亡和击飞时禁止施放

## 召唤物管理

对于召唤法术，需要在 `fire_ball.gd` 中注册召唤物：

```gdscript
func _on_cast() -> void:
    var wolf = preload("res://spells/summon_wolf/wolf.tscn").instantiate()
    add_child(wolf)
    
    # 注册到 SpellManager（自动跟踪生命周期）
    if caster.get("_spell_manager"):
        caster._spell_manager.register_summon(wolf)
```

**自动清理**：
- 角色死亡时，`SpellManager.dismiss_all_summons()` 会自动清理所有召唤物
- 召唤物 `queue_free()` 时，会自动从 `_active_summons` 字典中移除

## 故障排除

### 法术创建失败

1. 检查 Godot 控制台输出错误信息
2. 确认 `spells/` 目录存在且可写
3. 确认模板文件完整（`_template/` 目录下应有所有必需文件）

### Inspector 没有显示

1. 确认已打开 `spell_template.tscn`
2. 确认已选中根节点 `SpellTemplate`
3. 确认 Quiver Beat-em Up 插件已启用（Project Settings > Plugins 中应为 Enabled）

### 法术无法施放

1. 检查法力值是否足够：`caster.attributes.mana_current >= definition.mana_cost`
2. 检查状态是否允许：`SpellManager._is_state_allowed(definition)`
3. 检查冷却时间：`slot.is_ready()`

### 碰撞检测不工作

1. 确认 `fire_ball_skin.tscn` 的 `attack_heights` 已正确设置
2. 确认 HitBox 的 `CollisionShape2D` 已启用（`disabled = false`）
3. 确认 HurtBox 和 HitBox 不在同一 faction group

### 动画不播放

1. 确认 `spriteframes_fire_ball.tres` 已正确配置动画帧
2. 确认 `animation_tree_root.tres` 已正确配置状态机
3. 确认 `_skin.transition_to(&"active")` 被正确调用

## 更多资源

- 查看完整法术示例：`spells/fire_ball/`（待创建，阶段 7）
- 了解法术系统设计：`docs/SPELL_SYSTEM_DESIGN.md`
- 了解 Quiver 插件：`addons/quiver.beat_em_up/`
- 阅读插件架构文档：`docs/PLUGIN_ARCHITECTURE.md`

---

**最后更新**：2026-08-22
