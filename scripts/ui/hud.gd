extends CanvasLayer

@onready var distance_label: Label = $DistanceLabel
@onready var death_screen: Control = $DeathScreen
@onready var death_label: Label = $DeathScreen/DeathLabel
@onready var _death_overlay: ColorRect = $DeathScreen/GrayOverlay
@onready var menu_screen: Control = $MenuScreen
@onready var _game_mode_screen: Control = $GameModeScreen
@onready var _customize_screen: Control = $CustomizeScreen
@onready var _controls_screen: Control = $ControlsScreen
@onready var _pause_screen: Control = $PauseScreen
@onready var _settings_screen: Control = $SettingsScreen

const Mannequin = preload("res://scripts/ui/mannequin.gd")
const ABOVE_POSTERIZE_LAYER := 3   # above the posterize CanvasLayer (layer 2): mannequin + lodge stay uncrunched

const SCREEN_OVERLAY_COLOR := Color(0.15, 0.15, 0.15, 0.3)

# Palette
const COLOR_GOLD := Color(1.0, 0.82, 0.1, 1.0)
const COLOR_ORANGE := Color(1.0, 0.45, 0.05, 1.0)
const COLOR_NOW_PLAYING := Color(1.0, 1.0, 1.0, 0.5)
const COLOR_SKIP := Color(1.0, 1.0, 1.0, 0.65)
const COLOR_SKIP_HOVER := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_SKIP_PRESSED := Color(1.0, 1.0, 1.0, 0.4)
const COLOR_AFTERNOON := Color(1.0, 1.0, 1.0, 0.75)
const COLOR_PREVIEW_LABEL := Color(1.0, 1.0, 1.0, 0.4)
const COLOR_PREVIEW_PANEL := Color(0.06, 0.06, 0.10)
const COLOR_VIGNETTE := Color(1.0, 0.0, 0.0, 0.0)
const COLOR_INK := Color(0.08, 0.05, 0.1, 1.0)            # sticker text/border/shadow
const COLOR_TITLE_OUTLINE := Color(1.0, 0.97, 0.55, 1.0)
const COLOR_TITLE_SHADOW := Color(0.35, 0.2, 0.0, 1.0)
const COLOR_SPLASH := Color(1.0, 1.0, 0.2, 1.0)
const COLOR_STICKER_FILL := Color(0.08, 0.05, 0.1, 0.55)        # see-through dark, slope shows behind
const COLOR_STICKER_FILL_HOVER := Color(0.08, 0.05, 0.1, 0.75)
const COLOR_STICKER_EDGE := Color(1.0, 1.0, 1.0, 0.7)
const COLOR_STICKER_TEXT := Color(1.0, 1.0, 1.0, 0.92)

# Title screen splash: one picked at random every time the menu comes up
const MENU_TAGLINES: Array[String] = [
	"he cannot stop!",
	"brakes sold separately",
	"now with snow!",
	"100% downhill",
	"tax deductible?",
	"fired on a Tuesday",
	"grandpa's board!",
	"regular footed, mostly",
	"no poles!",
]

const CONTROLS_DATA: Array[Dictionary] = [
	{"key": "Left / Right",        "desc": "Steer the board left and right"},
	{"key": "A / D",               "desc": "Lean — shifts weight sideways and carves"},
	{"key": "Space",               "desc": "Jump — hold to charge, release to launch higher"},
	{"key": "W  (hold)",           "desc": "Lean forward — accelerate past top speed"},
	{"key": "S  (hold)",           "desc": "Lean back — brake on the ground, or hold before landing to widen your safe landing angle"},
	{"key": "Left / Right (air)",  "desc": "Spin — land within 180° of straight to score and boost speed"},
	{"key": "Up / Down (air)",     "desc": "Front / backflip — land upright to score (worth 3× a spin)"},
	{"key": "Lean + Turn",         "desc": "Always lean and turn the same direction — opposing inputs will cause a wipeout"},
	{"key": "Scoring",             "desc": "Distance × speed × combo multiplier — clean trick landings grow your combo; sloppy ones cost speed"},
	{"key": "Close calls",         "desc": "Narrowly dodge an obstacle above 30 m/s for bonus fun"},
	{"key": "Esc",                 "desc": "Pause"},
]

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
const FONT_SIZE_FUN_HAD := 18
const FONT_SIZE_TUTORIAL := 16
const FONT_SIZE_AFTERNOON := 14
const FONT_SIZE_CLOSE_CALL := 22
const FONT_SIZE_CONTROLS_TITLE := 48
const FONT_SIZE_CONTROLS_ROW := 16
const FONT_SIZE_CUSTOMIZE_TITLE := 36
const FONT_SIZE_CUSTOMIZE_SECTION := 18
const FONT_SIZE_PREVIEW := 13
const FONT_SIZE_TITLE := 96
const FONT_SIZE_SPLASH := 22
const FONT_SIZE_STICKER := 20
const FONT_SIZE_SETTINGS_ROW := 20

