extends CanvasLayer

@onready var distance_label: Label = $DistanceLabel
@onready var death_screen: Control = $DeathScreen
@onready var death_label: Label = $DeathScreen/DeathLabel
@onready var menu_screen: Control = $MenuScreen


func _ready() -> void:
	GameManager.state_changed.connect(_on_state_changed)
	_on_state_changed(GameManager.state)


func _process(_delta: float) -> void:
	if GameManager.state == GameManager.State.PLAYING:
		distance_label.text = "%.0f m\n%.0f m/s" % [ScoreManager.distance, GameManager.current_speed]


func _on_state_changed(new_state: GameManager.State) -> void:
	menu_screen.visible = new_state == GameManager.State.MENU
	death_screen.visible = new_state == GameManager.State.DEAD
	distance_label.visible = new_state == GameManager.State.PLAYING

	if new_state == GameManager.State.DEAD:
		var dist := ScoreManager.distance
		var best := ScoreManager.high_score
		var deaths := ScoreManager.deaths
		death_label.text = "He fell.\n%.0f meters — not bad for a Tuesday.\n\nBest: %.0f m  |  Falls: %d" % [dist, best, deaths]


func _on_start_pressed() -> void:
	GameManager.start_game()


func _on_try_again_pressed() -> void:
	GameManager.start_game()
