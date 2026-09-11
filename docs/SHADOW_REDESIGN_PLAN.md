# 阴影系统重构计划：SDF → Polygon 投影

> 版本：v2.1  
> 创建日期：2026-09-04  
> 状态：待实施  
> 取代：LIGHTING_IMPLEMENTATION_PLAN.md 中的 SDF 阴影方案（第二章、第三章）

---

## 1. 问题背景

### 当前架构（SDF ray march）

```
ShadowBox polygon → Godot SDF 纹理 → Sprite2D 平行四边形 → fragment shader 8步 ray march → 阴影
```

### 根本问题

1. **阴影形状错误**：渲染区域是固定平行四边形（4顶点），与 ShadowBox polygon 形状无关。polygon 只影响 SDF 距离值，不影响阴影几何形状。无论 polygon 是三角形还是38顶点剪影，阴影都是"整块填充的平行四边形"。
2. **性能瓶颈**：`texture_sdf()` 在 Intel UHD 上是性能瓶颈（每像素8次采样）。

### 新架构（Polygon 投影）

```
ShadowBox polygon → 沿光线投影到地面 → Polygon2D 直接渲染 → 阴影
```

阴影形状 = polygon 沿光线方向的投影，物理正确。

---

## 2. 架构变更概览

| 组件 | 当前（SDF） | 重构后（Polygon 投影） |
|------|------------|----------------------|
| ShadowRenderer 节点类型 | `Sprite2D` | `Node2D`（子节点挂 `Polygon2D`） |
| 阴影几何来源 | 平行四边形（sprite 尺寸计算） | ShadowBox polygon 投影 |
| 渲染方式 | SDF ray march（8步） | Polygon2D 直接渲染 |
| Shader | `shadow_sdf.gdshader`（SDF采样） | `shadow_polygon.gdshader`（纯色，后续加衰减） |
| SDF 依赖 | 是（`sdf_collision=true`） | 否（`sdf_collision=false`） |
| 软边缘 | SDF ray march 自然产生 | 后续迭代（P1 距离衰减，P2 柔边） |
| 跳跃处理 | SDF ray march 自动偏移 | 通过 `base_height` 增加投影高度 |

---

## 3. 详细实现步骤

### 步骤 1：创建新 shader `shadow_polygon.gdshader`

**文件**: `shaders/shadow_polygon.gdshader`

P0 阶段先用纯色渲染，验证投影正确性后再加衰减。

```glsl
shader_type canvas_item;
render_mode unshaded;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.05, 0.55);

void fragment() {
    COLOR = shadow_color * COLOR;  // 乘以 COLOR 以支持 modulate 淡出
}
```

**后续迭代**：
- P1：添加距离衰减（近端暗 → 远端淡）
- P2：添加柔边效果（smoothstep）

---

### 步骤 2：重写 `character_shadow_controller.gd`

**文件**: `scripts/character_shadow_controller.gd`

**核心变更**：
- `extends Sprite2D` → `extends Node2D`
- 移除所有平行四边形计算和 SDF shader 逻辑
- 添加 Polygon2D 子节点
- 读取 ShadowBox polygon → 使用 Transform2D 矩阵投影到地面 → 更新 Polygon2D

**投影原理**：
- 将 ShadowBox 的垂直轮廓沿光线方向"压扁"到地面
- 使用 Godot 内置的 `Transform2D` 矩阵一次性完成所有顶点的仿射变换
- 阴影锚定在脚部位置（polygon 中 Y 最大的点）

