extends Control
## Saisonabschluss: der Übergang vom 30. Juni auf den 1. Juli. Der Bildschirm
## wertet die Spielzeit aus (Meister, Auf- und Abstieg, Entwicklung, Nachwuchs)
## und zeigt alles auf einen Blick: eigenes Abschneiden, beide Abschluss-
## tabellen, Torjäger, beste Noten, den eigenen Kader, Karriereenden und die
## Aufsteiger aus der eigenen Jugend.

const MARK_COLORS := {
	"champion": Color("#e3b341"),
	"promoted": Color("#22c55e"),
	"relegated": Color("#f87171"),
}

var _s := {}                  # Zusammenfassung aus Game.end_season()
var _old_season := ""
var _new_season := ""

func _ready() -> void:
	if not Game.initialized:
		get_tree().change_scene_to_file.call_deferred("res://scenes/main_menu.tscn")
		return
	_old_season = Game.season_label()
	# Der Abschluss verändert die Welt – die Anzeigedaten liegen der Zusammen-
	# fassung bei, weil danach Tabellen und Statistiken zurückgesetzt sind.
	_s = Game.end_season()
	_new_season = Game.season_label()
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	box.add_child(_build_head())

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(columns)
	var tables: Array = _s.get("tables", [])
	for t in tables:
		columns.add_child(_build_table_card(t))
	columns.add_child(_build_side_column())

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 14)
	box.add_child(footer)
	var hint := Label.new()
	hint.text = "Die neue Spielzeit beginnt am 1. Juli mit der Sommervorbereitung."
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	footer.add_child(hint)
	var go := Button.new()
	go.text = "%s starten  →" % _new_season
	go.add_theme_font_size_override("font_size", 18)
	UITheme.make_primary(go)
	go.pressed.connect(_on_continue)
	footer.add_child(go)

# ------------------------------------------------------------------ Kopfbereich

## Kopf: eigene Bilanz, Saisonziel und die beiden Meister.
func _build_head() -> PanelContainer:
	var card := PanelContainer.new()
	var sb := UITheme.box(UITheme.SURFACE, 14, UITheme.BORDER)
	sb.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)

	var title := Label.new()
	title.text = "🏁  %s abgeschlossen" % _old_season
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	v.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)

	# Eigene Bilanz
	var c := Game.my_club()
	var mine := PanelContainer.new()
	var achieved: bool = bool(_s.get("goal_achieved", false))
	var mine_sb := UITheme.box(Color(0.06, 0.11, 0.08, 1.0) if achieved else Color(0.13, 0.07, 0.07, 1.0),
		10, UITheme.ACCENT if achieved else UITheme.DANGER)
	mine_sb.set_content_margin_all(10)
	mine.add_theme_stylebox_override("panel", mine_sb)
	mine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mine.size_flags_stretch_ratio = 1.5
	row.add_child(mine)
	var mine_row := HBoxContainer.new()
	mine_row.add_theme_constant_override("separation", 12)
	mine.add_child(mine_row)
	mine_row.add_child(UITheme.club_badge(c.short_name, Color(c.color), 52))
	var mine_texts := VBoxContainer.new()
	mine_texts.add_theme_constant_override("separation", 1)
	mine_texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mine_row.add_child(mine_texts)
	var place := Label.new()
	place.text = "%d. Platz  ·  %s" % [int(_s.get("my_position", 0)), _s.get("my_league_name", "")]
	place.add_theme_font_size_override("font_size", 19)
	mine_texts.add_child(place)
	var my_row: Dictionary = _s.get("my_row", {})
	if not my_row.is_empty():
		var bilanz := Label.new()
		bilanz.text = "%d Punkte  ·  %d S / %d U / %d N  ·  %d:%d Tore" % [
			int(my_row.points), int(my_row.won), int(my_row.drawn), int(my_row.lost),
			int(my_row.gf), int(my_row.ga)]
		bilanz.add_theme_font_size_override("font_size", 13)
		bilanz.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		mine_texts.add_child(bilanz)
	var goal := Label.new()
	var goal_text := "Saisonziel „%s“: %s" % [_s.get("goal_text", ""),
		"erreicht ✓" if achieved else "verfehlt ✗"]
	if int(_s.get("bonus_paid", 0)) > 0:
		goal_text += "   ·   Erfolgsprämie %s" % Fmt.money(int(_s.bonus_paid))
	goal.text = goal_text
	goal.add_theme_font_size_override("font_size", 14)
	goal.add_theme_color_override("font_color", UITheme.ACCENT if achieved else UITheme.DANGER)
	mine_texts.add_child(goal)

	# Die beiden Meister
	var tables: Array = _s.get("tables", [])
	for t in tables:
		var rows: Array = t.get("rows", [])
		if rows.is_empty():
			continue
		row.add_child(_champion_card(str(t.league), rows[0]))
	return card

