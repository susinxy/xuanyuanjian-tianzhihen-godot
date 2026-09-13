@tool
extends VBoxContainer
## 高度层扫描工具 Widget
##
## 提供的 Inspector UI：
## - "扫描并生成高度轨道" 按钮
## - 状态/错误信息显示
## - 扫描结果预览（动画数量、帧数量、错误数量）
##
## 工作流程：
## 1. 用户选择皮肤节点（QuiverCharacterSkinAnimTree）时，此 Widget 出现
## 2. 点击按钮触发扫描
## 3. Widget 调用 AnimationTrackInjector 执行：
##    a. 从 AnimatedSprite2D.sprite_frames 读取帧 → 文件名
##    b. 解析文件名 → CharacterHeightData
##    c. 注入 value tracks / method tracks 到 Animation 资源
##    d. 保存 .tres 文件
## 4. 显示扫描结果
##
## 注：轮廓转换为长任务，实际协程跑在常驻的 ContourConversionRunner 上
## （widget 会被 EditorInspector 每次重解析 memdelete，见 runner 脚本头注释）

### Member Variables and Dependencies -------------------------------------------------------------

const AnimationTrackInjector = preload(
	"res://addons/quiver.beat_em_up/custom_inspectors/height_layers/"
	+ "animation_track_injector.gd"
)

## 用 const preload 而非全局类名引用：不依赖 class_name 缓存重建时机，
## 新文件经 Syncthing 同步到另一台机器后首启即编译，不报"找不到类"
const ContourConversionRunner = preload(
	"res://addons/quiver.beat_em_up/custom_inspectors/height_layers/"
	+ "contour_conversion_runner.gd"
)

const PngScaleTool = preload(
	"res://addons/quiver.beat_em_up/custom_inspectors/height_layers/"
	+ "png_scale_tool.gd"
)

# 持久化文件路径（跨 widget 重建）
static var _persisted_preview_file_path: String = ""

# 持久化转换参数（跨 widget 重建）
static var _persisted_alpha_threshold: float = 0.5
static var _persisted_simplify_tolerance: float = 100.0
static var _persisted_min_area_ratio: float = 0.3
static var _persisted_erosion_radius: int = 0
static var _persisted_shape_type: int = 0
# ShadowBox 专用参数（持久化）
# 简化容差比 body 更小 = 更多顶点 = 阴影轮廓更精细
# 最小面积比比 body 更小 = 保留更多小碎片
static var _persisted_shadow_simplify_tolerance: float = 20.0
static var _persisted_shadow_min_area_ratio: float = 0.2

var _skin_node: Node = null
var _show_body_button: bool = true

# 轮廓转换 UI
var _body_contour_btn: Button
var _attack_contour_btn: Button
var _contour_status_label: Label
var _contour_result_label: RichTextLabel
# PNG 缩放与备份 UI
var _scale_source_edit: LineEdit
var _scale_backup_edit: LineEdit
var _scale_factor_spin: SpinBox
var _scale_reclaim_check: CheckBox
var _scale_apply_btn: Button
var _scale_restore_btn: Button
var _scale_result_label: Label
var _pending_scale_args: Dictionary = {}
var _pending_cleanup: Dictionary = {}
var _shape_type_option: OptionButton
var _alpha_threshold_spinbox: SpinBox
var _simplify_tolerance_spinbox: SpinBox
var _min_area_ratio_spinbox: SpinBox
var _erosion_radius_spinbox: SpinBox
# ShadowBox 专用参数 UI（仅 Body 轮廓转换使用）
var _shadow_simplify_tolerance_spinbox: SpinBox
var _shadow_min_area_ratio_spinbox: SpinBox

# 预览区域 UI
var _preview_file_path: LineEdit
var _preview_file_select_btn: Button
var _preview_contour_btn: Button
var _preview_mask_btn: Button
var _preview_mabr_test_btn: Button
var _preview_result_label: RichTextLabel
# .no.png 豁免标记辅助 UI
var _marker_type_option: OptionButton
var _marker_create_btn: Button
var _marker_delete_btn: Button
var _marker_state_label: Label
var _cleanup_btn: Button
var _preview_texture: TextureRect
var _preview_texture_attack: TextureRect

# 预览区域专用参数 UI
var _preview_alpha_threshold_spinbox: SpinBox
var _preview_simplify_tolerance_spinbox: SpinBox
var _preview_min_area_ratio_spinbox: SpinBox
var _preview_erosion_radius_spinbox: SpinBox

### -----------------------------------------------------------------------------------------------


### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	_build_ui()
	
	# 恢复持久化的文件路径
	if not _persisted_preview_file_path.is_empty():
		_preview_file_path.text = _persisted_preview_file_path
		_preview_contour_btn.disabled = false
		_preview_mask_btn.disabled = false
		_refresh_marker_state()
	
	# 恢复持久化的转换参数
	_alpha_threshold_spinbox.value = _persisted_alpha_threshold
	_simplify_tolerance_spinbox.value = _persisted_simplify_tolerance
	_min_area_ratio_spinbox.value = _persisted_min_area_ratio
	_erosion_radius_spinbox.value = _persisted_erosion_radius
	_shape_type_option.selected = _persisted_shape_type
	_shadow_simplify_tolerance_spinbox.value = _persisted_shadow_simplify_tolerance
	_shadow_min_area_ratio_spinbox.value = _persisted_shadow_min_area_ratio
	
	# 订阅常驻 runner 状态：widget 每次被 Inspector 销毁重建后，
	# 从 runner 恢复"运行中进度 / 上次结果"文字（不再被刷新冲掉）
	var runner := ContourConversionRunner.get_or_create()
	if runner != null:
		QuiverEditorHelper.connect_between(runner.progress_updated, _refresh_from_runner)
		QuiverEditorHelper.connect_between(runner.run_finished, _refresh_from_runner)
		_refresh_from_runner()
	
	# set_skin_node 可能先于 _ready 发生（进入树后才构建 UI）→ 此处补预填
	if _skin_node != null:
		_prefill_scale_dirs(_skin_node)


### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## 由 inspector_plugin 调用，传入皮肤节点引用
func set_skin_node(skin_node: Node) -> void:
	_skin_node = skin_node
	# UI 尚未构建时（_ready 晚于本调用），预填延迟到 _ready 尾部
	if _scale_source_edit != null:
		_prefill_scale_dirs(skin_node)


## 法术模式：隐藏 Body 按钮（法术不需要身体轮廓转换）
func hide_body_button() -> void:
	_show_body_button = false


### Private Methods -------------------------------------------------------------------------------

