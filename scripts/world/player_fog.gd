extends FogVolume

var _player: Node3D


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node3D


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return
	(material as ShaderMaterial).set_shader_parameter("player_pos", _player.position)
