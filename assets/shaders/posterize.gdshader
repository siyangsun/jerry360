shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float levels : hint_range(2.0, 32.0) = 6.0;

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	color = floor(color * levels) / max(levels - 1.0, 1.0);
	COLOR = vec4(color, 1.0);
}
