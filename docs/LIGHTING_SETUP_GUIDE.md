# 光照与阴影系统 — 配置指南

本文档面向关卡设计师，说明如何在新 stage 场景中配置昼夜循环光照和角色阴影系统。

---

## 一、系统架构概览

```
光照系统由三个层级组成：

L1 — project.godot 全局配置（SDF + Autoload）     ← 一次性配置，无需每个 stage 重复
L2 — 角色阴影系统（自动）                          ← QuiverCharacter._ready() 动态创建，无需手动添加
L3 — 昼夜循环系统（每个 stage 手动添加）            ← 需要在每个 stage 场景中添加节点
```

---

## 二、L1：project.godot 配置（已完成）

### 2.1 SDF 设置

```ini
[rendering]
2d/sdf/scale=0.125
```

| 参数 | 当前值 | 说明 |
|------|--------|------|
| `2d/sdf/scale` | `0.125` | SDF 纹理分辨率 = 视口 × 12.5%（1280×720 → 160×90） |
| `2d/sdf/oversize` | 未设置（默认 1） | SDF 纹理覆盖范围 = 视口 × 100% |

**注意**：`texture_sdf()` 返回的距离单位是画布像素（= 屏幕像素），与 `sdf_scale` 无关。`sdf_scale` 只影响 SDF 纹理的精度，不影响距离计算。

### 2.2 Autoload 注册

```ini
[autoload]
DayNightManager="*res://scripts/day_night/day_night_manager.gd"
```

DayNightManager 是全局单例，管理时间相位状态和过渡动画。所有 stage 的 DayNightController 通过它获取光源参数。

---

## 三、L2：角色阴影系统（自动，无需配置）

每个角色的 `QuiverCharacter._ready()` 会自动创建：

| 节点 | 类型 | 说明 |
|------|------|------|
| `ShadowRenderer` | `Sprite2D` (z_index=-1) | 1×1 纹理，vertex() 变形为平行四边形 |
| `ShadowBox` | `LightOccluder2D` | 在 skin 模板中预置，polygon 由动画 track 逐帧驱动 |

**无需手动添加任何节点。** 角色阴影由 `character_shadow_controller.gd` 自动管理：
- 每帧从 `DayNightManager` 读取 elevation/azimuth
- 计算阴影长度和方向，更新 shader instance uniform
- 跳跃时阴影自然淡出（`shadow_max_dist` 不含 `base_height`）

### 阴影参数（由 controller 自动计算）

| 参数 | 公式 | 说明 |
|------|------|------|
| `shadow_max_dist` | `clamp(sprite_h / tan(elevation), 30, 600)` | SDF ray march 最大距离（画布像素） |
| `shadow_size` | `(sprite_w, full_h)` | 平行四边形尺寸 |
| `shadow_dir` | `-Vector2(sin(ang), cos(ang))` | 阴影投射方向 |

---

## 四、L3：昼夜循环系统（每个 stage 需要配置）

### 4.1 需要添加的节点

在每个 stage 场景的根节点下添加：

```
Stage (Node2D)
├── CanvasModulate              ← 全局调色
│   └── color: Color.WHITE（初始值，运行时由 Controller 覆盖）
├── DirectionalLight2D           ← 主方向光源
│   ├── rotation_degrees: -45.0（默认右上方）
│   └── shadow/enabled: false   ← ⚠️ 必须关闭！阴影由 ShadowBox + SDF shader 负责
├── DayNightController (Node)    ← 昼夜控制器
│   ├── script: day_night_controller.gd
│   ├── scene_time_data: SceneTimeData（Inspector 中配置）
│   ├── canvas_modulate_path: "../CanvasModulate"
│   ├── directional_light_path: "../DirectionalLight2D"
│   └── point_lights_paths: ["../Lantern1", "../Lantern2", ...]
├── Lantern1 (PointLight2D)      ← 可选：灯笼/火把
│   ├── enabled: false（初始关闭，DUSK/NIGHT 自动点亮）
│   ├── texture: GradientTexture2D（径向渐变）
│   └── color: Color(1, 0.8, 0.5, 1)
└── Lantern2 (PointLight2D)      ← 可选：更多灯笼
```

### 4.2 配置 SceneTimeData

在 Inspector 中创建 SceneTimeData 资源，配置各相位参数：

**相位枚举**（`DayNightManager.TimePhase`）：

| 值 | 名称 | 中文 |
|----|------|------|
| 0 | DAWN | 黎明 |
| 1 | DAY | 白天 |
| 2 | DUSK | 黄昏 |
| 3 | NIGHT | 夜晚 |

