extends FogVolume

const CLEAR_FOG_RADIUS        := 15000.0  # clear bubble radius during clear runs (effectively no fog)
const CLEAR_FOG_FALLOFF       := 0.02     # fog density per unit during clear runs
const NORMAL_FOG_RADIUS       := 11.0     # clear bubble radius during normal runs (light fog in distance)
const NORMAL_FOG_FALLOFF      := 0.17     # fog density per unit during normal runs
const FOGGY_FOG_RADIUS        := 3.0      # clear bubble radius during foggy runs (fog starts very close)
const FOGGY_FOG_FALLOFF       := 0.15     # fog density per unit during foggy runs (thickens fast)
const FOG_TRANSITION_DURATION := 3.0      # seconds to blend between fog presets on variant change

const COMPAT_NORMAL_FOG_DENSITY := 0.025  # web: baseline haze, moodier than desktop
const COMPAT_MISTY_FOG_DENSITY  := 0.055  # web: thick soup
const COMPAT_CLEAR_FOG_DENSITY  := 0.005  # web: still a little haze, never fully clear

var _player: Node3D
var _tween: Tween
var _use_compat_fog: bool = false
var _compat_env: Environment
var _env: Environment            # world environment; volumetric fog is switched off on clear laps
var _mat: ShaderMaterial         # cached fog shader material
var _last_player_pos: Vector3 = Vector3.INF  # last position written to the shader (INF = never written)


func _ready() -> void:
	_use_compat_fog = RenderingServer.get_rendering_device() == null
	_player = get_tree().get_first_node_in_group("player") as Node3D
	var gen := get_tree().get_first_node_in_group("level_generator")
	if gen:
		gen.variant_changed.connect(_on_variant_changed)

	var world_env := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if _use_compat_fog:
		visible = false
		if world_env:
			_compat_env = world_env.environment
			_compat_env.volumetric_fog_enabled = false
			_compat_env.fog_aerial_perspective = 0.0
			_compat_env.fog_enabled = true
			_compat_env.fog_density = COMPAT_NORMAL_FOG_DENSITY
	else:
		if world_env:
			_env = world_env.environment
		_mat = material as ShaderMaterial
		_mat.set_shader_parameter("fog_radius", NORMAL_FOG_RADIUS)
		_mat.set_shader_parameter("fog_falloff", NORMAL_FOG_FALLOFF)


func _process(_delta: float) -> void:
	if _use_compat_fog:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return
	if _player.position != _last_player_pos:
		_last_player_pos = _player.position
		_mat.set_shader_parameter("player_pos", _last_player_pos)


func _on_variant_changed(variant: String) -> void:
	if _use_compat_fog:
		_compat_variant_changed(variant)
		return

	var target_radius: float
	var target_falloff: float
	if variant == "misty":
		target_radius = FOGGY_FOG_RADIUS
		target_falloff = FOGGY_FOG_FALLOFF
	elif variant == "clear":
		target_radius = CLEAR_FOG_RADIUS
		target_falloff = CLEAR_FOG_FALLOFF
	else:
		target_radius = NORMAL_FOG_RADIUS
		target_falloff = NORMAL_FOG_FALLOFF

	var from_radius: float = _mat.get_shader_parameter("fog_radius")
	var from_falloff: float = _mat.get_shader_parameter("fog_falloff")

	var log_r0 := log(from_radius);   var log_r1 := log(target_radius)
	var log_f0 := log(from_falloff);  var log_f1 := log(target_falloff)

	# Volumetric fog is pure cost on clear laps (the bubble is effectively infinite): turn it on
	# before blending away from clear, and off only once the blend into clear has finished.
	var is_clear := variant == "clear"
	if not is_clear:
		_set_volumetric_fog(true)
	_tween_fog(func(t: float) -> void:
		_mat.set_shader_parameter("fog_radius",  exp(lerp(log_r0, log_r1, t)))
		_mat.set_shader_parameter("fog_falloff", exp(lerp(log_f0, log_f1, t)))
	)
	if is_clear:
		_tween.finished.connect(_set_volumetric_fog.bind(false))


func _set_volumetric_fog(enabled: bool) -> void:
	if is_instance_valid(_env) and _env.volumetric_fog_enabled != enabled:
		_env.volumetric_fog_enabled = enabled


func _compat_variant_changed(variant: String) -> void:
	if not is_instance_valid(_compat_env):
		return
	var target_density: float
	if variant == "misty":
		target_density = COMPAT_MISTY_FOG_DENSITY
	elif variant == "clear":
		target_density = COMPAT_CLEAR_FOG_DENSITY
	else:
		target_density = COMPAT_NORMAL_FOG_DENSITY
	var from_density: float = _compat_env.fog_density
	_tween_fog(func(t: float) -> void:
		_compat_env.fog_density = lerp(from_density, target_density, t)
	)


func _tween_fog(step: Callable) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(step, 0.0, 1.0, FOG_TRANSITION_DURATION)
