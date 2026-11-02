extends RefCounted
## Crée les actions clavier au démarrage.
## On utilise les touches PHYSIQUES : la touche W d'un clavier QWERTY est au même
## endroit que le Z d'un clavier AZERTY, donc ZQSD et WASD marchent tous les deux.

static func setup() -> void:
	var map := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT],
		"roll": [KEY_SPACE],
		"start": [KEY_ENTER, KEY_KP_ENTER],
		"restart": [KEY_R],
		"reload": [KEY_R],
		"pause": [KEY_ESCAPE, KEY_P],
		"weapon_1": [KEY_1],
		"weapon_2": [KEY_2],
		"weapon_3": [KEY_3],
		"weapon_4": [KEY_4],
		"weapon_next": [KEY_E],
		"grenade": [KEY_G],
	}
	for action in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.1)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)

	# Changement d'arme a la molette de la souris.
	for a in ["weapon_next_wheel", "weapon_prev_wheel"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
	var wd := InputEventMouseButton.new()
	wd.button_index = MOUSE_BUTTON_WHEEL_DOWN
	InputMap.action_add_event("weapon_next_wheel", wd)
	var wu := InputEventMouseButton.new()
	wu.button_index = MOUSE_BUTTON_WHEEL_UP
	InputMap.action_add_event("weapon_prev_wheel", wu)

	# Tir : clic gauche de la souris. En mode tactile, un doigt posé n'est pas un clic :
	# le tir vient alors uniquement du bouton à l'écran.
	if not InputMap.has_action("shoot"):
		InputMap.add_action("shoot")
	_add_gamepad()
	apply_scheme()


## Manette (Xbox / PlayStation / compatibles) : toutes les actions du jeu.
## Stick gauche = se deplacer, stick droit = camera, RT/RB = tirer,
## B = roulade, X = recharger, LB = courir, Start = pause, A = valider.
static func _add_gamepad() -> void:
	var buttons := {
		"sprint": [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_LEFT_STICK],
		"roll": [JOY_BUTTON_B],
		"reload": [JOY_BUTTON_X],
		"pause": [JOY_BUTTON_START],
		"start": [JOY_BUTTON_A],
		"restart": [JOY_BUTTON_Y],
		"shoot": [JOY_BUTTON_RIGHT_SHOULDER],
		"weapon_next": [JOY_BUTTON_DPAD_RIGHT],
		"weapon_prev": [JOY_BUTTON_DPAD_LEFT],
		"grenade": [JOY_BUTTON_DPAD_DOWN],
	}
	for action in buttons:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for b in buttons[action]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = b
			InputMap.action_add_event(action, ev)
	var motions := {
		"move_left": [[JOY_AXIS_LEFT_X, -1.0]],
		"move_right": [[JOY_AXIS_LEFT_X, 1.0]],
		"move_forward": [[JOY_AXIS_LEFT_Y, -1.0]],
		"move_back": [[JOY_AXIS_LEFT_Y, 1.0]],
		"shoot": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]],
		"look_left": [[JOY_AXIS_RIGHT_X, -1.0]],
		"look_right": [[JOY_AXIS_RIGHT_X, 1.0]],
		"look_up": [[JOY_AXIS_RIGHT_Y, -1.0]],
		"look_down": [[JOY_AXIS_RIGHT_Y, 1.0]],
	}
	for action in motions:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.22)
		for m in motions[action]:
			var ev := InputEventJoypadMotion.new()
			ev.axis = m[0]
			ev.axis_value = m[1]
			InputMap.action_add_event(action, ev)


## Ajoute ou retire le clic de souris de l'action « shoot » selon le schéma de commandes.
static func apply_scheme() -> void:
	if not InputMap.has_action("shoot"):
		return
	for ev in InputMap.action_get_events("shoot"):
		if ev is InputEventMouseButton:
			InputMap.action_erase_event("shoot", ev)
	if not Settings.is_touch():
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("shoot", mb)
