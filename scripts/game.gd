extends Node3D
## La Nuit des Citrouilles — gestionnaire de partie.
## Construit le monde, le joueur et l'interface, fait apparaître les ennemis et les objets,
## gère le cycle nuit → aube, la victoire et la défaite.

const InputsScript = preload("res://scripts/inputs.gd")
const WorldScript = preload("res://scripts/world.gd")
const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const HudScript = preload("res://scripts/hud.gd")

enum State { MENU, PLAYING, WON, LOST }

# --- Réglages de la partie (modifiables) ---
const NIGHT_DURATION := 300.0     # durée de la nuit en secondes (5 min = minuit → 6 h)
const HEAL_AMOUNT := 25
const FREEZE_SECONDS := 6.0
const PICKUP_RADIUS := 1.6
const SAVE_PATH := "user://nuit_des_citrouilles.cfg"

const ENEMY_TYPES := {
	"pumpkin": {
		"model": "pumpkin_orange_jackolantern.fbx", "height": 1.0, "radius": 0.45,
		"speed": 2.9, "damage": 8, "hover": 0.0, "hop": true, "hp": 2,
		"glow": Color(1.0, 0.42, 0.06), "glow_energy": 1.1, "xp": 10,
	},
	"skull": {
		"model": "skull.fbx", "height": 0.8, "radius": 0.45,
		"speed": 4.3, "damage": 10, "hover": 1.1, "hop": false, "hp": 1,
		"glow": Color(0.4, 1.0, 0.55), "glow_energy": 0.9, "xp": 15,
	},
	"ribcage": {
		"model": "ribcage.fbx", "height": 1.5, "radius": 0.5,
		"speed": 3.4, "damage": 18, "hover": 0.0, "hop": false, "hp": 4,
		"glow": Color(0.5, 0.9, 1.0), "glow_energy": 0.7, "xp": 25,
	},
	"bomber": {
		"model": "pumpkin_yellow_jackolantern.fbx", "height": 0.95, "radius": 0.45,
		"speed": 4.6, "damage": 6, "hover": 0.0, "hop": true, "hp": 1,
		"glow": Color(1.0, 0.75, 0.10), "glow_energy": 1.5, "xp": 15,
		"explode_radius": 2.7, "explode_damage": 22,
	},
	"ghost": {
		"model": "skull.fbx", "height": 0.85, "radius": 0.45,
		"speed": 3.1, "damage": 9, "hover": 1.6, "hop": false, "hp": 3,
		"glow": Color(0.75, 0.85, 1.0), "glow_energy": 1.2, "xp": 20,
		"ranged": true, "preferred_range": 9.0,
	},
	"totem": {
		"model": "post_skull.fbx", "height": 1.9, "radius": 0.5,
		"speed": 0.0, "damage": 12, "hover": 0.0, "hop": false, "hp": 5,
		"glow": Color(0.72, 0.42, 1.0), "glow_energy": 1.3, "xp": 30,
		"ranged": true, "preferred_range": 13.0, "stationary": true,
	},
	"brute": {
		"model": "pumpkin_orange.fbx", "height": 1.45, "radius": 0.65,
		"speed": 2.0, "damage": 20, "hover": 0.0, "hop": true, "hp": 10,
		"glow": Color(1.0, 0.30, 0.05), "glow_energy": 1.0, "xp": 40,
	},
	"boss": {
		"model": "pumpkin_orange_jackolantern.fbx", "height": 2.6, "radius": 0.95,
		"speed": 2.15, "damage": 25, "hover": 0.0, "hop": true, "hp": 30,
		"glow": Color(1.0, 0.45, 0.05), "glow_energy": 1.8, "xp": 150,
		"boss": true, "attack_range": 2.3,
	},
}

# [fraction de la nuit, message]
const MESSAGES := [
	[0.2, "01:12 — Des crânes flottent dans la brume…"],
	[0.45, "02:42 — Les ossements se lèvent !"],
	[0.7, "04:12 — Tiens bon, l'aube approche…"],
	[0.9, "05:24 — Plus que quelques minutes !"],
]

# Couleurs du ciel : nuit -> aube.
const NIGHT_TOP := Color(0.02, 0.03, 0.10)
const NIGHT_HORIZON := Color(0.08, 0.10, 0.22)
const DAWN_TOP := Color(0.35, 0.45, 0.75)
const DAWN_HORIZON := Color(1.0, 0.62, 0.38)
const MOON_COLOR := Color(0.55, 0.65, 1.0)
const SUN_COLOR := Color(1.0, 0.80, 0.60)
const NIGHT_FOG := Color(0.07, 0.09, 0.18)
const DAWN_FOG := Color(0.85, 0.60, 0.50)
const NIGHT_AMBIENT := Color(0.24, 0.29, 0.48)
const DAWN_AMBIENT := Color(0.65, 0.52, 0.52)

const SFX_NAMES := [
	"shoot", "reload", "empty", "enemy_hit", "enemy_die", "hurt", "pickup",
	"freeze", "roll", "bell", "win", "lose", "explode", "explode_big", "switch", "throw",
]
const AUDIO_DIR := "res://assets/audio/"
const CUSTOM_MUSIC_DIR := "res://AJOUTEZ_VOS_MUSIQUES_ICI/"
const CUSTOM_MUSIC_EXTS := ["mp3", "ogg", "wav"]

static var skip_menu := false     # vrai après un « rejouer » : on saute le menu

var state: int = State.MENU
var game_time := 0.0
var frozen := false               # lu par les ennemis
var frozen_until := 0.0

