extends Node

var _menu_player: AudioStreamPlayer
var _game_player: AudioStreamPlayer
var _death_player: AudioStreamPlayer

const GAMEPLAY_SONGS: Array[String] = [
	"res://assets/audio/KRAZYKRAZY.mp3",
	"res://assets/audio/osmanthus danger.mp3",
	"res://assets/audio/decimba.mp3",
]

var _song_queue: Array[String] = []


func _ready() -> void:
	var menu_stream := load("res://assets/audio/purplepinkcannon - menu.mp3") as AudioStreamMP3
	menu_stream.loop = true
	_menu_player = AudioStreamPlayer.new()
	_menu_player.stream = menu_stream
	add_child(_menu_player)

	_game_player = AudioStreamPlayer.new()
	add_child(_game_player)
	_game_player.finished.connect(_play_random_gameplay_song)

	var death_stream := load("res://assets/audio/deathscreen.mp3") as AudioStreamMP3
	death_stream.loop = true
	_death_player = AudioStreamPlayer.new()
	_death_player.stream = death_stream
	add_child(_death_player)

	GameManager.state_changed.connect(_on_state_changed)
	_on_state_changed(GameManager.state)


func _play_random_gameplay_song() -> void:
	if _song_queue.is_empty():
		_song_queue = GAMEPLAY_SONGS.duplicate()
		_song_queue.shuffle()
	var stream := load(_song_queue.pop_front()) as AudioStreamMP3
	stream.loop = false
	_game_player.stream = stream
	_game_player.play()


func _on_state_changed(new_state: GameManager.State) -> void:
	match new_state:
		GameManager.State.MENU:
			_switch_to(_menu_player, [_game_player, _death_player])
		GameManager.State.DEAD:
			_switch_to(_death_player, [_menu_player, _game_player])
		GameManager.State.PLAYING:
			if not _game_player.playing:
				_play_random_gameplay_song()
			_menu_player.stop()
			_death_player.stop()
		GameManager.State.PAUSED:
			pass  # keep whatever is playing


func _switch_to(start: AudioStreamPlayer, stop: Array) -> void:
	if start.playing:
		return
	for p in stop:
		p.stop()
	start.play()
