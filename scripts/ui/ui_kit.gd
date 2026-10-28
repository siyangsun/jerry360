extends RefCounted
## Shared palette and builder helpers for the HUD and its screens. Static only: preload it, never instance it.
## Button/toggle/title styling lives in res://assets/ui/ui_theme.tres, not here.

const COLOR_GOLD := Color(1.0, 0.82, 0.1, 1.0)
const COLOR_ORANGE := Color(1.0, 0.45, 0.05, 1.0)
const COLOR_INK := Color(0.08, 0.05, 0.1, 1.0)
const SCREEN_OVERLAY_COLOR := Color(0.15, 0.15, 0.15, 0.3)

const CENTER_ANCHORS := Vector4(0.5, 0.5, 0.5, 0.5)
const BACK_BUTTON_ANCHORS := Vector4(0.38, 0.88, 0.62, 0.96)
const SCREEN_TITLE_ANCHORS := Vector4(0.0, 0.06, 1.0, 0.18)
const FONT_SIZE_SCREEN_TITLE := 48


static func make_label(text: String, font_size: int, start_hidden: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.visible = not start_hidden
	return label


## Sets anchors then offsets. Both Vector4(left, top, right, bottom).
static func layout(control: Control, anchors: Vector4, offsets: Vector4 = Vector4.ZERO) -> void:
	control.anchor_left = anchors.x
	control.anchor_right = anchors.z
	control.anchor_top = anchors.y
	control.anchor_bottom = anchors.w
	control.offset_left = offsets.x
	control.offset_right = offsets.z
	control.offset_top = offsets.y
	control.offset_bottom = offsets.w


static func make_system_font(names: Array, italic: bool = false) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(names)
	font.font_italic = italic
	return font


## Adds a label to a screen with the given anchors; caller tweaks alignment/color.
static func add_screen_label(parent: Control, text: String, font_size: int, anchors: Vector4) -> Label:
	var label := make_label(text, font_size)
	layout(label, anchors)
	parent.add_child(label)
	return label


## Big centered gold heading at the top of a full-screen menu.
static func add_screen_title(parent: Control, text: String) -> Label:
	var title := add_screen_label(parent, text, FONT_SIZE_SCREEN_TITLE, SCREEN_TITLE_ANCHORS)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_GOLD)
	return title


static func add_overlay(parent: Control) -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = SCREEN_OVERLAY_COLOR
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(overlay)


static func add_back_button(parent: Control, on_pressed: Callable, anchors: Vector4 = BACK_BUTTON_ANCHORS) -> Button:
	var back_btn := Button.new()
	back_btn.text = "< Back"
	layout(back_btn, anchors)
	back_btn.pressed.connect(on_pressed)
	parent.add_child(back_btn)
	return back_btn
