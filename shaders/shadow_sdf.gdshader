shader_type canvas_item;
render_mode unshaded;

// ── 共享参数（所有角色相同，通过共享 ShaderMaterial 设置）──
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.05, 0.55);
// color.rgb = 阴影颜色
// color.a   = 阴影最大深度（0=完全透明，1=完全不透明）

// ── 光源方向 ──
// angle 定义：光源在屏幕上的方位角（度）
//   0° = 光源在屏幕正上方 → 阴影向下投射
//  90° = 光源在屏幕正右方 → 阴影向左投射
// 135° = 光源在右上方    → 阴影向左下方投射（默认）
// 180° = 光源在正下方    → 阴影向上投射
// 270° = 光源在正左方    → 阴影向右投射
//
// 与 DirectionalLight2D.rotation_degrees 的映射：
//   shader_angle = fmod(light_rotation + 180.0, 360.0)
uniform float angle : hint_range(0.0, 360.0) = 135.0;

// ── 阴影柔和度（gradientTexture 未配置时的 fallback）──
// 0.0 = 最柔和（线性过渡，淡出区间最长）
// 1.0 = 硬边缘（阶跃过渡，无淡出）
// 原理：smoothstep(0, max(0.001, 1-softness), alpha)，softness 越大过渡区间越窄
uniform float softness : hint_range(0.0, 1.0) = 0.4;

// ── 渐变纹理（可选，配置后覆盖 softness）──
uniform sampler2D gradientTexture;

// ── per-instance 参数（每个角色不同，通过 set_instance_shader_parameter 设置）──
// shadow_size: Sprite2D 的缩放因子，将 1×1 矩形放大到 (full_w, full_h)
instance uniform vec2 shadow_size = vec2(141.6, 241.6);

// shadow_top_offset: 顶部两个顶点的偏移量
//   shadow_dir.y >= 0 时: (0, +half_len) — 顶边贴紧脚底
//   shadow_dir.y <  0 时: (dx, -half_len) — 顶边偏移（阴影向上延伸）
instance uniform vec2 shadow_top_offset = vec2(0.0, 90.0);

// shadow_bottom_offset: 底部两个顶点的偏移量
//   shadow_dir.y >= 0 时: (dx, +half_len) — 底边偏移（阴影向下延伸）
//   shadow_dir.y <  0 时: (0, -half_len) — 底边贴紧脚底
instance uniform vec2 shadow_bottom_offset = vec2(-126.0, 90.0);

// shadow_max_dist: 该角色的阴影长度上限（画布像素）
// 由 GDScript 根据精灵图尺寸和仰角计算后传入
// 计算公式：
//   sprite_h = 精灵图当前帧纹理高度（像素）
//   shadow_pixels = sprite_h / tan(太阳仰角)
//   shadow_pixels = clamp(shadow_pixels, MIN_SHADOW_LENGTH, MAX_SHADOW_LENGTH)
//   shadow_max_dist = shadow_pixels（画布像素，不乘 sdf_scale）
//
// 注意：shadow_max_dist 不包含跳跃高度，控制阴影浓淡（物理合理行为）
// 跳跃时阴影会自然淡出，这是符合物理规律的行为
instance uniform float shadow_max_dist = 90.0;

// ── Vertex Shader ──
// 将 Sprite2D 的 1×1 矩形变形为阴影平行四边形
// Sprite2D 初始顶点（centered=true, 1×1 纹理）:
//   VERTEX_ID 0 = 左上 (-0.5, -0.5)
//   VERTEX_ID 1 = 左下 (-0.5, +0.5)
//   VERTEX_ID 2 = 右下 (+0.5, +0.5)
//   VERTEX_ID 3 = 右上 (+0.5, -0.5)
void vertex() {
	// 1. 缩放：从 1×1 放大到 full_w × full_h（锚点 = 原点）
	VERTEX *= shadow_size;
	// 2. 条件偏移：底部顶点(1,2)用 bottom_offset，顶部顶点(0,3)用 top_offset
	if (VERTEX_ID == 1 || VERTEX_ID == 2) {
		VERTEX += shadow_bottom_offset;
	} else {
		VERTEX += shadow_top_offset;
	}
}

#define SDF_STEP \
	d = texture_sdf(at); \
	at += d * dir * running; \
	accum += d * running; \
	running *= step(0.01, d); \
	running *= step(accum, shadow_max_dist)

void fragment() {
	float ang_rad = angle * 3.1416 / 180.0;
	vec2 dir = vec2(sin(ang_rad), cos(ang_rad));

	vec2 at = screen_uv_to_sdf(SCREEN_UV);

	float d = 0.0;
	float accum = 0.0;
	float running = 1.0;

	// 固定 8 步 ray march，无分支，宏展开
	SDF_STEP;
	SDF_STEP;
	SDF_STEP;
	SDF_STEP;
	SDF_STEP;
	SDF_STEP;
	SDF_STEP;
	SDF_STEP;

	float ratio = clamp(accum / shadow_max_dist, 0.0, 1.0);
	float alpha = 1.0 - ratio;
	alpha = smoothstep(0.0, max(0.001, 1.0 - softness), alpha);

	COLOR = vec4(color.rgb, alpha * color.a);
}
