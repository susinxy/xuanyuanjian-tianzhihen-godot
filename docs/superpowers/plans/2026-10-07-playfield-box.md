# 盒轨搭建批（PlayfieldBox）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 段搭建范式切换为"一个盒+盒内装修"——新组件 `PlayfieldBox` 派生可移动区边界，校验器从"形状核对"修法为"死锁核对"（房 demotion），并交付模板 v2 双形态示范。

**Architecture:** 全部改动在**游戏仓侧**（`scripts/chapter/`、`tools/stage_validator/`、`scenes/chapter/`），**插件零改动**（`addons/quiver.beat_em_up/` 一字不碰，PLUGIN_ARCHITECTURE 无需同批改）。校验器为纯文本解析器（FileAccess 逐行），运行时几何生成不落 .tscn 文本、天然在执法域外。

**Tech Stack:** Godot 4.7.1 / GDScript 4；场景 runner 契约（`_check`/`_frames`/完成旗形制，参照 `tools/control_contract/control_contract.gd`）；stage_validator fixtures 声明制（头属性 `expect="R#"`）。

**Spec:** `docs/superpowers/specs/2026-10-07-playfield-box-design.md`（裁决记录在 §八，验收在 §七，先读它）

## Global Constraints

- 所有注释中文；`.gd` 蛇形命名、`.tscn` 蛇形、节点 PascalCase；commit 中文 `feat:/fix:/docs:`。
- **插件目录禁改**；本批唯一新代码文件= `scripts/chapter/playfield_box.gd`、`tools/box_contract/*`、fixture `.tscn`。
- 手改 .tscn 铁律（AGENTS）：StringName 键必须 `&"x"`；复合属性写完整构造式（`Vector2(a, b)`，禁标量）；`[node]` 属性块内**禁插注释行**；`load_steps` = ext+sub 数+1；删节点=头行+属性块整段删；改完 `git diff` 逐行核对 + headless 读回自证。
- headless 环境：Linux 端 `godot --headless --path . <场景|script>`；test_actor 消费前 `bash tools/matrix_runner/run_matrix.sh --ensure-only`；全矩阵唯一入口 `run_matrix.sh`；**异步 runner 末尾完成旗防静默跳段**。
- 新套注册须过 **R8 体检**：先故意破坏被测对象证响亮红（红档贴报告归档），复原再证全绿。
- 提交逐路径点名（禁 `git add -A`）；用户 WIP 不碰（`scenes/stages/xuanyuan-chapter-1/**`、`spells/fire_ball/**`）。
- 矩阵基线从 32 套=33 跑变为 **33 套=34 跑**（新增 box_contract）；终跑 RED=0 才可交。

---

### Task 1: PlayfieldBox 组件 + box_contract 套件（含 R8 术前红据）

**Files:**
- Create: `scripts/chapter/playfield_box.gd`
- Create: `tools/box_contract/box_contract.gd`、`tools/box_contract/box_contract.tscn`、`tools/box_contract/fixtures/seg_box_min.tscn`、`tools/box_contract/probe_body.gd`
- Modify: `tools/matrix_runner/run_matrix.sh`（roster 追加一行）

**Interfaces:**
- Produces: `PlayfieldBox`（class_name，`extends ReferenceRect`，@tool；组注册 `&"playfield_box"`；导出 `band_depth: float`、`gen_bands: bool`、`north_wall/south_wall/east_wall/west_wall: bool`、`gen_vis: bool`；运行时子节点 `BandNorth/BandSouth/BandEast/BandWest`（StaticBody2D+CollisionShape2D，layer=16760832/mask=0）、`VisFloor`（Polygon2D z=-10））。Task 2/3 依赖这些名字与配方值。

- [ ] **Step 1: 写 `scripts/chapter/playfield_box.gd`（全文）**

