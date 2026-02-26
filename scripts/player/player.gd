extends CharacterBody3D

@export var lateral_accel := 30.0
@export var lateral_friction := 16.0
@export var lateral_counter_decel := 100.0
@export var max_lateral_speed := 13.0
@export var jump_velocity := 10.0
@export var gravity := 24.0
@export var wall_gravity := 18.0

const AIR_SPIN_SPEED := 2.0    # rad/s of yaw input can apply in air
const BOOST_AMOUNT := 2.0      # multiplier on accel/decel after landing trick
const BOOST_DURATION := 1.5    # seconds the boost lasts
const BOOST_THRESHOLD := 0.15  # minimum air spin (rad) to earn a boost

const RECOVERY_YAW_MIN := 0.10      # yaw diff below which recovery is done
const RECOVERY_LERP_SPEED := 1.8    # yaw correction speed during recovery (normal = 10.0)
const RECOVERY_SPEED_DRAIN := 2.0   # forward speed lost per second while recovering
const RECOVERY_LATERAL_FACTOR := 0.15  # fraction of forward speed pushed sideways on landing

const TURN_BURST_ROT := 0.05          # rotation snap (bank+yaw) on initial button press
const TURN_BURST_FRAMES := 5		  # number of frames to turn burst
const LEAN_FORWARD_ACCEL := 6.0       # extra units/sec while leaning forward
const LEAN_FORWARD_ANGLE := -0.22     # body tilt in radians (~12.6°)
const LEAN_FORWARD_LATERAL_MULT := 0.5  # lateral accel/counter-decel multiplier while leaning
const LEAN_FORWARD_RECOVERY_YAW := 0.05  # tighter recovery threshold while leaning

const LEAN_BACK_ANGLE := 0.22          # body tilt backward in radians (~12.6°)
const LEAN_BACK_BRAKE := 8.0           # forward speed reduction per second while braking
const LEAN_BACK_MAX_REVERSE := 2.0     # max backward speed (m/s)
const LEAN_BACK_RECOVER_RATE := 10.0   # speed/sec to return to BASE_SPEED after releasing

var _is_dead: bool = false
var _was_on_floor: bool = false
var _air_spin_y: float = 0.0
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

	_is_leaning_fwd = is_on_floor() and Input.is_action_pressed("lean_forward")
	_is_leaning_back = is_on_floor() and Input.is_action_pressed("lean_back") and not _is_leaning_fwd

	_handle_lateral(delta)
	_handle_jump()
	_handle_rail_lock()
	_apply_gravity(delta)

	velocity.z = -GameManager.current_speed
	move_and_slide()

	_apply_wall_gravity(delta)
	_handle_air_spin(delta)
	_handle_landing()
	_handle_lean_forward(delta)
	_handle_lean_back(delta)
	_tick_boost(delta)

	var lateral_input := Input.get_axis("move_left", "move_right")
	GameManager.ramp_multiplier = 1.0 if abs(lateral_input) > 0.1 else GameManager.STRAIGHT_RAMP_MULT

	_spark_particles.emitting = _is_on_rail()

	# Snow cloud: continuous when recovering or braking, one-shot burst on landing
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

	# Smooth velocity for visuals — filters out rapid physics jitter
	_smooth_vel_x = lerpf(_smooth_vel_x, velocity.x, 10.0 * delta)

	# Visual tilt and yaw — velocity-based on ground, spin-based in air
	if is_instance_valid(mesh_pivot):
		if not _is_leaning_fwd and not _is_leaning_back and not _is_on_rail():
			if Input.is_action_just_pressed("move_right"):
				_turn_burst_frames = TURN_BURST_FRAMES
				_turn_burst_dir = 1.0
			elif Input.is_action_just_pressed("move_left"):
				_turn_burst_frames = TURN_BURST_FRAMES
				_turn_burst_dir = -1.0
			if _turn_burst_frames > 0:
				var step := _turn_burst_dir * TURN_BURST_ROT * 0.5
				mesh_pivot.rotation.z -= step
				mesh_pivot.rotation.y -= step
				_turn_burst_frames -= 1

		var lean_target := -lateral_input * 0.28 - _smooth_vel_x * 0.008
		mesh_pivot.rotation.z = lerpf(mesh_pivot.rotation.z, lean_target, 10.0 * delta)
		var pitch_target := 0.0
		if _is_leaning_fwd:
			pitch_target = LEAN_FORWARD_ANGLE
		elif _is_leaning_back:
			pitch_target = LEAN_BACK_ANGLE
		mesh_pivot.rotation.x = lerpf(mesh_pivot.rotation.x, pitch_target, 10.0 * delta)
		if is_instance_valid(snowboard_mesh):
			snowboard_mesh.rotation.y = mesh_pivot.rotation.y
			snowboard_mesh.rotation.z = mesh_pivot.rotation.z
		if is_on_floor():
			if not _is_on_rail():
				var ground_yaw := -_smooth_vel_x * 0.05
				var recovery_yaw_min := LEAN_FORWARD_RECOVERY_YAW if _is_leaning_fwd else RECOVERY_YAW_MIN
				if _yaw_recovery:
					var yaw_diff := absf(mesh_pivot.rotation.y - ground_yaw)
					if yaw_diff > recovery_yaw_min:
						mesh_pivot.rotation.y = lerpf(mesh_pivot.rotation.y, ground_yaw, RECOVERY_LERP_SPEED * delta)
						GameManager.current_speed = maxf(GameManager.current_speed - RECOVERY_SPEED_DRAIN * delta, GameManager.BASE_SPEED)
					else:
						_end_recovery()
						mesh_pivot.rotation.y = lerpf(mesh_pivot.rotation.y, ground_yaw, 10.0 * delta)
				else:
					mesh_pivot.rotation.y = lerpf(mesh_pivot.rotation.y, ground_yaw, 10.0 * delta)
		elif _yaw_recovery:
			# Became airborne mid-recovery — cancel cleanly
			_end_recovery()

	ScoreManager.add_distance(GameManager.current_speed * delta)


