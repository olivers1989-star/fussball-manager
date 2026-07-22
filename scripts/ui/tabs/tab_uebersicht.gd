class_name TabUebersicht
extends TabBase
## Übersicht als Dashboard: Nächstes Spiel, Teamstatus, Tabellenausschnitt,
## Saisonziel-Kurs, Torschützen, Nachrichten und letzte Ergebnisse.

var _welcome: Label
var _match_inner: VBoxContainer
var _status_rows := {}
var _table_box: VBoxContainer
var _goal_rows := {}
var _goal_status: Label
var _scorers: ItemList
var _news: ItemList
var _results: ItemList

func _init() -> void:
	super()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	_welcome = Label.new()
	_welcome.add_theme_font_size_override("font_size", 20)
	_welcome.add_theme_color_override("font_color", UITheme.ACCENT)
	box.add_child(_welcome)

	# ---------- Reihe 1: Nächstes Spiel + Teamstatus
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 16)
	box.add_child(row1)

	var match_box := _make_card("Nächstes Spiel", row1, 2.0)
	_match_inner = VBoxContainer.new()
	_match_inner.add_theme_constant_override("separation", 8)
	match_box.add_child(_match_inner)

	var status_box := _make_card("Teamstatus", row1, 1.0)
	var status_grid := GridContainer.new()
	status_grid.columns = 2
	status_grid.add_theme_constant_override("h_separation", 20)
	status_grid.add_theme_constant_override("v_separation", 6)
	status_box.add_child(status_grid)
	for entry in [["cond", "Ø Frische"], ["form", "Ø Form"], ["fit", "Einsatzbereit"], ["injured", "Verletzt"], ["suspended", "Gesperrt"]]:
		var key := Label.new()
		key.text = entry[1] + ":"
		key.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		status_grid.add_child(key)
		var value := Label.new()
		value.add_theme_font_size_override("font_size", 18)
		status_grid.add_child(value)
		_status_rows[entry[0]] = value

	# ---------- Reihe 2: Tabelle + Saisonziel/Finanzen + Torschützen
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 16)
	box.add_child(row2)

	var table_card := _make_card("Tabelle", row2, 1.0)
	_table_box = VBoxContainer.new()
	_table_box.add_theme_constant_override("separation", 4)
	table_card.add_child(_table_box)

	var goal_box := _make_card("Saisonziel & Finanzen", row2, 1.0)
	var goal_grid := GridContainer.new()
	goal_grid.columns = 2
	goal_grid.add_theme_constant_override("h_separation", 20)
	goal_grid.add_theme_constant_override("v_separation", 6)
	goal_box.add_child(goal_grid)
	for entry in [["goal", "Ziel"], ["pos", "Aktuell"], ["budget", "Budget"], ["salaries", "Gehälter"]]:
		var key := Label.new()
		key.text = entry[1] + ":"
		key.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		goal_grid.add_child(key)
		var value := Label.new()
		value.add_theme_font_size_override("font_size", 17)
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		goal_grid.add_child(value)
		_goal_rows[entry[0]] = value
	_goal_status = Label.new()
	_goal_status.add_theme_font_size_override("font_size", 18)
	goal_box.add_child(_goal_status)

	var scorer_box := _make_card("Beste Torschützen", row2, 1.0)
	_scorers = ItemList.new()
	_scorers.custom_minimum_size = Vector2(0, 150)
	_scorers.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scorer_box.add_child(_scorers)

	# ---------- Reihe 3: Aktuelles + Letzte Spiele
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 16)
	row3.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(row3)

	var news_box := _make_card("Aktuelles", row3, 2.0)
	_news = ItemList.new()
	_news.size_flags_vertical = Control.SIZE_EXPAND_FILL
	news_box.add_child(_news)

	var results_box := _make_card("Letzte Spiele", row3, 1.0)
	_results = ItemList.new()
	_results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results_box.add_child(_results)

func _make_card(title: String, parent: BoxContainer, ratio: float) -> VBoxContainer:
	var panel := UITheme.card()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	panel.add_child(inner)
	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 17)
	head.add_theme_color_override("font_color", UITheme.ACCENT)
	inner.add_child(head)
	return inner

# ------------------------------------------------------------------ Refresh

