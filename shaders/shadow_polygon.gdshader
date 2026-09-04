shader_type canvas_item;
render_mode unshaded;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.05, 0.55);

void fragment() {
	COLOR = shadow_color * COLOR;
}
