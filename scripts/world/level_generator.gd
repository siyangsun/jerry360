extends Node3D

# Chunk-based infinite level generation.
# Chunks spawn ahead of the player and are recycled behind.

signal level_changed(level_name: String, level_index: int)
signal variant_changed(variant: String)
signal tutorial_stage_changed(stage_index: int)
signal tutorial_complete

const CHUNK_LENGTH := 80.0      # length of each generated section of mountain (meters)
const CHUNKS_AHEAD := 6         # how many sections are built in front of Jerry at all times
const OBSTACLE_BUILDS_PER_FRAME := 1  # queued obstacles built per frame (spreads chunk cost across frames)
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

# Ramps
const RAMP_ANGLE_MIN := 0.10     # shallowest possible ramp angle
const RAMP_ANGLE_MAX := 0.270    # steepest possible ramp angle
const RAMP_LENGTH_MIN := 5.0     # shortest possible ramp (meters)
const RAMP_LENGTH_MAX := 15.0    # longest possible ramp (meters)
const RAMP_WIDTH := 5.0          # how wide each ramp is
const BIG_RAMP_LENGTH_SCALE_MIN := 2.0  # minimum length multiplier for big air ramps
const BIG_RAMP_LENGTH_SCALE_MAX := 3.0  # maximum length multiplier for big air ramps
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
const BUSH_AREA_RADIUS_FACTOR := 0.85  # crash cylinder radius = BUSH_RADIUS * this
const BUSH_NEAR_RADIUS := 2.2    # close-call sphere radius

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
const ROCK_ROUGHNESS := 0.90                   # rock material roughness
const ROCK_NEAR_PADDING := 1.5                 # close-call sphere radius = crystal radius + this

# Poles (Lift Area only) — T-shaped lift poles: vertical shaft + horizontal crossbar
const POLE_SHAFT_WIDTH  := 0.18    # width and depth of the vertical shaft
const POLE_SHAFT_HEIGHT := 5.5     # total height of the shaft
const POLE_BAR_LENGTH   := 2.4     # length of the horizontal crossbar
const POLE_BAR_HEIGHT   := 0.18    # thickness of the crossbar
const POLE_BAR_DEPTH    := 0.22    # depth of the crossbar
const POLE_SINK         := 0.1     # how far the base sits below ground level
const POLE_PAIR_SPREAD  := 5.0     # X distance between the two poles in a pair
const POLE_COLOR        := Color(0.16, 0.17, 0.20)  # same cool dark gray as rocks
const POLE_ROUGHNESS    := 0.3     # pole material roughness
const POLE_METALLIC     := 0.6     # pole material metallic
const POLE_AREA_SIZE    := Vector3(0.55, 2.0, 0.55)  # crash box covering the lower shaft
const POLE_AREA_CENTER_Y := 1.0    # height of the crash box center above the pole base
const POLE_NEAR_RADIUS  := 1.8     # close-call sphere radius

# Park fences — run along the top of each bank; posts lean like trees/signs/poles
const FENCE_POST_SPACING := 2.3    # meters between fence posts (shrinks on steep runs so the step never exceeds FENCE_MAX_STEP)
const FENCE_MAX_STEP     := 0.72   # most a rail is allowed to step down at each post
const FENCE_RAIL_ANGLE_SCALE := 0.5  # rail pitch as a fraction of the post lean (1 = square to posts, 0 = flat along the snow)
const FENCE_POST_WIDTH   := 0.10   # width and depth of each post
const FENCE_POST_HEIGHT  := 1.4    # how tall each post is
const FENCE_POST_SINK    := 0.1    # how far the post base sits into the bank
const FENCE_RAIL_THICK   := 0.06   # thickness of each horizontal rail
const FENCE_RAIL_HEIGHTS := [0.27, 0.65]  # height of each rail where it leaves the uphill post (it's higher by one step at the next post)
const FENCE_EDGE_INSET   := 0.26   # how far in from the outer lip of the bank the fence stands
const FENCE_COLLISION_THICK := 0.4 # depth of the solid wall Jerry bumps into (wider than posts so he can't clip through at speed)
const FENCE_RAIL_COLOR   := Color(1.0, 0.42, 0.05)   # resort-boundary orange

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

# Warning signs
const SIGN_POST_WIDTH  := 0.07    # thickness of the sign post
const SIGN_POST_HEIGHT := 2.0     # height of the post
const SIGN_FACE_SIZE   := 0.55    # width/height of the diamond sign face
const SIGN_FACE_THICK  := 0.05    # depth of the sign face
const SIGN_COLOR       := Color(0.95, 0.82, 0.08)   # warning yellow
const SIGN_POST_COLOR  := Color(0.80, 0.80, 0.80)   # light gray post
const SIGN_POST_ROUGHNESS := 0.6  # post material roughness
const SIGN_FACE_ROTATION_DEG := 45.0  # diamond orientation

