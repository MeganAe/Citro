extends RefCounted
## Identité visuelle de l'interface : palette, polices, icônes, thème Godot et petits constructeurs.
## Tout ce qui est visible passe par ici pour que les menus et le HUD restent cohérents.

# --- Palette : nuit bleutée, une seule couleur d'accent (ambre) ---
const BG := Color("070a14")
const PANEL := Color(0.047, 0.059, 0.102, 0.96)
const PANEL_SOFT := Color("121830")
const PANEL_HOVER := Color("1a2342")
const BORDER := Color("2b3558")
const ACCENT := Color("e9a23b")
const ACCENT_HOVER := Color("f4b95c")
const ACCENT_DARK := Color("9c6416")
const ON_ACCENT := Color("1b1307")
const TEXT := Color("ece8dd")
const MUTED := Color("8d96b3")
const DANGER := Color("d65545")
const ICE := Color("8fd3f0")
const GOOD := Color("86d08f")

const FONT_TITLE := "res://assets/fonts/Cinzel.ttf"
const FONT_UI := "res://assets/fonts/BarlowSemiCondensed-Medium.ttf"
const FONT_UI_BOLD := "res://assets/fonts/BarlowSemiCondensed-SemiBold.ttf"
const ICON_DIR := "res://assets/ui/icons/"

static var _fonts := {}
static var _icons := {}
static var _circles := {}


# --------------------------------------------------------------------------- ressources

static func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var f: Font = null
	match kind:
		"title":
			f = _variable_font(FONT_TITLE, 700, 3)
		"title_light":
			f = _variable_font(FONT_TITLE, 500, 4)
		"ui":
			f = _load_font(FONT_UI)
		"ui_bold":
			f = _load_font(FONT_UI_BOLD)
	if f == null:
		f = ThemeDB.fallback_font
	_fonts[kind] = f
	return f


static func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Font:
			return res
	return null


static func _variable_font(path: String, weight: int, tracking: int) -> Font:
	var base := _load_font(path)
	if base == null:
		return null
	var fv := FontVariation.new()
	fv.base_font = base
	var tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
	fv.variation_opentype = {tag: weight}
	fv.spacing_glyph = tracking
	return fv


## Icône Lucide (SVG blanc, à teinter avec modulate ou les couleurs d'icône du thème).
static func icon(icon_name: String) -> Texture2D:
	if _icons.has(icon_name):
		return _icons[icon_name]
	var tex: Texture2D = null
	var path := ICON_DIR + icon_name + ".svg"
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_icons[icon_name] = tex
	return tex


static func image(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


## Disque anti-crénelé (poignée des curseurs, boutons tactiles).
static func circle(radius: int, color: Color) -> Texture2D:
	var key := "%d_%s" % [radius, color.to_html()]
	if _circles.has(key):
		return _circles[key]
	var size := radius * 2 + 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size * 0.5, size * 0.5)
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(radius - d + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * a))
	var tex := ImageTexture.create_from_image(img)
	_circles[key] = tex
	return tex


# --------------------------------------------------------------------------- styles

