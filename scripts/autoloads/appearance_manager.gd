extends Node
## Single source of truth for rider looks: preset lists, the player's picks (persisted),
## and cached textures/materials/meshes shared by Jerry and every grommet.

signal appearance_changed
signal unlock_changed

const SAVE_PATH := "user://scores.cfg"
const SAVE_SECTION := "appearance"

# --- Presets (index 0 = default) ---
const JACKET_COLORS: Array[Color] = [
	Color(1.0, 0.45, 0.05),   # burnt orange (sprite as-is)
	Color(0.12, 0.22, 0.75),  # navy
	Color(0.85, 0.08, 0.12),  # cherry
	Color(0.08, 0.55, 0.18),  # pine
	Color(0.42, 0.12, 0.55),  # bruise
]
const HELMET_COLORS: Array[Color] = [
	Color(0.80, 0.78, 0.73),  # chalk
	Color(0.26, 0.27, 0.29),  # graphite
	Color(0.40, 0.42, 0.32),  # olive
	Color(0.24, 0.30, 0.40),  # slate
]
const PANTS_COLORS: Array[Color] = [
	Color(0.18, 0.19, 0.20),  # coal
	Color(0.55, 0.50, 0.40),  # sand
	Color(0.20, 0.25, 0.34),  # navy
	Color(0.34, 0.36, 0.28),  # moss
]
const GOGGLE_HUE_SHIFTS: Array[float] = [
	0.0,    # ice
	0.50,   # fire
	0.30,   # rose
	-0.25,  # toxic
]
## Last entry is the tutorial unlock; grommets never roll it.
const BOARD_TEXTURE_PATHS: Array[String] = [
	"res://assets/textures/boards/arctic-blast.png",
	"res://assets/textures/boards/rust.png",
	"res://assets/textures/boards/sound.png",
	"res://assets/textures/boards/tourmaline.png",
	"res://assets/textures/boards/sponsored.png",
]
const JACKET_TEXTURE_PATH := "res://assets/textures/player/ski-jacket-front.png"
const GOGGLE_TEXTURE_PATH := "res://assets/textures/player/goggles.png"

# --- Recolor tuning ---
const JACKET_SPRITE_BASE_V := 1.0     # HSV value of the sprite's base orange
const GOGGLE_FRAME_MAX_SAT := 0.2     # pixels at or below this saturation (white frame) are not hue-shifted

# --- Rider geometry (body is split into stacked bands, built upward from the feet) ---
# Visual only: collision capsule and camera still assume the old 1.0 m body.
const PANTS_HEIGHT := 0.4
const JACKET_HEIGHT := 0.4
const HELMET_EDGE := 0.28             # helmet is a cube this size, centred on top of the torso
const HELMET_SIZE := Vector3(HELMET_EDGE, HELMET_EDGE, HELMET_EDGE)
const BODY_SIZE := Vector3(0.3, PANTS_HEIGHT + JACKET_HEIGHT + HELMET_EDGE, 0.6)  # torso X depth, total height, torso Z width
const BODY_PIVOT_HEIGHT := 0.5        # parent origin (lean/flip pivot) sits this far above the feet
const BOARD_SIZE := Vector3(0.55, 0.08, 1.44)
const DECAL_OFFSET := 0.005           # sprite quads sit this far outside the face they decorate
const GOGGLE_WIDTH_FRACTION := 0.8    # goggles span this fraction of the helmet front-face width

# --- Materials ---
const JACKET_METALLIC := 0.0
const JACKET_SPECULAR := 1.0
const JACKET_ROUGHNESS := 1.0
const FLAT_ROUGHNESS := 1.0
const BOARD_EDGE_COLOR := Color(0.0, 0.0, 0.0)

# --- Player picks (indices into the lists above) ---
var jacket: int = 0
var helmet: int = 0
var pants: int = 0
var goggles: int = 0
var board: int = 0
var tutorial_board_unlocked: bool = false

# Caches: built lazily, shared by every rider
var _textures: Dictionary = {}   # String key -> Texture2D
var _materials: Dictionary = {}  # String key -> StandardMaterial3D
var _meshes: Dictionary = {}     # String key -> Mesh


func _ready() -> void:
	_load()


func unlock_tutorial_board() -> void:
	if tutorial_board_unlocked:
		return
	tutorial_board_unlocked = true
	_save()
	unlock_changed.emit()


## Sets one pick (part = &"jacket", &"helmet", &"pants", &"goggles" or &"board"), saves, notifies.
func select(part: StringName, idx: int) -> void:
	set(part, idx)
	_save()
	appearance_changed.emit()