var world = null
var player = null
var hud = null
var pickups: Array = []

var best_time := 0.0
var nights_won := 0
var items_collected := 0
var kills := 0

var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _moon: DirectionalLight3D
var _fill: DirectionalLight3D   # lueur bleutee opposee a la lune (detache les silhouettes)
var _spawn_timer := 2.0
var _power_timer := 24.0          # delai avant le prochain pouvoir (bouclier, rage...)
var _boss_spawned := false
var endless := false              # mode infini apres l'aube
static var start_mode := "night"  # "night" ou "waves" (conserve au redemarrage)
var mode := "night"
var wave := 0
var _wave_to_spawn := 0
var _wave_spawned := 0
var _wave_spawn_t := 0.0
var _wave_rest_t := -1.0
var _wave_boss_spawned := false
var _hordes_done := {}
var xp := 0
var level := 1
var xp_next := 50
var total_kills_meta := 0         # statistiques cumulees (sauvegardees)
var achievements := {}            # id -> vrai, succes debloques (sauvegardes)
var _tuto_step := -1              # -1 : tutoriel inactif, sinon etape 0..4
var _tuto_start_pos := Vector3.ZERO
var _tuto_last_yaw := 0.0
var _tuto_yaw_total := 0.0
var _tuto_ammo_start := 0
var _heal_timer := 12.0
var _candle_timer := 25.0
var _msg_index := 0
var _end_timer := 0.0
var _end_shown := false
var _new_best := false
var _sfx := {}
var _music_night: AudioStreamPlayer
var _music_dawn: AudioStreamPlayer
var _custom_player: AudioStreamPlayer
var _custom_playlist: Array = []
var _custom_index := 0
var _heartbeat: AudioStreamPlayer


func _ready() -> void:
	InputsScript.setup()
	randomize()
	_load_best()
	_build_environment()

	world = WorldScript.new()
	add_child(world)
	world.build()

	player = PlayerScript.new()
	player.position = WorldScript.START_POS
	add_child(player)
	player.connect("died", _on_player_died)
	player.connect("damaged", _on_player_damaged)

	hud = HudScript.new()
	add_child(hud)
	player.connect("health_changed", Callable(hud, "set_health"))
	hud.connect("start_pressed", _on_start_pressed)
	hud.connect("restart_pressed", _on_restart_pressed)
	hud.connect("pause_pressed", _on_pause_pressed)
	hud.connect("menu_pressed", _on_menu_pressed)
	hud.connect("endless_pressed", _start_endless)
	hud.connect("waves_pressed", _on_waves_pressed)
	hud.bind_player(player)
	player.connect("health_changed", _on_health_changed)
	player.connect("ammo_changed", Callable(hud, "set_ammo"))
	player.sfx = Callable(self, "play_sfx")
	_setup_audio()
	player.emit_state()
	player.emit_weapon()
	hud.set_xp(level, xp, xp_next)
	_apply_time(0.0)
	Settings.changed.connect(_on_setting_changed)
	_apply_quality()

	if skip_menu:
		_start_game(start_mode)
	else:
		_show_menu()


func _process(delta: float) -> void:
	frozen = game_time < frozen_until
	match state:
		State.MENU:
			player.menu_orbit(delta)
		State.PLAYING:
			_update_playing(delta)
		State.LOST:
			_update_lost(delta)


# --------------------------------------------------------------------------- états

func _show_menu() -> void:
	state = State.MENU
	hud.set_crosshair(false)
	hud.set_playing_ui(false)
	player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_menu(_best_text())


func _start_game(mode_name: String = "night") -> void:
	mode = mode_name
	start_mode = mode_name
	state = State.PLAYING
	game_time = 0.0
	hud.hide_menu()
	hud.set_playing_ui(true, true)
	_capture_mouse(true)
	player.controls_enabled = true
	if mode == "waves":
		hud.show_message("MODE VAGUES — Survis aux 10 vagues !  ·  Difficulté : %s" % ["Histoire", "Normal", "Cauchemar"][Settings.difficulty], 4.0)
		_start_wave(1)
	else:
		hud.show_message("MINUIT — Survis jusqu'à l'aube  ·  Difficulté : %s" % ["Histoire", "Normal", "Cauchemar"][Settings.difficulty], 4.0)
		if not Settings.tutorial_seen:
			_start_tutorial()
	hud.show_hint()
	hud.set_crosshair(true)
	hud.set_kills(0)
	play_sfx("bell")
	_spawn_pickup("heal")
	_spawn_pickup("heal")


