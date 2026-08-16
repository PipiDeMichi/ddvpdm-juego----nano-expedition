class_name HUD extends Control

@onready var _score_label: Label = %ScoreLabel
@onready var _health_bar: ProgressBar = %HealthBar
@onready var _game_over_label: Label = %GameOverLabel
@onready var _restart_button: Button = %RestartButton
@onready var _dash_label: Label = %DashLabel
@onready var _bomb_button: Button = %BombButton
@onready var _grenade_button: Button = %GrenadeButton
@onready var _warning_label: Label = %WarningLabel
@onready var _dark_overlay: ColorRect = %DarkOverlay
@onready var _boss_bar: ProgressBar = %BossHealthBar
@onready var _boss_label: Label = %BossLabel
@onready var _continue_button: Button = %ContinueButton
@onready var _stun_label: Label = %BossStunLabel
@onready var _stat_panel: PanelContainer = %ScoreboardPanel
@onready var _stat_score: Label = %ScoreboardScore
@onready var _stat_enemies: Label = %EnemiesLabel
@onready var _stat_dashes: Label = %DashesLabel
@onready var _stat_damage: Label = %DamageLabel
@onready var _stat_bombs: Label = %BombsLabel
@onready var _stat_grenades: Label = %GrenadesLabel
@onready var _stat_combo: Label = %ComboLabel
@onready var _stat_duration: Label = %DurationLabel
@onready var _pause_panel: PanelContainer = %PausePanel
@onready var _pause_resume: Button = %PauseResumeButton
@onready var _pause_save_menu: Button = %PauseSaveMenuButton
@onready var _pause_button: Button = %PauseButton

## True while the boss warning label should be flashing on/off
var _warn_flash_active: bool = false
## Timer for the 1s on/off flash cycle (0.5s on, 0.5s off)
var _warn_flash_timer: float = 0.0

var _player: Player = null


func _ready() -> void:
	# The HUD stays interactive even when gameplay is paused (e.g. level clear).
	process_mode = Node.PROCESS_MODE_ALWAYS

	_game_over_label.visible = false
	_restart_button.visible = false
	_dash_label.text = "DASH 100% (5/5)"
	_restart_button.pressed.connect(_on_restart_pressed)
	_bomb_button.pressed.connect(_on_bomb_pressed)
	_grenade_button.pressed.connect(_on_grenade_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_pause_resume.pressed.connect(_on_pause_resume)
	_pause_save_menu.pressed.connect(_on_pause_save_menu)
	_pause_button.pressed.connect(_on_pause_button_pressed)
	_warning_label.visible = false
	# Draw the boss warning on top of the screen-darkening overlay (z 50)
	_warning_label.z_index = 100
	_dark_overlay.visible = false
	_boss_bar.visible = false
	_boss_label.visible = false
	_continue_button.visible = false
	_stun_label.visible = false
	_stat_panel.visible = false
	_pause_panel.visible = false

	# The GameManager/player spawn in the parent node's _ready, which runs
	# AFTER this HUD's _ready. Defer binding until the end of the first frame
	# so the player and GameManager reliably exist.
	call_deferred("_setup")


func _setup() -> void:
	var gm: GameManager = get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm:
		gm.score_changed.connect(_on_score_changed)
		gm.game_over.connect(_on_game_over)
		gm.player_spawned.connect(_bind_player)

	var player: Player = get_tree().get_first_node_in_group("player") as Player
	if player:
		_bind_player(player)


func _bind_player(player: Player) -> void:
	if _player == player:
		return
	_player = player
	player.health_changed.connect(_on_health_changed)
	player.dashes_changed.connect(_on_dashes_changed)
	player.bomb_charges_changed.connect(_on_bomb_charges_changed)

	# Initialize displays from current player state
	_on_health_changed(player.health)
	_on_dashes_changed(player.dashes, player.max_dashes)
	_on_bomb_charges_changed(player.bomb_charges)
	_grenade_button.text = "GRENADE"


func _process(delta: float) -> void:
	# Boss warning flash: toggle visibility every 0.5s for a 1s on/off cycle.
	if _warn_flash_active:
		_warn_flash_timer -= delta
		if _warn_flash_timer <= 0.0:
			_warn_flash_timer = 0.5
			_warning_label.visible = not _warning_label.visible

	# Keep grenade button in sync with cooldown (no signal spam)
	if _player and is_instance_valid(_player):
		var remaining: float = _player.grenade_remaining
		if remaining > 0.0:
			_grenade_button.text = "GRENADE %.0fs" % ceil(remaining)
			_grenade_button.disabled = true
		else:
			_grenade_button.text = "GRENADE"
			_grenade_button.disabled = false

	# Bomb button: also show seconds until the next charge is reclaimed
		_update_bomb_button()


func _update_bomb_button() -> void:
	var charges: int = _player.bomb_charges
	var recharging: float = _player.get_bomb_recharge_remaining()
	if recharging > 0.0:
		_bomb_button.text = "BOMB x%d (%ds)" % [charges, int(ceil(recharging))]
	else:
		_bomb_button.text = "BOMB x%d" % charges
	# Still usable if the player has a charge left (recharge only REFILLS one)
	_bomb_button.disabled = charges <= 0


func _on_score_changed(new_score: int) -> void:
	_score_label.text = "SCORE: %d" % new_score


func _on_health_changed(new_health: int) -> void:
	var mx: int = _player.max_health if _player else 3
	_health_bar.max_value = mx
	_health_bar.value = new_health


func _on_dashes_changed(dash_count: int, max_dashes: int) -> void:
	var pct: int = int(round(float(dash_count) / float(max_dashes) * 100.0))
	_dash_label.text = "DASH %d%% (%d/%d)" % [pct, dash_count, max_dashes]


func _on_bomb_charges_changed(count: int) -> void:
	_bomb_button.text = "BOMB x%d" % count
	_bomb_button.disabled = count <= 0


func _on_game_over(final_score: int) -> void:
	_game_over_label.text = "GAME OVER\nFinal Score: %d" % final_score
	_game_over_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
	_game_over_label.visible = true
	_restart_button.visible = true


func _on_bomb_pressed() -> void:
	if _player and is_instance_valid(_player):
		_player.use_bomb()


func _on_grenade_pressed() -> void:
	if _player and is_instance_valid(_player):
		_player.use_grenade()


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_continue_pressed() -> void:
	var gm: GameManager = get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm:
		gm.continue_game()


## Boss warning: show the message and darken the screen over the given duration.
## The warning label flashes on/off every 1 second and is drawn on top of the
## darkening overlay.
func start_boss_warning(duration: float) -> void:
	_warning_label.visible = true
	_warn_flash_active = true
	_warn_flash_timer = 0.5
	_dark_overlay.visible = true
	_dark_overlay.color = Color(0, 0, 0, 0)
	var dark: Tween = create_tween()
	dark.tween_property(_dark_overlay, "color:a", 0.9, duration)


## Boss has spawned: hide warning, show its health bar, fade the darkness out.
func on_boss_spawned(boss: Boss) -> void:
	_warn_flash_active = false
	_warning_label.visible = false
	_boss_bar.max_value = boss.max_health
	_boss_bar.value = boss.health
	_boss_bar.visible = true
	_boss_label.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(_dark_overlay, "color:a", 0.0, 1.0)
	tween.tween_callback(func() -> void:
		_dark_overlay.visible = false
	)


func set_boss_health(hp: int, max_hp: int) -> void:
	if _boss_bar:
		_boss_bar.max_value = max_hp
		_boss_bar.value = hp


## Show "BOSS STUNED" for the given duration (bomb stun effect).
func show_boss_stunned(duration: float) -> void:
	_stun_label.visible = true
	var tween: Tween = create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(func() -> void:
		_stun_label.visible = false
	)


func show_level_complete() -> void:
	_boss_bar.visible = false
	_boss_label.visible = false
	_game_over_label.text = "LEVEL COMPLETED"
	_game_over_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3, 1))
	_game_over_label.visible = true
	_restart_button.text = "PLAY AGAIN"
	_restart_button.visible = true
	_continue_button.visible = true


