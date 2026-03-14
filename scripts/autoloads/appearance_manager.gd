extends Node

signal appearance_changed
signal unlock_changed

const ELECTRIC_BLUE_BOARD := Color(0.04, 0.42, 1.0)

var jerry_color: Color = Color(1.0, 0.45, 0.05)
var board_color: Color = Color(0.18, 0.18, 0.18)
var tutorial_board_unlocked: bool = false


func _ready() -> void:
	_load()


func unlock_tutorial_board() -> void:
	if tutorial_board_unlocked:
		return
	tutorial_board_unlocked = true
	_save()
	unlock_changed.emit()


func _save() -> void:
	var config := ConfigFile.new()
	config.load("user://scores.cfg")
	config.set_value("appearance", "tutorial_board_unlocked", tutorial_board_unlocked)
	config.save("user://scores.cfg")


func _load() -> void:
	var config := ConfigFile.new()
	if config.load("user://scores.cfg") == OK:
		tutorial_board_unlocked = config.get_value("appearance", "tutorial_board_unlocked", false)
