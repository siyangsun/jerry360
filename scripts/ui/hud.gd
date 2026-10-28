extends CanvasLayer
## In-game overlays (stats, callouts, level sign, wife call) plus switching between the menu screens.
## Each full-screen menu is its own scene under scenes/ui/; this script only decides which one shows.
## CleanLayer (layer 3) sits above the posterize pass so the mannequin and lodge keep true colours.

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const MenuScreen = preload("res://scripts/ui/menu_screen.gd")
const DeathScreen = preload("res://scripts/ui/death_screen.gd")

@onready var distance_label: Label = $DistanceLabel
@onready var _menu: MenuScreen = $MenuScreen
@onready var _game_mode: Control = $GameModeScreen
@onready var _controls: Control = $ControlsScreen
@onready var _settings: Control = $SettingsScreen
@onready var _death: DeathScreen = $DeathScreen
@onready var _pause: Control = $PauseScreen
@onready var _lodge: Control = $CleanLayer/LodgeScreen
@onready var _screens: Array[Control] = [_menu, _game_mode, _controls, _settings, _death, _pause, _lodge]

# Palette
const COLOR_GOLD := UIKit.COLOR_GOLD
const COLOR_ORANGE := UIKit.COLOR_ORANGE
const COLOR_INK := UIKit.COLOR_INK
const COLOR_NOW_PLAYING := Color(1.0, 1.0, 1.0, 0.5)
const COLOR_SKIP := Color(1.0, 1.0, 1.0, 0.65)
const COLOR_SKIP_HOVER := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_SKIP_PRESSED := Color(1.0, 1.0, 1.0, 0.4)
const COLOR_AFTERNOON := Color(1.0, 1.0, 1.0, 0.75)
const COLOR_VIGNETTE := Color(1.0, 0.0, 0.0, 0.0)

const LAP_DISTANCE := 1000.0
const WIFE_CALL_TEXT := "Hi honey, are you having fun?"
const WIFE_CALL_CLIPS: Array[String] = [
	"res://assets/audio/sfx/are you having fun.mp3",
	"res://assets/audio/sfx/are you having fun2.mp3",
]
const WIFE_KILL_TEXT := "No? Aww, I'm sorry. Come home whenever you get the chance!"

const CLOSE_CALL_DISPLAY_TIME := 2.5
const TRICK_DISPLAY_TIME := 2.5
const CLOSE_CALL_PHRASES := [
	"close one!",
	"could almost touch it",
	"yikes, barely snuck by there",
	"whoa, that was close",
]

# Font names
const SERIF_FONT_NAMES := ["Georgia", "Times New Roman", "Times", "serif"]
const TRICK_FONT_NAMES := ["Georgia", "Times New Roman", "serif"]
const MONO_FONT_NAMES := ["Consolas", "Courier New", "monospace"]
const SIGN_FONT_NAMES := ["Bahnschrift", "Arial Narrow", "Impact", "sans-serif"]  # resort signage: condensed, bold
const SIGN_FONT_WEIGHT := 700
const SIGN_FONT_STRETCH := 75   # percent; condensed

# Ski run sign (level name)
const COLOR_SIGN_FACE := Color(0.96, 0.95, 0.9, 0.9)
const COLOR_RUN_GREEN := Color(0.1, 0.6, 0.25)
const COLOR_RUN_BLUE := Color(0.1, 0.3, 0.8)
const SIGN_BORDER := 2
const SIGN_CORNER_RADIUS := 4
const SIGN_PADDING := Vector2(10.0, 6.0)
const SIGN_SEPARATION := 8
const SIGN_SYMBOL_SIZE := 18.0
const SIGN_SYMBOL_GAP := 3
# Trail difficulty by level number: green circle, blue square, black diamond, double black
enum Run { GREEN, BLUE, BLACK, DOUBLE_BLACK }
const RUN_THRESHOLDS: Array[int] = [1, 3, 5, 7]   # first level number at each Run rating
const TUTORIAL_MAX_RUN := Run.BLUE

