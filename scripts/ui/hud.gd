extends CanvasLayer

@onready var distance_label: Label = $DistanceLabel
@onready var death_screen: Control = $DeathScreen
@onready var death_label: Label = $DeathScreen/DeathLabel
@onready var _death_overlay: ColorRect = $DeathScreen/GrayOverlay
@onready var menu_screen: Control = $MenuScreen
@onready var _controls_screen: Control = $ControlsScreen
@onready var _pause_screen: Control = $PauseScreen

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
var _wife_label: Label
var _woohoo_label: Label
var _wife_audio: AudioStreamPlayer
var _wow_label: Label
var _wow_timer: float = 0.0
var _wife_call_active: bool = false
var _wife_call_timer: float = 0.0
var _wife_kill_timer: float = 0.0
var _woohoo_timer: float = 0.0

@export var fun_rate_wow_threshold: float = 20.0
@export var wow_display_time: float = 3.0
@export var wife_call_display_time: float = 3.5
@export var wife_kill_delay: float = 3.0
@export var woohoo_display_time: float = 2.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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

	_wow_label = Label.new()
	_wow_label.text = "wow this is fun!"
	_wow_label.add_theme_font_size_override("font_size", 18)
	_wow_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wow_label.visible = false
	add_child(_wow_label)

	var serif_font := SystemFont.new()
	serif_font.font_names = PackedStringArray(["Georgia", "Times New Roman", "Times", "serif"])

	_wife_label = Label.new()
	_wife_label.text = "Hi honey, are you having fun?"
	_wife_label.add_theme_font_size_override("font_size", 20)
	_wife_label.add_theme_font_override("font", serif_font)
	_wife_label.add_theme_color_override("font_color", Color.BLACK)
	_wife_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wife_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_wife_label.anchor_left = 1.0
	_wife_label.anchor_right = 1.0
	_wife_label.anchor_top = 0.5
	_wife_label.anchor_bottom = 0.5
	_wife_label.offset_left = -316.0
	_wife_label.offset_right = -16.0
	_wife_label.offset_top = -40.0
	_wife_label.offset_bottom = 40.0
	_wife_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wife_label.visible = false
	add_child(_wife_label)

	_woohoo_label = Label.new()
	_woohoo_label.text = "WOOHOO!!"
	_woohoo_label.add_theme_font_size_override("font_size", 64)
	_woohoo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_woohoo_label.anchor_left = 0.0
	_woohoo_label.anchor_right = 1.0
	_woohoo_label.anchor_top = 0.35
	_woohoo_label.anchor_bottom = 0.55
	_woohoo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_woohoo_label.visible = false
	add_child(_woohoo_label)

	_wife_audio = AudioStreamPlayer.new()
	_wife_audio.stream = load("res://assets/audio/are_you_having_fun.mp3")
	add_child(_wife_audio)

	MusicManager.song_changed.connect(_on_song_changed)
	ScoreManager.combo_changed.connect(_on_combo_changed)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.game_started.connect(_on_game_started)
	GameManager.wife_calling.connect(_on_wife_calling)
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

	if _wow_label.visible:
		if _wow_timer > 0.0:
			_wow_timer -= delta
			if _wow_timer <= 0.0:
				_wow_label.visible = false
		if is_instance_valid(_player):
			var cam := get_viewport().get_camera_3d()
			if cam:
				var screen_pos := cam.unproject_position(_player.global_position + Vector3(0, 2.2, 0))
				_wow_label.position = screen_pos + Vector2(-_wow_label.size.x * 0.5, 0.0)

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

		if _wow_timer <= 0.0 and ScoreManager.fun_rate > fun_rate_wow_threshold:
			_wow_timer = wow_display_time
			_wow_label.visible = true

		if _wife_call_active:
			_wife_call_timer -= delta
			if _wife_call_timer <= 0.0:
				_resolve_wife_call()
		if _wife_kill_timer > 0.0:
			_wife_kill_timer -= delta
			if _wife_kill_timer <= 0.0:
				GameManager.commit_wife_kill()
		if _woohoo_timer > 0.0:
			_woohoo_timer -= delta
			if _woohoo_timer <= 0.0:
				_woohoo_label.visible = false


func _on_combo_changed(count: int, multiplier: float) -> void:
	if count > 1:
		_combo_label.text = "x%.2f" % multiplier
		_combo_label.visible = GameManager.state == GameManager.State.PLAYING
	else:
		_combo_label.visible = false


func _on_state_changed(new_state: GameManager.State) -> void:
	menu_screen.visible = new_state == GameManager.State.MENU
	_controls_screen.visible = false
	_pause_screen.visible = new_state == GameManager.State.PAUSED
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
		_wife_label.visible = false
		_woohoo_label.visible = false
		_wow_label.visible = false
		_wife_call_active = false
		_wife_kill_timer = 0.0
		_wow_timer = 0.0

	if new_state == GameManager.State.DEAD:
		if GameManager.wife_killed_jerry:
			death_label.text = "should probably get on linkedin"
		else:
			var dist := ScoreManager.distance
			var best := ScoreManager.high_score
			var deaths := ScoreManager.deaths
			var tricks := ScoreManager.tricks_landed
			var top_combo := ScoreManager.max_combo
			var first_line := "Got a little too goofy." if _is_goofy else "He fell."
			var trick_str := "%d trick%s" % [tricks, "s" if tricks != 1 else ""]
			var combo_str := ("best combo x%d" % top_combo) if top_combo > 1 else "no combos"
			death_label.text = "%s\n%.0f meters — not bad for a Tuesday.\n%s  |  %s\n\nBest: %.0f m  |  Falls: %d" % [first_line, dist, trick_str, combo_str, best, deaths]


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


func _on_game_started() -> void:
	_elapsed = 0.0
	_lap_time = 0.0
	_next_lap_dist = LAP_DISTANCE
	_wife_call_active = false
	_wife_call_timer = 0.0
	_wife_kill_timer = 0.0
	_woohoo_timer = 0.0


func _on_try_again_pressed() -> void:
	GameManager.start_game()


func _on_resume_pressed() -> void:
	GameManager.resume_game()


func _on_menu_pressed() -> void:
	GameManager.return_to_menu()


func _on_nice_air(_air_time: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	_nice_air_time = 0.0
	_nice_air_label.visible = true


func _on_song_changed(song_name: String) -> void:
	_now_playing_label.text = "now playing\n" + song_name


func _on_wife_calling() -> void:
	_wife_call_active = true
	_wife_call_timer = wife_call_display_time
	_wife_label.visible = true
	_wife_audio.play()


func _resolve_wife_call() -> void:
	_wife_call_active = false
	var passed := GameManager.resolve_wife_call()
	if passed:
		_wife_label.visible = false
		_woohoo_label.visible = true
		_woohoo_timer = woohoo_display_time
	else:
		_wife_label.text = "No? Aww, I'm sorry. Dinner's ready soon!"
		_wife_kill_timer = wife_kill_delay
