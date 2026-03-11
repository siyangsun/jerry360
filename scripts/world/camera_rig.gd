extends Node3D
## Follows the player with a fixed downhill camera angle.

const LevelGenerator = preload("res://scripts/world/level_generator.gd")

@export var player: CharacterBody3D
@export var offset := Vector3(0.0, 3.0, 6.0)        # behind and above
@export var look_offset := Vector3(0.0, 0.0, -12.0) # point ahead of player
@export var follow_speed := 8.0
@export var lateral_follow_speed := 12.0

const SPEED_CAM_HEIGHT_DROP := 1.0   # camera gets lower as Jerry goes faster (feels more tucked in)
const SPEED_CAM_LOOK_RISE   := 1.0   # camera looks further ahead as speed increases
const LATERAL_SWAY_MULT     := -0.10 # how much the camera looks into a turn (higher = more)
const LATERAL_CAM_LEAN      :=  0.03 # how much the camera drifts sideways with Jerry's speed
const CAM_CARVE_LEAN        :=  -2.0    # how far the camera swings out during a real carving turn (lean + yaw together)
const CAM_CARVE_ROLL        :=   0.04   # slight camera tilt during a carve — higher feels more cinematic
const CAM_LATERAL_DELAY     :=   1.5    # how sluggishly the camera reacts to sideways movement (lower = more delay)
const ACCEL_CAM_Z_FOLLOW    := 8.0   # how quickly the camera catches up when Jerry accelerates forward
const ACCEL_DROP_RATE       := 0.07  # how much the camera dips on a burst of acceleration
const ACCEL_DROP_MAX        := 0.7   # maximum dip amount — keeps it from going crazy
const ACCEL_DROP_SMOOTH     := 4.0   # how fast the camera recovers from the dip

const SPEED_FOV_BASE  := 68.0  # normal field of view at slow speed (higher = wider angle)
const SPEED_FOV_BOOST := 12.0  # extra field of view added at top speed (makes it feel faster)
const AIR_CAM_LIFT    := 1.4   # camera rises when Jerry is in the air so you can see the landing
const SLOPE_LOOK_Y_MULT := 0.1  # how much the look target drops per degree of slope (pushes horizon up)

var _prev_speed := 0.0
var _accel_drop := 0.0
var _vel_lean := 0.0
var _carve_lean := 0.0
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
	var mesh_pivot := player.get_node_or_null("MeshPivot") as Node3D
	_vel_lean = lerpf(_vel_lean, player.velocity.x * LATERAL_CAM_LEAN, CAM_LATERAL_DELAY * delta)
	var carve_lean_target: float = mesh_pivot.rotation.z * player._board_yaw * CAM_CARVE_LEAN if is_instance_valid(mesh_pivot) else 0.0
	_carve_lean = lerpf(_carve_lean, carve_lean_target, CAM_LATERAL_DELAY * delta)
	var lateral_lean := _vel_lean + _carve_lean
	var target_pos := player.global_position + dynamic_offset + Vector3(lateral_lean, 0.0, 0.0)
	var new_pos := global_position
	new_pos.x = lerpf(new_pos.x, target_pos.x, lateral_follow_speed * delta)
	new_pos.y = lerpf(new_pos.y, target_pos.y, follow_speed * delta)
	new_pos.z = lerpf(new_pos.z, target_pos.z, ACCEL_CAM_Z_FOLLOW * delta)
	global_position = new_pos

	var slope_drop := look_offset.z * tan(deg_to_rad(LevelGenerator.DOWNHILL_TILT_ANGLE))
	var tilt_look_drop := LevelGenerator.DOWNHILL_TILT_ANGLE * SLOPE_LOOK_Y_MULT
	var dynamic_look := look_offset + Vector3(0.0, SPEED_CAM_LOOK_RISE * speed_ratio - slope_drop - tilt_look_drop, 0.0)
	var sway_x := player.velocity.x * LATERAL_SWAY_MULT
	look_at(player.global_position + dynamic_look + Vector3(sway_x, 0.0, 0.0), Vector3.UP)
	rotate_object_local(Vector3.RIGHT, deg_to_rad(-LevelGenerator.DOWNHILL_TILT_ANGLE * 0.5))
	rotate_object_local(Vector3.FORWARD, _carve_lean * CAM_CARVE_ROLL)
	_camera.fov = lerpf(_camera.fov, SPEED_FOV_BASE + SPEED_FOV_BOOST * speed_ratio, 6.0 * delta)