# Font sizes
const FONT_SIZE_LEVEL := 22
const FONT_SIZE_LEVEL_NUMBER := 12
const FONT_SIZE_COMBO := 24
const FONT_SIZE_BANNER := 64        # GOOFY, WOOHOO
const FONT_SIZE_CALLOUT := 28       # danger, nice air, trick
const FONT_SIZE_NOW_PLAYING := 17
const FONT_SIZE_SKIP := 21
const FONT_SIZE_WOW := 18
const FONT_SIZE_WIFE := 20
const FONT_SIZE_FUN_HAD := 22
const FONT_SIZE_TUTORIAL := 16
const FONT_SIZE_AFTERNOON := 14
const FONT_SIZE_CLOSE_CALL := 22

# Layout: anchors are Vector4(left, top, right, bottom); offsets use the same order
const LEVEL_POSITION := Vector2(16.0, 20.0)
const COMBO_TOP_Y := 16.0
const DANGER_TOP_Y := 48.0
const GOOFY_ANCHORS := Vector4(0.5, 0.0, 0.5, 0.0)
const GOOFY_OFFSETS := Vector4(-400.0, 60.0, 400.0, 140.0)
const NOW_PLAYING_ANCHORS := Vector4(1.0, 0.0, 1.0, 0.0)
const NOW_PLAYING_OFFSETS := Vector4(-206.0, 8.0, -8.0, 50.0)
const SKIP_ANCHORS := Vector4(1.0, 0.0, 1.0, 0.0)
const SKIP_OFFSETS := Vector4(-116.0, 62.0, -8.0, 95.0)
const WIFE_ANCHORS := Vector4(1.0, 0.5, 1.0, 0.5)
const WIFE_OFFSETS := Vector4(-316.0, -40.0, -16.0, 40.0)
const WOOHOO_ANCHORS := Vector4(0.0, 0.35, 1.0, 0.55)
const NICE_AIR_ANCHORS := Vector4(0.5, 0.5, 0.5, 0.5)
const NICE_AIR_OFFSETS := Vector4(-100.0, -20.0, 100.0, 20.0)
const TRICK_ANCHORS := Vector4(1.0, 1.0, 1.0, 1.0)
const TRICK_OFFSETS := Vector4(-347.0, -105.0, -12.0, -55.0)
const FUN_HAD_ANCHORS := Vector4(1.0, 1.0, 1.0, 1.0)
const FUN_HAD_OFFSETS := Vector4(-347.0, -50.0, -12.0, -12.0)
const TUTORIAL_ANCHORS := Vector4(0.11, 0.82, 0.9, 0.95)   # left edge clears the mannequin widget
const AFTERNOON_ANCHORS := Vector4(0.11, 0.88, 0.9, 0.96)  # left edge clears the mannequin widget
const CLOSE_CALL_ANCHORS := Vector4(0.0, 0.5, 0.5, 0.5)
const CLOSE_CALL_OFFSETS := Vector4(18.0, -16.0, 300.0, 16.0)

# Wobble: sine frequency (rad/s) and amplitude (px) per axis
const GOOFY_WOBBLE_FREQ := Vector2(27.0, 19.0)
const GOOFY_WOBBLE_AMP := Vector2(6.0, 4.0)
const NICE_AIR_WOBBLE_FREQ := Vector2(31.0, 23.0)
const NICE_AIR_WOBBLE_AMP := Vector2(5.0, 4.0)
const CLOSE_CALL_WOBBLE_FREQ := Vector2(29.0, 17.0)
const CLOSE_CALL_WOBBLE_AMP := Vector2(4.0, 3.0)

# Wipeout danger display
const DANGER_MIN_INTENSITY := 0.25
const DANGER_VIGNETTE_MAX_ALPHA := 0.18

# Wow label floats above the player (world-space offset)
const WOW_WORLD_OFFSET := Vector3(0.0, 2.5, 0.0)

