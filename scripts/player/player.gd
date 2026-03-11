extends CharacterBody3D

const LevelGenerator = preload("res://scripts/world/level_generator.gd")

# ── Feel parameters — tunable in Inspector ───────────────────────────────────
@export var lateral_accel := 22.0               # how quickly Jerry builds up sideways speed when leaning
@export var lateral_friction := 16.0            # how quickly sideways drift slows down when not leaning
@export var lateral_counter_decel := 100.0      # how quickly Jerry kills his drift when leaning the opposite way
@export var max_lateral_speed := 13.0           # maximum speed Jerry can move sideways
@export var lean_max_lateral := 3.5             # how much the lean keys (A/D) contribute to sideways speed
@export var jump_velocity := 8.0                # how high Jerry jumps (uncharged)
@export var ramp_jump_factor := 0.8            # how much ramp steepness × speed boosts the jump
@export var charge_max_time := 0.6              # how long to hold down to reach full charge (seconds)
@export var charge_jump_boost := 7.0            # extra jump height added at full charge
@export var charge_release_window := 0.1        # seconds after releasing down where a charged jump still fires
@export var jump_buffer_time := 0.2             # how long a jump input is remembered while still holding down (seconds)
@export var charge_squat_scale := 0.825         # how much Jerry squishes down at full charge (fraction of normal height)
@export var wall_gravity := 18.0                # how strongly the side walls pull Jerry back toward center
@export var air_lean_friction_factor := 0.4     # sideways drift slows down slower in the air (fraction of normal)
@export var rail_jump_lateral_factor := 0.7     # how much sideways speed is kept when jumping off a rail
@export var conflict_opposing_threshold := 0.09 # how much lean and turn can oppose before flagging a conflict
@export var conflict_decay_rate := 2.0          # how fast the conflict warning clears when you stop opposing
@export var crash_threshold_slow_deg := 75.0    # at slow speed, you can land this many degrees off-center before wiping out
@export var crash_threshold_fast_deg := 45.0    # at top speed, you must be within this many degrees to land clean
@export var crash_threshold_big_air_deg := 22.0 # after a big air, must be this close to straight to survive
@export var big_air_time := 1.0                 # air time (seconds) at which full big-air tightening kicks in
@export var wipeout_lateral_decel := 30.0       # how fast Jerry's sideways slide stops during a wipeout
@export var lean_tilt_visual_scale := 0.28      # how much Jerry's body visually tilts when you lean (cosmetic)
@export var lean_vel_tilt_visual_scale := 0.016 # extra tilt based on how fast Jerry is actually moving sideways (cosmetic)
@export var air_spin_lerp_speed := 8.0          # how snappily Jerry's body follows his spin in the air (cosmetic)
@export var wipeout_danger_dead_zone := 0.05    # minimum change before the wipeout danger meter visually updates
@export var wipeout_fall_pitch := -1.3          # how far forward Jerry pitches when he starts wiping out (cosmetic)
@export var wipeout_wobble_freq := 14.0         # how fast Jerry wobbles during the tumble phase (cosmetic)
@export var wipeout_wobble_amp := 0.7           # how wide the tumble wobble is (cosmetic)
@export var wipeout_phase1_end := 0.35          # fraction of wipeout time when tumble ends and flat spin begins
@export var wipeout_phase2_end := 0.75          # fraction of wipeout time when flat spin ends and recovery begins
@export var air_turn_speed := 4.0              # how fast Jerry spins when pressing turn arrows in the air (trick speed)
@export var air_lean_force := 4.0              # how much sideways movement you get from A/D while airborne
@export var boost_amount := 2.0               # speed boost multiplier rewarded for landing a trick
@export var boost_duration := 1.5             # how long the trick landing boost lasts (seconds)
@export var boost_threshold := 0.15           # minimum spin needed to earn a speed boost on landing
@export var recovery_yaw_min := 0.10          # how close to straight Jerry needs to be before recovery ends
@export var recovery_lerp_speed := 1.8        # how slowly the board corrects itself after a sloppy landing
@export var recovery_speed_drain := 2.0       # speed lost per second while recovering from a sloppy landing
@export var recovery_lateral_factor := 0.15   # how much sideways momentum a sloppy landing gives Jerry
@export var turn_burst_yaw := 0.03            # how much the board snaps sideways on the first frame of a turn press (cosmetic)
@export var turn_burst_bank := 0.025          # how much the body snaps sideways on the first frame of a turn press (cosmetic)
@export var turn_burst_frames := 5            # how many frames the initial turn snap lasts
@export var turn_burst_accel_factor := 0.5    # lean acceleration is reduced to this fraction during the snap
@export var lean_forward_accel := 6.0         # how fast Jerry accelerates when leaning forward (W key)
@export var lean_forward_angle := -0.22       # how far forward Jerry pitches when leaning forward (cosmetic)
@export var lean_forward_lateral_mult := 0.5  # sideways control is reduced to this fraction while leaning forward
@export var lean_forward_recovery_yaw := 0.05 # alignment tolerance during lean-forward recovery
@export var lean_back_angle := 0.22           # how far back Jerry leans when braking on the ground (cosmetic)
@export var air_lean_back_angle := 0.22       # how far back Jerry leans when holding lean-back in the air (cosmetic)
@export var lean_back_landing_bonus_deg := 20.0 # extra spin-angle forgiveness when leaning back at landing
@export var lean_back_tilt_factor := 1.4      # land_tilt_wipeout is multiplied by this when leaning back at landing
@export var lean_back_brake := 8.0            # braking force when holding lean back
@export var lean_back_max_reverse := 2.0      # maximum reverse speed when fully braked
@export var lean_back_recover_rate := 10.0    # how fast Jerry gets back to base speed after braking
@export var rail_speed_drain := 3.0           # speed lost per second while grinding a rail
@export var snow_terrain_speed_drain := 4.0   # speed lost per second on deep snow (moguls, side walls)
@export var lean_forward_max_speed := 55.0    # maximum speed achievable by leaning forward (above normal cap)
@export var lean_boost_decay := 15.0          # how fast Jerry slows back to normal after releasing lean forward
@export var min_trick_air_time := 0.3         # minimum time in the air before a spin counts as a trick (seconds)
@export var min_trick_spin := 0.8             # minimum spin to count as a trick (roughly half a rotation)
@export var stomp_threshold := PI / 12.0      # within this angle of a clean landing, it's a perfect stomp (15°)
@export var sloppy_speed_penalty := 15.0      # speed lost for landing a trick slightly off-angle
@export var wipeout_duration := 2.2           # how long a full wipeout lasts (seconds)
@export var wipeout_brake_rate := 40.0        # how aggressively Jerry decelerates during a wipeout
@export var land_tilt_wipeout := 4.2          # how much sideways tilt at landing triggers a wipeout (too much lean = fall)
@export var board_turn_speed := 1.0           # how fast the board rotates when pressing turn arrows
@export var board_turn_max := 0.35            # maximum angle the board can turn from straight (about 20°)
@export var board_turn_return := 3.0          # how fast the board returns to straight when you let go
@export var board_turn_accel := 5.0           # how quickly turn speed ramps up when pressing a turn key
@export var board_turn_brake := 9.0           # how quickly turn speed ramps down when releasing a turn key
@export var conflict_wipeout_time := 0.45     # how long you can lean and turn against each other before wiping out (seconds)
@export var conflict_min_speed := 14.0        # minimum speed at which opposing lean+turn can cause a wipeout

