extends Node3D

var _snow: GPUParticles3D
var _trail: GPUParticles3D
var _player: CharacterBody3D
var _active := false


func _ready() -> void:
	_player = get_parent() as CharacterBody3D
	_setup_snow()
	_setup_trail()
	GameManager.state_changed.connect(_on_state_changed)
	_active = GameManager.state == GameManager.State.PLAYING


func _physics_process(_delta: float) -> void:
	var emitting := _active and is_instance_valid(_player) and _player.is_on_floor()
	_snow.emitting = emitting
	_trail.emitting = emitting


func _setup_snow() -> void:
	_snow = GPUParticles3D.new()
	_snow.amount = 60
	_snow.lifetime = 1.0
	_snow.local_coords = false
	_snow.position = Vector3(0.0, 0.05, 0.25)

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 65.0
	mat.gravity = Vector3(0, -5.0, 0)
	mat.initial_velocity_min = 2.5
	mat.initial_velocity_max = 7.0
	mat.scale_min = 0.06
	mat.scale_max = 0.18

	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	mat.color_ramp = ramp

	_snow.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.07
	mesh.height = 0.14
	mesh.radial_segments = 4
	mesh.rings = 2
	_snow.draw_pass_1 = mesh

	add_child(_snow)


func _setup_trail() -> void:
	_trail = GPUParticles3D.new()
	_trail.amount = 120
	_trail.lifetime = 0.7
	_trail.local_coords = false
	_trail.position = Vector3(0.0, 0.04, 0.2)

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0.1, 1)
	mat.spread = 10.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 0.1
	mat.initial_velocity_max = 0.5
	mat.scale_min = 0.12
	mat.scale_max = 0.28
	# Drive color here so it multiplies cleanly with the alpha-only gradient below
	mat.color = Color(0.75, 0.75, 0.75, 1.0)

	# Gradient controls alpha fade only — RGB stays white so mat.color drives the tint
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.88))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	mat.color_ramp = ramp

	_trail.process_material = mat

	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.45)
	var quad_mat := StandardMaterial3D.new()
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad_mat.vertex_color_use_as_albedo = true
	quad_mat.albedo_color = Color.WHITE
	quad.material = quad_mat
	_trail.draw_pass_1 = quad

	add_child(_trail)


func _on_state_changed(new_state: GameManager.State) -> void:
	_active = new_state == GameManager.State.PLAYING