var _elapsed: float = 0.0
var _lap_time: float = 0.0
var _best_lap: float = INF

# Last values written to the distance/fun labels; text is only rebuilt when these change
var _shown_dist: int = -1
var _shown_speed: int = -1
var _shown_elapsed: int = -1
var _shown_best: int = -2
var _shown_fun: int = -1
var _next_lap_dist: float = LAP_DISTANCE
var _combo_label: Label
var _goofy_label: Label
var _goofy_time: float = 0.0
var _is_goofy: bool = false
var _danger_label: Label
var _danger_vignette: ColorRect
var _nice_air_label: Label
var _nice_air_time: float = 0.0
var _trick_label: Label
var _trick_label_timer: float = 0.0
var _fun_had_label: Label
var _player: Node
var _level_sign: PanelContainer
var _level_label: Label
var _level_number_label: Label
var _run_symbols: HBoxContainer
var _skip_btn: Button
var _now_playing_label: Label
var _wife_label: Label
var _woohoo_label: Label
var _wife_audio: AudioStreamPlayer
var _wife_clips: Array[AudioStream] = []
var _wife_clip_idx: int = 0        # rotates through _wife_clips each call (per session)
var _wife_clip_active: bool = false  # clip started and not yet finished/stopped (true while paused too)
var _wow_label: Label
var _wow_timer: float = 0.0
var _wife_call_active: bool = false
var _wife_call_timer: float = 0.0
var _wife_kill_timer: float = 0.0
var _woohoo_timer: float = 0.0
var _tutorial_label: Label
var _tutorial_instructions: Array[String] = []
var _tutorial_instruction_idx: int = 0
var _tutorial_instruction_timer: float = 0.0
var _afternoon_label: Label
var _afternoon_timer: float = 0.0
var _close_call_label: Label
var _close_call_timer: float = 0.0
var _close_call_wobble_time: float = 0.0

