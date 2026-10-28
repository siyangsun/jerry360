extends Control
## Title screen: backstory, wobbling JERRY360 logo (click to spin), two click-to-dismiss splashes, main buttons.

signal play_pressed
signal how_to_play_pressed
signal lodge_pressed
signal settings_pressed

const UIKit = preload("res://scripts/ui/ui_kit.gd")

const COLOR_TITLE_OUTLINE := Color(1.0, 0.97, 0.55, 1.0)
const COLOR_TITLE_SHADOW := Color(0.35, 0.2, 0.0, 1.0)
const COLOR_SPLASH := Color(1.0, 1.0, 0.2, 1.0)

# One picked at random every time the menu comes up
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

const FONT_SIZE_TITLE := 96
const FONT_SIZE_SPLASH := 22

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
const SPLASH_LEFT_OFFSETS := Vector4(-610.0, 300.0, -250.0, 335.0)  # beside the left end of the title, clear of the story
const SPLASH_ROTATION := -PI / 14.0
const SPLASH_LEFT_TEXT := "it's really fun apparently!"
const SPLASH_OUTLINE_SIZE := 2
const SPLASH_FADE_TIME := 0.4
const SPLASH_PULSE_FREQ := 9.0   # rad/s
const SPLASH_PULSE_AMP := 0.08   # fraction of base scale

var _title: RichTextLabel
var _title_tween: Tween
var _splash_right: Label
var _splash_left: Label
var _splash_time: float = 0.0


func _ready() -> void:
	$Buttons/PunchPassButton.pressed.connect(play_pressed.emit)
	$Buttons/HowToPlayButton.pressed.connect(how_to_play_pressed.emit)
	$Buttons/LodgeButton.pressed.connect(lodge_pressed.emit)
	$Buttons/SettingsButton.pressed.connect(settings_pressed.emit)
	_build_title()
	reset_splashes()


func _process(delta: float) -> void:
	if not visible:
		return
	_splash_time += delta
	var pulse := Vector2.ONE * (1.0 + sin(_splash_time * SPLASH_PULSE_FREQ) * SPLASH_PULSE_AMP)
	for splash: Label in [_splash_right, _splash_left]:
		splash.pivot_offset = splash.size * 0.5
		splash.scale = pulse


## Back on the menu: both splashes return, right one with a fresh tagline.
func reset_splashes() -> void:
	_splash_right.text = MENU_TAGLINES.pick_random()
	for splash: Label in [_splash_right, _splash_left]:
		splash.show()
		splash.modulate.a = 1.0
		splash.mouse_filter = Control.MOUSE_FILTER_STOP


func _build_title() -> void:
	_title = RichTextLabel.new()
	UIKit.layout(_title, TITLE_ANCHORS)
	_title.bbcode_enabled = true
	_title.fit_content = true
	_title.scroll_active = false
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.text = "[center][wave amp=%d freq=%.1f]JERRY360[/wave][/center]" % [TITLE_WAVE_AMP, TITLE_WAVE_FREQ]
	var font := FontVariation.new()
	font.spacing_glyph = TITLE_GLYPH_SPACING
	_title.add_theme_font_override("normal_font", font)
	_title.add_theme_font_size_override("normal_font_size", FONT_SIZE_TITLE)
	_title.add_theme_color_override("default_color", UIKit.COLOR_GOLD)
	_title.add_theme_color_override("font_outline_color", COLOR_TITLE_OUTLINE)
	_title.add_theme_constant_override("outline_size", TITLE_OUTLINE_SIZE)
	_title.add_theme_color_override("font_shadow_color", COLOR_TITLE_SHADOW)
	_title.add_theme_constant_override("shadow_offset_x", TITLE_SHADOW_OFFSET)
	_title.add_theme_constant_override("shadow_offset_y", TITLE_SHADOW_OFFSET)
	_title.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # project default is nearest; it shreds rotated glyphs
	_title.gui_input.connect(_on_title_gui_input)
	add_child(_title)

	_splash_right = _add_splash("", SPLASH_OFFSETS, SPLASH_ROTATION)
	_splash_left = _add_splash(SPLASH_LEFT_TEXT, SPLASH_LEFT_OFFSETS, -SPLASH_ROTATION)


func _add_splash(text: String, offsets: Vector4, angle: float) -> Label:
	var splash := UIKit.make_label(text, FONT_SIZE_SPLASH)
	UIKit.layout(splash, SPLASH_ANCHORS, offsets)
	splash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	splash.rotation = angle
	splash.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	splash.add_theme_color_override("font_color", COLOR_SPLASH)
	splash.add_theme_color_override("font_outline_color", UIKit.COLOR_INK)
	splash.add_theme_constant_override("outline_size", SPLASH_OUTLINE_SIZE)
	splash.gui_input.connect(_on_splash_gui_input.bind(splash))
	add_child(splash)
	return splash


func _on_splash_gui_input(event: InputEvent, splash: Label) -> void:
	if _is_left_click(event):
		splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw := splash.create_tween()
		tw.tween_property(splash, "modulate:a", 0.0, SPLASH_FADE_TIME)
		tw.tween_callback(splash.hide)


## Does the 360. Pivot is set here because the title's size is only known after layout.
func _on_title_gui_input(event: InputEvent) -> void:
	if not _is_left_click(event) or (_title_tween and _title_tween.is_running()):
		return
	_title.pivot_offset = _title.size * 0.5
	_title_tween = create_tween()
	_title_tween.tween_property(_title, "rotation", TAU, TITLE_SPIN_TIME).from(0.0) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)


func _is_left_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