```gdscript
@tool
class_name PlayfieldBox
extends ReferenceRect

## 可移动区盒（2026-10 盒轨搭建批 G1，法源 specs/2026-10-07-playfield-box-design §二）：
## 编辑器拖框=段的可行走闭区间；运行时派生四边实体墙带（**外贴**，不吞可行走面积）
## 与可选 Vis 地板。墙带为运行时生成，不落 .tscn 文本（校验器管辖外，防手改）。
## 坐标系契约（R13②）：anchors 保持默认、offset 四值即段局部矩形（雷区 a 同源）。
## 单一职责：只管边界，不碰阴影（ShadowRegion 为平级家具，默认不摆=全区域回退）。

const HEIGHT_ALL := 16760832  # = QuiverCharacter.get_all_height_layers_mask()，同 R7 配方

## 墙带外延厚度（致死击飞 ≤2000px/s ≈33px/拍，400 深冗余封锁）
@export var band_depth := 400.0
## 总开关：生成四边实体墙带
@export var gen_bands := true
## 单边墙开关（法典雷 k：盒南北界与相机动态带是两层墙，竖向大于视口时外圈墙永不被撞）
@export var north_wall := true
@export var south_wall := true
@export var east_wall := true
@export var west_wall := true
## 运行时生成地板色块（纯装饰，z=-10 Vis 惯例）
@export var gen_vis := true


func _ready() -> void:
	if Engine.is_editor_hint():
		QuiverEditorHelper.disable_all_processing(self)
		return
	add_to_group(&"playfield_box")
	# 盒矩形（段局部坐标）=anchors 默认下 offset 四值直读（勿用 get_global_rect——
	# 子节点局部计算与全局变换解耦，见 _band 的 origin 换算）
	var origin := Vector2(offset_left, offset_top)
	var size := Vector2(offset_right - offset_left, offset_bottom - offset_top)
	if size.x <= 0.0 or size.y <= 0.0:
		push_warning("PlayfieldBox %s 矩形零面积（offset 未摆正），墙带/地板不生成" % get_path())
		return
	if gen_bands:
		_make_band(&"BandNorth", Rect2(origin.x, origin.y - band_depth, size.x, band_depth))
		_make_band(&"BandSouth", Rect2(origin.x, origin.y + size.y, size.x, band_depth))
		_make_band(&"BandEast", Rect2(origin.x + size.x, origin.y - band_depth,
				band_depth, size.y + 2.0 * band_depth))
		_make_band(&"BandWest", Rect2(origin.x - band_depth, origin.y - band_depth,
				band_depth, size.y + 2.0 * band_depth))
	if gen_vis:
		_make_vis(origin, size)


func _get_configuration_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	if anchor_left != 0.0 or anchor_top != 0.0 or anchor_right != 0.0 or anchor_bottom != 0.0:
		w.append("盒矩形坐标系将失配（R13②）：anchors 须保持默认，矩形全靠 offset 四值")
	return w


## 单边墙带：开关关则不建。body 挂盒下，局部坐标=世界矩形-盒原点（保全局变换
## 显式换算——add_child 第二参不是保形义务，判例见 AGENTS 手改 tscn 节）
func _make_band(p_name: StringName, world_seg_rect: Rect2) -> void:
	var enabled := north_wall if p_name == &"BandNorth" else (
			south_wall if p_name == &"BandSouth" else (
			east_wall if p_name == &"BandEast" else west_wall))
	if not enabled:
		return
	var body := StaticBody2D.new()
	body.name = p_name
	body.collision_layer = HEIGHT_ALL
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = world_seg_rect.size
	shape.shape = rs
	body.add_child(shape)
	add_child(body)
	var origin := Vector2(offset_left, offset_top)
	body.position = world_seg_rect.get_center() - origin


func _make_vis(origin: Vector2, size: Vector2) -> void:
	var floor_v := Polygon2D.new()
	floor_v.name = "VisFloor"
	floor_v.z_index = -10
	floor_v.color = Color(0.55, 0.43, 0.25, 1.0)
	floor_v.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)])
	add_child(floor_v)
```

注意：`_make_band` 里 `p_name` 比较与四开关映射——若嫌绕可改为显式四参版本（每边传 enabled bool）；执行时**二选一即可，测试判据不变**。

- [ ] **Step 2: 写 `tools/box_contract/probe_body.gd`（确定性格子兵，绕开行为档/通道 API 风险）**

```gdscript
extends CharacterBody2D

## 盒契约探针体：恒定速度驱动 move_and_slide（判例合规：裸舞台角色初速沉降
## 相位随机——本腿自带确定性，不用活体角色推演边界几何）。mask=全高度层，
## 真实角色持当前高度位 ⊆ 全集，墙带可见性判据保守等价。

var axis := Vector2.ZERO
var speed := 400.0

const HEIGHT_ALL := 16760832


func _ready() -> void:
	collision_layer = HEIGHT_ALL
	collision_mask = HEIGHT_ALL
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(20, 20)
	shape.shape = rs
	add_child(shape)


func _physics_process(_delta: float) -> void:
	velocity = axis * speed
	move_and_slide()
```

- [ ] **Step 3: 写 fixture `tools/box_contract/fixtures/seg_box_min.tscn`**