const TREE_TRUNK_RADIUS := 0.30    # how thick tree trunks are
const TREE_TRUNK_HEIGHT := 2.4     # how tall the trunk is before foliage starts
const TREE_FOLIAGE_RADIUS := 1.6   # how wide the foliage cone is at the base
const TREE_FOLIAGE_HEIGHT := 5.6   # how tall the foliage cone is
const TREE_CLUSTER_SPREAD := 6.0   # how spread out trees are within a cluster
const TREE_COLOR_FOLIAGE := Color(0.05, 0.28, 0.05)  # dark pine green
const TREE_COLOR_TRUNK := Color(0.22, 0.12, 0.05)    # dark brown
const TREE_RADIAL_SEGMENTS := 3    # trunk and foliage are triangular prisms/pyramids
const TREE_AREA_PADDING := 0.15    # crash cylinder is this much wider than the trunk
const TREE_NEAR_RADIUS := 2.0      # close-call sphere radius

# Rails
const RAIL_WIDTH_VISUAL := 0.25    # how wide the rail looks
const RAIL_WIDTH_COLLISION := 0.4  # collision is wider than visual so Jerry stays on
const RAIL_HEIGHT := 0.12          # thickness of the flat rail slab
const RAIL_LENGTH_MIN := 25.0      # shortest possible rail (meters)
const RAIL_LENGTH_MAX := 75.0      # longest possible rail (meters)
const RAIL_PEAK_HEIGHT := 1.5      # how high the flat grinding section is above the ground
const RAIL_RAMP_SECTION := 4.5     # length of the approach and exit ramps on each end
const RAIL_RAMP_GAP := 0.1         # small gap between the ramp top and the flat section
const RAIL_COLOR := Color(0.72, 0.72, 0.78)  # rail metal color
const RAIL_METALLIC := 0.85        # rail material metallic
const RAIL_ROUGHNESS := 0.15       # rail material roughness

# Lap marker (red line across the floor at the end of each lap)
const LAP_MARKER_COLOR := Color(1.0, 0.08, 0.08)
const LAP_MARKER_HEIGHT := 0.02    # thickness of the marker
const LAP_MARKER_DEPTH := 0.18     # how wide the marker stripe is along the slope

# Shared-resource ids (one material/mesh/shape per id, reused by every obstacle)
const MAT_SNOW      := &"snow"
const MAT_SNOW_RAMP := &"snow_ramp"
const MAT_RAIL      := &"rail"
const MAT_SIGN_POST := &"sign_post"
const MAT_SIGN_FACE := &"sign_face"
const MAT_TRUNK     := &"trunk"
const MAT_FOLIAGE   := &"foliage"
const MAT_ROCK      := &"rock"
const MAT_POLE      := &"pole"
const MAT_LAP       := &"lap"
const MAT_FENCE_RAIL := &"fence_rail"
const MESH_TRUNK      := &"trunk"
const MESH_FOLIAGE    := &"foliage"
const MESH_BUSH       := &"bush"
const MESH_MOGUL      := &"mogul"
const MESH_SIGN_POST  := &"sign_post"
const MESH_SIGN_FACE  := &"sign_face"
const MESH_POLE_SHAFT := &"pole_shaft"
const MESH_POLE_BAR   := &"pole_bar"
const MESH_ROCK_BODY  := &"rock_body"  # built at radius 1; scaled per crystal
const MESH_ROCK_CAP   := &"rock_cap"   # built at radius 1; scaled per crystal
const MESH_FENCE_POST := &"fence_post"
const SHAPE_TREE_HIT  := &"tree_hit"
const SHAPE_TREE_NEAR := &"tree_near"
const SHAPE_BUSH_HIT  := &"bush_hit"
const SHAPE_BUSH_NEAR := &"bush_near"
const SHAPE_POLE_HIT  := &"pole_hit"
const SHAPE_POLE_NEAR := &"pole_near"
const SHAPE_MOGUL     := &"mogul"

# ── Tutorial configs ───────────────────────────────────────────────────────────
# Five hardcoded stages played in order. Each has a variant key (drives tilt + speed)
# and a floor_width key (optional, defaults to FLOOR_WIDTH).
# Instructions for each stage live in res://assets/tutorial/stage_N.txt.
const TUTORIAL_STAGE_COUNT := 5
const TUTORIAL_LAP_CHUNKS := LAP_CHUNKS * 3  # each tutorial stage is 3x longer than a regular lap
const TUTORIAL_LEVELS := [
	{
		"name": "BUNNY HILL",
		"variant": "clear", "floor_width": FLOOR_WIDTH,
		"tree": 0.0, "rail": 0.0, "mogul": 0.0, "ramp": 0.0, "bush": 0.0, "rock": 0.0,
	},
	{
		"name": "CAT TRACK",
		"variant": "clear", "floor_width": NARROWS_FLOOR_WIDTH,
		"tree": 0.0, "rail": 0.0, "mogul": 0.0, "ramp": 0.0, "bush": 0.0, "rock": 0.0,
	},
	{
		"name": "CIRCLE TRAIL",
		"variant": "clear", "floor_width": FLOOR_WIDTH,
		"tree": 0.25, "rail": 0.0, "mogul": 0.0, "ramp": 0.0, "bush": 0.0, "rock": 0.0,
	},
	{
		"name": "BASIC PARK",
		"variant": "clear", "floor_width": FLOOR_WIDTH,
		"tree": 0.0, "rail": 0.40, "mogul": 0.0, "ramp": 0.40, "bush": 0.0, "rock": 0.0,
	},
	{
		"name": "ICY BLUE",
		"variant": "steep", "floor_width": FLOOR_WIDTH,
		"tree": 0.0, "rail": 0.0, "mogul": 0.0, "ramp": 0.0, "bush": 0.0, "rock": 0.0,
	},
]