# ── Physics laws — do not tune ────────────────────────────────────────────────
const GRAVITY := 24.0
const WALL_NORMAL_THRESHOLD := 0.2         # floor normal x above this triggers wall physics

enum WipeoutReason { NONE, CONFLICT, AIR_YAW, AIR_TILT }

signal stance_changed(goofy: bool)
signal wipeout_danger(intensity: float, reason: WipeoutReason)
signal nice_air(air_time: float)

var is_goofy: bool = false
var _is_dead: bool = false
var _was_on_floor: bool = false
var _air_spin_y: float = 0.0
var _air_time: float = 0.0
var _nice_air_shown: bool = false
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
var _is_squatting: bool = false
var _turn_burst_frames: int = 0
var _turn_burst_dir: float = 0.0

var _board_yaw: float = 0.0    # board facing angle offset from world forward (rad, + = right)
var _board_yaw_vel: float = 0.0  # current angular velocity of board yaw (rad/s)
var _lean_vel_x: float = 0.0   # lean-only lateral velocity contribution
var _conflict_timer: float = 0.0
var _charge_timer: float = 0.0
var _charge_amount: float = 0.0
var _charge_release_window_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _wipeout_danger_intensity: float = 0.0
var _wipeout_danger_reason: WipeoutReason = WipeoutReason.NONE