# Layout: anchors are Vector4(left, top, right, bottom); offsets use the same order
const LEVEL_POSITION := Vector2(8.0, 8.0)
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

const CONTROLS_TITLE_ANCHORS := Vector4(0.0, 0.06, 1.0, 0.18)
const CONTROLS_LIST_ANCHORS := Vector4(0.1, 0.20, 0.9, 0.85)
const CONTROLS_BACK_ANCHORS := Vector4(0.38, 0.88, 0.62, 0.96)
const CONTROLS_LIST_SEPARATION := 10
const CONTROLS_KEY_COLUMN_WIDTH := 160.0

const CUSTOMIZE_TITLE_ANCHORS := Vector4(0.04, 0.04, 0.56, 0.16)
# Option rows (label + swatches on one line), stacked from the first row's anchors by CUSTOMIZE_ROW_STEP
const CUSTOMIZE_FIRST_ROW_ANCHORS := Vector4(0.04, 0.18, 0.60, 0.27)
const CUSTOMIZE_ROW_STEP := 0.13
const CUSTOMIZE_ROW_LABEL_WIDTH := 110.0
const CUSTOMIZE_BACK_ANCHORS := Vector4(0.04, 0.88, 0.22, 0.96)
const PREVIEW_PANEL_ANCHORS := Vector4(0.62, 0.10, 0.96, 0.86)
const PREVIEW_LABEL_ANCHORS := Vector4(0.0, 0.04, 1.0, 0.14)
const PREVIEW_PANEL_CORNER_RADIUS := 4
const PREVIEW_BODY_WIDTH := 60.0   # px for the torso's 0.6 m jacket-front face; sets the preview's px-per-metre
const PREVIEW_FEET_Y := 35.0       # px offset of the feet from the panel centre
const PREVIEW_LID_SCALE := 1.43    # preview-only: enlarges the 0.28 m lid (28 px -> ~40 px) so it reads in the lodge
const PREVIEW_BOARD_OFFSETS := Vector4(-13.0, -4.0, 13.0, 100.0)   # upright board sprite, then rotated flat
const PREVIEW_BOARD_ROTATION := -PI * 0.5  # nose left, so sprite text reads upright
const CENTER_ANCHORS := Vector4(0.5, 0.5, 0.5, 0.5)

# Title: wobbling gold logo that does a full 360 when clicked
const TITLE_ANCHORS := Vector4(0.0, 0.33, 1.0, 0.33)   # zero-height; fit_content grows it downward
const TITLE_GLYPH_SPACING := 5
const TITLE_OUTLINE_SIZE := 2
const TITLE_SHADOW_OFFSET := 2
const TITLE_WAVE_AMP := 40       # BBCode [wave] units
const TITLE_WAVE_FREQ := 4.0
const TITLE_SPIN_TIME := 0.9
# Splashes: right one is a random tagline, left one is fixed; click either and it fades away until next visit
const SPLASH_ANCHORS := Vector4(0.5, 0.0, 0.5, 0.0)
const SPLASH_OFFSETS := Vector4(130.0, 345.0, 490.0, 380.0)        # tucked under the right end of the title
const SPLASH_LEFT_OFFSETS := Vector4(-500.0, 230.0, -140.0, 265.0)  # above the left end of the title
const SPLASH_ROTATION := -PI / 14.0
const SPLASH_LEFT_TEXT := "it's really fun apparently!"
const SPLASH_FADE_TIME := 0.4
const SPLASH_PULSE_FREQ := 9.0   # rad/s
const SPLASH_PULSE_AMP := 0.08   # fraction of base scale

# Sticker buttons: see-through dark, gold on hover. Kept straight: tilted edges stair-step
const STICKER_BORDER := 2

# Settings ("KNOBS")
const SAVE_PATH := "user://scores.cfg"
const SETTINGS_SECTION := "settings"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
const KEY_FULLSCREEN := "fullscreen"
const VOLUME_STEP := 0.05
const SETTINGS_LIST_ANCHORS := Vector4(0.25, 0.30, 0.75, 0.70)
const SETTINGS_LIST_SEPARATION := 28
const SETTINGS_LABEL_WIDTH := 190.0
const SLIDER_THICKNESS := 18.0

