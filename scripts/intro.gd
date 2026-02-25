extends Control

const MAIN_SCENE := "res://scenes/main.tscn"

const SLIDES: Array[String] = [
	"JERRY.",
	"Age 34.\nFormer tax accountant.\n\nFired on a Tuesday.",
	"He found his late grandfather's snowboard\nin the garage.\n\nHe drove to the mountain.\nHe pointed it downhill.",
	"That was three weeks ago.\n\nJerry has not stopped.",
]

const FADE_TIME := 0.5
const HOLD_TIME := 2.4

var _slide_index := 0
var _skipped := false

@onready var label: Label = $Label
@onready var skip_label: Label = $SkipLabel


func _ready() -> void:
	label.modulate.a = 0.0
	_show_slide(0)


func _unhandled_input(event: InputEvent) -> void:
	if _skipped:
		return
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_skip()


func _show_slide(index: int) -> void:
	if index >= SLIDES.size():
		_go_to_main()
		return

	label.text = SLIDES[index]

	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, FADE_TIME)
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(label, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(func():
		_slide_index += 1
		_show_slide(_slide_index)
	)


func _skip() -> void:
	_skipped = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(_go_to_main)


func _go_to_main() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)
