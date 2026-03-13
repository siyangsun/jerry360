extends Node3D

# Chunk-based infinite level generation.
# Chunks spawn ahead of the player and are recycled behind.

signal level_changed(level_name: String, level_index: int)
signal variant_changed(variant: String)

const CHUNK_LENGTH := 80.0      # length of each generated section of mountain (meters)
const CHUNKS_AHEAD := 10        # how many sections are built in front of Jerry at all times
const CHUNKS_BEHIND := 2        # how many sections are kept behind Jerry before being deleted
const LAP_CHUNKS := 5           # how many sections make up one lap

# Concave pipe cross-section
const FLOOR_WIDTH := 18.0       # width of the flat riding surface
const WALL_WIDTH := 4.5         # width of each angled side wall panel
const WALL_ANGLE := 0.6981      # how steeply the side walls angle up (40 degrees)
const PANEL_THICKNESS := 0.5    # thickness of floor and wall panels

# Shared snow terrain surface properties
const SNOW_COLOR := Color(0.88, 0.94, 1.0)  # slightly blue-tinted white
const SNOW_ROUGHNESS := 0.88
const SNOW_TERRAIN_SPEED_DRAIN := 4.0       # speed lost per second when on snow obstacles (moguls, walls)

# Ramps
const RAMP_ANGLE_MIN := 0.10     # shallowest possible ramp angle
const RAMP_ANGLE_MAX := 0.270    # steepest possible ramp angle
const RAMP_LENGTH_MIN := 5.0     # shortest possible ramp (meters)
const RAMP_LENGTH_MAX := 15.0    # longest possible ramp (meters)
const RAMP_WIDTH := 5.0          # how wide each ramp is
const RAMP_THICKNESS := 0.1      # visual thickness of the ramp surface
const RAMP_SLOT_SPACING := 44.0  # meters between obstacle spawn slots in each section
const RAMP_MARGIN := 15.0        # clear space kept at the start and end of each section

# Moguls
const MOGUL_BASE := 1.2           # half-width of each mogul bump
const MOGUL_HEIGHT := 0.6         # how tall each mogul sticks up above the floor
const MOGUL_SINK := 0.08          # how far the base dips below floor level (keeps it flush)
const MOGULS_PER_FIELD_MIN := 5   # fewest moguls in one field
const MOGULS_PER_FIELD_MAX := 10  # most moguls in one field
const MOGUL_FIELD_SPREAD_Z := 16.0  # how spread out along the slope a mogul field is

# Bushes (glades only)
const BUSH_RADIUS := 1.3         # how wide each bush is
const BUSH_HEIGHT := 1.5         # how tall each bush is
const BUSH_SINK := 0.2           # how far the base dips into the floor
const BUSH_CLUSTER_SPREAD := 2.0 # how spread out bushes are within a cluster

# Rock crystals (crags only)
const ROCK_SEGMENTS := 6                       # hexagonal prism cross-section
const ROCK_RADIUS_MIN := 0.7                   # thinnest crystal radius
const ROCK_RADIUS_MAX := 1.8                   # widest crystal radius
const ROCK_BODY_HEIGHT_FACTOR := 1.8           # prism body height = radius * this
const ROCK_CAP_HEIGHT_FACTOR := 1.1            # pointed cap height = radius * this
const ROCK_SINK := 0.6                         # how far the base sits below ground level
const ROCK_TILT_X_MAX := 0.45                  # max random forward/back tilt (radians)
const ROCK_TILT_Z_MAX := 0.35                  # max random side tilt (radians)
const ROCK_CLUSTER_SPREAD := 3.5              # how spread out crystals are within a clump
const ROCK_COLOR := Color(0.16, 0.17, 0.20)    # cool dark gray with slight blue cast

# Upright terrain tilt — leans obstacles toward the camera to sell the downhill slope illusion
const DOWNHILL_TILT_ANGLE := 20.0  # degrees of tilt; higher = more dramatic perceived slope

# Lap variants — each lap rolls one of: regular, misty, steep, clear
const VARIANT_REGULAR := "regular"
const VARIANT_MISTY   := "misty"
const VARIANT_STEEP   := "steep"
const VARIANT_CLEAR   := "clear"
const VARIANT_MISTY_CHANCE   := 0.30  # probability of a misty lap
const VARIANT_STEEP_CHANCE   := 0.20  # probability of a steep lap
const VARIANT_CLEAR_CHANCE   := 0.30  # probability of a clear lap (remaining roll = regular)
const STEEP_TILT_ANGLE := 30.0      # tree tilt on steep runs (degrees)
const NARROWS_FLOOR_WIDTH    := 8.0   # narrower riding surface for THE NARROWS level

