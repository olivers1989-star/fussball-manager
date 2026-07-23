extends Node
## Prüft den kalendarischen Saisonübergang: Die Spielzeit läuft vom 1. Juli bis
## zum 30. Juni. Nach dem letzten Spieltag läuft der Kalender durch die
## Sommerpause weiter, erst der 1. Juli löst den Abschluss aus.

func _ready() -> void:
	print("=== SAISONWECHSEL-TEST START ===")
	Game.setup = {"name": "Testtrainer", "mode": "vereinsauswahl", "origin": "Dortmund",
		"skills": {"taktik": 3, "training": 3, "motivation": 3, "verhandlung": 1, "jugend": 2}}
	Game.new_game(2)

	# --- Saisonrahmen: Start am 1. Juli, letzter Spieltag im Mai
	var year: int = int(Game.world.season_year)
	var start := Time.get_datetime_dict_from_unix_time(ScheduleGen.season_start(year))
	assert(int(start.day) == 1 and int(start.month) == 7,
		"Saisonstart ist %02d.%02d. statt 01.07." % [int(start.day), int(start.month)])
	var dates: Array = Game.world.matchday_dates
	assert(dates.size() == ScheduleGen.total_rounds(),
		"Kalender hat %d statt %d Spieltagstermine" % [dates.size(), ScheduleGen.total_rounds()])
	var last := Time.get_datetime_dict_from_unix_time(int(dates[dates.size() - 1]))
	assert(int(last.month) == 5 or (int(last.month) == 6 and int(last.day) <= 7),
		"Letzter Spieltag liegt am %02d.%02d. – erwartet Ende Mai" % [int(last.day), int(last.month)])
	var season_end := Time.get_datetime_dict_from_unix_time(ScheduleGen.season_end(year))
	assert(int(season_end.day) == 30 and int(season_end.month) == 6,
		"Saisonende ist %02d.%02d. statt 30.06." % [int(season_end.day), int(season_end.month)])
	print("Saison %d/%02d: 01.07. bis 30.06., 1. Spieltag %02d.%02d., letzter %02d.%02d." % [
		year, (year + 1) % 100,
		int(Time.get_datetime_dict_from_unix_time(int(Game.world.matchday_dates[0])).day),
		int(Time.get_datetime_dict_from_unix_time(int(Game.world.matchday_dates[0])).month),
		int(last.day), int(last.month)])

	# --- Saison durchspielen
	var guard := 0
	while not Game.season_over() and guard < 500:
		guard += 1
		Game.play_matchday()
	assert(Game.season_over(), "Saison wurde nicht zu Ende gespielt")
	assert(not Game.season_rollover_due(), "Nach dem letzten Spieltag ist der Abschluss noch nicht faellig")

	# --- Sommerpause: Der Kalender laeuft weiter bis zum 1. Juli
	var days := 0
	while not Game.season_rollover_due() and days < 120:
		var before: int = Game.date_unix()
		Game.advance_day()
		assert(Game.date_unix() > before, "Der Kalender steht in der Sommerpause still")
		days += 1
	assert(Game.season_rollover_due(), "Der 1. Juli wurde nie erreicht")
	var today := Game.date_dict()
	assert(int(today.day) == 1 and int(today.month) == 7,
		"Abschluss faellig am %02d.%02d. statt 01.07." % [int(today.day), int(today.month)])
	print("Sommerpause: %d Tage vom letzten Spieltag bis zum 1. Juli" % days)
	assert(Game.advance_day().news.is_empty(), "Der Kalender laeuft ueber den 1. Juli hinaus")

	# --- Abschluss: Daten muessen VOR der Umstellung erfasst sein
	var old_year: int = int(Game.world.season_year)
	var champion_before: String = Game.club(Game.world.leagues[1].table()[0].club_id).name
	var s := Game.end_season()

	assert(str(s.champion1) == champion_before, "Meister stimmt nicht mit der Abschlusstabelle ueberein")
	var tables: Array = s.tables
	assert(tables.size() == 8, "Es fehlen Abschlusstabellen (%d von 8)" % tables.size())
	for t in tables:
		var rows: Array = t.rows
		var expect_clubs: int = 20 if int(t.league_id) == 3 else 18
		var expect_games: int = 38 if int(t.league_id) == 3 else 34
		assert(rows.size() == expect_clubs, "%s hat %d statt %d Zeilen" % [t.league, rows.size(), expect_clubs])
		var points_before := 999
		for row in rows:
			assert(int(row.played) == expect_games,
				"%s hat %d statt %d Spiele" % [row.name, int(row.played), expect_games])
			assert(int(row.points) <= points_before, "Tabelle ist nicht sortiert")
			points_before = int(row.points)
		assert(str(rows[0].mark) == "champion", "Platz 1 ist nicht als Meister markiert")

	# Erste Liga: 17./18. direkt runter, 16. in die Relegation
	assert(str(tables[0].rows[16].mark) == "relegated", "Platz 17 der Ersten Liga ist kein Absteiger")
	assert(str(tables[0].rows[15].mark) == "playoff_down", "Platz 16 der Ersten Liga spielt keine Relegation")
	# Zweite Liga: 1./2. hoch, 3. Relegation, 17./18. runter, 16. Relegation
	assert(str(tables[1].rows[1].mark) == "promoted", "Platz 2 der Zweiten Liga ist kein Aufsteiger")
	assert(str(tables[1].rows[2].mark) == "playoff_up", "Platz 3 der Zweiten Liga spielt keine Relegation")
	assert(str(tables[1].rows[15].mark) == "playoff_down", "Platz 16 der Zweiten Liga spielt keine Relegation")
	# Dritte Liga: 1./2. hoch, 3. Relegation, 17.–20. runter
	assert(str(tables[2].rows[1].mark) == "promoted", "Platz 2 der Dritten Liga ist kein Aufsteiger")
	assert(str(tables[2].rows[2].mark) == "playoff_up", "Platz 3 der Dritten Liga spielt keine Relegation")
	for i in range(16, 20):
		assert(str(tables[2].rows[i].mark) == "relegated",
			"Platz %d der Dritten Liga ist kein Absteiger" % (i + 1))
	# Regionalliga: fünf Staffeln, keine Absteiger, der Meister spielt um den Aufstieg
	var staffeln := 0
	for t in tables:
		if bool(t.playable):
			continue
		staffeln += 1
		assert(str(t.rows[0].mark) == "champion", "%s hat keinen Meister" % t.league)
		for row in t.rows:
			assert(str(row.mark) != "relegated", "%s darf keine Absteiger haben" % t.league)
	assert(staffeln == 5, "Es fehlen Regionalliga-Staffeln (%d von 5)" % staffeln)

	# Relegation: zwei Duelle um den Klassenerhalt plus die Aufstiegsrelegation,
	# jeweils über Hin- und Rückspiel
	var playoffs: Array = s.playoffs
	assert(playoffs.size() == 3, "Es fehlen Relegationsduelle (%d von 3)" % playoffs.size())
	var kinds := {}
	for po in playoffs:
		kinds[str(po.kind)] = int(kinds.get(str(po.kind), 0)) + 1
		assert(str(po.winner) != "", "Relegationsduell ohne Sieger")
		# Gesamtstand muss der Summe beider Spiele entsprechen
		assert(int(po.total_a) == int(po.leg1_a) + int(po.leg2_a),
			"Gesamtstand A stimmt nicht: %d statt %d" % [int(po.total_a), int(po.leg1_a) + int(po.leg2_a)])
		assert(int(po.total_b) == int(po.leg1_b) + int(po.leg2_b),
			"Gesamtstand B stimmt nicht: %d statt %d" % [int(po.total_b), int(po.leg1_b) + int(po.leg2_b)])
		# Verlängerung genau dann, wenn es nach zwei Spielen gleich stand
		assert(bool(po.extra_time) == (int(po.reg_a) == int(po.reg_b)),
			"Verlaengerung passt nicht zum Stand nach zwei Spielen")
		if bool(po.shootout):
			assert(bool(po.extra_time), "Elfmeterschießen ohne vorherige Verlängerung")
			assert(int(po.total_a) == int(po.total_b), "Elfmeterschießen trotz Vorsprung")
			assert(int(po.pens_a) != int(po.pens_b), "Elfmeterschießen ohne Entscheidung")
		# Der Sieger muss zum Gesamtstand passen
		var expect: String = str(po.a) if bool(po.a_wins) else str(po.b)
		assert(str(po.winner) == expect, "Sieger passt nicht zum Ausgang")
		print("%s: %s %d:%d %s (Hin %d:%d, Rück %d:%d%s) → %s" % [
			po.title, po.a, int(po.total_a), int(po.total_b), po.b,
			int(po.leg1_b), int(po.leg1_a), int(po.leg2_a), int(po.leg2_b),
			(", n. V." if bool(po.extra_time) else "") + (", i. E. %d:%d" % [int(po.pens_a), int(po.pens_b)] if bool(po.shootout) else ""),
			po.winner])
	assert(int(kinds.get("relegation", 0)) == 2, "Es fehlen Relegationsduelle zum Klassenerhalt")
	assert(int(kinds.get("aufstiegsrunde", 0)) == 1, "Die Aufstiegsrelegation der Regionalliga fehlt")

	# Bilanz: Jede Liga behält ihre Größe
	assert(s.promoted.size() == s.relegated.size(),
		"Erste Liga: %d rauf, %d runter" % [s.promoted.size(), s.relegated.size()])

	var scorers: Array = s.scorers
	assert(not scorers.is_empty(), "Torjaegerliste ist leer")
	assert(int(scorers[0].goals) >= int(scorers[scorers.size() - 1].goals), "Torjaeger nicht sortiert")
	print("Torschuetzenkoenig: %s (%s) mit %d Toren" % [scorers[0].name, scorers[0].short, int(scorers[0].goals)])
	var ratings: Array = s.ratings
	if not ratings.is_empty():
		print("Beste Note: %s (%s) mit %.2f" % [ratings[0].name, ratings[0].short, float(ratings[0].note)])
	assert(not s.my_row.is_empty(), "Eigene Tabellenzeile fehlt")
	assert(int(s.my_row.played) == 34, "Eigene Bilanz unvollstaendig")

	# --- Neue Saison steht bereit
	assert(int(Game.world.season_year) == old_year + 1, "Saisonjahr wurde nicht erhoeht")
	assert(Game.matchday() == 0, "Spieltagszaehler nicht zurueckgesetzt")
	assert(not Game.season_rollover_due(), "Neue Saison meldet sofort wieder Abschluss")
	var d := Game.date_dict()
	assert(int(d.day) == 1 and int(d.month) == 7, "Neue Saison startet nicht am 1. Juli")
	assert(str(Game.day_kind(Game.date_unix()).kind) == "preseason",
		"1. Juli gilt als %s statt Vorbereitung" % Game.day_kind(Game.date_unix()).kind)
	for lg_id in Game.world.leagues:
		if lg_id == 0:
			continue   # Oberliga: Warteschlange ohne Spielbetrieb
		var lg: LeagueData = Game.world.leagues[lg_id]
		var want_clubs: int = 20 if lg_id == 3 else 18
		var want_games: int = 380 if lg_id == 3 else 306
		assert(lg.club_ids.size() == want_clubs, "%s hat %d Vereine" % [lg.name, lg.club_ids.size()])
		assert(lg.fixtures.size() == want_games, "%s hat %d Partien" % [lg.name, lg.fixtures.size()])
		assert(lg.own_rounds().size() == (38 if lg_id == 3 else 34),
			"%s hat %d Spieltage" % [lg.name, lg.own_rounds().size()])
		for f in lg.fixtures:
			assert(not f.played, "Neuer Spielplan enthaelt bereits gespielte Partien")
	# Aufsteiger stehen jetzt wirklich in der Ersten Liga
	for club_name in s.promoted:
		var found := false
		for cid in Game.world.leagues[1].club_ids:
			if Game.club(cid).name == club_name:
				found = true
		assert(found, "Aufsteiger %s fehlt in der Ersten Liga" % club_name)
	print("Neue Saison %s ab %s" % [Game.season_label(), Game.date_label()])
	_check_two_legged_ties()
	print("=== SAISONWECHSEL-TEST OK ===")
	get_tree().quit(0)