**默认参数值：**

| 参数 | DAWN | DAY | DUSK | NIGHT |
|------|------|-----|------|-------|
| CanvasModulate 颜色 | `(0.95, 0.85, 0.75)` 暖橙 | `(1.0, 1.0, 1.0)` 白 | `(0.9, 0.7, 0.5)` 暮橙 | `(0.3, 0.4, 0.6)` 冷蓝 |
| DirectionalLight2D 旋转 | `-70°`（右侧低角度） | `-45°`（右上方） | `70°`（左侧低角度） | `45°`（左上方） |
| DirectionalLight2D 能量 | `0.6` | `1.0` | `0.5` | `0.3` |
| DirectionalLight2D 颜色 | `(1.0, 0.8, 0.6)` 暖黄 | `(1.0, 1.0, 0.95)` 淡黄 | `(1.0, 0.6, 0.3)` 橙红 | `(0.6, 0.7, 1.0)` 冷蓝 |
| 太阳仰角 (elevation) | `20°` | `45°` | `20°` | `30°` |
| 灯笼 | ❌ | ❌ | ✅ | ✅ |

**可选参数：**

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `default_phase` | int | `1` (DAY) | 进入场景时的初始相位 |
| `can_cycle` | bool | `false` | 是否自动循环 DAY→DUSK→NIGHT→DAWN |
| `cycle_duration` | float | `300.0` | 完整循环时长（秒），4 个相位等分 |
| `transition_duration` | float | `2.0` | 相位过渡动画时长（秒） |
| `point_lights_enabled_phases` | Array | `[2, 3]` | 哪些相位点亮灯笼 |

### 4.3 相位过渡机制

切换相位时：
1. `DayNightManager` 创建 Tween，在 `transition_duration` 秒内将 `progress` 从 0 插值到 1
2. 每帧触发 `phase_transitioning` 信号，`DayNightController` 插值：
   - `CanvasModulate.color`：`from_color.lerp(to_color, progress)`
   - `DirectionalLight2D.rotation`：`lerp_angle(from_rot, to_rot, progress)`
   - `DirectionalLight2D.energy` / `color`：`lerp()`
3. 阴影方向通过 `get_sun_elevation_deg()` / `get_sun_azimuth_deg()` 读取插值缓存，平滑旋转

---

## 五、光照覆盖（LightingOverride）

用于法术或剧情触发的临时光照变化（如 Boss 战变暗）。

### 5.1 使用方式

```gdscript
var override := LightingOverride.new()
override.color = Color(0.2, 0.2, 0.3)        # CanvasModulate 目标颜色
override.light_rotation = 200.0               # DirectionalLight2D 目标旋转
override.light_energy = 0.3                   # DirectionalLight2D 目标能量
override.light_color = Color(0.4, 0.3, 0.5)   # DirectionalLight2D 目标颜色
override.transition_duration = 0.5            # 过渡时长（秒）
override.priority = 10                        # 优先级（越高越优先）

var id := DayNightManager.apply_lighting_override(override, 3.0)  # 3 秒后自动恢复
```

### 5.2 覆盖栈

多个覆盖可以叠加。`DayNightManager` 按 `priority` 排序，取最高优先级的覆盖生效。调用 `remove_lighting_override(id)` 可提前移除。

---

## 六、Shader 参数调参

### 6.1 共享参数（所有角色相同）

通过 `ShaderMaterial` 设置，在 `character_shadow_controller.gd` 的 `_setup_shared_resources()` 中初始化：

| 参数 | 默认值 | 范围 | 效果 |
|------|--------|------|------|
| `color` | `(0.0, 0.0, 0.05, 0.55)` | vec4 | 阴影颜色 + 最大不透明度 |
| `softness` | `0.4` | 0.0 ~ 1.0 | 0 = 最柔和（长渐变），1 = 最硬（阶跃） |
| `gradientTexture` | 未启用 | sampler2D | 启用后覆盖 softness，用纹理控制淡出曲线 |

### 6.2 实例参数（每角色独立，自动计算）

| 参数 | 说明 |
|------|------|
| `shadow_size` | 平行四边形 (width, height) |
| `shadow_top_offset` | 顶边偏移 |
| `shadow_bottom_offset` | 底边偏移 |
| `shadow_max_dist` | SDF ray march 最大距离 |

### 6.3 推荐调参方向