@export var fun_rate_wow_threshold: float = 20.0
@export var wow_display_time: float = 3.0
@export var wife_call_display_time: float = 3.5
@export var wife_kill_delay: float = 3.0
@export var woohoo_display_time: float = 2.0
@export var tutorial_instruction_interval: float = 8.0
@export var afternoon_display_time: float = 5.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_level_sign()

	_combo_label = UIKit.make_label("", FONT_SIZE_COMBO, true)
	_combo_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_combo_label.position.y = COMBO_TOP_Y
	_combo_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_combo_label)

	_goofy_label = UIKit.make_label("GOOFY", FONT_SIZE_BANNER, true)
	UIKit.layout(_goofy_label, GOOFY_ANCHORS, GOOFY_OFFSETS)
	_goofy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_goofy_label)

	_danger_vignette = ColorRect.new()
	_danger_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_danger_vignette.color = COLOR_VIGNETTE
	_danger_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_danger_vignette)

	_danger_label = UIKit.make_label("", FONT_SIZE_CALLOUT, true)
	_danger_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_danger_label.position.y = DANGER_TOP_Y
	_danger_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_danger_label)

	_now_playing_label = UIKit.make_label("now playing\n", FONT_SIZE_NOW_PLAYING, true)
	_now_playing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UIKit.layout(_now_playing_label, NOW_PLAYING_ANCHORS, NOW_PLAYING_OFFSETS)
	_now_playing_label.add_theme_color_override("font_color", COLOR_NOW_PLAYING)
	add_child(_now_playing_label)

	_skip_btn = Button.new()
	_skip_btn.text = ">> skip"
	_skip_btn.add_theme_font_size_override("font_size", FONT_SIZE_SKIP)
	UIKit.layout(_skip_btn, SKIP_ANCHORS, SKIP_OFFSETS)
	_skip_btn.flat = true
	_skip_btn.add_theme_color_override("font_color", COLOR_SKIP)
	_skip_btn.add_theme_color_override("font_hover_color", COLOR_SKIP_HOVER)
	_skip_btn.add_theme_color_override("font_pressed_color", COLOR_SKIP_PRESSED)
	_skip_btn.visible = false
	_skip_btn.pressed.connect(MusicManager.skip_song)
	add_child(_skip_btn)

	_wow_label = UIKit.make_label("wow this is fun!", FONT_SIZE_WOW, true)
	add_child(_wow_label)

	_wife_label = UIKit.make_label(WIFE_CALL_TEXT, FONT_SIZE_WIFE, true)
	_wife_label.add_theme_font_override("font", UIKit.make_system_font(SERIF_FONT_NAMES))
	_wife_label.add_theme_color_override("font_color", Color.BLACK)
	_wife_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wife_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	UIKit.layout(_wife_label, WIFE_ANCHORS, WIFE_OFFSETS)
	add_child(_wife_label)

	_woohoo_label = UIKit.make_label("WOOHOO!!", FONT_SIZE_BANNER, true)
	_woohoo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.layout(_woohoo_label, WOOHOO_ANCHORS)
	add_child(_woohoo_label)

	_wife_audio = AudioStreamPlayer.new()
	_wife_audio.bus = &"SFX"
	add_child(_wife_audio)
	_wife_audio.finished.connect(_end_wife_clip)
	# load() not preload(): a clip that hasn't been imported yet is skipped instead of breaking the HUD
	for path in WIFE_CALL_CLIPS:
		if ResourceLoader.exists(path):
			_wife_clips.append(load(path))

	MusicManager.song_changed.connect(_on_song_changed)
	ScoreManager.combo_changed.connect(_on_combo_changed)
	ScoreManager.close_call.connect(_on_close_call)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.game_started.connect(_on_game_started)
	GameManager.wife_calling.connect(_on_wife_calling)
	GameManager.afternoon_started.connect(_on_afternoon_started)

	_nice_air_label = UIKit.make_label("nice air!", FONT_SIZE_CALLOUT, true)
	_nice_air_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.layout(_nice_air_label, NICE_AIR_ANCHORS, NICE_AIR_OFFSETS)
	add_child(_nice_air_label)

	_trick_label = UIKit.make_label("", FONT_SIZE_CALLOUT, true)
	_trick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UIKit.layout(_trick_label, TRICK_ANCHORS, TRICK_OFFSETS)
	_trick_label.add_theme_color_override("font_color", COLOR_ORANGE)
	_trick_label.add_theme_font_override("font", UIKit.make_system_font(TRICK_FONT_NAMES, true))
	add_child(_trick_label)

	_fun_had_label = UIKit.make_label("", FONT_SIZE_FUN_HAD, true)
	_fun_had_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UIKit.layout(_fun_had_label, FUN_HAD_ANCHORS, FUN_HAD_OFFSETS)
	_fun_had_label.add_theme_color_override("font_color", COLOR_ORANGE)
	_fun_had_label.add_theme_font_override("font", UIKit.make_system_font(MONO_FONT_NAMES))
	add_child(_fun_had_label)

	_tutorial_label = UIKit.make_label("", FONT_SIZE_TUTORIAL, true)
	_tutorial_label.add_theme_color_override("font_color", COLOR_ORANGE)
	_tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	UIKit.layout(_tutorial_label, TUTORIAL_ANCHORS)
	add_child(_tutorial_label)

	_afternoon_label = UIKit.make_label("looks like the grommets are off from school", FONT_SIZE_AFTERNOON, true)
	_afternoon_label.add_theme_color_override("font_color", COLOR_AFTERNOON)
	_afternoon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.layout(_afternoon_label, AFTERNOON_ANCHORS)
	add_child(_afternoon_label)

	_close_call_label = UIKit.make_label("", FONT_SIZE_CLOSE_CALL, true)
	_close_call_label.add_theme_color_override("font_color", COLOR_GOLD)
	_close_call_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	UIKit.layout(_close_call_label, CLOSE_CALL_ANCHORS, CLOSE_CALL_OFFSETS)
	add_child(_close_call_label)

	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_player.stance_changed.connect(_on_stance_changed)
		_player.wipeout_danger.connect(_on_wipeout_danger)
		_player.nice_air.connect(_on_nice_air)
		_player.trick_named.connect(_on_trick_named)
	_menu.play_pressed.connect(_show_screen.bind(_game_mode))
	_menu.how_to_play_pressed.connect(_show_screen.bind(_controls))
	_menu.lodge_pressed.connect(_show_screen.bind(_lodge))
	_menu.settings_pressed.connect(_show_screen.bind(_settings))
	for screen in [_game_mode, _controls, _settings, _lodge]:
		screen.back_pressed.connect(_show_screen.bind(_menu))
	call_deferred("_connect_level_generator")
	_on_state_changed(GameManager.state)


