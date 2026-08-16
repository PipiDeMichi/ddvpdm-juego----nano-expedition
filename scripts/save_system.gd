class_name SaveSystem extends RefCounted
## Persists / restores the full state of the current run (player HP, score,
## position, dash + bomb charges, run stats, and boss state) so the main menu's
## "Continue" button can drop the player straight back into an in-progress run.

const SAVE_PATH := "user://save.cfg"

## Set by the main menu right before switching to the game scene to request that
## the game load the existing save instead of starting a brand-new run.
static var pending_resume: bool = false


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


## Snapshot the current run into user://save.cfg.
static func save_run(gm: GameManager) -> void:
	if gm == null or gm.player == null:
		return
	var cfg := ConfigFile.new()
	var p: Player = gm.player

	cfg.set_value("run", "score", gm.score)
	cfg.set_value("run", "enemies_killed", gm.enemies_killed)
	cfg.set_value("run", "dash_uses", gm.dash_uses)
	cfg.set_value("run", "damage_taken", gm.damage_taken)
	cfg.set_value("run", "bombs_used", gm.bombs_used)
	cfg.set_value("run", "grenades_thrown", gm.grenades_thrown)
	cfg.set_value("run", "max_combo", gm.max_combo)
	cfg.set_value("run", "game_time", gm._game_time)
	cfg.set_value("run", "next_boss_threshold", gm._next_boss_threshold)

	cfg.set_value("player", "pos_x", p.global_position.x)
	cfg.set_value("player", "pos_y", p.global_position.y)
	cfg.set_value("player", "rotation", p.rotation)
	cfg.set_value("player", "health", p.health)
	cfg.set_value("player", "max_health", p.max_health)
	cfg.set_value("player", "dashes", p.dashes)
	cfg.set_value("player", "max_dashes", p.max_dashes)
	cfg.set_value("player", "bomb_charges", p.bomb_charges)
	cfg.set_value("player", "grenade_remaining", p.grenade_remaining)
	cfg.set_value("player", "grenade_cooldown", p.grenade_cooldown)

	cfg.set_value("boss", "active", gm._boss_active)
	if gm._boss and is_instance_valid(gm._boss):
		cfg.set_value("boss", "health", gm._boss.health)
		cfg.set_value("boss", "enraged", gm._boss._enraged)

	cfg.save(SAVE_PATH)


## Read the saved run back as a flat Dictionary (empty if none or malformed).
## Keys are prefixed with the section, e.g. "run_score", "player_health".
static func read_save() -> Dictionary:
	var out: Dictionary = {}
	if not has_save():
		return out
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return out
	for section in ["run", "player", "boss"]:
		for key in cfg.get_section_keys(section):
			out[section + "_" + key] = cfg.get_value(section, key, null)
	return out
