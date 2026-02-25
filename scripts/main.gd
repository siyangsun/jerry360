extends Node3D


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if GameManager.state == GameManager.State.PLAYING:
			GameManager.pause_game()
		elif GameManager.state == GameManager.State.PAUSED:
			GameManager.resume_game()