```gdscript
extends Node2D

## 角色阴影控制器
## 由 QuiverCharacter._ready() 动态创建
## 管理：读取 ShadowBox polygon → 沿光线投影到地面 → Polygon2D 渲染

const SHADOW_SHADER_PATH := "res://shaders/shadow_polygon.gdshader"
const DEBUG_OVERLAY_SCRIPT := preload("res://scripts/shadow_debug_overlay.gd")
const DEBUG_ENABLED := true
const MIN_ELEVATION := 5.0
const DEFAULT_ELEVATION := 45.0
const MAX_FADE_HEIGHT := 400.0

static var _shared_material: ShaderMaterial = null

var _skin: QuiverCharacterSkin
var _day_night: Node
var _shadow_polygon: Polygon2D
var _debug_overlay: Node2D = null
var _current_elevation: float = DEFAULT_ELEVATION
var _current_azimuth: float = -45.0

func setup(skin: QuiverCharacterSkin) -> void:
    _skin = skin
    _day_night = get_node_or_null("/root/DayNightManager")
    _setup_shared_material()
    _create_shadow_polygon()
    if DEBUG_ENABLED:
        _create_debug_overlay()
    _update_shadow()

func _setup_shared_material() -> void:
    if _shared_material == null:
        _shared_material = ShaderMaterial.new()
        _shared_material.shader = preload(SHADOW_SHADER_PATH)
        _shared_material.set_shader_parameter("shadow_color", Color(0.0, 0.0, 0.05, 0.55))

func _create_shadow_polygon() -> void:
    _shadow_polygon = Polygon2D.new()
    _shadow_polygon.name = "ShadowPolygon"
    _shadow_polygon.material = _shared_material
    add_child(_shadow_polygon)

func _create_debug_overlay() -> void:
    _debug_overlay = Node2D.new()
    _debug_overlay.name = "ShadowDebugOverlay"
    _debug_overlay.z_index = 1
    _debug_overlay.set_script(DEBUG_OVERLAY_SCRIPT)
    add_child(_debug_overlay)

func _process(_delta: float) -> void:
    _update_shadow()

func _update_shadow() -> void:
    if not _skin:
        return
    var projected := _project_polygon_to_ground()
    if projected.size() > 0:
        _shadow_polygon.polygon = projected
    var jump_height: float = _skin.base_height if _skin else 0.0
    var fade: float = 1.0 - clamp(jump_height / MAX_FADE_HEIGHT, 0.0, 0.8)
    _shadow_polygon.modulate.a = fade
    if _debug_overlay:
        _debug_overlay.update_polygon(projected)

## 将 ShadowBox polygon 投影到地面
## 坐标空间：AnimatedSprite2D 本地 → 角色空间
## 投影原理：沿光线方向压扁 polygon，锚定在脚部位置
## 使用 Transform2D 矩阵一次性完成所有顶点的仿射变换
## 返回投影后的顶点数组（PackedVector2Array）
func _project_polygon_to_ground() -> PackedVector2Array:
    var sprite := _skin.get_node_or_null("AnimatedSprite2D")
    if not sprite:
        return PackedVector2Array()
    var shadow_box := sprite.get_node_or_null("ShadowBox")
    if not shadow_box or not shadow_box is LightOccluder2D:
        return PackedVector2Array()
    var occ: LightOccluder2D = shadow_box
    if not occ.occluder:
        return PackedVector2Array()
    var polygon: PackedVector2Array = occ.occluder.polygon
    if polygon.size() < 3:
        return PackedVector2Array()

    var sprite_xf: Transform2D = sprite.transform  # 渲染器实际使用的完整局部变换
    var elevation := _get_current_elevation()
    var shadow_dir := _get_shadow_direction()
    var tan_elev := tan(deg_to_rad(max(elevation, MIN_ELEVATION)))

    # 找到脚部位置（角色空间中 Y 最大的点）
    var foot_y: float = -INF
    for v in polygon:
        var v_char := sprite_xf * v
        foot_y = max(foot_y, v_char.y)

    # 构建投影变换矩阵
    # 投影公式：
    #   projected.x = v.x + (foot_y - v.y) / tan_elev * shadow_dir.x
    #   projected.y = foot_y + (foot_y - v.y) / tan_elev * shadow_dir.y
    var basis_x := Vector2(1, 0)
    var basis_y := Vector2(-shadow_dir.x / tan_elev, -shadow_dir.y / tan_elev)
    var origin := Vector2(foot_y * shadow_dir.x / tan_elev, foot_y + foot_y * shadow_dir.y / tan_elev)
    var transform := Transform2D(basis_x, basis_y, origin)

    # 转换到角色空间并应用投影变换
    # （sprite 的旋转/缩放/平移全量生效：sprite.scale=0.3 时影子同步缩小）
    var char_polygon := sprite_xf.xform(polygon)

    return transform.xform(char_polygon)

func _get_current_elevation() -> float:
    if _day_night and _day_night.has_method("get_sun_elevation_deg"):
        return _day_night.get_sun_elevation_deg()
    return DEFAULT_ELEVATION

func _get_shadow_direction() -> Vector2:
    if _day_night and _day_night.has_method("get_sun_azimuth_deg"):
        var azimuth: float = _day_night.get_sun_azimuth_deg()
        var shader_angle := fmod(azimuth + 180.0, 360.0)
        var ang_rad := shader_angle * PI / 180.0
        var light_dir := Vector2(sin(ang_rad), cos(ang_rad))
        return -light_dir
    return Vector2(-0.7, 0.7).normalized()
```

