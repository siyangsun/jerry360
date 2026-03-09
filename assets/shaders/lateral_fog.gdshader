shader_type fog;

uniform float boundary_start : hint_range(10.0, 200.0) = 80.0;   // X distance from center where fog begins at floor level
uniform float boundary_falloff : hint_range(0.0, 0.5) = 0.02;    // density gained per metre past the boundary
uniform float floor_y : hint_range(-20.0, 20.0) = 0.0;           // world Y of the snow floor
uniform float height_scale : hint_range(0.0, 20.0) = 5.0;        // extra metres of boundary per metre above floor
uniform vec3 fog_albedo : source_color = vec3(0.85, 0.92, 1.0);

void fog() {
	float height_above_floor = max(0.0, WORLD_POSITION.y - floor_y);
	float effective_boundary = boundary_start + height_above_floor * height_scale;
	float dist = max(0.0, abs(WORLD_POSITION.x) - effective_boundary);
	DENSITY = dist * boundary_falloff;
	ALBEDO = fog_albedo;
}