func _update_playing(delta: float) -> void:
	if _tuto_step >= 0:
		_update_tutorial()
	game_time += delta
	var f := clampf(game_time / NIGHT_DURATION, 0.0, 1.0)
	_apply_time(f)
	if endless:
		hud.set_clock("06:00 +" + _fmt(game_time - NIGHT_DURATION), 1.0)
	else:
		hud.set_clock(_clock_text(f), f)
	hud.set_freeze(maxf(frozen_until - game_time, 0.0))
	_check_messages(f)

	if mode == "waves" and not endless:
		_update_waves(delta)
		_update_pickup_timers(delta)
		_check_pickups()
		return

	# Hordes surprises : anneau de citrouilles explosives (nuit classique).
	if not endless:
		for hf in [0.3, 0.65]:
			if f >= hf and not bool(_hordes_done.get(hf, false)):
				_hordes_done[hf] = true
				hud.show_message("VAGUE DE CITROUILLES EXPLOSIVES !", 3.5)
				play_sfx("bell")
				for i in range(6):
					var b = _spawn_specific("bomber")
					var a := TAU * float(i) / 6.0
					b.position = player.global_position + Vector3(cos(a) * 11.0, 0.15, sin(a) * 11.0)

	# LE boss de fin de nuit, vers 05:24.
	if not _boss_spawned and f >= 0.88 and not endless:
		_boss_spawned = true
		_spawn_specific("boss")
		hud.show_message("LE ROI CITROUILLE SE LÈVE !", 4.0)
		play_sfx("bell")
		player.add_shake(0.7)

	# Apparition des ennemis : de plus en plus nombreux et rapides.
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		if get_tree().get_nodes_in_group("enemy").size() < _max_enemies(f):
			_spawn_enemy(f)
		_spawn_timer = lerpf(3.2, 0.8, f) * _diff([1.35, 1.0, 0.8])

	_update_pickup_timers(delta)
	_check_pickups()

	if game_time >= NIGHT_DURATION and not endless:
		_win()


## Minuteurs des objets (soins, bougies, pouvoirs, grenades) : nuit + mode Vagues.
func _update_pickup_timers(delta: float) -> void:
	_power_timer -= delta
	if _power_timer <= 0.0:
		_power_timer = randf_range(26.0, 36.0)
		var powers := ["shield", "rage", "swift", "grenade"]
		var pk := String(powers.pick_random())
		if _count_pickups(pk) == 0:
			_spawn_pickup(pk)
	_heal_timer -= delta
	if _heal_timer <= 0.0:
		if _count_pickups("heal") < 2:
			_spawn_pickup("heal")
		_heal_timer = randf_range(10.0, 14.0)
	_candle_timer -= delta
	if _candle_timer <= 0.0:
		if _count_pickups("candle") < 1:
			_spawn_pickup("candle")
		_candle_timer = randf_range(26.0, 34.0)


## Mode Vagues : 10 vagues croissantes, repos entre chacune, boss en vague 10.
func _start_wave(n: int) -> void:
	wave = n
	_wave_to_spawn = 5 + n * 4
	_wave_spawned = 0
	_wave_spawn_t = 0.5
	_wave_rest_t = -1.0
	_wave_boss_spawned = false
	hud.show_message("VAGUE %d / 10" % n, 3.0)
	play_sfx("bell")


func _update_waves(delta: float) -> void:
	if _wave_rest_t > 0.0:
		_wave_rest_t -= delta
		hud.set_clock("Repos : %s" % _fmt(ceilf(_wave_rest_t)), clampf(float(wave) / 10.0, 0.0, 1.0))
		_apply_time(clampf(float(wave) / 10.0, 0.0, 1.0))
		if _wave_rest_t <= 0.0:
			_start_wave(wave + 1)
		return
	var alive := get_tree().get_nodes_in_group("enemy").size()
	hud.set_clock("VAGUE %d/10 — %d restants" % [wave, _wave_to_spawn + alive], clampf(float(wave - 1) / 10.0 + (1.0 - float(_wave_to_spawn + alive) / float(maxi(5 + wave * 4, 1))) / 10.0, 0.0, 1.0))
	_apply_time(clampf(float(wave) / 10.0, 0.0, 1.0))
	if _wave_to_spawn > 0:
		_wave_spawn_t -= delta
		if _wave_spawn_t <= 0.0 and alive < mini(6 + wave, 14):
			_wave_spawn_t = 1.15
			_wave_to_spawn -= 1
			_wave_spawned += 1
			if wave >= 10 and not _wave_boss_spawned and _wave_spawned >= (5 + wave * 4) / 2:
				_wave_boss_spawned = true
				_spawn_specific("boss")
				hud.show_message("LE ROI CITROUILLE SE LÈVE !", 4.0)
				play_sfx("bell")
			else:
				_spawn_enemy(clampf(float(wave) / 10.0, 0.05, 1.0))
	elif alive == 0:
		if wave >= 10:
			_win()
		else:
			_wave_rest_t = 12.0
			player.heal(15)
			_spawn_pickup("grenade")
			hud.show_message("Vague %d terminée ! +15 PV — la prochaine arrive…" % wave, 4.0)
			play_sfx("win")


func _update_lost(delta: float) -> void:
	if _end_shown:
		return
	_end_timer -= delta
	if _end_timer <= 0.0:
		_end_shown = true
		hud.show_end({
			"win": false,
			"title": "Les ténèbres t'ont avalé",
			"subtitle": ("Mode Vagues : tu es tombé à la vague %d." % wave) if mode == "waves" else (("Mode infini : tu as tenu %s après l'aube." % _fmt(game_time - NIGHT_DURATION)) if endless else ("Encore %s avant l'aube." % _fmt(maxf(NIGHT_DURATION - game_time, 0.0)))),
			"time": _fmt(game_time),
			"clock": ("VAGUE %d/10" % wave) if mode == "waves" else _clock_text(game_time / NIGHT_DURATION),
			"accuracy": _accuracy_text(),
			"level": level,
			"endless_ok": false,
			"kills": kills,
			"items": items_collected,
			"best": ("Nouveau record  ·  " if _new_best else "") + _best_text(),
			"new_best": _new_best,
		})


