class_name MainMenu extends Control

@onready var _play_button: Button = %PlayButton
@onready var _continue_button: Button = %ContinueButton
@onready var _exit_button: Button = %ExitButton


## The persistent music autoload (survives scene changes), or null if unavailable.
func _music() -> Music:
	return get_node_or_null("/root/MusicPlayer") as Music


func _ready() -> void:
	# Play the menu theme and crossfade to the game theme when a choice is made.
	var m := _music()
	if m:
		m.play_menu_music()
	# "Continue" is only available if there is a saved, in-progress run.
	_continue_button.disabled = not SaveSystem.has_save()
	_play_button.grab_focus()
	_play_button.pressed.connect(_on_play)
	_continue_button.pressed.connect(_on_continue)
	_exit_button.pressed.connect(_on_exit)


func _on_play() -> void:
	# Start a brand-new run: discard any previous save.
	SaveSystem.pending_resume = false
	SaveSystem.clear_save()
	var m := _music()
	if m:
		m.play_game_music()
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_continue() -> void:
	if not SaveSystem.has_save():
		return
	# Keep the save so the game loads it and resumes the run.
	SaveSystem.pending_resume = true
	var m := _music()
	if m:
		m.play_game_music()
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_exit() -> void:
	get_tree().quit()