# --- Builders ---

## Shifts a label's offsets by a sine wobble around its base offsets.
func _wobble(label: Label, base_offsets: Vector4, time: float, freq: Vector2, amp: Vector2) -> void:
	var wx := sin(time * freq.x) * amp.x
	var wy := sin(time * freq.y) * amp.y
	label.offset_left = base_offsets.x + wx
	label.offset_top = base_offsets.y + wy
	label.offset_right = base_offsets.z + wx
	label.offset_bottom = base_offsets.w + wy


func _make_sign_font() -> SystemFont:
	var font := UIKit.make_system_font(SIGN_FONT_NAMES)
	font.font_weight = SIGN_FONT_WEIGHT
	font.font_stretch = SIGN_FONT_STRETCH
	return font


func _make_sign_box(face: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = face
	box.border_color = COLOR_INK
	box.set_border_width_all(SIGN_BORDER)
	box.set_corner_radius_all(SIGN_CORNER_RADIUS)
	box.content_margin_left = SIGN_PADDING.x
	box.content_margin_right = SIGN_PADDING.x
	box.content_margin_top = SIGN_PADDING.y
	box.content_margin_bottom = SIGN_PADDING.y
	return box


## Trail sign: [difficulty symbols] RUN NAME  lvl N
func _build_level_sign() -> void:
	_level_sign = PanelContainer.new()
	_level_sign.position = LEVEL_POSITION
	_level_sign.visible = false
	_level_sign.add_theme_stylebox_override("panel", _make_sign_box(COLOR_SIGN_FACE))
	add_child(_level_sign)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SIGN_SEPARATION)
	_level_sign.add_child(row)

	_run_symbols = HBoxContainer.new()
	_run_symbols.add_theme_constant_override("separation", SIGN_SYMBOL_GAP)
	_run_symbols.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_run_symbols)

	var font := _make_sign_font()
	_level_label = UIKit.make_label("", FONT_SIZE_LEVEL)
	_level_label.add_theme_font_override("font", font)
	_level_label.add_theme_color_override("font_color", COLOR_INK)
	row.add_child(_level_label)

	_level_number_label = UIKit.make_label("", FONT_SIZE_LEVEL_NUMBER)
	_level_number_label.add_theme_font_override("font", font)
	_level_number_label.add_theme_color_override("font_color", Color(COLOR_INK, 0.6))
	_level_number_label.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(_level_number_label)


func _run_for_level(level_number: int) -> Run:
	var run := Run.GREEN
	for i in RUN_THRESHOLDS.size():
		if level_number >= RUN_THRESHOLDS[i]:
			run = i as Run
	if GameManager.is_tutorial:
		run = mini(run, TUTORIAL_MAX_RUN) as Run
	return run


func _set_run_symbols(run: Run) -> void:
	for child in _run_symbols.get_children():
		child.queue_free()
	match run:
		Run.GREEN: _add_run_symbol(COLOR_RUN_GREEN, true, false)
		Run.BLUE: _add_run_symbol(COLOR_RUN_BLUE, false, false)
		Run.BLACK: _add_run_symbol(COLOR_INK, false, true)
		Run.DOUBLE_BLACK:
			_add_run_symbol(COLOR_INK, false, true)
			_add_run_symbol(COLOR_INK, false, true)


