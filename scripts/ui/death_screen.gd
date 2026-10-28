extends Control
## Wipeout summary over a gray wash, with a Try Again button.

const UIKit = preload("res://scripts/ui/ui_kit.gd")

@onready var _summary: Label = $DeathLabel


func _ready() -> void:
	$GrayOverlay.color = UIKit.SCREEN_OVERLAY_COLOR
	$TryAgainButton.pressed.connect(func() -> void: GameManager.start_game(GameManager.is_tutorial))


## Fills in the run summary; goofy changes the first line.
func show_results(was_goofy: bool) -> void:
	var tricks := ScoreManager.tricks_landed
	var top_combo := ScoreManager.max_combo
	var trick_str := "%d trick%s" % [tricks, "s" if tricks != 1 else ""]
	var combo_str := ("best combo x%d" % top_combo) if top_combo > 1 else "no combos"
	var first_line: String
	if GameManager.wife_killed_jerry:
		first_line = "not really feeling it today.\nsoup sounds good actually..."
	elif was_goofy:
		first_line = "Got a little too goofy."
	else:
		first_line = "He fell."
	_summary.text = "%s\n%.0f meters — not bad for a Tuesday.\n%s  |  %s\n\nBest: %.0f m  |  Falls: %d" % [
		first_line, ScoreManager.distance, trick_str, combo_str, ScoreManager.high_score, ScoreManager.deaths]