func _champion_card(league_name: String, top: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := UITheme.box(Color(0.13, 0.11, 0.04, 1.0), 10, MARK_COLORS.champion)
	sb.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", sb)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	card.add_child(line)
	line.add_child(UITheme.club_badge(str(top.short), Color(str(top.color)), 42))
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(texts)
	var head := Label.new()
	head.text = "🏆  Meister %s" % league_name
	head.add_theme_font_size_override("font_size", 12)
	head.add_theme_color_override("font_color", MARK_COLORS.champion)
	texts.add_child(head)
	var name_label := Label.new()
	name_label.text = str(top.name)
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 16)
	texts.add_child(name_label)
	var stats := Label.new()
	stats.text = "%d Punkte · %d:%d Tore" % [int(top.points), int(top.gf), int(top.ga)]
	stats.add_theme_font_size_override("font_size", 12)
	stats.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	texts.add_child(stats)
	return card

# ------------------------------------------------------------------ Tabellen

func _build_table_card(t: Dictionary) -> PanelContainer:
	var card := _card("📊 Abschlusstabelle %s" % str(t.league))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box: VBoxContainer = card.get_child(0)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	box.add_child(header)
	for col in [["", 20], ["", 22], ["Verein", 0], ["Sp", 26], ["S", 22], ["U", 22], ["N", 22], ["Tore", 50], ["Diff", 34], ["Pkt", 30]]:
		var h := Label.new()
		h.text = str(col[0])
		h.add_theme_font_size_override("font_size", 11)
		h.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		if int(col[1]) == 0:
			h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			h.custom_minimum_size = Vector2(int(col[1]), 0)
			h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_child(h)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var rows_box := VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 1)
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows_box)
	for row in t.get("rows", []):
		rows_box.add_child(_table_row(row))

	var legend := Label.new()
	legend.text = "🏆 Meister   ⬆ Aufstieg   ⬇ Abstieg"
	legend.add_theme_font_size_override("font_size", 11)
	legend.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	box.add_child(legend)
	return card

func _table_row(row: Dictionary) -> PanelContainer:
	var mark := str(row.get("mark", ""))
	var mine: bool = bool(row.get("mine", false))
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.16, 0.12, 1.0) if mine else Color(0.06, 0.09, 0.13, 1.0)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(3)
	if mark != "":
		# Farbiger Streifen links: Meister, Aufstieg, Abstieg
		sb.border_width_left = 4
		sb.border_color = MARK_COLORS[mark]
	if mine:
		sb.border_width_top = 1
		sb.border_width_bottom = 1
		sb.border_width_right = 1
		sb.border_color = UITheme.ACCENT if mark == "" else MARK_COLORS[mark]
	panel.add_theme_stylebox_override("panel", sb)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	panel.add_child(line)

	var pos := Label.new()
	pos.text = str(int(row.pos))
	pos.custom_minimum_size = Vector2(20, 0)
	pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pos.add_theme_font_size_override("font_size", 12)
	pos.add_theme_color_override("font_color", MARK_COLORS.get(mark, UITheme.TEXT_DIM))
	line.add_child(pos)
	line.add_child(UITheme.club_badge(str(row.short), Color(str(row.color)), 20))
	var name_label := Label.new()
	name_label.text = str(row.name)
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 12)
	if mine:
		name_label.add_theme_color_override("font_color", UITheme.ACCENT)
	line.add_child(name_label)
	for cell in [[str(int(row.played)), 26], [str(int(row.won)), 22], [str(int(row.drawn)), 22],
		[str(int(row.lost)), 22], ["%d:%d" % [int(row.gf), int(row.ga)], 50],
		["%+d" % int(row.diff), 34]]:
		line.add_child(_cell(str(cell[0]), int(cell[1]), UITheme.TEXT_DIM))
	var pts := _cell(str(int(row.points)), 30, UITheme.TEXT)
	pts.add_theme_font_size_override("font_size", 13)
	line.add_child(pts)
	return panel

# ------------------------------------------------------------------ Seitenspalte

