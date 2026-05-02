extends Node

signal song_changed(song_name: String)

var _menu_player: AudioStreamPlayer
var _game_player: AudioStreamPlayer
var _death_player: AudioStreamPlayer
var _wife_death_player: AudioStreamPlayer

const TUTORIAL_SONG := "res://assets/audio/music/figuring it out.mp3"
const WIFE_DEATH_SONG := "res://assets/audio/music/i miss my wife.mp3"

const GAMEPLAY_SONGS: Array[String] = [
	"res://assets/audio/music/KRAZYKRAZY.mp3",
	"res://assets/audio/music/osmanthus danger.mp3",
	"res://assets/audio/music/decimba.mp3",
	"res://assets/audio/music/neon snowcone.mp3",
	"res://assets/audio/music/watch out.mp3",
	"res://assets/audio/music/heel hook.mp3",
	"res://assets/audio/music/laguna liability.mp3",
	"res://assets/audio/music/earnings per share.mp3",
	"res://assets/audio/music/can't see shit.mp3",
]

const VOLUME_DB := -3.1

var _song_queue: Array[String] = []


func _ready() -> void:
	var menu_stream := load("res://assets/audio/music/menu.mp3") as AudioStreamMP3
	menu_stream.loop = true
	_menu_player = AudioStreamPlayer.new()
	_menu_player.stream = menu_stream
	_menu_player.volume_db = VOLUME_DB
	add_child(_menu_player)

	_game_player = AudioStreamPlayer.new()
	_game_player.volume_db = VOLUME_DB
	add_child(_game_player)
	_game_player.finished.connect(_play_random_gameplay_song)

	var death_stream := load("res://assets/audio/music/deathscreen.mp3") as AudioStreamMP3
	death_stream.loop = true
	_death_player = AudioStreamPlayer.new()
	_death_player.stream = death_stream
	_death_player.volume_db = VOLUME_DB
	add_child(_death_player)

	var wife_death_stream := load(WIFE_DEATH_SONG) as AudioStreamMP3
	wife_death_stream.loop = true
	_wife_death_player = AudioStreamPlayer.new()
	_wife_death_player.stream = wife_death_stream
	_wife_death_player.volume_db = VOLUME_DB
	add_child(_wife_death_player)

	GameManager.state_changed.connect(_on_state_changed)
	_on_state_changed(GameManager.state)


func _play_random_gameplay_song() -> void:
	if _song_queue.is_empty():
		_song_queue = GAMEPLAY_SONGS.duplicate()
		_song_queue.shuffle()
	var path := _song_queue.pop_front() as String
	var stream := load(path) as AudioStreamMP3
	stream.loop = false
	_game_player.stream = stream
	_game_player.play()
	song_changed.emit(path.get_file().get_basename())


func _on_state_changed(new_state: GameManager.State) -> void:
	match new_state:
		GameManager.State.MENU:
			_switch_to(_menu_player, [_game_player, _death_player, _wife_death_player])
		GameManager.State.DEAD:
			if GameManager.wife_killed_jerry:
				_switch_to(_wife_death_player, [_menu_player, _game_player, _death_player])
			else:
				_switch_to(_death_player, [_menu_player, _game_player, _wife_death_player])
		GameManager.State.PLAYING:
			if not _game_player.playing:
				if GameManager.is_tutorial:
					_play_tutorial_song()
				else:
					_play_random_gameplay_song()
			_menu_player.stop()
			_death_player.stop()
			_wife_death_player.stop()
		GameManager.State.PAUSED:
			pass  # keep whatever is playing


func _play_tutorial_song() -> void:
	var stream := load(TUTORIAL_SONG) as AudioStreamMP3
	stream.loop = true
	_game_player.stream = stream
	_game_player.play()
	song_changed.emit(TUTORIAL_SONG.get_file().get_basename())


func skip_song() -> void:
	if _game_player.playing:
		_game_player.stop()
		_play_random_gameplay_song()


func _switch_to(start: AudioStreamPlayer, stop: Array) -> void:
	if start.playing:
		return
	for p in stop:
		p.stop()
	start.play()
