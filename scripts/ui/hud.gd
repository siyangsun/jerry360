extends CanvasLayer

@onready var distance_label: Label = $DistanceLabel
@onready var death_screen: Control = $DeathScreen
@onready var death_label: Label = $DeathScreen/DeathLabel
@onready var menu_screen: Control = $MenuScreen

const LAP_DISTANCE := 1000.0

var _elapsed: float = 0.0
var _lap_time: float = 0.0
var _best_lap: float = INF
var _next_lap_dist: float = LAP_DISTANCE
var _combo_label: Label


func _ready() -> void:
	_combo_label = Label.new()
	_combo_label.visible = false
	_combo_label.add_theme_font_size_override("font_size", 24)
	_combo_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_combo_label.position.y = 16
	_combo_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_combo_label)
	ScoreManager.combo_changed.connect(_on_combo_changed)
	GameManager.state_changed.connect(_on_state_changed)
	_on_state_changed(GameManager.state)


func _process(delta: float) -> void:
	if GameManager.state == GameManager.State.PLAYING:
		_elapsed += delta
		_lap_time += delta
		if ScoreManager.distance >= _next_lap_dist:
			if _lap_time < _best_lap:
				_best_lap = _lap_time
			_lap_time = 0.0
			_next_lap_dist += LAP_DISTANCE
		var mins := int(_elapsed) / 60
		var secs := int(_elapsed) % 60
		var best_str := "--:--"
		if _best_lap < INF:
			best_str = "%d:%02d" % [int(_best_lap) / 60, int(_best_lap) % 60]
		distance_label.text = "%.0f m\n%.0f m/s\n%d:%02d\nBest %s" % [ScoreManager.distance, GameManager.current_speed, mins, secs, best_str]


func _on_combo_changed(count: int, multiplier: float) -> void:
	if count > 1:
		_combo_label.text = "x%.2f" % multiplier
		_combo_label.visible = GameManager.state == GameManager.State.PLAYING
	else:
		_combo_label.visible = false


func _on_state_changed(new_state: GameManager.State) -> void:
	menu_screen.visible = new_state == GameManager.State.MENU
	death_screen.visible = new_state == GameManager.State.DEAD
	distance_label.visible = new_state == GameManager.State.PLAYING
	if new_state != GameManager.State.PLAYING:
		_combo_label.visible = false

	if new_state == GameManager.State.PLAYING:
		_elapsed = 0.0
		_lap_time = 0.0
		_next_lap_dist = LAP_DISTANCE

	if new_state == GameManager.State.DEAD:
		var dist := ScoreManager.distance
		var best := ScoreManager.high_score
		var deaths := ScoreManager.deaths
		death_label.text = "He fell.\n%.0f meters — not bad for a Tuesday.\n\nBest: %.0f m  |  Falls: %d" % [dist, best, deaths]


func _on_start_pressed() -> void:
	GameManager.start_game()


func _on_try_again_pressed() -> void:
	GameManager.start_game()
