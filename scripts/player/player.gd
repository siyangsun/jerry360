extends CharacterBody3D

# ── Feel parameters — tunable in Inspector ───────────────────────────────────
@export var lateral_accel := 22.0
@export var lateral_friction := 16.0
@export var lateral_counter_decel := 100.0
@export var max_lateral_speed := 13.0
@export var lean_max_lateral := 3.5        # max lateral speed contribution from lean (A/D)
@export var jump_velocity := 10.0
@export var wall_gravity := 18.0
@export var air_lean_friction_factor := 0.4   # fraction of lateral_friction applied in air
@export var rail_jump_lateral_factor := 0.7   # lateral speed fraction when jumping off rail/wall
@export var conflict_opposing_threshold := 0.09  # |lean×turn| below this = conflict
@export var conflict_decay_rate := 2.0           # how fast conflict timer drains when not conflicting
@export var crash_threshold_slow_deg := 75.0     # max overshoot angle (degrees) at base speed
@export var crash_threshold_fast_deg := 45.0     # max overshoot angle (degrees) at max speed
@export var wipeout_lateral_decel := 30.0        # lateral decel rate during wipeout slide
@export var lean_tilt_visual_scale := 0.28       # body roll per unit of lean input
@export var lean_vel_tilt_visual_scale := 0.016  # body roll per unit of lean velocity
@export var air_spin_lerp_speed := 8.0           # how snappily the mesh follows air spin
@export var wipeout_danger_dead_zone := 0.05     # min intensity change to emit wipeout_danger signal
@export var wipeout_fall_pitch := -1.3           # forward pitch angle during wipeout tumble
@export var wipeout_wobble_freq := 14.0          # wobble oscillation frequency during tumble
@export var wipeout_wobble_amp := 0.7            # wobble roll amplitude during tumble
@export var wipeout_phase1_end := 0.35           # t where tumble transitions to flat spin
@export var wipeout_phase2_end := 0.75           # t where flat spin transitions to recovery
@export var air_turn_speed := 4.0       # rad/s of turn input (arrows) in air — spin/tricks
@export var air_lean_force := 4.0       # lateral accel from lean input (A/D) in air
@export var boost_amount := 2.0         # multiplier on accel/decel after landing trick
@export var boost_duration := 1.5       # seconds the boost lasts
@export var boost_threshold := 0.15     # minimum air spin (rad) to earn a boost
@export var recovery_yaw_min := 0.10      # yaw diff below which recovery is done
@export var recovery_lerp_speed := 1.8    # yaw correction speed during recovery
@export var recovery_speed_drain := 2.0   # forward speed lost per second while recovering
@export var recovery_lateral_factor := 0.15  # fraction of forward speed pushed sideways on landing
@export var turn_burst_yaw := 0.03           # yaw snap per frame on initial turn press (rad)
@export var turn_burst_bank := 0.025         # bank snap per frame on initial turn press (rad)
@export var turn_burst_frames := 5           # number of frames the burst lasts
@export var turn_burst_accel_factor := 0.5   # lean accel multiplier during burst
@export var lean_forward_accel := 6.0
@export var lean_forward_angle := -0.22
@export var lean_forward_lateral_mult := 0.5
@export var lean_forward_recovery_yaw := 0.05
@export var lean_back_angle := 0.22
@export var lean_back_brake := 8.0
@export var lean_back_max_reverse := 2.0
@export var lean_back_recover_rate := 10.0
@export var rail_speed_drain := 3.0
@export var snow_terrain_speed_drain := 4.0
@export var lean_forward_max_speed := 55.0
@export var lean_boost_decay := 15.0
@export var min_trick_air_time := 0.3
@export var min_trick_spin := 0.8
@export var stomp_threshold := PI / 12.0
@export var sloppy_speed_penalty := 15.0
@export var wipeout_duration := 2.2
@export var wipeout_brake_rate := 40.0
@export var land_tilt_wipeout := 4.2    # lean_vel_x magnitude at landing that causes wipeout
@export var board_turn_speed := 1.0       # rad/s board yaw rotation on ground (arrows)
@export var board_turn_max := 0.35        # max board yaw offset from forward (~20°)
@export var board_turn_return := 3.0      # rad/s return-to-center when no turn input
@export var board_turn_accel := 5.0       # rad/s² ramp-up when pressing turn
@export var board_turn_brake := 9.0       # rad/s² ramp-down when releasing turn
@export var conflict_wipeout_time := 0.45 # seconds of opposing lean+turn before wipeout
@export var conflict_min_speed := 14.0    # minimum speed for conflict wipeout

