extends Control
## Commandes tactiles : joystick flottant à gauche, caméra au doigt à droite,
## boutons de tir, de roulade et de rechargement. Les doigts sont suivis un par un (multitouch).
## Le joueur ne sait rien du tactile : on simule les mêmes actions que le clavier.

signal pause_requested

const UI = preload("res://scripts/ui_theme.gd")

const STICK_RADIUS := 100.0
const KNOB_RADIUS := 44.0
const STICK_ZONE := 0.45          # part de la largeur de l'écran réservée au joystick
const DEAD_ZONE := 0.12
const SPRINT_AT := 0.93           # on court quand le joystick est poussé à fond
const LOOK_FACTOR := 1.5

var player = null

var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _look_id := -1
var _finger_button := {}          # index du doigt -> nom du bouton tenu
var _buttons := {}                # nom -> {center, radius, icon, action, hold}
var _pause_rect := Rect2()
var _pause_down := false
var _held := {}                   # actions actuellement enfoncées par nous


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resized.connect(_layout)
	_layout()


func set_active(on: bool) -> void:
	if visible == on:
		return
	visible = on
	if not on:
		_release_all()
	queue_redraw()


func _exit_tree() -> void:
	_release_all()


# --------------------------------------------------------------------------- disposition

func _layout() -> void:
	var ins := Settings.safe_insets(get_viewport())
	var right := size.x - ins.z
	var bottom := size.y - ins.w
	_buttons = {
		"fire": {"center": Vector2(right - 140.0, bottom - 130.0), "radius": 66.0, "icon": "crosshair", "action": "shoot", "hold": true},
		"roll": {"center": Vector2(right - 298.0, bottom - 92.0), "radius": 46.0, "icon": "refresh-cw", "action": "roll", "hold": false},
		"reload": {"center": Vector2(right - 258.0, bottom - 214.0), "radius": 40.0, "icon": "rotate-ccw", "action": "reload", "hold": false},
		"weapon": {"center": Vector2(right - 356.0, bottom - 190.0), "radius": 40.0, "icon": "zap", "action": "weapon_next", "hold": false},
		"grenade": {"center": Vector2(right - 140.0, bottom - 300.0), "radius": 44.0, "icon": "flame", "action": "grenade", "hold": false},
	}
	_pause_rect = Rect2(right - 76.0, ins.y + 14.0, 60.0, 60.0)
	queue_redraw()