func _build_ui() -> void:
	# 预览区域
	_build_preview_ui()
	
	# === 轮廓多边形转换区域 ===
	add_child(HSeparator.new())
	
	var contour_header := Label.new()
	contour_header.text = "🔷 轮廓多边形转换"
	contour_header.add_theme_font_size_override("font_size", 16)
	add_child(contour_header)
	
	var contour_desc := Label.new()
	contour_desc.text = "从 PNG 提取轮廓，生成精确碰撞多边形。\n" + \
						"Body: 替换 HurtShape，计算 physical_height\n" + \
						"Attack: 替换 AttackShape，计算 attack_heights"
	contour_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	contour_desc.add_theme_color_override("font_color", Color.GRAY)
	add_child(contour_desc)
	
	# 参数行
	var param_container := VBoxContainer.new()
	add_child(param_container)
	
	# Alpha 阈值
	var alpha_row := HBoxContainer.new()
	param_container.add_child(alpha_row)
	var alpha_label := Label.new()
	alpha_label.text = "Alpha 阈值:"
	alpha_label.custom_minimum_size.x = 80
	alpha_row.add_child(alpha_label)
	_alpha_threshold_spinbox = SpinBox.new()
	_alpha_threshold_spinbox.min_value = 0.0
	_alpha_threshold_spinbox.max_value = 1.0
	_alpha_threshold_spinbox.step = 0.1
	_alpha_threshold_spinbox.value = 0.5
	_alpha_threshold_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alpha_row.add_child(_alpha_threshold_spinbox)
	
	# 简化容差
	var tolerance_row := HBoxContainer.new()
	param_container.add_child(tolerance_row)
	var tolerance_label := Label.new()
	tolerance_label.text = "简化容差:"
	tolerance_label.custom_minimum_size.x = 80
	tolerance_row.add_child(tolerance_label)
	_simplify_tolerance_spinbox = SpinBox.new()
	_simplify_tolerance_spinbox.min_value = 0.0
	_simplify_tolerance_spinbox.max_value = 256.0
	_simplify_tolerance_spinbox.step = 0.5
	_simplify_tolerance_spinbox.value = 100.0
	_simplify_tolerance_spinbox.suffix = " px"
	_simplify_tolerance_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tolerance_row.add_child(_simplify_tolerance_spinbox)
	
	# 最小面积比例
	var area_ratio_row := HBoxContainer.new()
	param_container.add_child(area_ratio_row)
	var area_ratio_label := Label.new()
	area_ratio_label.text = "最小面积比例:"
	area_ratio_label.custom_minimum_size.x = 80
	area_ratio_row.add_child(area_ratio_label)
	_min_area_ratio_spinbox = SpinBox.new()
	_min_area_ratio_spinbox.min_value = 0.1
	_min_area_ratio_spinbox.max_value = 0.8
	_min_area_ratio_spinbox.step = 0.05
	_min_area_ratio_spinbox.value = 0.3
	_min_area_ratio_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area_ratio_row.add_child(_min_area_ratio_spinbox)
	
	# 碰撞形状类型
	var shape_row := HBoxContainer.new()
	param_container.add_child(shape_row)
	var shape_label := Label.new()
	shape_label.text = "碰撞形状:"
	shape_label.custom_minimum_size.x = 80
	shape_row.add_child(shape_label)
	_shape_type_option = OptionButton.new()
	_shape_type_option.add_item("Polygon", AnimationTrackInjector.ShapeType.POLYGON)
	_shape_type_option.add_item("Capsule", AnimationTrackInjector.ShapeType.CAPSULE)
	_shape_type_option.add_item("Rectangle", AnimationTrackInjector.ShapeType.RECTANGLE)
	_shape_type_option.selected = 0
	_shape_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shape_type_option.item_selected.connect(_on_shape_type_changed)
	shape_row.add_child(_shape_type_option)
	
	# 腐蚀半径（仅影响 MABR/Capsule/Rectangle）
	var erosion_row := HBoxContainer.new()
	param_container.add_child(erosion_row)
	var erosion_label := Label.new()
	erosion_label.text = "腐蚀半径:"
	erosion_label.custom_minimum_size.x = 80
	erosion_row.add_child(erosion_label)
	_erosion_radius_spinbox = SpinBox.new()
	_erosion_radius_spinbox.min_value = 0
	_erosion_radius_spinbox.max_value = 100
	_erosion_radius_spinbox.step = 1
	_erosion_radius_spinbox.value = 0
	_erosion_radius_spinbox.suffix = " px"
	_erosion_radius_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	erosion_row.add_child(_erosion_radius_spinbox)
	var erosion_hint := Label.new()
	erosion_hint.text = "(仅 MABR)"
	erosion_hint.add_theme_color_override("font_color", Color.GRAY)
	erosion_row.add_child(erosion_hint)
	
	# ShadowBox 参数标题（仅 Body 转换使用）
	var shadow_param_label := Label.new()
	shadow_param_label.text = "ShadowBox 参数（仅 Body）"
	shadow_param_label.add_theme_color_override("font_color", Color.GRAY)
	param_container.add_child(shadow_param_label)
	
	# ShadowBox 简化容差
	var shadow_tolerance_row := HBoxContainer.new()
	param_container.add_child(shadow_tolerance_row)
	var shadow_tolerance_label := Label.new()
	shadow_tolerance_label.text = "阴影简化容差:"
	shadow_tolerance_label.custom_minimum_size.x = 80
	shadow_tolerance_row.add_child(shadow_tolerance_label)
	_shadow_simplify_tolerance_spinbox = SpinBox.new()
	_shadow_simplify_tolerance_spinbox.min_value = 0.0
	_shadow_simplify_tolerance_spinbox.max_value = 256.0
	_shadow_simplify_tolerance_spinbox.step = 0.5
	_shadow_simplify_tolerance_spinbox.value = 20.0
	_shadow_simplify_tolerance_spinbox.suffix = " px"
	_shadow_simplify_tolerance_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shadow_tolerance_row.add_child(_shadow_simplify_tolerance_spinbox)
	
	# ShadowBox 最小面积比例
	var shadow_area_ratio_row := HBoxContainer.new()
	param_container.add_child(shadow_area_ratio_row)
	var shadow_area_ratio_label := Label.new()
	shadow_area_ratio_label.text = "阴影最小面积:"
	shadow_area_ratio_label.custom_minimum_size.x = 80
	shadow_area_ratio_row.add_child(shadow_area_ratio_label)
	_shadow_min_area_ratio_spinbox = SpinBox.new()
	_shadow_min_area_ratio_spinbox.min_value = 0.1
	_shadow_min_area_ratio_spinbox.max_value = 0.8
	_shadow_min_area_ratio_spinbox.step = 0.05
	_shadow_min_area_ratio_spinbox.value = 0.2
	_shadow_min_area_ratio_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shadow_area_ratio_row.add_child(_shadow_min_area_ratio_spinbox)
	
	# 按钮容器
	var contour_btn_container := HBoxContainer.new()
	add_child(contour_btn_container)
	
	_body_contour_btn = Button.new()
	_body_contour_btn.text = "🏃 Body 轮廓转换"
	_body_contour_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_contour_btn.pressed.connect(_on_body_contour_pressed)
	contour_btn_container.add_child(_body_contour_btn)
	
	_attack_contour_btn = Button.new()
	_attack_contour_btn.text = "⚔ Attack 轮廓转换"
	_attack_contour_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attack_contour_btn.pressed.connect(_on_attack_contour_pressed)
	contour_btn_container.add_child(_attack_contour_btn)
	
	_cleanup_btn = Button.new()
	_cleanup_btn.text = "🧹 清理非法注入的攻击数据"
	_cleanup_btn.tooltip_text = "按开盒声明标准删除历史误注入的轨道（形状 polygon/position/rotation、跟随位置、显隐、attack_heights）；手写轨道不碰。执行前显示预览清单确认"
	_cleanup_btn.pressed.connect(_on_cleanup_pressed)
	add_child(_cleanup_btn)
	
	# 轮廓转换状态
	_contour_status_label = Label.new()
	_contour_status_label.text = "就绪"
	_contour_status_label.add_theme_color_override("font_color", Color.GRAY)
	add_child(_contour_status_label)
	
	# 轮廓转换结果
	_contour_result_label = RichTextLabel.new()
	_contour_result_label.bbcode_enabled = true
	_contour_result_label.text = ""
	_contour_result_label.custom_minimum_size = Vector2(0, 100)
	add_child(_contour_result_label)
	
	_build_png_scale_ui()
	
	# 法术模式：禁用 Body 按钮
	if not _show_body_button:
		_body_contour_btn.disabled = true
		_body_contour_btn.tooltip_text = "法术不需要 Body 轮廓转换"


