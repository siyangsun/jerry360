shader_type fog;

uniform float boundary_start : hint_range(30.0, 120.0) = 120.0;  // world X distance from center where fog begins
uniform float boundary_falloff : hint_range(0.0, 0.5) = 0.02; // density gained per metre past the start
uniform vec3 fog_albedo : source_color = vec3(0.85, 0.92, 1.0);

void fog() {
	float dist = max(0.0, abs(WORLD_POSITION.x) - boundary_start);
	DENSITY = dist * boundary_falloff;
	ALBEDO = fog_albedo;
}