func _win() -> void:
	var waves_win := mode == "waves"
	if waves_win:
		_unlock_achievement("vagues", "Vainqueur des 10 vagues")
	else:
		_unlock_achievement("survivant", "Survivant de la nuit")
	state = State.WON
	_new_best = best_time < NIGHT_DURATION
	if not waves_win:
		nights_won += 1
		best_time = NIGHT_DURATION
	_save_best()
	player.invulnerable = true
	player.controls_enabled = false
	_capture_mouse(false)
	hud.set_playing_ui(true, false)
	for e in get_tree().get_nodes_in_group("enemy"):
		e.vanish()
	hud.set_freeze(0.0)
	hud.set_crosshair(false)
	hud.set_clock("06:00", 1.0)
	play_sfx("win")
	_heartbeat.stop()
	_end_shown = true
	hud.show_end({
		"win": true,
		"title": "Les 10 vagues sont vaincues" if waves_win else "L'aube se lève",
		"subtitle": ("Tu as triomphé des 10 vagues avec %d points de vie." % player.health) if waves_win else ("Tu as tenu jusqu'au bout de la nuit avec %d points de vie." % player.health),
		"time": _fmt(game_time) if waves_win else _fmt(NIGHT_DURATION),
		"clock": "VAGUE 10/10" if waves_win else "06:00",
		"kills": kills,
		"items": items_collected,
		"accuracy": _accuracy_text(),
		"level": level,
		"endless_ok": not waves_win,
		"best": ("Vagues terminées" if waves_win else "Nuit survécue" + ("  ·  première victoire" if _new_best else "")) + "  ·  " + _best_text(),
		"new_best": _new_best,
	})


func _on_player_died() -> void:
	state = State.LOST
	_new_best = game_time > best_time
	if _new_best:
		best_time = game_time
	_save_best()
	_end_timer = 1.8
	_end_shown = false
	_capture_mouse(false)
	hud.set_playing_ui(true, false)
	hud.set_freeze(0.0)
	hud.set_crosshair(false)
	_heartbeat.stop()
	play_sfx("lose")


func _on_player_damaged() -> void:
	hud.flash_damage()


func _on_waves_pressed() -> void:
	if state == State.MENU:
		_start_game("waves")


func _on_start_pressed() -> void:
	if state == State.MENU:
		_start_game()
	elif (state == State.WON or state == State.LOST) and _end_shown:
		_restart()


func _on_restart_pressed() -> void:
	if get_tree().paused or ((state == State.WON or state == State.LOST) and _end_shown):
		_restart()


func _on_pause_pressed() -> void:
	if state != State.PLAYING:
		return
	var p := not get_tree().paused
	get_tree().paused = p
	hud.set_paused(p, "Il est %s  ·  %d monstres vaincus" % [_clock_text(game_time / NIGHT_DURATION), kills])
	hud.set_crosshair(not p)
	hud.set_playing_ui(true, not p)
	_capture_mouse(not p)


## Apres la victoire : on repart pour tenir le plus longtemps possible.
func _start_endless() -> void:
	if state != State.WON:
		return
	mode = "night"
	endless = true
	state = State.PLAYING
	_end_shown = false
	hud.hide_end()
	hud.set_playing_ui(true, true)
	hud.set_crosshair(true)
	player.invulnerable = false
	player.controls_enabled = true
	_capture_mouse(true)
	_spawn_timer = 1.0
	hud.show_message("MODE INFINI — Tiens le plus longtemps possible !", 4.0)
	play_sfx("bell")


func _on_menu_pressed() -> void:
	skip_menu = false
	get_tree().paused = false
	get_tree().reload_current_scene()


## La souris n'est capturée qu'avec le clavier : au tactile, il n'y a pas de pointeur à retenir.
func _capture_mouse(on: bool) -> void:
	if on and not Settings.is_touch():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _notification(what: int) -> void:
	# Le jeu se met en pause tout seul quand la fenêtre perd le focus (appel, changement d'appli).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if state == State.PLAYING and not get_tree().paused:
			_on_pause_pressed()


func _restart() -> void:
	skip_menu = true
	get_tree().paused = false
	get_tree().reload_current_scene()


# --------------------------------------------------------------------------- tutoriel

## Premier lancement : 5 gestes appris en jouant, monstres retardes pendant
## l'apprentissage. Entree (ou bouton A) pour passer.
func _start_tutorial() -> void:
	_tuto_step = 0
	_tuto_start_pos = player.global_position
	_tuto_last_yaw = player.pivot.rotation.y
	_tuto_yaw_total = 0.0
	_spawn_timer = maxf(_spawn_timer, 30.0)
	_show_tuto_step()


func _tuto_text() -> String:
	var touch := Settings.is_touch()
	match _tuto_step:
		0:
			return "TUTORIEL 1/5\nDéplace-toi : %s" % ("joystick à gauche" if touch else "ZQSD / flèches / stick gauche")
		1:
			return "TUTORIEL 2/5\nTourne la caméra : %s" % ("glisse un doigt à droite" if touch else "souris / stick droit")
		2:
			return "TUTORIEL 3/5\nVise et tire : %s" % ("bouton de tir à droite" if touch else "clic gauche / gâchette droite")
		3:
			return "TUTORIEL 4/5\nEsquive avec une roulade : %s" % ("bouton roulade" if touch else "ESPACE / bouton B")
		4:
			return "TUTORIEL 5/5\nRecharge : %s" % ("bouton recharger" if touch else "R / bouton X")
	return ""


func _show_tuto_step() -> void:
	_tuto_ammo_start = player.ammo
	var skip := "" if Settings.is_touch() else "\nEntrée pour passer"
	hud.show_message(_tuto_text() + skip, 30.0)


