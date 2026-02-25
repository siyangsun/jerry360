extends ColorRect

@export var levels: float = 6.0


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/posterize.gdshader")
	mat.set_shader_parameter("levels", levels)
	material = mat
