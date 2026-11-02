extends CanvasLayer
## Interface en jeu (vie, XP, horloge, munitions, messages) et passerelle vers les menus
## et les commandes tactiles. game.gd ne parle qu'à ce nœud.

signal start_pressed
signal restart_pressed
signal pause_pressed
signal menu_pressed
signal endless_pressed
signal waves_pressed

const UI = preload("res://scripts/ui_theme.gd")
const MenusScript = preload("res://scripts/menus.gd")
const TouchScript = preload("res://scripts/touch_controls.gd")

var menus: Control
var touch: Control

var _screen: Control               # plein écran : voile de dégâts, réticule
var _hud: Control                  # zone de sécurité : tout le reste du HUD
var _hud_safe: MarginContainer
var _game_ui: Control
var _vignette: TextureRect
var _vignette_tween: Tween
var _cross: Control
var _cross_parts: Array = []          # morceaux du réticule (pour les teinter)
var _cross_on_target := false
var _hitmark_t := 0.0                 # > 0 : le réticule vient de confirmer une touche

var _health_bar: ProgressBar
var _health_value: Label
var _clock_label: Label
var _night_bar: ProgressBar
var _message_panel: PanelContainer
var _message: Label
var _msg_tween: Tween
var _kills_label: Label
var _top_right: HBoxContainer
var _ammo_box: HBoxContainer
var _ammo_value: Label
var _ammo_max: Label
var _ammo_icon: TextureRect
var _reload_label: Label
var _freeze_row: HBoxContainer
var _freeze_label: Label
var _hint: Label
var _hint_tween: Tween
var _fps: Label
var _weapon_label: Label
var _weapon_detail: Label
var _grenade_count := 2
var _grenade_label: Label
var _xp_bar: ProgressBar
var _xp_value: Label
var _shield_label: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	_screen = Control.new()
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.theme = UI.build_theme(Settings.is_touch())
	add_child(_screen)

	_build_vignette()
	_build_crosshair()

	_game_ui = Control.new()
	_game_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_ui.visible = false
	_screen.add_child(_game_ui)

	_hud_safe = MarginContainer.new()
	_hud_safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_ui.add_child(_hud_safe)
	_hud = Control.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_safe.add_child(_hud)

	_build_status()
	_build_clock()
	_build_top_right()
	_build_ammo()
	_build_bottom()
	_build_fps()

	touch = TouchScript.new()
	_screen.add_child(touch)
	touch.pause_requested.connect(func(): pause_pressed.emit())

	menus = MenusScript.new()
	_screen.add_child(menus)
	menus.play_pressed.connect(func(): start_pressed.emit())
	menus.resume_pressed.connect(func(): pause_pressed.emit())
	menus.restart_pressed.connect(func(): restart_pressed.emit())
	menus.quit_to_menu_pressed.connect(func(): menu_pressed.emit())
	if menus.has_signal("endless_pressed"):
		menus.connect("endless_pressed", func(): endless_pressed.emit())
	if menus.has_signal("waves_pressed"):
		menus.connect("waves_pressed", func(): waves_pressed.emit())

	Settings.changed.connect(_on_setting_changed)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	_layout_for_scheme()


func _process(_delta: float) -> void:
	if _fps.visible:
		_fps.text = "%d IPS" % Engine.get_frames_per_second()
	if _hitmark_t > 0.0:
		_hitmark_t = maxf(_hitmark_t - _delta, 0.0)
		if _hitmark_t <= 0.0:
			_paint_crosshair()


## Réticule : blanc au repos, ambre quand une cible est verrouillée,
## rouge un court instant quand une balle touche un monstre.
func _paint_crosshair() -> void:
	var col := Color(1.0, 1.0, 1.0, 0.9)
	if _hitmark_t > 0.0:
		col = UI.DANGER
	elif _cross_on_target:
		col = UI.ACCENT
	for part in _cross_parts:
		(part as ColorRect).color = col
	_cross.scale = Vector2.ONE * (1.3 if _cross_on_target or _hitmark_t > 0.0 else 1.0)


func set_crosshair_target(on: bool) -> void:
	_cross_on_target = on
	_paint_crosshair()


func flash_hitmarker() -> void:
	_hitmark_t = 0.12
	_paint_crosshair()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if menus.go_back():
			get_viewport().set_input_as_handled()
		else:
			pause_pressed.emit()
	elif event.is_action_pressed("restart"):
		restart_pressed.emit()