# Trees
const TREE_TRUNK_RADIUS := 0.30    # how thick tree trunks are
const TREE_TRUNK_HEIGHT := 2.4     # how tall the trunk is before foliage starts
const TREE_FOLIAGE_RADIUS := 1.6   # how wide the foliage cone is at the base
const TREE_FOLIAGE_HEIGHT := 5.6   # how tall the foliage cone is
const TREE_CLUSTER_SPREAD := 6.0   # how spread out trees are within a cluster
const TREE_COLOR_FOLIAGE := Color(0.05, 0.28, 0.05)  # dark pine green
const TREE_COLOR_TRUNK := Color(0.22, 0.12, 0.05)    # dark brown

# Rails
const RAIL_WIDTH_VISUAL := 0.25    # how wide the rail looks
const RAIL_WIDTH_COLLISION := 0.4  # collision is wider than visual so Jerry stays on
const RAIL_HEIGHT := 0.12          # thickness of the flat rail slab
const RAIL_LENGTH_MIN := 25.0      # shortest possible rail (meters)
const RAIL_LENGTH_MAX := 75.0      # longest possible rail (meters)
const RAIL_PEAK_HEIGHT := 1.5      # how high the flat grinding section is above the ground
const RAIL_RAMP_SECTION := 4.5     # length of the approach and exit ramps on each end
const RAIL_RAMP_GAP := 0.1         # small gap between the ramp top and the flat section

# ── Level configs ─────────────────────────────────────────────────────────────
# Each level: name, chunks before advancing, and obstacle spawn weights.
# Weights are evaluated in order (tree → rail → mogul → ramp); remaining roll = empty slot.
const EMPTY_LEVEL := { "tree": 0.0, "rail": 0.0, "mogul": 0.0, "ramp": 0.0, "bush": 0.0, "rock": 0.0 }

const LEVELS := [
	{
		"name": "THE PARK",
		"chunks": 5,
		"tree": 0.05, "rail": 0.40, "mogul": 0.00, "ramp": 0.40, "bush": 0.00, "rock": 0.00,
	},
	{
		"name": "THE RUNS",
		"chunks": 5,
		"tree": 0.05, "rail": 0.10, "mogul": 0.55, "ramp": 0.10, "bush": 0.00, "rock": 0.00,
	},
	{
		"name": "THE GLADES",
		"chunks": 5,
		"tree": 0.35, "rail": 0.08, "mogul": 0.10, "ramp": 0.03, "bush": 0.20, "rock": 0.00,
	},
	{
		"name": "THE CRAGS",
		"chunks": 5,
		"tree": 0.18, "rail": 0.00, "mogul": 0.00, "ramp": 0.00, "bush": 0.00, "rock": 0.60,
	},
	{
		"name": "THE NARROWS",
		"chunks": 5,
		"floor_width": NARROWS_FLOOR_WIDTH,
		"tree": 0.12, "rail": 0.30, "mogul": 0.20, "ramp": 0.15, "bush": 0.00, "rock": 0.18,
	},
]

@export var chunk_scenes: Array[PackedScene] = []
@export var player: CharacterBody3D

var _active_chunks: Array[Node3D] = []
var _spawn_z: float = 0.0  # next chunk spawn position (negative Z = forward)
var _chunk_count: int = 0

# Display-side level tracking — follows player position, drives the HUD signal
var _display_level_index: int = 0
var _display_level_number: int = 1
var _last_player_chunk: int = 0

# Current lap variant
var _active_variant: String = VARIANT_REGULAR
var _active_tilt_angle: float = DOWNHILL_TILT_ANGLE
var _active_floor_width: float = FLOOR_WIDTH