# Swatches
const SWATCH_SIZE := Vector2(52.0, 52.0)
const SWATCH_SEPARATION := 10
const SWATCH_CORNER_RADIUS := 3
const SWATCH_SELECTED_BORDER := 3
const SWATCH_TEXTURE_BG := Color(0.06, 0.06, 0.10)  # behind goggle/board thumbnails

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
var _swatch_styles: Dictionary = {}  # appearance part (StringName) -> Array of StyleBoxFlat
var _board_hbox: HBoxContainer
var _preview_helmet: ColorRect
var _preview_jacket: TextureRect
var _preview_goggles: TextureRect
var _preview_pants: ColorRect
var _preview_board: TextureRect
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
var _title: RichTextLabel
var _title_tween: Tween
var _splash_label: Label
var _splash_left: Label
var _splash_time: float = 0.0
var _settings: Dictionary = {BUS_MUSIC: 1.0, BUS_SFX: 1.0, KEY_FULLSCREEN: false}  # written to SAVE_PATH on leaving KNOBS

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

	_combo_label = _make_label("", FONT_SIZE_COMBO, true)
	_combo_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_combo_label.position.y = COMBO_TOP_Y
	_combo_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_combo_label)

	_goofy_label = _make_label("GOOFY", FONT_SIZE_BANNER, true)
	_layout(_goofy_label, GOOFY_ANCHORS, GOOFY_OFFSETS)
	_goofy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_goofy_label)

	_danger_vignette = ColorRect.new()
	_danger_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_danger_vignette.color = COLOR_VIGNETTE
	_danger_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_danger_vignette)

	_danger_label = _make_label("", FONT_SIZE_CALLOUT, true)
	_danger_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_danger_label.position.y = DANGER_TOP_Y
	_danger_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_danger_label)

	_now_playing_label = _make_label("now playing\n", FONT_SIZE_NOW_PLAYING, true)
	_now_playing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_layout(_now_playing_label, NOW_PLAYING_ANCHORS, NOW_PLAYING_OFFSETS)
	_now_playing_label.add_theme_color_override("font_color", COLOR_NOW_PLAYING)
	add_child(_now_playing_label)

	_skip_btn = Button.new()
	_skip_btn.text = ">> skip"
	_skip_btn.add_theme_font_size_override("font_size", FONT_SIZE_SKIP)
	_layout(_skip_btn, SKIP_ANCHORS, SKIP_OFFSETS)
	_skip_btn.flat = true
	_skip_btn.add_theme_color_override("font_color", COLOR_SKIP)
	_skip_btn.add_theme_color_override("font_hover_color", COLOR_SKIP_HOVER)
	_skip_btn.add_theme_color_override("font_pressed_color", COLOR_SKIP_PRESSED)
	_skip_btn.visible = false
	_skip_btn.pressed.connect(MusicManager.skip_song)
	add_child(_skip_btn)

	_wow_label = _make_label("wow this is fun!", FONT_SIZE_WOW, true)
	add_child(_wow_label)

	_wife_label = _make_label(WIFE_CALL_TEXT, FONT_SIZE_WIFE, true)
	_wife_label.add_theme_font_override("font", _make_system_font(SERIF_FONT_NAMES))
	_wife_label.add_theme_color_override("font_color", Color.BLACK)
	_wife_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wife_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_layout(_wife_label, WIFE_ANCHORS, WIFE_OFFSETS)
	add_child(_wife_label)

	_woohoo_label = _make_label("WOOHOO!!", FONT_SIZE_BANNER, true)
	_woohoo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layout(_woohoo_label, WOOHOO_ANCHORS)
	add_child(_woohoo_label)

	_wife_audio = AudioStreamPlayer.new()
	_wife_audio.bus = BUS_SFX
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

	_nice_air_label = _make_label("nice air!", FONT_SIZE_CALLOUT, true)
	_nice_air_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layout(_nice_air_label, NICE_AIR_ANCHORS, NICE_AIR_OFFSETS)
	add_child(_nice_air_label)

	_trick_label = _make_label("", FONT_SIZE_CALLOUT, true)
	_trick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_layout(_trick_label, TRICK_ANCHORS, TRICK_OFFSETS)
	_trick_label.add_theme_color_override("font_color", COLOR_ORANGE)
	_trick_label.add_theme_font_override("font", _make_system_font(TRICK_FONT_NAMES, true))
	add_child(_trick_label)

	_fun_had_label = _make_label("", FONT_SIZE_FUN_HAD, true)
	_fun_had_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_layout(_fun_had_label, FUN_HAD_ANCHORS, FUN_HAD_OFFSETS)
	_fun_had_label.add_theme_color_override("font_color", COLOR_ORANGE)
	_fun_had_label.add_theme_font_override("font", _make_system_font(MONO_FONT_NAMES))
	add_child(_fun_had_label)

	_tutorial_label = _make_label("", FONT_SIZE_TUTORIAL, true)
	_tutorial_label.add_theme_color_override("font_color", COLOR_ORANGE)
	_tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_layout(_tutorial_label, TUTORIAL_ANCHORS)
	add_child(_tutorial_label)

	_afternoon_label = _make_label("looks like the grommets are off from school", FONT_SIZE_AFTERNOON, true)
	_afternoon_label.add_theme_color_override("font_color", COLOR_AFTERNOON)
	_afternoon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layout(_afternoon_label, AFTERNOON_ANCHORS)
	add_child(_afternoon_label)

	_close_call_label = _make_label("", FONT_SIZE_CLOSE_CALL, true)
	_close_call_label.add_theme_color_override("font_color", COLOR_GOLD)
	_close_call_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_layout(_close_call_label, CLOSE_CALL_ANCHORS, CLOSE_CALL_OFFSETS)
	add_child(_close_call_label)

	_player = get_tree().get_first_node_in_group("player")
	var clean_layer := CanvasLayer.new()
	clean_layer.layer = ABOVE_POSTERIZE_LAYER
	add_child(clean_layer)
	clean_layer.add_child(Mannequin.new())  # finds the player via the "player" group
	_customize_screen.reparent(clean_layer)  # lodge swatches/preview must show true colours
	if _player:
		_player.stance_changed.connect(_on_stance_changed)
		_player.wipeout_danger.connect(_on_wipeout_danger)
		_player.nice_air.connect(_on_nice_air)
		_player.trick_named.connect(_on_trick_named)
	_death_overlay.color = SCREEN_OVERLAY_COLOR
	_build_controls_screen()
	_build_customize_screen()
	_load_settings()
	_build_settings_screen()
	_build_title()
	for screen in [menu_screen, _game_mode_screen, _controls_screen, _settings_screen, _customize_screen, death_screen, _pause_screen]:
		_stickerize_buttons(screen)
	AppearanceManager.unlock_changed.connect(_on_tutorial_board_unlocked)
	call_deferred("_connect_level_generator")
	_on_state_changed(GameManager.state)