# --------------------------------------------------------------------------- API (appelée par game.gd)

func bind_player(p: Node) -> void:
	touch.player = p
	if p.has_signal("shield_changed"):
		p.connect("shield_changed", Callable(self, "set_shield"))
	if p.has_signal("weapon_changed"):
		p.connect("weapon_changed", Callable(self, "set_weapon"))
	if p.has_signal("grenade_changed"):
		p.connect("grenade_changed", Callable(self, "set_grenades"))
	if p.has_signal("aim_changed"):
		p.connect("aim_changed", Callable(self, "set_crosshair_target"))
	if p.has_signal("hit_confirmed"):
		p.connect("hit_confirmed", Callable(self, "flash_hitmarker"))


func set_health(current: int, maximum: int) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_value.text = str(current)


func set_clock(text: String, fraction: float) -> void:
	_clock_label.text = text
	_night_bar.value = fraction


func set_ammo(current: int, maximum: int, reloading: bool) -> void:
	_ammo_max.text = "/ %d" % maximum
	_reload_label.visible = reloading
	_ammo_value.visible = not reloading
	_ammo_max.visible = not reloading
	_ammo_value.text = str(current)
	var low := current <= 3
	_ammo_value.add_theme_color_override("font_color", UI.DANGER if low else UI.TEXT)


func set_xp(lvl: int, current: int, needed: int) -> void:
	if _xp_bar == null:
		return
	_xp_bar.max_value = float(maxi(needed, 1))
	_xp_bar.value = float(current)
	_xp_value.text = str(lvl)


func set_shield(points: int) -> void:
	if _shield_label == null:
		return
	_shield_label.visible = points > 0
	_shield_label.text = "Bouclier : %d" % points


func set_weapon(weapon_name: String, detail: String) -> void:
	if _weapon_label == null:
		return
	_weapon_label.text = weapon_name
	_weapon_detail.text = detail


func set_grenades(count: int) -> void:
	if _grenade_label == null:
		return
	_grenade_count = count
	_grenade_label.text = ("Grenades : %d" if Settings.is_touch() else "Grenades : %d  (G)") % count
	_grenade_label.add_theme_color_override("font_color", UI.DANGER if count <= 0 else UI.MUTED)


func set_kills(count: int) -> void:
	_kills_label.text = str(count)


func set_crosshair(on: bool) -> void:
	_cross.visible = on


func set_freeze(seconds_left: float) -> void:
	if seconds_left > 0.0:
		_freeze_label.text = "Monstres figés  %.1f s" % seconds_left
		_freeze_row.visible = true
	else:
		_freeze_row.visible = false


func show_message(text: String, duration: float = 3.5) -> void:
	_message.text = text
	# Les longs messages (tutoriel) passent sur plusieurs lignes au lieu d'une bande très large.
	var long_text := text.length() > 44 or text.contains("\n")
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if long_text else TextServer.AUTOWRAP_OFF
	_message.custom_minimum_size.x = 560.0 if long_text else 0.0
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _msg_tween != null and _msg_tween.is_valid():
		_msg_tween.kill()
	_message_panel.modulate.a = 0.0
	_msg_tween = create_tween()
	_msg_tween.tween_property(_message_panel, "modulate:a", 1.0, 0.3)
	_msg_tween.tween_interval(duration)
	_msg_tween.tween_property(_message_panel, "modulate:a", 0.0, 0.6)


func flash_damage() -> void:
	if _vignette_tween != null and _vignette_tween.is_valid():
		_vignette_tween.kill()
	_vignette.modulate.a = 0.25 if Settings.reduce_flashes else 0.85
	_vignette_tween = create_tween()
	_vignette_tween.tween_property(_vignette, "modulate:a", 0.0, 0.5)


## Affiche ou cache le HUD de partie et les commandes tactiles.
func set_playing_ui(on: bool, with_touch: bool = false) -> void:
	_game_ui.visible = on
	touch.set_active(on and with_touch and Settings.is_touch())


func show_hint() -> void:
	if Settings.is_touch():
		return
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint.modulate.a = 1.0
	_hint_tween = create_tween()
	_hint_tween.tween_interval(12.0)
	_hint_tween.tween_property(_hint, "modulate:a", 0.0, 1.5)


func show_menu(best_text: String) -> void:
	menus.set_best(best_text)
	menus.show_screen("title")