**关键设计决策**：

1. **共享 ShaderMaterial**：所有角色共享同一个 `_shared_material` 实例（`static var`），修改 `shadow_color` 时只需改一处。与旧 SDF 方案一致。
2. **Debug 开关**：`DEBUG_ENABLED` 常量控制是否创建调试覆盖层。验证完成后设为 `false`。
3. **跳跃淡出**：通过 `modulate.a` 实现，与后续 P1 距离衰减（shader 内逐像素效果）不冲突。`MAX_FADE_HEIGHT` 控制淡出速度。
4. **Transform2D 投影**：使用 Godot 内置的 `Transform2D` 矩阵完成仿射变换，比手动循环计算更高效，代码更简洁。

**删除的函数**（相比当前 SDF 版本）：
- `_compute_shadow_vertices()` — 不再计算平行四边形
- `_update_verts()` — 不再更新 vertex shader uniform
- `_get_sprite_width()` / `_get_sprite_height()` — 不再需要精灵图尺寸
- `_get_shadow_pixels()` — 不再需要 shadow_max_dist

**保留但重写的函数**：
- `_setup_shared_resources()` → `_setup_shared_material()` — 仍共享 ShaderMaterial，但不再创建 PlaceholderTexture2D

---

### 步骤 3：修改 `quiver_character.gd`

**文件**: `addons/quiver.beat_em_up/characters/quiver_character.gd`

**变更**：`Sprite2D.new()` → `Node2D.new()`

```gdscript
## 动态创建阴影渲染器
## 创建一个 Node2D 节点，挂载 character_shadow_controller.gd 脚本
## 内部创建 Polygon2D 子节点，渲染 ShadowBox polygon 投影到地面的形状
## 由 _ready() 在初始化阶段调用
func _create_shadow_renderer() -> void:
    if not _skin:
        return
    
    var sr := Node2D.new()
    sr.name = "ShadowRenderer"
    sr.z_index = -1
    sr.set_script(SHADOW_CONTROLLER_SCRIPT)
    add_child(sr)
    sr.setup(_skin)
```

---

### 步骤 4：修改 `shadow_debug_overlay.gd`

**文件**: `scripts/shadow_debug_overlay.gd`

**变更**：支持 N 顶点多边形（不再只画4顶点平行四边形）

```gdscript
extends Node2D

## 阴影几何调试覆盖层
## 绘制投影后的 polygon 轮廓（支持 N 顶点）

var _polygon: PackedVector2Array = PackedVector2Array()

func update_polygon(polygon: PackedVector2Array) -> void:
    _polygon = polygon
    queue_redraw()

func _draw() -> void:
    if _polygon.size() < 2:
        return

    for i in range(_polygon.size()):
        var next := (i + 1) % _polygon.size()
        draw_line(_polygon[i], _polygon[next], Color.WHITE, 2.0)

    var colors := [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW,
                   Color.CYAN, Color.MAGENTA, Color.ORANGE, Color.PURPLE]
    for i in range(_polygon.size()):
        draw_circle(_polygon[i], 5.0, colors[i % colors.size()])

    draw_line(Vector2(-15, 0), Vector2(15, 0), Color.WHITE, 2.0)
    draw_line(Vector2(0, -15), Vector2(0, 15), Color.WHITE, 2.0)
```

