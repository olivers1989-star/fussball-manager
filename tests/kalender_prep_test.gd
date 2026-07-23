extends Node
## Prüft, dass die Spielvorbereitung nur vor einem EIGENEN Spiel kommt.
## An englischen Wochen (Dienstag) spielen nur die 20er-Ligen – ein Erstligist
## darf dann weder einen Spieltag noch eine Spielvorbereitung angezeigt bekommen.
## Prüft außerdem die Ersatzbank auf 9 Plätze.

func _ready() -> void:
	print("=== KALENDER-PREP-TEST START ===")
	# Erstligist (spielt nur samstags)
	Game.setup = {"name": "Test", "mode": "vereinsauswahl", "origin": "Dortmund",
		"skills": {"taktik": 3, "training": 3, "motivation": 3, "verhandlung": 1, "jugend": 2}}
	var bvw := -1
	Game.new_game(1)
	for cid in Game.world.clubs:
		if Game.world.clubs[cid].short_name == "BVW":
			bvw = cid
	Game.new_game(bvw)

	# Ersatzbank: 9 Plätze
	assert(ClubData.BENCH_SIZE == 9, "Ersatzbank ist %d statt 9" % ClubData.BENCH_SIZE)
	var bench := Game.my_club().match_bench(Game.world.players, Game.my_club().match_lineup(Game.world.players))
	assert(bench.size() == 9, "Match-Bank hat %d statt 9 Spieler" % bench.size())
	print("Ersatzbank: %d Plätze" % ClubData.BENCH_SIZE)

	# Alle 38 Spieltagstermine durchgehen: an Terminen, an denen die Erste Liga
	# NICHT spielt (englische Wochen), darf der Vortag KEINE prep sein.
	var l1: LeagueData = Game.world.leagues[1]
	var prep_days := 0
	var false_prep := 0
	var midweek_rounds: Array = []
	for r in Game.world.matchday_dates.size():
		if not l1.plays_in_round(r):
			midweek_rounds.append(r)
	assert(midweek_rounds.size() == 4, "Erwartet 4 englische Wochen, gefunden %d" % midweek_rounds.size())

	# Für jeden englischen Woche-Termin: der Vortag darf kein prep sein
	for r in midweek_rounds:
		var day_before: int = int(Game.world.matchday_dates[r]) - Game.DAY
		var kind := str(Game.day_kind(day_before).kind)
		if kind == "prep":
			false_prep += 1
			print("  FEHLER: prep am Vortag der englischen Woche (Runde %d)" % r)
	assert(false_prep == 0, "%d falsche Spielvorbereitungen an englischen Wochen" % false_prep)
	print("Keine falsche Spielvorbereitung an den 4 englischen Wochen")

	# Positivkontrolle: der Vortag eines echten Erste-Liga-Spieltags IST prep
	var own_rounds := l1.own_rounds()
	var checked := 0
	for r in own_rounds:
		var day_before: int = int(Game.world.matchday_dates[r]) - Game.DAY
		if str(Game.day_kind(day_before).kind) == "prep":
			prep_days += 1
		checked += 1
	assert(prep_days == checked, "Nur %d von %d Erste-Liga-Vortagen sind Spielvorbereitung" % [prep_days, checked])
	print("Alle %d Vortage echter Spieltage sind Spielvorbereitung" % checked)

	# Ganzen Kalender durchlaufen und prep-Meldungen zählen: nie mehr prep als
	# eigene Spieltage
	Game.new_game(bvw)
	var preps := 0
	var guard := 0
	while not Game.season_over() and guard < 400:
		guard += 1
		if Game.is_matchday_today():
			if Game.my_match_today():
				Game.finish_matchday(Game.start_matchday())
			else:
				Game.simulate_matchday_without_me()
			continue
		var r := Game.advance_day()
		if r.get("prep", false):
			preps += 1
			assert(Game.days_until_matchday() == 1, "prep, aber nächstes eigenes Spiel nicht morgen")
	assert(preps <= own_rounds.size(),
		"%d Spielvorbereitungen bei nur %d eigenen Spieltagen" % [preps, own_rounds.size()])
	print("Saison durchlaufen: %d Spielvorbereitungen, %d eigene Spieltage" % [preps, own_rounds.size()])

	print("=== KALENDER-PREP-TEST OK ===")
	get_tree().quit(0)