# --- Builders ---

func _make_label(text: String, font_size: int, start_hidden: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.visible = not start_hidden
	return label


## Sets anchors then offsets. Both Vector4(left, top, right, bottom).
func _layout(control: Control, anchors: Vector4, offsets: Vector4 = Vector4.ZERO) -> void:
	control.anchor_left = anchors.x
	control.anchor_right = anchors.z
	control.anchor_top = anchors.y
	control.anchor_bottom = anchors.w
	control.offset_left = offsets.x
	control.offset_right = offsets.z
	control.offset_top = offsets.y
	control.offset_bottom = offsets.w


func _make_system_font(names: Array, italic: bool = false) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(names)
	font.font_italic = italic
	return font


## Adds a label to a screen with the given anchors; caller tweaks alignment/color.
func _add_screen_label(parent: Control, text: String, font_size: int, anchors: Vector4) -> Label:
	var label := _make_label(text, font_size)
	_layout(label, anchors)
	parent.add_child(label)
	return label


func _add_overlay(parent: Control) -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = SCREEN_OVERLAY_COLOR
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(overlay)


func _add_back_button(parent: Control, anchors: Vector4, on_pressed: Callable) -> void:
	var back_btn := Button.new()
	back_btn.text = "< Back"
	_layout(back_btn, anchors)
	back_btn.pressed.connect(on_pressed)
	parent.add_child(back_btn)


## Shifts a label's offsets by a sine wobble around its base offsets.
func _wobble(label: Label, base_offsets: Vector4, time: float, freq: Vector2, amp: Vector2) -> void:
	var wx := sin(time * freq.x) * amp.x
	var wy := sin(time * freq.y) * amp.y
	label.offset_left = base_offsets.x + wx
	label.offset_top = base_offsets.y + wy
	label.offset_right = base_offsets.z + wx
	label.offset_bottom = base_offsets.w + wy


func _make_sign_font() -> SystemFont:
	var font := _make_system_font(SIGN_FONT_NAMES)
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
	_level_label = _make_label("", FONT_SIZE_LEVEL)
	_level_label.add_theme_font_override("font", font)
	_level_label.add_theme_color_override("font_color", COLOR_INK)
	row.add_child(_level_label)

	_level_number_label = _make_label("", FONT_SIZE_LEVEL_NUMBER)
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


func _build_title() -> void:
	_title = RichTextLabel.new()
	_layout(_title, TITLE_ANCHORS)
	_title.bbcode_enabled = true
	_title.fit_content = true
	_title.scroll_active = false
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.text = "[center][wave amp=%d freq=%.1f]JERRY360[/wave][/center]" % [TITLE_WAVE_AMP, TITLE_WAVE_FREQ]
	var font := FontVariation.new()
	font.spacing_glyph = TITLE_GLYPH_SPACING
	_title.add_theme_font_override("normal_font", font)
	_title.add_theme_font_size_override("normal_font_size", FONT_SIZE_TITLE)
	_title.add_theme_color_override("default_color", COLOR_GOLD)
	_title.add_theme_color_override("font_outline_color", COLOR_TITLE_OUTLINE)
	_title.add_theme_constant_override("outline_size", TITLE_OUTLINE_SIZE)
	_title.add_theme_color_override("font_shadow_color", COLOR_TITLE_SHADOW)
	_title.add_theme_constant_override("shadow_offset_x", TITLE_SHADOW_OFFSET)
	_title.add_theme_constant_override("shadow_offset_y", TITLE_SHADOW_OFFSET)
	_title.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # project default is nearest; it shreds rotated glyphs
	_title.gui_input.connect(_on_title_gui_input)
	menu_screen.add_child(_title)

	_splash_label = _add_splash("", SPLASH_OFFSETS, SPLASH_ROTATION)
	_splash_left = _add_splash(SPLASH_LEFT_TEXT, SPLASH_LEFT_OFFSETS, -SPLASH_ROTATION)


func _add_splash(text: String, offsets: Vector4, angle: float) -> Label:
	var splash := _make_label(text, FONT_SIZE_SPLASH)
	_layout(splash, SPLASH_ANCHORS, offsets)
	splash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	splash.rotation = angle
	splash.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	splash.mouse_filter = Control.MOUSE_FILTER_STOP
	splash.add_theme_color_override("font_color", COLOR_SPLASH)
	splash.add_theme_color_override("font_outline_color", COLOR_INK)
	splash.add_theme_constant_override("outline_size", STICKER_BORDER)
	splash.gui_input.connect(_on_splash_gui_input.bind(splash))
	menu_screen.add_child(splash)
	return splash


func _on_splash_gui_input(event: InputEvent, splash: Label) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw := splash.create_tween()
		tw.tween_property(splash, "modulate:a", 0.0, SPLASH_FADE_TIME)
		tw.tween_callback(splash.hide)


## Back on the menu: both splashes return, right one with a fresh tagline.
func _reset_splashes() -> void:
	_splash_label.text = MENU_TAGLINES.pick_random()
	for splash: Label in [_splash_label, _splash_left]:
		splash.show()
		splash.modulate.a = 1.0
		splash.mouse_filter = Control.MOUSE_FILTER_STOP


## Does the 360 (click only). Pivot is set here because the title's size is only known after layout.
func _spin_title() -> void:
	if _title_tween and _title_tween.is_running():
		return
	_title.pivot_offset = _title.size * 0.5
	_title_tween = create_tween()
	_title_tween.tween_property(_title, "rotation", TAU, TITLE_SPIN_TIME).from(0.0) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)