## Prüft die Regel für Relegationsduelle über viele Wiederholungen: Es zählt
## der Gesamtstand beider Spiele; nur bei Gleichstand folgt die Verlängerung im
## Rückspiel, und erst danach darf das Elfmeterschießen entscheiden.
func _check_two_legged_ties() -> void:
	# Das ausgeglichenste Paar der Ersten Liga – bei ungleichen Mannschaften
	# gäbe es kaum Gleichstände und die Verlängerung käme nie vor
	var pool: Array = Game.world.leagues[1].club_ids
	var a: ClubData = Game.club(int(pool[0]))
	var b: ClubData = Game.club(int(pool[1]))
	var best_gap := 9999
	for i in pool.size():
		for j in range(i + 1, pool.size()):
			var ca := Game.club(int(pool[i]))
			var cb := Game.club(int(pool[j]))
			var gap: int = absi(ca.team_strength(Game.world.players) - cb.team_strength(Game.world.players))
			if gap < best_gap:
				best_gap = gap
				a = ca
				b = cb
	print("Testpaarung: %s gegen %s (Staerkeunterschied %d)" % [a.short_name, b.short_name, best_gap])
	var extra := 0
	var shootouts := 0
	var rounds := 60
	for i in rounds:
		# Vor jedem Duell beide Kader frisch machen – sonst sind die Mannschaften
		# nach vielen Wiederholungen ausgelaugt und verletzt
		for c in [a, b]:
			for pid in c.player_ids:
				var p: PlayerData = Game.world.players[pid]
				p.condition = 100.0
				p.injury_matchdays = 0
				p.suspended_matchdays = 0
		var r := Game._play_two_legs(a, b)
		var regulation_tie: bool = int(r.reg_a) == int(r.reg_b)
		if not bool(r.extra_time):
			assert(not regulation_tie, "Gleichstand ohne Verlaengerung")
			assert(int(r.total_a) != int(r.total_b), "Kein Sieger ohne Verlaengerung")
		else:
			extra += 1
			assert(regulation_tie, "Verlaengerung trotz Vorsprung nach zwei Spielen")
		if bool(r.shootout):
			shootouts += 1
			assert(bool(r.extra_time), "Elfmeterschiessen ohne Verlaengerung")
			assert(int(r.total_a) == int(r.total_b), "Elfmeterschiessen trotz Vorsprung")
			assert(int(r.pens_a) != int(r.pens_b), "Elfmeterschiessen ohne Entscheidung")
		assert(str(r.winner) == (str(r.a) if bool(r.a_wins) else str(r.b)), "Sieger passt nicht")
	print("Relegationsregel geprueft: %d Duelle, davon %d mit Verlaengerung und %d mit Elfmeterschiessen" % [
		rounds, extra, shootouts])

	# Die Verlängerung selbst deterministisch pruefen: zweimal 15 Minuten dran
	var sim := MatchSim.new()
	sim.is_friendly = true
	sim.knockout = true
	sim.setup(a, b, Game.world.players)
	sim.run_full()
	assert(sim.minute == 90 and sim.finished, "K.-o.-Spiel endet bei Minute %d" % sim.minute)
	var goals_before: int = sim.hg + sim.ag
	sim.run_extra_time()
	assert(sim.minute == 120 and sim.finished, "Verlaengerung endet bei Minute %d" % sim.minute)
	assert(sim.hg + sim.ag >= goals_before, "Tore sind in der Verlaengerung verschwunden")
	print("Verlaengerung geprueft: 90 -> 120 Minuten, Endstand %d:%d" % [sim.hg, sim.ag])
