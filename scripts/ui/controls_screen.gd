extends Control
## "HOW TO PLAY": key / description table built from CONTROLS_DATA.

signal back_pressed

const UIKit = preload("res://scripts/ui/ui_kit.gd")

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

const FONT_SIZE_ROW := 16
const LIST_ANCHORS := Vector4(0.1, 0.20, 0.9, 0.85)
const LIST_SEPARATION := 10
const KEY_COLUMN_WIDTH := 160.0


func _ready() -> void:
	UIKit.add_overlay(self)
	UIKit.add_screen_title(self, "HOW TO PLAY")

	var list := VBoxContainer.new()
	UIKit.layout(list, LIST_ANCHORS)
	list.add_theme_constant_override("separation", LIST_SEPARATION)
	add_child(list)

	for entry in CONTROLS_DATA:
		var row := HBoxContainer.new()
		var key_label := UIKit.make_label(entry["key"], FONT_SIZE_ROW)
		key_label.custom_minimum_size.x = KEY_COLUMN_WIDTH
		key_label.add_theme_color_override("font_color", UIKit.COLOR_GOLD)
		row.add_child(key_label)
		var desc_label := UIKit.make_label(entry["desc"], FONT_SIZE_ROW)
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc_label)
		list.add_child(row)

	UIKit.add_back_button(self, back_pressed.emit)
