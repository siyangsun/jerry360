extends Node3D

# Chunk-based infinite level generation.
# Chunks spawn ahead of the player and are recycled behind.

const CHUNK_LENGTH := 240.0
const CHUNKS_AHEAD := 4
const CHUNKS_BEHIND := 1

# Concave pipe cross-section
const FLOOR_WIDTH := 14.0   # wide flat base
const WALL_WIDTH := 4.5     # each angled side panel
const WALL_ANGLE := 0.6981  # deg_to_rad(40) — slope of side panels from horizontal
const PANEL_THICKNESS := 0.5

# Ramps
const RAMP_ANGLE := 0.175   # deg_to_rad(10) — shallow enough to ride onto without jumping
const RAMP_LENGTH := 7.0
const RAMP_WIDTH := 5.0
const RAMP_THICKNESS := 0.1
const RAMP_SPAWN_CHANCE := 0.75  # chance per slot
const RAMP_SLOT_SPACING := 44.0  # meters between spawn slots
const RAMP_MARGIN := 15.0        # clear space at each chunk end

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
		wall_size
	))

	# Right wall — mirrored
	root.add_child(_make_panel(
		Vector3(wall_cx, wall_cy, center_z),
		WALL_ANGLE,
		wall_size
	))

	_maybe_add_ramps(root)
	return root


func _maybe_add_ramps(root: Node3D) -> void:
	var z := -RAMP_MARGIN
	while z > -(CHUNK_LENGTH - RAMP_MARGIN):
		if randf() < RAMP_SPAWN_CHANCE:
			var max_offset := FLOOR_WIDTH * 0.5 - RAMP_WIDTH * 0.5
			var rx := randf_range(-max_offset, max_offset)
			root.add_child(_make_ramp(Vector3(rx, 0.0, z)))
		z -= RAMP_SLOT_SPACING


func _make_ramp(origin: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = origin  # y=0, sits on floor

	var w := RAMP_WIDTH
	var l := RAMP_LENGTH
	var h := l * tan(RAMP_ANGLE)  # peak height at back end

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

	# Visual: tilted box slab
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(w, RAMP_THICKNESS, l)
	mesh_inst.mesh = box
	mesh_inst.rotation.x = RAMP_ANGLE
	mesh_inst.position.y = RAMP_THICKNESS * 0.5 * cos(RAMP_ANGLE) + l * 0.5 * sin(RAMP_ANGLE)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 0.91, 1.0)
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	return body


func _make_panel(pos: Vector3, rot_z: float, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.z = rot_z

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
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