func _on_title_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_spin_title()


## Every Button directly under a screen becomes a slightly crooked see-through sticker.
func _stickerize_buttons(screen: Control) -> void:
	for child in screen.get_children():
		if child is Button:
			_stickerize(child)


func _stickerize(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_STICKER_FILL
	normal.border_color = COLOR_STICKER_EDGE
	normal.set_border_width_all(STICKER_BORDER)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = COLOR_STICKER_FILL_HOVER
	hover.border_color = COLOR_GOLD
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = COLOR_GOLD
	pressed.border_color = COLOR_GOLD
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("hover_pressed", pressed)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", COLOR_STICKER_TEXT)
	btn.add_theme_color_override("font_focus_color", COLOR_STICKER_TEXT)
	btn.add_theme_color_override("font_hover_color", COLOR_GOLD)
	btn.add_theme_color_override("font_pressed_color", COLOR_INK)
	btn.add_theme_color_override("font_hover_pressed_color", COLOR_INK)
	btn.add_theme_font_size_override("font_size", FONT_SIZE_STICKER)


func _build_settings_screen() -> void:
	_add_overlay(_settings_screen)

	var title := _add_screen_label(_settings_screen, "KNOBS", FONT_SIZE_CONTROLS_TITLE, CONTROLS_TITLE_ANCHORS)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_GOLD)

	var list := VBoxContainer.new()
	_layout(list, SETTINGS_LIST_ANCHORS)
	list.add_theme_constant_override("separation", SETTINGS_LIST_SEPARATION)
	_settings_screen.add_child(list)
	_add_volume_row(list, "tunes", BUS_MUSIC, COLOR_GOLD)
	_add_volume_row(list, "crunchy noises", BUS_SFX, COLOR_ORANGE)

	var big := CheckButton.new()
	big.text = "big screen mode"
	big.add_theme_font_size_override("font_size", FONT_SIZE_SETTINGS_ROW)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		big.add_theme_color_override(state, COLOR_GOLD)
	big.button_pressed = _settings[KEY_FULLSCREEN]
	big.toggled.connect(_set_fullscreen)
	list.add_child(big)

	_add_back_button(_settings_screen, CONTROLS_BACK_ANCHORS, _on_settings_back_pressed)


func _add_volume_row(list: VBoxContainer, label_text: String, bus: StringName, fill: Color) -> void:
	var row := HBoxContainer.new()
	var label := _make_label(label_text, FONT_SIZE_SETTINGS_ROW)
	label.custom_minimum_size.x = SETTINGS_LABEL_WIDTH
	label.add_theme_color_override("font_color", COLOR_GOLD)
	row.add_child(label)
	var slider := HSlider.new()
	slider.max_value = 1.0
	slider.step = VOLUME_STEP
	slider.value = _settings[bus]
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Fat inked groove, filled with sticker color up to the grabber
	var groove := StyleBoxFlat.new()
	groove.bg_color = COLOR_INK
	groove.content_margin_top = SLIDER_THICKNESS * 0.5
	groove.content_margin_bottom = SLIDER_THICKNESS * 0.5
	var filled := StyleBoxFlat.new()
	filled.bg_color = fill
	filled.set_border_width_all(STICKER_BORDER)
	filled.border_color = COLOR_INK
	slider.add_theme_stylebox_override("slider", groove)
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	slider.value_changed.connect(_set_bus_volume.bind(bus))
	row.add_child(slider)
	list.add_child(row)


