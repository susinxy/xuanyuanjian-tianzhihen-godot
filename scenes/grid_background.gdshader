shader_type canvas_item;

uniform float grid_size : hint_range(10.0, 500.0) = 100.0;
uniform float sub_grid_size : hint_range(5.0, 200.0) = 25.0;
uniform float line_width : hint_range(0.5, 5.0) = 1.0;
uniform float sub_line_width : hint_range(0.5, 3.0) = 0.5;
uniform vec4 grid_color : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform vec4 sub_grid_color : source_color = vec4(0.12, 0.12, 0.12, 1.0);
uniform vec4 bg_color : source_color = vec4(0.06, 0.06, 0.06, 1.0);
uniform float ground_line_y = 0.0;
uniform float ground_line_width : hint_range(1.0, 10.0) = 3.0;
uniform vec4 ground_line_color : source_color = vec4(0.4, 0.3, 0.2, 1.0);

void fragment() {
    vec2 world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;

    // Main grid
    vec2 main_grid = abs(fract(world_pos / grid_size - 0.5) - 0.5) * grid_size;
    float main_line = min(main_grid.x, main_grid.y);
    float main_mask = 1.0 - smoothstep(0.0, line_width, main_line);

    // Sub grid
    vec2 sub_grid = abs(fract(world_pos / sub_grid_size - 0.5) - 0.5) * sub_grid_size;
    float sub_line = min(sub_grid.x, sub_grid.y);
    float sub_mask = 1.0 - smoothstep(0.0, sub_line_width, sub_line);

    // Ground reference line
    float ground_dist = abs(world_pos.y - ground_line_y);
    float ground_mask = 1.0 - smoothstep(0.0, ground_line_width, ground_dist);

    // Compose
    vec4 color = bg_color;
    color = mix(color, sub_grid_color, sub_mask);
    color = mix(color, grid_color, main_mask);
    color = mix(color, ground_line_color, ground_mask);

    COLOR = color;
}