@onready var _squat_root: Node3D = $SquatRoot
@onready var mesh_pivot: Node3D = $SquatRoot/MeshPivot
@onready var snowboard_mesh: MeshInstance3D = $SnowboardMesh
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D

const COLLIDER_FULL_HEIGHT := 1.0

var _capsule: CapsuleShape3D


func _ready() -> void:
	add_to_group("player")
	GameManager.state_changed.connect(_on_state_changed)
	_spark_particles = _make_spark_particles()
	add_child(_spark_particles)
	_snow_particles = _make_snow_particles()
	add_child(_snow_particles)
	_squat_root.scale = Vector3.ONE
	_capsule = _collision_shape.shape as CapsuleShape3D
	assert(_capsule != null, "Player CollisionShape3D must use a CapsuleShape3D — check main.tscn")


func _physics_process(delta: float) -> void:
	if _is_dead or GameManager.state != GameManager.State.PLAYING:
		return

	if _is_wiping_out:
		_handle_wipeout(delta)
		return

	_is_leaning_fwd = is_on_floor() and Input.is_action_pressed("lean_forward")
	_is_leaning_back = is_on_floor() and Input.is_action_pressed("lean_back") and not _is_leaning_fwd
	_is_squatting = is_on_floor() and Input.is_action_pressed("squat")

	_handle_lean(delta)
	_handle_board_turn(delta)
	_handle_charge_jump(delta)
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
		if _air_time >= big_air_time and not _nice_air_shown:
			nice_air.emit(_air_time)
			_nice_air_shown = true

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
		elif not is_on_floor() and Input.is_action_pressed("lean_back"):
			pitch_target = air_lean_back_angle
		mesh_pivot.rotation.x = lerpf(mesh_pivot.rotation.x, pitch_target, 10.0 * delta)
		var squat_y := lerpf(_squat_root.scale.y, lerpf(1.0, charge_squat_scale, _charge_timer / charge_max_time), 12.0 * delta)
		_squat_root.scale = Vector3(1.0, squat_y, 1.0)
		_capsule.height = COLLIDER_FULL_HEIGHT * squat_y
		_collision_shape.position.y = _capsule.height * 0.5
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
		var leaning_back_preview := Input.is_action_pressed("lean_back")
		var spin := absf(_air_spin_y)
		if spin >= min_trick_spin:
			var nearest_n := maxf(1.0, roundf(spin / PI))
			var residual := absf(spin - nearest_n * PI)
			var speed_ratio := clampf((GameManager.current_speed - GameManager.BASE_SPEED) / (GameManager.MAX_SPEED - GameManager.BASE_SPEED), 0.0, 1.0)
			var air_factor := clampf(_air_time / big_air_time, 0.0, 1.0)
			var crash_threshold := lerpf(
				lerpf(deg_to_rad(crash_threshold_slow_deg), deg_to_rad(crash_threshold_fast_deg), speed_ratio),
				deg_to_rad(crash_threshold_big_air_deg),
				air_factor)
			if leaning_back_preview:
				crash_threshold += deg_to_rad(lean_back_landing_bonus_deg)
			var yaw_intensity := clampf((residual - stomp_threshold) / (crash_threshold - stomp_threshold), 0.0, 1.0)
			if yaw_intensity > best_intensity:
				best_intensity = yaw_intensity
				best_reason = WipeoutReason.AIR_YAW

		# — Air tilt danger: live preview of landing-tilt wipeout risk —
		var tilt_limit_preview := land_tilt_wipeout * (lean_back_tilt_factor if leaning_back_preview else 1.0)
		var tilt_intensity := clampf(absf(_lean_vel_x) / tilt_limit_preview, 0.0, 1.0)
		if tilt_intensity > best_intensity:
			best_intensity = tilt_intensity
			best_reason = WipeoutReason.AIR_TILT

	_emit_danger(best_intensity, best_reason)