## Circle, square, or diamond (a square turned 45 degrees inside a fixed-size slot).
func _add_run_symbol(color: Color, circle: bool, diamond: bool) -> void:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2.ONE * SIGN_SYMBOL_SIZE
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var shape := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = color
	if circle:
		box.set_corner_radius_all(int(SIGN_SYMBOL_SIZE))
	shape.add_theme_stylebox_override("panel", box)
	shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var side := SIGN_SYMBOL_SIZE * (sqrt(0.5) if diamond else 1.0)  # diamond's corners stay inside the slot
	shape.size = Vector2.ONE * side
	shape.position = (slot.custom_minimum_size - shape.size) * 0.5
	shape.pivot_offset = shape.size * 0.5
	if diamond:
		shape.rotation = PI * 0.25
	slot.add_child(shape)
	_run_symbols.add_child(slot)


## Shows one full-screen menu (or none, during play) and hides the rest.
func _show_screen(screen: Control) -> void:
	for each in _screens:
		each.visible = each == screen


func _connect_level_generator() -> void:
	var level_gen := get_tree().get_first_node_in_group("level_generator")
	if level_gen:
		level_gen.level_changed.connect(_on_level_changed)
		level_gen.tutorial_stage_changed.connect(_on_tutorial_stage_changed)
		level_gen.tutorial_complete.connect(_on_tutorial_complete)


func _process(delta: float) -> void:
	if _goofy_label.visible:
		_goofy_time += delta
		_wobble(_goofy_label, GOOFY_OFFSETS, _goofy_time, GOOFY_WOBBLE_FREQ, GOOFY_WOBBLE_AMP)

	if _nice_air_label.visible:
		_nice_air_time += delta
		_wobble(_nice_air_label, NICE_AIR_OFFSETS, _nice_air_time, NICE_AIR_WOBBLE_FREQ, NICE_AIR_WOBBLE_AMP)
		if is_instance_valid(_player) and _player.is_on_floor():
			_nice_air_label.visible = false
			_nice_air_time = 0.0

	if _wow_label.visible and is_instance_valid(_player):
		var cam := _player.get_viewport().get_camera_3d()
		if cam:
			var sub_size := Vector2(_player.get_viewport().size)
			var hud_size := get_viewport().get_visible_rect().size  # logical size; the stretch mode scales the window
			var screen_pos := cam.unproject_position(_player.global_position + WOW_WORLD_OFFSET)
			screen_pos *= hud_size / sub_size
			_wow_label.position = screen_pos + Vector2(-_wow_label.size.x * 0.5, -_wow_label.size.y)

	if _trick_label.visible:
		_trick_label_timer -= delta
		if _trick_label_timer <= 0.0:
			_trick_label.visible = false

	if _close_call_label.visible:
		_close_call_timer -= delta
		_close_call_wobble_time += delta
		_wobble(_close_call_label, CLOSE_CALL_OFFSETS, _close_call_wobble_time, CLOSE_CALL_WOBBLE_FREQ, CLOSE_CALL_WOBBLE_AMP)
		if _close_call_timer <= 0.0:
			_close_call_label.visible = false

	if _wow_label.visible:
		if _wow_timer > 0.0:
			_wow_timer -= delta
			if _wow_timer <= 0.0:
				_wow_label.visible = false

	if GameManager.state == GameManager.State.PLAYING:
		_elapsed += delta
		_lap_time += delta
		if ScoreManager.distance >= _next_lap_dist:
			if _lap_time < _best_lap:
				_best_lap = _lap_time
			_lap_time = 0.0
			_next_lap_dist += LAP_DISTANCE
		var dist_m := roundi(ScoreManager.distance)
		var speed_ms := roundi(GameManager.current_speed)
		var elapsed_s := int(_elapsed)
		var best_s := int(_best_lap) if _best_lap < INF else -1
		if dist_m != _shown_dist or speed_ms != _shown_speed or elapsed_s != _shown_elapsed or best_s != _shown_best:
			_shown_dist = dist_m
			_shown_speed = speed_ms
			_shown_elapsed = elapsed_s
			_shown_best = best_s
			var best_str := "--:--"
			if best_s >= 0:
				best_str = "%d:%02d" % [best_s / 60, best_s % 60]
			distance_label.text = "%d m\n%d m/s\n%d:%02d\nBest %s" % [dist_m, speed_ms, elapsed_s / 60, elapsed_s % 60, best_str]
		var fun_shown := roundi(ScoreManager.fun)
		if fun_shown != _shown_fun:
			_shown_fun = fun_shown
			_fun_had_label.text = "fun had: %d" % fun_shown

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
		if _afternoon_timer > 0.0:
			_afternoon_timer -= delta
			if _afternoon_timer <= 0.0:
				_afternoon_label.visible = false
		if _tutorial_label.visible and _tutorial_instructions.size() > 1:
			_tutorial_instruction_timer -= delta
			if _tutorial_instruction_timer <= 0.0:
				_tutorial_instruction_idx = (_tutorial_instruction_idx + 1) % _tutorial_instructions.size()
				_tutorial_label.text = _tutorial_instructions[_tutorial_instruction_idx]
				_tutorial_instruction_timer = tutorial_instruction_interval