func _update_tutorial() -> void:
	var done := false
	match _tuto_step:
		0:
			var d := Vector2(player.global_position.x - _tuto_start_pos.x, player.global_position.z - _tuto_start_pos.z).length()
			done = d > 2.5
		1:
			var yaw: float = player.pivot.rotation.y
			_tuto_yaw_total += absf(angle_difference(_tuto_last_yaw, yaw))
			_tuto_last_yaw = yaw
			done = _tuto_yaw_total > 0.8
		2:
			done = player.ammo < _tuto_ammo_start
		3:
			done = bool(player.get("_rolling"))
		4:
			done = bool(player.reloading) or player.ammo >= player.magazine
	if done:
		_tuto_step += 1
		if _tuto_step > 4:
			_end_tutorial("Tutoriel terminé — survis jusqu'à l'aube !")
		else:
			_show_tuto_step()


func _end_tutorial(message: String) -> void:
	_tuto_step = -1
	Settings.set_value("tutorial_seen", true)
	hud.show_message(message, 4.0)


func _unhandled_input(event: InputEvent) -> void:
	if _tuto_step >= 0 and state == State.PLAYING and event.is_action_pressed("start"):
		_end_tutorial("Tutoriel passé — survis jusqu'à l'aube !")


# --------------------------------------------------------------------------- ennemis & objets

## Facteur de difficulte (reglee dans les Options) : monstres, degats, vitesse.
func _diff(table: Array) -> float:
	return float(table[clampi(Settings.difficulty, 0, 2)])


func _max_enemies(f: float) -> int:
	# Qualité Basse (téléphones) : 20 % de monstres en moins pour garder une image fluide.
	var perf := 0.8 if Settings.quality == 0 else 1.0
	return int(round((8.0 + f * 26.0) * _diff([0.65, 1.0, 1.35]) * perf))


func _pick_enemy_type(f: float) -> String:
	var pool: Array = ["pumpkin", "pumpkin", "pumpkin"]
	if f >= 0.2:
		pool.append_array(["skull", "skull"])
	if f >= 0.35:
		pool.append("bomber")            # citrouille explosive jaune
	if f >= 0.45:
		pool.append_array(["ribcage", "skull"])
	if f >= 0.4:
		pool.append("totem")             # totem maudit : tour tireuse immobile
	if f >= 0.5:
		pool.append("brute")             # grosse citrouille tanqueuse
	if f >= 0.55:
		pool.append("ghost")             # crane volant qui tire a distance
	if f >= 0.7:
		pool.append_array(["ribcage", "ribcage", "bomber"])
	return String(pool.pick_random())


func _spawn_enemy(f: float) -> void:
	_spawn_specific(_pick_enemy_type(f))


func _spawn_specific(kind: String) -> Node:
	var config: Dictionary = ENEMY_TYPES[kind].duplicate()
	config["kind"] = kind
	if endless:
		var bonus := 1.0 + minf((game_time - NIGHT_DURATION) / 60.0 * 0.05, 0.6)
		config["speed"] = float(config["speed"]) * bonus
	config["speed"] = float(config["speed"]) * _diff([0.85, 1.0, 1.15])
	config["damage"] = maxi(1, int(round(float(config["damage"]) * _diff([0.6, 1.0, 1.4]))))
	config["hp"] = maxi(1, int(round(float(config["hp"]) * _diff([0.75, 1.0, 1.3]))))
	# Monstres ELITES (dores) : plus gros, PV et XP triples, des la mi-nuit.
	var f_now := clampf(game_time / NIGHT_DURATION, 0.0, 1.0)
	if kind != "boss" and kind != "totem" and f_now >= 0.25 and randf() < 0.12:
		config["elite"] = true
		config["hp"] = int(config["hp"]) * 3
		config["xp"] = int(config.get("xp", 10)) * 3
		config["glow"] = Color(1.0, 0.85, 0.30)
		config["glow_energy"] = 1.6
	var enemy := EnemyScript.new()
	enemy.setup(config, self, player)
	if bool(config.get("elite", false)):
		enemy.scale = Vector3.ONE * 1.3
	var p: Vector3 = world.random_open_point(player.global_position, 18.0, 1.2)
	var hover := float(config["hover"])
	p.y = hover if hover > 0.0 else 0.15
	enemy.position = p
	add_child(enemy)
	return enemy


func _spawn_pickup(kind: String) -> void:
	var p: Vector3 = world.random_open_point(player.global_position, 8.0, 1.0)
	var pk := PickupScript.new()
	pk.setup(kind)
	pk.position = p
	add_child(pk)
	pickups.append(pk)


func _count_pickups(kind: String) -> int:
	var n := 0
	for pk in pickups:
		if is_instance_valid(pk) and pk.kind == kind and not pk.collected:
			n += 1
	return n


func _check_pickups() -> void:
	var pp: Vector3 = player.global_position
	for pk in pickups.duplicate():
		if not is_instance_valid(pk):
			pickups.erase(pk)
			continue
		var d := Vector2(pk.global_position.x - pp.x, pk.global_position.z - pp.z).length()
		if d < PICKUP_RADIUS:
			_collect(pk)