# ── Physics laws — do not tune ────────────────────────────────────────────────
const GRAVITY := 24.0
const WALL_NORMAL_THRESHOLD := 0.2         # floor normal x above this triggers wall physics

enum WipeoutReason { NONE, CONFLICT, AIR_YAW, AIR_TILT }

signal stance_changed(goofy: bool)
signal wipeout_danger(intensity: float, reason: WipeoutReason)

var is_goofy: bool = false
var _is_dead: bool = false
var _was_on_floor: bool = false
var _air_spin_y: float = 0.0
var _air_time: float = 0.0
var _is_wiping_out: bool = false
var _wipeout_timer: float = 0.0
var _rail_spin_acc: float = 0.0
var _rail_tricks: int = 0
var _was_on_rail: bool = false
var _was_on_snow: bool = false
var _boost_multiplier: float = 1.0
var _boost_timer: float = 0.0
var _smooth_vel_x: float = 0.0
var _spark_particles: GPUParticles3D
var _snow_particles: GPUParticles3D
var _yaw_recovery: bool = false
var _is_leaning_fwd: bool = false
var _is_leaning_back: bool = false
var _turn_burst_frames: int = 0
var _turn_burst_dir: float = 0.0

var _board_yaw: float = 0.0    # board facing angle offset from world forward (rad, + = right)
var _board_yaw_vel: float = 0.0  # current angular velocity of board yaw (rad/s)
var _lean_vel_x: float = 0.0   # lean-only lateral velocity contribution
var _conflict_timer: float = 0.0
var _wipeout_danger_intensity: float = 0.0
var _wipeout_danger_reason: WipeoutReason = WipeoutReason.NONE

@onready var mesh_pivot: Node3D = $MeshPivot
@onready var snowboard_mesh: MeshInstance3D = $SnowboardMesh


func _ready() -> void:
	add_to_group("player")
	GameManager.state_changed.connect(_on_state_changed)
	_spark_particles = _make_spark_particles()
	add_child(_spark_particles)
	_snow_particles = _make_snow_particles()
	add_child(_snow_particles)