static func box(bg: Color, border: Color = Color(0, 0, 0, 0), border_w: int = 0, radius: int = 4,
		pad_x: int = 0, pad_y: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


static func card_style() -> StyleBoxFlat:
	var sb := box(PANEL, BORDER, 1, 8, 36, 30)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 28
	return sb


# --------------------------------------------------------------------------- thème

static func build_theme(touch: bool) -> Theme:
	var t := Theme.new()
	t.default_font = font("ui")
	t.default_font_size = scaled_size(22)

	var pad_y := 16 if touch else 13
	var pad_x := 24

	# Boutons
	t.set_stylebox("normal", "Button", box(PANEL_SOFT, BORDER, 1, 5, pad_x, pad_y))
	t.set_stylebox("hover", "Button", box(PANEL_HOVER, ACCENT_DARK, 1, 5, pad_x, pad_y))
	t.set_stylebox("pressed", "Button", box(ACCENT_DARK, ACCENT, 1, 5, pad_x, pad_y))
	t.set_stylebox("disabled", "Button", box(PANEL_SOFT, BORDER, 1, 5, pad_x, pad_y))
	var focus := box(Color(0, 0, 0, 0), ACCENT, 2, 5, pad_x, pad_y)
	focus.draw_center = false
	t.set_stylebox("focus", "Button", focus)
	t.set_font("font", "Button", font("ui_bold"))
	t.set_font_size("font_size", "Button", scaled_size(22))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_color("icon_normal_color", "Button", TEXT)
	t.set_color("icon_hover_color", "Button", Color.WHITE)
	t.set_color("icon_pressed_color", "Button", Color.WHITE)
	t.set_color("icon_focus_color", "Button", Color.WHITE)
	t.set_constant("h_separation", "Button", 12)
	t.set_constant("icon_max_width", "Button", 24)

	# Bouton principal (ambre)
	t.set_type_variation("ButtonPrimary", "Button")
	t.set_stylebox("normal", "ButtonPrimary", box(ACCENT, ACCENT, 1, 5, pad_x, pad_y))
	t.set_stylebox("hover", "ButtonPrimary", box(ACCENT_HOVER, ACCENT_HOVER, 1, 5, pad_x, pad_y))
	t.set_stylebox("pressed", "ButtonPrimary", box(ACCENT_DARK, ACCENT_DARK, 1, 5, pad_x, pad_y))
	var focus_p := box(Color(0, 0, 0, 0), Color.WHITE, 2, 5, pad_x, pad_y)
	focus_p.draw_center = false
	t.set_stylebox("focus", "ButtonPrimary", focus_p)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		var col := ON_ACCENT
		if c.ends_with("pressed_color"):
			col = Color.WHITE
		t.set_color(c, "ButtonPrimary", col)

	# Bouton discret (retour, fermer)
	t.set_type_variation("ButtonGhost", "Button")
	var ghost_pad := 12
	t.set_stylebox("normal", "ButtonGhost", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 5, ghost_pad, pad_y))
	t.set_stylebox("hover", "ButtonGhost", box(PANEL_HOVER, Color(0, 0, 0, 0), 0, 5, ghost_pad, pad_y))
	t.set_stylebox("pressed", "ButtonGhost", box(PANEL_SOFT, Color(0, 0, 0, 0), 0, 5, ghost_pad, pad_y))
	var focus_g := box(Color(0, 0, 0, 0), ACCENT, 2, 5, ghost_pad, pad_y)
	focus_g.draw_center = false
	t.set_stylebox("focus", "ButtonGhost", focus_g)
	t.set_color("font_color", "ButtonGhost", MUTED)

	# Sélecteur segmenté (une option parmi plusieurs)
	var seg_pad_y := 12 if touch else 8
	t.set_type_variation("ButtonSegment", "Button")
	t.set_stylebox("normal", "ButtonSegment", box(PANEL_SOFT, BORDER, 1, 4, 18, seg_pad_y))
	t.set_stylebox("hover", "ButtonSegment", box(PANEL_HOVER, BORDER, 1, 4, 18, seg_pad_y))
	t.set_stylebox("pressed", "ButtonSegment", box(ACCENT, ACCENT, 1, 4, 18, seg_pad_y))
	t.set_stylebox("hover_pressed", "ButtonSegment", box(ACCENT_HOVER, ACCENT_HOVER, 1, 4, 18, seg_pad_y))
	var focus_s := box(Color(0, 0, 0, 0), Color.WHITE, 2, 4, 18, seg_pad_y)
	focus_s.draw_center = false
	t.set_stylebox("focus", "ButtonSegment", focus_s)
	t.set_font_size("font_size", "ButtonSegment", 20)
	t.set_color("font_pressed_color", "ButtonSegment", ON_ACCENT)
	t.set_color("font_hover_pressed_color", "ButtonSegment", ON_ACCENT)

	# Curseurs
	var track := box(BORDER, Color(0, 0, 0, 0), 0, 3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := box(ACCENT, Color(0, 0, 0, 0), 0, 3)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	var fill_hl := box(ACCENT_HOVER, Color(0, 0, 0, 0), 0, 3)
	fill_hl.content_margin_top = 3
	fill_hl.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill_hl)
	var grab_r := 14 if touch else 10
	t.set_icon("grabber", "HSlider", circle(grab_r, ACCENT))
	t.set_icon("grabber_highlight", "HSlider", circle(grab_r, ACCENT_HOVER))
	t.set_icon("grabber_disabled", "HSlider", circle(grab_r, MUTED))

	# Barre de défilement fine
	var empty := StyleBoxEmpty.new()
	t.set_stylebox("scroll", "VScrollBar", empty)
	t.set_stylebox("scroll_focus", "VScrollBar", empty)
	t.set_stylebox("grabber", "VScrollBar", box(BORDER, Color(0, 0, 0, 0), 0, 3, 3, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(MUTED, Color(0, 0, 0, 0), 0, 3, 3, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(ACCENT, Color(0, 0, 0, 0), 0, 3, 3, 0))

	# Texte
	t.set_color("font_color", "Label", TEXT)
	return t


# --------------------------------------------------------------------------- constructeurs

## Taille reelle d'un texte, selon le reglage d'accessibilite du joueur.
static func scaled_size(size: int) -> int:
	return clampi(roundi(float(size) * Settings.text_scale), 10, 72)


static func label(text: String, size: int = 22, color: Color = TEXT, kind: String = "ui") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", scaled_size(size))
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Texte avec contour sombre, lisible par-dessus la scène 3D (HUD).
static func hud_label(text: String, size: int = 22, color: Color = TEXT, kind: String = "ui_bold") -> Label:
	var l := label(text, size, color, kind)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.07, 0.9))
	l.add_theme_constant_override("outline_size", maxi(3, int(size * 0.14)))
	return l


static func button(text: String, icon_name: String = "", variation: String = "") -> Button:
	var b := Button.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = variation
	if icon_name != "":
		var tex := icon(icon_name)
		if tex != null:
			b.icon = tex
			b.expand_icon = true
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b


static func icon_rect(icon_name: String, size: int, color: Color = TEXT) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon(icon_name)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.modulate = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func spacer(h: int = 0, w: int = 0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Filet fin (séparateur de sections).
static func rule(color: Color = BORDER, thickness: int = 1) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, thickness)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Dégradé linéaire plein écran (voile derrière les menus).
static func gradient(from: Color, to: Color, horizontal: bool = true) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, from)
	g.set_color(1, to)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0) if horizontal else Vector2(0, 1)
	gt.width = 256
	gt.height = 256
	var r := TextureRect.new()
	r.texture = gt
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
