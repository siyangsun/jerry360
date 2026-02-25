extends Node

enum State { MENU, PLAYING, PAUSED, DEAD }

var state: State = State.MENU
var current_speed: float = 12.0

const BASE_SPEED := 12.0
const MAX_SPEED := 40.0
const SPEED_RAMP_RATE := 0.5  # units per second

signal state_changed(new_state: State)
signal speed_changed(new_speed: float)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func start_game() -> void:
	current_speed = BASE_SPEED
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
		current_speed = minf(current_speed + SPEED_RAMP_RATE * delta, MAX_SPEED)
		speed_changed.emit(current_speed)


func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(state)