func _physics_process(delta: float) -> void:
	if _is_dead or GameManager.state != GameManager.State.PLAYING:
		return

	if _is_wiping_out:
		_handle_wipeout(delta)
		return

	_is_leaning_fwd = is_on_floor() and Input.is_action_pressed("lean_forward")
	_is_leaning_back = is_on_floor() and Input.is_action_pressed("lean_back") and not _is_leaning_fwd

	_handle_lean(delta)
	_handle_board_turn(delta)
	_handle_jump()
	_handle_rail_lock(delta)
	_apply_gravity(delta)

	# Compose movement vector from board direction + lean lateral bias
	var board_vel_x := sin(_board_yaw) * GameManager.current_speed
	velocity.x = board_vel_x + _lean_vel_x
	velocity.z = -cos(_board_yaw) * GameManager.current_speed
	move_and_slide()

	# Recover lean contribution after collision response
	_lean_vel_x = velocity.x - sin(_board_yaw) * GameManager.current_speed

	if not is_on_floor():
		_air_time += delta

	_apply_wall_gravity(delta)
	_handle_air_spin(delta)
	_handle_landing()
	_handle_lean_forward(delta)
	_handle_lean_back(delta)
	_handle_snow_terrain_drag(delta)
	_tick_boost(delta)
	_evaluate_wipeout_danger(delta)

	if not _is_leaning_fwd and is_on_floor() and GameManager.current_speed > GameManager.MAX_SPEED:
		GameManager.current_speed = maxf(GameManager.current_speed - lean_boost_decay * delta, GameManager.MAX_SPEED)

	var turn_input := Input.get_axis("move_left", "move_right")
	var lean_input := Input.get_axis("lean_left", "lean_right")
	GameManager.ramp_multiplier = 1.0 if (abs(turn_input) > 0.1 or abs(lean_input) > 0.1) else GameManager.STRAIGHT_RAMP_MULT

	var on_rail := _is_on_rail()
	_spark_particles.emitting = on_rail
	if on_rail != _was_on_rail:
		SfxManager.set_grinding(on_rail)
		_was_on_rail = on_rail

	var want_continuous_snow := (_yaw_recovery or _is_leaning_back) and is_on_floor()
	if want_continuous_snow:
		if _snow_particles.one_shot:
			_snow_particles.one_shot = false
			_snow_particles.explosiveness = 0.0
		_snow_particles.emitting = true
	elif not _snow_particles.one_shot:
		_snow_particles.emitting = false
		_snow_particles.one_shot = true
		_snow_particles.explosiveness = 1.0

	if position.y < -50.0:
		_fall_off()
		return

	_smooth_vel_x = lerpf(_smooth_vel_x, velocity.x, 10.0 * delta)

	# Visual tilt and yaw — lean (A/D) drives body roll, turn (arrows) drives board yaw
	if is_instance_valid(mesh_pivot):
		if not _is_leaning_fwd and not _is_leaning_back and not _is_on_rail():
			if Input.is_action_just_pressed("move_right"):
				_turn_burst_frames = turn_burst_frames
				_turn_burst_dir = 1.0
			elif Input.is_action_just_pressed("move_left"):
				_turn_burst_frames = turn_burst_frames
				_turn_burst_dir = -1.0
			if _turn_burst_frames > 0:
				mesh_pivot.rotation.z -= _turn_burst_dir * turn_burst_bank
				mesh_pivot.rotation.y -= _turn_burst_dir * turn_burst_yaw
				_turn_burst_frames -= 1

		var lean_target := -lean_input * lean_tilt_visual_scale - _lean_vel_x * lean_vel_tilt_visual_scale
		mesh_pivot.rotation.z = lerpf(mesh_pivot.rotation.z, lean_target, 10.0 * delta)
		var pitch_target := 0.0
		if _is_leaning_fwd:
			pitch_target = lean_forward_angle
		elif _is_leaning_back:
			pitch_target = lean_back_angle
		mesh_pivot.rotation.x = lerpf(mesh_pivot.rotation.x, pitch_target, 10.0 * delta)
		if is_instance_valid(snowboard_mesh):
			snowboard_mesh.rotation.y = mesh_pivot.rotation.y
			snowboard_mesh.rotation.z = mesh_pivot.rotation.z
		if is_on_floor():
			if not _is_on_rail():
				var stance_offset := PI if is_goofy else 0.0
				var ground_yaw := stance_offset - _board_yaw
				var yaw_min := lean_forward_recovery_yaw if _is_leaning_fwd else recovery_yaw_min
				if _yaw_recovery:
					var yaw_diff := absf(mesh_pivot.rotation.y - ground_yaw)
					if yaw_diff > yaw_min:
						mesh_pivot.rotation.y = lerpf(mesh_pivot.rotation.y, ground_yaw, recovery_lerp_speed * delta)
						GameManager.current_speed = maxf(GameManager.current_speed - recovery_speed_drain * delta, GameManager.BASE_SPEED)
					else:
						_end_recovery()
						mesh_pivot.rotation.y = lerpf(mesh_pivot.rotation.y, ground_yaw, 10.0 * delta)
				else:
					mesh_pivot.rotation.y = lerpf(mesh_pivot.rotation.y, ground_yaw, 10.0 * delta)
		elif _yaw_recovery:
			_end_recovery()

	ScoreManager.add_distance(GameManager.current_speed * delta)


