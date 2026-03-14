extends ColorRect

@export var levels: float = 6.0

const BASE_LEVELS := 9.0              # normal number of color steps during play (higher = smoother)
const MIN_COMBO_LEVELS := 4.5         # fewest color steps at high combo — image gets grittier/crunchier
const STOMP_LEVELS := 2.0             # color steps during a perfect stomp flash (very crunchy for a moment)
const STOMP_FLASH_DURATION := 0.25    # how long the stomp crunch flash lasts (seconds)
const COMBO_LEVELS_RAMP := 10         # combo count at which the image reaches maximum crunch

const DANGER_SPEED_THRESHOLD := 40.0  # speed above which speed lines begin
const LEAN_FORWARD_MAX_SPEED  := 55.0  # player's lean-forward speed cap (must match player.gd export)
const MAX_SPEED_LINES := 1.0           # speed lines intensity at max lean-forward speed

var _target_levels: float = BASE_LEVELS
var _current_levels: float = BASE_LEVELS
var _flash_timer: float = 0.0
var _combo_target_levels: float = BASE_LEVELS
var _current_speed_lines: float = 0.0
var _player: CharacterBody3D


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/posterize.gdshader")
	mat.set_shader_parameter("levels", levels)
	mat.set_shader_parameter("speed_lines", 0.0)
	material = mat
	_current_levels = levels
	_target_levels = levels
	ScoreManager.combo_changed.connect(_on_combo_changed)
	ScoreManager.trick_landed.connect(_on_trick_landed)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.game_started.connect(_on_game_started)
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D


func _process(delta: float) -> void:
	var overspeed_ratio := 0.0
	if GameManager.state == GameManager.State.PLAYING \
			and is_instance_valid(_player) and _player.is_on_floor():
		overspeed_ratio = clampf(
			(GameManager.current_speed - DANGER_SPEED_THRESHOLD) / (LEAN_FORWARD_MAX_SPEED - DANGER_SPEED_THRESHOLD),
			0.0, 1.0)
	_target_levels = _combo_target_levels

	if _flash_timer > 0.0:
		_flash_timer -= delta
		_current_levels = STOMP_LEVELS
	else:
		_current_levels = lerpf(_current_levels, _target_levels, 5.0 * delta)
	material.set_shader_parameter("levels", _current_levels)

	var target_speed_lines := overspeed_ratio * MAX_SPEED_LINES
	_current_speed_lines = lerpf(_current_speed_lines, target_speed_lines, 4.0 * delta)
	material.set_shader_parameter("speed_lines", _current_speed_lines)


func _on_combo_changed(count: int, _multiplier: float) -> void:
	var t := clampf(float(count) / COMBO_LEVELS_RAMP, 0.0, 1.0)
	_combo_target_levels = lerpf(BASE_LEVELS, MIN_COMBO_LEVELS, t)


func _on_trick_landed(is_stomp: bool) -> void:
	if is_stomp:
		_flash_timer = STOMP_FLASH_DURATION


func _on_game_started() -> void:
	_combo_target_levels = BASE_LEVELS
	_target_levels = BASE_LEVELS
	_current_levels = BASE_LEVELS
	_flash_timer = 0.0
	_current_speed_lines = 0.0


func _on_state_changed(new_state: GameManager.State) -> void:
	if new_state == GameManager.State.DEAD:
		_current_speed_lines = 0.0
		material.set_shader_parameter("speed_lines", 0.0)
