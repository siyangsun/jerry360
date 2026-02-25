extends Node3D

# Chunk-based infinite level generation.
# Chunks spawn ahead of the player and are recycled behind.

const CHUNK_LENGTH := 80.0
const CHUNKS_AHEAD := 4
const CHUNKS_BEHIND := 1
const LANE_WIDTH := 2.5

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
	if GameManager.state != GameManager.State.PLAYING or not is_instance_valid(player):
		return

	# Spawn chunks ahead
	while _spawn_z > player.position.z - CHUNKS_AHEAD * CHUNK_LENGTH:
		_spawn_chunk()

	# Despawn chunks behind
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
	# Plain flat platform used until real chunk scenes are built.
	# Body is offset so the chunk extends from z=0 to z=-CHUNK_LENGTH.
	var root := Node3D.new()
	root.name = "FallbackChunk"

	var body := StaticBody3D.new()
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3((LANE_WIDTH * 3.0 + 2.0) * 2.0, 0.4, CHUNK_LENGTH)
	mesh_inst.mesh = box

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	col.shape = shape

	body.add_child(mesh_inst)
	body.add_child(col)
	# Center of the box sits half a chunk length ahead (in -Z)
	body.position = Vector3(0.0, -0.2, -CHUNK_LENGTH * 0.5)
	root.add_child(body)
	return root


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
