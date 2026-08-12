# Phase 0.1：角色创建总结

## 核心原则

Quiver 插件提供了**通用骨架**（基类场景 + 基础脚本），每个角色需要提供的**独有内容**是资源文件和场景配置。

## Chad 作为标准样例的分析

### 插件提供的（所有角色共用）
- `quiver_character_base.tscn` — 基础 CharacterBody2D + StateMachine
- `quiver_character.gd` — 基础脚本（自动处理 `attributes.reset()`, group 添加）
- `quiver_character_skin_base.tscn` — 基础皮肤结构
- `quiver_character_skin.*.gd` — 皮肤脚本（自动处理 AnimationTree）
- 所有 action states（`quiver_action_*.gd`）— 移动、攻击、跳跃、击飞、死亡等

### Chad 自己提供的（角色独有内容）

#### 1. 角色场景配置 `chad.tscn`
继承 `quiver_character_base.tscn`，配置完整的行为树：
```
Chad (extends quiver_character_base)
├─ Collision (CollisionShape2D, r=20 h=204 横向胶囊)
├─ ChadSkin (实例化 chad_skin.tscn)
└─ StateMachine
   ├─ Ground (地面层)
   │  ├─ Move → Idle + Walk
   │  ├─ Hurt (轻伤/重伤)
   │  ├─ Combo1→2→3 (连击序列)
   │  └─ Recovery (倒地起身)
   ├─ Air (空中层)
   │  ├─ Jump → Impulse + MidAir + Landing + Attack
   │  └─ Knockout → Launch + MidAir + Bounce
   └─ Die (死亡)
```

#### 2. 角色脚本 `chad.gd` —— **几乎空壳**
```gdscript
@tool
extends QuiverCharacter
# 只有标准 _ready 模板，不重写任何方法
```

#### 3. 皮肤场景 `chad_skin.tscn`
实例化 `quiver_character_skin_base.tscn`，添加视觉和战斗组件：
```
ChadSkin (extends skin_base)
├─ AnimatedSprite2D (使用 Chad 自己的 sprite_frames)
├─ AnimationPlayer (使用 Chad 自己的 AnimationLibrary)
├─ AnimationTree (配置完整的 AnimationNodeBlendTree)
├─ HurtBox (碰撞类型 = player_hurt_box)
└─ Attacks
   ├─ Attack1 (拳1，HitBox + CollisionShape)
   ├─ Attack2 (拳2)
   ├─ Attack3 (拳3，终结技)
   └─ AttackAir (空中踢)
```

#### 4. 皮肤脚本 `chad_skin.gd` —— **几乎空壳**
```gdscript
@tool
extends QuiverCharacterSkinAnimTree

signal suplex_landed    # Chad 专属：背摔落地信号
signal sliding_stopped  # Chad 专属：滑行结束信号

# 只添加了 2 个 Chad 独有的动画事件信号
# 基础功能都由父类处理
```

#### 5. 资源文件夹 `resources/`
| 文件 | 内容 | 备注 |
|------|------|------|
| `anim_library_chad.tres` | 所有动画集合 | AnimationLibrary |
| `spriteframes_chad.tres` | 所有 sprite frames | 包含 idle/walk/attack/hurt/die 等 |
| `chad_attributes.tres` | 角色属性 | HP、移速、跳跃力等 |
| `chad_gradient.tres` | 生命条颜色 | GradientResource |
| `attacks/punch1_attack_data.tres` | 第一拳伤害数据 | damage + knockback |
| `attacks/punch2_attack_data.tres` | 第二拳 | |
| `attacks/punch3_attack_data.tres` | 第三拳（终结） | 通常更高 damage |
| `attacks/air_kick_attack_data.tres` | 空中踢 | |
| `animations/*.tres` (20+) | 每个动画的独立文件 | idle_left/right, walk_left/right, attack1-3, hurt, etc. |

### 关键理解

1. **角色差异体现在资源**，不在脚本  
   Chad 和 chen_jingchou 的 `.gd` 文件几乎相同，差异化是通过不同的动画、sprite、属性、攻击数据实现的。

2. **行为树结构可复用**  
   所有 action states 由插件提供，只需要在 `.tscn` 中实例化并配置参数（如 `_skin_state`, `_path_next_state`）。

3. **皮肤是视觉层**  
   AnimationTree 控制动画切换，AnimatedSprite2D 播放具体帧动画，HitBox/HurtBox 处理碰撞。

---

## 当前 chen_jingchou 的问题

### 已完成
✅ 复制了 Chad 的完整目录结构  
✅ 批量替换 `chad` → `chen_jingchou`, `Chad` → `ChenJingchou`  
✅ 修复了两个 `.tscn` 的 UID 冲突  

### 待验证
❓ 角色是否能在测试场景中正常显示  
❓ 动画是否能正常播放  
❓ 攻击/跳跃等行为是否正常工作  

---

## 正确的测试流程

1. **删除 `.godot/uid_cache.bin`** — 强制 Godot 重新生成 UID 缓存
2. **重启 Godot 编辑器** — 让它重新扫描资源
3. **手动打开 `chen_jingchou.tscn`** — 确认角色场景能正常加载
4. **运行 `test_stage_phase0.tscn`** — 观察角色是否正常显示

---

## 下一步

如果 Phase 0.1 测试通过，进入 **Phase 0.2：修复镜头 Y 轴滚动 + 创建第一个完整 fight room**