func _load_settings() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)  # missing file -> defaults in _settings
	for key in _settings:
		_settings[key] = config.get_value(SETTINGS_SECTION, key, _settings[key])
	_set_bus_volume(_settings[BUS_MUSIC], BUS_MUSIC)
	_set_bus_volume(_settings[BUS_SFX], BUS_SFX)
	_set_fullscreen(_settings[KEY_FULLSCREEN])


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)  # keep scores + lodge picks that share the file
	for key in _settings:
		config.set_value(SETTINGS_SECTION, key, _settings[key])
	config.save(SAVE_PATH)


func _set_bus_volume(linear: float, bus: StringName) -> void:
	_settings[bus] = linear
	var idx := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(idx, linear_to_db(linear))
	AudioServer.set_bus_mute(idx, linear <= 0.0)


func _set_fullscreen(on: bool) -> void:
	_settings[KEY_FULLSCREEN] = on
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


func _build_controls_screen() -> void:
	_add_overlay(_controls_screen)

	var title := _add_screen_label(_controls_screen, "HOW TO PLAY", FONT_SIZE_CONTROLS_TITLE, CONTROLS_TITLE_ANCHORS)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.add_theme_color_override("font_color", COLOR_GOLD)

	var list := VBoxContainer.new()
	_layout(list, CONTROLS_LIST_ANCHORS)
	list.add_theme_constant_override("separation", CONTROLS_LIST_SEPARATION)
	_controls_screen.add_child(list)

	for entry in CONTROLS_DATA:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var key_label := _make_label(entry["key"], FONT_SIZE_CONTROLS_ROW)
		key_label.custom_minimum_size.x = CONTROLS_KEY_COLUMN_WIDTH
		key_label.add_theme_color_override("font_color", COLOR_GOLD)
		row.add_child(key_label)

		var desc_label := _make_label(entry["desc"], FONT_SIZE_CONTROLS_ROW)
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc_label)

		list.add_child(row)

	_add_back_button(_controls_screen, CONTROLS_BACK_ANCHORS, _on_controls_back_pressed)


func _connect_level_generator() -> void:
	var level_gen := get_tree().get_first_node_in_group("level_generator")
	if level_gen:
		level_gen.level_changed.connect(_on_level_changed)
		level_gen.tutorial_stage_changed.connect(_on_tutorial_stage_changed)
		level_gen.tutorial_complete.connect(_on_tutorial_complete)


func _process(delta: float) -> void:
	if menu_screen.visible:
		_splash_time += delta
		var pulse := Vector2.ONE * (1.0 + sin(_splash_time * SPLASH_PULSE_FREQ) * SPLASH_PULSE_AMP)
		for splash: Label in [_splash_label, _splash_left]:
			splash.pivot_offset = splash.size * 0.5
			splash.scale = pulse

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
			var hud_size := Vector2(get_viewport().size)
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
	menu_screen.visible = new_state == GameManager.State.MENU
	_game_mode_screen.visible = false
	_customize_screen.visible = false
	_controls_screen.visible = false
	_settings_screen.visible = false
	_pause_screen.visible = new_state == GameManager.State.PAUSED
	death_screen.visible = new_state == GameManager.State.DEAD
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

	if new_state == GameManager.State.MENU:
		_reset_splashes()

	if new_state == GameManager.State.DEAD:
		var dist := ScoreManager.distance
		var best := ScoreManager.high_score
		var deaths := ScoreManager.deaths
		var tricks := ScoreManager.tricks_landed
		var top_combo := ScoreManager.max_combo
		var trick_str := "%d trick%s" % [tricks, "s" if tricks != 1 else ""]
		var combo_str := ("best combo x%d" % top_combo) if top_combo > 1 else "no combos"
		var first_line: String
		if GameManager.wife_killed_jerry:
			first_line = "not really feeling it today.\nsoup sounds good actually..."
		elif _is_goofy:
			first_line = "Got a little too goofy."
		else:
			first_line = "He fell."
		death_label.text = "%s\n%.0f meters — not bad for a Tuesday.\n%s  |  %s\n\nBest: %.0f m  |  Falls: %d" % [first_line, dist, trick_str, combo_str, best, deaths]


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