func grommet_board_count() -> int:
	return BOARD_TEXTURE_PATHS.size() - 1


# --- Textures ---

func jacket_texture(idx: int) -> Texture2D:
	var key := "jacket%d" % idx
	if not _textures.has(key):
		if idx == 0:
			_textures[key] = load(JACKET_TEXTURE_PATH)
		else:
			_textures[key] = _recolor_jacket(_load_image(JACKET_TEXTURE_PATH), JACKET_COLORS[idx])
	return _textures[key]


func goggle_texture(idx: int) -> Texture2D:
	var key := "goggles%d" % idx
	if not _textures.has(key):
		var img := _load_image(GOGGLE_TEXTURE_PATH)
		img = img.get_region(img.get_used_rect())  # crop transparent margin so the quad hugs the lens
		_textures[key] = _hue_shift_goggles(img, GOGGLE_HUE_SHIFTS[idx])
	return _textures[key]


func board_texture(idx: int) -> Texture2D:
	var key := "board%d" % idx
	if not _textures.has(key):
		_textures[key] = load(BOARD_TEXTURE_PATHS[idx])
	return _textures[key]


func _load_image(path: String) -> Image:
	# Copy: some renderers hand back the texture's own Image, and recolors must not compound
	var img: Image = (load(path) as Texture2D).get_image().duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


## Takes hue+saturation from the target and scales the sprite's value by target.v / base v,
## so dark presets stay dark and the zipper/button shading survives.
func _recolor_jacket(img: Image, target: Color) -> ImageTexture:
	var v_scale := target.v / JACKET_SPRITE_BASE_V
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			img.set_pixel(x, y, Color.from_hsv(target.h, target.s, clampf(c.v * v_scale, 0.0, 1.0), c.a))
	return ImageTexture.create_from_image(img)


## Rotates lens hue; low-saturation pixels (white frame) are left alone.
func _hue_shift_goggles(img: Image, shift: float) -> ImageTexture:
	if shift != 0.0:
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a == 0.0 or c.s <= GOGGLE_FRAME_MAX_SAT:
					continue
				img.set_pixel(x, y, Color.from_hsv(fposmod(c.h + shift, 1.0), c.s, c.v, c.a))
	return ImageTexture.create_from_image(img)


# --- Materials ---

func _material(key: String, make: Callable) -> StandardMaterial3D:
	if not _materials.has(key):
		_materials[key] = make.call()
	return _materials[key]


func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = FLAT_ROUGHNESS
	return mat


func _textured_material(tex: Texture2D) -> StandardMaterial3D:
	var mat := _flat_material(Color.WHITE)
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat


func _jacket_material(color: Color, tex: Texture2D) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color if tex == null else Color.WHITE
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.metallic = JACKET_METALLIC
	mat.metallic_specular = JACKET_SPECULAR
	mat.roughness = JACKET_ROUGHNESS
	return mat


func _goggle_material(idx: int) -> StandardMaterial3D:
	var mat := _textured_material(goggle_texture(idx))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	return mat


# --- Meshes (unit-less, materials applied per instance via material_override) ---

func _box(key: String, size: Vector3) -> BoxMesh:
	if not _meshes.has(key):
		var box := BoxMesh.new()
		box.size = size
		_meshes[key] = box
	return _meshes[key]


func _quad(key: String, size: Vector2) -> QuadMesh:
	if not _meshes.has(key):
		var quad := QuadMesh.new()
		quad.size = size
		_meshes[key] = quad
	return _meshes[key]


func _add_mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)


