extends Node

var distance: float = 0.0
var high_score: float = 0.0
var deaths: int = 0
var combo_count: int = 0
var combo_multiplier: float = 1.0
var fun: float = 0.0

const COMBO_MULT_PER_COUNT := 0.25  # score multiplier added per trick in a combo (stacks up)
const COMBO_MAX_MULTIPLIER := 4.0   # highest possible score multiplier, no matter how big the combo

@export var fun_speed_rate: float = 0.3         # fun per (m/s * second) — scales with speed and multiplier
@export var fun_airtime_rate: float = 3.0       # fun per (air_seconds * speed) awarded on clean landing
@export var fun_rail_rate_mult: float = 2.0     # fun rate multiplier while grinding a rail
@export var fun_carve_rate_bonus: float = 0.5   # max additional fun rate when fully carving (added on top)

signal distance_updated(dist: float)
signal new_high_score(dist: float)
signal combo_changed(count: int, multiplier: float)
signal trick_landed(is_stomp: bool)
signal fun_updated(fun: float)


func _ready() -> void:
	_load_high_score()
	GameManager.state_changed.connect(_on_state_changed)


func _on_state_changed(new_state: GameManager.State) -> void:
	if new_state == GameManager.State.PLAYING:
		distance = 0.0
		fun = 0.0
		reset_combo()
	elif new_state == GameManager.State.DEAD:
		deaths += 1
		reset_combo()
		_check_high_score()


func add_distance(delta_dist: float) -> void:
	distance += delta_dist * combo_multiplier
	distance_updated.emit(distance)


func add_fun_continuous(speed: float, delta: float, on_rail: bool = false, carve_intensity: float = 0.0) -> void:
	var rate_mult := fun_rail_rate_mult if on_rail else 1.0
	rate_mult += carve_intensity * fun_carve_rate_bonus
	fun += speed * fun_speed_rate * rate_mult * combo_multiplier * delta
	fun_updated.emit(fun)


func add_fun_airtime(air_time: float, speed: float) -> void:
	fun += air_time * speed * fun_airtime_rate * combo_multiplier
	fun_updated.emit(fun)


func add_trick(is_stomp: bool) -> void:
	combo_count += 1
	combo_multiplier = minf(1.0 + combo_count * COMBO_MULT_PER_COUNT, COMBO_MAX_MULTIPLIER)
	combo_changed.emit(combo_count, combo_multiplier)
	trick_landed.emit(is_stomp)


func reset_combo() -> void:
	if combo_count == 0:
		return
	combo_count = 0
	combo_multiplier = 1.0
	combo_changed.emit(combo_count, combo_multiplier)


func _check_high_score() -> void:
	if distance > high_score:
		high_score = distance
		new_high_score.emit(high_score)
		_save_high_score()


func _save_high_score() -> void:
	var config := ConfigFile.new()
	config.load("user://scores.cfg")
	config.set_value("scores", "high_score", high_score)
	config.set_value("scores", "deaths", deaths)
	config.save("user://scores.cfg")


func _load_high_score() -> void:
	var config := ConfigFile.new()
	if config.load("user://scores.cfg") == OK:
		high_score = config.get_value("scores", "high_score", 0.0)
		deaths = config.get_value("scores", "deaths", 0)