# A/D: lean body, biases lateral velocity
func _handle_lean(delta: float) -> void:
	var input := Input.get_axis("lean_left", "lean_right")
	var accel_mult := _boost_multiplier
	var lean_mult := lean_forward_lateral_mult if _is_leaning_fwd else 1.0
	var carve_mult := turn_burst_accel_factor if (_turn_burst_frames > 0 and not _is_leaning_fwd) else 1.0
	if not is_on_floor():
		# Slight lateral influence in air
		if input != 0.0:
			_lean_vel_x = clampf(_lean_vel_x + input * air_lean_force * delta, -lean_max_lateral, lean_max_lateral)
		else:
			_lean_vel_x = move_toward(_lean_vel_x, 0.0, lateral_friction * air_lean_friction_factor * delta)
		return
	if input != 0.0:
		if _lean_vel_x * input < 0.0:
			_lean_vel_x = move_toward(_lean_vel_x, 0.0, lateral_counter_decel * accel_mult * lean_mult * delta)
		else:
			_lean_vel_x = clampf(_lean_vel_x + input * lateral_accel * accel_mult * lean_mult * carve_mult * delta, -lean_max_lateral, lean_max_lateral)
	else:
		_lean_vel_x = move_toward(_lean_vel_x, 0.0, lateral_friction * accel_mult * delta)


# Left/Right arrows: rotate board direction, changes movement vector
func _handle_board_turn(delta: float) -> void:
	if not is_on_floor() or _is_on_rail():
		return
	var input := Input.get_axis("move_left", "move_right")
	var target_vel := input * board_turn_speed
	var accel := board_turn_accel if input != 0.0 else board_turn_brake
	_board_yaw_vel = move_toward(_board_yaw_vel, target_vel, accel * delta)
	_board_yaw = clampf(_board_yaw + _board_yaw_vel * delta, -board_turn_max, board_turn_max)
	if input == 0.0:
		_board_yaw = move_toward(_board_yaw, 0.0, board_turn_return * delta)


# Consolidated wipeout risk evaluation — computes danger intensity for all self-induced sources
# and emits wipeout_danger signal. Triggers wipeout when conflict hits 1.0.
# Landing checks (yaw overshoot, tilt) still fire at the landing moment in _handle_landing.
func _evaluate_wipeout_danger(delta: float) -> void:
	var best_intensity := 0.0
	var best_reason := WipeoutReason.NONE

	# — Conflict danger (ground): yaw without tilt, or opposing lean+turn —
	if is_on_floor() and GameManager.current_speed >= conflict_min_speed and not _is_on_rail():
		var lean_input := Input.get_axis("lean_left", "lean_right")
		var turn_input := Input.get_axis("move_left", "move_right")
		if lean_input * turn_input < -conflict_opposing_threshold or (lean_input == 0 and abs(turn_input) > 0):
			_conflict_timer += delta
			if _conflict_timer >= conflict_wipeout_time:
				_conflict_timer = 0.0
				_emit_danger(0.0, WipeoutReason.NONE)
				_start_wipeout()
				return
		else:
			_conflict_timer = move_toward(_conflict_timer, 0.0, delta * conflict_decay_rate)
		var conflict_intensity := _conflict_timer / conflict_wipeout_time
		if conflict_intensity > best_intensity:
			best_intensity = conflict_intensity
			best_reason = WipeoutReason.CONFLICT
	else:
		_conflict_timer = 0.0

	# — Air yaw danger: live preview of how badly you'd overshoot a clean landing —
	if not is_on_floor() and _air_time >= min_trick_air_time:
		var spin := absf(_air_spin_y)
		if spin >= min_trick_spin:
			var nearest_n := maxf(1.0, roundf(spin / PI))
			var residual := absf(spin - nearest_n * PI)
			var speed_ratio := clampf((GameManager.current_speed - GameManager.BASE_SPEED) / (GameManager.MAX_SPEED - GameManager.BASE_SPEED), 0.0, 1.0)
			var crash_threshold := lerpf(deg_to_rad(crash_threshold_slow_deg), deg_to_rad(crash_threshold_fast_deg), speed_ratio)
			var yaw_intensity := clampf((residual - stomp_threshold) / (crash_threshold - stomp_threshold), 0.0, 1.0)
			if yaw_intensity > best_intensity:
				best_intensity = yaw_intensity
				best_reason = WipeoutReason.AIR_YAW

		# — Air tilt danger: live preview of landing-tilt wipeout risk —
		var tilt_intensity := clampf(absf(_lean_vel_x) / land_tilt_wipeout, 0.0, 1.0)
		if tilt_intensity > best_intensity:
			best_intensity = tilt_intensity
			best_reason = WipeoutReason.AIR_TILT

	_emit_danger(best_intensity, best_reason)


