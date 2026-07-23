class_name TabTabelle
extends TabBase
## Ligatabelle als moderne Zeilen-Karten: Zonen-Markierung (Meister/Aufstieg/
## Abstieg), Vereins-Badges, Formkurve der letzten 5 Spiele, eigener Verein markiert.

const COL_WIDTHS := {"pos": 44, "form": 160, "sp": 44, "s": 34, "u": 34, "n": 34, "tore": 70, "diff": 52, "pkt": 60}

var _selected_league := 1
var _league_buttons := {}
var _rows_box: VBoxContainer

func _init() -> void:
	super()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	box.add_child(top)
	top.add_child(heading("Tabelle"))
	var group := ButtonGroup.new()
	for def in Data.LEAGUE_DEFS:
		var league_id := int(def.id)
		var b := Button.new()
		b.text = str(def.short) if not bool(def.playable) else str(def.name)
		if not bool(def.playable):
			b.tooltip_text = "%s – Unterbau, nicht spielbar. Die fünf Staffelmeister spielen den Aufstieg in die Dritte Liga aus." % str(def.name)
		b.toggle_mode = true
		b.button_group = group
		b.set_pressed_no_signal(league_id == 1)
		b.pressed.connect(_on_league_selected.bind(league_id))
		top.add_child(b)
		_league_buttons[league_id] = b
	var legend := info_label()
	legend.text = "     ▪ Grün: Aufstieg   ·   ▪ Gelb: Relegation   ·   ▪ Rot: Abstieg"
	top.add_child(legend)

	# Kopfzeile
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	box.add_child(header)
	header.add_child(_head_label("#", COL_WIDTHS.pos))
	header.add_child(_head_label("", 36))
	var name_head := _head_label("Verein", 0)
	name_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_head)
	header.add_child(_head_label("Form", COL_WIDTHS.form))
	header.add_child(_head_label("Sp", COL_WIDTHS.sp))
	header.add_child(_head_label("S", COL_WIDTHS.s))
	header.add_child(_head_label("U", COL_WIDTHS.u))
	header.add_child(_head_label("N", COL_WIDTHS.n))
	header.add_child(_head_label("Tore", COL_WIDTHS.tore))
	header.add_child(_head_label("Diff.", COL_WIDTHS.diff))
	header.add_child(_head_label("Pkt.", COL_WIDTHS.pkt))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 6)
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows_box)

## Farbstreifen links: Aufstieg grün, Relegation gelb, Abstieg rot – abgeleitet
## aus den Auf-/Abstiegsregeln der Liga.
func _zone_color(pos: int, lg: LeagueData) -> Color:
	var rules: Dictionary = Game.LEAGUE_RULES.get(lg.id, {})
	if rules.is_empty():
		return Color(0, 0, 0, 0)
	var size: int = lg.club_ids.size()
	if pos <= int(rules.up_direct):
		return UITheme.ACCENT
	if int(rules.up_playoff) > 0 and pos == int(rules.up_direct) + 1:
		return UITheme.WARN
	if pos > size - int(rules.down_direct):
		return UITheme.DANGER
	if int(rules.down_playoff) > 0 and pos == size - int(rules.down_direct):
		return UITheme.WARN
	return Color(0, 0, 0, 0)

func _head_label(text: String, width: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	l.add_theme_font_size_override("font_size", 13)
	if width > 0:
		l.custom_minimum_size = Vector2(width, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if text != "Verein" else HORIZONTAL_ALIGNMENT_LEFT
	return l

func select_my_league() -> void:
	_on_league_selected(Game.my_club().league_id)

func _on_league_selected(league_id: int) -> void:
	_selected_league = league_id
	for id in _league_buttons:
		_league_buttons[id].set_pressed_no_signal(id == league_id)
	refresh()

func refresh() -> void:
	while _rows_box.get_child_count() > 0:
		var child := _rows_box.get_child(0)
		_rows_box.remove_child(child)
		child.free()
	var lg := Game.league(_selected_league)
	var rows := lg.table()
	for i in rows.size():
		_rows_box.add_child(_table_row(i + 1, rows[i], lg))

func _table_row(pos: int, row: Dictionary, lg: LeagueData) -> PanelContainer:
	var club := Game.club(int(row.club_id))
	var is_mine := club.id == Game.my_club_id

	var panel := PanelContainer.new()
	var style := UITheme.box(UITheme.SURFACE2 if is_mine else UITheme.FIELD, 10, UITheme.ACCENT if is_mine else UITheme.BORDER, 10)
	if is_mine:
		style.set_border_width_all(1)
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", style)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	panel.add_child(line)

	# Zonen-Markierung aus den Auf-/Abstiegsregeln der Liga
	var zone := ColorRect.new()
	zone.custom_minimum_size = Vector2(5, 26)
	zone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	zone.color = _zone_color(pos, lg)
	line.add_child(zone)

	var pos_label := Label.new()
	pos_label.text = "%d." % pos
	pos_label.custom_minimum_size = Vector2(COL_WIDTHS.pos - 15, 0)
	pos_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pos_label.add_theme_font_size_override("font_size", 17)
	line.add_child(pos_label)

	line.add_child(UITheme.club_badge(club.short_name, Color(club.color), 32))

	var name_label := Label.new()
	name_label.text = club.name
	name_label.clip_contents = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 17)
	if is_mine:
		name_label.add_theme_color_override("font_color", UITheme.ACCENT)
	line.add_child(name_label)

	# Formkurve (letzte 5)
	var form_row := HBoxContainer.new()
	form_row.custom_minimum_size = Vector2(COL_WIDTHS.form, 0)
	form_row.add_theme_constant_override("separation", 4)
	var recent := lg.fixtures_of_club(club.id).filter(func(x): return x.played)
	var last5 := recent.slice(maxi(0, recent.size() - 5))
	for x in last5:
		var mine_home: bool = int(x.home) == club.id
		var gf: int = int(x.hg) if mine_home else int(x.ag)
		var ga: int = int(x.ag) if mine_home else int(x.hg)
		if gf > ga:
			form_row.add_child(UITheme.mini_pill("S", Color("#166534")))
		elif gf == ga:
			form_row.add_child(UITheme.mini_pill("U", Color("#475569")))
		else:
			form_row.add_child(UITheme.mini_pill("N", Color("#7f1d1d")))
	line.add_child(form_row)

	line.add_child(_num_label(str(int(row.played)), COL_WIDTHS.sp))
	line.add_child(_num_label(str(int(row.won)), COL_WIDTHS.s))
	line.add_child(_num_label(str(int(row.drawn)), COL_WIDTHS.u))
	line.add_child(_num_label(str(int(row.lost)), COL_WIDTHS.n))
	line.add_child(_num_label("%d:%d" % [int(row.gf), int(row.ga)], COL_WIDTHS.tore))
	var diff: int = int(row.gf) - int(row.ga)
	var diff_label := _num_label("%+d" % diff, COL_WIDTHS.diff)
	diff_label.add_theme_color_override("font_color",
		UITheme.ACCENT if diff > 0 else (UITheme.DANGER if diff < 0 else UITheme.TEXT_DIM))
	line.add_child(diff_label)
	var pkt := _num_label(str(int(row.points)), COL_WIDTHS.pkt)
	pkt.add_theme_font_size_override("font_size", 19)
	line.add_child(pkt)
	return panel

func _num_label(text: String, width: int) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(width, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 16)
	return l