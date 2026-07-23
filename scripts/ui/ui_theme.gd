class_name UITheme
extends RefCounted
## Zentrales Erscheinungsbild des Spiels: dunkles Manager-Design.
## Wird einmalig als Fenster-Theme gesetzt (siehe autoload/data.gd) –
## alle Controls erben Farben, Panels und Abstände automatisch.

const BG := Color("#0b1017")        # Fensterhintergrund
const SURFACE := Color("#151d29")   # Panels, Sidebar
const SURFACE2 := Color("#212e40")  # Hover, aktive Navigation
const FIELD := Color("#0e151f")     # Listen, Tabellen, Eingabefelder
const BORDER := Color("#2c3a4d")
const ACCENT := Color("#22c55e")    # Grün – Aktionen, Hervorhebungen
const ACCENT_DARK := Color("#14532d")
const TEXT := Color("#e6edf6")
const TEXT_DIM := Color("#8fa1b8")
const WARN := Color("#facc15")
const DANGER := Color("#f87171")

static func build() -> Theme:
	var t := Theme.new()

	# Systemschrift mit Emoji-Fallback (für ⚽, 🚑, Pfeile usw.)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Arial"])
	var emoji := SystemFont.new()
	emoji.font_names = PackedStringArray(["Segoe UI Emoji", "Segoe UI Symbol"])
	font.fallbacks = [emoji]
	t.default_font = font
	t.default_font_size = 17

	# --- Panels
	t.set_stylebox("panel", "PanelContainer", box(SURFACE, 12, BORDER, 14))
	t.set_stylebox("panel", "Panel", box(SURFACE, 12, BORDER, 14))

	# --- Buttons (und OptionButton, das nicht automatisch von Button erbt)
	for type in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, _button_box(SURFACE2, BORDER))
		t.set_stylebox("hover", type, _button_box(Color("#2a3a52"), ACCENT.darkened(0.35)))
		t.set_stylebox("pressed", type, _button_box(ACCENT_DARK, ACCENT))
		t.set_stylebox("disabled", type, _button_box(Color("#101722"), Color("#1d2634")))
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, Color("#bbf7d0"))
		t.set_color("font_disabled_color", type, Color("#4b5a6e"))
	t.set_color("arrow_color", "OptionButton", TEXT_DIM)

	# --- Eingabefelder
	t.set_stylebox("normal", "LineEdit", box(FIELD, 8, BORDER, 10))
	t.set_stylebox("focus", "LineEdit", box(FIELD, 8, ACCENT, 10))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_DIM.darkened(0.2))
	t.set_color("caret_color", "LineEdit", ACCENT)

	# --- Listen
	t.set_stylebox("panel", "ItemList", box(FIELD, 10, BORDER, 10))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("selected", "ItemList", box(ACCENT_DARK, 6))
	t.set_stylebox("selected_focus", "ItemList", box(ACCENT_DARK, 6))
	t.set_stylebox("hovered", "ItemList", box(SURFACE2, 6))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	t.set_constant("v_separation", "ItemList", 8)

	# --- Tabellen
	t.set_stylebox("panel", "Tree", box(FIELD, 10, BORDER, 10))
	t.set_stylebox("focus", "Tree", StyleBoxEmpty.new())
	t.set_stylebox("selected", "Tree", box(ACCENT_DARK, 6))
	t.set_stylebox("selected_focus", "Tree", box(ACCENT_DARK, 6))
	t.set_stylebox("hovered", "Tree", box(SURFACE2, 6))
	t.set_stylebox("title_button_normal", "Tree", box(SURFACE, 6, BORDER, 6))
	t.set_stylebox("title_button_hover", "Tree", box(SURFACE2, 6, BORDER, 6))
	t.set_stylebox("title_button_pressed", "Tree", box(SURFACE2, 6, BORDER, 6))
	t.set_color("font_color", "Tree", TEXT)
	t.set_color("font_selected_color", "Tree", Color.WHITE)
	t.set_color("title_button_color", "Tree", TEXT_DIM)
	t.set_color("guide_color", "Tree", Color(1, 1, 1, 0.04))
	t.set_constant("v_separation", "Tree", 9)

	# --- Text
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("normal", "RichTextLabel", box(FIELD, 10, BORDER, 12))
	t.set_color("default_color", "RichTextLabel", TEXT)

	# --- Fortschrittsbalken (Frische etc.)
	t.set_stylebox("background", "ProgressBar", box(FIELD, 6, BORDER))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, 6))

	# --- Dialoge
	t.set_stylebox("panel", "AcceptDialog", box(SURFACE, 12, BORDER, 16))
	t.set_stylebox("panel", "ConfirmationDialog", box(SURFACE, 12, BORDER, 16))

	return t

