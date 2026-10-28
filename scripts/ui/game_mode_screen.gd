extends Control
## "pick your poison": endless run or the tutorial.

signal back_pressed


func _ready() -> void:
	$Buttons/StartButton.pressed.connect(GameManager.start_game)
	$Buttons/LearnButton.pressed.connect(GameManager.start_game.bind(true))
	$BackButton.pressed.connect(back_pressed.emit)
