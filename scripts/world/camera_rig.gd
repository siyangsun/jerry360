extends Node3D
## Follows the player with a fixed downhill camera angle.

const LevelGenerator = preload("res://scripts/world/level_generator.gd")

@export var player: CharacterBody3D
@export var offset := Vector3(0.0, 3.0, 6.0)        # behind and above
@export var look_offset := Vector3(0.0, 2.0, -12.0) # point ahead of player
@export var follow_speed := 8.0
@export var lateral_follow_speed := 12.0

const SPEED_CAM_HEIGHT_DROP := 1.0   # how much lower the camera gets at max speed
const SPEED_CAM_LOOK_RISE   := 1.0   # how much higher the look target gets at max speed
const LATERAL_SWAY_MULT     := -0.04 # look-target x shift per m/s of lateral velocity
const ACCEL_CAM_Z_FOLLOW    := 8.0   # Z catch-up speed; lower = more lag behind player
const ACCEL_DROP_RATE       := 0.07  # units dropped per m/s² of acceleration
const ACCEL_DROP_MAX        := 0.7   # cap on downward bias
const ACCEL_DROP_SMOOTH     := 4.0   # recovery speed when acceleration eases

const SPEED_FOV_BASE  := 68.0  # FOV at minimum speed
const SPEED_FOV_BOOST := 12.0  # extra degrees added at max speed
const AIR_CAM_LIFT    := 1.4   # units the camera rises while player is airborne

var _prev_speed := 0.0
var _accel_drop := 0.0
var _camera: Camera3D


func _ready() -> void:
	_camera = $Camera3D
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not is_instance_valid(player):
		return

	var speed_ratio := clampf(
		(GameManager.current_speed - GameManager.BASE_SPEED) / (GameManager.MAX_SPEED - GameManager.BASE_SPEED),
		0.0, 1.0)

	var accel := (GameManager.current_speed - _prev_speed) / delta
	_prev_speed = GameManager.current_speed
	var target_drop := clampf(accel * ACCEL_DROP_RATE, 0.0, ACCEL_DROP_MAX)
	_accel_drop = lerpf(_accel_drop, target_drop, ACCEL_DROP_SMOOTH * delta)

	var air_lift := AIR_CAM_LIFT if not player.is_on_floor() else 0.0
	var dynamic_offset := offset + Vector3(0.0, -SPEED_CAM_HEIGHT_DROP * speed_ratio - _accel_drop + air_lift, 0.0)
	var target_pos := player.global_position + dynamic_offset
	var new_pos := global_position
	new_pos.x = lerpf(new_pos.x, target_pos.x, lateral_follow_speed * delta)
	new_pos.y = lerpf(new_pos.y, target_pos.y, follow_speed * delta)
	new_pos.z = lerpf(new_pos.z, target_pos.z, ACCEL_CAM_Z_FOLLOW * delta)
	global_position = new_pos

	var slope_drop := look_offset.z * tan(deg_to_rad(LevelGenerator.DOWNHILL_TILT_ANGLE))
	var dynamic_look := look_offset + Vector3(0.0, SPEED_CAM_LOOK_RISE * speed_ratio + slope_drop, 0.0)
	var sway_x := player.velocity.x * LATERAL_SWAY_MULT
	look_at(player.global_position + dynamic_look + Vector3(sway_x, 0.0, 0.0), Vector3.UP)
	rotate_object_local(Vector3.RIGHT, deg_to_rad(LevelGenerator.DOWNHILL_TILT_ANGLE * 0.5))
	_camera.fov = lerpf(_camera.fov, SPEED_FOV_BASE + SPEED_FOV_BOOST * speed_ratio, 6.0 * delta)