| 场景 | color.a | softness | 说明 |
|------|---------|----------|------|
| 明亮白天 | 0.4 ~ 0.5 | 0.3 ~ 0.5 | 柔和阴影，半透明 |
| 黄昏/夜晚 | 0.6 ~ 0.7 | 0.2 ~ 0.4 | 更浓的阴影，更柔和的边缘 |
| 室内/洞穴 | 0.3 ~ 0.4 | 0.5 ~ 0.7 | 浅阴影，较硬边缘 |

---

## 七、轮廓转换工具（ShadowBox polygon）

角色的 ShadowBox polygon 通过 Inspector 面板的轮廓转换工具自动生成：

### 7.1 操作步骤

1. 在 Godot 中打开角色 skin 场景
2. 选中根节点（`XXXSkin`）
3. 在 Inspector 面板找到 **高度层碰撞设置** 区域
4. 选择 `category = Body`
5. 调整 ShadowBox 参数：
   - `shadow_simplify_tolerance`: 默认 `20`（越小轮廓越精细）
   - `shadow_min_area_ratio`: 默认 `0.2`（越小保留越多小碎片）
6. 点击 **转换轮廓** 按钮
7. 工具自动扫描精灵图 → 生成 polygon → 注入动画 track

### 7.2 参数建议

| 精灵图复杂度 | tolerance | min_area_ratio | 说明 |
|-------------|-----------|----------------|------|
| 简单（人形，无装饰） | 30 ~ 50 | 0.3 | 少量顶点即可 |
| 中等（有披风/长发） | 15 ~ 25 | 0.15 | 保留更多轮廓细节 |
| 复杂（大量装饰/翅膀） | 10 ~ 15 | 0.1 | 最精细的轮廓 |

---

## 八、常见问题排查

### Q1：阴影不显示

**检查清单：**
1. `DirectionalLight2D.shadow/enabled` 是否为 `false`？（必须关闭内置阴影）
2. `project.godot` 中 `DayNightManager` autoload 是否注册？
3. 角色 skin 中是否有 `ShadowBox` (LightOccluder2D) 节点？
4. `ShadowBox.occluder` 是否设置了 `OccluderPolygon2D`？
5. `OccluderPolygon2D.polygon` 是否非空？（用轮廓转换工具生成）

### Q2：阴影方向跳变（不平滑）

**原因**：`DayNightManager` 的方位角插值缓存未生效。
**检查**：`day_night_manager.gd` 中 `transition_to()` 是否在 Tween 回调中同时更新 `_interpolated_elevation` 和 `_interpolated_azimuth`。

### Q3：阴影太短或太长

**调整 `character_shadow_controller.gd` 中的常量：**

| 常量 | 默认值 | 效果 |
|------|--------|------|
| `MIN_ELEVATION` | `5.0` | 太阳最小仰角（越小阴影越长） |
| `MAX_SHADOW_LENGTH` | `600.0` | 阴影最大像素长度 |
| `MIN_SHADOW_LENGTH` | `30.0` | 阴影最小像素长度 |

### Q4：阴影边缘锯齿

**解决方案：**
1. 降低 `softness`（更柔和的过渡掩盖锯齿）
2. 提高 `sdf_scale`（更高的 SDF 分辨率，但性能代价更大）

### Q5：灯笼在 DUSK/NIGHT 不亮

**检查清单：**
1. `SceneTimeData.point_lights_enabled_phases` 是否包含 `2` 和 `3`？
2. `DayNightController.point_lights_paths` 是否指向正确的 NodePath？
3. PointLight2D 的 `texture` 是否设置了 `GradientTexture2D`？
4. PointLight2D 的 `enabled` 初始值是否为 `false`？

---

## 九、文件清单

| 文件 | 说明 |
|------|------|
| `shaders/shadow_sdf.gdshader` | SDF 阴影渲染 shader |
| `scripts/character_shadow_controller.gd` | 角色阴影控制器 |
| `scripts/shadow_debug_overlay.gd` | 阴影调试菱形绘制 |
| `scripts/day_night/day_night_manager.gd` | 昼夜循环全局管理器（Autoload） |
| `scripts/day_night/day_night_controller.gd` | 场景内昼夜控制器 |
| `scripts/day_night/scene_time_data.gd` | 场景时间配置资源 |
| `scripts/day_night/lighting_override.gd` | 光照覆盖资源 |
| `scripts/debug_day_night_input.gd` | 调试按键（1/2/3/4 切换相位，O 覆盖） |
| `scripts/debug_height_overlay.gd` | 高度层 + 阴影调试面板 |
| `scripts/debug_knockout_overlay.gd` | 击飞调试面板 |
| `scripts/debug_spell_test_overlay.gd` | 法术碰撞调试面板 |
