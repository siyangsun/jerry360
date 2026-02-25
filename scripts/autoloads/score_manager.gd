extends Node

var distance: float = 0.0
var high_score: float = 0.0
var deaths: int = 0

signal distance_updated(dist: float)
signal new_high_score(dist: float)


func _ready() -> void:
	_load_high_score()
	GameManager.state_changed.connect(_on_state_changed)


func _on_state_changed(new_state: GameManager.State) -> void:
	if new_state == GameManager.State.PLAYING:
		distance = 0.0
	elif new_state == GameManager.State.DEAD:
		deaths += 1
		_check_high_score()


func add_distance(delta_dist: float) -> void:
	distance += delta_dist
	distance_updated.emit(distance)


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
