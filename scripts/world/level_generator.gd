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
	var wall_cx: float = FLOOR_WIDTH * 0.5 + WALL_WIDTH * 0.5 * cos(WALL_ANGLE)
	var wall_cy: float = WALL_WIDTH * 0.5 * sin(WALL_ANGLE)
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

	return root


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