func _on_combo_changed(count: int, multiplier: float) -> void:
	if count > 1:
		_combo_label.text = "x%.2f" % multiplier
		_combo_label.visible = GameManager.state == GameManager.State.PLAYING
	else:
		_combo_label.visible = false


func _on_state_changed(new_state: GameManager.State) -> void:
	_sync_wife_clip(new_state)
	match new_state:
		GameManager.State.MENU:
			_show_screen(_menu)
			_menu.reset_splashes()
		GameManager.State.PAUSED:
			_show_screen(_pause)
		GameManager.State.DEAD:
			_death.show_results(_is_goofy)
			_show_screen(_death)
		_:
			_show_screen(null)
	distance_label.visible = new_state == GameManager.State.PLAYING
	_level_sign.visible = new_state == GameManager.State.PLAYING
	_skip_btn.visible = new_state == GameManager.State.PLAYING
	_now_playing_label.visible = new_state == GameManager.State.PLAYING
	_fun_had_label.visible = new_state == GameManager.State.PLAYING
	if new_state != GameManager.State.PLAYING:
		_combo_label.visible = false
		_goofy_label.visible = false
		_danger_label.visible = false
		_danger_vignette.color.a = 0.0
		_wife_label.visible = false
		_woohoo_label.visible = false
		_wow_label.visible = false
		_trick_label.visible = false
		_close_call_label.visible = false
		_wife_call_active = false
		_wife_kill_timer = 0.0
		_wow_timer = 0.0
		_tutorial_label.visible = false
		_tutorial_instructions.clear()
		_afternoon_label.visible = false
		_afternoon_timer = 0.0


func _on_stance_changed(goofy: bool) -> void:
	_is_goofy = goofy
	_goofy_label.visible = goofy and GameManager.state == GameManager.State.PLAYING
	if goofy:
		_goofy_time = 0.0


func _on_wipeout_danger(intensity: float, reason: int) -> void:
	if intensity < DANGER_MIN_INTENSITY or GameManager.state != GameManager.State.PLAYING:
		_danger_label.visible = false
		_danger_vignette.color.a = 0.0
		return
	_danger_label.visible = true
	match reason:
		1: _danger_label.text = "WATCH IT"    # CONFLICT
		2: _danger_label.text = "LAND CLEAN"  # AIR_YAW
		3: _danger_label.text = "LEVEL OUT"   # AIR_TILT
	_danger_label.add_theme_color_override("font_color", Color(1.0, 1.0 - intensity, 0.0))
	_danger_vignette.color = Color(1.0, 0.0, 0.0, intensity * DANGER_VIGNETTE_MAX_ALPHA)


