extends Control
## "HOW TO PLAY": key / description table built from CONTROLS_DATA, with the HUD mannequin's pose beside moves that have one.

signal back_pressed

const UIKit = preload("res://scripts/ui/ui_kit.gd")
const Mannequin = preload("res://scripts/ui/mannequin.gd")

const CONTROLS_DATA: Array[Dictionary] = [
	{"key": "Left / Right",        "desc": "Steer the board left and right", "pose": "turn-left"},
	{"key": "A / D",               "desc": "Lean — shifts weight sideways and carves", "pose": "turn-right"},
	{"key": "Space",               "desc": "Jump — hold to charge, release to launch higher"},
	{"key": "W  (hold)",           "desc": "Lean forward — accelerate past top speed"},
	{"key": "S  (hold)",           "desc": "Lean back — brake on the ground, or hold before landing to widen your safe landing angle", "pose": "brake"},
	{"key": "Left / Right (air)",  "desc": "Spin — land within 180° of straight to score and boost speed", "pose": "spin-left"},
	{"key": "Up / Down (air)",     "desc": "Front / backflip — land upright to score (worth 3× a spin)"},
	{"key": "Lean + Turn",         "desc": "Always lean and turn the same direction — opposing inputs will cause a wipeout", "pose": "wipeout"},
	{"key": "Scoring",             "desc": "Distance × speed × combo multiplier — clean trick landings grow your combo; sloppy ones cost speed"},
	{"key": "Close calls",         "desc": "Narrowly dodge an obstacle above 30 m/s for bonus fun"},
	{"key": "Esc",                 "desc": "Pause"},
]

const FONT_SIZE_ROW := 16
const LIST_ANCHORS := Vector4(0.08, 0.19, 0.92, 0.86)
const LIST_SEPARATION := 4
const POSE_ICON_SIZE := 52.0          # px square; mannequin sprites are 256 px, mipmapped so they shrink cleanly
const POSE_ICON_GAP := 12
const PLAIN_ROW_HEIGHT := 30.0       # rows without a pose: shorter than an icon row, but not cramped
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
		row.add_theme_constant_override("separation", POSE_ICON_GAP)
		row.add_child(_make_pose_icon(entry.get("pose", "")))
		var key_label := UIKit.make_label(entry["key"], FONT_SIZE_ROW)
		key_label.custom_minimum_size.x = KEY_COLUMN_WIDTH
		key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key_label.add_theme_color_override("font_color", UIKit.COLOR_GOLD)
		row.add_child(key_label)
		var desc_label := UIKit.make_label(entry["desc"], FONT_SIZE_ROW)
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(desc_label)
		list.add_child(row)

	UIKit.add_back_button(self, back_pressed.emit)


## Rows without a pose get a spacer: same width so text columns line up, PLAIN_ROW_HEIGHT tall.
func _make_pose_icon(pose: String) -> Control:
	if pose.is_empty():
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(POSE_ICON_SIZE, PLAIN_ROW_HEIGHT)
		return spacer
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2.ONE * POSE_ICON_SIZE
	icon.texture = load("%s%s.png" % [Mannequin.SPRITE_DIR, pose])
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return icon
