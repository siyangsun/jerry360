extends CharacterBody3D

@export var lateral_accel := 22.0
@export var lateral_friction := 16.0
@export var lateral_counter_decel := 85.0
@export var max_lateral_speed := 13.0
@export var jump_velocity := 10.0
@export var gravity := 24.0
@export var wall_gravity := 18.0

const AIR_SPIN_SPEED := 2.0    # rad/s of yaw input can apply in air
const BOOST_AMOUNT := 2.0      # multiplier on accel/decel after landing trick
const BOOST_DURATION := 1.5    # seconds the boost lasts
const BOOST_THRESHOLD := 0.15  # minimum air spin (rad) to earn a boost

var _is_dead: bool = false
var _was_on_floor: bool = false
var _air_spin_y: float = 0.0
var _boost_multiplier: float = 1.0
var _boost_timer: float = 0.0
var _smooth_vel_x: float = 0.0

@onready var mesh_pivot: Node3D = $MeshPivot


func _ready() -> void:
	add_to_group("player")
	GameManager.state_changed.connect(_on_state_changed)


func _physics_process(delta: float) -> void:
	if _is_dead or GameManager.state != GameManager.State.PLAYING:
		return

	_handle_lateral(delta)
	_handle_jump()
	_apply_gravity(delta)

	velocity.z = -GameManager.current_speed
	move_and_slide()

	_apply_wall_gravity(delta)
	_handle_air_spin(delta)
	_handle_landing()
	_tick_boost(delta)

	if position.y < -50.0:
		_fall_off()
		return

	# Smooth velocity for visuals — filters out rapid physics jitter
	_smooth_vel_x = lerpf(_smooth_vel_x, velocity.x, 10.0 * delta)

	# Visual tilt and yaw — velocity-based on ground, spin-based in air
	if is_instance_valid(mesh_pivot):
		mesh_pivot.rotation.z = lerpf(mesh_pivot.rotation.z, -_smooth_vel_x * 0.02, 10.0 * delta)
		if is_on_floor():
			mesh_pivot.rotation.y = lerpf(mesh_pivot.rotation.y, -_smooth_vel_x * 0.05, 10.0 * delta)

	ScoreManager.add_distance(GameManager.current_speed * delta)


func _handle_lateral(delta: float) -> void:
	if not is_on_floor():
		return
	var input := Input.get_axis("move_left", "move_right")
	var accel_mult := _boost_multiplier
	if input != 0.0:
		if velocity.x * input < 0.0:
			velocity.x = move_toward(velocity.x, 0.0, lateral_counter_decel * accel_mult * delta)
		else:
			velocity.x = clampf(velocity.x + input * lateral_accel * accel_mult * delta, -max_lateral_speed, max_lateral_speed)
	else:
		velocity.x = move_toward(velocity.x, 0.0, lateral_friction * accel_mult * delta)


func _handle_jump() -> void:
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta


func _apply_wall_gravity(delta: float) -> void:
	if not is_on_floor():
		return
	if abs(get_floor_normal().x) > 0.2:
		velocity.x -= sign(position.x) * wall_gravity * delta


func _handle_air_spin(delta: float) -> void:
	if is_on_floor():
		return
	var input := Input.get_axis("move_left", "move_right")
	_air_spin_y -= input * AIR_SPIN_SPEED * delta
	if is_instance_valid(mesh_pivot):
		mesh_pivot.rotation.y = lerpf(mesh_pivot.rotation.y, _air_spin_y, 8.0 * delta)


func _handle_landing() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		if abs(_air_spin_y) >= BOOST_THRESHOLD:
			_boost_multiplier = BOOST_AMOUNT
			_boost_timer = BOOST_DURATION
		_air_spin_y = 0.0
	_was_on_floor = on_floor


func _tick_boost(delta: float) -> void:
	if _boost_timer <= 0.0:
		return
	_boost_timer -= delta
	if _boost_timer <= 0.0:
		_boost_timer = 0.0
		_boost_multiplier = 1.0
	else:
		_boost_multiplier = lerpf(1.0, BOOST_AMOUNT, _boost_timer / BOOST_DURATION)


func _fall_off() -> void:
	if _is_dead:
		return
	_is_dead = true
	velocity = Vector3.ZERO
	GameManager.player_died()


func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	velocity = Vector3.ZERO
	GameManager.player_died()


func _on_state_changed(new_state: GameManager.State) -> void:
	if new_state == GameManager.State.PLAYING:
		_is_dead = false
		velocity = Vector3.ZERO
		position = Vector3(0.0, 3.0, 0.0)
		_air_spin_y = 0.0
		_boost_multiplier = 1.0
		_boost_timer = 0.0
		_was_on_floor = false
		_smooth_vel_x = 0.0