func _on_level_changed(level_name: String, level_number: int) -> void:
	_level_label.text = level_name
	_level_number_label.text = "lvl %d" % level_number
	_set_run_symbols(_run_for_level(level_number))
	_level_sign.visible = GameManager.state == GameManager.State.PLAYING


func _on_game_started() -> void:
	_elapsed = 0.0
	_lap_time = 0.0
	_next_lap_dist = LAP_DISTANCE
	_wife_call_active = false
	_wife_call_timer = 0.0
	_wife_kill_timer = 0.0
	_woohoo_timer = 0.0
	_wife_label.text = WIFE_CALL_TEXT


func _on_nice_air(_air_time: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	_nice_air_time = 0.0
	_nice_air_label.visible = true


func _on_trick_named(trick: String) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	_trick_label.text = trick
	_trick_label.visible = true
	_trick_label_timer = TRICK_DISPLAY_TIME


func _on_song_changed(song_name: String) -> void:
	_now_playing_label.text = "now playing\n" + song_name


func _on_wife_calling() -> void:
	_wife_call_active = true
	_wife_call_timer = wife_call_display_time
	_wife_label.visible = true
	if not _wife_clips.is_empty():
		_wife_audio.stream = _wife_clips[_wife_clip_idx % _wife_clips.size()]
		_wife_clip_idx += 1
		_wife_audio.play()
		_wife_clip_active = true
		MusicManager.duck(true)


## Wife clip follows the game state: pauses with the game (music un-ducks while paused),
## resumes ducked, and is cut on menu/death so the music is never left quiet.
func _sync_wife_clip(new_state: GameManager.State) -> void:
	if not _wife_clip_active:
		return
	match new_state:
		GameManager.State.PLAYING:
			_wife_audio.stream_paused = false
			MusicManager.duck(true)
		GameManager.State.PAUSED:
			_wife_audio.stream_paused = true
			MusicManager.duck(false)
		_:
			_wife_audio.stop()
			_end_wife_clip()


func _end_wife_clip() -> void:
	_wife_clip_active = false
	_wife_audio.stream_paused = false
	MusicManager.duck(false)


func _resolve_wife_call() -> void:
	_wife_call_active = false
	var passed := GameManager.resolve_wife_call()
	if passed:
		_wife_label.visible = false
		_woohoo_label.visible = true
		_woohoo_timer = woohoo_display_time
	else:
		_wife_label.text = WIFE_KILL_TEXT
		_wife_kill_timer = wife_kill_delay


func _on_tutorial_stage_changed(stage_index: int) -> void:
	_tutorial_instructions.clear()
	_tutorial_instruction_idx = 0
	var path := "res://assets/tutorial/stage_%d.txt" % (stage_index + 1)
	var f := FileAccess.open(path, FileAccess.READ)
	if f:
		while not f.eof_reached():
			var line := f.get_line().strip_edges()
			if line.length() > 0:
				_tutorial_instructions.append(line)
		f.close()
	if _tutorial_instructions.size() > 0:
		_tutorial_label.text = _tutorial_instructions[0]
		_tutorial_label.visible = true
		_tutorial_instruction_timer = tutorial_instruction_interval
	else:
		_tutorial_label.visible = false


func _on_afternoon_started() -> void:
	_afternoon_label.visible = true
	_afternoon_timer = afternoon_display_time


func _on_tutorial_complete() -> void:
	_tutorial_label.visible = false
	AppearanceManager.unlock_tutorial_board()
	GameManager.return_to_menu()


func _on_close_call() -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	_close_call_label.text = CLOSE_CALL_PHRASES[randi() % CLOSE_CALL_PHRASES.size()]
	_close_call_label.visible = true
	_close_call_timer = CLOSE_CALL_DISPLAY_TIME
	_close_call_wobble_time = 0.0