func _emit_danger(intensity: float, reason: WipeoutReason) -> void:
	if absf(intensity - _wipeout_danger_intensity) > wipeout_danger_dead_zone or reason != _wipeout_danger_reason:
		_wipeout_danger_intensity = intensity
		_wipeout_danger_reason = reason
		wipeout_danger.emit(intensity, reason)


func _handle_jump() -> void:
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
		if _is_on_rail() or abs(get_floor_normal().x) > WALL_NORMAL_THRESHOLD:
			var dir := Input.get_axis("lean_left", "lean_right")
			velocity.x = dir * max_lateral_speed * rail_jump_lateral_factor


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta


func _apply_wall_gravity(delta: float) -> void:
	if not is_on_floor():
		return
	if abs(get_floor_normal().x) > WALL_NORMAL_THRESHOLD:
		velocity.x -= sign(position.x) * wall_gravity * delta


# Arrows spin in air (tricks); A/D lateral drift handled in _handle_lean
func _handle_air_spin(delta: float) -> void:
	var on_rail := _is_on_rail()
	if is_on_floor() and not on_rail:
		_rail_spin_acc = 0.0
		_rail_tricks = 0
		return
	var input := Input.get_axis("move_left", "move_right")
	var spin_delta := input * air_turn_speed * delta
	_air_spin_y -= spin_delta
	if on_rail:
		_rail_spin_acc += absf(spin_delta)
		var earned := int(_rail_spin_acc / PI)
		if earned > _rail_tricks:
			_rail_tricks = earned
			ScoreManager.add_trick(false)
	if is_instance_valid(mesh_pivot):
		var stance_offset := PI if is_goofy else 0.0
		mesh_pivot.rotation.y = lerpf(mesh_pivot.rotation.y, stance_offset + _air_spin_y, air_spin_lerp_speed * delta)


func _handle_landing() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		SfxManager.play_landing()
		if not _is_on_rail():
			_snow_particles.restart()
		var spin := absf(_air_spin_y)
		if _air_time >= min_trick_air_time and spin >= min_trick_spin:
			var nearest_n := maxf(1.0, roundf(spin / PI))
			var overshoot := absf(spin - nearest_n * PI)
			var speed_ratio := clampf((GameManager.current_speed - GameManager.BASE_SPEED) / (GameManager.MAX_SPEED - GameManager.BASE_SPEED), 0.0, 1.0)
			var crash_threshold := lerpf(deg_to_rad(crash_threshold_slow_deg), deg_to_rad(crash_threshold_fast_deg), speed_ratio)
			if overshoot >= crash_threshold:
				_air_spin_y = 0.0
				_air_time = 0.0
				_start_wipeout()
				_was_on_floor = on_floor
				return
			if int(nearest_n) % 2 == 1:
				is_goofy = !is_goofy
				stance_changed.emit(is_goofy)
			if overshoot >= stomp_threshold:
				GameManager.current_speed = maxf(GameManager.current_speed - sloppy_speed_penalty, GameManager.BASE_SPEED)
			else:
				ScoreManager.add_trick(true)
		if _air_time >= min_trick_air_time and absf(_lean_vel_x) >= land_tilt_wipeout:
			_air_spin_y = 0.0
			_air_time = 0.0
			_start_wipeout()
			_was_on_floor = on_floor
			return
		var stance_after := PI if is_goofy else 0.0
		if is_instance_valid(mesh_pivot):
			mesh_pivot.rotation.y = stance_after + wrapf(mesh_pivot.rotation.y - stance_after, -PI, PI)
		var residual := wrapf(_air_spin_y, -PI, PI)
		if abs(residual) > recovery_yaw_min:
			_yaw_recovery = true
			_lean_vel_x = clampf(sin(residual) * GameManager.current_speed * recovery_lateral_factor, -max_lateral_speed, max_lateral_speed)
		if abs(residual) >= boost_threshold:
			_boost_multiplier = boost_amount
			_boost_timer = boost_duration
		_air_spin_y = 0.0
		_air_time = 0.0
	elif not on_floor and _was_on_floor:
		SfxManager.play_airborne()
	_was_on_floor = on_floor