### PNG 缩放与备份 ------------------------------------------------------------------

## 构建"PNG 缩放与备份"区块（纯资产层工具：缩放写盘 + 备份只认第一次）
func _build_png_scale_ui() -> void:
	add_child(_make_separator())
	
	var title := Label.new()
	title.text = "PNG 缩放与备份（资产层，缩放后需重跑两类轮廓转换）"
	title.add_theme_font_size_override("font_size", 14)
	add_child(title)
	
	_scale_source_edit = LineEdit.new()
	_scale_source_edit.placeholder_text = "源目录 res://..."
	_scale_source_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_scale_source_edit)
	
	_scale_backup_edit = LineEdit.new()
	_scale_backup_edit.placeholder_text = "备份目录 res://...（首次执行自动采集原图）"
	_scale_backup_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_scale_backup_edit)
	
	var factor_row := HBoxContainer.new()
	factor_row.add_child(_make_label("缩放系数:"))
	_scale_factor_spin = SpinBox.new()
	_scale_factor_spin.min_value = 0.05
	_scale_factor_spin.max_value = 4.0
	_scale_factor_spin.step = 0.05
	_scale_factor_spin.value = 0.55
	_scale_factor_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	factor_row.add_child(_scale_factor_spin)
	_scale_reclaim_check = CheckBox.new()
	_scale_reclaim_check.text = "以当前图重新采集原底"
	_scale_reclaim_check.tooltip_text = "逃生门：忽略账本判定，把源目录当前内容整体立为新原底（不可逆，执行前弹确认）。日常增删改原画不需要它——直接点执行缩放，账本逐文件自动识别"
	factor_row.add_child(_scale_reclaim_check)
	add_child(factor_row)
	
	var btn_row := HBoxContainer.new()
	_scale_apply_btn = Button.new()
	_scale_apply_btn.text = "🖼 执行缩放"
	_scale_apply_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scale_apply_btn.pressed.connect(_on_scale_apply_pressed)
	btn_row.add_child(_scale_apply_btn)
	_scale_restore_btn = Button.new()
	_scale_restore_btn.text = "↩ 恢复原图"
	_scale_restore_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scale_restore_btn.pressed.connect(_on_scale_restore_pressed)
	btn_row.add_child(_scale_restore_btn)
	add_child(btn_row)
	
	_scale_result_label = Label.new()
	_scale_result_label.text = "就绪"
	_scale_result_label.add_theme_color_override("font_color", Color.GRAY)
	_scale_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_scale_result_label)


## 选中皮肤节点时，从场景路径反推源/备份目录（可手动改）
func _prefill_scale_dirs(skin_node: Node) -> void:
	var scene_path := skin_node.scene_file_path
	if scene_path.is_empty():
		return
	var char_dir := scene_path.get_base_dir()
	_scale_source_edit.text = char_dir.path_join("resources/sprites")
	_scale_backup_edit.text = char_dir.path_join("resources/sprites_master")


func _on_scale_apply_pressed() -> void:
	_dispatch_scale("scale")


func _on_scale_restore_pressed() -> void:
	_dispatch_scale("restore")


## 路径校验后投递给常驻 runner（分帧执行，见 contour_conversion_runner.gd）。
## 两道不可逆操作前置确认：逃生门（全量换底，弹窗含"疑似印品"计数）、恢复原图（复活孤儿计数）
func _dispatch_scale(scale_mode: String) -> void:
	var source_dir := _scale_source_edit.text.strip_edges().trim_suffix("/")
	var backup_dir := _scale_backup_edit.text.strip_edges().trim_suffix("/")
	if source_dir.is_empty() or backup_dir.is_empty():
		_scale_result_label.text = "❌ 源目录/备份目录不能为空"
		return
	if backup_dir == source_dir or backup_dir.begins_with(source_dir + "/"):
		_scale_result_label.text = "❌ 备份目录不能在源目录内部或与其相同（兄弟目录如 sprites_master/ 是合法的）"
		return
	if scale_mode == "scale" and _scale_reclaim_check.button_pressed:
		var preview: Dictionary = PngScaleTool.preview_actions(source_dir, backup_dir, _scale_factor_spin.value)
		_confirm_then_start(
			"⚠️ 逃生门已勾选：将用源目录当前内容【整体覆盖】备份原底。\n"
			+ "其中 %d 个文件与账本吻合（疑似缩小图），其原底会被不可逆替换。\n" % preview.reprinted
			+ "仅在你确定源目录全部是原画时使用。确认执行？",
			{"mode": scale_mode, "src": source_dir, "bak": backup_dir}
		)
		return
	if scale_mode == "restore":
		var orphans: int = PngScaleTool.count_orphans(
			ProjectSettings.globalize_path(source_dir), ProjectSettings.globalize_path(backup_dir)
		)
		if orphans > 0:
			_confirm_then_start(
				"备份中有 %d 个文件在源目录已不存在（多半是被你删除的美术）。\n" % orphans
				+ "恢复将把它们复活回源目录。确认执行？",
				{"mode": scale_mode, "src": source_dir, "bak": backup_dir}
			)
			return
	_start_scale_job(scale_mode, source_dir, backup_dir)


