extends Control


func _ready() -> void:
	$Buttons/ResumeButton.pressed.connect(GameManager.resume_game)
	$Buttons/MenuButton.pressed.connect(GameManager.return_to_menu)