func _collect(pk) -> void:
	if pk.kind == "heal":
		if player.health >= player.max_health:
			return   # inutile à pleine santé : on le laisse pour plus tard
		player.heal(HEAL_AMOUNT)
		hud.show_message("+%d PV — citrouille croquée" % HEAL_AMOUNT, 2.0)
		play_sfx("pickup")
	elif pk.kind == "shield":
		player.grant_shield(50, 25.0)
		hud.show_message("Bouclier spectral : +50 d'armure (25 s)", 2.5)
		play_sfx("pickup")
	elif pk.kind == "rage":
		player.grant_power("rage", 12.0)
		hud.show_message("RAGE ! Dégâts doublés pendant 12 s", 2.5)
		play_sfx("pickup")
	elif pk.kind == "grenade":
		player.grenades = mini(player.grenades + 2, 9)
		player.grenade_changed.emit(player.grenades)
		hud.show_message("+2 grenades (touche G pour lancer)", 2.5)
		play_sfx("pickup")
	elif pk.kind == "swift":
		player.grant_power("swift", 15.0)
		hud.show_message("Rapidité : +25 % de vitesse pendant 15 s", 2.5)
		play_sfx("pickup")
	else:
		frozen_until = game_time + FREEZE_SECONDS
		hud.show_message("Bougies sacrées ! Les monstres sont figés", 2.5)
		play_sfx("freeze")
	items_collected += 1
	pickups.erase(pk)
	pk.collect()


# --------------------------------------------------------------------------- audio

func _setup_audio() -> void:
	for n in SFX_NAMES:
		var path := AUDIO_DIR + String(n) + ".wav"
		if ResourceLoader.exists(path):
			_sfx[n] = load(path)
	# Musiques personnelles : si le joueur a colle ses chansons dans
	# AJOUTEZ_VOS_MUSIQUES_ICI/, elles remplacent les musiques d'ambiance.
	if not _setup_custom_music():
		_music_night = _make_loop_player("music_night", -6.0)
		_music_dawn = _make_loop_player("music_dawn", -60.0)
		_music_night.play()
		_music_dawn.play()
	_heartbeat = _make_loop_player("heartbeat", -4.0)


## Cherche les chansons du joueur dans CUSTOM_MUSIC_DIR (par ordre alphabetique)
## et les joue en boucle, les unes apres les autres. Renvoie faux s'il n'y en a pas.
func _setup_custom_music() -> bool:
	var dir := DirAccess.open(CUSTOM_MUSIC_DIR)
	if dir == null:
		return false
	var files: Array = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and not fname.begins_with("."):
			if fname.get_extension().to_lower() in CUSTOM_MUSIC_EXTS:
				files.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	files.sort()
	for f in files:
		var path := CUSTOM_MUSIC_DIR + String(f)
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is AudioStream:
				if res is AudioStreamMP3:
					(res as AudioStreamMP3).loop = false
				elif res is AudioStreamOggVorbis:
					(res as AudioStreamOggVorbis).loop = false
				elif res is AudioStreamWAV:
					(res as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
				_custom_playlist.append(res)
	if _custom_playlist.is_empty():
		return false
	_custom_player = AudioStreamPlayer.new()
	_custom_player.bus = "Music"
	_custom_player.volume_db = -6.0
	_custom_player.finished.connect(_on_custom_track_finished)
	add_child(_custom_player)
	_custom_index = 0
	_custom_player.stream = _custom_playlist[0]
	_custom_player.play()
	print("Musiques personnelles : ", _custom_playlist.size(), " chanson(s) trouvee(s) dans ", CUSTOM_MUSIC_DIR)
	return true


func _on_custom_track_finished() -> void:
	if _custom_playlist.is_empty() or _custom_player == null:
		return
	_custom_index = (_custom_index + 1) % _custom_playlist.size()
	_custom_player.stream = _custom_playlist[_custom_index]
	_custom_player.play()


func _make_loop_player(file: String, volume_db: float) -> AudioStreamPlayer:
	var player_node := AudioStreamPlayer.new()
	player_node.bus = "Music" if file.begins_with("music") else "SFX"
	var path := AUDIO_DIR + file + ".wav"
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is AudioStreamWAV:
			var wav := (res as AudioStreamWAV).duplicate() as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.data.size() / 2.0)   # 16 bits mono
			player_node.stream = wav
	player_node.volume_db = volume_db
	add_child(player_node)
	return player_node


## Joue un effet sonore (appelé aussi par le joueur et les ennemis).
func play_sfx(sfx_name: String) -> void:
	if not _sfx.has(sfx_name):
		return
	var sp := AudioStreamPlayer.new()
	sp.stream = _sfx[sfx_name]
	sp.bus = "SFX"
	sp.volume_db = -4.0
	if sfx_name == "bell":
		sp.volume_db = -10.0
	add_child(sp)
	sp.finished.connect(sp.queue_free)
	sp.play()


func register_kill(enemy = null) -> void:
	kills += 1
	total_kills_meta += 1
	hud.set_kills(kills)
	if total_kills_meta >= 1:
		_unlock_achievement("premier_sang", "Premier sang")
	if total_kills_meta >= 50:
		_unlock_achievement("chasseur", "Chasseur de monstres (50 au total)")
	if enemy != null:
		_gain_xp(int(enemy.get("xp_value")))
		if bool(enemy.get("is_boss")):
			_unlock_achievement("roi_tombe", "Le Roi Citrouille est tombé")
			_boss_hitstop()
			_spawn_pickup("shield")
			_spawn_pickup("heal")
		elif randf() < 0.18:
			_spawn_pickup("heal" if randf() < 0.6 else String(["rage", "swift"].pick_random()))


func _gain_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = 50 + (level - 1) * 40
		if level >= 5:
			_unlock_achievement("niveau5", "Niveau 5 atteint")
		_level_up()
	hud.set_xp(level, xp, xp_next)