func _confirm_then_start(text: String, args: Dictionary) -> void:
	_pending_scale_args = args
	var dlg := ConfirmationDialog.new()
	dlg.dialog_text = text
	dlg.title = "确认操作"
	add_child(dlg)
	dlg.confirmed.connect(_on_confirm_scale_confirmed)
	dlg.popup_centered()


func _on_confirm_scale_confirmed() -> void:
	if _pending_scale_args.is_empty():
		return
	var a := _pending_scale_args
	_pending_scale_args = {}
	_start_scale_job(a["mode"], a["src"], a["bak"])


func _start_scale_job(scale_mode: String, source_dir: String, backup_dir: String) -> void:
	var runner := ContourConversionRunner.get_or_create()
	if runner == null or runner.is_running:
		return
	runner.start_scale(scale_mode, source_dir, backup_dir, _scale_factor_spin.value, _scale_reclaim_check.button_pressed)


func _make_separator() -> HSeparator:
	return HSeparator.new()


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


## 从常驻 runner 刷新状态/结果/按钮（widget 重建后恢复 + 运行中实时跟随）
## 轮廓转换与 PNG 缩放共用同一 runner，按 job_kind 分流显示；互斥体现在四按钮全禁
func _refresh_from_runner() -> void:
	var runner := ContourConversionRunner.peek()
	if runner == null or _contour_status_label == null:
		return
	if runner.is_running:
		var text := runner.progress_text if not runner.progress_text.is_empty() else runner.status_text
		if runner.job_kind == "scale":
			_scale_result_label.text = text
			_scale_result_label.add_theme_color_override("font_color", Color.CYAN)
		else:
			_contour_status_label.text = text
			_contour_status_label.add_theme_color_override("font_color", Color.CYAN)
			if not runner.result_text.is_empty():
				_contour_result_label.text = runner.result_text
		_body_contour_btn.disabled = true
		_attack_contour_btn.disabled = true
		_scale_apply_btn.disabled = true
		_scale_restore_btn.disabled = true
		_cleanup_btn.disabled = true
	else:
		if runner.job_kind == "scale":
			if not runner.status_text.is_empty():
				_scale_result_label.text = runner.status_text
				_scale_result_label.add_theme_color_override("font_color", runner.status_color)
		else:
			if not runner.status_text.is_empty():
				_contour_status_label.text = runner.status_text
				_contour_status_label.add_theme_color_override("font_color", runner.status_color)
			if not runner.result_text.is_empty():
				_contour_result_label.text = runner.result_text
		# 恢复按钮状态（法术模式下 Body 保持禁用）
		_body_contour_btn.disabled = not _show_body_button
		_attack_contour_btn.disabled = false
		_scale_apply_btn.disabled = false
		_scale_restore_btn.disabled = false
		_cleanup_btn.disabled = false


## 碰撞形状类型切换时设置默认参数
func _on_shape_type_changed(index: int) -> void:
	match index:
		AnimationTrackInjector.ShapeType.POLYGON:
			_erosion_radius_spinbox.value = 0
			_simplify_tolerance_spinbox.value = 100.0
		AnimationTrackInjector.ShapeType.CAPSULE, AnimationTrackInjector.ShapeType.RECTANGLE:
			_erosion_radius_spinbox.value = 20
			_simplify_tolerance_spinbox.value = 5.0


func _on_body_contour_pressed() -> void:
	_start_conversion("body")


func _on_attack_contour_pressed() -> void:
	_start_conversion("attack")


## 收集当前 UI 参数并持久化，交给常驻 runner 执行
## （协程不在 widget 内跑：切页销毁 widget 不影响转换与进度显示）
func _start_conversion(mode: String) -> void:
	if _skin_node == null:
		return
	var runner := ContourConversionRunner.get_or_create()
	if runner == null or runner.is_running:
		return
	
	_persisted_alpha_threshold = _alpha_threshold_spinbox.value
	_persisted_simplify_tolerance = _simplify_tolerance_spinbox.value
	_persisted_min_area_ratio = _min_area_ratio_spinbox.value
	_persisted_erosion_radius = int(_erosion_radius_spinbox.value)
	_persisted_shape_type = _shape_type_option.selected
	_persisted_shadow_simplify_tolerance = _shadow_simplify_tolerance_spinbox.value
	_persisted_shadow_min_area_ratio = _shadow_min_area_ratio_spinbox.value
	
	runner.start(mode, _skin_node, {
		"alpha_threshold": _alpha_threshold_spinbox.value,
		"simplify_tolerance": _simplify_tolerance_spinbox.value,
		"min_area_ratio": _min_area_ratio_spinbox.value,
		"erosion_radius": int(_erosion_radius_spinbox.value),
		"shape_type": _shape_type_option.selected,
		"shadow_simplify_tolerance": _shadow_simplify_tolerance_spinbox.value,
		"shadow_min_area_ratio": _shadow_min_area_ratio_spinbox.value,
	})


