extends CharacterBody3D

const GRAVITY := 24.0
const LANE_WIDTH := 2.5
const LANE_POSITIONS := [-LANE_WIDTH, 0.0, LANE_WIDTH]
const LATERAL_LERP_SPEED := 3.5
const LANE_SWITCH_INTERVAL_MIN := 3.0
const LANE_SWITCH_INTERVAL_MAX := 9.0
const SPEED_VARIANCE_MIN := 0.82
const SPEED_VARIANCE_MAX := 1.08

const BODY_CENTER_Y := 0.5
const BOARD_CENTER_Y := 0.04
const GOOFY_CHANCE := 0.3                       # fraction of grommets riding goofy (jacket faces -X)
const COLLIDER_RADIUS := 0.3                    # solid capsule (matches Jerry's)
const COLLIDER_HEIGHT := 1.0
const HIT_AREA_RADIUS := 0.42                   # kill-zone capsule that crashes Jerry
const HIT_AREA_HEIGHT := 1.2

# Wipeout parameters — read from Jerry's node in _ready() so they stay in sync
var _wipeout_duration: float     = 2.2
var _wipeout_brake_rate: float   = 40.0
var _wipeout_lateral_decel: float = 30.0
var _wipeout_fall_pitch: float   = -1.3
var _wipeout_wobble_freq: float  = 14.0
var _wipeout_wobble_amp: float   = 0.7
var _wipeout_phase1_end: float   = 0.35
var _wipeout_phase2_end: float   = 0.75

# Shared across every rider (meshes/materials are cached in AppearanceManager)
static var _collider_shape: CapsuleShape3D
static var _hit_area_shape: CapsuleShape3D

var _speed_variance: float = 1.0
var _target_lane: int = 1
var _lane_switch_timer: float = 0.0

var _is_crashed: bool = false
var _crash_timer: float = 0.0
var _crash_speed: float = 0.0  # rider's own speed during the crash deceleration

var _mesh_pivot: Node3D
var _you_good_label: Label3D = null


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
		player.wipeout_getting_up.connect(_on_jerry_getting_up)
		_wipeout_duration      = player.wipeout_duration
		_wipeout_brake_rate    = player.wipeout_brake_rate
		_wipeout_lateral_decel = player.wipeout_lateral_decel
		_wipeout_fall_pitch    = player.wipeout_fall_pitch
		_wipeout_wobble_freq   = player.wipeout_wobble_freq
		_wipeout_wobble_amp    = player.wipeout_wobble_amp
		_wipeout_phase1_end    = player.wipeout_phase1_end
		_wipeout_phase2_end    = player.wipeout_phase2_end

	_build_visuals()
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


## Each part rolls independently from the same lists Jerry picks from; never the sponsored board.
func _build_visuals() -> void:
	_mesh_pivot = Node3D.new()
	add_child(_mesh_pivot)

	var body := Node3D.new()
	body.position.y = BODY_CENTER_Y
	if randf() < GOOFY_CHANCE:
		body.rotation.y = PI  # carries the jacket/goggle face to -X without mirroring it
	_mesh_pivot.add_child(body)
	AppearanceManager.build_rider_body(body,
		randi() % AppearanceManager.JACKET_COLORS.size(),
		randi() % AppearanceManager.HELMET_COLORS.size(),
		randi() % AppearanceManager.PANTS_COLORS.size(),
		randi() % AppearanceManager.GOGGLE_HUE_SHIFTS.size())

	var board := Node3D.new()
	board.position.y = BOARD_CENTER_Y
	_mesh_pivot.add_child(board)
	AppearanceManager.build_board(board, randi() % AppearanceManager.grommet_board_count())


static func _get_capsule(radius: float, height: float) -> CapsuleShape3D:
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	return shape


func _on_jerry_getting_up() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	if global_position.distance_to(player.global_position) > 15.0:
		return
	if is_instance_valid(_you_good_label):
		return
	_you_good_label = Label3D.new()
	_you_good_label.text = "you good?"
	_you_good_label.font_size = 32
	_you_good_label.modulate = Color(1.0, 1.0, 1.0, 0.9)
	_you_good_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_you_good_label.no_depth_test = true
	_you_good_label.pixel_size = 0.008
	_you_good_label.position = Vector3(0.0, 2.0, 0.0)
	add_child(_you_good_label)
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(_you_good_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(_you_good_label.queue_free)


func _build_collision() -> void:
	if _collider_shape == null:
		_collider_shape = _get_capsule(COLLIDER_RADIUS, COLLIDER_HEIGHT)
		_hit_area_shape = _get_capsule(HIT_AREA_RADIUS, HIT_AREA_HEIGHT)

	var col := CollisionShape3D.new()
	col.position.y = BODY_CENTER_Y
	col.shape = _collider_shape
	add_child(col)

	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	var area_col := CollisionShape3D.new()
	area_col.position.y = BODY_CENTER_Y
	area_col.shape = _hit_area_shape
	area.add_child(area_col)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body.has_method("crash"):
			body.crash()
	)
	add_child(area)
