class_name TabSpielplan
extends TabBase
## Saison-Spielplan als moderne Kartenliste: Termin, Gegner mit Badge,
## Heim/Auswärts, Ergebnis-Pille – das nächste Spiel ist hervorgehoben.

var _list: VBoxContainer

func _init() -> void:
	super()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	box.add_child(top)
	top.add_child(heading("Spielplan"))
	var legend := info_label()
	legend.text = "     Alle Partien deines Vereins – das nächste Spiel ist markiert"
	top.add_child(legend)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

func refresh() -> void:
	while _list.get_child_count() > 0:
		var child := _list.get_child(0)
		_list.remove_child(child)
		child.free()
	var c := Game.my_club()
	var fixtures := Game.my_league().fixtures_of_club(c.id)
	fixtures.sort_custom(func(a, b): return int(a.round) < int(b.round))
	for f in fixtures:
		if int(f.round) == 0:
			_list.add_child(_section_label("Hinrunde"))
		elif int(f.round) == 17:
			_list.add_child(_section_label("Rückrunde  ·  nach der Winterpause"))
		_list.add_child(_fixture_row(f, c))

func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", UITheme.ACCENT)
	return l

func _fixture_row(f: Dictionary, c: ClubData) -> PanelContainer:
	var round_no := int(f.round)
	var is_next: bool = not f.played and round_no == Game.matchday()
	var home := int(f.home) == c.id
	var opponent := Game.club(int(f.away) if home else int(f.home))

	var panel := PanelContainer.new()
	var style := UITheme.box(UITheme.SURFACE2 if is_next else UITheme.FIELD, 10, UITheme.ACCENT if is_next else UITheme.BORDER, 10)
	if is_next:
		style.set_border_width_all(1)
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	panel.add_child(line)

	# Termin
	var when := VBoxContainer.new()
	when.add_theme_constant_override("separation", 0)
	when.custom_minimum_size = Vector2(120, 0)
	line.add_child(when)
	var round_label := Label.new()
	round_label.text = "Spieltag %d" % (round_no + 1)
	round_label.add_theme_font_size_override("font_size", 12)
	round_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	when.add_child(round_label)
	var d := Time.get_datetime_dict_from_unix_time(Game.matchday_date(round_no))
	var date_label := Label.new()
	date_label.text = "%s, %02d.%02d.%d" % [Game.WEEKDAYS[int(d.weekday)], int(d.day), int(d.month), int(d.year)]
	date_label.add_theme_font_size_override("font_size", 15)
	when.add_child(date_label)

	# Heim/Auswärts
	line.add_child(UITheme.mini_pill("Heim" if home else "Ausw.", Color("#1e3a5f") if home else Color("#3b3f46"), Color.WHITE, 56))

	# Gegner
	line.add_child(UITheme.club_badge(opponent.short_name, Color(opponent.color), 34))
	var opp_label := Label.new()
	opp_label.text = opponent.name
	opp_label.add_theme_font_size_override("font_size", 18)
	opp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(opp_label)

	# Spielstätte
	var venue := Label.new()
	venue.text = c.stadium if home else opponent.stadium
	venue.add_theme_font_size_override("font_size", 13)
	venue.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	line.add_child(venue)

	# Ergebnis / Status
	if f.played:
		var my_goals: int = int(f.hg) if home else int(f.ag)
		var their_goals: int = int(f.ag) if home else int(f.hg)
		var color := Color("#166534") if my_goals > their_goals else (Color("#475569") if my_goals == their_goals else Color("#7f1d1d"))
		line.add_child(UITheme.mini_pill("%d : %d" % [int(f.hg), int(f.ag)], color, Color.WHITE, 64))
	elif is_next:
		line.add_child(UITheme.mini_pill("NÄCHSTES SPIEL", Color("#166534"), Color.WHITE, 130))
	else:
		line.add_child(UITheme.mini_pill("–", UITheme.SURFACE2, UITheme.TEXT_DIM, 64))
	return panel