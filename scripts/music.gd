class_name Music extends Node
## Background music manager (autoload "MusicPlayer"). Plays the menu theme until
## the player enters the game, then crossfades to the normal gameplay theme on
## Play/Continue, and to the boss theme when the boss spawns. It survives scene
## changes so the music carries across the menu <-> game transition.

const MENU := preload("res://assets/Audios/menu.mp3")
const OST := preload("res://assets/Audios/ost1.mp3")
const BOSS_OST := preload("res://assets/Audios/boss_ost.mp3")

## Music volume in dB (shared by all tracks; 30% quieter than the original -6 dB)
@export var music_volume: float = -9.0
## Seconds for the crossfade between tracks
@export var fade_time: float = 1.0

## Two players let us crossfade: one fades out while the other fades in.
var _a: AudioStreamPlayer = null
var _b: AudioStreamPlayer = null
## The player that is currently audible
var _active: AudioStreamPlayer = null


func _ready() -> void:
	_a = AudioStreamPlayer.new()
	_b = AudioStreamPlayer.new()
	for p: AudioStreamPlayer in [_a, _b]:
		# Keep the music playing even while the game is paused (the pause menu or
		# the boss-defeat freeze), so it carries on through transitions.
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.volume_db = -60.0
		p.finished.connect(_on_finished)
		add_child(p)
	_active = _a


## Replay the current track so it loops until the song changes.
func _on_finished() -> void:
	if _active:
		_active.play()


## Play the main-menu theme.
func play_menu_music() -> void:
	_play_track_or_skip(MENU)


## Play the normal gameplay theme (used on Play/Continue).
func play_game_music() -> void:
	_play_track_or_skip(OST)


## Play the boss theme.
func play_boss_music() -> void:
	_play_track_or_skip(BOSS_OST)


## Crossfade to the given track, unless it's already the one playing.
func _play_track_or_skip(new_stream: AudioStream) -> void:
	if _active != null and _active.playing and _active.stream == new_stream:
		return
	if _a == null or _b == null:
		return
	var out: AudioStreamPlayer = _active
	var inn: AudioStreamPlayer = _b if out == _a else _a
	inn.stop()
	inn.stream = new_stream
	inn.volume_db = -60.0
	inn.play()
	var tw := create_tween()
	tw.tween_property(out, "volume_db", -60.0, fade_time)
	tw.parallel().tween_property(inn, "volume_db", music_volume, fade_time)
	tw.tween_callback(func() -> void:
		out.stop()
		_active = inn
	)
