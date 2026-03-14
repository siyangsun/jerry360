extends CharacterBody3D

const GRAVITY := 24.0
const LANE_WIDTH := 2.5
const LANE_POSITIONS := [-LANE_WIDTH, 0.0, LANE_WIDTH]
const LATERAL_LERP_SPEED := 3.5
const LANE_SWITCH_INTERVAL_MIN := 3.0
const LANE_SWITCH_INTERVAL_MAX := 9.0
const SPEED_VARIANCE_MIN := 0.82
const SPEED_VARIANCE_MAX := 1.08

const RIDER_COLORS: Array[Color] = [
	Color(1.0, 0.45, 0.05),   # burnt orange
	Color(0.12, 0.22, 0.75),  # navy
	Color(0.85, 0.08, 0.12),  # cherry
	Color(0.08, 0.55, 0.18),  # pine
]

# Wipeout parameters — read from Jerry's node in _ready() so they stay in sync
var _wipeout_duration: float     = 2.2
var _wipeout_brake_rate: float   = 40.0
var _wipeout_lateral_decel: float = 30.0
var _wipeout_fall_pitch: float   = -1.3
var _wipeout_wobble_freq: float  = 14.0
var _wipeout_wobble_amp: float   = 0.7
var _wipeout_phase1_end: float   = 0.35
var _wipeout_phase2_end: float   = 0.75

var _speed_variance: float = 1.0
var _target_lane: int = 1
var _lane_switch_timer: float = 0.0

var _is_crashed: bool = false
var _crash_timer: float = 0.0
var _crash_speed: float = 0.0  # rider's own speed during the crash deceleration

var _mesh_pivot: Node3D


func _ready() -> void:
	add_to_group("ai_rider")
	collision_layer = 2
	collision_mask = 1
	_target_lane = randi() % 3
	position.x = LANE_POSITIONS[_target_lane]
	_speed_variance = randf_range(SPEED_VARIANCE_MIN, SPEED_VARIANCE_MAX)
	_lane_switch_timer = randf_range(LANE_SWITCH_INTERVAL_MIN, LANE_SWITCH_INTERVAL_MAX)

	# Read wipeout vars from Jerry so any Inspector tweaks on the player propagate here too
	var player := get_tree().get_first_node_in_group("player")
	if player:
		_wipeout_duration      = player.wipeout_duration
		_wipeout_brake_rate    = player.wipeout_brake_rate
		_wipeout_lateral_decel = player.wipeout_lateral_decel
		_wipeout_fall_pitch    = player.wipeout_fall_pitch
		_wipeout_wobble_freq   = player.wipeout_wobble_freq
		_wipeout_wobble_amp    = player.wipeout_wobble_amp
		_wipeout_phase1_end    = player.wipeout_phase1_end
		_wipeout_phase2_end    = player.wipeout_phase2_end

	var color := RIDER_COLORS[randi() % RIDER_COLORS.size()]
	_build_visuals(color)
	_build_collision()


func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return

	if _is_crashed:
		_handle_crash(delta)
		return

	velocity.z = -GameManager.current_speed * _speed_variance

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	var target_x: float = LANE_POSITIONS[_target_lane]
	position.x = lerp(position.x, target_x, LATERAL_LERP_SPEED * delta)

	_lane_switch_timer -= delta
	if _lane_switch_timer <= 0.0:
		_pick_new_lane()
		_lane_switch_timer = randf_range(LANE_SWITCH_INTERVAL_MIN, LANE_SWITCH_INTERVAL_MAX)

	move_and_slide()


func crash() -> void:
	if _is_crashed:
		return
	_is_crashed = true
	_crash_timer = _wipeout_duration
	_crash_speed = GameManager.current_speed * _speed_variance


func _handle_crash(delta: float) -> void:
	_crash_timer -= delta
	_crash_speed = maxf(_crash_speed - _wipeout_brake_rate * delta, 0.0)
	velocity.z = -_crash_speed
	velocity.x = move_toward(velocity.x, 0.0, _wipeout_lateral_decel * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()

	if is_instance_valid(_mesh_pivot):
		var t := 1.0 - (_crash_timer / _wipeout_duration)
		if t < _wipeout_phase1_end:
			_mesh_pivot.rotation.x = lerpf(_mesh_pivot.rotation.x, _wipeout_fall_pitch, 12.0 * delta)
			_mesh_pivot.rotation.z = lerpf(_mesh_pivot.rotation.z, sin(_crash_timer * _wipeout_wobble_freq) * _wipeout_wobble_amp, 8.0 * delta)
		elif t < _wipeout_phase2_end:
			_mesh_pivot.rotation.x = lerpf(_mesh_pivot.rotation.x, -PI / 2.0, 5.0 * delta)
			_mesh_pivot.rotation.z = lerpf(_mesh_pivot.rotation.z, 0.0, 5.0 * delta)
		else:
			_mesh_pivot.rotation.x = lerpf(_mesh_pivot.rotation.x, 0.0, 5.0 * delta)
			_mesh_pivot.rotation.z = lerpf(_mesh_pivot.rotation.z, 0.0, 5.0 * delta)

	if _crash_timer <= 0.0:
		_end_crash()


func _end_crash() -> void:
	_is_crashed = false
	_crash_timer = 0.0
	if is_instance_valid(_mesh_pivot):
		_mesh_pivot.rotation = Vector3.ZERO
	# Re-randomize lane so rider doesn't resume into whatever they crashed on
	_target_lane = randi() % 3
	_lane_switch_timer = randf_range(LANE_SWITCH_INTERVAL_MIN, LANE_SWITCH_INTERVAL_MAX)


func _pick_new_lane() -> void:
	var options: Array[int] = []
	if _target_lane > 0:
		options.append(_target_lane - 1)
	if _target_lane < 2:
		options.append(_target_lane + 1)
	if options.size() > 0:
		_target_lane = options[randi() % options.size()]


func _build_visuals(color: Color) -> void:
	_mesh_pivot = Node3D.new()
	add_child(_mesh_pivot)

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = color
	body_mat.metallic = 0.9
	body_mat.metallic_specular = 1.0
	body_mat.roughness = 0.05

	var body_mesh := MeshInstance3D.new()
	var body_box := BoxMesh.new()
	body_box.size = Vector3(0.3, 1.0, 0.6)
	body_box.material = body_mat
	body_mesh.mesh = body_box
	body_mesh.position.y = 0.5
	_mesh_pivot.add_child(body_mesh)

	var board_mat := StandardMaterial3D.new()
	board_mat.albedo_color = Color(0.18, 0.18, 0.18)
	board_mat.roughness = 1.0

	var board_mesh := MeshInstance3D.new()
	var board_box := BoxMesh.new()
	board_box.size = Vector3(0.55, 0.08, 1.44)
	board_box.material = board_mat
	board_mesh.mesh = board_box
	board_mesh.position.y = 0.04
	_mesh_pivot.add_child(board_mesh)


func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.0
	col.position.y = 0.5
	col.shape = shape
	add_child(col)

	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	var area_col := CollisionShape3D.new()
	var area_shape := CapsuleShape3D.new()
	area_shape.radius = 0.42
	area_shape.height = 1.2
	area_col.position.y = 0.5
	area_col.shape = area_shape
	area.add_child(area_col)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body.has_method("crash"):
			body.crash()
	)
	add_child(area)
