extends Node

enum State { MENU, PLAYING, PAUSED, DEAD }

var state: State = State.MENU
var current_speed: float = 12.0
var ramp_multiplier: float = 1.0  # set by player each frame; >1 when going straight

const BASE_SPEED := 12.0
const MAX_SPEED := 40.0
const SPEED_RAMP_RATE := 0.5       # units/sec at base (turning)
const STRAIGHT_RAMP_MULT := 3.0    # how many times faster when going straight

signal state_changed(new_state: State)
signal speed_changed(new_speed: float)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func start_game() -> void:
	current_speed = BASE_SPEED
	ramp_multiplier = 1.0
	_set_state(State.PLAYING)


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


func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	if current_speed < MAX_SPEED:
		current_speed = minf(current_speed + SPEED_RAMP_RATE * ramp_multiplier * delta, MAX_SPEED)
		speed_changed.emit(current_speed)


func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(state)