func _ready() -> void:
	add_to_group("level_generator")
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	GameManager.state_changed.connect(_on_state_changed)
	for i in range(CHUNKS_AHEAD + 1):
		_spawn_chunk()


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if GameManager.state != GameManager.State.PLAYING or not is_instance_valid(player):
		return

	while _spawn_z > player.position.z - CHUNKS_AHEAD * CHUNK_LENGTH:
		_spawn_chunk()

	# Advance displayed level when player crosses a lap marker boundary
	var player_chunk := int(-player.position.z / CHUNK_LENGTH)
	while player_chunk > _last_player_chunk:
		_last_player_chunk += 1
		if _last_player_chunk % LAP_CHUNKS == 0:
			_display_level_index = (_display_level_index + 1) % LEVELS.size()
			_display_level_number += 1
			_pick_variant()
			level_changed.emit(_make_display_name(LEVELS[_display_level_index]["name"]), _display_level_number)

	var despawn_z := player.position.z + CHUNKS_BEHIND * CHUNK_LENGTH
	for chunk in _active_chunks.duplicate():
		if chunk.position.z > despawn_z:
			_active_chunks.erase(chunk)
			chunk.queue_free()


func _spawn_chunk() -> void:
	_chunk_count += 1

	# Derive level from chunk position — same formula as the display side
	var chunk_idx := int(-_spawn_z / CHUNK_LENGTH)
	var level_idx := (chunk_idx / LAP_CHUNKS) % LEVELS.size()
	var cfg: Dictionary = LEVELS[level_idx]

	var chunk: Node3D
	if chunk_scenes.is_empty():
		chunk = _make_fallback_chunk(cfg)
	else:
		chunk = chunk_scenes[randi() % chunk_scenes.size()].instantiate()

	chunk.position.z = _spawn_z
	add_child(chunk)
	_active_chunks.append(chunk)
	_spawn_z -= CHUNK_LENGTH