---

### 步骤 5：禁用 ShadowBox 的 SDF 生成

**位置**: `animation_track_injector.gd` 中 `_ensure_shadow_occluder_exists()`

当前代码：
```gdscript
shadow_box.sdf_collision = true
```

改为：
```gdscript
shadow_box.sdf_collision = false
```

**说明**：
- `sdf_collision` 是静态属性，在创建 ShadowBox 节点时设置一次
- 没有 animation track 控制 `sdf_collision`——track 只驱动 `occluder:polygon`
- 只需修改创建代码，已有角色在 Godot Inspector 中手动设置 `sdf_collision = false`

**影响**：
- ShadowBox 仍然存在，polygon 仍然被 animation track 驱动
- 但不再写入 SDF 纹理（节省 GPU 开销）
- 不影响 Godot 内置光照（本项目未使用）

---

### 步骤 6：清理旧 shader

**文件**: `shaders/shadow_sdf.gdshader` — 保留但不再使用（后续可删除）

---

## 4. 坐标空间详解

### 节点层级

```
RunTest (CharacterBody2D)          position = (0, 0)  ← 脚底
├── RunTestSkin (Node2D)           position = (0, 0)
│   └── AnimatedSprite2D           position = (0, -96) ← 动画 track
│       └── ShadowBox              position = (0, 0) relative to AnimatedSprite2D
│           └── polygon            在 AnimatedSprite2D 本地坐标
└── ShadowRenderer (Node2D)        position = (0, 0)  ← 脚底
    └── ShadowPolygon (Polygon2D)  position = (0, 0)  ← 渲染投影后的 polygon
```

### 投影公式

```
输入: vertex_sprite (AnimatedSprite2D 本地坐标)
转换: vertex_char = AnimatedSprite2D.transform * vertex_sprite  # 含 rotation/scale/position
脚部: foot_y = max(所有 vertex_char.y)  # polygon 中 Y 最大的点
高度: h = foot_y - vertex_char.y  # 相对于脚部的高度，h >= 0
偏移: shadow_offset = h / tan(仰角)
投影: projected.x = vertex_char.x + shadow_offset * shadow_dir.x
      projected.y = foot_y + shadow_offset * shadow_dir.y
```

**关键点**：
- 阴影锚定在脚部位置（`foot_y`），而不是精灵图底部
- 转换用 sprite 的**完整局部变换**（rotation/scale/position 全生效）：对 AnimatedSprite2D 设置 `scale=0.3` 做小体型时，影子与视觉同步缩小；scale=1、rotation=0 时与旧"仅平移"公式逐位等价（历史角色零行为差异）
- 注意：sprite 缩放只同步"渲染 + hurtbox + 影子"；`physical_height/width` 轨道、高度层 Y 偏移、跳跃位移为像素单位烘死，不随 sprite.scale 缩放
- 使用 `Transform2D` 矩阵一次性完成所有顶点的仿射变换
- `shadow_dir` 是阴影方向向量（光线反方向），控制阴影延伸方向

### Transform2D 矩阵

投影公式可以表示为仿射变换矩阵：

```gdscript
var basis_x := Vector2(1, 0)
var basis_y := Vector2(-shadow_dir.x / tan_elev, -shadow_dir.y / tan_elev)
var origin := Vector2(foot_y * shadow_dir.x / tan_elev, foot_y + foot_y * shadow_dir.y / tan_elev)
var transform := Transform2D(basis_x, basis_y, origin)

var projected := transform.xform(char_polygon)
```

**优势**：
- 代码更简洁（一行代码完成所有顶点的投影）
- 性能更好（`xform()` 是 C++ 实现，比 GDScript 循环更快）
- 数学正确（利用 Godot 内置的矩阵运算）

### 投影示例

假设 elevation=45°，azimuth=135°（光源在右上方），shadow_dir = (-0.707, 0.707)：

