extends Control
## "CUSTOMIZE JERRY": swatch rows for each gear part plus a flat preview of the rider.
## Lives on a CanvasLayer above the posterize pass so swatches show true colours.

signal back_pressed

const UIKit = preload("res://scripts/ui/ui_kit.gd")

const COLOR_PREVIEW_LABEL := Color(1.0, 1.0, 1.0, 0.4)
const COLOR_PREVIEW_PANEL := Color(0.06, 0.06, 0.10)

const FONT_SIZE_TITLE := 36
const FONT_SIZE_SECTION := 18
const FONT_SIZE_PREVIEW := 13

const TITLE_ANCHORS := Vector4(0.04, 0.04, 0.56, 0.16)
const ROWS_ANCHORS := Vector4(0.04, 0.18, 0.60, 0.79)   # five option rows, label + swatches each
const ROWS_SEPARATION := 29
const ROW_LABEL_WIDTH := 110.0
const BACK_ANCHORS := Vector4(0.04, 0.88, 0.22, 0.96)
const PREVIEW_PANEL_ANCHORS := Vector4(0.62, 0.10, 0.96, 0.86)
const PREVIEW_LABEL_ANCHORS := Vector4(0.0, 0.04, 1.0, 0.14)
const PREVIEW_PANEL_CORNER_RADIUS := 4
const PREVIEW_BODY_WIDTH := 60.0   # px for the torso's 0.6 m jacket-front face; sets the preview's px-per-metre
const PREVIEW_FEET_Y := 35.0       # px offset of the feet from the panel centre
const PREVIEW_LID_SCALE := 1.43    # preview-only: enlarges the 0.28 m lid (28 px -> ~40 px) so it reads in the lodge
const PREVIEW_BOARD_OFFSETS := Vector4(-13.0, -4.0, 13.0, 100.0)   # upright board sprite, then rotated flat
const PREVIEW_BOARD_ROTATION := -PI * 0.5  # nose left, so sprite text reads upright

# Swatches
const SWATCH_SIZE := Vector2(52.0, 52.0)
const SWATCH_SEPARATION := 10
const SWATCH_CORNER_RADIUS := 3
const SWATCH_SELECTED_BORDER := 3
const SWATCH_TEXTURE_BG := Color(0.06, 0.06, 0.10)  # behind goggle/board thumbnails

var _rows: VBoxContainer
var _swatch_styles: Dictionary = {}  # appearance part (StringName) -> Array of StyleBoxFlat
var _board_hbox: HBoxContainer
var _preview_helmet: ColorRect
var _preview_jacket: TextureRect
var _preview_goggles: TextureRect
var _preview_pants: ColorRect
var _preview_board: TextureRect


func _ready() -> void:
	UIKit.add_overlay(self)

	var title := UIKit.add_screen_label(self, "CUSTOMIZE JERRY", FONT_SIZE_TITLE, TITLE_ANCHORS)
	title.add_theme_color_override("font_color", UIKit.COLOR_GOLD)

	_rows = VBoxContainer.new()
	UIKit.layout(_rows, ROWS_ANCHORS)
	_rows.add_theme_constant_override("separation", ROWS_SEPARATION)
	add_child(_rows)

	var row := _add_option_row("his jacket:")
	for i in AppearanceManager.JACKET_COLORS.size():
		_add_option_swatch(row, &"jacket", i, AppearanceManager.JACKET_COLORS[i])
	row = _add_option_row("lid:")
	for i in AppearanceManager.HELMET_COLORS.size():
		_add_option_swatch(row, &"helmet", i, AppearanceManager.HELMET_COLORS[i])
	row = _add_option_row("legs:")
	for i in AppearanceManager.PANTS_COLORS.size():
		_add_option_swatch(row, &"pants", i, AppearanceManager.PANTS_COLORS[i])
	row = _add_option_row("eyes:")
	for i in AppearanceManager.GOGGLE_HUE_SHIFTS.size():
		_add_option_swatch(row, &"goggles", i, SWATCH_TEXTURE_BG, AppearanceManager.goggle_texture(i))
	_board_hbox = _add_option_row("board:")
	var board_count: int = AppearanceManager.grommet_board_count()
	if AppearanceManager.tutorial_board_unlocked:
		board_count = AppearanceManager.BOARD_TEXTURE_PATHS.size()
	for i in board_count:
		_add_option_swatch(_board_hbox, &"board", i, SWATCH_TEXTURE_BG, AppearanceManager.board_texture(i))

	_build_preview()
	UIKit.add_back_button(self, back_pressed.emit, BACK_ANCHORS)
	AppearanceManager.unlock_changed.connect(_on_tutorial_board_unlocked)


func _build_preview() -> void:
	var preview_panel := Panel.new()
	UIKit.layout(preview_panel, PREVIEW_PANEL_ANCHORS)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_PREVIEW_PANEL
	panel_style.set_corner_radius_all(PREVIEW_PANEL_CORNER_RADIUS)
	preview_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(preview_panel)

	var preview_label := UIKit.add_screen_label(preview_panel, "preview", FONT_SIZE_PREVIEW, PREVIEW_LABEL_ANCHORS)
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


## Adds a "label: [swatches]" row to the stacked row list.
func _add_option_row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", SWATCH_SEPARATION)
	_rows.add_child(row)
	var label := UIKit.make_label(label_text, FONT_SIZE_SECTION)
	label.custom_minimum_size.x = ROW_LABEL_WIDTH
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return row


func _add_preview_rect(parent: Control, offsets: Vector4) -> ColorRect:
	var rect := ColorRect.new()
	UIKit.layout(rect, UIKit.CENTER_ANCHORS, offsets)
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
	UIKit.layout(rect, UIKit.CENTER_ANCHORS, offsets)
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
		UIKit.layout(thumb, Vector4(0.0, 0.0, 1.0, 1.0), Vector4(inset, inset, -inset, -inset))
		btn.add_child(thumb)
	return btn


func _on_option_selected(part: StringName, idx: int) -> void:
	AppearanceManager.select(part, idx)
	var styles: Array = _swatch_styles[part]
	for i in styles.size():
		(styles[i] as StyleBoxFlat).set_border_width_all(SWATCH_SELECTED_BORDER if i == idx else 0)
	_refresh_preview()


func _on_tutorial_board_unlocked() -> void:
	var i := AppearanceManager.BOARD_TEXTURE_PATHS.size() - 1
	_add_option_swatch(_board_hbox, &"board", i, SWATCH_TEXTURE_BG, AppearanceManager.board_texture(i))