## 构建单文件测试 UI
func _build_preview_ui() -> void:
	var preview_header := Label.new()
	preview_header.text = "🎨 轮廓预览 & Mask 编辑"
	preview_header.add_theme_font_size_override("font_size", 16)
	add_child(preview_header)
	
	add_child(HSeparator.new())
	
	# 文件选择行
	var file_row := HBoxContainer.new()
	add_child(file_row)
	
	var file_label := Label.new()
	file_label.text = "PNG 文件:"
	file_label.custom_minimum_size.x = 80
	file_row.add_child(file_label)
	
	_preview_file_path = LineEdit.new()
	_preview_file_path.placeholder_text = "选择 PNG 文件..."
	_preview_file_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_file_path.editable = false
	file_row.add_child(_preview_file_path)
	
	_preview_file_select_btn = Button.new()
	_preview_file_select_btn.text = "浏览"
	_preview_file_select_btn.pressed.connect(_on_preview_file_select_btn_pressed)
	file_row.add_child(_preview_file_select_btn)
	
	_build_marker_ui()
	
	# 预览参数区域
	var preview_param_container := VBoxContainer.new()
	add_child(preview_param_container)
	
	var preview_param_label := Label.new()
	preview_param_label.text = "预览参数"
	preview_param_label.add_theme_font_size_override("font_size", 14)
	preview_param_container.add_child(preview_param_label)
	
	# Alpha 阈值
	var preview_alpha_row := HBoxContainer.new()
	preview_param_container.add_child(preview_alpha_row)
	var preview_alpha_label := Label.new()
	preview_alpha_label.text = "Alpha 阈值:"
	preview_alpha_label.custom_minimum_size.x = 80
	preview_alpha_row.add_child(preview_alpha_label)
	_preview_alpha_threshold_spinbox = SpinBox.new()
	_preview_alpha_threshold_spinbox.min_value = 0.0
	_preview_alpha_threshold_spinbox.max_value = 1.0
	_preview_alpha_threshold_spinbox.step = 0.1
	_preview_alpha_threshold_spinbox.value = 0.5
	_preview_alpha_threshold_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_alpha_row.add_child(_preview_alpha_threshold_spinbox)
	
	# 简化容差
	var preview_tolerance_row := HBoxContainer.new()
	preview_param_container.add_child(preview_tolerance_row)
	var preview_tolerance_label := Label.new()
	preview_tolerance_label.text = "简化容差:"
	preview_tolerance_label.custom_minimum_size.x = 80
	preview_tolerance_row.add_child(preview_tolerance_label)
	_preview_simplify_tolerance_spinbox = SpinBox.new()
	_preview_simplify_tolerance_spinbox.min_value = 0.0
	_preview_simplify_tolerance_spinbox.max_value = 256.0
	_preview_simplify_tolerance_spinbox.step = 0.5
	_preview_simplify_tolerance_spinbox.value = 100.0
	_preview_simplify_tolerance_spinbox.suffix = " px"
	_preview_simplify_tolerance_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_tolerance_row.add_child(_preview_simplify_tolerance_spinbox)
	
	# 最小面积比例
	var preview_area_ratio_row := HBoxContainer.new()
	preview_param_container.add_child(preview_area_ratio_row)
	var preview_area_ratio_label := Label.new()
	preview_area_ratio_label.text = "最小面积比例:"
	preview_area_ratio_label.custom_minimum_size.x = 80
	preview_area_ratio_row.add_child(preview_area_ratio_label)
	_preview_min_area_ratio_spinbox = SpinBox.new()
	_preview_min_area_ratio_spinbox.min_value = 0.1
	_preview_min_area_ratio_spinbox.max_value = 0.8
	_preview_min_area_ratio_spinbox.step = 0.05
	_preview_min_area_ratio_spinbox.value = 0.3
	_preview_min_area_ratio_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_area_ratio_row.add_child(_preview_min_area_ratio_spinbox)
	
	# 腐蚀半径
	var preview_erosion_row := HBoxContainer.new()
	preview_param_container.add_child(preview_erosion_row)
	var preview_erosion_label := Label.new()
	preview_erosion_label.text = "腐蚀半径:"
	preview_erosion_label.custom_minimum_size.x = 80
	preview_erosion_row.add_child(preview_erosion_label)
	_preview_erosion_radius_spinbox = SpinBox.new()
	_preview_erosion_radius_spinbox.min_value = 0
	_preview_erosion_radius_spinbox.max_value = 100
	_preview_erosion_radius_spinbox.step = 1
	_preview_erosion_radius_spinbox.value = 0
	_preview_erosion_radius_spinbox.suffix = " px"
	_preview_erosion_radius_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_erosion_row.add_child(_preview_erosion_radius_spinbox)
	var preview_erosion_hint := Label.new()
	preview_erosion_hint.text = "(仅 MABR)"
	preview_erosion_hint.add_theme_color_override("font_color", Color.GRAY)
	preview_erosion_row.add_child(preview_erosion_hint)
	
	# 操作按钮行
	var preview_btn_row := HBoxContainer.new()
	add_child(preview_btn_row)
	
	_preview_contour_btn = Button.new()
	_preview_contour_btn.text = "🔍 预览轮廓"
	_preview_contour_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_contour_btn.disabled = true
	_preview_contour_btn.pressed.connect(_on_preview_contour_pressed)
	preview_btn_row.add_child(_preview_contour_btn)
	
	_preview_mask_btn = Button.new()
	_preview_mask_btn.text = "🎨 编辑 Mask"
	_preview_mask_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_mask_btn.disabled = true
	_preview_mask_btn.pressed.connect(_on_preview_mask_pressed)
	preview_btn_row.add_child(_preview_mask_btn)
	
	_preview_mabr_test_btn = Button.new()
	_preview_mabr_test_btn.text = "🧪 MABR 测试"
	_preview_mabr_test_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_mabr_test_btn.pressed.connect(_on_preview_mabr_test_pressed)
	preview_btn_row.add_child(_preview_mabr_test_btn)
	
	# 结果显示
	_preview_result_label = RichTextLabel.new()
	_preview_result_label.bbcode_enabled = true
	_preview_result_label.text = "[color=gray]选择文件后点击预览按钮[/color]"
	_preview_result_label.custom_minimum_size = Vector2(0, 150)
	add_child(_preview_result_label)
	
	# 轮廓预览图（双栏：左=body 规则，右=attack 规则含高度带）
	var preview_imgs := HBoxContainer.new()
	preview_imgs.add_theme_constant_override("separation", 8)
	add_child(preview_imgs)
	
	var body_col := VBoxContainer.new()
	body_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_imgs.add_child(body_col)
	var body_cap := Label.new()
	body_cap.text = "Body 检测预览"
	body_col.add_child(body_cap)
	_preview_texture = TextureRect.new()
	_preview_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_texture.custom_minimum_size = Vector2(0, 256)
	body_col.add_child(_preview_texture)
	
	var atk_col := VBoxContainer.new()
	atk_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_imgs.add_child(atk_col)
	var atk_cap := Label.new()
	atk_cap.text = "Attack 检测预览（绿带=命中高度层）"
	atk_col.add_child(atk_cap)
	_preview_texture_attack = TextureRect.new()
	_preview_texture_attack.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_preview_texture_attack.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_texture_attack.custom_minimum_size = Vector2(0, 256)
	atk_col.add_child(_preview_texture_attack)
	
	add_child(HSeparator.new())


### 非法注入数据清理 ------------------------------------------------------------------

func _on_cleanup_pressed() -> void:
	if _skin_node == null:
		return
	var runner := ContourConversionRunner.peek()
	if runner != null and runner.is_running:
		return
	var injector := AnimationTrackInjector.new()
	var errors: Array[String] = []
	var anim_player := injector._get_animation_player(_skin_node, errors)
	if anim_player == null:
		_contour_result_label.text = "❌ 未找到 AnimationPlayer，无法清理"
		return
	var shapes: Array = injector._discover_shape_nodes(_skin_node).filter(
		func(n: Dictionary) -> bool: return n["category"] == "attack"
	)
	var dry: Dictionary = injector.cleanup_illegal_attack_data(_skin_node, anim_player, shapes, true)
	var deleted: Array = dry.deleted
	if deleted.is_empty():
		_contour_result_label.text = "[color=green]✅ 无需清理：未发现非法注入数据[/color]"
		return
	var preview := ""
	for i in mini(deleted.size(), 12):
		preview += "  " + str(deleted[i]) + "\n"
	if deleted.size() > 12:
		preview += "  ... 等共 %d 条\n" % deleted.size()
	_pending_cleanup = {
		"injector": injector, "player": anim_player, "shapes": shapes,
	}
	var dlg := ConfirmationDialog.new()
	dlg.title = "清理预览（%d 个动画，共 %d 条轨道）" % [dry.files, deleted.size()]
	dlg.dialog_text = "将删除以下注入产物轨道（手写 :disabled 轨道不碰）：\n" + preview + "\n确认执行？"
	add_child(dlg)
	dlg.confirmed.connect(_on_cleanup_confirmed)
	dlg.popup_centered()


