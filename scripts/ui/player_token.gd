class_name PlayerToken
extends Button
## Spielerkarte im Taktikboard-Stil: runder Trikot-Chip mit Stärkezahl,
## Positions-Kürzel darüber, Namensplakette darunter, Frische-Balken mit
## Formpfeil. Wird im Aufstellungsbildschirm und im Spiel verwendet.

const TOKEN := 46

const GROUP_COLORS := {
	"TW": Color("#eab308"), "AB": Color("#3b82f6"),
	"MF": Color("#22c55e"), "ST": Color("#ef4444"),
}

var pid := -1
var zone_pos := ""

var pos_label: Label
var token: PanelContainer
var str_label: Label
var name_plate: PanelContainer
var name_label: Label
var extra_label: Label      # Note bzw. Zusatzinfo unter dem Namen
var fresh_bar: ColorRect
var fresh_rest: ColorRect
var form_label: Label

func _init() -> void:
	custom_minimum_size = Vector2(108, 104)
	focus_mode = Control.FOCUS_NONE
	flat = true

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 1)
	add_child(v)

	pos_label = Label.new()
	pos_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pos_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pos_label.add_theme_font_size_override("font_size", 12)
	v.add_child(pos_label)

	var token_row := HBoxContainer.new()
	token_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	token_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(token_row)
	token = PanelContainer.new()
	token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	token.custom_minimum_size = Vector2(TOKEN, TOKEN)
	token_row.add_child(token)
	str_label = Label.new()
	str_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	str_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	str_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	str_label.add_theme_font_size_override("font_size", 20)
	token.add_child(str_label)

	name_plate = PanelContainer.new()
	name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_plate)
	var plate_box := VBoxContainer.new()
	plate_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate_box.add_theme_constant_override("separation", 0)
	name_plate.add_child(plate_box)
	name_label = Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.clip_text = true
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	plate_box.add_child(name_label)
	extra_label = Label.new()
	extra_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	extra_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	extra_label.add_theme_font_size_override("font_size", 11)
	extra_label.visible = false
	plate_box.add_child(extra_label)

	var bar_row := HBoxContainer.new()
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_row.add_theme_constant_override("separation", 4)
	v.add_child(bar_row)
	var bar_wrap := HBoxContainer.new()
	bar_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_wrap.add_theme_constant_override("separation", 0)
	bar_wrap.custom_minimum_size = Vector2(0, 5)
	bar_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(bar_wrap)
	fresh_bar = ColorRect.new()
	fresh_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fresh_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_wrap.add_child(fresh_bar)
	fresh_rest = ColorRect.new()
	fresh_rest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fresh_rest.color = Color(0, 0, 0, 0.35)
	fresh_rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_wrap.add_child(fresh_rest)
	form_label = Label.new()
	form_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	form_label.add_theme_font_size_override("font_size", 11)
	bar_row.add_child(form_label)

## Balken über Stretch-Ratios: gefüllter Anteil zu Restanteil.
func set_fresh(cond: float, color: Color) -> void:
	fresh_bar.color = color
	var filled := clampf(cond, 1.0, 100.0)
	fresh_bar.size_flags_stretch_ratio = filled
	fresh_rest.size_flags_stretch_ratio = maxf(100.0 - filled, 0.01)
	fresh_rest.color = Color(0, 0, 0, 0.0) if color.a == 0.0 else Color(0, 0, 0, 0.35)

## Färbt Token und Plakette; mismatch = positionsfremd, selected = ausgewählt.
func style_token(group: String, mismatch: bool, selected: bool, empty: bool = false) -> void:
	var base: Color = GROUP_COLORS.get(group, Color("#22c55e"))
	var color: Color = base if not mismatch else Color("#f59e0b")
	if empty:
		color = Color(0.35, 0.4, 0.38, 0.55)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color.darkened(0.12)
	sb.set_corner_radius_all(TOKEN / 2)
	sb.set_border_width_all(3 if selected else 2)
	sb.border_color = Color.WHITE if selected else color.lightened(0.35)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 4
	sb.content_margin_top = 2
	token.add_theme_stylebox_override("panel", sb)
	str_label.add_theme_color_override("font_color", Color.WHITE if not empty else Color(1, 1, 1, 0.5))

	var plate := UITheme.box(Color(0.05, 0.08, 0.07, 0.88), 5)
	plate.content_margin_left = 6
	plate.content_margin_right = 6
	plate.content_margin_top = 1
	plate.content_margin_bottom = 1
	if selected:
		plate.set_border_width_all(1)
		plate.border_color = Color.WHITE
	name_plate.add_theme_stylebox_override("panel", plate)
	name_label.add_theme_color_override("font_color", Color.WHITE if not empty else Color(1, 1, 1, 0.5))
	pos_label.add_theme_color_override("font_color", color.lightened(0.45))

	var invisible := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(state, invisible)

## Frische-Farbe: grün (frisch) → gelb → rot (platt).
static func fresh_color(cond: float) -> Color:
	if cond >= 75.0:
		return Color("#22c55e")
	if cond >= 55.0:
		return Color("#eab308")
	if cond >= 35.0:
		return Color("#f97316")
	return Color("#ef4444")

## Noten-Farbe: gut grün, mittel neutral, schlecht rot.
static func note_color(note: float) -> Color:
	if note <= 2.5:
		return Color("#4ade80")
	if note <= 4.0:
		return Color("#e2e8f0")
	return Color("#f87171")
