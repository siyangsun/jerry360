extends Node

var _menu_player: AudioStreamPlayer
var _game_player: AudioStreamPlayer


func _ready() -> void:
	var menu_stream := load("res://assets/audio/purplepinkcannon - menu.mp3") as AudioStreamMP3
	menu_stream.loop = true
	_menu_player = AudioStreamPlayer.new()
	_menu_player.stream = menu_stream
	add_child(_menu_player)

	var game_stream := load("res://assets/audio/KRAZYKRAZY.mp3") as AudioStreamMP3
	game_stream.loop = true
	_game_player = AudioStreamPlayer.new()
	_game_player.stream = game_stream
	add_child(_game_player)

	GameManager.state_changed.connect(_on_state_changed)
	_on_state_changed(GameManager.state)


func _on_state_changed(new_state: GameManager.State) -> void:
	match new_state:
		GameManager.State.MENU, GameManager.State.DEAD:
			_switch_to(_menu_player, _game_player)
		GameManager.State.PLAYING:
			_switch_to(_game_player, _menu_player)
		GameManager.State.PAUSED:
			pass  # keep whatever is playing


func _switch_to(start: AudioStreamPlayer, stop: AudioStreamPlayer) -> void:
	if start.playing:
		return
	stop.stop()
	start.play()