func _on_cleanup_confirmed() -> void:
	if _pending_cleanup.is_empty():
		return
	var injector = _pending_cleanup["injector"]
	var ap = _pending_cleanup["player"]
	var shapes: Array = _pending_cleanup["shapes"]
	_pending_cleanup = {}
	var wet: Dictionary = injector.cleanup_illegal_attack_data(_skin_node, ap, shapes, false)
	var lines := ["[b]清理完成：删除 %d 条轨道（%d 个动画）[/b]" % [(wet.deleted as Array).size(), wet.files]]
	for d in (wet.deleted as Array).slice(0, 20):
		lines.append("  " + str(d))
	if (wet.deleted as Array).size() > 20:
		lines.append("  ...")
	for e in wet.errors:
		lines.append("[color=red]" + str(e) + "[/color]")
	lines.append("")
	lines.append("[color=green]✅ 建议随重跑一次 Attack 轮廓转换[/color]")
	_contour_result_label.text = "\n".join(lines)
	EditorInterface.get_resource_filesystem().scan()


### .no.png 豁免标记辅助 ----------------------------------------------------------

const MARKER_SUFFIXES := ["", ".body", ".attack", ".shadow"]


func _build_marker_ui() -> void:
	var title := Label.new()
	title.text = "跳过检测（轮廓转换时不处理该图的指定检测类别）"
	title.add_theme_font_size_override("font_size", 14)
	add_child(title)
	
	var marker_row := HBoxContainer.new()
	add_child(marker_row)
	var marker_label := Label.new()
	marker_label.text = "类别:"
	marker_label.custom_minimum_size.x = 80
	marker_row.add_child(marker_label)
	_marker_type_option = OptionButton.new()
	_marker_type_option.add_item("跳过全部三类（body+attack+shadow）", 0)
	_marker_type_option.add_item("只跳过 Body（受击框/身高，影子不受影响）", 1)
	_marker_type_option.add_item("只跳过 Attack（挥拳判定框）", 2)
	_marker_type_option.add_item("只跳过 Shadow（影子轮廓，身体不受影响）", 3)
	_marker_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_marker_type_option.item_selected.connect(func(_i: int) -> void: _refresh_marker_state())
	marker_row.add_child(_marker_type_option)
	_marker_create_btn = Button.new()
	_marker_create_btn.text = "⛔ 跳过"
	_marker_create_btn.pressed.connect(_on_marker_create_pressed)
	marker_row.add_child(_marker_create_btn)
	_marker_delete_btn = Button.new()
	_marker_delete_btn.text = "↩️ 恢复检测"
	_marker_delete_btn.pressed.connect(_on_marker_delete_pressed)
	marker_row.add_child(_marker_delete_btn)
	_marker_state_label = Label.new()
	_marker_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_marker_state_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(_marker_state_label)
	
	var info := Label.new()
	info.text = ("「跳过」后，重跑轮廓转换时这张图不再被检测：对应的受击多边形 / 攻击判定 / "
		+ "影子轮廓 / 高度数据都不会为使用它的帧写入关键帧，沿用前面最近一次被检测帧的值。改回后需重跑转换才生效。\n"
		+ "典型场景：某帧画面里有不该算作身体的元素（武器入画、变身特效、道具残影）。"
		+ "若只是「部分不要」而非「整张不要」，应改用旁边的「蒙版编辑」圈定检测区域，而不是这里。\n"
		+ "实现：图片同目录落一个合法小 PNG 文件（如 xxx.shadow.no.png），也可手动创建删除。")
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 11)
	info.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	add_child(info)
	_refresh_marker_state()


func _current_marker_path() -> String:
	var file_path := _preview_file_path.text.strip_edges()
	if file_path.is_empty() or not file_path.ends_with(".png"):
		return ""
	return file_path.replace(".png", "") + MARKER_SUFFIXES[_marker_type_option.get_selected_id()] + ".no.png"


func _refresh_marker_state() -> void:
	if _marker_state_label == null:
		return
	var file_path := _preview_file_path.text.strip_edges()
	if file_path.is_empty():
		_marker_state_label.text = "先在上方「PNG 文件」浏览选择要控制的那张图"
		_marker_create_btn.disabled = true
		_marker_delete_btn.disabled = true
		return
	var base := file_path.replace(".png", "")
	var has_generic := FileAccess.file_exists(base + ".no.png")
	var names := ["Body", "Attack", "Shadow"]
	var suffixes := [".body.no.png", ".attack.no.png", ".shadow.no.png"]
	var parts: Array[String] = []
	for i in 3:
		if FileAccess.file_exists(base + suffixes[i]):
			parts.append(names[i] + " ⛔已跳过")
		elif has_generic:
			parts.append(names[i] + " ⛔已跳过（通用 .no.png）")
		else:
			parts.append(names[i] + " 正常检测")
	_marker_state_label.text = "当前状态: " + " ｜ ".join(parts)
	_marker_create_btn.disabled = false
	_marker_delete_btn.disabled = false


func _on_marker_create_pressed() -> void:
	var marker_path := _current_marker_path()
	if marker_path.is_empty():
		return
	if not FileAccess.file_exists(marker_path):
		# 2×2 不透明合法 PNG——0 字节文件会让导入器报错，故由工具代生成
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 1))
		var err := img.save_png(ProjectSettings.globalize_path(marker_path))
		if err != OK:
			_marker_state_label.text = "❌ 跳过文件创建失败 err=%d" % err
			return
	_refresh_marker_state()


func _on_marker_delete_pressed() -> void:
	var marker_path := _current_marker_path()
	if marker_path.is_empty():
		return
	if FileAccess.file_exists(marker_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(marker_path))
	_refresh_marker_state()


## 预览区域文件选择按钮点击
func _on_preview_file_select_btn_pressed() -> void:
	var file_dialog := FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.filters = ["*.png ; PNG Images"]
	file_dialog.current_dir = "res://characters/playable/"
	
	file_dialog.file_selected.connect(func(path: String):
		_preview_file_path.text = path
		_persisted_preview_file_path = path
		_preview_contour_btn.disabled = false
		_preview_mask_btn.disabled = false
		_refresh_marker_state()
		file_dialog.queue_free()
	)
	
	file_dialog.canceled.connect(func():
		file_dialog.queue_free()
	)
	
	add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(800, 600))