## Abgerundete flache Box, optional mit Rand und Innenabstand.
static func box(bg: Color, radius := 8, border := Color(0, 0, 0, 0), margin := -1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(1)
	if margin > 0:
		sb.content_margin_left = margin
		sb.content_margin_right = margin
		sb.content_margin_top = margin * 0.7
		sb.content_margin_bottom = margin * 0.7
	return sb

static func _button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := box(bg, 9, border)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	return sb

## Karte: Panel mit größerem Innenabstand für Inhaltsblöcke.
static func card() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(SURFACE, 14, BORDER)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	p.add_theme_stylebox_override("panel", sb)
	return p

## Rundes Vereins-Badge mit Kürzel in Vereinsfarbe.
static func club_badge(short_name: String, club_color: Color, size := 46) -> Label:
	var l := Label.new()
	l.text = short_name
	l.custom_minimum_size = Vector2(size, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", int(size * 0.32))
	var sb := StyleBoxFlat.new()
	sb.bg_color = club_color
	sb.set_corner_radius_all(size >> 1)
	l.add_theme_stylebox_override("normal", sb)
	l.add_theme_color_override("font_color", Color.WHITE if club_color.get_luminance() < 0.55 else Color("#111827"))
	return l

## Wappen eines Vereins: echtes Logo, wenn unter data/logos/<Vereins-ID>.png
## eines hinterlegt ist – sonst der gezeichnete Farbkreis mit dem Kürzel.
## Die Vereins-ID ist stabil, damit Logos zugeordnet bleiben.
static func club_logo(club: ClubData, size := 46) -> Control:
	var texture := club.load_logo()
	if texture == null:
		return club_badge(club.short_name, Color(club.color), size)
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(size, size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.tooltip_text = club.name
	return icon

## Prominenter Aktions-Button (grün).
static func make_primary(button: Button) -> void:
	var normal := box(Color("#16a34a"), 10)
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var hover := normal.duplicate()
	hover.bg_color = ACCENT
	var pressed := normal.duplicate()
	pressed.bg_color = Color("#15803d")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color("#06130a"))
	button.add_theme_color_override("font_hover_color", Color("#052e16"))
	button.add_theme_color_override("font_pressed_color", Color("#dcfce7"))

## Navigations-Button für die Sidebar.
static func style_nav(button: Button, active: bool) -> void:
	var sb: StyleBoxFlat
	if active:
		sb = box(SURFACE2, 8)
		sb.border_color = ACCENT
		sb.border_width_left = 3
	else:
		sb = box(Color(0, 0, 0, 0), 8)
	sb.content_margin_left = 16
	sb.content_margin_right = 12
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	var hover: StyleBoxFlat = sb.duplicate()
	if not active:
		hover.bg_color = SURFACE2
	button.add_theme_stylebox_override("normal", sb)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", sb)
	button.add_theme_color_override("font_color", Color.WHITE if active else TEXT_DIM)
	button.add_theme_color_override("font_hover_color", Color.WHITE)

## Sehr kompakte Pille (z. B. S/U/N-Formpunkte, Ergebnisse in Listen).
static func mini_pill(text: String, bg: Color, fg := Color.WHITE, min_width := 24) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(min_width, 24)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.add_theme_font_size_override("font_size", 13)
	var sb := box(bg, 6)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	l.add_theme_stylebox_override("normal", sb)
	l.add_theme_color_override("font_color", fg)
	return l

## Kleine gefärbte Info-Pille (z. B. Status, Minute).
static func pill(text: String, bg: Color, fg := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sb := box(bg, 999)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	l.add_theme_stylebox_override("normal", sb)
	l.add_theme_color_override("font_color", fg)
	return l
