extends StaticBody3D
## Base class for all obstacles.
## Subclass this and override _on_player_hit() for custom behaviour.

signal player_hit
signal near_miss

@export var kill_player := true
@export var near_miss_radius := 2.0   # detection sphere radius for close-call scoring (0 = disabled)

var _player_was_hit := false
var _near_miss_cooldown := 0.0


func _ready() -> void:
	# Expects a child Area3D named "HitArea" with a CollisionShape3D
	var area := get_node_or_null("HitArea") as Area3D
	if area:
		area.body_entered.connect(_on_body_entered)

	# Auto-create proximity zone for close-call detection
	if near_miss_radius > 0.0:
		var prox := Area3D.new()
		prox.name = "NearMissArea"
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = near_miss_radius
		shape.shape = sphere
		prox.add_child(shape)
		add_child(prox)
		prox.body_entered.connect(_on_near_miss_entered)
		prox.body_exited.connect(_on_near_miss_exited)


func _process(delta: float) -> void:
	if _near_miss_cooldown > 0.0:
		_near_miss_cooldown -= delta


func _on_near_miss_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_was_hit = false


func _on_near_miss_exited(body: Node3D) -> void:
	if body.is_in_group("player") and _near_miss_cooldown <= 0.0:
		_near_miss_cooldown = 2.0
		(func():
			if not _player_was_hit:
				near_miss.emit()
				ScoreManager.add_close_call()
		).call_deferred()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_was_hit = true
		player_hit.emit()
		_on_player_hit(body)


func _on_player_hit(player: Node3D) -> void:
	if kill_player and player.has_method("die"):
		player.die()
