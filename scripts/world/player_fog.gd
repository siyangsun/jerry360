extends FogVolume

const LevelGenerator = preload("res://scripts/world/level_generator.gd")

const CLEAR_FOG_RADIUS   := 15000.0  # clear bubble radius during clear runs (effectively no fog)
const CLEAR_FOG_FALLOFF  := 0.02     # fog density per unit during clear runs
const NORMAL_FOG_RADIUS  := 11.0     # clear bubble radius during normal runs (light fog in distance)
const NORMAL_FOG_FALLOFF := 0.17     # fog density per unit during normal runs
const FOGGY_FOG_RADIUS   := 3.0      # clear bubble radius during foggy runs (fog starts very close)
const FOGGY_FOG_FALLOFF  := 0.15     # fog density per unit during foggy runs (thickens fast)
var _player: Node3D


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node3D
	var gen := get_tree().get_first_node_in_group("level_generator")
	if gen:
		gen.variant_changed.connect(_on_variant_changed)


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return
	(material as ShaderMaterial).set_shader_parameter("player_pos", _player.position)


func _on_variant_changed(variant: String) -> void:
	var mat := material as ShaderMaterial
	if variant == "misty":
		mat.set_shader_parameter("fog_radius", FOGGY_FOG_RADIUS)
		mat.set_shader_parameter("fog_falloff", FOGGY_FOG_FALLOFF)
	elif variant == "clear":
		mat.set_shader_parameter("fog_radius", CLEAR_FOG_RADIUS)
		mat.set_shader_parameter("fog_falloff", CLEAR_FOG_FALLOFF)
	else:
		mat.set_shader_parameter("fog_radius", NORMAL_FOG_RADIUS)
		mat.set_shader_parameter("fog_falloff", NORMAL_FOG_FALLOFF)
