extends Node3D
## Follows the player with a fixed downhill camera angle.

@export var player: CharacterBody3D
@export var offset := Vector3(0.0, 2.5, 8.0)        # behind and above
@export var look_offset := Vector3(0.0, 2.0, -12.0) # point ahead of player
@export var follow_speed := 8.0
@export var lateral_follow_speed := 12.0

const SPEED_CAM_HEIGHT_DROP := 1.0  # how much lower the camera gets at max speed
const SPEED_CAM_LOOK_RISE   := 1.0  # how much higher the look target gets at max speed
const LATERAL_SWAY_MULT     := 0.04 # look-target x shift per m/s of lateral velocity


func _ready() -> void:
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

	var dynamic_offset := offset + Vector3(0.0, -SPEED_CAM_HEIGHT_DROP * speed_ratio, 0.0)
	var target_pos := player.global_position + dynamic_offset
	var new_pos := global_position
	new_pos.x = lerpf(new_pos.x, target_pos.x, lateral_follow_speed * delta)
	new_pos.y = lerpf(new_pos.y, target_pos.y, follow_speed * delta)
	new_pos.z = target_pos.z
	global_position = new_pos

	var dynamic_look := look_offset + Vector3(0.0, SPEED_CAM_LOOK_RISE * speed_ratio, 0.0)
	var sway_x := player.velocity.x * LATERAL_SWAY_MULT
	look_at(player.global_position + dynamic_look + Vector3(sway_x, 0.0, 0.0), Vector3.UP)