func hide_menu() -> void:
	menus.hide_all()


func show_end(data: Dictionary) -> void:
	menus.show_end(data)


func hide_end() -> void:
	menus.hide_all()


func set_paused(on: bool, info: String = "") -> void:
	if on:
		menus.set_pause_info(info)
		menus.show_screen("pause")
		touch.set_active(false)
	else:
		menus.hide_all()


# --------------------------------------------------------------------------- réglages

func _on_setting_changed(key: String) -> void:
	if key == "controls":
		_screen.theme = UI.build_theme(Settings.is_touch())
		_layout_for_scheme()
	elif key == "show_fps":
		_fps.visible = Settings.show_fps


func _apply_safe_area() -> void:
	var ins := Settings.safe_insets(get_viewport())
	_hud_safe.add_theme_constant_override("margin_left", 28 + int(ins.x))
	_hud_safe.add_theme_constant_override("margin_top", 20 + int(ins.y))
	_hud_safe.add_theme_constant_override("margin_right", 28 + int(ins.z))
	_hud_safe.add_theme_constant_override("margin_bottom", 20 + int(ins.w))


## Place le compteur de munitions et laisse la place au bouton pause en mode tactile.
func _layout_for_scheme() -> void:
	var is_touch := Settings.is_touch()
	_fps.visible = Settings.show_fps
	_top_right.offset_right = -84.0 if is_touch else 0.0
	if is_touch:
		_ammo_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
		_ammo_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_ammo_box.offset_top = 58.0
		_ammo_box.offset_right = -84.0
	else:
		_ammo_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE)
		_ammo_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_ammo_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if _hint != null:
		_hint.visible = not is_touch
	# Au tactile, la place est comptée : pas de détail d'arme, textes plus petits.
	if _weapon_detail != null:
		_weapon_detail.visible = not is_touch
		_weapon_label.add_theme_font_size_override("font_size", 20 if is_touch else 24)
		_grenade_label.add_theme_font_size_override("font_size", 16 if is_touch else 18)
		set_grenades(_grenade_count)


# --------------------------------------------------------------------------- construction

func _make_bar(fill: Color, width: float, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(width, height)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 100.0
	bar.add_theme_stylebox_override("background", UI.box(Color(0.02, 0.03, 0.07, 0.7), Color(1, 1, 1, 0.08), 1, 3))
	bar.add_theme_stylebox_override("fill", UI.box(fill, Color(0, 0, 0, 0), 0, 3))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


func _build_vignette() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.7, 0.0, 0.0, 0.0))
	g.add_point(0.55, Color(0.7, 0.0, 0.0, 0.0))
	g.set_color(g.get_point_count() - 1, Color(0.8, 0.02, 0.02, 0.75))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	_vignette = TextureRect.new()
	_vignette.texture = gt
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	_screen.add_child(_vignette)


func _build_crosshair() -> void:
	_cross = Control.new()
	_cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_cross)
	var parts := [Rect2(-1.5, -1.5, 3.0, 3.0), Rect2(-14.0, -1.0, 8.0, 2.0), Rect2(6.0, -1.0, 8.0, 2.0),
			Rect2(-1.0, -14.0, 2.0, 8.0), Rect2(-1.0, 6.0, 2.0, 8.0)]
	for r in parts:
		var tick := ColorRect.new()
		tick.color = Color(1.0, 1.0, 1.0, 0.9)
		tick.position = r.position
		tick.size = r.size
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cross.add_child(tick)
		_cross_parts.append(tick)
		# Contour sombre pour rester lisible sur fond clair.
		var shadow := ColorRect.new()
		shadow.color = Color(0.0, 0.0, 0.0, 0.45)
		shadow.position = r.position - Vector2(1, 1)
		shadow.size = r.size + Vector2(2, 2)
		shadow.show_behind_parent = true
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cross.add_child(shadow)
	_cross.visible = false


func _stat_row(parent: Control, icon_name: String, color: Color) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var icon := UI.icon_rect(icon_name, 22, color)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var bar := _make_bar(color, 250.0, 12.0)
	row.add_child(bar)
	var value := UI.hud_label("100", 19, UI.TEXT)
	value.custom_minimum_size = Vector2(44, 0)
	row.add_child(value)
	return [bar, value]


