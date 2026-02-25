extends CanvasLayer

@onready var distance_label: Label = $DistanceLabel
@onready var death_screen: Control = $DeathScreen
@onready var final_dist_label: Label = $DeathScreen/VBox/FinalDistanceLabel
@onready var high_score_label: Label = $DeathScreen/VBox/HighScoreLabel
@onready var menu_screen: Control = $MenuScreen


func _ready() -> void:
	ScoreManager.distance_updated.connect(_on_distance_updated)
	ScoreManager.new_high_score.connect(_on_new_high_score)
	GameManager.state_changed.connect(_on_state_changed)
	_on_state_changed(GameManager.state)


func _on_distance_updated(dist: float) -> void:
	distance_label.text = "%.0f m" % dist


func _on_new_high_score(dist: float) -> void:
	high_score_label.text = "NEW BEST: %.0f m" % dist


func _on_state_changed(new_state: GameManager.State) -> void:
	menu_screen.visible = new_state == GameManager.State.MENU
	death_screen.visible = new_state == GameManager.State.DEAD
	distance_label.visible = new_state == GameManager.State.PLAYING

	if new_state == GameManager.State.DEAD:
		final_dist_label.text = "Distance: %.0f m" % ScoreManager.distance
		high_score_label.text = "Best: %.0f m" % ScoreManager.high_score


func _on_start_pressed() -> void:
	GameManager.start_game()


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().reload_current_scene()
