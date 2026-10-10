shader_type canvas_item;

// Very light 3x3 gaussian (1-2-1 kernel) for the HUD mannequin sprite.
// Premultiplied: colour is weighted by alpha, so transparent texels (whatever RGB they carry)
// never tint the result, and a fully transparent neighbourhood stays exactly alpha 0.
uniform float blur_radius_px = 1.0;  // sample spacing in source texels

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;  // vertex colour incl. modulate (alpha 0.9), before the texture is applied
}

// (rgb * a * w, a * w) for one kernel tap
vec4 premul(vec4 s, float w) {
	return vec4(s.rgb * s.a, s.a) * w;
}

void fragment() {
	vec2 o = TEXTURE_PIXEL_SIZE * blur_radius_px;
	vec4 sum = premul(texture(TEXTURE, UV), 4.0);
	sum += premul(texture(TEXTURE, UV + vec2(o.x, 0.0)), 2.0) + premul(texture(TEXTURE, UV - vec2(o.x, 0.0)), 2.0);
	sum += premul(texture(TEXTURE, UV + vec2(0.0, o.y)), 2.0) + premul(texture(TEXTURE, UV - vec2(0.0, o.y)), 2.0);
	sum += premul(texture(TEXTURE, UV + o), 1.0) + premul(texture(TEXTURE, UV - o), 1.0);
	sum += premul(texture(TEXTURE, UV + vec2(o.x, -o.y)), 1.0) + premul(texture(TEXTURE, UV + vec2(-o.x, o.y)), 1.0);
	vec3 col = sum.a > 0.0 ? sum.rgb / sum.a : vec3(0.0);
	COLOR = vec4(col, sum.a / 16.0) * v_modulate;
}