盒段最小几何（段形根+盒，x:-200..800、y:-200..300，供 A/B/C/D 腿）：

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/chapter/stage_content.gd" id="1_sc"]
[ext_resource type="Script" path="res://scripts/chapter/playfield_box.gd" id="2_box"]

[node name="SegBoxMin" type="Node2D"]
script = ExtResource("1_sc")
segment_id = &"fx_box_min"
entry_points = {&"default": Vector2(0, 100)}

[node name="PlayfieldBox" type="ReferenceRect" parent="."]
script = ExtResource("2_box")
offset_left = -200.0
offset_top = -200.0
offset_right = 800.0
offset_bottom = 300.0
```

（load_steps=3：2 ext+0 sub+1。entry (0,100) 在盒内——R13③ 兼容。）

- [ ] **Step 4: 写 `tools/box_contract/box_contract.gd`（A-E 腿）**

形制逐条抄 `tools/control_contract/control_contract.gd`（`_check`/`_frames`/`_require_kit`/完成旗/`════════` 汇总行）；runner 场景根 Node。常量：

```gdscript
const Kit := preload("res://tools/matrix_runner/test_actor_kit.gd")
const SEG_FIXTURE := "res://tools/box_contract/fixtures/seg_box_min.tscn"
const PROBE := preload("tools/box_contract/probe_body.gd")
const BOX_RECT := Rect2(-200, -200, 1000, 500)   # fixture 盒矩形（局部=世界，段摆原点）
const EXPECTED := 18  # 末数按终账门
```

腿序与判据（全部在 `_ready` 里 `await` 串行；每腿先 `_require_kit` 仅 E 腿需要）：

- **A 装配自证**：实例化 fixture 段 add_child（挂 self），`_frames(2)`；取 `$PlayfieldBox`；`_check(box != null, "A1 盒节点在位")`；四面墙带 `_check(box.get_node_or_null(^"BandNorth") != null …)`（4 断言）；`_check(body.collision_layer == 16760832 and body.collision_mask == 0)` 逐带（4 断言，共 A=9）；`_check(box.is_in_group(&"playfield_box"), "A10 组注册")`。
- **B 行走封锁**：probe 实例挂段内 `global_position = Vector2(0, 0)`（盒内）；`axis=Vector2(0,1)`；`_frames(180)`；`_check(pb.global_position.y <= BOX_RECT.end.y + 4.0, "B 南界封锁（实际 %s）")`；改 `axis=Vector2(1,0)` 再 180 拍 `_check(pb.global_position.x <= BOX_RECT.end.x + 4.0, "B 东界封锁")`（+2 断言=11）。
- **C 击飞封锁**：probe 复位 `(0,0)`，`speed=1500`，`axis=Vector2(1,0)` 30 拍后 `axis=Vector2.ZERO`；`_check(pb.global_position.x <= BOX_RECT.end.x + 4.0, "C 高速 1500px/s 不穿盒墙")`（+1=12）。
- **D Vis/开关独立性**：重新实例化 fixture（先 `_frames(1)` + 上一 probe `queue_free`），add_child **前** `seg.get_node("PlayfieldBox")` 取不到——改为 instantiate 后遍历根子找 script 为 playfield_box 的节点，设 `gen_vis=false`、`north_wall=false` 再 add_child；`_frames(2)`；`_check(box.get_node_or_null(^"VisFloor") == null, "D1 gen_vis 关闭无地板件")`；`_check(box.get_node_or_null(^"BandNorth") == null, "D2 north_wall 关闭无北带")`；`_check(box.get_node_or_null(^"BandSouth") != null, "D3 其余墙带不受影响")`（+3=15）。
- **E 真角色共存冒烟**：`_require_kit("E")`；test_actor 实例 add_child 于段内、`global_position=Vector2(0,100)`；`_frames(60)`（沉降判例）；`_check(actor.global_position.y <= BOX_RECT.end.y + 60.0, "E1 活体不越界（宽松界，判据见判例：初速沉降 ±）")`；`_check(true if no SCRIPT ERROR log?` ——以 `actor != null and actor.attributes.health_current > 0.0, "E2 活体存活入场"`（+2=17）；腿末清场 `queue_free` 两实例+`_frames(3)`。
- 最后一条：`_check(_finished, "F 全序列执行完成")`（完成旗判例，凑满 EXPECTED=18）。

`_report()`：`print("════════ box-contract: %s ════（断言 %d，红 %d，完成旗=%s）")` 与 PASS/FAIL 判定，仿 control_contract 原样。

- [ ] **Step 5: 写 `tools/box_contract/box_contract.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tools/box_contract/box_contract.gd" id="1_box"]

[node name="BoxContract" type="Node"]
script = ExtResource("1_box")
```

- [ ] **Step 6: R8 术前红据（先红后绿，归档）**

```bash
# 备份墙带段并摘除生成
cp scripts/chapter/playfield_box.gd /tmp/opencode/box_batch/playfield_box.gd.bak
python3 - <<'EOF'  # 把 _ready 中三行 _make_band 调用与 Band 生成注释掉
EOF
bash tools/matrix_runner/run_matrix.sh --ensure-only
timeout 500 godot --headless --path . res://tools/box_contract/box_contract.tscn \
  > /tmp/opencode/box_batch/red_no_bands.log 2>&1
# 判据：A 墙带在位/配方系、B、C 必须 FAIL；Vis/组/存活腿仍 PASS；红档留存
# 复原 .bak → 复跑全绿
```

Expected：红档 ≥6 FAIL（A2-A9、B×2、C），无 SCRIPT ERROR；复原后 `PASS ════ 断言 18 红 0`。红档文件永久归档（报告附路径）。

- [ ] **Step 7: 注册矩阵**

`tools/matrix_runner/run_matrix.sh` roster 数组 control_contract 行后追加：

```
	"scene|box_contract|tools/box_contract/box_contract.tscn"
```

- [ ] **Step 8: 单跑复验+提交**

```bash
timeout 500 godot --headless --path . res://tools/box_contract/box_contract.tscn 2>&1 | tail -3
git add scripts/chapter/playfield_box.gd tools/box_contract/ tools/matrix_runner/run_matrix.sh
git commit -m 'feat: 盒轨搭建批 T1——PlayfieldBox 组件（拖框=可移动区、四边实体墙带运行时外贴派生、单边开关、Vis 地板可选、零阴影暗线）+box_contract 套件 A-E 腿 18 断言（R8 术前红据：摘墙带 B/C 响亮红归档）；矩阵 33 套=34 跑注册'
```

---

### Task 2: 校验器修法（R3 降黄 / R4 接线化 / R9 去房化 / R13 盒轨）+ fixtures

**Files:**
- Modify: `tools/stage_validator/validator.gd`（`_check_r3`:329、`_check_r4`:343、`_check_r9`:~420、dispatch `:204-222`、常量区 `:67-71`、头注规则表 `:13-57`）
- Create: `tools/stage_validator/fixtures/` 九个新 fixture（清单见 Step 4）

**Interfaces:**
- Consumes: Task 1 的 `res://scripts/chapter/playfield_box.gd` 路径字符串（fixture 文本引用，真实文件已存在可导入）。
- Produces: 新签名 `_check_r4(detectors, spawners, add)`、`_check_r9(detectors, add)`、`_check_r13(model, root, add)`；规则码 `R13`；NOTICE 打印通道（不计违例、不参与 expect 比对）。

- [ ] **Step 1: R8 术前红据（旧法跑新 fixtures）**

先写 Step 4 的 fixtures（文件到位但校验器未改），跑：

```bash
godot --headless --path . -s tools/stage_validator/validator.gd -- --fixtures \
  > /tmp/opencode/box_batch/red_old_law_fixtures.log 2>&1
```

Expected：`no_room_band` FAIL（expect=none 实触发 R4）——形状法拦遭遇带的铁证；`box_double/box_anchored/box_entry_outside` FAIL（expect=R13 实触发空集）；`orphan_spawner` 可能绿（旧法无孤儿检查=真死锁漏网，也是证据）；归档。

- [ ] **Step 2: 改 `validator.gd` 四个函数+dispatch+常量**

头注规则表同步改写（R3/R4/R9 新文+R13 行，法源指 spec §三）。

```gdscript
const PLAYBOX_GD := "playfield_box.gd"   # R13 盒轨（常量区）
```

dispatch 区（现 `:207-208` 两行改三行、`:213` R9 换签、R13 挂在 R14 臂后）：

```gdscript
	_check_r3(rooms, detectors)
	_check_r4(detectors, spawners, add)
	# ...R5/R6/R7 不动...
	_check_r9(detectors, add)
	# ...R10/R11/R12...
	if is_segment:
		_check_r13(model, root, add)
```

R3（整体替换：降为 NOTICE 打印，不进 violations）：

```gdscript
## R3 降黄（盒轨批：纯特写房=合法，解锁机制缺口法典待立项——只提醒不执法）
func _check_r3(rooms: Array, detectors: Array) -> void:
	for room in rooms:
		if _under(room, detectors).is_empty():
			print("NOTICE: R3黄 房 %s 无检测器触发（空特写房合法，注意无解锁源）" % room.full)
```

R4（整体替换，头注新文=两条死锁核对）：

```gdscript
## R4 接线化（旧"room 与 spawner 都必填"是配方形状核对，误伤合法遭遇带；
## 新罚真危害两端：哑检测器=player_detected 无人应答；孤儿生成器=波永不刷
## +壳实源集缺员=推进死锁）
func _check_r4(detectors: Array, spawners: Array, add: Callable) -> void:
	var covered := {}
	for det in detectors:
		var room_p := _nodepath_of(det.props.get("path_fight_room", ""))
		var sp_list := _nodepaths_of(det.props.get("paths_enemy_spawners", ""))
		if room_p.is_empty() and sp_list.is_empty():
			add.call("R4", "检测器 %s 既无房亦无波次引用（哑件；处方：挂 path_fight_room 或至少引一个生成器）" % det.full)
		for p in sp_list:
			covered[_resolve(det.full, p)] = true
	for sp in spawners:
		if not covered.has(sp.full):
			add.call("R4", "生成器 %s 未被任何检测器引用（孤儿：波永不刷+段判清实源缺员=死锁；处方：列入某检测器 paths_enemy_spawners）" % sp.full)
```

R9（整体替换：owner 从"房"改"检测器"）：

```gdscript
## R9 去房化：同一生成器被 ≥2 检测器共引=争抢波次所有权（遭遇带无房也入网）
func _check_r9(detectors: Array, add: Callable) -> void:
	var owners := {}
	for det in detectors:
		for p in _nodepaths_of(det.props.get("paths_enemy_spawners", "")):
			var key := _resolve(det.full, p)
			if not owners.has(key):
				owners[key] = {}
			owners[key][det.full] = true
	for key in owners:
		if owners[key].size() >= 2:
			add.call("R9", "spawner %s 被 %d 个检测器共引" % [key, owners[key].size()])
```

R13（新增函数）：

```gdscript
## R13 盒轨（spec §三）：管辖=含 playfield_box.gd 的段文件；旧形段（无盒）
## 不查=兼容通道（ref/demo 不迁移判例在册）。①唯一②坐标系契约③入口在盒④房越盒黄。
func _check_r13(model: Dictionary, root: Dictionary, add: Callable) -> void:
	var boxes := _kind_nodes(model, PLAYBOX_GD)
	if boxes.is_empty():
		return
	if boxes.size() > 1:
		add.call("R13", "段含 %d 个盒（双盒=模型破产；一段一界）" % boxes.size())
		return
	var box: Dictionary = boxes[0]
	if box.get("parent", ".") != ".":
		add.call("R13", "盒 %s 必须直挂段根（家具坐标系契约）" % box.full)
		return
	for k in box.props:
		if k.begins_with("anchor_") or k == "scale" or k == "position":
			add.call("R13", "盒 %s 写了非默认坐标属性 %s（矩形全靠默认 anchors+offset，雷区 a 同源）" % [box.full, k])
			return
	var l := float(box.props.get("offset_left", "0"))
	var t := float(box.props.get("offset_top", "0"))
	var r := float(box.props.get("offset_right", "0"))
	var b := float(box.props.get("offset_bottom", "0"))
	var rect := Rect2(l, t, r - l, b - t)
	if not rect.has_area():
		add.call("R13", "盒 %s 零面积（offset 未摆正）" % box.full)
		return
	var ep: String = root.props.get("entry_points", "")
	if ep != "":
		var rx := _rx('Vector2\\(\\s*(-?\\d+(?:\\.\\d+)?),\\s*(-?\\d+(?:\\.\\d+)?)\\)')
		for m in rx.search_all(ep):
			var pt := Vector2(m.get_string(1).to_float(), m.get_string(2).to_float())
			if not rect.grow(0.5).has_point(pt):
				add.call("R13", "入口 %s 越出盒矩形 %s（落位必穿墙带；处方：改 entry_points 或挪盒）" % [pt, rect])
	for room in _kind_nodes(model, ROOM_GD):
		var rl := float(room.props.get("offset_left", "0"))
		var rt := float(room.props.get("offset_top", "0"))
		var rr := float(room.props.get("offset_right", "0"))
		var rb := float(room.props.get("offset_bottom", "0"))
		if rr > rect.end.x + 0.5 or rl < rect.position.x - 0.5 \
				or rb > rect.end.y + 0.5 or rt < rect.position.y - 0.5:
			print("NOTICE: R13黄 房 %s 矩形越出盒界（锁房全景时越界处可见不可走，雷 l）" % room.full)
```

- [ ] **Step 3: 复跑 fixtures 全绿 + 默认模式盘点**

```bash
godot --headless --path . -s tools/stage_validator/validator.gd -- --fixtures
godot --headless --path . -s tools/stage_validator/validator.gd
```

Expected：fixtures `RESULT: ... 违例 0`；默认模式 **ref/demo 现有段零新红**（`no_room_band` 等绿）。**注意**：孤儿生成器上线后若 `scenes/stages/**` 存量真红（历史 spawner 没被检测器引用），属真死锁存量——修复文件本体（补引用路径），不许豁免不许改法（spec §七.2）。

- [ ] **Step 4: 九个 fixtures**（`tools/stage_validator/fixtures/`；骨架先 `read` 现存的 `r4_detector_empty_paths.tscn` 与 `r9_shared_spawner.tscn` 抄其 spawner/SD 子资源形制；每文件首行头属性 `expect="..."`；根形=段（script stage_content.gd + `segment_id = &"fx_*"`））

| 文件 | 结构与触发（判据自洽：不夹带他规——spawner 一律带合法 R5 四级路径与 R6 真 enemy_scene=ExtResource spar_enemy，detector 一律三掩码形不触发他规） |
|---|---|
| `box_ok_seg.tscn` | 盒（-200..800 × -200..300，缺省 anchors）+entry (0,100) 盒内；无三件套 → expect=none |
| `box_double.tscn` | 两个 PlayfieldBox 节点（name 异）→ expect=R13 |
| `box_anchored.tscn` | 单盒+`anchor_left = 1.0` 行 → expect=R13 |
| `box_entry_outside.tscn` | 单盒+`entry_points = {&"default": Vector2(3000, 600)}` → expect=R13 |
| `no_room_band.tscn` | 检测器（无 path_fight_room 行，`paths_enemy_spawners=[NodePath("../EnemySpawner1")]`）+生成器1 → **expect=none（房 demotion 核心绿判例）** |
| `dumb_detector.tscn` | 孤立检测器（两路皆空）→ expect=R4 |
| `orphan_spawner.tscn` | 孤立生成器（无任何检测器）→ expect=R4 |
| `room_untriggered.tscn` | 房（子树仅生成器）+段根检测器引用该生成器 → expect=none（NOTICE 不计） |
| `shared_spawner_no_room.tscn` | 段根两检测器共引同一生成器 → expect=R9 |

- [ ] **Step 5: 提交**

```bash
git add tools/stage_validator/validator.gd tools/stage_validator/fixtures/
git commit -m 'feat: 盒轨搭建批 T2 校验器修法——R3 降黄（纯特写房合法）、R4 拆形状核对改接线核对（哑检测器红+孤儿生成器红=真死锁补防）、R9 去房化、新立 R13 盒轨（唯一/坐标系/入口在盒/房越盒黄）+九 fixtures；R8 术前红据归档（旧法拦遭遇带铁证）；默认模式存量盘点零红'
```

---

### Task 3: 段模板 v2（盒+双形态示范）+ 契约 F 腿

**Files:**
- Modify: `scenes/chapter/segment_template.tscn`（整文件重写）
- Modify: `tools/box_contract/box_contract.gd`（追加 F 腿+EXPECTED 终账）

- [ ] **Step 1: 重写模板（全文，先备份 `cp` 到 /tmp/opencode/box_batch/template_v1.bak）**

结构=（ext 7：stage_content/spar_enemy/fight_room/det/spawner/sd/playfield_box；sub 4：Seg_room1/SD_w1/Seg_enc/SD_w2 → `load_steps=12`）：

- 根 `StageSegment`（script=stage_content）`metadata/_assembly_notes` 重写为：**"盒轨段样板（法源 spec 2026-10-07-playfield-box + 法典条 17）：①第一件=拖 PlayfieldBox 框（=可移动区闭区间，anchors 勿动，offset 即段局部坐标）②盒内摆家具（房=可选特写/锁战；遭遇带=无房刷怪合法形；触发件/NPC/宝箱平级）③必改 segment_id；入口默认 (500,600) 须落盒内。墙带由盒运行时派生（手摆场地几何=新段禁用，旧段兼容）。红线：段内禁壳件；生成器 path_spawn_parent 恒四级；检测器三掩码配方；改完 validator+冒烟+F5 三件套。过场段：删两件留盒+auto_complete=true。"**
- `PlayfieldBox`（type=ReferenceRect，script=box ext）`offset_left = -80.0 offset_top = -280.0 offset_right = 2000.0 offset_bottom = 600.0`（范本=旧 GroundBody 南界 600 与检测线 -280 的忠实替身；entry 默认 (500,600) 落界线上合规）。
- `Room1` 及子 `EnemySpawner1/PlayerDetector/Shape`：**原样保留 v1 数值**（房矩形 -280..1200 会触发 R13④ 房越盒黄——**收进盒**：`offset_bottom/limit_bottom/after_fight_limit_bottom` 由 1200 改 **600**，`after_fight_limit_right` 1900 保留<2000 ✓ 黄警告消除）。
- `Encounter1`（type=Area2D，script=det，`position = Vector2(1580, 160)`，三掩码配方行照抄 v1 检测器，**无 path_fight_room 行**，`paths_enemy_spawners = Array[NodePath]([NodePath("../EnemySpawner2")])`）+子 `Shape`（Seg_enc：`a = Vector2(0, -400) b = Vector2(0, 440)`）。
- `EnemySpawner2`（Marker2D 直挂段根，`position = Vector2(1750, 480)`，四级 spawn_parent，`spawn_waves = [[SubResource("SD_w2")]]`，SD_w2=同 spar_enemy 形制）。
- `VisEncLine`（Polygon2D 触发带色块 x=1580 竖条，抄 v1 VisTriggerLine 形制改坐标）。
- `VisSign`（Label 文案改 `"SEG TEMPLATE v2 —— 先拖盒，再摆家具"`）。
- **删除** v1 的 `GroundBody/WallL/WallR` 三节点与 `Rect_ground/Rect_wall` 两 sub、`VisFloor/VisWallL/VisWallR`（盒派生接管）。

- [ ] **Step 2: box_contract 追加 F 腿**（模板结构冒烟）

在 E 腿后、完成旗前插：

```gdscript
	# ── F：模板 v2 结构冒烟（手改 tscn 判例防线：解析错/吞属性当场现形）──
	var tpl := load("res://scenes/chapter/segment_template.tscn") as PackedScene
	_check(tpl != null, "F1 模板可实例化（零 Parse Error 族）")
	if tpl != null:
		var seg := tpl.instantiate()
		add_child(seg)
		await _frames(2)
		var box := seg.get_node_or_null(^"PlayfieldBox")
		_check(box != null and box.is_in_group(&"playfield_box"), "F2 盒在位且运行时生带")
		_check(box != null and box.get_node_or_null(^"BandSouth") != null, "F3 四带派生")
		var enc := seg.get_node_or_null(^"Encounter1")
		_check(enc != null and str(enc.get("path_fight_room")) == "", "F4 遭遇带无房合法形")
		_check(seg.get_node_or_null(^"Room1/PlayerDetector") != null \
				and seg.get_node_or_null(^"GroundBody") == null, "F5 锁房件在位/旧几何已退")
		seg.queue_free()
		await _frames(3)
```

EXPECTED 门同步改 18→23。

- [ ] **Step 3: 验证三件套**

```bash
godot --headless --path . -s tools/stage_validator/validator.gd -- --fixtures | tail -1
bash tools/matrix_runner/run_matrix.sh --ensure-only
timeout 500 godot --headless --path . res://tools/box_contract/box_contract.tscn 2>&1 | tail -3
```

Expected：fixtures 违例 0；box-contract `PASS 断言 23 红 0`。（模板在 `scenes/chapter/`，validator 默认扫 `scenes/stages/` 不吞它——F 腿就是它的场景级执法。）

- [ ] **Step 4: 提交**

```bash
git add scenes/chapter/segment_template.tscn tools/box_contract/box_contract.gd
git commit -m 'feat: 盒轨搭建批 T3 段模板 v2——PlayfieldBox 第一件+锁房三件套（收界进盒）+无房遭遇带双形态示范；GroundBody/WallL/WallR 手摆几何退役；box_contract F 腿模板冒烟（23 断言）'
```

---

### Task 4: 文档口径重写（法典/GUIDE/AGENTS/STATUS/spec 状态）

**Files:**
- Modify: `docs/STAGE_ASSEMBLY.md`、`docs/guides/GUIDE_关卡搭建.md`、`DEVELOPMENT_STATUS.md`、根 `AGENTS.md`（git 外，照改）、spec 状态行
- **不动**：`docs/PLUGIN_ARCHITECTURE.md`、根 `PLUGIN_CHANGES.md`（零插件改动——两文件头各查一眼确认无需条目）

- [ ] **Step 1: STAGE_ASSEMBLY**：0.2 步 4 改盒叙事（旧形手摆地墙=兼容通道标注）；0.3 增**遭遇带字段卡**（检测器无房+spawner 直挂段根+四级路径+三掩码）；第一章条 4 末尾补"房 demotion 见条 17"；新增条 17 全文（照 spec §三 R13 四点+§一两行 demotion 法理："只罚机械死锁/静默失败，不罚配方形状"）；雷区增 k/l（照 spec §五）；0.4/0.5 涉及"复制改件"处补一行新段用 v2 模板。
- [ ] **Step 2: GUIDE_关卡搭建**：L82-84 场地件表重写（盒行=拖框；GroundBody 三行并入"旧形兼容"注）；新增**盒配方卡**（三步：拖盒→摆家具→查黄）；ShadowRegion 条目标注"**默认不摆**：无区域=全区域生成（现行回退机制），盒即视觉边界；仅性能收口/局部去影才摆"；排障表"走路被弹开+掉血"行拆旧形/新形两口径（新形查盒框与 band_depth，不查文件配方——运行时派生改不回）。
- [ ] **Step 3: AGENTS.md**：Stage Structure 图 `地面/墙 StaticBody（layer=16760832 mask=0）` 行替换为 `PlayfieldBox（拖框=可移动区；墙带运行时派生）`；矩阵计数 32 套=33 跑→**33 套=34 跑**（runner 列表补 box_contract）。
- [ ] **Step 4: DEVELOPMENT_STATUS** 新批条目（交付物/契约/红据路径/F5 待验）；spec 头状态"待用户审阅"→"**已批准 2026-10-07**"。
- [ ] **Step 5: 提交** `git add docs/STAGE_ASSEMBLY.md docs/guides/GUIDE_关卡搭建.md DEVELOPMENT_STATUS.md docs/superpowers/specs/2026-10-07-playfield-box-design.md`（AGENTS.md 在根仓库外无 git；PLUGIN_CHANGES 根目录无 git）：commit `docs: 盒轨搭建批法典/GUIDE/STATUS 口径重写——条17 只罚死锁不罚形状、遭遇带字段卡、雷 k/l、盒配方卡、ShadowRegion 默认不摆、矩阵 34 跑计数`

---

### Task 5: 终核全矩阵 + 交付

- [ ] **Step 1: 全矩阵**

```bash
bash tools/matrix_runner/run_matrix.sh 2>&1 | tee /tmp/opencode/box_batch/matrix_final.log | tail -5
```

Expected：`红套数：0`（33 套=34 跑）。任何红→走故障处置判断链（根因/确证/影响面/动手），禁盲改。

- [ ] **Step 2: push + 报告 + F5 验收单**

报告含：R8 两份红据路径、存量盘点结果（若 chapter 存量修复要单列）、"默认已裁"无新增。**F5 验收单（用户，唯一实机项）**：在 `xuanyuan-chapter-1`（或临时复制 v2 模板摆一段）——①拖盒框→走四界（上下界观感=法典雷 k 说明：常态由相机带决定、盒南北墙视野外属正常）②遭遇带形态：走过绿触发带怪冒出且**镜头不锁**、可边打边撤③锁房形态照旧④新段黄警告（编辑器盒上配置警告/validator NOTICE）读一遍确认"报错即教学"。

---

## 自审记录（writing-plans 三查）

1. Spec 覆盖：G1=T1，G2=T2，G3=T3，G4=T4，G5=T1/T2 R8+T5；非目标未混入任务 ✓（纯特写房解锁、旧段迁移、盒房统一派生、全家具在盒硬查——均无实现步骤）。§七 验收四项→T2 Step3 盘点/T3 F 腿/T5 矩阵/T5 F5。
2. 占位符：T2 Step1 heredoc 为示意（红据操作细节留执行者按红档判据自行注释，判据已给全）；其余代码均全文。
3. 类型一致：`PlayfieldBox` 组名 `&"playfield_box"`、带名 `Band*`、fixture 段根 script、R13 常量 `PLAYBOX_GD="playfield_box.gd"`（`_script_path_of().ends_with()` 匹配模式与 ROOM_GD 等既有常量同族 ✓）；EXPECTED 18→23 两处同步标注 ✓。