## 预览轮廓按钮点击
func _on_preview_contour_pressed() -> void:
	_run_preview()


## Mask 编辑器按钮点击
func _on_preview_mask_pressed() -> void:
	var file_path := _preview_file_path.text
	if file_path.is_empty():
		return
	
	var MaskEditorDialog = preload("res://addons/quiver.beat_em_up/custom_inspectors/height_layers/mask_editor_dialog.gd")
	var dialog := MaskEditorDialog.new()
	dialog.set_params(_alpha_threshold_spinbox.value, _simplify_tolerance_spinbox.value, _min_area_ratio_spinbox.value)
	add_child(dialog)
	# 母版上下文与缩放面板同源：mask 的权威版认同一个母版目录，不会跑偏
	dialog.set_master_context(_scale_source_edit.text, _scale_backup_edit.text)
	dialog.set_png_path(file_path)
	# 编辑器内换图 → 面板"当前文件"跟随最后一张，免二次浏览
	dialog.file_changed.connect(func(p: String):
		_preview_file_path.text = p
		_persisted_preview_file_path = p
		_refresh_marker_state()
	)
	dialog.popup_centered(Vector2i(1220, 730))
	# AcceptDialog(Window) 没有 closed/popup_hide 信号；用 CanvasItem.visibility_changed
	# 在隐藏后回收，避免每开一次泄漏一个窗口实例
	dialog.visibility_changed.connect(func():
		if not dialog.visible:
			dialog.queue_free()
	)


## MABR 测试按钮点击
func _on_preview_mabr_test_pressed() -> void:
	_preview_mabr_test_btn.disabled = true
	_preview_result_label.text = "[color=cyan]运行 MABR 基础测试...[/color]"
	
	await get_tree().process_frame
	
	var results := ContourTracer.run_mabr_tests()
	
	var lines := []
	lines.append("[b]MABR 基础测试结果[/b]")
	lines.append("")
	for r in results:
		if r.begins_with("✅"):
			lines.append("[color=green]%s[/color]" % r)
		elif r.begins_with("❌"):
			lines.append("[color=red]%s[/color]" % r)
		elif r.begins_with("总计"):
			lines.append("")
			if "0 失败" in r:
				lines.append("[color=green][b]%s[/b][/color]" % r)
			else:
				lines.append("[color=red][b]%s[/b][/color]" % r)
		else:
			lines.append(r)
	
	_preview_result_label.text = "\n".join(lines)
	_preview_mabr_test_btn.disabled = false


## 执行预览
func _run_preview() -> void:
	if _skin_node == null:
		_preview_result_label.text = "[color=red]错误: 未关联皮肤节点[/color]"
		return
	
	var file_path := _preview_file_path.text
	if file_path.is_empty():
		_preview_result_label.text = "[color=red]错误: 未选择文件[/color]"
		return
	
	# 禁用按钮
	_preview_contour_btn.disabled = true
	_preview_result_label.text = "[color=cyan]预览中...[/color]"
	
	# 等待两帧确保 UI 更新
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 获取预览专用参数
	var alpha_threshold: float = _preview_alpha_threshold_spinbox.value
	var simplify_tolerance: float = _preview_simplify_tolerance_spinbox.value
	var min_area_ratio: float = _preview_min_area_ratio_spinbox.value
	var erosion_radius: int = int(_preview_erosion_radius_spinbox.value)
	
	# 执行预览（同一张图分别按 body / attack 规则各算一遍，与转换同源的解析链）
	var injector := AnimationTrackInjector.new()
	var result := injector.preview_single_file(file_path, alpha_threshold, simplify_tolerance, min_area_ratio, erosion_radius, "body")
	var result_attack := injector.preview_single_file(file_path, alpha_threshold, simplify_tolerance, min_area_ratio, erosion_radius, "attack")
	
	# 显示结果（两节报告）
	_display_preview_result(result, result_attack)
	
	# 显示预览图（双栏；右栏叠攻击高度带）
	await _display_preview(result, _preview_texture, false)
	await _display_preview(result_attack, _preview_texture_attack, true)
	
	# 恢复按钮
	_preview_contour_btn.disabled = false


## 显示预览结果
func _display_preview_result(res_body: Dictionary, res_attack: Dictionary) -> void:
	var base: Dictionary = res_body if res_body.error == "" else res_attack
	if base.error != "":
		_preview_result_label.text = "[color=red]错误: %s[/color]" % base.error
		return
	
	var lines := []
	lines.append("[b]文件:[/b] %s    [b]尺寸:[/b] %d × %d" % [base.file_name, base.image_size.x, base.image_size.y])
	lines.append("")
	
	lines.append("[b]── Body 检测 ──[/b]")
	_append_body_section(lines, res_body)
	
	lines.append("")
	lines.append("[b]── Attack 检测 ──[/b]")
	_append_attack_section(lines, res_attack)
	
	_preview_result_label.text = "\n".join(lines)


func _mask_line(r: Dictionary) -> String:
	if r.skipped:
		return "⛔ 本类别已跳过（标记文件: %s）" % r.skip_reason.get_file()
	if r.has_mask:
		return "蒙版: %s" % r.mask_used.get_file()
	return "蒙版: 无（全图检测）"


func _append_body_section(lines: Array, r: Dictionary) -> void:
	lines.append("  " + _mask_line(r))
	if r.skipped:
		return
	if r.error != "":
		lines.append("  [color=red]%s[/color]" % r.error)
		return
	lines.append("  [b]提取轮廓数:[/b] %d   [b]顶点总数:[/b] %d" % [r.contour_count, r.total_vertices])
	lines.append("  [b]physical_height:[/b] %.1f" % r.physical_height)
	lines.append("  [b]坐标范围:[/b] X %.1f~%.1f  Y %.1f~%.1f" % [
		r.bounding_box.position.x, r.bounding_box.position.x + r.bounding_box.size.x,
		r.bounding_box.position.y, r.bounding_box.position.y + r.bounding_box.size.y
	])
	if r.has("mabr") and not r.mabr.is_empty():
		var mabr: Dictionary = r.mabr
		lines.append("  [b]MABR:[/b] %.1f × %.1f @ %.1f°   [b]Capsule:[/b] r=%.1f h=%.1f" % [
			mabr.size.x, mabr.size.y, rad_to_deg(mabr.angle),
			r.capsule.radius if r.has("capsule") and not r.capsule.is_empty() else 0.0,
			r.capsule.height if r.has("capsule") and not r.capsule.is_empty() else 0.0
		])
	lines.append("  [b]参数:[/b] alpha=%.1f, tolerance=%.1f, erosion=%d" % [r.alpha_threshold, r.simplify_tolerance, r.erosion_radius])


