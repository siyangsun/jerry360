extends Control
## Bottom-left pose widget: renders a mannequin sprite for player.current_action.
## Sprites live in SPRITE_DIR as <action>.png, <action>2.png, <action>3.png ... (extra numbers = animation frames).

const SPRITE_DIR := "res://assets/graphics/mannequin/"
const MAX_FRAMES := 9                       # highest numeric suffix probed per pose

# Look (Rat)
const WIDGET_ANCHORS := Vector4(0.0, 1.0, 0.0, 1.0)
const WIDGET_OFFSETS := Vector4(8.0, -264.0, 264.0, -8.0)   # 256x256 px (sprites at native 1:1), 8 px from the bottom-left corner
const SPRITE_ALPHA := 0.9
const BLUR_SHADER_PATH := "res://assets/shaders/mannequin_blur.gdshader"
const BLUR_RADIUS_PX := 1.0                 # very light blur on the sprite only (user override of nearest crispness)
const FPS_DEFAULT := 6.0
const FPS_SPIN := 10.0

const MIN_POSE_HOLD := 0.12                 # s; display hold for every action but wipeout (anti-flicker)

const PlayerScript = preload("res://scripts/player/player.gd")
# Which actions loop fast / don't loop / mirror for goofy is a display choice, so it lives here
const SPIN_ACTIONS: Array[StringName] = [PlayerScript.ACTION_SPIN_LEFT, PlayerScript.ACTION_SPIN_RIGHT]
const HOLD_EXEMPT_ACTIONS: Array[StringName] = [  # entering these skips MIN_POSE_HOLD
	PlayerScript.ACTION_WIPEOUT, PlayerScript.ACTION_GRAB_FRONT, PlayerScript.ACTION_GRAB_BACK,
]
const NO_LOOP_ACTIONS: Array[StringName] = [PlayerScript.ACTION_WIPEOUT]
const GOOFY_FLIP_ACTIONS: Array[StringName] = [PlayerScript.ACTION_NEUTRAL, PlayerScript.ACTION_GRIND, PlayerScript.ACTION_BRAKE]

var player: PlayerScript                    # found via the "player" group

var _frames: Dictionary = {}                # action StringName -> Array[Texture2D]
var _sprite: TextureRect
var _shown: StringName = PlayerScript.ACTION_NEUTRAL
var _shown_time: float = 0.0                # time since _shown last changed

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = WIDGET_ANCHORS.x
	anchor_top = WIDGET_ANCHORS.y
	anchor_right = WIDGET_ANCHORS.z
	anchor_bottom = WIDGET_ANCHORS.w
	offset_left = WIDGET_OFFSETS.x
	offset_top = WIDGET_OFFSETS.y
	offset_right = WIDGET_OFFSETS.z
	offset_bottom = WIDGET_OFFSETS.w

	_sprite = TextureRect.new()
	_sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # user override: smooth when squatted/rotated
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite.modulate.a = SPRITE_ALPHA
	var blur := ShaderMaterial.new()
	blur.shader = load(BLUR_SHADER_PATH)
	blur.set_shader_parameter("blur_radius_px", BLUR_RADIUS_PX)
	_sprite.material = blur
	_sprite.pivot_offset = (Vector2(WIDGET_OFFSETS.z, WIDGET_OFFSETS.w) - Vector2(WIDGET_OFFSETS.x, WIDGET_OFFSETS.y)) * 0.5
	add_child(_sprite)

	for action in PlayerScript.ACTIONS:
		_frames[action] = _load_frames(action)
	visible = false


## Loads <action>.png, <action>2.png, ... stopping at the first gap.
## ResourceLoader.exists works in exported builds (raw pngs aren't packed there). In the editor it also
## says yes for a stale .import whose png was deleted, so there we additionally require the png itself.
func _load_frames(action: StringName) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	var in_editor := OS.has_feature("editor")
	for i in range(1, MAX_FRAMES + 1):
		var path := "%s%s%s.png" % [SPRITE_DIR, action, "" if i == 1 else str(i)]
		if not ResourceLoader.exists(path) or (in_editor and not FileAccess.file_exists(path)):
			break
		var tex := load(path) as Texture2D
		if tex == null:
			break
		frames.append(tex)
	return frames


## Render-only: what Jerry is doing comes from player.current_action.
func _process(delta: float) -> void:
	visible = GameManager.state == GameManager.State.PLAYING
	if not visible:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as PlayerScript
		if player == null:
			return

	var wanted := player.current_action
	_shown_time += delta
	if wanted != _shown and (wanted in HOLD_EXEMPT_ACTIONS or _shown_time >= MIN_POSE_HOLD):
		_shown = wanted
		_shown_time = 0.0  # frame index derives from this, so it resets only on a name change

	var frames: Array = _frames[_shown]
	if frames.is_empty():
		_sprite.texture = null
		return
	var fps := FPS_SPIN if _shown in SPIN_ACTIONS else FPS_DEFAULT
	var frame := int(_shown_time * fps)
	if _shown in NO_LOOP_ACTIONS:
		frame = mini(frame, frames.size() - 1)
	else:
		frame %= frames.size()
	_sprite.texture = frames[frame]
	_sprite.flip_h = player.is_goofy and _shown in GOOFY_FLIP_ACTIONS
	_sprite.scale = Vector2(1.0, player.pose_squat_y)
	# Sprites face the viewer with the board nose on the right, so nose-down = clockwise = +rotation.
	# Rotation is on the Control, independent of flip_h, so goofy mirroring never reverses it.
	_sprite.rotation = player.pose_flip_angle
