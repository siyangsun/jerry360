shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float levels : hint_range(2.0, 32.0) = 6.0;
uniform float contrast : hint_range(0.5, 3.0) = 1.10;
uniform float brightness : hint_range(0.0, 1.5) = 0.95;
uniform float speed_lines : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;

	if (speed_lines > 0.0) {
		vec2 centered = SCREEN_UV - 0.5;
		float radius = length(centered);
		float angle = atan(centered.y, centered.x);

		const float LINE_COUNT = 64.0;
		const float JITTER_FPS = 20.0;  // how many times per second lines re-randomize

		float t_seed = floor(TIME * JITTER_FPS);
		float seg_f = (angle / (2.0 * PI) + 0.5) * LINE_COUNT;
		float seg_id = floor(seg_f);
		float seg_frac = fract(seg_f);

		// Three independent hashes per segment per jitter frame
		float h1 = fract(sin(seg_id * 127.1 + t_seed * 311.7) * 43758.5453);
		float h2 = fract(sin(seg_id * 269.5 + t_seed * 183.3) * 23421.631);
		float h3 = fract(sin(seg_id * 419.2 + t_seed * 271.1) * 57849.234);

		float line_width = 0.04 + h1 * 0.08;
		float has_line = step(0.70, h1);
		float is_line = has_line * step(seg_frac, line_width);

		// Each line has its own inner and outer radius — randomized length
		float inner_r = mix(0.10, 0.22, h2);
		float outer_r = inner_r + mix(0.18, 0.50, h3);
		float radial = smoothstep(inner_r, inner_r + 0.02, radius)
		             * (1.0 - smoothstep(outer_r - 0.02, outer_r, radius));

		color = mix(color, vec3(1.0), is_line * radial * speed_lines * 0.35);
	}

	color = color * brightness;
	color = clamp((color - 0.5) * contrast + 0.5, 0.0, 1.0);
	color = floor(color * levels) / max(levels - 1.0, 1.0);
	COLOR = vec4(color, 1.0);
}
