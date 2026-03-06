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
var _goofy_label: Label
var _goofy_time: float = 0.0
var _is_goofy: bool = false
var _danger_label: Label
var _danger_vignette: ColorRect
var _level_label: Label


func _ready() -> void:
	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 18)
	_level_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_level_label.position = Vector2(8.0, 8.0)
	_level_label.visible = false
	add_child(_level_label)

	_combo_label = Label.new()
	_combo_label.visible = false
	_combo_label.add_theme_font_size_override("font_size", 24)
	_combo_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_combo_label.position.y = 16
	_combo_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_combo_label)

	_goofy_label = Label.new()
	_goofy_label.text = "GOOFY"
	_goofy_label.visible = false
	_goofy_label.add_theme_font_size_override("font_size", 64)
	_goofy_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_goofy_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_goofy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goofy_label.position.y = 12.0
	_goofy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_goofy_label)

	_danger_vignette = ColorRect.new()
	_danger_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_danger_vignette.color = Color(1.0, 0.0, 0.0, 0.0)
	_danger_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_danger_vignette)

	_danger_label = Label.new()
	_danger_label.visible = false
	_danger_label.add_theme_font_size_override("font_size", 28)
	_danger_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_danger_label.position.y = 48
	_danger_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_danger_label)

	ScoreManager.combo_changed.connect(_on_combo_changed)
	GameManager.state_changed.connect(_on_state_changed)
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.stance_changed.connect(_on_stance_changed)
		player.wipeout_danger.connect(_on_wipeout_danger)
	call_deferred("_connect_level_generator")
	_on_state_changed(GameManager.state)


func _connect_level_generator() -> void:
	var level_gen := get_tree().get_first_node_in_group("level_generator")
	if level_gen:
		level_gen.level_changed.connect(_on_level_changed)


func _process(delta: float) -> void:
	if _goofy_label.visible:
		_goofy_time += delta
		_goofy_label.position.x = sin(_goofy_time * 27.0) * 6.0
		_goofy_label.position.y = sin(_goofy_time * 19.0) * 4.0

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
	_level_label.visible = new_state == GameManager.State.PLAYING
	if new_state != GameManager.State.PLAYING:
		_combo_label.visible = false
		_goofy_label.visible = false
		_danger_label.visible = false
		_danger_vignette.color.a = 0.0

	if new_state == GameManager.State.PLAYING:
		_elapsed = 0.0
		_lap_time = 0.0
		_next_lap_dist = LAP_DISTANCE

	if new_state == GameManager.State.DEAD:
		var dist := ScoreManager.distance
		var best := ScoreManager.high_score
		var deaths := ScoreManager.deaths
		var first_line := "Got a little too goofy." if _is_goofy else "He fell."
		death_label.text = "%s\n%.0f meters — not bad for a Tuesday.\n\nBest: %.0f m  |  Falls: %d" % [first_line, dist, best, deaths]


func _on_stance_changed(goofy: bool) -> void:
	_is_goofy = goofy
	_goofy_label.visible = goofy and GameManager.state == GameManager.State.PLAYING
	if goofy:
		_goofy_time = 0.0


func _on_wipeout_danger(intensity: float, reason: int) -> void:
	if intensity < 0.25 or GameManager.state != GameManager.State.PLAYING:
		_danger_label.visible = false
		_danger_vignette.color.a = 0.0
		return
	_danger_label.visible = true
	match reason:
		1: _danger_label.text = "WATCH IT"    # CONFLICT
		2: _danger_label.text = "LAND CLEAN"  # AIR_YAW
		3: _danger_label.text = "LEVEL OUT"   # AIR_TILT
	_danger_label.add_theme_color_override("font_color", Color(1.0, 1.0 - intensity, 0.0))
	_danger_vignette.color = Color(1.0, 0.0, 0.0, intensity * 0.18)


func _on_start_pressed() -> void:
	GameManager.start_game()


func _on_level_changed(level_name: String, level_number: int) -> void:
	_level_label.text = "LEVEL %d: %s" % [level_number, level_name]
	_level_label.visible = GameManager.state == GameManager.State.PLAYING


func _on_try_again_pressed() -> void:
	GameManager.start_game()
