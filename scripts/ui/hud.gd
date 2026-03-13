extends CanvasLayer

@onready var distance_label: Label = $DistanceLabel
@onready var death_screen: Control = $DeathScreen
@onready var death_label: Label = $DeathScreen/DeathLabel
@onready var _death_overlay: ColorRect = $DeathScreen/GrayOverlay
@onready var menu_screen: Control = $MenuScreen
@onready var _controls_screen: Control = $ControlsScreen

const SCREEN_OVERLAY_COLOR := Color(0.15, 0.15, 0.15, 0.3)

const CONTROLS_DATA: Array[Dictionary] = [
	{"key": "← →",        "desc": "Steer the board left and right"},
	{"key": "A / D",       "desc": "Lean — shifts weight sideways and carves"},
	{"key": "Space / ↑",   "desc": "Jump"},
	{"key": "↓  (hold)",   "desc": "Charge a jump — release to launch higher"},
	{"key": "W  (hold)",   "desc": "Lean forward — accelerate past top speed"},
	{"key": "S  (hold)",   "desc": "Lean back — brake on the ground, or prep for landing"},
	{"key": "← → (air)",  "desc": "Spin tricks — land straight to score and boost"},
	{"key": "Esc",         "desc": "Pause"},
]

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
var _nice_air_label: Label
var _nice_air_time: float = 0.0
var _player: Node
var _level_label: Label
var _skip_btn: Button
var _now_playing_label: Label


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

	_now_playing_label = Label.new()
	_now_playing_label.text = "now playing\n"
	_now_playing_label.add_theme_font_size_override("font_size", 11)
	_now_playing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_now_playing_label.anchor_left = 1.0
	_now_playing_label.anchor_right = 1.0
	_now_playing_label.anchor_top = 0.0
	_now_playing_label.anchor_bottom = 0.0
	_now_playing_label.offset_right = -8.0
	_now_playing_label.offset_left = -140.0
	_now_playing_label.offset_top = 8.0
	_now_playing_label.offset_bottom = 36.0
	_now_playing_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	_now_playing_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_now_playing_label.visible = false
	add_child(_now_playing_label)

	_skip_btn = Button.new()
	_skip_btn.text = ">> skip"
	_skip_btn.add_theme_font_size_override("font_size", 14)
	_skip_btn.anchor_left = 1.0
	_skip_btn.anchor_right = 1.0
	_skip_btn.anchor_top = 0.0
	_skip_btn.anchor_bottom = 0.0
	_skip_btn.offset_right = -8.0
	_skip_btn.offset_left = -80.0
	_skip_btn.offset_top = 38.0
	_skip_btn.offset_bottom = 60.0
	_skip_btn.flat = true
	_skip_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	_skip_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1.0))
	_skip_btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 0.4))
	_skip_btn.visible = false
	_skip_btn.pressed.connect(MusicManager.skip_song)
	add_child(_skip_btn)

	MusicManager.song_changed.connect(_on_song_changed)
	ScoreManager.combo_changed.connect(_on_combo_changed)
	GameManager.state_changed.connect(_on_state_changed)
	_nice_air_label = Label.new()
	_nice_air_label.text = "nice air!"
	_nice_air_label.visible = false
	_nice_air_label.add_theme_font_size_override("font_size", 28)
	_nice_air_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nice_air_label.anchor_left = 0.5
	_nice_air_label.anchor_right = 0.5
	_nice_air_label.anchor_top = 0.5
	_nice_air_label.anchor_bottom = 0.5
	_nice_air_label.offset_left = -100.0
	_nice_air_label.offset_right = 100.0
	_nice_air_label.offset_top = -20.0
	_nice_air_label.offset_bottom = 20.0
	_nice_air_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_nice_air_label)

	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_player.stance_changed.connect(_on_stance_changed)
		_player.wipeout_danger.connect(_on_wipeout_danger)
		_player.nice_air.connect(_on_nice_air)
	_death_overlay.color = SCREEN_OVERLAY_COLOR
	_build_controls_screen()
	call_deferred("_connect_level_generator")
	_on_state_changed(GameManager.state)


