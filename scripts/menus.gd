extends Control
## Tous les écrans de menu : titre, commandes, options, pause, fin de partie.
## Construit dans le code, avec le thème de ui_theme.gd. hud.gd l'instancie et relaie les signaux.

signal play_pressed
signal resume_pressed
signal restart_pressed
signal quit_to_menu_pressed
signal waves_pressed
signal endless_pressed

const UI = preload("res://scripts/ui_theme.gd")
const KEY_ART := ["res://assets/ui/key_art.jpg", "res://assets/ui/key_art.png", "res://assets/ui/key_art.webp"]
const TITLE_IMAGE := "res://assets/ui/title.webp"
const VERSION_TEXT := "v11"

var _screens: Dictionary = {}
var _focus: Dictionary = {}
var _safe_boxes: Array = []
var _current := ""
var _return_to := ""
var _fade: Tween
var _best_label: Label
var _pause_info: Label
var _end: Dictionary = {}
var _touch_only: Array = []      # lignes d'options visibles seulement avec les commandes tactiles
var _keys_box: Control
var _touch_box: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UI.build_theme(Settings.is_touch())

	_build_title()
	_build_howto()
	_build_options()
	_build_pause()
	_build_end()

	Settings.changed.connect(_on_setting_changed)
	get_viewport().size_changed.connect(_apply_safe_area)
	_refresh_control_scheme()
	_apply_safe_area()


# --------------------------------------------------------------------------- API

func current_screen() -> String:
	return _current


func is_open() -> bool:
	return _current != ""


func show_screen(screen_name: String) -> void:
	for key in _screens:
		_screens[key].visible = false
	_current = screen_name
	if screen_name == "" or not _screens.has(screen_name):
		_current = ""
		return
	var screen: Control = _screens[screen_name]
	screen.visible = true
	if _fade != null and _fade.is_valid():
		_fade.kill()
	screen.modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(screen, "modulate:a", 1.0, 0.18)
	if _focus.has(screen_name) and not Settings.is_touch():
		(_focus[screen_name] as Control).grab_focus()


func hide_all() -> void:
	show_screen("")


## Retour depuis « Options » ou « Commandes ». Renvoie vrai si la touche Échap a été utilisée.
func go_back() -> bool:
	if _current == "options" or _current == "howto":
		show_screen(_return_to if _return_to != "" else "title")
		return true
	return false


func set_best(text: String) -> void:
	_best_label.text = text


func set_pause_info(text: String) -> void:
	_pause_info.text = text


## data : win (bool), title, subtitle, time, clock, kills, items, best, new_best (bool)
func show_end(data: Dictionary) -> void:
	var win: bool = data.get("win", false)
	(_end["eyebrow"] as Label).text = "NUIT TERMINÉE"
	(_end["title"] as Label).text = String(data.get("title", ""))
	(_end["title"] as Label).add_theme_color_override("font_color", UI.ACCENT if win else UI.DANGER)
	(_end["subtitle"] as Label).text = String(data.get("subtitle", ""))
	(_end["time"] as Label).text = String(data.get("time", ""))
	(_end["clock"] as Label).text = String(data.get("clock", ""))
	(_end["kills"] as Label).text = str(data.get("kills", 0))
	(_end["items"] as Label).text = str(data.get("items", 0))
	var best_line: Label = _end["best"]
	best_line.text = String(data.get("best", ""))
	if _end.has("endless"):
		(_end["endless"] as Button).visible = win and bool(data.get("endless_ok", true))
	if _end.has("accuracy"):
		(_end["accuracy"] as Label).text = String(data.get("accuracy", "—"))
	if _end.has("level"):
		(_end["level"] as Label).text = str(data.get("level", 1))
	best_line.add_theme_color_override("font_color", UI.ACCENT if data.get("new_best", false) else UI.MUTED)
	show_screen("end")


# --------------------------------------------------------------------------- squelette commun

func _make_screen(screen_name: String, dim: float = 0.7) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	add_child(root)
	_screens[screen_name] = root
	if dim > 0.0:
		var shade := ColorRect.new()
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.color = Color(0.015, 0.02, 0.05, dim)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(shade)
	return root


func _safe(root: Control, base: int = 32) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.set_meta("base", base)
	root.add_child(m)
	_safe_boxes.append(m)
	return m


