extends CharacterBody3D

@export var lateral_accel := 22.0
@export var lateral_friction := 16.0
@export var lateral_counter_decel := 85.0
@export var max_lateral_speed := 13.0
@export var jump_velocity := 10.0
@export var gravity := 24.0
@export var wall_gravity := 18.0

var _is_dead: bool = false

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

	if position.y < -50.0:
		_fall_off()
		return

	# Visual tilt based on lateral velocity
	if is_instance_valid(mesh_pivot):
		mesh_pivot.rotation.z = lerpf(mesh_pivot.rotation.z, -velocity.x * 0.05, 10.0 * delta)

	ScoreManager.add_distance(GameManager.current_speed * delta)


func _handle_lateral(delta: float) -> void:
	if not is_on_floor():
		return
	var input := Input.get_axis("move_left", "move_right")
	if input != 0.0:
		if velocity.x * input < 0.0:
			# Counter-steering: shed opposite velocity faster
			velocity.x = move_toward(velocity.x, 0.0, lateral_counter_decel * delta)
		else:
			# Same direction or from rest: normal acceleration
			velocity.x = clampf(velocity.x + input * lateral_accel * delta, -max_lateral_speed, max_lateral_speed)
	else:
		velocity.x = move_toward(velocity.x, 0.0, lateral_friction * delta)


func _handle_jump() -> void:
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
		# velocity.x intentionally unchanged — lateral momentum carries into jump


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta


func _apply_wall_gravity(delta: float) -> void:
	if not is_on_floor():
		return
	# If the floor normal tilts sideways, we're on a side panel not the flat base
	if abs(get_floor_normal().x) > 0.2:
		# Accelerate toward center based on displacement, not velocity
		velocity.x -= sign(position.x) * wall_gravity * delta


func _fall_off() -> void:
	if _is_dead:
		return
	_is_dead = true
	velocity = Vector3.ZERO
	GameManager.return_to_menu()


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