func _build_customize_screen() -> void:
	_add_overlay(_customize_screen)

	var title := _add_screen_label(_customize_screen, "CUSTOMIZE JERRY", FONT_SIZE_CUSTOMIZE_TITLE, CUSTOMIZE_TITLE_ANCHORS)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_color_override("font_color", COLOR_GOLD)

	var row := _add_option_row("his jacket:", 0)
	for i in AppearanceManager.JACKET_COLORS.size():
		_add_option_swatch(row, &"jacket", i, AppearanceManager.JACKET_COLORS[i])
	row = _add_option_row("lid:", 1)
	for i in AppearanceManager.HELMET_COLORS.size():
		_add_option_swatch(row, &"helmet", i, AppearanceManager.HELMET_COLORS[i])
	row = _add_option_row("legs:", 2)
	for i in AppearanceManager.PANTS_COLORS.size():
		_add_option_swatch(row, &"pants", i, AppearanceManager.PANTS_COLORS[i])
	row = _add_option_row("eyes:", 3)
	for i in AppearanceManager.GOGGLE_HUE_SHIFTS.size():
		_add_option_swatch(row, &"goggles", i, SWATCH_TEXTURE_BG, AppearanceManager.goggle_texture(i))
	_board_hbox = _add_option_row("board:", 4)
	var board_count: int = AppearanceManager.grommet_board_count()
	if AppearanceManager.tutorial_board_unlocked:
		board_count = AppearanceManager.BOARD_TEXTURE_PATHS.size()
	for i in board_count:
		_add_option_swatch(_board_hbox, &"board", i, SWATCH_TEXTURE_BG, AppearanceManager.board_texture(i))

	# Preview panel
	var preview_panel := Panel.new()
	_layout(preview_panel, PREVIEW_PANEL_ANCHORS)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_PREVIEW_PANEL
	panel_style.set_corner_radius_all(PREVIEW_PANEL_CORNER_RADIUS)
	preview_panel.add_theme_stylebox_override("panel", panel_style)
	_customize_screen.add_child(preview_panel)

	var preview_label := _add_screen_label(preview_panel, "preview", FONT_SIZE_PREVIEW, PREVIEW_LABEL_ANCHORS)
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.add_theme_color_override("font_color", COLOR_PREVIEW_LABEL)

	# Body stacked bottom-up at the same proportions as the 3D rider
	var px_per_m := PREVIEW_BODY_WIDTH / AppearanceManager.BODY_SIZE.z
	var half_w := PREVIEW_BODY_WIDTH * 0.5
	var pants_top := PREVIEW_FEET_Y - AppearanceManager.PANTS_HEIGHT * px_per_m
	var jacket_top := pants_top - AppearanceManager.JACKET_HEIGHT * px_per_m
	var lid_size := AppearanceManager.HELMET_SIZE.y * px_per_m * PREVIEW_LID_SCALE
	var lid_top := jacket_top - lid_size
	_preview_pants = _add_preview_rect(preview_panel, Vector4(-half_w, pants_top, half_w, PREVIEW_FEET_Y))
	_preview_jacket = _add_preview_texture(preview_panel, Vector4(-half_w, jacket_top, half_w, pants_top), TextureRect.STRETCH_SCALE)
	# Lid is a cube narrower than the torso, centred over the jacket
	var lid_half_w := AppearanceManager.HELMET_SIZE.z * px_per_m * PREVIEW_LID_SCALE * 0.5
	_preview_helmet = _add_preview_rect(preview_panel, Vector4(-lid_half_w, lid_top, lid_half_w, jacket_top))

	# Goggles centred on the lid, sized exactly like the 3D rig's goggle quad
	var gsize := AppearanceManager.goggle_size(lid_half_w * 2.0, lid_size)
	var g_center_y := (lid_top + jacket_top) * 0.5
	_preview_goggles = _add_preview_texture(preview_panel,
		Vector4(-gsize.x * 0.5, g_center_y - gsize.y * 0.5, gsize.x * 0.5, g_center_y + gsize.y * 0.5),
		TextureRect.STRETCH_SCALE)

	_preview_board = _add_preview_texture(preview_panel, PREVIEW_BOARD_OFFSETS, TextureRect.STRETCH_SCALE)
	var b := PREVIEW_BOARD_OFFSETS
	_preview_board.pivot_offset = Vector2(b.z - b.x, b.w - b.y) * 0.5
	_preview_board.rotation = PREVIEW_BOARD_ROTATION
	_refresh_preview()

	_add_back_button(_customize_screen, CUSTOMIZE_BACK_ANCHORS, _on_customize_back_pressed)


## Adds a "label: [swatches]" row; index stacks rows downward by CUSTOMIZE_ROW_STEP.
func _add_option_row(label_text: String, index: int) -> HBoxContainer:
	var a := CUSTOMIZE_FIRST_ROW_ANCHORS
	var dy := CUSTOMIZE_ROW_STEP * index
	var row := HBoxContainer.new()
	_layout(row, Vector4(a.x, a.y + dy, a.z, a.w + dy))
	row.add_theme_constant_override("separation", SWATCH_SEPARATION)
	_customize_screen.add_child(row)
	var label := _make_label(label_text, FONT_SIZE_CUSTOMIZE_SECTION)
	label.custom_minimum_size.x = CUSTOMIZE_ROW_LABEL_WIDTH
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return row