func _build_side_column() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(430, 0)

	col.add_child(_movement_card())

	var card := _card("🥅 Torjäger, Noten & dein Kader")
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(card)
	var box: VBoxContainer = card.get_child(0)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 3)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)

	inner.add_child(_group_header("TORJÄGERLISTE"))
	var scorers: Array = _s.get("scorers", [])
	if scorers.is_empty():
		inner.add_child(_note("Kein Spieler hat getroffen."))
	for i in scorers.size():
		inner.add_child(_person_row(i + 1, scorers[i], "%d Tore" % int(scorers[i].goals),
			UITheme.ACCENT, "%d Spiele" % int(scorers[i].matches)))

	inner.add_child(_group_header("BESTE DURCHSCHNITTSNOTEN"))
	var ratings: Array = _s.get("ratings", [])
	if ratings.is_empty():
		inner.add_child(_note("Zu wenige Einsätze für eine Wertung."))
	for i in ratings.size():
		inner.add_child(_person_row(i + 1, ratings[i], ("%.2f" % float(ratings[i].note)).replace(".", ","),
			PlayerToken.note_color(float(ratings[i].note)), "%d Spiele" % int(ratings[i].matches)))

	inner.add_child(_group_header("DEIN KADER IN DIESER SAISON"))
	var squad: Array = _s.get("my_squad", [])
	if squad.is_empty():
		inner.add_child(_note("Keine Einsätze erfasst."))
	for entry in squad:
		var extra := "%d Sp." % int(entry.matches)
		if int(entry.goals) > 0:
			extra += " · %d Tore" % int(entry.goals)
		inner.add_child(_person_row(0, entry, ("%.2f" % float(entry.note)).replace(".", ","),
			PlayerToken.note_color(float(entry.note)), extra))

	var retired: Array = _s.get("retired", [])
	if not retired.is_empty():
		inner.add_child(_group_header("KARRIEREENDE IN DEINEM KADER"))
		for entry in retired:
			inner.add_child(_note("👋  %s" % str(entry)))
	var notable: Array = _s.get("retired_notable", [])
	if not notable.is_empty():
		inner.add_child(_group_header("PROMINENTE RÜCKTRITTE"))
		for entry in notable:
			inner.add_child(_note("👋  %s" % str(entry)))
	var youth: Array = _s.get("new_youth", [])
	if not youth.is_empty():
		inner.add_child(_group_header("AUS DEINER JUGEND AUFGERÜCKT"))
		for entry in youth:
			inner.add_child(_note("🌱  %s" % str(entry)))
	return col

## Auf- und Abstieg auf einen Blick.
func _movement_card() -> PanelContainer:
	var card := _card("🔁 Auf- und Abstieg")
	var box: VBoxContainer = card.get_child(0)
	var up: Array = _s.get("promoted", [])
	var down: Array = _s.get("relegated", [])
	var up_label := Label.new()
	up_label.text = "⬆  Aufsteiger: %s" % (", ".join(up) if not up.is_empty() else "–")
	up_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	up_label.add_theme_font_size_override("font_size", 13)
	up_label.add_theme_color_override("font_color", MARK_COLORS.promoted)
	box.add_child(up_label)
	var down_label := Label.new()
	down_label.text = "⬇  Absteiger: %s" % (", ".join(down) if not down.is_empty() else "–")
	down_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	down_label.add_theme_font_size_override("font_size", 13)
	down_label.add_theme_color_override("font_color", MARK_COLORS.relegated)
	box.add_child(down_label)
	return card

# ------------------------------------------------------------------ Bausteine

func _card(title: String) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := UITheme.box(UITheme.SURFACE, 12, UITheme.BORDER)
	sb.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", sb)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 5)
	card.add_child(inner)
	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", UITheme.ACCENT)
	inner.add_child(head)
	return card

func _group_header(text: String) -> Label:
	var l := Label.new()
	l.text = "  " + text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", UITheme.ACCENT)
	l.add_theme_stylebox_override("normal", UITheme.box(Color(0.08, 0.12, 0.10, 1.0), 4))
	return l

func _note(text: String) -> Label:
	var l := Label.new()
	l.text = "  " + text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	return l

## Zeile für Torjäger, Noten und Kader: Rang, Nation, Name, Verein, Kennzahl.
func _person_row(rank: int, entry: Dictionary, value: String, value_color: Color, extra: String) -> PanelContainer:
	var mine: bool = bool(entry.get("mine", false)) or not entry.has("short")
	var panel := PanelContainer.new()
	var sb := UITheme.box(Color(0.10, 0.16, 0.12, 1.0) if mine else Color(0.06, 0.09, 0.13, 1.0), 4)
	sb.set_content_margin_all(3)
	panel.add_theme_stylebox_override("panel", sb)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 5)
	panel.add_child(line)
	if rank > 0:
		var r := Label.new()
		r.text = "%d." % rank
		r.custom_minimum_size = Vector2(24, 0)
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		r.add_theme_font_size_override("font_size", 12)
		r.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		line.add_child(r)
	line.add_child(UITheme.mini_pill(str(entry.pos),
		PlayerToken.GROUP_COLORS[PlayerData.GROUP_OF[str(entry.pos)]].darkened(0.3), Color.WHITE, 32))
	line.add_child(Flags.icon(str(entry.nat), 13))
	var name_label := Label.new()
	name_label.text = str(entry.name)
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 12)
	line.add_child(name_label)
	if entry.has("short"):
		line.add_child(UITheme.club_badge(str(entry.short), Color(str(entry.color)), 18))
	var extra_label := Label.new()
	extra_label.text = extra
	extra_label.custom_minimum_size = Vector2(84, 0)
	extra_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	extra_label.add_theme_font_size_override("font_size", 11)
	extra_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	line.add_child(extra_label)
	var value_label := Label.new()
	value_label.text = value
	value_label.custom_minimum_size = Vector2(52, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 13)
	value_label.add_theme_color_override("font_color", value_color)
	line.add_child(value_label)
	return panel

func _cell(text: String, width: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(width, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", color)
	return l

func _on_continue() -> void:
	# Der Hub zeigt danach die Angebote anderer Vereine (Karrieremodus)
	Game.season_just_rolled = true
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