func refresh() -> void:
	var c := Game.my_club()
	_welcome.text = "%s  ·  Willkommen, %s – %s (%s)" % [
		Game.date_label(), Game.manager_name, c.name, Game.my_league().name]
	_refresh_match_card(c)
	_refresh_status(c)
	_refresh_table(c)
	_refresh_goal(c)
	_refresh_lists(c)

func _refresh_match_card(c: ClubData) -> void:
	while _match_inner.get_child_count() > 0:
		var child := _match_inner.get_child(0)
		_match_inner.remove_child(child)
		child.free()
	var f := Game.next_fixture(c.id)
	if f.is_empty():
		var done := Label.new()
		done.text = "Die Saison ist beendet – schließe sie über den Button oben rechts ab."
		done.add_theme_font_size_override("font_size", 18)
		_match_inner.add_child(done)
		return
	var home_club := Game.club(int(f.home))
	var away_club := Game.club(int(f.away))

	var duel := HBoxContainer.new()
	duel.alignment = BoxContainer.ALIGNMENT_CENTER
	duel.add_theme_constant_override("separation", 16)
	_match_inner.add_child(duel)
	duel.add_child(UITheme.club_badge(home_club.short_name, Color(home_club.color), 48))
	var home_label := Label.new()
	home_label.text = home_club.name
	home_label.add_theme_font_size_override("font_size", 22)
	duel.add_child(home_label)
	var vs := Label.new()
	vs.text = "vs"
	vs.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	duel.add_child(vs)
	var away_label := Label.new()
	away_label.text = away_club.name
	away_label.add_theme_font_size_override("font_size", 22)
	duel.add_child(away_label)
	duel.add_child(UITheme.club_badge(away_club.short_name, Color(away_club.color), 48))

	var when := Label.new()
	var d := Time.get_datetime_dict_from_unix_time(Game.matchday_date(Game.matchday()))
	when.text = "Spieltag %d  ·  %s, %02d.%02d.%d  ·  %s" % [
		Game.matchday() + 1, Game.WEEKDAYS[int(d.weekday)], int(d.day), int(d.month), int(d.year), home_club.stadium]
	when.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	when.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	_match_inner.add_child(when)

	for club in [home_club, away_club]:
		var form_row := HBoxContainer.new()
		form_row.alignment = BoxContainer.ALIGNMENT_CENTER
		form_row.add_theme_constant_override("separation", 6)
		_match_inner.add_child(form_row)
		var info := Label.new()
		info.text = "%s: Platz %d · Mannschaftsstärke %d · Form" % [
			club.short_name, Game.league(club.league_id).position_of(club.id),
			club.team_strength(Game.world.players)]
		info.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		form_row.add_child(info)
		var recent := Game.league(club.league_id).fixtures_of_club(club.id).filter(func(x): return x.played)
		var last5 := recent.slice(maxi(0, recent.size() - 5))
		if last5.is_empty():
			form_row.add_child(UITheme.pill("–", UITheme.SURFACE2, UITheme.TEXT_DIM))
		for x in last5:
			var mine_home: bool = int(x.home) == club.id
			var gf: int = int(x.hg) if mine_home else int(x.ag)
			var ga: int = int(x.ag) if mine_home else int(x.hg)
			if gf > ga:
				form_row.add_child(UITheme.pill("S", Color("#166534")))
			elif gf == ga:
				form_row.add_child(UITheme.pill("U", Color("#475569")))
			else:
				form_row.add_child(UITheme.pill("N", Color("#7f1d1d")))

func _refresh_status(c: ClubData) -> void:
	var squad := c.players(Game.world.players)
	var cond_sum := 0.0
	var form_sum := 0.0
	var injured := 0
	var suspended := 0
	for p in squad:
		cond_sum += p.condition
		form_sum += p.form
		if p.is_injured():
			injured += 1
		elif p.is_suspended():
			suspended += 1
	var avg_cond := cond_sum / squad.size()
	_status_rows.cond.text = "%d %%" % int(avg_cond)
	_status_rows.cond.add_theme_color_override("font_color",
		UITheme.ACCENT if avg_cond >= 85 else (UITheme.WARN if avg_cond >= 65 else UITheme.DANGER))
	var avg_form := form_sum / squad.size()
	_status_rows.form.text = Fmt.form_icon(avg_form)
	_status_rows.form.add_theme_color_override("font_color", Fmt.form_color(avg_form))
	_status_rows.fit.text = "%d von %d" % [squad.size() - injured - suspended, squad.size()]
	_status_rows.injured.text = str(injured)
	_status_rows.injured.add_theme_color_override("font_color", UITheme.DANGER if injured > 0 else UITheme.TEXT)
	_status_rows.suspended.text = str(suspended)
	_status_rows.suspended.add_theme_color_override("font_color", UITheme.WARN if suspended > 0 else UITheme.TEXT)