func _apply_safe_area() -> void:
	var insets := Settings.safe_insets(get_viewport())
	for m in _safe_boxes:
		var b: int = m.get_meta("base")
		m.add_theme_constant_override("margin_left", b + int(insets.x))
		m.add_theme_constant_override("margin_top", b + int(insets.y))
		m.add_theme_constant_override("margin_right", b + int(insets.z))
		m.add_theme_constant_override("margin_bottom", b + int(insets.w))


## Carte centrée. Renvoie la colonne qui reçoit le contenu.
func _card(root: Control, width: int) -> VBoxContainer:
	var safe := _safe(root, 24)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	panel.add_theme_stylebox_override("panel", UI.card_style())
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)
	return col


func _header(col: VBoxContainer, title: String, with_close: bool = true) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var t := UI.label(title, 34, UI.TEXT, "title")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	if with_close:
		var close := UI.button("Retour", "x", "ButtonGhost")
		close.pressed.connect(go_back)
		row.add_child(close)
	col.add_child(UI.spacer(4))


func _menu_button(parent: Control, text: String, icon_name: String, variation: String, cb: Callable) -> Button:
	var b := UI.button(text, icon_name, variation)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _open(screen_name: String) -> void:
	_return_to = _current
	show_screen(screen_name)


# --------------------------------------------------------------------------- écran titre

func _build_title() -> void:
	var root := _make_screen("title", 0.0)

	var art: Texture2D = null
	for p in KEY_ART:
		art = UI.image(p)
		if art != null:
			break
	if art != null:
		var bg := TextureRect.new()
		bg.texture = art
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bg)
	root.add_child(UI.gradient(Color(0.015, 0.02, 0.05, 0.94), Color(0.015, 0.02, 0.05, 0.12), true))
	root.add_child(UI.gradient(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.55), false))

	var safe := _safe(root, 36)
	var page := VBoxContainer.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(page)

	# Mise en page adaptative : en paysage (telephone), le titre est a gauche
	# et les boutons a droite — tout reste visible sans defilement. En portrait,
	# empilement classique avec un titre limite en hauteur.
	var vp := get_viewport_rect().size
	var landscape := vp.x >= vp.y and vp.y > 0.0
	var body: BoxContainer
	if landscape:
		body = HBoxContainer.new()
		body.add_theme_constant_override("separation", 36)
	else:
		body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(body)

	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(left)

	var title_w := 600.0
	if landscape:
		title_w = clampf(minf(vp.x * 0.46, (vp.y - 150.0) * 1.723), 200.0, 560.0)
	elif vp.y > 0.0:
		title_w = clampf(minf(vp.x * 0.72, vp.y * 0.52), 190.0, 600.0)
	var logo := UI.image(TITLE_IMAGE)
	if logo != null:
		var lr := TextureRect.new()
		lr.texture = logo
		lr.custom_minimum_size = Vector2(title_w, title_w * 383.0 / 660.0)
		lr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		lr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		lr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		left.add_child(lr)
	else:
		left.add_child(UI.label("LA NUIT DES", 30, UI.ACCENT, "title_light"))
		left.add_child(UI.label("CITROUILLES", 92, UI.TEXT, "title"))

	left.add_child(UI.spacer(8))
	var tagline := UI.label("Cinq minutes pour tenir jusqu'à l'aube.", 19 if vp.y < 540.0 else 25, UI.MUTED)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(tagline)

	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.custom_minimum_size = Vector2(clampf(vp.x * 0.34, 240.0, 360.0) if landscape else minf(vp.x * 0.8, 360.0), 0)
	buttons.add_theme_constant_override("separation", 10)
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if landscape:
		body.add_child(buttons)
	else:
		left.add_child(UI.spacer(16))
		left.add_child(buttons)

	var play := _menu_button(buttons, "JOUER", "play", "ButtonPrimary", func(): play_pressed.emit())
	_focus["title"] = play
	_menu_button(buttons, "MODE VAGUES", "flame", "", func(): waves_pressed.emit())
	if vp.y < 540.0:
		for b in buttons.get_children():
			if b is Button:
				(b as Button).custom_minimum_size = Vector2(0, 40)
	_menu_button(buttons, "COMMANDES", "gamepad-2", "", func(): _open("howto"))
	_menu_button(buttons, "OPTIONS", "settings", "", func(): _open("options"))
	if Settings.can_quit():
		_menu_button(buttons, "QUITTER", "log-out", "ButtonGhost", func(): get_tree().quit())

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(footer)
	var indent_footer := UI.spacer(0, 56)
	footer.add_child(indent_footer)
	footer.add_child(UI.icon_rect("trophy", 22, UI.ACCENT))
	_best_label = UI.label("", 20, UI.MUTED)
	_best_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_best_label)
	footer.add_child(UI.label(VERSION_TEXT, 18, UI.MUTED))


