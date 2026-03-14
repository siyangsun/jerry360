extends Node

const AiRider = preload("res://scripts/world/ai_rider.gd")

const SPAWN_DISTANCE_AHEAD := 110.0   # how far in front of the player riders appear
const DESPAWN_DISTANCE_BEHIND := 35.0 # how far behind the player before a rider is freed
const MAX_RIDERS_MAIN_RUN := 12
const SPAWN_INTERVAL_MAIN_RUN := 1.2  # seconds between spawns on a main run
const MAX_RIDERS_AFTERNOON := 2
const SPAWN_INTERVAL_AFTERNOON := 40.0  # infrequent background riders in the afternoon

var _spawn_timer: float = 0.0
var _is_main_run: bool = false
var _player: Node3D


func _ready() -> void:
	call_deferred("_connect_signals")


func _connect_signals() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node3D
	var level_gen := get_tree().get_first_node_in_group("level_generator")
	if level_gen:
		level_gen.level_changed.connect(_on_level_changed)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.game_started.connect(_on_game_started)


func _process(delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING or GameManager.is_tutorial:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return

	_despawn_stale()

	var max_riders: int
	var spawn_interval: float
	if _is_main_run:
		max_riders = MAX_RIDERS_MAIN_RUN
		spawn_interval = SPAWN_INTERVAL_MAIN_RUN
	elif GameManager.is_afternoon:
		max_riders = MAX_RIDERS_AFTERNOON
		spawn_interval = SPAWN_INTERVAL_AFTERNOON
	else:
		return

	if get_tree().get_nodes_in_group("ai_rider").size() >= max_riders:
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_rider()
		_spawn_timer = spawn_interval


func _spawn_rider() -> void:
	var rider := AiRider.new()
	rider.position = Vector3(0.0, 0.5, _player.position.z - SPAWN_DISTANCE_AHEAD)
	get_parent().add_child(rider)


func _despawn_stale() -> void:
	for rider in get_tree().get_nodes_in_group("ai_rider"):
		if rider.position.z > _player.position.z + DESPAWN_DISTANCE_BEHIND:
			rider.queue_free()


func _on_level_changed(level_name: String, _level_number: int) -> void:
	_is_main_run = "MAIN LANE" in level_name
	if _is_main_run:
		_spawn_timer = 0.5  # kick off a spawn quickly when the level starts


func _on_game_started() -> void:
	for rider in get_tree().get_nodes_in_group("ai_rider"):
		rider.queue_free()
	_is_main_run = false
	_spawn_timer = 0.0


func _on_state_changed(new_state: GameManager.State) -> void:
	if new_state != GameManager.State.PLAYING:
		for rider in get_tree().get_nodes_in_group("ai_rider"):
			rider.queue_free()
		_is_main_run = false
		_spawn_timer = 0.0