```
AnimatedSprite2D.position = (0, -96)
polygon 顶点（AnimatedSprite2D 本地坐标）：
  头顶: (-33, -85)
  脚部: (0, 94)

转换到角色空间：
  头顶: (-33, -85) + (0, -96) = (-33, -181)
  脚部: (0, 94) + (0, -96) = (0, -2)

脚部位置：foot_y = max(-181, -2) = -2

头顶顶点投影：
  h = foot_y - vertex_char.y = -2 - (-181) = 179
  shadow_offset = 179 / tan(45°) = 179
  projected.x = -33 + 179 * (-0.707) = -159.6
  projected.y = -2 + 179 * 0.707 = 124.6
  → 阴影在脚部下方（Y > foot_y），正确！

脚部顶点投影：
  h = foot_y - vertex_char.y = -2 - (-2) = 0
  shadow_offset = 0
  projected.x = 0 + 0 = 0
  projected.y = -2 + 0 = -2
  → 脚部顶点位置不变，锚定在脚部，正确！
```

**结果**：阴影从脚部向左下方延伸（因为 shadow_dir = (-0.707, 0.707)），形成一个压扁的多边形。

### 跳跃时的变化

```
跳跃状态: 角色跳起，AnimatedSprite2D.position.y 变小（如 -296）

polygon 顶点（AnimatedSprite2D 本地坐标）不变：
  头顶: (-33, -85)
  脚部: (0, 94)

转换到角色空间：
  头顶: (-33, -85) + (0, -296) = (-33, -381)
  脚部: (0, 94) + (0, -296) = (0, -202)

脚部位置：foot_y = max(-381, -202) = -202

头顶顶点投影：
  h = foot_y - vertex_char.y = -202 - (-381) = 179
  shadow_offset = 179 / tan(45°) = 179
  projected.x = -33 + 179 * (-0.707) = -159.6
  projected.y = -202 + 179 * 0.707 = -75.4
  → 阴影仍然锚定在脚部（foot_y = -202），但整体向上移动

跳跃淡出：
  base_height = -skin.position.y = 200
  fade = 1.0 - clamp(200 / 400, 0.0, 0.8) = 0.6
  → 阴影变淡（modulate.a = 0.6）
```

**注意**：跳跃时 `foot_y` 会变化（因为 AnimatedSprite2D 的 position 变化），但 polygon 的相对形状不变。阴影会跟随角色整体移动，同时通过 `modulate.a` 淡出。

---

## 5. Godot 渲染机制参考

### 核心概念

| 概念 | 含义 | 默认值 |
|------|------|--------|
| `z_index` | 层级，大的覆盖小的 | 0 |
| `z_as_relative` | z_index 是否相对父节点 | true |
| `effective_z` | 实际排序值 | — |
| `y_sort_enabled` | 子节点按 Y 位置排序 | false |
| `show_behind_parent` | 在父节点之前绘制 | false |
| 场景树顺序 | effective_z 相同时的 tiebreaker | — |

### effective_z 计算

```
effective_z(node) =
    如果 z_as_relative == true（默认）:
        node.z_index + effective_z(父节点)
    如果 z_as_relative == false:
        node.z_index
```

### 渲染优先级（从高到低）

| 优先级 | 因素 | 范围 |
|--------|------|------|
| 1（最高） | CanvasLayer.layer | 全局隔离 |
| 2 | effective_z | 同一 CanvasLayer 内 |
| 3a | Y 位置（y_sort 启用时） | 同一 effective_z 内 |
| 3b | show_behind_parent | 同一父节点内（无 y_sort） |
| 4（最低） | 场景树顺序 | tiebreaker |

### y_sort 行为

- 父节点 `y_sort_enabled = true` 时，直接子节点按 Y 位置排序
- Y 小的先画（屏幕上方的物体先画，看起来更远）
- Y 大的后画（屏幕下方的物体后画，看起来更近）
- Y 相同时按场景树顺序
- **只在同一 effective_z 内生效**

### show_behind_parent 限制

