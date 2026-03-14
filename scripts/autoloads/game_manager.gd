extends Node

enum State { MENU, PLAYING, PAUSED, DEAD }

var state: State = State.MENU
var current_speed: float = 12.0
var ramp_multiplier: float = 1.0  # set by player each frame; higher when going straight

const BASE_SPEED := 12.0           # Jerry's starting speed
const MAX_SPEED := 40.0            # fastest Jerry can go without leaning forward
const SPEED_RAMP_RATE := 0.5       # how many units of speed are added per second (while turning)
const STRAIGHT_RAMP_MULT := 3.0    # going straight speeds up this many times faster than turning

# Steep variant speed bonuses — added on top of the base values during steep laps
const STEEP_MAX_SPEED_BONUS := 15.0
const STEEP_RAMP_RATE_BONUS := 0.3

# Active per-lap speed caps — swapped by set_variant() each lap
var active_max_speed: float = MAX_SPEED
var active_speed_ramp_rate: float = SPEED_RAMP_RATE

@export var wife_call_interval: float = 60.0
@export var wife_call_base_threshold: float = 1500.0
@export var wife_call_threshold_ramp: float = 2000.0

var wife_killed_jerry: bool = false

var _play_elapsed: float = 0.0
var _call_minute: int = 0
var _wife_call_pending: bool = false

signal state_changed(new_state: State)
signal speed_changed(new_speed: float)
signal wife_calling()
signal game_started


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func start_game() -> void:
	current_speed = BASE_SPEED
	ramp_multiplier = 1.0
	active_max_speed = MAX_SPEED
	active_speed_ramp_rate = SPEED_RAMP_RATE
	wife_killed_jerry = false
	_play_elapsed = 0.0
	_call_minute = 0
	_wife_call_pending = false
	game_started.emit()
	_set_state(State.PLAYING)


func set_variant(variant: String) -> void:
	if variant == "steep":
		active_max_speed = MAX_SPEED + STEEP_MAX_SPEED_BONUS
		active_speed_ramp_rate = SPEED_RAMP_RATE + STEEP_RAMP_RATE_BONUS
	else:
		active_max_speed = MAX_SPEED
		active_speed_ramp_rate = SPEED_RAMP_RATE


func pause_game() -> void:
	if state == State.PLAYING:
		_set_state(State.PAUSED)
		get_tree().paused = true


func resume_game() -> void:
	if state == State.PAUSED:
		get_tree().paused = false
		_set_state(State.PLAYING)


func player_died() -> void:
	_set_state(State.DEAD)


func return_to_menu() -> void:
	get_tree().paused = false
	_set_state(State.MENU)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == State.PLAYING:
			pause_game()
		elif state == State.PAUSED:
			resume_game()


func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	if current_speed < active_max_speed:
		current_speed = minf(current_speed + active_speed_ramp_rate * ramp_multiplier * delta, active_max_speed)
		speed_changed.emit(current_speed)
	_play_elapsed += delta
	if not _wife_call_pending and _play_elapsed >= wife_call_interval * (_call_minute + 1):
		_wife_call_pending = true
		wife_calling.emit()


func resolve_wife_call() -> bool:
	_wife_call_pending = false
	var threshold := wife_call_base_threshold + _call_minute * _call_minute * wife_call_threshold_ramp
	_call_minute += 1
	return ScoreManager.fun >= threshold


func commit_wife_kill() -> void:
	wife_killed_jerry = true
	player_died()


func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(state)