func _level_up() -> void:
	# Aucun panneau d'amelioration : le jeu ne s'arrete JAMAIS pendant l'action.
	# La montee de niveau debloque les armes et redonne un peu de vie,
	# annoncee par un simple message qui ne bloque rien.
	play_sfx("pickup")
	player.heal(10)
	var msg := "NIVEAU %d ! +10 PV" % level
	for i in range(player.WEAPONS.size()):
		var w: Dictionary = player.WEAPONS[i]
		if level >= int(w["unlock"]) and not bool(player.unlocked_weapons[i]):
			if player.unlock_weapon(String(w["id"])):
				msg = "NIVEAU %d — NOUVELLE ARME : %s ! (touches 1-4 / E)" % [level, String(w["name"])]
	hud.show_message(msg, 3.5)


func _accuracy_text() -> String:
	if player == null or player.shots_fired <= 0:
		return "—"
	return "%d %%" % int(round(100.0 * float(player.shots_hit) / float(player.shots_fired)))


func _boss_hitstop() -> void:
	Engine.time_scale = 0.25
	player.add_shake(0.9)
	await get_tree().create_timer(0.09, true, false, true).timeout
	Engine.time_scale = 1.0


func _unlock_achievement(id: String, label: String) -> void:
	if bool(achievements.get(id, false)):
		return
	achievements[id] = true
	_save_best()
	hud.show_message("SUCCÈS DÉBLOQUÉ — " + label, 3.5)
	play_sfx("win")


func _on_health_changed(current: int, maximum: int) -> void:
	# Battement de coeur quand la vie est basse.
	var low := current > 0 and float(current) / float(maximum) <= 0.3
	if low and not _heartbeat.playing:
		_heartbeat.play()
	elif not low and _heartbeat.playing:
		_heartbeat.stop()


# --------------------------------------------------------------------------- réglages graphiques

func _on_setting_changed(key: String) -> void:
	if key == "quality":
		_apply_quality()
	elif key == "controls":
		InputsScript.apply_scheme()


## 0 = basse (téléphones), 1 = moyenne, 2 = haute.
func _apply_quality() -> void:
	var q: int = Settings.quality
	var vp := get_viewport()
	_moon.shadow_enabled = q >= 1
	_moon.directional_shadow_max_distance = 40.0 if q == 1 else 70.0
	_moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if q >= 2 else DirectionalLight3D.SHADOW_ORTHOGONAL
	_env.glow_enabled = q >= 1
	_env.ssao_enabled = q >= 1            # les props "posent" au sol
	_env.sdfgi_enabled = q >= 2           # lumiere rebondie douce (PC)
	_env.volumetric_fog_enabled = q >= 2  # halos des lanternes dans la brume
	_env.fog_enabled = true
	vp.msaa_3d = Viewport.MSAA_2X if q >= 2 else Viewport.MSAA_DISABLED
	vp.scaling_3d_scale = [0.7, 0.85, 1.0][q]
	vp.use_debanding = q >= 1


# --------------------------------------------------------------------------- ciel & horloge

func _build_environment() -> void:
	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sky_curve = 0.15
	var sky := Sky.new()
	sky.sky_material = _sky_mat

	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = NIGHT_AMBIENT
	_env.ambient_light_energy = 0.6
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 1.06
	# Etalonnage leger : nuit plus profonde, couleurs un peu plus riches.
	_env.adjustment_enabled = true
	_env.adjustment_brightness = 1.02
	_env.adjustment_contrast = 1.08
	_env.adjustment_saturation = 1.12
	_env.fog_enabled = true
	_env.fog_light_color = NIGHT_FOG
	_env.fog_density = 0.014
	_env.fog_sky_affect = 0.35
	# Brume basse : plus epaisse pres du sol que dans le ciel.
	_env.fog_height = 7.0
	_env.fog_height_density = 0.035
	_env.glow_enabled = true
	_env.glow_intensity = 0.8
	_env.glow_strength = 1.1
	_env.glow_bloom = 0.12
	# Brouillard volumetrique (active seulement en qualite haute par
	# _apply_quality) : les lanternes et la lune y dessinent des halos.
	_env.volumetric_fog_albedo = Color(0.55, 0.65, 0.90)
	_env.volumetric_fog_emission = Color(0.05, 0.07, 0.14)
	_env.volumetric_fog_emission_energy = 0.4
	_env.volumetric_fog_density = 0.010
	_env.volumetric_fog_sky_affect = 0.2
	_env.volumetric_fog_length = 90.0
	# Occlusion ambiante (contact des props au sol) : reglages, activation
	# selon la qualite dans _apply_quality.
	_env.ssao_radius = 1.4
	_env.ssao_intensity = 1.8
	_env.ssao_power = 1.5

	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)

	_moon = DirectionalLight3D.new()
	_moon.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
	_moon.light_color = MOON_COLOR
	_moon.light_energy = 0.65
	_moon.shadow_enabled = true
	_moon.directional_shadow_max_distance = 70.0
	_moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_moon.shadow_normal_bias = 0.5   # evite les ombres "granuleuses" sur les modeles low-poly
	_moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(_moon)

	# Contre-jour froid tres faible, sans ombres : les silhouettes (joueur,
	# monstres, arbres) se detachent du fond au lieu d'etre toutes noires.
	_fill = DirectionalLight3D.new()
	_fill.rotation_degrees = Vector3(-35.0, -145.0, 0.0)
	_fill.light_color = Color(0.35, 0.45, 0.75)
	_fill.light_energy = 0.18
	_fill.shadow_enabled = false
	_fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(_fill)

	_build_moon_disc()