func _refresh_table(c: ClubData) -> void:
	while _table_box.get_child_count() > 0:
		var child := _table_box.get_child(0)
		_table_box.remove_child(child)
		child.free()
	var table := Game.my_league().table()
	var my_pos := Game.my_league().position_of(c.id)
	var start := clampi(my_pos - 3, 0, maxi(0, table.size() - 5))
	for i in range(start, mini(start + 5, table.size())):
		var row: Dictionary = table[i]
		var club := Game.club(int(row.club_id))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		_table_box.add_child(line)
		var pos_label := Label.new()
		pos_label.text = "%2d." % (i + 1)
		pos_label.custom_minimum_size = Vector2(32, 0)
		line.add_child(pos_label)
		var name_label := Label.new()
		name_label.text = club.name
		name_label.clip_contents = true
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		var pts := Label.new()
		pts.text = "%d P." % int(row.points)
		line.add_child(pts)
		if club.id == c.id:
			for l in [pos_label, name_label, pts]:
				l.add_theme_color_override("font_color", UITheme.ACCENT)
			name_label.add_theme_font_size_override("font_size", 18)

func _refresh_goal(c: ClubData) -> void:
	var my_pos := Game.my_league().position_of(c.id)
	var goal_pos := int(Game.season_goal.get("position", 18))
	_goal_rows.goal.text = Game.season_goal.get("text", "–")
	_goal_rows.pos.text = "Platz %d" % my_pos
	_goal_rows.budget.text = Fmt.money(c.budget)
	_goal_rows.salaries.text = "%s/Monat" % Fmt.money(c.salaries_per_month(Game.world.players) + Game.coach_salary)
	if Game.matchday() == 0:
		_goal_status.text = "Saison startet – alles ist möglich!"
		_goal_status.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	elif my_pos <= goal_pos:
		_goal_status.text = "✓ Auf Kurs"
		_goal_status.add_theme_color_override("font_color", UITheme.ACCENT)
	else:
		_goal_status.text = "✗ Hinter dem Plan (%d Plätze)" % (my_pos - goal_pos)
		_goal_status.add_theme_color_override("font_color", UITheme.DANGER)

func _refresh_lists(c: ClubData) -> void:
	_scorers.clear()
	var squad := c.players(Game.world.players)
	squad.sort_custom(func(a, b): return a.goals_season > b.goals_season)
	for i in mini(5, squad.size()):
		var p: PlayerData = squad[i]
		if p.goals_season == 0 and i > 0:
			break
		_scorers.add_item("%d Tore – %s (%s)" % [p.goals_season, p.full_name(), p.pos])

	_news.clear()
	if Game.news.is_empty():
		_news.add_item("Noch keine Meldungen – lass die Tage laufen!")
		_news.set_item_disabled(0, true)
	for i in mini(20, Game.news.size()):
		var e: Dictionary = Game.news[i]
		_news.add_item("%s – %s" % [e.day, e.text])

	_results.clear()
	var played := Game.my_league().fixtures_of_club(c.id).filter(func(x): return x.played)
	played.reverse()
	for i in mini(8, played.size()):
		var x: Dictionary = played[i]
		var h := Game.club(int(x.home))
		var a := Game.club(int(x.away))
		var mine_home := h.id == c.id
		var my_goals: int = int(x.hg) if mine_home else int(x.ag)
		var their_goals: int = int(x.ag) if mine_home else int(x.hg)
		var icon := "✅" if my_goals > their_goals else ("➖" if my_goals == their_goals else "❌")
		_results.add_item("%s  ST %d: %s %d:%d %s" % [icon, int(x.round) + 1, h.short_name, int(x.hg), int(x.ag), a.short_name])
	if played.is_empty():
		_results.add_item("Noch keine Spiele absolviert.")
		_results.set_item_disabled(0, true)