func _append_attack_section(lines: Array, r: Dictionary) -> void:
	lines.append("  " + _mask_line(r))
	if r.skipped:
		return
	if r.error != "":
		lines.append("  [color=red]%s[/color]" % r.error)
		return
	lines.append("  [b]提取轮廓数:[/b] %d   [b]顶点总数:[/b] %d" % [r.contour_count, r.total_vertices])
	var heights: Array = r.attack_heights
	if heights.is_empty():
		lines.append("  攻击高度: 无可注入轮廓")
		return
	var defs: Array = QuiverCharacter.get_height_definitions()
	var hs := []
	var ls := []
	for hv in heights:
		hs.append("%.1f" % hv)
		for def in defs:
			if hv > def["min"] and hv <= def["max"]:
				ls.append(str(def["layer"]))
				break
	lines.append("  [b]攻击高度:[/b] [%s] px（离脚底）" % ", ".join(hs))
	lines.append("  [b]命中高度层:[/b] %s（图中绿带，亮线=代表高度）" % " / ".join(ls))


## 显示轮廓预览图
func _display_preview(result: Dictionary, target: TextureRect, show_bands := false) -> void:
	if result.image == null:
		target.texture = null
		return
	if result.skipped or (result.contours as Array).is_empty():
		# 被本类别跳过 / 无轮廓：只显示干净原图，含义由文字报告说明
		target.texture = ImageTexture.create_from_image(result.image)
		return
	var eroded_contours = result.eroded_contours if result.has("eroded_contours") else result.contours
	var heights: Array = result.attack_heights if show_bands else []
	var preview_texture = await _generate_contour_preview(result.image, result.contours, eroded_contours, heights)
	target.texture = preview_texture


## 生成轮廓预览图
##
## 在 SubViewport 中渲染：原图 + 轮廓多边形叠加
## 返回 ImageTexture
func _generate_contour_preview(image: Image, contours: Array[PackedVector2Array], eroded_contours: Array[PackedVector2Array], attack_heights: Array = []):
	var img_w := image.get_width()
	var img_h := image.get_height()
	
	# 创建 SubViewport
	var viewport := SubViewport.new()
	viewport.size = Vector2i(img_w, img_h)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	
	# 底层：原图
	var bg := TextureRect.new()
	bg.texture = ImageTexture.create_from_image(image)
	bg.size = Vector2(img_w, img_h)
	viewport.add_child(bg)
	
	# 上层：轮廓绘制节点
	var overlay := Node2D.new()
	overlay.set_meta("contours", contours)
	overlay.set_meta("eroded_contours", eroded_contours)
	overlay.set_meta("attack_heights", attack_heights)
	overlay.set_meta("img_size", Vector2(img_w, img_h))
	viewport.add_child(overlay)
	
	# 连接 draw 信号
	overlay.draw.connect(_on_overlay_draw.bind(overlay))
	overlay.queue_redraw()
	
	# 等待一帧让渲染完成
	await get_tree().process_frame
	
	# 获取渲染结果
	var viewport_texture := viewport.get_texture()
	var result_texture := ImageTexture.create_from_image(viewport_texture.get_image())
	
	# 清理
	viewport.queue_free()
	
	return result_texture


## 轮廓绘制回调
func _on_overlay_draw(overlay: Node2D) -> void:
	var contours: Array[PackedVector2Array] = overlay.get_meta("contours")
	var eroded_contours: Array[PackedVector2Array] = overlay.get_meta("eroded_contours")
	
	for contour in contours:
		if contour.size() < 3:
			continue
		
		# 填充半透明绿色
		overlay.draw_colored_polygon(contour, Color(0, 1, 0, 0.3))
		
		# 绘制红色边线（闭合）
		var polyline := PackedVector2Array()
		for vertex in contour:
			polyline.append(vertex)
		polyline.append(contour[0])  # 闭合
		overlay.draw_polyline(polyline, Color(1, 0, 0, 1), 2.0, true)
	
	# 绘制 MABR（蓝色矩形 + 黄色中心点，使用腐蚀后的轮廓）
	if eroded_contours.size() > 0 and eroded_contours[0].size() >= 3:
		var mabr := ContourTracer.calc_mabr(eroded_contours[0])
		var corners: PackedVector2Array = mabr.corners
		
		if corners.size() == 4:
			# 蓝色半透明填充
			overlay.draw_colored_polygon(corners, Color(0, 0.5, 1, 0.15))
			
			# 蓝色边线（闭合）
			var mabr_polyline := PackedVector2Array()
			for c in corners:
				mabr_polyline.append(c)
			mabr_polyline.append(corners[0])
			overlay.draw_polyline(mabr_polyline, Color(0, 0.5, 1, 1), 3.0, true)
			
		# 黄色中心点
		var center: Vector2 = mabr.center
		overlay.draw_circle(center, 4, Color(1, 1, 0, 1))
		
		# 绘制 Capsule（品红色，使用 MABR 推导）
		var capsule := ContourTracer.calc_capsule_from_mabr(mabr)
		var capsule_polygon := ContourTracer.generate_capsule_polygon(
			capsule.center,
			capsule.radius,
			capsule.height,
			capsule.angle,
			16
		)
		
		if capsule_polygon.size() >= 3:
			# 品红色半透明填充
			overlay.draw_colored_polygon(capsule_polygon, Color(1, 0, 1, 0.15))
			
			# 品红色边线（闭合）
			var capsule_polyline := PackedVector2Array()
			for p in capsule_polygon:
				capsule_polyline.append(p)
			capsule_polyline.append(capsule_polygon[0])
			overlay.draw_polyline(capsule_polyline, Color(1, 0, 1, 1), 2.0, true)
	# 攻击高度带（仅 attack 栏传入 heights 时绘制）：
	# 每个代表高度所属的整个层区间画半透明绿带 + 代表高度画一条亮绿线（离底=从下往上）
	var heights: Array = overlay.get_meta("attack_heights", [])
	if heights.is_empty():
		return
	var img_size: Vector2 = overlay.get_meta("img_size", Vector2.ZERO)
	var defs: Array = QuiverCharacter.get_height_definitions()
	for hv in heights:
		var h: float = hv
		for def in defs:
			if h > def["min"] and h <= def["max"]:
				var top_y: float = img_size.y - minf(def["max"], img_size.y)
				var bot_y: float = img_size.y - def["min"]
				overlay.draw_rect(Rect2(0, top_y, img_size.x, bot_y - top_y), Color(0.2, 0.85, 0.3, 0.25), true)
				overlay.draw_line(Vector2(0, img_size.y - h), Vector2(img_size.x, img_size.y - h), Color(0.15, 0.95, 0.35, 0.9), 1.0)
				break

### -----------------------------------------------------------------------------------------------
