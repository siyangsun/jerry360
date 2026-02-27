extends Node3D

# Chunk-based infinite level generation.
# Chunks spawn ahead of the player and are recycled behind.

const CHUNK_LENGTH := 80.0
const CHUNKS_AHEAD := 10
const CHUNKS_BEHIND := 2

# Concave pipe cross-section
const FLOOR_WIDTH := 18.0   # wide flat base
const WALL_WIDTH := 4.5     # each angled side panel
const WALL_ANGLE := 0.6981  # deg_to_rad(40) — slope of side panels from horizontal
const PANEL_THICKNESS := 0.5

# Shared snow terrain surface properties
const SNOW_COLOR := Color(0.88, 0.94, 1.0)
const SNOW_ROUGHNESS := 0.88
const SNOW_TERRAIN_SPEED_DRAIN := 4.0  # forward speed lost per second when on any snow obstacle

# Ramps
const RAMP_ANGLE_MIN := 0.10
const RAMP_ANGLE_MAX := 0.270
const RAMP_LENGTH_MIN := 5.0
const RAMP_LENGTH_MAX := 15.0
const RAMP_WIDTH := 5.0
const RAMP_THICKNESS := 0.1
const RAMP_SPAWN_CHANCE := 0.5  # chance per slot (after rail roll)
const RAMP_SLOT_SPACING := 44.0  # meters between spawn slots
const RAMP_MARGIN := 15.0        # clear space at each chunk end

# Moguls
const MOGUL_SPAWN_CHANCE := 0.25
const MOGUL_BASE := 1.2           # half-width of square base
const MOGUL_HEIGHT := 0.6         # apex above floor — "slightly" sticking out
const MOGUL_SINK := 0.08          # base sinks this far below y=0 so it's flush
const MOGULS_PER_FIELD_MIN := 5
const MOGULS_PER_FIELD_MAX := 10
const MOGUL_FIELD_SPREAD_Z := 16.0

# Rails
const RAIL_SPAWN_CHANCE := 0.25   # checked first — rails are rarer than ramps
const RAIL_WIDTH_VISUAL := 0.2
const RAIL_WIDTH_COLLISION := 0.3  # wider than visual so Jerry stays on
const RAIL_HEIGHT := 0.12          # thickness of the flat rail slab
const RAIL_LENGTH_MIN := 25.0
const RAIL_LENGTH_MAX := 75.0
const RAIL_PEAK_HEIGHT := 1.5      # how high the flat section is above the ground
const RAIL_RAMP_SECTION := 4.5    # length of each ramp (on-ramp and off-ramp)
const RAIL_RAMP_GAP := 0.1        # gap between each ramp top and the flat section

@export var chunk_scenes: Array[PackedScene] = []
@export var player: CharacterBody3D

var _active_chunks: Array[Node3D] = []
var _spawn_z: float = 0.0  # next chunk spawn position (negative Z = forward)


func _ready() -> void:
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

	var despawn_z := player.position.z + CHUNKS_BEHIND * CHUNK_LENGTH
	for chunk in _active_chunks.duplicate():
		if chunk.position.z > despawn_z:
			_active_chunks.erase(chunk)
			chunk.queue_free()


func _spawn_chunk() -> void:
	var chunk: Node3D
	if chunk_scenes.is_empty():
		chunk = _make_fallback_chunk()
	else:
		chunk = chunk_scenes[randi() % chunk_scenes.size()].instantiate()

	chunk.position.z = _spawn_z
	add_child(chunk)
	_active_chunks.append(chunk)
	_spawn_z -= CHUNK_LENGTH


func _make_fallback_chunk() -> Node3D:
	var root := Node3D.new()
	root.name = "FallbackChunk"

	var center_z := -CHUNK_LENGTH * 0.5

	# Floor — wide and flat
	var floor_size := Vector3(FLOOR_WIDTH, PANEL_THICKNESS, CHUNK_LENGTH)
	root.add_child(_make_panel(
		Vector3(0.0, -PANEL_THICKNESS * 0.5, center_z),
		0.0,
		floor_size
	))

	# Side wall geometry: position the panel center so its inner edge
	# meets the floor edge at (±FLOOR_WIDTH/2, 0).
	# Account for panel thickness so the inner top edge is flush with the floor at y=0
	var wall_cx: float = FLOOR_WIDTH * 0.5 + WALL_WIDTH * 0.5 * cos(WALL_ANGLE) + PANEL_THICKNESS * 0.5 * sin(WALL_ANGLE)
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

	_maybe_add_obstacles(root)
	return root


func _maybe_add_obstacles(root: Node3D) -> void:
	var z := -RAMP_MARGIN
	while z > -(CHUNK_LENGTH - RAMP_MARGIN):
		var roll := randf()
		if roll < RAIL_SPAWN_CHANCE:
			var length := randf_range(RAIL_LENGTH_MIN, RAIL_LENGTH_MAX)  # long enough for on+off ramps plus flat section
			var max_offset := FLOOR_WIDTH * 0.5 - RAIL_WIDTH_COLLISION * 0.5
			var rx := randf_range(-max_offset, max_offset)
			root.add_child(_make_rail(Vector3(rx, 0.0, z - length * 0.5), length))
		elif roll < RAIL_SPAWN_CHANCE + MOGUL_SPAWN_CHANCE:
			root.add_child(_make_mogul_field(Vector3(0.0, 0.0, z)))
		elif roll < RAIL_SPAWN_CHANCE + MOGUL_SPAWN_CHANCE + RAMP_SPAWN_CHANCE:
			var max_offset := FLOOR_WIDTH * 0.5 - RAMP_WIDTH * 0.5
			var rx := randf_range(-max_offset, max_offset)
			var ramp_angle := randf_range(RAMP_ANGLE_MIN, RAMP_ANGLE_MAX)
			var ramp_length := randf_range(RAMP_LENGTH_MIN, RAMP_LENGTH_MAX)
			root.add_child(_make_ramp(Vector3(rx, 0.0, z), ramp_angle, ramp_length))
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
	var bot_n  := Vector3(0.0, -1.0, 0.0)

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
	var max_x := FLOOR_WIDTH * 0.5 - MOGUL_BASE
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


func _on_state_changed(new_state: GameManager.State) -> void:
	if new_state == GameManager.State.PLAYING:
		_reset()


func _reset() -> void:
	for chunk in _active_chunks:
		chunk.queue_free()
	_active_chunks.clear()
	_spawn_z = 0.0
	for i in range(CHUNKS_AHEAD + 1):
		_spawn_chunk()
