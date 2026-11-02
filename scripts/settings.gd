extends Node
## Réglages du joueur (autoload « Settings »).
## Sauvegardés dans user://settings.cfg, appliqués au démarrage et à chaque changement.

signal changed(key: String)

const PATH := "user://settings.cfg"
const KEYS := ["master", "music", "sfx", "sensitivity", "aim_assist", "vibration",
		"quality", "controls", "show_fps", "fullscreen",
		"difficulty", "text_scale", "reduce_flashes", "auto_shoot", "tutorial_seen"]

var master := 0.9
var music := 0.8
var sfx := 0.9
var sensitivity := 1.0      # multiplicateur de la caméra (souris et tactile)
var aim_assist := true      # tactile : le tir se cale sur le monstre le plus proche du viseur
var vibration := true       # tactile : vibre quand on est touché
var quality := 2            # 0 basse, 1 moyenne, 2 haute
var controls := 0           # 0 auto, 1 tactile, 2 clavier + souris
var show_fps := false
var fullscreen := false
var difficulty := 1         # 0 Histoire (facile), 1 Normal, 2 Cauchemar
var text_scale := 1.0       # taille des textes (0,85 a 1,30), appliquee au lancement
var reduce_flashes := false # reduit vignette de degats et flash de tir
var auto_shoot := false     # tire tout seul quand une cible est verrouillee (aide a la visee requise)
var tutorial_seen := false  # le tutoriel interactif ne joue qu'une fois


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	quality = 0 if is_mobile_device() else 2
	_load()
	_apply_audio()
	if fullscreen and can_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


## Vrai sur téléphone / tablette (application ou navigateur mobile).
func is_mobile_device() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


## Vrai si on affiche les commandes tactiles.
func is_touch() -> bool:
	return controls == 1 or (controls == 0 and is_mobile_device())


func can_quit() -> bool:
	return not OS.has_feature("web") and not is_mobile_device()


func can_fullscreen() -> bool:
	return not is_mobile_device()


func set_value(key: String, value, persist: bool = true) -> void:
	if not KEYS.has(key):
		return
	set(key, value)
	if key in ["master", "music", "sfx"]:
		_apply_audio()
	elif key == "fullscreen" and can_fullscreen():
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if persist:
		_save()
	changed.emit(key)


## Écrit les réglages sur le disque (appelé quand on relâche un curseur).
func flush() -> void:
	_save()


## Marges de sécurité (encoche, coins arrondis) converties en unités de l'interface.
## x = gauche, y = haut, z = droite, w = bas.
func safe_insets(viewport: Viewport) -> Vector4:
	if not is_mobile_device():
		return Vector4.ZERO
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0.0 or win.y <= 0.0:
		return Vector4.ZERO
	var area := Rect2(DisplayServer.get_display_safe_area())
	var screen := Vector2(DisplayServer.screen_get_size())
	if screen.x <= 0.0 or area.size.x <= 0.0:
		return Vector4.ZERO
	var k := viewport.get_visible_rect().size.x / screen.x
	var left := maxf(area.position.x, 0.0) * k
	var top := maxf(area.position.y, 0.0) * k
	var right := maxf(screen.x - area.end.x, 0.0) * k
	var bottom := maxf(screen.y - area.end.y, 0.0) * k
	return Vector4(left, top, right, bottom)


# --------------------------------------------------------------------------- interne

func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func _apply_audio() -> void:
	_set_bus("Master", master)
	_set_bus("Music", music)
	_set_bus("SFX", sfx)


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in KEYS:
		if cfg.has_section_key("settings", key):
			set(key, cfg.get_value("settings", key))
	quality = clampi(int(quality), 0, 2)
	controls = clampi(int(controls), 0, 2)
	difficulty = clampi(int(difficulty), 0, 2)
	text_scale = clampf(float(text_scale), 0.85, 1.30)


func _save() -> void:
	var cfg := ConfigFile.new()
	for key in KEYS:
		cfg.set_value("settings", key, get(key))
	cfg.save(PATH)