func hide_level_complete() -> void:
	_game_over_label.visible = false
	_restart_button.visible = false
	_continue_button.visible = false
	_stat_panel.visible = false


## Show/hide the in-game pause menu (driven by ESC / the PauseManager).
func set_paused(paused: bool) -> void:
	_pause_panel.visible = paused
	if paused:
		_pause_resume.grab_focus()


## Top-right HUD pause button: opens the in-game pause menu (same as pressing ESC).
func _on_pause_button_pressed() -> void:
	var gm: GameManager = get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm:
		gm.toggle_pause()  # flips to paused + shows the panel (guards against game over)
	else:
		get_tree().paused = not get_tree().paused
		_pause_panel.visible = get_tree().paused


func _on_pause_resume() -> void:
	var gm: GameManager = get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm:
		gm.toggle_pause()  # flips back to running and hides the panel
	else:
		get_tree().paused = false
		_pause_panel.visible = false


func _on_pause_save_menu() -> void:
	var gm: GameManager = get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm:
		gm.save_and_quit_to_menu()
	else:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/menu.tscn")


## Populate and show the end-of-run scoreboard (score, kills, dashes, damage,
## bombs, grenades, max combo, run duration).
func show_scoreboard(score: int, enemies: int, dashes: int, damage: int,
		bombs: int, grenades: int, combo: int, duration: float) -> void:
	_stat_panel.visible = true
	_stat_score.text = "Final Score:  %d" % score
	_stat_enemies.text = "Enemies killed:  %d" % enemies
	_stat_dashes.text = "Dashes used:  %d" % dashes
	_stat_damage.text = "Damage taken:  %d" % damage
	_stat_bombs.text = "Bombs used:  %d" % bombs
	_stat_grenades.text = "Grenades thrown:  %d" % grenades
	_stat_combo.text = "Max combo:  x%d" % combo
	_stat_duration.text = "Duration:  %s" % _format_duration(int(duration))


## Format a duration in seconds as "M:SS".
func _format_duration(total_seconds: int) -> String:
	var m: int = int(floor(float(total_seconds) / 60.0))
	var s: int = total_seconds - m * 60
	return "%d:%02d" % [m, s]