# --------------------------------------------------------------------------- commandes

func _keycap(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(UI.PANEL_SOFT, UI.BORDER, 1, 4, 12, 5))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(UI.label(text, 19, UI.TEXT, "ui_bold"))
	return p


func _icon_chip(icon_name: String, color: Color = UI.TEXT) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(UI.PANEL_SOFT, UI.BORDER, 1, 4, 8, 8))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(UI.icon_rect(icon_name, 22, color))
	return p


func _control_row(parent: Control, chips: Array, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var left := HBoxContainer.new()
	left.custom_minimum_size = Vector2(170, 0)
	left.add_theme_constant_override("separation", 6)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left)
	for c in chips:
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		left.add_child(c)
	var l := UI.label(text, 21, UI.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)


func _info_row(parent: Control, icon_name: String, color: Color, head: String, body: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var chip := _icon_chip(icon_name, color)
	chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(chip)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	col.add_child(UI.label(head, 21, UI.TEXT, "ui_bold"))
	var b := UI.label(body, 19, UI.MUTED)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(b)


func _build_howto() -> void:
	var root := _make_screen("howto", 0.72)
	var col := _card(root, 1020)
	_header(col, "COMMANDES")

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 40)
	col.add_child(body)

	# Colonne de gauche : objectif et objets
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(400, 0)
	left.add_theme_constant_override("separation", 14)
	body.add_child(left)
	left.add_child(UI.label("OBJECTIF", 17, UI.ACCENT, "ui_bold"))
	var goal := UI.label("Survivre de minuit à six heures. Les monstres arrivent de plus en plus vite : citrouilles, puis crânes volants, puis squelettes.", 21, UI.TEXT)
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(goal)
	left.add_child(UI.spacer(4))
	left.add_child(UI.label("À RAMASSER", 17, UI.ACCENT, "ui_bold"))
	_info_row(left, "heart", UI.DANGER, "Citrouille lumineuse", "Rend 25 points de vie.")
	_info_row(left, "snowflake", UI.ICE, "Bougie bleue", "Fige tous les monstres pendant 6 secondes.")


	# Colonne de droite : clavier ou tactile
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 0)
	body.add_child(right)

	_keys_box = VBoxContainer.new()
	_keys_box.add_theme_constant_override("separation", 12)
	right.add_child(_keys_box)
	_keys_box.add_child(UI.label("CLAVIER ET SOURIS", 17, UI.ACCENT, "ui_bold"))
	_control_row(_keys_box, [_keycap("Z"), _keycap("Q"), _keycap("S"), _keycap("D")], "Se déplacer (WASD et flèches aussi)")
	_control_row(_keys_box, [_keycap("Maj")], "Course automatique : le personnage court toujours dans la direction choisie")
	_control_row(_keys_box, [_keycap("Espace")], "Roulade d'esquive")
	_control_row(_keys_box, [_keycap("Souris")], "Viser (aide à la visée réglable dans les Options)")
	_control_row(_keys_box, [_keycap("Clic gauche")], "Tirer, maintenir pour tirer en continu")
	_control_row(_keys_box, [_keycap("R")], "Recharger")
	_control_row(_keys_box, [_keycap("1"), _keycap("2"), _keycap("3"), _keycap("4"), _keycap("E")], "Changer d'arme (débloquées en montant de niveau)")
	_control_row(_keys_box, [_keycap("G")], "Lancer une grenade explosive")
	_control_row(_keys_box, [_keycap("Échap")], "Pause")

	_touch_box = VBoxContainer.new()
	_touch_box.add_theme_constant_override("separation", 12)
	right.add_child(_touch_box)
	_touch_box.add_child(UI.label("ÉCRAN TACTILE", 17, UI.ACCENT, "ui_bold"))
	_control_row(_touch_box, [_icon_chip("gamepad-2")], "Joystick à gauche pour bouger. Pousse-le à fond pour courir.")
	_control_row(_touch_box, [_icon_chip("maximize")], "Glisse un doigt à droite pour tourner la caméra")
	_control_row(_touch_box, [_icon_chip("zap")], "Bouton éclair : changer d'arme  ·  bouton flamme : grenade")
	_control_row(_touch_box, [_icon_chip("crosshair", UI.ACCENT)], "Tirer. Si l'aide à la visée est activée (Options), le viseur se cale sur le monstre le plus proche du réticule.")
	_control_row(_touch_box, [_icon_chip("refresh-cw")], "Roulade d'esquive")
	_control_row(_touch_box, [_icon_chip("rotate-ccw")], "Recharger")
	_control_row(_touch_box, [_icon_chip("pause")], "Pause")


