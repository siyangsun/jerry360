extends Node

var _menu_player: AudioStreamPlayer
var _game_player: AudioStreamPlayer
var _death_player: AudioStreamPlayer


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

	var death_stream := load("res://assets/audio/deathscreen.mp3") as AudioStreamMP3
	death_stream.loop = true
	_death_player = AudioStreamPlayer.new()
	_death_player.stream = death_stream
	add_child(_death_player)

	GameManager.state_changed.connect(_on_state_changed)
	_on_state_changed(GameManager.state)


func _on_state_changed(new_state: GameManager.State) -> void:
	match new_state:
		GameManager.State.MENU:
			_switch_to(_menu_player, [_game_player, _death_player])
		GameManager.State.DEAD:
			_switch_to(_death_player, [_menu_player, _game_player])
		GameManager.State.PLAYING:
			_switch_to(_game_player, [_menu_player, _death_player])
		GameManager.State.PAUSED:
			pass  # keep whatever is playing


func _switch_to(start: AudioStreamPlayer, stop: Array) -> void:
	if start.playing:
		return
	for p in stop:
		p.stop()
	start.play()