func _add_preview_rect(parent: Control, offsets: Vector4) -> ColorRect:
	var rect := ColorRect.new()
	_layout(rect, CENTER_ANCHORS, offsets)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _make_nearest_texture_rect(stretch: TextureRect.StretchMode) -> TextureRect:
	var rect := TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = stretch
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _add_preview_texture(parent: Control, offsets: Vector4, stretch: TextureRect.StretchMode) -> TextureRect:
	var rect := _make_nearest_texture_rect(stretch)
	_layout(rect, CENTER_ANCHORS, offsets)
	parent.add_child(rect)
	return rect


func _refresh_preview() -> void:
	_preview_helmet.color = AppearanceManager.HELMET_COLORS[AppearanceManager.helmet]
	_preview_jacket.texture = AppearanceManager.jacket_texture(AppearanceManager.jacket)
	_preview_goggles.texture = AppearanceManager.goggle_texture(AppearanceManager.goggles)
	_preview_pants.color = AppearanceManager.PANTS_COLORS[AppearanceManager.pants]
	_preview_board.texture = AppearanceManager.board_texture(AppearanceManager.board)


## Builds a swatch for one appearance option, records its "normal" style (for selection borders) and adds it to the row.
func _add_option_swatch(row: HBoxContainer, part: StringName, idx: int, color: Color, texture: Texture2D = null) -> void:
	var btn := _make_swatch_button(color, idx == AppearanceManager.get(part), texture)
	if not _swatch_styles.has(part):
		_swatch_styles[part] = []
	_swatch_styles[part].append(btn.get_theme_stylebox("normal"))
	btn.pressed.connect(_on_option_selected.bind(part, idx))
	row.add_child(btn)


func _make_swatch_button(color: Color, selected: bool, texture: Texture2D = null) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = SWATCH_SIZE
	btn.text = ""

	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(SWATCH_CORNER_RADIUS)
	normal.set_border_width_all(SWATCH_SELECTED_BORDER if selected else 0)
	normal.border_color = Color.WHITE

	# Focus is drawn on top of "normal"; an opaque focus box hid the clicked swatch's selection border
	var focus := StyleBoxEmpty.new()

	btn.add_theme_stylebox_override("normal", normal)
	# Hover reuses "normal": a lightened hover box lingered after a click (mouse still over it) and,
	# once posterized, read as a different colour. A swatch always shows its true colour + selection border.
	btn.add_theme_stylebox_override("hover", normal)
	btn.add_theme_stylebox_override("hover_pressed", normal)
	btn.add_theme_stylebox_override("pressed", normal)
	btn.add_theme_stylebox_override("focus", focus)

	if texture != null:
		# Thumbnail inset by the selection border so the white outline stays visible
		var inset := float(SWATCH_SELECTED_BORDER)
		var thumb := _make_nearest_texture_rect(TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		thumb.texture = texture
		_layout(thumb, Vector4(0.0, 0.0, 1.0, 1.0), Vector4(inset, inset, -inset, -inset))
		btn.add_child(thumb)
	return btn


func _on_option_selected(part: StringName, idx: int) -> void:
	AppearanceManager.select(part, idx)
	var styles: Array = _swatch_styles[part]
	for i in styles.size():
		(styles[i] as StyleBoxFlat).set_border_width_all(SWATCH_SELECTED_BORDER if i == idx else 0)
	_refresh_preview()


func _on_customize_pressed() -> void:
	menu_screen.visible = false
	_customize_screen.visible = true


func _on_customize_back_pressed() -> void:
	_customize_screen.visible = false
	menu_screen.visible = true


func _on_how_to_play_pressed() -> void:
	menu_screen.visible = false
	_controls_screen.visible = true


func _on_controls_back_pressed() -> void:
	_controls_screen.visible = false
	menu_screen.visible = true


func _on_settings_pressed() -> void:
	menu_screen.visible = false
	_settings_screen.visible = true


func _on_settings_back_pressed() -> void:
	_save_settings()
	_settings_screen.visible = false
	menu_screen.visible = true


func _on_punch_pass_pressed() -> void:
	menu_screen.visible = false
	_game_mode_screen.visible = true


func _on_game_mode_back_pressed() -> void:
	_game_mode_screen.visible = false
	menu_screen.visible = true


func _on_start_pressed() -> void:
	GameManager.start_game()


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


func _on_try_again_pressed() -> void:
	GameManager.start_game(GameManager.is_tutorial)


func _on_resume_pressed() -> void:
	GameManager.resume_game()


func _on_menu_pressed() -> void:
	GameManager.return_to_menu()


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


func _on_learn_pressed() -> void:
	GameManager.start_game(true)


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


func _on_tutorial_board_unlocked() -> void:
	if not is_instance_valid(_board_hbox):
		return
	var i := AppearanceManager.BOARD_TEXTURE_PATHS.size() - 1
	_add_option_swatch(_board_hbox, &"board", i, SWATCH_TEXTURE_BG, AppearanceManager.board_texture(i))