# Obstacle spawn weights are evaluated in this order; remaining roll = empty slot.
const OBSTACLE_ORDER := ["tree", "rail", "mogul", "ramp", "bush", "rock", "pole", "big_ramp", "sign"]

const LEVELS := [
	{
		"name": "THE PARK",
		"chunks": 5,
		"fence": true,
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
		"tree": 0.35, "rail": 0.08, "mogul": 0.10, "ramp": 0.03, "bush": 0.20, "rock": 0.00, "sign": 0.12,
	},
	{
		"name": "THE CRAGS",
		"chunks": 5,
		"tree": 0.18, "rail": 0.00, "mogul": 0.00, "ramp": 0.00, "bush": 0.00, "rock": 0.60, "sign": 0.15,
	},
	{
		"name": "THE NARROWS",
		"chunks": 5,
		"floor_width": NARROWS_FLOOR_WIDTH,
		"tree": 0.10, "rail": 0.26, "mogul": 0.17, "ramp": 0.13, "bush": 0.00, "rock": 0.15, "sign": 0.09,
	},
	{
		"name": "THE LIFT AREA",
		"chunks": 5,
		"tree": 0.05, "rail": 0.00, "mogul": 0.40, "ramp": 0.12, "bush": 0.00, "rock": 0.00, "pole": 0.45,
	},
	{
		"name": "BIG AIR",
		"chunks": 5,
		"tree": 0.00, "rail": 0.00, "mogul": 0.00, "ramp": 0.00, "bush": 0.00, "rock": 0.00, "big_ramp": 0.42, "sign": 0.20,
	},
]

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

var _seen_lift_area: bool = false  # true once the player has entered the Lift Area

# Obstacles waiting to be built, one (or a few) per frame; see _build_queued_obstacles
var _build_queue: Array[Dictionary] = []

# Shared resource caches (filled lazily, reused by every chunk)
static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}
static var _shapes: Dictionary = {}
static var _box_meshes: Dictionary = {}   # keyed by size
static var _box_shapes: Dictionary = {}   # keyed by size


func _ready() -> void:
	add_to_group("level_generator")
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.game_started.connect(_reset)
	for i in range(CHUNKS_AHEAD + 1):
		_spawn_chunk()
	_build_queued_obstacles(_build_queue.size())


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if GameManager.state != GameManager.State.PLAYING or not is_instance_valid(player):
		return

	while _spawn_z > player.position.z - CHUNKS_AHEAD * CHUNK_LENGTH:
		_spawn_chunk()
	_build_queued_obstacles(OBSTACLE_BUILDS_PER_FRAME)

	# Advance displayed level when player crosses a lap marker boundary
	var player_chunk := int(-player.position.z / CHUNK_LENGTH)
	while player_chunk > _last_player_chunk:
		_last_player_chunk += 1
		if GameManager.is_tutorial:
			if _last_player_chunk % TUTORIAL_LAP_CHUNKS == 0:
				var stage := _last_player_chunk / TUTORIAL_LAP_CHUNKS
				if stage >= TUTORIAL_STAGE_COUNT:
					tutorial_complete.emit()
				else:
					var cfg: Dictionary = TUTORIAL_LEVELS[stage]
					var variant: String = cfg.get("variant", VARIANT_REGULAR)
					_set_tilt_for_variant(variant)
					GameManager.set_variant(variant)
					tutorial_stage_changed.emit(stage)
					level_changed.emit(cfg["name"], stage + 1)
		elif _last_player_chunk % LAP_CHUNKS == 0:
			_display_level_index = (_display_level_index + 1) % LEVELS.size()
			_display_level_number += 1
			_pick_variant()
			var display_name := _make_display_name(LEVELS[_display_level_index]["name"])
			level_changed.emit(display_name, _display_level_number)
			if _seen_lift_area and not GameManager.is_afternoon:
				GameManager.set_afternoon()
			if "LIFT AREA" in display_name:
				_seen_lift_area = true

	var despawn_z := player.position.z + CHUNKS_BEHIND * CHUNK_LENGTH
	# Chunks are ordered oldest-first, so only the front can be stale; free at most one per frame
	if not _active_chunks.is_empty() and _active_chunks[0].position.z > despawn_z:
		_active_chunks.pop_front().queue_free()


