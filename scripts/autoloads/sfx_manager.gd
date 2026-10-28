extends Node

const BUS := &"SFX"

var _grind_player: AudioStreamPlayer
var _snow_player: AudioStreamPlayer
var _land_player: AudioStreamPlayer
var _air_player: AudioStreamPlayer
var _collide_player: AudioStreamPlayer


func _ready() -> void:
	_grind_player = _make_player("res://assets/audio/sfx/railgrind.mp3", true)
	_snow_player = _make_player("res://assets/audio/sfx/on snow.mp3", true)
	_land_player = _make_player("res://assets/audio/sfx/landing.mp3", false)
	_air_player = _make_player("res://assets/audio/sfx/midair.mp3", false)
	_collide_player = _make_player("res://assets/audio/sfx/collide.mp3", false)
	GameManager.state_changed.connect(_on_state_changed)


func _make_player(path: String, loop: bool) -> AudioStreamPlayer:
	var stream := load(path) as AudioStreamMP3
	stream.loop = loop
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = BUS
	add_child(player)
	return player


func set_grinding(active: bool) -> void:
	if active and not _grind_player.playing:
		_grind_player.play()
	elif not active:
		_grind_player.stop()


func set_on_snow(active: bool) -> void:
	if active and not _snow_player.playing:
		_snow_player.play()
	elif not active:
		_snow_player.stop()


func play_landing() -> void:
	_land_player.play()


func play_airborne() -> void:
	_air_player.play()


func play_collide() -> void:
	_land_player.stop()
	_collide_player.play()


func _on_state_changed(new_state: GameManager.State) -> void:
	if new_state != GameManager.State.PLAYING:
		for player: AudioStreamPlayer in get_children():
			player.stop()