func _make_fallback_chunk(cfg: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "FallbackChunk"
	_active_floor_width = cfg.get("floor_width", FLOOR_WIDTH)

	var center_z := -CHUNK_LENGTH * 0.5

	# Floor — wide and flat
	var floor_size := Vector3(_active_floor_width, PANEL_THICKNESS, CHUNK_LENGTH)
	root.add_child(_make_panel(
		Vector3(0.0, -PANEL_THICKNESS * 0.5, center_z),
		0.0,
		floor_size
	))

	# Side wall geometry: position the panel center so its inner edge
	# meets the floor edge at (±_active_floor_width/2, 0).
	# Account for panel thickness so the inner top edge is flush with the floor at y=0
	var wall_cx: float = _active_floor_width * 0.5 + WALL_WIDTH * 0.5 * cos(WALL_ANGLE) + PANEL_THICKNESS * 0.5 * sin(WALL_ANGLE)
	var wall_cy: float = WALL_WIDTH * 0.5 * sin(WALL_ANGLE) - PANEL_THICKNESS * 0.5 * cos(WALL_ANGLE)
	var wall_size := Vector3(WALL_WIDTH, PANEL_THICKNESS, CHUNK_LENGTH)

	# Left wall — rotated inward (negative Z rotation tilts right edge down to meet floor)
	root.add_child(_make_panel(
		Vector3(-wall_cx, wall_cy, center_z),
		-WALL_ANGLE,
		wall_size,
		true
	))

	# Right wall — mirrored
	root.add_child(_make_panel(
		Vector3(wall_cx, wall_cy, center_z),
		WALL_ANGLE,
		wall_size,
		true
	))

	_maybe_add_obstacles(root, cfg)
	if _chunk_count % LAP_CHUNKS == 0:
		root.add_child(_make_lap_marker())
	return root


func _maybe_add_obstacles(root: Node3D, cfg: Dictionary) -> void:
	var z := -RAMP_MARGIN
	while z > -(CHUNK_LENGTH - RAMP_MARGIN):
		var roll := randf()
		if roll < cfg.tree:
			var max_offset := _active_floor_width * 0.5 - TREE_FOLIAGE_RADIUS - 0.5
			var tx := randf_range(-max_offset, max_offset)
			root.add_child(_make_tree_cluster(Vector3(tx, 0.0, z)))
		elif roll < cfg.tree + cfg.rail:
			var length := randf_range(RAIL_LENGTH_MIN, RAIL_LENGTH_MAX)
			var max_offset := _active_floor_width * 0.5 - RAIL_WIDTH_COLLISION * 0.5
			var rx := randf_range(-max_offset, max_offset)
			root.add_child(_make_rail(Vector3(rx, 0.0, z - length * 0.5), length))
		elif roll < cfg.tree + cfg.rail + cfg.mogul:
			root.add_child(_make_mogul_field(Vector3(0.0, 0.0, z)))
		elif roll < cfg.tree + cfg.rail + cfg.mogul + cfg.ramp:
			var max_offset := _active_floor_width * 0.5 - RAMP_WIDTH * 0.5
			var rx := randf_range(-max_offset, max_offset)
			var ramp_angle := randf_range(RAMP_ANGLE_MIN, RAMP_ANGLE_MAX)
			var ramp_length := randf_range(RAMP_LENGTH_MIN, RAMP_LENGTH_MAX)
			root.add_child(_make_ramp(Vector3(rx, 0.0, z), ramp_angle, ramp_length))
		elif roll < cfg.tree + cfg.rail + cfg.mogul + cfg.ramp + cfg.bush:
			var max_offset := _active_floor_width * 0.5 - BUSH_RADIUS - 0.5
			var bx := randf_range(-max_offset, max_offset)
			root.add_child(_make_bush_cluster(Vector3(bx, 0.0, z)))
		elif roll < cfg.tree + cfg.rail + cfg.mogul + cfg.ramp + cfg.bush + cfg.rock:
			var max_offset := _active_floor_width * 0.5 - ROCK_RADIUS_MAX - 0.5
			var rx := randf_range(-max_offset, max_offset)
			root.add_child(_make_rock_cluster(Vector3(rx, 0.0, z)))
		z -= RAMP_SLOT_SPACING


func _make_ramp(origin: Vector3, angle: float, length: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = origin  # y=0, sits on floor
	body.add_to_group("snow_terrain")

	var w := RAMP_WIDTH
	var l := length
	var h := l * tan(angle)  # peak height at back end

	# Wedge collision: front edge flush with floor (y=0), back has depth below floor
	var col := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([
		Vector3(-w * 0.5,  0.0,  l * 0.5),  # front left  — flush with floor
		Vector3( w * 0.5,  0.0,  l * 0.5),  # front right — flush with floor
		Vector3(-w * 0.5, -1.0, -l * 0.5),  # back bottom left  — solid base
		Vector3( w * 0.5, -1.0, -l * 0.5),  # back bottom right — solid base
		Vector3(-w * 0.5,  h,   -l * 0.5),  # back top left
		Vector3( w * 0.5,  h,   -l * 0.5),  # back top right
	])
	col.shape = shape
	body.add_child(col)

	# Visual: triangular prism
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = _make_ramp_visual(w, l, h, angle)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = SNOW_COLOR
	mat.roughness = SNOW_ROUGHNESS
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	return body


func _make_ramp_visual(w: float, l: float, h: float, angle: float) -> ArrayMesh:
	var fl  := Vector3(-w * 0.5, 0.0,  l * 0.5)
	var fr  := Vector3( w * 0.5, 0.0,  l * 0.5)
	var bl  := Vector3(-w * 0.5, 0.0, -l * 0.5)
	var br  := Vector3( w * 0.5, 0.0, -l * 0.5)
	var blt := Vector3(-w * 0.5, h,   -l * 0.5)
	var brt := Vector3( w * 0.5, h,   -l * 0.5)

	var top_n  := Vector3(0.0, cos(angle), sin(angle))
	var back_n := Vector3(0.0, 0.0, -1.0)
	var left_n := Vector3(-1.0, 0.0, 0.0)
	var rght_n := Vector3( 1.0, 0.0, 0.0)

	var verts := PackedVector3Array([
		fl,  fr,  brt,   fl,  brt, blt,   # top (riding surface)
		bl,  blt, brt,   bl,  brt, br,    # back wall
		fl,  blt, bl,                     # left side triangle
		fr,  br,  brt,                    # right side triangle
	])
	var norms := PackedVector3Array([
		top_n,  top_n,  top_n,   top_n,  top_n,  top_n,
		back_n, back_n, back_n,  back_n, back_n, back_n,
		left_n, left_n, left_n,
		rght_n, rght_n, rght_n,
	])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _make_rail(origin: Vector3, length: float) -> StaticBody3D:
	# Trapezoidal rail: on-ramp → elevated flat section → off-ramp.
	# origin is the center of the whole rail; +Z = player entry side.
	var body := StaticBody3D.new()
	body.position = origin
	body.add_to_group("rail")

	var ramp_len := RAIL_RAMP_SECTION
	var gap     := RAIL_RAMP_GAP
	# flat_len accounts for both ramp sections AND the gaps on each side
	var flat_len := length - 2.0 * (ramp_len + gap)
	# Ramp tops out at the flat section's riding surface so there is no step at the junction
	var peak_h := RAIL_PEAK_HEIGHT + RAIL_HEIGHT
	var ramp_angle := atan2(peak_h, ramp_len)
	var slant_len := sqrt(ramp_len * ramp_len + peak_h * peak_h)
	var cw := RAIL_WIDTH_COLLISION
	var vw := RAIL_WIDTH_VISUAL

	# Z of each ramp's high end (gap away from the flat section edge)
	var on_peak_z  :=  flat_len * 0.5 + gap
	var off_peak_z := -(flat_len * 0.5 + gap)

	# ── Collision ─────────────────────────────────────────────────────────────

	# On-ramp wedge: ground level at entry (+Z), rises to peak_h at on_peak_z
	var col_on := CollisionShape3D.new()
	var shape_on := ConvexPolygonShape3D.new()
	shape_on.points = PackedVector3Array([
		Vector3(-cw * 0.5, 0.0,    +length * 0.5),
		Vector3(+cw * 0.5, 0.0,    +length * 0.5),
		Vector3(-cw * 0.5, 0.0,     on_peak_z),
		Vector3(+cw * 0.5, 0.0,     on_peak_z),
		Vector3(-cw * 0.5, peak_h,  on_peak_z),
		Vector3(+cw * 0.5, peak_h,  on_peak_z),
	])
	col_on.shape = shape_on
	body.add_child(col_on)

	# Flat elevated section (0.5 m gap on each side between it and the ramp tops)
	var col_flat := CollisionShape3D.new()
	var shape_flat := BoxShape3D.new()
	shape_flat.size = Vector3(cw, RAIL_HEIGHT, flat_len)
	col_flat.position.y = RAIL_PEAK_HEIGHT + RAIL_HEIGHT * 0.5
	col_flat.shape = shape_flat
	body.add_child(col_flat)

	# Off-ramp wedge: peak_h at off_peak_z, ground level at exit (-Z)
	var col_off := CollisionShape3D.new()
	var shape_off := ConvexPolygonShape3D.new()
	shape_off.points = PackedVector3Array([
		Vector3(-cw * 0.5, peak_h,  off_peak_z),
		Vector3(+cw * 0.5, peak_h,  off_peak_z),
		Vector3(-cw * 0.5, 0.0,     off_peak_z),
		Vector3(+cw * 0.5, 0.0,     off_peak_z),
		Vector3(-cw * 0.5, 0.0,    -length * 0.5),
		Vector3(+cw * 0.5, 0.0,    -length * 0.5),
	])
	col_off.shape = shape_off
	body.add_child(col_off)

	# ── Visuals ───────────────────────────────────────────────────────────────

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.72, 0.78)
	mat.metallic = 0.85
	mat.roughness = 0.15

	# On-ramp: center Z simplifies to (length - ramp_len) * 0.5 regardless of gap
	var on_mesh := MeshInstance3D.new()
	var on_box := BoxMesh.new()
	on_box.size = Vector3(vw, RAIL_HEIGHT, slant_len)
	on_mesh.mesh = on_box
	on_mesh.material_override = mat
	on_mesh.rotation.x = ramp_angle
	on_mesh.position = Vector3(0.0, peak_h * 0.5, (length - ramp_len) * 0.5)
	body.add_child(on_mesh)

	# Flat section
	var flat_mesh := MeshInstance3D.new()
	var flat_box := BoxMesh.new()
	flat_box.size = Vector3(vw, RAIL_HEIGHT, flat_len)
	flat_mesh.mesh = flat_box
	flat_mesh.material_override = mat
	flat_mesh.position = Vector3(0.0, RAIL_PEAK_HEIGHT + RAIL_HEIGHT * 0.5, 0.0)
	body.add_child(flat_mesh)

	# Off-ramp
	var off_mesh := MeshInstance3D.new()
	var off_box := BoxMesh.new()
	off_box.size = Vector3(vw, RAIL_HEIGHT, slant_len)
	off_mesh.mesh = off_box
	off_mesh.material_override = mat
	off_mesh.rotation.x = -ramp_angle
	off_mesh.position = Vector3(0.0, peak_h * 0.5, -(length - ramp_len) * 0.5)
	body.add_child(off_mesh)

	return body


func _make_mogul_field(center: Vector3) -> Node3D:
	var field := Node3D.new()
	field.position = center
	field.name = "MogulField"
	var count := randi_range(MOGULS_PER_FIELD_MIN, MOGULS_PER_FIELD_MAX)
	var max_x := _active_floor_width * 0.5 - MOGUL_BASE
	for i in range(count):
		var ox := randf_range(-max_x, max_x)
		var oz := randf_range(-MOGUL_FIELD_SPREAD_Z * 0.5, MOGUL_FIELD_SPREAD_Z * 0.5)
		field.add_child(_make_mogul(Vector3(ox, 0.0, oz)))
	return field


func _make_mogul(pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.add_to_group("snow_terrain")

	var b := MOGUL_BASE
	var h := MOGUL_HEIGHT
	var g := MOGUL_SINK

	var col := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([
		Vector3(-b, -g,  b),
		Vector3( b, -g,  b),
		Vector3(-b, -g, -b),
		Vector3( b, -g, -b),
		Vector3( 0,  h,  0),
	])
	col.shape = shape
	body.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = _make_mogul_mesh(b, h, g)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = SNOW_COLOR
	mat.roughness = SNOW_ROUGHNESS
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	return body


func _make_mogul_mesh(b: float, h: float, g: float) -> ArrayMesh:
	var apex := Vector3( 0,  h,  0)
	var fl   := Vector3(-b, -g,  b)
	var fr   := Vector3( b, -g,  b)
	var bl   := Vector3(-b, -g, -b)
	var br   := Vector3( b, -g, -b)

	var front_n := (fr - fl).cross(apex - fl).normalized()
	var back_n  := (bl - br).cross(apex - br).normalized()
	var left_n  := (fl - bl).cross(apex - bl).normalized()
	var right_n := (br - fr).cross(apex - fr).normalized()

	var verts := PackedVector3Array([
		fl, fr, apex,
		br, bl, apex,
		bl, fl, apex,
		fr, br, apex,
	])
	var norms := PackedVector3Array([
		front_n, front_n, front_n,
		back_n,  back_n,  back_n,
		left_n,  left_n,  left_n,
		right_n, right_n, right_n,
	])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _make_tree_cluster(center: Vector3) -> Node3D:
	var cluster := Node3D.new()
	cluster.position = center
	var count := randi_range(1, 7)
	for i in range(count):
		var ox := randf_range(-TREE_CLUSTER_SPREAD, TREE_CLUSTER_SPREAD)
		var oz := randf_range(-TREE_CLUSTER_SPREAD, TREE_CLUSTER_SPREAD)
		cluster.add_child(_make_tree(Vector3(ox, 0.0, oz)))
	return cluster


func _make_tree(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.x = _active_tilt_angle

	# Trunk — skinny triangular prism
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = TREE_COLOR_TRUNK
	var trunk_cyl := CylinderMesh.new()
	trunk_cyl.top_radius = TREE_TRUNK_RADIUS
	trunk_cyl.bottom_radius = TREE_TRUNK_RADIUS
	trunk_cyl.height = TREE_TRUNK_HEIGHT
	trunk_cyl.radial_segments = 3
	var trunk_mesh := MeshInstance3D.new()
	trunk_mesh.mesh = trunk_cyl
	trunk_mesh.material_override = trunk_mat
	trunk_mesh.position.y = TREE_TRUNK_HEIGHT * 0.5
	root.add_child(trunk_mesh)

	# Foliage — pointy triangular pyramid (top_radius = 0)
	var foliage_mat := StandardMaterial3D.new()
	foliage_mat.albedo_color = TREE_COLOR_FOLIAGE
	var foliage_cyl := CylinderMesh.new()
	foliage_cyl.top_radius = 0.0
	foliage_cyl.bottom_radius = TREE_FOLIAGE_RADIUS
	foliage_cyl.height = TREE_FOLIAGE_HEIGHT
	foliage_cyl.radial_segments = 3
	var foliage_mesh := MeshInstance3D.new()
	foliage_mesh.mesh = foliage_cyl
	foliage_mesh.material_override = foliage_mat
	foliage_mesh.position.y = TREE_TRUNK_HEIGHT + TREE_FOLIAGE_HEIGHT * 0.5
	root.add_child(foliage_mesh)

	# Crash area — covers the whole tree height
	var area := Area3D.new()
	var area_col := CollisionShape3D.new()
	var area_shape := CylinderShape3D.new()
	area_shape.radius = TREE_TRUNK_RADIUS + 0.15
	area_shape.height = TREE_TRUNK_HEIGHT + TREE_FOLIAGE_HEIGHT
	area_col.shape = area_shape
	area_col.position.y = (TREE_TRUNK_HEIGHT + TREE_FOLIAGE_HEIGHT) * 0.5
	area.add_child(area_col)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body.has_method("crash"):
			body.crash()
	)
	root.add_child(area)

	return root


func _make_bush_cluster(center: Vector3) -> Node3D:
	var cluster := Node3D.new()
	cluster.position = center
	var count := randi_range(2, 5)
	for i in range(count):
		var ox := randf_range(-BUSH_CLUSTER_SPREAD, BUSH_CLUSTER_SPREAD)
		var oz := randf_range(-BUSH_CLUSTER_SPREAD, BUSH_CLUSTER_SPREAD)
		cluster.add_child(_make_bush(Vector3(ox, 0.0, oz)))
	return cluster


func _make_bush(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = _make_bush_mesh()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = TREE_COLOR_FOLIAGE
	mesh_inst.material_override = mat
	root.add_child(mesh_inst)

	var area := Area3D.new()
	var area_col := CollisionShape3D.new()
	var area_shape := CylinderShape3D.new()
	area_shape.radius = BUSH_RADIUS * 0.85
	area_shape.height = BUSH_HEIGHT
	area_col.shape = area_shape
	area_col.position.y = BUSH_HEIGHT * 0.5
	area.add_child(area_col)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body.has_method("crash"):
			body.crash()
	)
	root.add_child(area)

	return root


func _make_bush_mesh() -> ArrayMesh:
	var t := (1.0 + sqrt(5.0)) / 2.0   # golden ratio
	var cr := sqrt(1.0 + t * t)         # icosahedron circumradius

	# 12 icosahedron vertices (raw, unnormalized)
	var raw: Array = [
		Vector3(-1,  t,  0), Vector3( 1,  t,  0),
		Vector3(-1, -t,  0), Vector3( 1, -t,  0),
		Vector3( 0, -1,  t), Vector3( 0,  1,  t),
		Vector3( 0, -1, -t), Vector3( 0,  1, -t),
		Vector3( t,  0, -1), Vector3( t,  0,  1),
		Vector3(-t,  0, -1), Vector3(-t,  0,  1),
	]

	# Normalize then scale: XZ → BUSH_RADIUS, Y → [-BUSH_SINK, BUSH_HEIGHT - BUSH_SINK]
	var y_norm_min := -t / cr   # ≈ -0.851
	var y_norm_max :=  t / cr   # ≈  0.851
	var y_range := y_norm_max - y_norm_min

	var pts: Array = []
	for v: Vector3 in raw:
		var n := v / cr
		var y_t := (n.y - y_norm_min) / y_range  # 0..1
		pts.append(Vector3(n.x * BUSH_RADIUS, y_t * BUSH_HEIGHT - BUSH_SINK, n.z * BUSH_RADIUS))

	# 20 triangular faces — CCW winding from outside
	var faces: Array = [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()

	for face: Array in faces:
		var a: Vector3 = pts[face[0]]
		var b: Vector3 = pts[face[1]]
		var c: Vector3 = pts[face[2]]
		var n := (b - a).cross(c - a).normalized()
		verts.append_array([a, b, c])
		norms.append_array([n, n, n])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _make_rock_cluster(center: Vector3) -> Node3D:
	var cluster := Node3D.new()
	cluster.position = center
	var count := randi_range(1, 5)
	for i in range(count):
		var ox := randf_range(-ROCK_CLUSTER_SPREAD, ROCK_CLUSTER_SPREAD)
		var oz := randf_range(-ROCK_CLUSTER_SPREAD, ROCK_CLUSTER_SPREAD)
		cluster.add_child(_make_rock_crystal(Vector3(ox, 0.0, oz)))
	return cluster


func _make_rock_crystal(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = randf() * TAU
	root.rotation.x = randf_range(-ROCK_TILT_X_MAX, ROCK_TILT_X_MAX)
	root.rotation.z = randf_range(-ROCK_TILT_Z_MAX, ROCK_TILT_Z_MAX)
	root.rotation.x += deg_to_rad(_active_tilt_angle)

	var radius  := randf_range(ROCK_RADIUS_MIN, ROCK_RADIUS_MAX)
	var body_h  := radius * ROCK_BODY_HEIGHT_FACTOR
	var cap_h   := radius * ROCK_CAP_HEIGHT_FACTOR

	var mat := StandardMaterial3D.new()
	mat.albedo_color = ROCK_COLOR
	mat.roughness = 0.90
	mat.metallic = 0.0

	# Hexagonal prism body
	var body_cyl := CylinderMesh.new()
	body_cyl.top_radius = radius
	body_cyl.bottom_radius = radius
	body_cyl.height = body_h
	body_cyl.radial_segments = ROCK_SEGMENTS
	var body_mesh := MeshInstance3D.new()
	body_mesh.mesh = body_cyl
	body_mesh.material_override = mat
	body_mesh.position.y = body_h * 0.5 - ROCK_SINK
	root.add_child(body_mesh)

	# Pointed cap
	var cap_cyl := CylinderMesh.new()
	cap_cyl.top_radius = 0.0
	cap_cyl.bottom_radius = radius
	cap_cyl.height = cap_h
	cap_cyl.radial_segments = ROCK_SEGMENTS
	var cap_mesh := MeshInstance3D.new()
	cap_mesh.mesh = cap_cyl
	cap_mesh.material_override = mat
	cap_mesh.position.y = body_h + cap_h * 0.5 - ROCK_SINK
	root.add_child(cap_mesh)

	# Crash area
	var area := Area3D.new()
	var area_col := CollisionShape3D.new()
	var area_shape := CylinderShape3D.new()
	area_shape.radius = radius
	area_shape.height = body_h + cap_h
	area_col.shape = area_shape
	area_col.position.y = (body_h + cap_h) * 0.5 - ROCK_SINK
	area.add_child(area_col)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body.has_method("crash"):
			body.crash()
	)
	root.add_child(area)

	return root


func _make_lap_marker() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(_active_floor_width, 0.02, 0.18)
	mi.mesh = box
	mi.position = Vector3(0.0, 0.02, -(CHUNK_LENGTH - 0.09))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.08, 0.08)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	return mi


func _make_panel(pos: Vector3, rot_z: float, size: Vector3, is_snow_terrain: bool = false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.z = rot_z
	if is_snow_terrain:
		body.add_to_group("snow_terrain")

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	if is_snow_terrain:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = SNOW_COLOR
		mat.roughness = SNOW_ROUGHNESS
		mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	return body


func _pick_variant() -> void:
	var roll := randf()
	if roll < VARIANT_MISTY_CHANCE:
		_active_variant = VARIANT_MISTY
	elif roll < VARIANT_MISTY_CHANCE + VARIANT_STEEP_CHANCE:
		_active_variant = VARIANT_STEEP
	elif roll < VARIANT_MISTY_CHANCE + VARIANT_STEEP_CHANCE + VARIANT_CLEAR_CHANCE:
		_active_variant = VARIANT_CLEAR
	else:
		_active_variant = VARIANT_REGULAR
	_active_tilt_angle = STEEP_TILT_ANGLE if _active_variant == VARIANT_STEEP else DOWNHILL_TILT_ANGLE
	GameManager.set_variant(_active_variant)
	variant_changed.emit(_active_variant)


func _make_display_name(base: String) -> String:
	# Inserts the variant prefix after "THE " — e.g. "THE MISTY PARK", "THE STEEP RUNS"
	match _active_variant:
		VARIANT_MISTY:    return "THE MISTY " + base.substr(4)
		VARIANT_STEEP:    return "THE STEEP " + base.substr(4)
		VARIANT_CLEAR:  return "THE CLEAR " + base.substr(4)
		_: return base


func _on_state_changed(new_state: GameManager.State) -> void:
	if new_state == GameManager.State.PLAYING:
		_reset()


func _reset() -> void:
	for chunk in _active_chunks:
		chunk.queue_free()
	_active_chunks.clear()
	_spawn_z = 0.0
	_chunk_count = 0
	_display_level_index = 0
	_display_level_number = 1
	_last_player_chunk = 0
	_pick_variant()
	for i in range(CHUNKS_AHEAD + 1):
		_spawn_chunk()
	level_changed.emit(_make_display_name(LEVELS[0]["name"]), 1)