## f : avancement de la nuit (0 = minuit, 1 = 6 h). La lumière change surtout dans le dernier tiers.
## Lune visible : un disque pale (texture generee, crateres simples) place
## dans la direction d'ou vient la lumiere de lune, + un halo doux derriere.
## Materiaux sans brouillard : a 180 m, la lune resterait invisible sinon.
func _build_moon_disc() -> void:
	var dir: Vector3 = _moon.transform.basis.z.normalized()
	var pos := dir * 180.0
	pos.y = maxf(pos.y, 70.0)
	var halo := _moon_quad(64.0, _halo_texture(), Color(0.55, 0.65, 1.0, 0.35))
	halo.position = pos + dir * 3.0
	add_child(halo)
	var disc := _moon_quad(19.0, _moon_texture(), Color(0.95, 0.97, 1.0, 1.0))
	disc.position = pos
	add_child(disc)


func _moon_quad(size: float, tex: Texture2D, tint: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	mi.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.albedo_color = tint
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.disable_fog = true   # sinon la lune, a 180 m, serait noyee dans le brouillard
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _moon_texture() -> Texture2D:
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var craters := [Vector3(0.38, 0.34, 0.10), Vector3(0.60, 0.52, 0.14), Vector3(0.44, 0.66, 0.08),
			Vector3(0.66, 0.30, 0.06), Vector3(0.30, 0.55, 0.05), Vector3(0.55, 0.72, 0.05)]
	for y in range(s):
		for x in range(s):
			var d := Vector2(x - s * 0.5, y - s * 0.5).length() / (s * 0.46)
			if d > 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var base := 0.92 - d * 0.18
			var col := Color(base * 0.92, base * 0.95, base * 1.05, 1.0)
			for c in craters:
				var cd := Vector2(x / float(s) - c.x, y / float(s) - c.y).length()
				if cd < c.z:
					col = col.lerp(Color(0.55, 0.58, 0.68, 1.0), 0.45 * (1.0 - cd / c.z))
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _halo_texture() -> Texture2D:
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in range(s):
		for x in range(s):
			var d := clampf(Vector2(x - s * 0.5, y - s * 0.5).length() / (s * 0.5), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, pow(1.0 - d, 2.4)))
	return ImageTexture.create_from_image(img)


func _apply_time(f: float) -> void:
	var d := smoothstep(0.6, 1.0, f)
	var top := NIGHT_TOP.lerp(DAWN_TOP, d)
	var horizon := NIGHT_HORIZON.lerp(DAWN_HORIZON, d)
	_sky_mat.sky_top_color = top
	_sky_mat.sky_horizon_color = horizon
	_sky_mat.ground_horizon_color = horizon
	_sky_mat.ground_bottom_color = NIGHT_HORIZON.lerp(DAWN_FOG, d)
	_env.fog_light_color = NIGHT_FOG.lerp(DAWN_FOG, d)
	_env.fog_density = lerpf(0.02, 0.009, d)
	_env.ambient_light_color = NIGHT_AMBIENT.lerp(DAWN_AMBIENT, d)
	_env.ambient_light_energy = lerpf(0.6, 1.0, d)
	_moon.light_color = MOON_COLOR.lerp(SUN_COLOR, d)
	_moon.light_energy = lerpf(0.6, 1.3, d)
	_moon.rotation_degrees.x = lerpf(-48.0, -16.0, d)
	if _music_night != null:
		_music_night.volume_db = linear_to_db(maxf(1.0 - d, 0.001)) - 6.0
		_music_dawn.volume_db = linear_to_db(maxf(d, 0.001)) - 6.0


func _clock_text(f: float) -> String:
	var minutes := int(clampf(f, 0.0, 1.0) * 360.0)
	return "%02d:%02d" % [floori(minutes / 60.0), minutes % 60]


func _fmt(seconds: float) -> String:
	var s := int(seconds)
	return "%02d:%02d" % [floori(s / 60.0), s % 60]


func _check_messages(f: float) -> void:
	if _msg_index >= MESSAGES.size():
		return
	var entry: Array = MESSAGES[_msg_index]
	if f >= float(entry[0]):
		hud.show_message(String(entry[1]), 4.0)
		play_sfx("bell")
		_msg_index += 1


# --------------------------------------------------------------------------- score

func _best_text() -> String:
	if best_time <= 0.0:
		return "Aucune partie jouée"
	if nights_won <= 0:
		return "Meilleur temps %s" % _fmt(best_time)
	var plural := "s" if nights_won > 1 else ""
	return "Meilleur temps %s  ·  %d nuit%s survécue%s" % [_fmt(best_time), nights_won, plural, plural]


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_time = float(cfg.get_value("score", "best_time", 0.0))
		nights_won = int(cfg.get_value("score", "nights_won", 0))
		total_kills_meta = int(cfg.get_value("meta", "total_kills", 0))
		for id in ["premier_sang", "chasseur", "roi_tombe", "niveau5", "survivant", "vagues"]:
			achievements[id] = bool(cfg.get_value("succes", id, false))


func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)   # on conserve le reste du fichier
	cfg.set_value("score", "best_time", best_time)
	cfg.set_value("score", "nights_won", nights_won)
	cfg.set_value("meta", "total_kills", total_kills_meta)
	for id in achievements:
		cfg.set_value("succes", id, bool(achievements[id]))
	cfg.save(SAVE_PATH)
