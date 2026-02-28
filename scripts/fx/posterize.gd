extends ColorRect

@export var levels: float = 6.0

const BASE_LEVELS := 9.0
const MIN_COMBO_LEVELS := 4.5    # crunchiest state at high combo
const STOMP_LEVELS := 2.0        # brief harsh snap on stomp
const STOMP_FLASH_DURATION := 0.25
const COMBO_LEVELS_RAMP := 10    # combo count at which full crunch is reached

var _target_levels: float = BASE_LEVELS
var _current_levels: float = BASE_LEVELS
var _flash_timer: float = 0.0


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/posterize.gdshader")
	mat.set_shader_parameter("levels", levels)
	material = mat
	_current_levels = levels
	_target_levels = levels
	ScoreManager.combo_changed.connect(_on_combo_changed)
	ScoreManager.trick_landed.connect(_on_trick_landed)
	GameManager.state_changed.connect(_on_state_changed)


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		_current_levels = STOMP_LEVELS
	else:
		_current_levels = lerpf(_current_levels, _target_levels, 5.0 * delta)
	material.set_shader_parameter("levels", _current_levels)


func _on_combo_changed(count: int, _multiplier: float) -> void:
	var t := clampf(float(count) / COMBO_LEVELS_RAMP, 0.0, 1.0)
	_target_levels = lerpf(BASE_LEVELS, MIN_COMBO_LEVELS, t)


func _on_trick_landed(is_stomp: bool) -> void:
	if is_stomp:
		_flash_timer = STOMP_FLASH_DURATION


func _on_state_changed(new_state: GameManager.State) -> void:
	if new_state == GameManager.State.PLAYING:
		_target_levels = BASE_LEVELS
		_current_levels = BASE_LEVELS
		_flash_timer = 0.0