- 让子节点在父节点之前绘制
- **如果父节点有 `y_sort_enabled = true`，`show_behind_parent` 不生效**（Godot 已知行为）

---

## 6. 渲染顺序讨论

### 当前场景结构（无 y_sort）

```
TestStage (z=0, 无 y_sort)
├── Background (z=-10)           → effective_z = -10    第 1 个画
├── GroundLine (z=0)             → effective_z = 0      第 4 个画
├── Ground (z=0)                 → effective_z = 0      第 5 个画
├── Character (z=0)              → effective_z = 0      第 6 个画
│   └── ShadowRenderer (z=-1)    → effective_z = -1     第 2 个画
├── Enemy (z=0)                  → effective_z = 0      第 7 个画
│   └── ShadowRenderer (z=-1)    → effective_z = -1     第 3 个画
├── ShortWall (z=0)              → effective_z = 0      第 8 个画
├── TallWall (z=0)               → effective_z = 0      第 9 个画
└── Platform (z=0)               → effective_z = 0      第 10 个画
```

### 渲染顺序分析

| 场景 | 期望行为 | 当前行为 | 是否正确 |
|------|---------|---------|---------|
| 阴影在角色身后 | 角色遮挡阴影 | 角色遮挡阴影 | ✓ |
| 阴影在角色前面，墙在角色前面，墙离观察者更近 | 墙遮挡阴影 | 墙遮挡阴影 | ✓ |
| 阴影在角色前面，墙在角色前面，阴影离观察者更近 | 阴影在墙前面 | 墙遮挡阴影 | ✗ |

### 根本原因

阴影的 `effective_z` 固定为 -1（相对于角色的 z 层级），无法根据光线方向动态调整。阴影的渲染顺序完全由角色的位置决定，而不是阴影实际投射到的地面位置。

### 决定

**保持当前方案，不做修改。** 后续再解决阴影与墙体、台阶坡度的渲染顺序问题。

---

## 7. 验证计划

### 验证 1：投影正确性
- 运行游戏，检查 ShadowDebugOverlay 白色轮廓
- 预期：polygon 投影到地面后，形状为沿 shadow_dir 方向拉伸的多边形

### 验证 2：阴影形状
- 观察阴影是否匹配投影后的 polygon 轮廓
- 预期：阴影形状 = polygon 投影，不再是平行四边形

### 验证 3：多角度
- 修改 DayNightManager 的 azimuth 值（-45°, 0°, 45°, 90°, 135°）
- 预期：阴影方向随光线角度变化，形状正确

### 验证 4：跳跃
- 角色跳跃时观察阴影
- 预期：阴影沿 shadow_dir 方向平移，同时通过 `modulate.a` 淡出（跳得越高越淡）

### 验证 5：动画切换
- 切换不同动画（idle, walk, attack）
- 预期：ShadowBox polygon 随动画变化，阴影形状正确更新

### 验证 6：性能
- 对比重构前后的 FPS（Intel UHD）
- 预期：FPS 提升（消除 texture_sdf 瓶颈）

---

## 8. 后续迭代

| 优先级 | 内容 |
|--------|------|
| P0 | 实现 polygon 投影 + 纯色渲染（本次） |
| P1 | 添加距离衰减（近端暗 → 远端淡） |
| P2 | 添加柔边效果（smoothstep） |
| P3 | 移除旧 SDF shader 和调试代码 |
| P4 | 性能对比测试 |
| P5 | 解决阴影与墙体、台阶坡度的渲染顺序问题 |

---

## 9. 文件变更清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `scripts/character_shadow_controller.gd` | **重写** | Node2D + Polygon2D + 投影逻辑 |
| `scripts/shadow_debug_overlay.gd` | **修改** | 支持 N 顶点多边形 |
| `shaders/shadow_polygon.gdshader` | **新建** | 纯色阴影 shader（后续加衰减） |
| `addons/.../quiver_character.gd` | **修改** | Sprite2D → Node2D |
| `addons/.../animation_track_injector.gd` | **修改** | sdf_collision = false |
| `shaders/shadow_sdf.gdshader` | **保留** | 不再使用，后续清理 |