# --------------------------------------------------------------------------- options

func _section(parent: Control, text: String) -> void:
	parent.add_child(UI.spacer(8))
	parent.add_child(UI.label(text, 17, UI.ACCENT, "ui_bold"))


func _row(parent: Control, text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UI.label(text, 22, UI.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	row.add_child(control)
	parent.add_child(row)
	return row


func _slider(key: String, lo: float, hi: float, step: float, fmt: Callable) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Settings.get(key))
	s.custom_minimum_size = Vector2(300, 36)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_ALL
	box.add_child(s)
	var value := UI.label(String(fmt.call(s.value)), 20, UI.MUTED)
	value.custom_minimum_size = Vector2(70, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(value)
	s.value_changed.connect(func(v: float):
		value.text = String(fmt.call(v))
		Settings.set_value(key, v, false))
	s.drag_ended.connect(func(_changed: bool): Settings.flush())
	return box


func _segmented(labels: Array, current: int, on_pick: Callable) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var group := ButtonGroup.new()
	for i in labels.size():
		var b := Button.new()
		b.text = String(labels[i])
		b.toggle_mode = true
		b.button_group = group
		b.theme_type_variation = "ButtonSegment"
		b.focus_mode = Control.FOCUS_ALL
		b.button_pressed = (i == current)
		b.toggled.connect(func(on: bool):
			if on:
				on_pick.call(i))
		box.add_child(b)
	return box


func _yes_no(key: String) -> HBoxContainer:
	return _segmented(["Non", "Oui"], 1 if bool(Settings.get(key)) else 0,
		func(i: int): Settings.set_value(key, i == 1))


func _build_options() -> void:
	var root := _make_screen("options", 0.72)
	var col := _card(root, 860)
	_header(col, "OPTIONS")

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)

	var pct := func(v: float) -> String: return "%d %%" % roundi(v * 100.0)

	_section(list, "JEU")
	_row(list, "Difficulté", _segmented(["Histoire", "Normal", "Cauchemar"], Settings.difficulty,
		func(i: int): Settings.set_value("difficulty", i)))

	_section(list, "ACCESSIBILITÉ")
	_row(list, "Taille du texte (relancer le jeu)", _slider("text_scale", 0.85, 1.30, 0.05, pct))
	_row(list, "Réduire les flashs", _yes_no("reduce_flashes"))
	_row(list, "Tir auto. sur cible verrouillée", _yes_no("auto_shoot"))

	_section(list, "AUDIO")
	_row(list, "Volume général", _slider("master", 0.0, 1.0, 0.05, pct))
	_row(list, "Musique", _slider("music", 0.0, 1.0, 0.05, pct))
	_row(list, "Effets sonores", _slider("sfx", 0.0, 1.0, 0.05, pct))

	_section(list, "COMMANDES")
	_row(list, "Schéma de commandes", _segmented(["Auto", "Tactile", "Clavier"], Settings.controls,
		func(i: int): Settings.set_value("controls", i)))
	_row(list, "Sensibilité de la caméra", _slider("sensitivity", 0.4, 2.0, 0.1,
		func(v: float) -> String: return "%.1f ×" % v))
	_row(list, "Aide à la visée", _yes_no("aim_assist"))
	_touch_only.append(_row(list, "Vibrations", _yes_no("vibration")))

	_section(list, "AFFICHAGE")
	_row(list, "Qualité graphique", _segmented(["Basse", "Moyenne", "Haute"], Settings.quality,
		func(i: int): Settings.set_value("quality", i)))
	if Settings.can_fullscreen():
		_row(list, "Plein écran", _yes_no("fullscreen"))
	_row(list, "Afficher les images par seconde", _yes_no("show_fps"))

	# Le focus par défaut est le bouton « Retour » de l'en-tête.
	_focus["options"] = (col.get_child(0).get_child(1) as Control)
	_focus["howto"] = _first_button_of(_screens["howto"])


func _first_button_of(node: Node) -> Control:
	if node is Button:
		return node
	for c in node.get_children():
		var r := _first_button_of(c)
		if r != null:
			return r
	return null


# --------------------------------------------------------------------------- pause

func _build_pause() -> void:
	var root := _make_screen("pause", 0.62)
	var col := _card(root, 480)
	var title := UI.label("PAUSE", 46, UI.TEXT, "title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_pause_info = UI.label("", 20, UI.MUTED)
	_pause_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_pause_info)
	col.add_child(UI.spacer(4))
	col.add_child(UI.spacer(2))

	var resume := _menu_button(col, "REPRENDRE", "play", "ButtonPrimary", func(): resume_pressed.emit())
	_focus["pause"] = resume
	_menu_button(col, "OPTIONS", "settings", "", func(): _open("options"))
	_menu_button(col, "COMMANDES", "gamepad-2", "", func(): _open("howto"))
	_menu_button(col, "RECOMMENCER", "rotate-ccw", "", func(): restart_pressed.emit())
	_menu_button(col, "MENU PRINCIPAL", "house", "ButtonGhost", func(): quit_to_menu_pressed.emit())


# --------------------------------------------------------------------------- fin de partie

func _stat_tile(row: Control, caption: String, key: String) -> void:
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_stylebox_override("panel", UI.box(UI.PANEL_SOFT, UI.BORDER, 1, 6, 16, 14))
	row.add_child(tile)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	tile.add_child(v)
	var value := UI.label("", 42, UI.TEXT, "ui_bold")
	v.add_child(value)
	v.add_child(UI.label(caption, 16, UI.MUTED))
	_end[key] = value


func _build_end() -> void:
	var root := _make_screen("end", 0.78)
	var col := _card(root, 860)

	var eyebrow := UI.label("NUIT TERMINÉE", 17, UI.MUTED, "ui_bold")
	col.add_child(eyebrow)
	_end["eyebrow"] = eyebrow
	var title := UI.label("", 52, UI.ACCENT, "title")
	col.add_child(title)
	_end["title"] = title
	var sub := UI.label("", 22, UI.MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)
	_end["subtitle"] = sub
	col.add_child(UI.spacer(4))

	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 12)
	col.add_child(tiles)
	_stat_tile(tiles, "TEMPS TENU", "time")
	_stat_tile(tiles, "HEURE ATTEINTE", "clock")
	_stat_tile(tiles, "MONSTRES VAINCUS", "kills")
	_stat_tile(tiles, "OBJETS RAMASSÉS", "items")
	var tiles2 := HBoxContainer.new()
	tiles2.add_theme_constant_override("separation", 12)
	col.add_child(tiles2)
	_stat_tile(tiles2, "PRÉCISION DES TIRS", "accuracy")
	_stat_tile(tiles2, "NIVEAU ATTEINT", "level")

	var best := UI.label("", 20, UI.MUTED)
	col.add_child(best)
	_end["best"] = best

	col.add_child(UI.spacer(4))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	col.add_child(buttons)
	var again := _menu_button(buttons, "REJOUER", "refresh-cw", "ButtonPrimary", func(): restart_pressed.emit())
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_focus["end"] = again
	var endless := _menu_button(buttons, "MODE INFINI", "timer", "", func(): endless_pressed.emit())
	endless.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_end["endless"] = endless
	var menu := _menu_button(buttons, "MENU PRINCIPAL", "house", "", func(): quit_to_menu_pressed.emit())
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL


# --------------------------------------------------------------------------- réglages

func _on_setting_changed(key: String) -> void:
	if key == "controls":
		theme = UI.build_theme(Settings.is_touch())
		_refresh_control_scheme()


func _refresh_control_scheme() -> void:
	var touch := Settings.is_touch()
	for row in _touch_only:
		row.visible = touch
	if _keys_box != null:
		_keys_box.visible = not touch
	if _touch_box != null:
		_touch_box.visible = touch