func _handle_lateral(delta: float) -> void:
	if not is_on_floor():
		return
	var input := Input.get_axis("move_left", "move_right")
	var accel_mult := _boost_multiplier
	var lean_mult := LEAN_FORWARD_LATERAL_MULT if _is_leaning_fwd else 1.0
	var speed_ratio := clampf(GameManager.current_speed / 10.0, 0.0, 1.0)
	var effective_max_lateral := lerpf(1.0, max_lateral_speed, speed_ratio)
	if input != 0.0:
		if velocity.x * input < 0.0:
			velocity.x = move_toward(velocity.x, 0.0, lateral_counter_decel * accel_mult * lean_mult * delta)
		else:
			velocity.x = clampf(velocity.x + input * lateral_accel * accel_mult * lean_mult * delta, -effective_max_lateral, effective_max_lateral)
	else:
		velocity.x = move_toward(velocity.x, 0.0, lateral_friction * accel_mult * delta)


func _handle_jump() -> void:
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
		if _is_on_rail():
			var dir := Input.get_axis("move_left", "move_right")
			velocity.x = dir * max_lateral_speed


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta


func _apply_wall_gravity(delta: float) -> void:
	if not is_on_floor():
		return
	if abs(get_floor_normal().x) > 0.2:
		velocity.x -= sign(position.x) * wall_gravity * delta


func _handle_air_spin(delta: float) -> void:
	if is_on_floor() and not _is_on_rail():
		return
	var input := Input.get_axis("move_left", "move_right")
	_air_spin_y -= input * AIR_SPIN_SPEED * delta
	if is_instance_valid(mesh_pivot):
		mesh_pivot.rotation.y = lerpf(mesh_pivot.rotation.y, _air_spin_y, 8.0 * delta)


func _handle_landing() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		if not _is_on_rail():
			_snow_particles.restart()
		if abs(_air_spin_y) > RECOVERY_YAW_MIN:
			_yaw_recovery = true
			velocity.x = clampf(sin(_air_spin_y) * GameManager.current_speed * RECOVERY_LATERAL_FACTOR, -max_lateral_speed, max_lateral_speed)
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


func _handle_lean_forward(delta: float) -> void:
	if not _is_leaning_fwd or _is_on_rail():
		return
	GameManager.current_speed = minf(GameManager.current_speed + LEAN_FORWARD_ACCEL * delta, GameManager.MAX_SPEED)


func _handle_rail_lock() -> void:
	# Grinding: lock lateral position; jump or lean-forward releases it
	if not _is_on_rail() or velocity.y > 0.0 or _is_leaning_fwd:
		return
	velocity.x = 0.0


func _handle_lean_back(delta: float) -> void:
	if not is_on_floor():
		return
	if _is_leaning_back:
		GameManager.current_speed = maxf(GameManager.current_speed - LEAN_BACK_BRAKE * delta, -LEAN_BACK_MAX_REVERSE)
	elif GameManager.current_speed < GameManager.BASE_SPEED:
		# Quick ramp back up after releasing
		GameManager.current_speed = minf(GameManager.current_speed + LEAN_BACK_RECOVER_RATE * delta, GameManager.BASE_SPEED)


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
	p.local_coords = false  # particles fly off in world space

	var proc := ParticleProcessMaterial.new()
	proc.direction = Vector3(0.0, 1.0, 0.0)
	proc.spread = 80.0
	proc.initial_velocity_min = 1.0
	proc.initial_velocity_max = 3.5
	proc.gravity = Vector3(0.0, -9.0, 0.0)
	proc.scale_min = 0.8
	proc.scale_max = 1.6
	proc.color = Color(1.0, 0.85, 0.1)  # yellow
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
	proc.emission_ring_axis = Vector3(0.0, 1.0, 0.0)  # ring lies flat on XZ
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
	proc.color = Color(1.0, 1.0, 1.0, 0.85)  # white
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
		velocity = Vector3.ZERO
		position = Vector3(0.0, 3.0, 0.0)
		_air_spin_y = 0.0
		_boost_multiplier = 1.0
		_boost_timer = 0.0
		_was_on_floor = false
		_smooth_vel_x = 0.0
		_spark_particles.emitting = false
		_snow_particles.emitting = false
		_snow_particles.one_shot = true
		_snow_particles.explosiveness = 1.0
		_end_recovery()
