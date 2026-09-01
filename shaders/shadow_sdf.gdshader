shader_type canvas_item;
render_mode unshaded;

// ── 阴影外观 ──
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.1, 0.4);
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

// ── 阴影长度上限 ──
// max_dist = 阴影最大长度（SDF 空间单位），超过此距离的阴影被截断
// 由 GDScript 根据"参考角色身高"和光源仰角动态计算后传入
// 
// 物理含义：max_dist 基于当前角色的 physical_height 计算
// （多 ShadowRenderer 方案：每个角色独立计算自己的 max_dist）
// 计算公式（在 GDScript 中）：
//   physical_height = 当前角色的身高（屏幕像素，由 AnimationPlayer track 每帧更新）
//   tan_elev = tan(太阳仰角)
//   shadow_pixels = physical_height / tan_elev
//   sdf_scale = ProjectSettings.rendering/2d/sdf/scale
//   max_dist = shadow_pixels * sdf_scale
//
// 注意：max_dist 只控制阴影长度上限，不影响实际阴影长度
// 实际阴影长度由 occluder 几何位置决定（ray march 碰到 occluder 时 break）
uniform float max_dist : hint_range(0.0, 1000.0) = 100.0;

// ── 阴影柔和度（gradientTexture 未配置时的 fallback）──
// 0.0 = 最柔和（线性过渡，淡出区间最长）
// 1.0 = 硬边缘（阶跃过渡，无淡出）
// 原理：smoothstep(0, max(0.001, 1-softness), alpha)，softness 越大过渡区间越窄
uniform float softness : hint_range(0.0, 1.0) = 0.4;

// ── 渐变纹理（可选，配置后覆盖 softness）──
uniform sampler2D gradientTexture;

void fragment() {
	// 角度转方向向量
	float ang_rad = angle * 3.1416 / 180.0;
	vec2 dir = vec2(sin(ang_rad), cos(ang_rad));

	// 当前像素的 SDF 坐标
	vec2 at = screen_uv_to_sdf(SCREEN_UV);

	// Ray Marching
	// d = texture_sdf(at) 返回从当前位置到最近 occluder 边缘的距离
	// 远离 occluder 时 d 很大（一步跳远），接近时 d 很小（一步逼近）
	// 正常情况步数约 8-15 步，由 max_dist 保证循环必然终止
	float accum = 0.0;
	while (true) {
		float d = texture_sdf(at);
		accum += d;
		if (d < 0.01) {
			break;  // 碰到 occluder 边缘
		}
		if (accum >= max_dist) {
			break;  // 超过阴影长度上限
		}
		at += d * dir;
	}

	// 计算基础透明度
	float ratio = clamp(accum / max_dist, 0.0, 1.0);
	float alpha = 1.0 - ratio;

	// 柔和度处理
	// 先尝试 gradientTexture，未配置时 fallback 到 softness
	vec4 grad_sample = texture(gradientTexture, vec2(alpha, 0.5));
	if (grad_sample.r > 0.99) {
		// 未配置纹理（默认 1x1 白色纹理，采样值=1.0）→ 用 softness
		alpha = smoothstep(0.0, max(0.001, 1.0 - softness), alpha);
	} else {
		// 配置了有效渐变纹理 → 用纹理
		alpha = grad_sample.r;
	}

	// 最终输出
	COLOR = vec4(color.rgb, alpha * color.a);
}