func _build_status() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE)

	var h := _stat_row(col, "heart", Color(0.86, 0.22, 0.24))
	_health_bar = h[0]
	_health_value = h[1]
	var x := _stat_row(col, "flame", Color(0.65, 0.85, 1.0))
	_xp_bar = x[0]
	_xp_bar.max_value = 50.0
	_xp_bar.value = 0.0
	_xp_value = x[1]
	_xp_value.text = "1"
	_shield_label = UI.hud_label("", 20, Color(0.55, 0.80, 1.0), "ui_bold")
	_shield_label.visible = false
	col.add_child(_shield_label)


func _build_clock() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH

	_clock_label = UI.hud_label("00:00", 44, UI.TEXT, "title")
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_clock_label)
	var sub := UI.hud_label("AVANT L'AUBE", 14, UI.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	_night_bar = _make_bar(UI.ACCENT, 300.0, 5.0)
	_night_bar.max_value = 1.0
	_night_bar.value = 0.0
	_night_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_night_bar)
	col.add_child(UI.spacer(16))

	_message_panel = PanelContainer.new()
	_message_panel.add_theme_stylebox_override("panel", UI.box(Color(0.03, 0.04, 0.09, 0.8), UI.BORDER, 1, 5, 22, 10))
	_message_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_message_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_panel.modulate.a = 0.0
	col.add_child(_message_panel)
	_message = UI.label(" ", 25, UI.TEXT, "ui_bold")
	_message_panel.add_child(_message)


func _build_top_right() -> void:
	_top_right = HBoxContainer.new()
	_top_right.add_theme_constant_override("separation", 10)
	_top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_top_right)
	_top_right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	_top_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_top_right.add_child(UI.icon_rect("skull", 24, UI.MUTED))
	_kills_label = UI.hud_label("0", 28, UI.TEXT)
	_kills_label.custom_minimum_size = Vector2(36, 0)
	_kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_top_right.add_child(_kills_label)


func _build_ammo() -> void:
	_ammo_box = HBoxContainer.new()
	_ammo_box.add_theme_constant_override("separation", 10)
	_ammo_box.alignment = BoxContainer.ALIGNMENT_END
	_ammo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_ammo_box)
	_weapon_label = UI.hud_label("Pistolet", 24, UI.ACCENT, "ui_bold")
	_ammo_box.add_child(_weapon_label)
	_weapon_detail = UI.hud_label("", 17, UI.MUTED, "ui")
	_ammo_box.add_child(_weapon_detail)
	_ammo_icon = UI.icon_rect("crosshair", 26, UI.MUTED)
	_ammo_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ammo_box.add_child(_ammo_icon)
	_ammo_value = UI.hud_label("12", 46, UI.TEXT)
	_ammo_box.add_child(_ammo_value)
	_ammo_max = UI.hud_label("/ 12", 24, UI.MUTED)
	_ammo_max.size_flags_vertical = Control.SIZE_SHRINK_END
	_ammo_box.add_child(_ammo_max)
	_reload_label = UI.hud_label("RECHARGEMENT", 26, UI.ACCENT)
	_reload_label.visible = false
	_ammo_box.add_child(_reload_label)
	_grenade_label = UI.hud_label("Grenades : 2  (G)", 18, UI.MUTED, "ui")
	_ammo_box.add_child(_grenade_label)


func _build_bottom() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.alignment = BoxContainer.ALIGNMENT_END
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN

	_freeze_row = HBoxContainer.new()
	_freeze_row.add_theme_constant_override("separation", 10)
	_freeze_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_freeze_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_freeze_row.visible = false
	col.add_child(_freeze_row)
	_freeze_row.add_child(UI.icon_rect("snowflake", 24, UI.ICE))
	_freeze_label = UI.hud_label("", 24, UI.ICE)
	_freeze_row.add_child(_freeze_label)

	# Aide des touches : en bas à gauche, sur plusieurs lignes, loin des munitions.
	_hint = UI.hud_label("ZQSD  bouger\nMaj  courir\nEspace  rouler\nClic  tirer\nR  recharger\nG  grenade\n1-4 ou E  changer d'arme", 17, UI.MUTED, "ui")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hint.modulate.a = 0.0
	_hud.add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE)
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _build_fps() -> void:
	_fps = UI.hud_label("", 16, UI.MUTED, "ui")
	_fps.visible = false
	_hud.add_child(_fps)
	_fps.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE)
	_fps.offset_top = 72.0