## Builds pants/jacket/helmet bands plus jacket + goggle sprites on the +X face,
## feet BODY_PIVOT_HEIGHT below parent's origin. Rotate parent PI about Y for a goofy-facing rider.
func build_rider_body(parent: Node3D, jacket_idx: int, helmet_idx: int, pants_idx: int, goggle_idx: int) -> void:
	var w := BODY_SIZE.x
	var d := BODY_SIZE.z
	var pants_h := PANTS_HEIGHT
	var jacket_h := JACKET_HEIGHT
	var helmet_h := HELMET_SIZE.y
	var bottom := -BODY_PIVOT_HEIGHT
	var pants_y := bottom + pants_h * 0.5
	var jacket_y := bottom + pants_h + jacket_h * 0.5
	var helmet_y := bottom + pants_h + jacket_h + helmet_h * 0.5
	var face_x := w * 0.5 + DECAL_OFFSET
	var face_rot := Vector3(0.0, PI * 0.5, 0.0)  # QuadMesh faces +Z; this turns it to +X, unmirrored

	_add_mesh(parent, _box("pants", Vector3(w, pants_h, d)),
		_material("pants%d" % pants_idx, _flat_material.bind(PANTS_COLORS[pants_idx])), Vector3(0.0, pants_y, 0.0))
	_add_mesh(parent, _box("jacket", Vector3(w, jacket_h, d)),
		_material("jacket%d" % jacket_idx, _jacket_material.bind(JACKET_COLORS[jacket_idx], null)), Vector3(0.0, jacket_y, 0.0))
	_add_mesh(parent, _box("helmet", HELMET_SIZE),
		_material("helmet%d" % helmet_idx, _flat_material.bind(HELMET_COLORS[helmet_idx])), Vector3(0.0, helmet_y, 0.0))

	_add_mesh(parent, _quad("jacket_face", Vector2(d, jacket_h)),
		_material("jacket_face%d" % jacket_idx, _jacket_material.bind(JACKET_COLORS[jacket_idx], jacket_texture(jacket_idx))),
		Vector3(face_x, jacket_y, 0.0), face_rot)

	var gsize := goggle_size(HELMET_SIZE.z, helmet_h)
	_add_mesh(parent, _quad("goggles", gsize),
		_material("goggles%d" % goggle_idx, _goggle_material.bind(goggle_idx)),
		Vector3(HELMET_SIZE.x * 0.5 + DECAL_OFFSET, helmet_y, 0.0), face_rot)


## Goggle sprite size on a helmet face band_w wide and band_h tall: GOGGLE_WIDTH_FRACTION of the
## width, height from the cropped sprite's aspect, capped at the band. Shared by the 3D rig and lodge preview.
func goggle_size(band_w: float, band_h: float) -> Vector2:
	var tex := goggle_texture(0)
	var w := band_w * GOGGLE_WIDTH_FRACTION
	return Vector2(w, minf(w * float(tex.get_height()) / float(tex.get_width()), band_h))


## Builds the board (flat black box) with its sprite on top and bottom, centred on parent's origin.
## Sprite top = nose = -Z on both faces; bottom quad is rotated (not scaled) so text reads correctly.
func build_board(parent: Node3D, board_idx: int) -> void:
	_add_mesh(parent, _box("board", BOARD_SIZE), _material("board_edge", _flat_material.bind(BOARD_EDGE_COLOR)), Vector3.ZERO)
	var quad := _quad("board_face", Vector2(BOARD_SIZE.x, BOARD_SIZE.z))
	var mat := _material("board%d" % board_idx, _textured_material.bind(board_texture(board_idx)))
	var face_y := BOARD_SIZE.y * 0.5 + DECAL_OFFSET
	_add_mesh(parent, quad, mat, Vector3(0.0, face_y, 0.0), Vector3(-PI * 0.5, 0.0, 0.0))
	_add_mesh(parent, quad, mat, Vector3(0.0, -face_y, 0.0), Vector3(PI * 0.5, PI, 0.0))


# --- Persistence ---

func _save() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value(SAVE_SECTION, "tutorial_board_unlocked", tutorial_board_unlocked)
	config.set_value(SAVE_SECTION, "jacket", jacket)
	config.set_value(SAVE_SECTION, "helmet", helmet)
	config.set_value(SAVE_SECTION, "pants", pants)
	config.set_value(SAVE_SECTION, "goggles", goggles)
	config.set_value(SAVE_SECTION, "board", board)
	config.save(SAVE_PATH)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	tutorial_board_unlocked = config.get_value(SAVE_SECTION, "tutorial_board_unlocked", false)
	jacket = _clamp_pick(config.get_value(SAVE_SECTION, "jacket", 0), JACKET_COLORS.size())
	helmet = _clamp_pick(config.get_value(SAVE_SECTION, "helmet", 0), HELMET_COLORS.size())
	pants = _clamp_pick(config.get_value(SAVE_SECTION, "pants", 0), PANTS_COLORS.size())
	goggles = _clamp_pick(config.get_value(SAVE_SECTION, "goggles", 0), GOGGLE_HUE_SHIFTS.size())
	var board_limit := BOARD_TEXTURE_PATHS.size() if tutorial_board_unlocked else grommet_board_count()
	board = _clamp_pick(config.get_value(SAVE_SECTION, "board", 0), board_limit)


## Out-of-range saved picks (e.g. a list shrank) fall back to the default.
func _clamp_pick(value: int, count: int) -> int:
	return value if value >= 0 and value < count else 0