func _tick_boost(delta: float) -> void:
	if _boost_timer <= 0.0:
		return
	_boost_timer -= delta
	if _boost_timer <= 0.0:
		_boost_timer = 0.0
		_boost_multiplier = 1.0
	else:
		_boost_multiplier = lerpf(1.0, boost_amount, _boost_timer / boost_duration)


func crash() -> void:
	if _is_dead or _is_wiping_out:
		return
	SfxManager.play_collide()
	_start_wipeout()


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


func _handle_lean_forward(delta: float) -> void:
	if not _is_leaning_fwd or _is_on_rail():
		return
	GameManager.current_speed = minf(GameManager.current_speed + lean_forward_accel * delta, lean_forward_max_speed)


func _handle_snow_terrain_drag(delta: float) -> void:
	var on_snow := is_on_floor() and not _is_on_rail()
	if on_snow:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			if col.get_collider() != null and col.get_collider().is_in_group("snow_terrain"):
				GameManager.current_speed = maxf(GameManager.current_speed - snow_terrain_speed_drain * delta, GameManager.BASE_SPEED)
				break
	if on_snow != _was_on_snow:
		SfxManager.set_on_snow(on_snow)
		_was_on_snow = on_snow


func _handle_rail_lock(delta: float) -> void:
	if not _is_on_rail() or velocity.y > 0.0 or _is_leaning_fwd:
		return
	velocity.x = 0.0
	_lean_vel_x = 0.0
	_board_yaw = 0.0
	GameManager.current_speed = maxf(GameManager.current_speed - rail_speed_drain * delta, GameManager.BASE_SPEED)


func _handle_lean_back(delta: float) -> void:
	if not is_on_floor():
		return
	if _is_leaning_back:
		GameManager.current_speed = maxf(GameManager.current_speed - lean_back_brake * delta, -lean_back_max_reverse)
	elif GameManager.current_speed < GameManager.BASE_SPEED:
		GameManager.current_speed = minf(GameManager.current_speed + lean_back_recover_rate * delta, GameManager.BASE_SPEED)


func _start_wipeout() -> void:
	_is_wiping_out = true
	_wipeout_timer = wipeout_duration
	_yaw_recovery = false
	_boost_multiplier = 1.0
	_boost_timer = 0.0
	_was_on_rail = false
	_was_on_snow = false
	_board_yaw = 0.0
	_board_yaw_vel = 0.0
	_lean_vel_x = 0.0
	_conflict_timer = 0.0
	_wipeout_danger_intensity = 0.0
	_wipeout_danger_reason = WipeoutReason.NONE
	wipeout_danger.emit(0.0, WipeoutReason.NONE)
	is_goofy = false
	stance_changed.emit(false)
	SfxManager.set_grinding(false)
	SfxManager.set_on_snow(false)
	ScoreManager.reset_combo()
	_snow_particles.restart()


