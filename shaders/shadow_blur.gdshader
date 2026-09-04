shader_type canvas_item;
render_mode unshaded;

// 可分离高斯模糊的一趟：dir=(1,0) 横向、dir=(0,1) 纵向。
// src = 上一层（阴影缓冲 / 横模糊缓冲）的 ViewportTexture；UV 覆盖全屏。
// 5-tap（双线性补偿）近似高斯，半径 radius 以纹素为单位缩放偏移。
uniform sampler2D src : filter_linear;
uniform vec2 dir = vec2(1.0, 0.0);
uniform vec2 texel_size = vec2(0.0015625, 0.0027778);
uniform float radius : hint_range(0.0, 8.0) = 2.0;

void fragment() {
	vec2 o1 = dir * texel_size * (1.3846153846 * radius);
	vec2 o2 = dir * texel_size * (3.2307692308 * radius);
	vec4 c = texture(src, UV) * 0.2270270270;
	c += (texture(src, UV + o1) + texture(src, UV - o1)) * 0.3162162162;
	c += (texture(src, UV + o2) + texture(src, UV - o2)) * 0.0702702703;
	COLOR = c;
}