func _spawn_chunk() -> void:
	_chunk_count += 1

	# Derive level from chunk position — same formula as the display side
	var chunk_idx := int(-_spawn_z / CHUNK_LENGTH)
	var cfg: Dictionary
	if GameManager.is_tutorial:
		var stage_idx := mini(chunk_idx / TUTORIAL_LAP_CHUNKS, TUTORIAL_STAGE_COUNT - 1)
		cfg = TUTORIAL_LEVELS[stage_idx]
		var variant: String = cfg.get("variant", VARIANT_REGULAR)
		_set_tilt_for_variant(variant)
	else:
		var level_idx := (chunk_idx / LAP_CHUNKS) % LEVELS.size()
		cfg = LEVELS[level_idx]

	var chunk := _make_chunk(cfg)
	chunk.position.z = _spawn_z
	add_child(chunk)
	_active_chunks.append(chunk)
	_spawn_z -= CHUNK_LENGTH


func _make_chunk(cfg: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Chunk"
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

	if cfg.get("fence", false):
		root.add_child(_make_fence(-1.0))
		root.add_child(_make_fence(1.0))

	_maybe_add_obstacles(root, cfg)
	var _lap_chunk_size := TUTORIAL_LAP_CHUNKS if GameManager.is_tutorial else LAP_CHUNKS
	if _chunk_count % _lap_chunk_size == 0:
		root.add_child(_make_lap_marker())
	return root


func _maybe_add_obstacles(root: Node3D, cfg: Dictionary) -> void:
	# Rolls which obstacle goes in each slot now; the nodes themselves are built later, one per frame.
	var z := -RAMP_MARGIN
	while z > -(CHUNK_LENGTH - RAMP_MARGIN):
		var roll := randf()
		var cumulative := 0.0
		for key: String in OBSTACLE_ORDER:
			cumulative += cfg.get(key, 0.0)
			if roll < cumulative:
				_build_queue.append({
					"root": root, "key": key, "z": z,
					"tilt": _active_tilt_angle, "floor_width": _active_floor_width,
				})
				break
		z -= RAMP_SLOT_SPACING


# Builds up to `count` queued obstacles using the tilt/width that were active when they were queued.
func _build_queued_obstacles(count: int) -> void:
	while count > 0 and not _build_queue.is_empty():
		var job: Dictionary = _build_queue.pop_front()
		var root: Node3D = job["root"]
		if not is_instance_valid(root):
			continue
		count -= 1
		var saved_tilt := _active_tilt_angle
		var saved_width := _active_floor_width
		_active_tilt_angle = job["tilt"]
		_active_floor_width = job["floor_width"]
		_add_obstacle(root, job["key"], job["z"])
		_active_tilt_angle = saved_tilt
		_active_floor_width = saved_width


func _add_obstacle(root: Node3D, key: String, z: float) -> void:
	match key:
		"tree":
			var max_offset := _active_floor_width * 0.5 - TREE_FOLIAGE_RADIUS - 0.5
			var tx := randf_range(-max_offset, max_offset)
			root.add_child(_make_tree_cluster(Vector3(tx, 0.0, z)))
		"rail":
			var length := randf_range(RAIL_LENGTH_MIN, RAIL_LENGTH_MAX)
			var max_offset := _active_floor_width * 0.5 - RAIL_WIDTH_COLLISION * 0.5
			var rx := randf_range(-max_offset, max_offset)
			root.add_child(_make_rail(Vector3(rx, 0.0, z - length * 0.5), length))
		"mogul":
			root.add_child(_make_mogul_field(Vector3(0.0, 0.0, z)))
		"ramp":
			var max_offset := _active_floor_width * 0.5 - RAMP_WIDTH * 0.5
			var rx := randf_range(-max_offset, max_offset)
			var ramp_angle := randf_range(RAMP_ANGLE_MIN, RAMP_ANGLE_MAX)
			var ramp_length := randf_range(RAMP_LENGTH_MIN, RAMP_LENGTH_MAX)
			root.add_child(_make_ramp(Vector3(rx, 0.0, z), ramp_angle, ramp_length))
		"bush":
			var max_offset := _active_floor_width * 0.5 - BUSH_RADIUS - 0.5
			var bx := randf_range(-max_offset, max_offset)
			root.add_child(_make_bush_cluster(Vector3(bx, 0.0, z)))
		"rock":
			var max_offset := _active_floor_width * 0.5 - ROCK_RADIUS_MAX - 0.5
			var rx := randf_range(-max_offset, max_offset)
			root.add_child(_make_rock_cluster(Vector3(rx, 0.0, z)))
		"pole":
			root.add_child(_make_pole_pair(Vector3(0.0, 0.0, z)))
		"big_ramp":
			var scale := randf_range(BIG_RAMP_LENGTH_SCALE_MIN, BIG_RAMP_LENGTH_SCALE_MAX)
			var ramp_angle := randf_range(RAMP_ANGLE_MIN, RAMP_ANGLE_MAX)
			var ramp_length := randf_range(RAMP_LENGTH_MIN, RAMP_LENGTH_MAX) * scale
			var ramp_width := (_active_floor_width + WALL_WIDTH * 2.0) * 0.95
			root.add_child(_make_ramp(Vector3(0.0, 0.0, z), ramp_angle, ramp_length, ramp_width))
		"sign":
			var side := 1.0 if randf() > 0.5 else -1.0
			var sx := side * randf_range(_active_floor_width * 0.3, _active_floor_width * 0.45)
			root.add_child(_make_warning_sign(Vector3(sx, 0.0, z)))


# ── Shared resources ──────────────────────────────────────────────────────────

static func _material(id: StringName) -> StandardMaterial3D:
	if not _materials.has(id):
		_materials[id] = _build_material(id)
	return _materials[id]


static func _build_material(id: StringName) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	match id:
		MAT_SNOW, MAT_SNOW_RAMP:
			mat.albedo_color = SNOW_COLOR
			mat.roughness = SNOW_ROUGHNESS
			if id == MAT_SNOW_RAMP:
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		MAT_RAIL:
			mat.albedo_color = RAIL_COLOR
			mat.metallic = RAIL_METALLIC
			mat.roughness = RAIL_ROUGHNESS
		MAT_SIGN_POST:
			mat.albedo_color = SIGN_POST_COLOR
			mat.roughness = SIGN_POST_ROUGHNESS
		MAT_SIGN_FACE:
			mat.albedo_color = SIGN_COLOR
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		MAT_TRUNK:
			mat.albedo_color = TREE_COLOR_TRUNK
		MAT_FOLIAGE:
			mat.albedo_color = TREE_COLOR_FOLIAGE
		MAT_ROCK:
			mat.albedo_color = ROCK_COLOR
			mat.roughness = ROCK_ROUGHNESS
			mat.metallic = 0.0
		MAT_POLE:
			mat.albedo_color = POLE_COLOR
			mat.roughness = POLE_ROUGHNESS
			mat.metallic = POLE_METALLIC
		MAT_FENCE_RAIL:
			mat.albedo_color = FENCE_RAIL_COLOR
		MAT_LAP:
			mat.albedo_color = LAP_MARKER_COLOR
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


static func _mesh(id: StringName) -> Mesh:
	if not _meshes.has(id):
		_meshes[id] = _build_mesh(id)
	return _meshes[id]


static func _build_mesh(id: StringName) -> Mesh:
	match id:
		MESH_TRUNK:
			return _make_cylinder_mesh(TREE_TRUNK_RADIUS, TREE_TRUNK_RADIUS, TREE_TRUNK_HEIGHT, TREE_RADIAL_SEGMENTS)
		MESH_FOLIAGE:
			return _make_cylinder_mesh(0.0, TREE_FOLIAGE_RADIUS, TREE_FOLIAGE_HEIGHT, TREE_RADIAL_SEGMENTS)
		MESH_BUSH:
			return _make_bush_mesh()
		MESH_MOGUL:
			return _make_mogul_mesh(MOGUL_BASE, MOGUL_HEIGHT, MOGUL_SINK)
		MESH_SIGN_POST:
			return _make_box_mesh(Vector3(SIGN_POST_WIDTH, SIGN_POST_HEIGHT, SIGN_POST_WIDTH))
		MESH_SIGN_FACE:
			return _make_box_mesh(Vector3(SIGN_FACE_SIZE, SIGN_FACE_SIZE, SIGN_FACE_THICK))
		MESH_POLE_SHAFT:
			return _make_box_mesh(Vector3(POLE_SHAFT_WIDTH, POLE_SHAFT_HEIGHT, POLE_SHAFT_WIDTH))
		MESH_POLE_BAR:
			return _make_box_mesh(Vector3(POLE_BAR_LENGTH, POLE_BAR_HEIGHT, POLE_BAR_DEPTH))
		MESH_FENCE_POST:
			return _make_box_mesh(Vector3(FENCE_POST_WIDTH, FENCE_POST_HEIGHT, FENCE_POST_WIDTH))
		MESH_ROCK_BODY:
			return _make_cylinder_mesh(1.0, 1.0, ROCK_BODY_HEIGHT_FACTOR, ROCK_SEGMENTS)
		MESH_ROCK_CAP:
			return _make_cylinder_mesh(0.0, 1.0, ROCK_CAP_HEIGHT_FACTOR, ROCK_SEGMENTS)
	return null


static func _make_cylinder_mesh(top_radius: float, bottom_radius: float, height: float, segments: int) -> CylinderMesh:
	var cyl := CylinderMesh.new()
	cyl.top_radius = top_radius
	cyl.bottom_radius = bottom_radius
	cyl.height = height
	cyl.radial_segments = segments
	return cyl


static func _make_box_mesh(size: Vector3) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	return box


static func _box_mesh(size: Vector3) -> BoxMesh:
	if not _box_meshes.has(size):
		_box_meshes[size] = _make_box_mesh(size)
	return _box_meshes[size]


static func _box_shape(size: Vector3) -> BoxShape3D:
	if not _box_shapes.has(size):
		var shape := BoxShape3D.new()
		shape.size = size
		_box_shapes[size] = shape
	return _box_shapes[size]


static func _shape(id: StringName) -> Shape3D:
	if not _shapes.has(id):
		_shapes[id] = _build_shape(id)
	return _shapes[id]


static func _build_shape(id: StringName) -> Shape3D:
	match id:
		SHAPE_TREE_HIT:
			return _make_cylinder_shape(TREE_TRUNK_RADIUS + TREE_AREA_PADDING, TREE_TRUNK_HEIGHT + TREE_FOLIAGE_HEIGHT)
		SHAPE_TREE_NEAR:
			return _make_sphere_shape(TREE_NEAR_RADIUS)
		SHAPE_BUSH_HIT:
			return _make_cylinder_shape(BUSH_RADIUS * BUSH_AREA_RADIUS_FACTOR, BUSH_HEIGHT)
		SHAPE_BUSH_NEAR:
			return _make_sphere_shape(BUSH_NEAR_RADIUS)
		SHAPE_POLE_HIT:
			var box := BoxShape3D.new()
			box.size = POLE_AREA_SIZE
			return box
		SHAPE_POLE_NEAR:
			return _make_sphere_shape(POLE_NEAR_RADIUS)
		SHAPE_MOGUL:
			var convex := ConvexPolygonShape3D.new()
			convex.points = PackedVector3Array([
				Vector3(-MOGUL_BASE, -MOGUL_SINK,  MOGUL_BASE),
				Vector3( MOGUL_BASE, -MOGUL_SINK,  MOGUL_BASE),
				Vector3(-MOGUL_BASE, -MOGUL_SINK, -MOGUL_BASE),
				Vector3( MOGUL_BASE, -MOGUL_SINK, -MOGUL_BASE),
				Vector3( 0.0,         MOGUL_HEIGHT, 0.0),
			])
			return convex
	return null


static func _make_cylinder_shape(radius: float, height: float) -> CylinderShape3D:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	return shape


static func _make_sphere_shape(radius: float) -> SphereShape3D:
	var shape := SphereShape3D.new()
	shape.radius = radius
	return shape


# Wraps a shape in a CollisionShape3D raised to `y`.
func _make_collision(shape: Shape3D, y: float) -> CollisionShape3D:
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = y
	return col


# Kill zone that watches Jerry (layer 1) and AI riders (layer 2). It is never itself a detection target.
func _make_hit_area(shape: Shape3D, y: float) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 3  # layer 1 (Jerry) + layer 2 (AI riders)
	area.add_child(_make_collision(shape, y))
	return area


func _make_ramp(origin: Vector3, angle: float, length: float, width: float = RAMP_WIDTH) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = origin  # y=0, sits on floor
	body.add_to_group("snow_terrain")

	var w := width
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
	mesh_inst.material_override = _material(MAT_SNOW_RAMP)
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

	var mat := _material(MAT_RAIL)

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

	body.add_child(_make_collision(_shape(SHAPE_MOGUL), 0.0))

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = _mesh(MESH_MOGUL)
	mesh_inst.material_override = _material(MAT_SNOW)
	body.add_child(mesh_inst)

	return body


static func _make_mogul_mesh(b: float, h: float, g: float) -> ArrayMesh:
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


func _make_warning_sign(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.x = _active_tilt_angle

	var post := MeshInstance3D.new()
	post.mesh = _mesh(MESH_SIGN_POST)
	post.material_override = _material(MAT_SIGN_POST)
	post.position.y = SIGN_POST_HEIGHT * 0.5
	root.add_child(post)

	var face := MeshInstance3D.new()
	face.mesh = _mesh(MESH_SIGN_FACE)
	face.material_override = _material(MAT_SIGN_FACE)
	face.position.y = SIGN_POST_HEIGHT + SIGN_FACE_SIZE * 0.5
	face.rotation_degrees.z = SIGN_FACE_ROTATION_DEG
	root.add_child(face)

	return root


# Connects crash detection to hit_area and adds a proximity sphere for close-call scoring.
func _attach_near_miss(root: Node3D, hit_area: Area3D, near_shape: Shape3D, near_y: float) -> void:
	var hit := [false]
	hit_area.body_entered.connect(func(body: Node3D) -> void:
		if body.has_method("crash"):
			hit[0] = true
			body.crash()
	)
	var near := Area3D.new()
	near.collision_layer = 0
	near.collision_mask = 1  # player only
	near.add_child(_make_collision(near_shape, near_y))
	near.body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group("player"): hit[0] = false
	)
	near.body_exited.connect(func(body: Node3D) -> void:
		if body.is_in_group("player"):
			(func():
				if not hit[0]: ScoreManager.add_close_call()
			).call_deferred()
	)
	root.add_child(near)


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
	var trunk_mesh := MeshInstance3D.new()
	trunk_mesh.mesh = _mesh(MESH_TRUNK)
	trunk_mesh.material_override = _material(MAT_TRUNK)
	trunk_mesh.position.y = TREE_TRUNK_HEIGHT * 0.5
	root.add_child(trunk_mesh)

	# Foliage — pointy triangular pyramid
	var foliage_mesh := MeshInstance3D.new()
	foliage_mesh.mesh = _mesh(MESH_FOLIAGE)
	foliage_mesh.material_override = _material(MAT_FOLIAGE)
	foliage_mesh.position.y = TREE_TRUNK_HEIGHT + TREE_FOLIAGE_HEIGHT * 0.5
	root.add_child(foliage_mesh)

	# Crash area — covers the whole tree height
	var center_y := (TREE_TRUNK_HEIGHT + TREE_FOLIAGE_HEIGHT) * 0.5
	var area := _make_hit_area(_shape(SHAPE_TREE_HIT), center_y)
	_attach_near_miss(root, area, _shape(SHAPE_TREE_NEAR), center_y)
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
	mesh_inst.mesh = _mesh(MESH_BUSH)
	mesh_inst.material_override = _material(MAT_FOLIAGE)
	root.add_child(mesh_inst)

	var area := _make_hit_area(_shape(SHAPE_BUSH_HIT), BUSH_HEIGHT * 0.5)
	_attach_near_miss(root, area, _shape(SHAPE_BUSH_NEAR), BUSH_HEIGHT * 0.5)
	root.add_child(area)

	return root


static func _make_bush_mesh() -> ArrayMesh:
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
	var rock_mat := _material(MAT_ROCK)

	# Hexagonal prism body (shared unit-radius mesh, scaled uniformly to this crystal's radius)
	var body_mesh := MeshInstance3D.new()
	body_mesh.mesh = _mesh(MESH_ROCK_BODY)
	body_mesh.material_override = rock_mat
	body_mesh.scale = Vector3.ONE * radius
	body_mesh.position.y = body_h * 0.5 - ROCK_SINK
	root.add_child(body_mesh)

	# Pointed cap
	var cap_mesh := MeshInstance3D.new()
	cap_mesh.mesh = _mesh(MESH_ROCK_CAP)
	cap_mesh.material_override = rock_mat
	cap_mesh.scale = Vector3.ONE * radius
	cap_mesh.position.y = body_h + cap_h * 0.5 - ROCK_SINK
	root.add_child(cap_mesh)

	# Crash area (radius varies per crystal, so these shapes are not shared)
	var center_y := (body_h + cap_h) * 0.5 - ROCK_SINK
	var area := _make_hit_area(_make_cylinder_shape(radius, body_h + cap_h), center_y)
	_attach_near_miss(root, area, _make_sphere_shape(radius + ROCK_NEAR_PADDING), center_y)
	root.add_child(area)

	return root


func _make_pole_pair(center: Vector3) -> Node3D:
	var cluster := Node3D.new()
	cluster.position = center
	cluster.add_child(_make_pole(Vector3(-POLE_PAIR_SPREAD * 0.5, 0.0, 0.0)))
	cluster.add_child(_make_pole(Vector3( POLE_PAIR_SPREAD * 0.5, 0.0, 0.0)))
	return cluster


func _make_pole(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.x = _active_tilt_angle
	var pole_mat := _material(MAT_POLE)

	# Vertical shaft
	var shaft_mesh := MeshInstance3D.new()
	shaft_mesh.mesh = _mesh(MESH_POLE_SHAFT)
	shaft_mesh.material_override = pole_mat
	shaft_mesh.position.y = POLE_SHAFT_HEIGHT * 0.5 - POLE_SINK
	root.add_child(shaft_mesh)

	# Horizontal crossbar at top
	var bar_mesh := MeshInstance3D.new()
	bar_mesh.mesh = _mesh(MESH_POLE_BAR)
	bar_mesh.material_override = pole_mat
	bar_mesh.position.y = POLE_SHAFT_HEIGHT - POLE_SINK
	root.add_child(bar_mesh)

	# Crash area — box covering the lower portion of the shaft where riders pass through
	var area_y := POLE_AREA_CENTER_Y - POLE_SINK
	var area := _make_hit_area(_shape(SHAPE_POLE_HIT), area_y)
	_attach_near_miss(root, area, _shape(SHAPE_POLE_NEAR), area_y)
	root.add_child(area)

	return root


# Solid fence along the top of one bank (side = -1 left, 1 right).
func _make_fence(side: float) -> StaticBody3D:
	var root := StaticBody3D.new()
	var along := WALL_WIDTH - FENCE_EDGE_INSET
	root.position = Vector3(side * (_active_floor_width * 0.5 + along * cos(WALL_ANGLE)), along * sin(WALL_ANGLE), 0.0)
	var tilt := deg_to_rad(_active_tilt_angle)
	var upright := Basis(Vector3.RIGHT, tilt)  # same lean as trees/signs/poles
	var rail_pitch := tilt * FENCE_RAIL_ANGLE_SCALE
	var rail_basis := Basis(Vector3.RIGHT, rail_pitch)
	# Rail climbs `step` up the next post over `spacing`: step = spacing * sin(pitch) / cos(tilt - pitch)
	var step_per_meter := sin(rail_pitch) / cos(tilt - rail_pitch)
	# Posts divide the chunk evenly so the pattern lines up across chunk seams
	var post_count := ceili(CHUNK_LENGTH / minf(FENCE_POST_SPACING, FENCE_MAX_STEP / step_per_meter))
	var spacing := CHUNK_LENGTH / post_count
	# Each rail runs from one post until it meets the next post downhill, then steps down
	var rail_length := spacing * cos(tilt) / cos(tilt - rail_pitch)

	var posts: Array[Transform3D] = []
	var rails: Array[Transform3D] = []
	for i in range(post_count):
		var base := Vector3(0.0, 0.0, -i * spacing)
		posts.append(Transform3D(upright, base + upright * Vector3(0.0, FENCE_POST_HEIGHT * 0.5 - FENCE_POST_SINK, 0.0)))
		for h: float in FENCE_RAIL_HEIGHTS:
			rails.append(Transform3D(rail_basis, base + upright * Vector3(0.0, h, 0.0) + rail_basis * Vector3(0.0, 0.0, -rail_length * 0.5)))
	root.add_child(_make_multimesh(_mesh(MESH_FENCE_POST), _material(MAT_SIGN_POST), posts))
	root.add_child(_make_multimesh(_box_mesh(Vector3(FENCE_RAIL_THICK, FENCE_RAIL_THICK, rail_length)), _material(MAT_FENCE_RAIL), rails))

	# One upright box the full chunk length; the tilt only shifts the fence along Z, which the box already spans
	var wall_h := FENCE_POST_HEIGHT * cos(tilt) - FENCE_POST_SINK
	var col := CollisionShape3D.new()
	col.shape = _box_shape(Vector3(FENCE_COLLISION_THICK, wall_h, CHUNK_LENGTH))
	col.position = Vector3(0.0, wall_h * 0.5, -CHUNK_LENGTH * 0.5)
	root.add_child(col)

	return root


func _make_multimesh(mesh: Mesh, mat: Material, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	return mmi


func _make_lap_marker() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh(Vector3(_active_floor_width, LAP_MARKER_HEIGHT, LAP_MARKER_DEPTH))
	mi.position = Vector3(0.0, LAP_MARKER_HEIGHT, -(CHUNK_LENGTH - LAP_MARKER_DEPTH * 0.5))
	mi.material_override = _material(MAT_LAP)
	return mi


func _make_panel(pos: Vector3, rot_z: float, size: Vector3, is_snow_terrain: bool = false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.z = rot_z
	if is_snow_terrain:
		body.add_to_group("snow_terrain")

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = _box_mesh(size)
	if is_snow_terrain:
		mesh_inst.material_override = _material(MAT_SNOW)
	body.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	col.shape = _box_shape(size)
	body.add_child(col)

	return body


func _set_tilt_for_variant(variant: String) -> void:
	_active_tilt_angle = STEEP_TILT_ANGLE if variant == VARIANT_STEEP else DOWNHILL_TILT_ANGLE


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
	_set_tilt_for_variant(_active_variant)
	GameManager.set_variant(_active_variant)
	variant_changed.emit(_active_variant)


func _make_display_name(base: String) -> String:
	# Inserts the variant prefix after "THE " — e.g. "THE MISTY PARK", "THE STEEP RUNS"
	match _active_variant:
		VARIANT_MISTY:    return "THE MISTY " + base.substr(4)
		VARIANT_STEEP:    return "THE STEEP " + base.substr(4)
		VARIANT_CLEAR:  return "THE CLEAR " + base.substr(4)
		_: return base


func _on_state_changed(_new_state: GameManager.State) -> void:
	pass


func _reset() -> void:
	_build_queue.clear()
	for chunk in _active_chunks:
		chunk.queue_free()
	_active_chunks.clear()
	_spawn_z = 0.0
	_chunk_count = 0
	_display_level_index = 0
	_display_level_number = 1
	_last_player_chunk = 0
	_seen_lift_area = false
	if GameManager.is_tutorial:
		var cfg: Dictionary = TUTORIAL_LEVELS[0]
		var variant: String = cfg.get("variant", VARIANT_REGULAR)
		_set_tilt_for_variant(variant)
		GameManager.set_variant(variant)
		for i in range(CHUNKS_AHEAD + 1):
			_spawn_chunk()
		_build_queued_obstacles(_build_queue.size())
		level_changed.emit(TUTORIAL_LEVELS[0]["name"], 1)
		tutorial_stage_changed.emit(0)
	else:
		_pick_variant()
		for i in range(CHUNKS_AHEAD + 1):
			_spawn_chunk()
		_build_queued_obstacles(_build_queue.size())
		level_changed.emit(_make_display_name(LEVELS[0]["name"]), 1)
