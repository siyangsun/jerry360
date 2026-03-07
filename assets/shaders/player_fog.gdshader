shader_type fog;

uniform vec3 player_pos = vec3(0.0);                           // updated each frame by player_fog.gd
uniform float fog_radius : hint_range(10.0, 20000.0) = 15000.0;      // clear bubble radius on X and Y axes
uniform float depth_scale : hint_range(1.0, 10.0) = 10.0;      // how many times farther you can see forward vs sideways
uniform float fog_falloff : hint_range(0.0, 0.3) = 0.02;      // density gained per ellipsoid-unit past the surface
uniform vec3 fog_albedo : source_color = vec3(0.85, 0.92, 1.0);

void fog() {
	vec3 diff = WORLD_POSITION - player_pos;
	float ellipsoid_r = length(vec3(diff.x, diff.y, diff.z / depth_scale)) / fog_radius;
	DENSITY = max(0.0, ellipsoid_r - 1.0) * fog_falloff;
	ALBEDO = fog_albedo;
}