func _emit_danger(intensity: float, reason: WipeoutReason) -> void:
	if absf(intensity - _wipeout_danger_intensity) > wipeout_danger_dead_zone or reason != _wipeout_danger_reason:
		_wipeout_danger_intensity = intensity
		_wipeout_danger_reason = reason
		wipeout_danger.emit(intensity, reason)


func _handle_charge_jump(delta: float) -> void:
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer -= delta
	if is_on_floor() and _is_squatting:
		_charge_timer = minf(_charge_timer + delta, charge_max_time)
		_charge_release_window_timer = 0.0
	else:
		if _charge_timer > 0.0:
			_charge_amount = _charge_timer / charge_max_time
			_charge_release_window_timer = charge_release_window
			_charge_timer = 0.0
			# Do not snap the scale — stay compressed until the jump fires or the window expires
		if _charge_release_window_timer > 0.0:
			_charge_release_window_timer -= delta
			if _charge_release_window_timer <= 0.0:
				_charge_release_window_timer = 0.0
				_charge_amount = 0.0


func _handle_jump() -> void:
	if not is_on_floor():
		return
	if Input.is_action_just_pressed("jump"):
		if _is_squatting and _charge_timer > 0.0:
			_jump_buffer_timer = jump_buffer_time  # buffer it — fires when Down is released
			return
		_fire_jump()
	elif _jump_buffer_timer > 0.0 and _charge_release_window_timer > 0.0:
		_jump_buffer_timer = 0.0
		_fire_jump()


func _fire_jump() -> void:
	var boost := _charge_amount * charge_jump_boost if _charge_release_window_timer > 0.0 else 0.0
	_charge_amount = 0.0
	_charge_release_window_timer = 0.0
	var base_slope_z := sin(deg_to_rad(LevelGenerator.DOWNHILL_TILT_ANGLE))
	var ramp_z_excess := clampf(get_floor_normal().z - base_slope_z, 0.0, 1.0)
	var ramp_boost := ramp_z_excess * GameManager.current_speed * ramp_jump_factor
	velocity.y = jump_velocity + boost + ramp_boost
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
		var leaning_back_on_land := Input.is_action_pressed("lean_back")
		var spin := absf(_air_spin_y)
		if _air_time >= min_trick_air_time and spin >= min_trick_spin:
			var nearest_n := maxf(1.0, roundf(spin / PI))
			var overshoot := absf(spin - nearest_n * PI)
			var speed_ratio := clampf((GameManager.current_speed - GameManager.BASE_SPEED) / (GameManager.MAX_SPEED - GameManager.BASE_SPEED), 0.0, 1.0)
			var air_factor := clampf(_air_time / big_air_time, 0.0, 1.0)
			var crash_threshold := lerpf(
				lerpf(deg_to_rad(crash_threshold_slow_deg), deg_to_rad(crash_threshold_fast_deg), speed_ratio),
				deg_to_rad(crash_threshold_big_air_deg),
				air_factor)
			if leaning_back_on_land:
				crash_threshold += deg_to_rad(lean_back_landing_bonus_deg)
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
		var tilt_limit := land_tilt_wipeout * (lean_back_tilt_factor if leaning_back_on_land else 1.0)
		if _air_time >= min_trick_air_time and absf(_lean_vel_x) >= tilt_limit:
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
		_nice_air_shown = false
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
	_charge_timer = 0.0
	_charge_amount = 0.0
	_charge_release_window_timer = 0.0
	_jump_buffer_timer = 0.0
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
	_squat_root.scale = Vector3.ONE


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
		_charge_timer = 0.0
		_charge_amount = 0.0
		_charge_release_window_timer = 0.0
		_jump_buffer_timer = 0.0
		_squat_root.scale = Vector3.ONE
		_wipeout_danger_intensity = 0.0
		_wipeout_danger_reason = WipeoutReason.NONE
		wipeout_danger.emit(0.0, WipeoutReason.NONE)
		_spark_particles.emitting = false
		_snow_particles.emitting = false
		_snow_particles.one_shot = true
		_snow_particles.explosiveness = 1.0
		_end_recovery()
