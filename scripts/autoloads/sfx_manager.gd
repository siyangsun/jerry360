extends Node

var _grind_player: AudioStreamPlayer
var _snow_player: AudioStreamPlayer
var _land_player: AudioStreamPlayer
var _air_player: AudioStreamPlayer
var _collide_player: AudioStreamPlayer


func _ready() -> void:
	var grind_stream := load("res://assets/audio/sfx/railgrind.mp3") as AudioStreamMP3
	grind_stream.loop = true
	_grind_player = AudioStreamPlayer.new()
	_grind_player.stream = grind_stream
	add_child(_grind_player)

	var snow_stream := load("res://assets/audio/sfx/on snow.mp3") as AudioStreamMP3
	snow_stream.loop = true
	_snow_player = AudioStreamPlayer.new()
	_snow_player.stream = snow_stream
	add_child(_snow_player)

	var land_stream := load("res://assets/audio/sfx/landing.mp3") as AudioStreamMP3
	land_stream.loop = false
	_land_player = AudioStreamPlayer.new()
	_land_player.stream = land_stream
	add_child(_land_player)

	var air_stream := load("res://assets/audio/sfx/midair.mp3") as AudioStreamMP3
	air_stream.loop = false
	_air_player = AudioStreamPlayer.new()
	_air_player.stream = air_stream
	add_child(_air_player)

	var collide_stream := load("res://assets/audio/sfx/collide.mp3") as AudioStreamMP3
	collide_stream.loop = false
	_collide_player = AudioStreamPlayer.new()
	_collide_player.stream = collide_stream
	add_child(_collide_player)

	GameManager.state_changed.connect(_on_state_changed)


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
	_collide_player.play()


func _on_state_changed(new_state: GameManager.State) -> void:
	if new_state != GameManager.State.PLAYING:
		_grind_player.stop()
		_snow_player.stop()
		_land_player.stop()
		_air_player.stop()
		_collide_player.stop()