# --------------------------------------------------------------------------- entrées

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touch_down(t.index, t.position)
		else:
			_touch_up(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_touch_drag(d.index, d.position, d.relative)


func _touch_down(index: int, pos: Vector2) -> void:
	if _pause_rect.grow(14.0).has_point(pos):
		_pause_down = true
		pause_requested.emit()
		queue_redraw()
		get_viewport().set_input_as_handled()
		return
	for key in _buttons:
		var b: Dictionary = _buttons[key]
		if pos.distance_to(b["center"]) <= float(b["radius"]) * 1.2:
			_finger_button[index] = key
			_press(String(b["action"]))
			queue_redraw()
			get_viewport().set_input_as_handled()
			return
	if _stick_id == -1 and pos.x < size.x * STICK_ZONE:
		_stick_id = index
		_stick_origin = pos
		_stick_vec = Vector2.ZERO
		queue_redraw()
	elif _look_id == -1:
		_look_id = index
	get_viewport().set_input_as_handled()


func _touch_up(index: int) -> void:
	if _finger_button.has(index):
		var b: Dictionary = _buttons[_finger_button[index]]
		_finger_button.erase(index)
		_release(String(b["action"]), true)
	if index == _stick_id:
		_stick_id = -1
		_stick_vec = Vector2.ZERO
		_apply_stick()
	if index == _look_id:
		_look_id = -1
	_pause_down = false
	queue_redraw()


func _touch_drag(index: int, pos: Vector2, relative: Vector2) -> void:
	if index == _stick_id:
		var offset := (pos - _stick_origin)
		_stick_vec = offset.limit_length(STICK_RADIUS) / STICK_RADIUS
		_apply_stick()
		queue_redraw()
	elif index == _look_id or _finger_button.get(index, "") == "fire":
		if player != null and is_instance_valid(player):
			player.look_delta(relative * LOOK_FACTOR)


# --------------------------------------------------------------------------- actions simulées

func _apply_stick() -> void:
	var v := _stick_vec
	if v.length() < DEAD_ZONE:
		v = Vector2.ZERO
	_set_strength("move_left", maxf(-v.x, 0.0))
	_set_strength("move_right", maxf(v.x, 0.0))
	_set_strength("move_forward", maxf(-v.y, 0.0))
	_set_strength("move_back", maxf(v.y, 0.0))
	if v.length() >= SPRINT_AT:
		_press("sprint")
	else:
		_release("sprint", false)


func _set_strength(action: String, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
		_held[action] = true
	else:
		_release(action, false)


func _press(action: String) -> void:
	Input.action_press(action)
	_held[action] = true


## Une impulsion très brève peut passer entre deux images physiques : on garde l'action
## enfoncée un court instant pour que le joueur la voie.
func _release(action: String, delayed: bool) -> void:
	if not _held.has(action):
		return
	_held.erase(action)
	if delayed:
		get_tree().create_timer(0.12).timeout.connect(func(): Input.action_release(action))
	else:
		Input.action_release(action)


func _release_all() -> void:
	for action in _held.keys():
		Input.action_release(action)
	_held.clear()
	_stick_id = -1
	_look_id = -1
	_stick_vec = Vector2.ZERO
	_finger_button.clear()


# --------------------------------------------------------------------------- dessin

func _draw() -> void:
	if not visible:
		return
	var white := Color(1, 1, 1, 0.3)

	# Joystick : discret au repos, complet quand on le tient.
	if _stick_id != -1:
		draw_circle(_stick_origin, STICK_RADIUS, Color(1, 1, 1, 0.06))
		draw_arc(_stick_origin, STICK_RADIUS, 0.0, TAU, 64, white, 2.0, true)
		var knob := _stick_origin + _stick_vec * STICK_RADIUS
		draw_circle(knob, KNOB_RADIUS, Color(1, 1, 1, 0.22))
		draw_arc(knob, KNOB_RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.55), 2.0, true)
	else:
		var rest := Vector2(size.x * 0.16, size.y - 150.0)
		draw_arc(rest, STICK_RADIUS * 0.8, 0.0, TAU, 64, Color(1, 1, 1, 0.12), 2.0, true)

	# Boutons d'action
	for key in _buttons:
		var b: Dictionary = _buttons[key]
		var c: Vector2 = b["center"]
		var r: float = b["radius"]
		var down := _finger_button.values().has(key)
		var is_fire: bool = key == "fire"
		var fill := Color(0.03, 0.045, 0.1, 0.5)
		if down:
			fill = Color(UI.ACCENT.r, UI.ACCENT.g, UI.ACCENT.b, 0.45) if is_fire else Color(1, 1, 1, 0.22)
		draw_circle(c, r, fill)
		var edge := Color(UI.ACCENT.r, UI.ACCENT.g, UI.ACCENT.b, 0.85) if is_fire else Color(1, 1, 1, 0.4)
		draw_arc(c, r, 0.0, TAU, 56, edge, 2.5 if is_fire else 2.0, true)
		var tex := UI.icon(String(b["icon"]))
		if tex != null:
			var s := r * 0.95
			var tint := UI.ACCENT_HOVER if is_fire else Color(1, 1, 1, 0.9)
			draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, tint)

	# Bouton pause
	var pc := _pause_rect.get_center()
	draw_circle(pc, _pause_rect.size.x * 0.5, Color(0.03, 0.045, 0.1, 0.55) if not _pause_down else Color(1, 1, 1, 0.22))
	draw_arc(pc, _pause_rect.size.x * 0.5, 0.0, TAU, 40, Color(1, 1, 1, 0.35), 2.0, true)
	var pt := UI.icon("pause")
	if pt != null:
		var ps := _pause_rect.size.x * 0.5
		draw_texture_rect(pt, Rect2(pc - Vector2(ps, ps) * 0.5, Vector2(ps, ps)), false, Color(1, 1, 1, 0.9))