func _handle_wipeout(delta: float) -> void:
	_wipeout_timer -= delta
	GameManager.current_speed = maxf(GameManager.current_speed - wipeout_brake_rate * delta, 0.0)
	velocity.z = -GameManager.current_speed
	velocity.x = move_toward(velocity.x, 0.0, wipeout_lateral_decel * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()

	if is_instance_valid(mesh_pivot):
		var t := 1.0 - (_wipeout_timer / wipeout_duration)
		if t < wipeout_phase1_end:
			mesh_pivot.rotation.x = lerpf(mesh_pivot.rotation.x, wipeout_fall_pitch, 12.0 * delta)
			mesh_pivot.rotation.z = lerpf(mesh_pivot.rotation.z, sin(_wipeout_timer * wipeout_wobble_freq) * wipeout_wobble_amp, 8.0 * delta)
		elif t < wipeout_phase2_end:
			mesh_pivot.rotation.x = lerpf(mesh_pivot.rotation.x, -PI / 2.0, 5.0 * delta)
			mesh_pivot.rotation.z = lerpf(mesh_pivot.rotation.z, 0.0, 5.0 * delta)
		else:
			mesh_pivot.rotation.x = lerpf(mesh_pivot.rotation.x, 0.0, 5.0 * delta)
			mesh_pivot.rotation.z = lerpf(mesh_pivot.rotation.z, 0.0, 5.0 * delta)
			mesh_pivot.rotation.y = lerpf(mesh_pivot.rotation.y, 0.0, 5.0 * delta)

	if position.y < -50.0:
		_fall_off()
		return

	if _wipeout_timer <= 0.0:
		_end_wipeout()


func _end_wipeout() -> void:
	_is_wiping_out = false
	_wipeout_timer = 0.0
	GameManager.current_speed = 0.0
	if is_instance_valid(mesh_pivot):
		mesh_pivot.rotation = Vector3.ZERO


func _end_recovery() -> void:
	_yaw_recovery = false


func _is_on_rail() -> bool:
	if not is_on_floor():
		return false
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_collider() != null and col.get_collider().is_in_group("rail"):
			return true
	return false


func _make_spark_particles() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 20
	p.lifetime = 0.3
	p.emitting = false
	p.local_coords = false

	var proc := ParticleProcessMaterial.new()
	proc.direction = Vector3(0.0, 1.0, 0.0)
	proc.spread = 80.0
	proc.initial_velocity_min = 1.0
	proc.initial_velocity_max = 3.5
	proc.gravity = Vector3(0.0, -9.0, 0.0)
	proc.scale_min = 0.8
	proc.scale_max = 1.6
	var color_gradient := Gradient.new()
	color_gradient.colors = PackedColorArray([Color(1.0, 0.85, 0.1), Color(1.0, 0.25, 0.02)])
	color_gradient.offsets = PackedFloat32Array([0.0, 1.0])
	var color_tex := GradientTexture1D.new()
	color_tex.gradient = color_gradient
	proc.color_initial_ramp = color_tex
	p.process_material = proc

	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.07, 0.07)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.surface_set_material(0, mat)
	p.draw_pass_1 = mesh

	return p


func _make_snow_particles() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 28
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.local_coords = false

	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	proc.emission_ring_axis = Vector3(0.0, 1.0, 0.0)
	proc.emission_ring_radius = 0.35
	proc.emission_ring_inner_radius = 0.1
	proc.emission_ring_height = 0.05
	proc.direction = Vector3(0.0, 0.4, 0.0)
	proc.spread = 55.0
	proc.initial_velocity_min = 2.5
	proc.initial_velocity_max = 5.0
	proc.gravity = Vector3(0.0, -5.0, 0.0)
	proc.scale_min = 1.2
	proc.scale_max = 2.8
	proc.color = Color(1.0, 1.0, 1.0, 0.85)
	p.process_material = proc

	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.1, 0.1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_set_material(0, mat)
	p.draw_pass_1 = mesh

	return p


func _on_state_changed(new_state: GameManager.State) -> void:
	if new_state == GameManager.State.PLAYING:
		_is_dead = false
		is_goofy = false
		stance_changed.emit(false)
		velocity = Vector3.ZERO
		position = Vector3(0.0, 3.0, 0.0)
		_air_spin_y = 0.0
		_air_time = 0.0
		_is_wiping_out = false
		_wipeout_timer = 0.0
		_rail_spin_acc = 0.0
		_rail_tricks = 0
		_was_on_rail = false
		_was_on_snow = false
		_boost_multiplier = 1.0
		_boost_timer = 0.0
		_was_on_floor = false
		_smooth_vel_x = 0.0
		_board_yaw = 0.0
		_board_yaw_vel = 0.0
		_lean_vel_x = 0.0
		_conflict_timer = 0.0
		_wipeout_danger_intensity = 0.0
		_wipeout_danger_reason = WipeoutReason.NONE
		wipeout_danger.emit(0.0, WipeoutReason.NONE)
		_spark_particles.emitting = false
		_snow_particles.emitting = false
		_snow_particles.one_shot = true
		_snow_particles.explosiveness = 1.0
		_end_recovery()
