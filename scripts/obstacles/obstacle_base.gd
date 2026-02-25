extends StaticBody3D
## Base class for all obstacles.
## Subclass this and override _on_player_hit() for custom behaviour.

signal player_hit

@export var kill_player := true


func _ready() -> void:
	# Expects a child Area3D named "HitArea" with a CollisionShape3D
	var area := get_node_or_null("HitArea") as Area3D
	if area:
		area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_hit.emit()
		_on_player_hit(body)


func _on_player_hit(player: Node3D) -> void:
	if kill_player and player.has_method("die"):
		player.die()