func _build_controls_screen() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = SCREEN_OVERLAY_COLOR
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls_screen.add_child(overlay)

	var title := Label.new()
	title.text = "HOW TO PLAY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.anchor_top = 0.06
	title.anchor_bottom = 0.18
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.1, 1))
	_controls_screen.add_child(title)

	var list := VBoxContainer.new()
	list.anchor_left = 0.1
	list.anchor_right = 0.9
	list.anchor_top = 0.20
	list.anchor_bottom = 0.85
	list.add_theme_constant_override("separation", 10)
	_controls_screen.add_child(list)

	for entry in CONTROLS_DATA:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var key_label := Label.new()
		key_label.text = entry["key"]
		key_label.custom_minimum_size.x = 160
		key_label.add_theme_font_size_override("font_size", 16)
		key_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.1, 1))
		row.add_child(key_label)

		var desc_label := Label.new()
		desc_label.text = entry["desc"]
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_label.add_theme_font_size_override("font_size", 16)
		row.add_child(desc_label)

		list.add_child(row)

	var back_btn := Button.new()
	back_btn.text = "< Back"
	back_btn.anchor_left = 0.38
	back_btn.anchor_right = 0.62
	back_btn.anchor_top = 0.88
	back_btn.anchor_bottom = 0.96
	back_btn.pressed.connect(_on_controls_back_pressed)
	_controls_screen.add_child(back_btn)


func _connect_level_generator() -> void:
	var level_gen := get_tree().get_first_node_in_group("level_generator")
	if level_gen:
		level_gen.level_changed.connect(_on_level_changed)


func _process(delta: float) -> void:
	if _goofy_label.visible:
		_goofy_time += delta
		_goofy_label.position.x = sin(_goofy_time * 27.0) * 6.0
		_goofy_label.position.y = sin(_goofy_time * 19.0) * 4.0

	if _nice_air_label.visible:
		_nice_air_time += delta
		var wx := sin(_nice_air_time * 31.0) * 5.0
		var wy := sin(_nice_air_time * 23.0) * 4.0
		_nice_air_label.offset_left = -100.0 + wx
		_nice_air_label.offset_right =  100.0 + wx
		_nice_air_label.offset_top  =  -20.0 + wy
		_nice_air_label.offset_bottom =  20.0 + wy
		if is_instance_valid(_player) and _player.is_on_floor():
			_nice_air_label.visible = false
			_nice_air_time = 0.0

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
		distance_label.text = "%.0f m\n%.0f m/s\n%d:%02d\nBest %s\nfun had: %.0f" % [ScoreManager.distance, GameManager.current_speed, mins, secs, best_str, ScoreManager.fun]


func _on_combo_changed(count: int, multiplier: float) -> void:
	if count > 1:
		_combo_label.text = "x%.2f" % multiplier
		_combo_label.visible = GameManager.state == GameManager.State.PLAYING
	else:
		_combo_label.visible = false


func _on_state_changed(new_state: GameManager.State) -> void:
	menu_screen.visible = new_state == GameManager.State.MENU
	_controls_screen.visible = false
	death_screen.visible = new_state == GameManager.State.DEAD
	distance_label.visible = new_state == GameManager.State.PLAYING
	_level_label.visible = new_state == GameManager.State.PLAYING
	_skip_btn.visible = new_state == GameManager.State.PLAYING
	_now_playing_label.visible = new_state == GameManager.State.PLAYING
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


func _on_how_to_play_pressed() -> void:
	menu_screen.visible = false
	_controls_screen.visible = true


func _on_controls_back_pressed() -> void:
	_controls_screen.visible = false
	menu_screen.visible = true


func _on_start_pressed() -> void:
	GameManager.start_game()


func _on_level_changed(level_name: String, level_number: int) -> void:
	_level_label.text = "LEVEL %d: %s" % [level_number, level_name]
	_level_label.visible = GameManager.state == GameManager.State.PLAYING


func _on_try_again_pressed() -> void:
	GameManager.start_game()


func _on_nice_air(_air_time: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	_nice_air_time = 0.0
	_nice_air_label.visible = true


func _on_song_changed(song_name: String) -> void:
	_now_playing_label.text = "now playing\n" + song_name
