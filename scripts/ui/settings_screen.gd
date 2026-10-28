extends Control
## "KNOBS": music/SFX volume and fullscreen. Loads and applies saved values on startup (the HUD
## instances this screen at boot), saves when leaving via Back.

signal back_pressed

const UIKit = preload("res://scripts/ui/ui_kit.gd")

const SAVE_PATH := "user://scores.cfg"
const SAVE_SECTION := "settings"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
const KEY_FULLSCREEN := "fullscreen"

const FONT_SIZE_ROW := 20
const VOLUME_STEP := 0.05
const LIST_ANCHORS := Vector4(0.25, 0.30, 0.75, 0.70)
const LIST_SEPARATION := 28
const LABEL_WIDTH := 190.0
const SLIDER_THICKNESS := 18.0
const SLIDER_FILL_BORDER := 2

var _settings: Dictionary = {BUS_MUSIC: 1.0, BUS_SFX: 1.0, KEY_FULLSCREEN: false}


func _ready() -> void:
	_load()
	UIKit.add_overlay(self)
	UIKit.add_screen_title(self, "KNOBS")

	var list := VBoxContainer.new()
	UIKit.layout(list, LIST_ANCHORS)
	list.add_theme_constant_override("separation", LIST_SEPARATION)
	add_child(list)
	_add_volume_row(list, "tunes", BUS_MUSIC, UIKit.COLOR_GOLD)
	_add_volume_row(list, "crunchy noises", BUS_SFX, UIKit.COLOR_ORANGE)

	var big := CheckButton.new()
	big.text = "big screen mode"
	big.button_pressed = _settings[KEY_FULLSCREEN]
	big.toggled.connect(_set_fullscreen)
	list.add_child(big)

	UIKit.add_back_button(self, _on_back_pressed)


func _add_volume_row(list: VBoxContainer, label_text: String, bus: StringName, fill: Color) -> void:
	var row := HBoxContainer.new()
	var label := UIKit.make_label(label_text, FONT_SIZE_ROW)
	label.custom_minimum_size.x = LABEL_WIDTH
	label.add_theme_color_override("font_color", UIKit.COLOR_GOLD)
	row.add_child(label)
	var slider := HSlider.new()
	slider.max_value = 1.0
	slider.step = VOLUME_STEP
	slider.value = _settings[bus]
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Fat inked groove, filled with the row's color up to the grabber
	var groove := StyleBoxFlat.new()
	groove.bg_color = UIKit.COLOR_INK
	groove.content_margin_top = SLIDER_THICKNESS * 0.5
	groove.content_margin_bottom = SLIDER_THICKNESS * 0.5
	var filled := StyleBoxFlat.new()
	filled.bg_color = fill
	filled.set_border_width_all(SLIDER_FILL_BORDER)
	filled.border_color = UIKit.COLOR_INK
	slider.add_theme_stylebox_override("slider", groove)
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	slider.value_changed.connect(_set_bus_volume.bind(bus))
	row.add_child(slider)
	list.add_child(row)


func _on_back_pressed() -> void:
	_save()
	back_pressed.emit()


func _load() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)  # missing file -> defaults in _settings
	for key in _settings:
		_settings[key] = config.get_value(SAVE_SECTION, key, _settings[key])
	_set_bus_volume(_settings[BUS_MUSIC], BUS_MUSIC)
	_set_bus_volume(_settings[BUS_SFX], BUS_SFX)
	_set_fullscreen(_settings[KEY_FULLSCREEN])


func _save() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)  # keep scores + lodge picks that share the file
	for key in _settings:
		config.set_value(SAVE_SECTION, key, _settings[key])
	config.save(SAVE_PATH)


func _set_bus_volume(linear: float, bus: StringName) -> void:
	_settings[bus] = linear
	var idx := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(idx, linear_to_db(linear))
	AudioServer.set_bus_mute(idx, linear <= 0.0)


func _set_fullscreen(on: bool) -> void:
	_settings[KEY_FULLSCREEN] = on
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
