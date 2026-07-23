extends Node
## Prüft die Bundesland-Zuordnung: Jeder Verein hat ein Bundesland und eine
## stabile ID, die Regionalliga-Staffeln passen zu ihren Bundesländern, und
## Absteiger aus der Dritten Liga landen in der richtigen Staffel – auch wenn
## zwei Vereine aus demselben Bundesland absteigen.

func _ready() -> void:
	print("=== BUNDESLAND-TEST START ===")
	Game.setup = {"name": "Testtrainer", "mode": "vereinsauswahl", "origin": "Dortmund",
		"skills": {"taktik": 3, "training": 3, "motivation": 3, "verhandlung": 1, "jugend": 2}}
	Game.new_game(2)

	# --- Stammdaten: ID und Bundesland überall gesetzt und eindeutig
	var seen_ids := {}
	var seen_shorts := {}
	for def in Data.club_defs:
		var cid := int(def.get("id", -1))
		assert(cid > 0, "%s hat keine ID" % str(def.name))
		assert(not seen_ids.has(cid), "ID %d ist doppelt vergeben" % cid)
		seen_ids[cid] = true
		assert(not seen_shorts.has(str(def.short)), "Kuerzel %s ist doppelt" % str(def.short))
		seen_shorts[str(def.short)] = true
		var land := str(def.get("land", ""))
		assert(ClubData.LAENDER.has(land), "%s hat kein gueltiges Bundesland (%s)" % [str(def.name), land])
	print("%d Vereine mit eindeutiger ID und Bundesland" % Data.club_defs.size())

	# --- Jeder Verein in der Welt kennt sein Bundesland
	for cid in Game.world.clubs:
		var c: ClubData = Game.world.clubs[cid]
		assert(ClubData.LAENDER.has(c.land), "%s ohne Bundesland" % c.name)
		assert(c.land_name() != "", "%s: Bundesland ohne Namen" % c.name)
		assert(c.logo_path().ends_with("/%d.png" % c.id), "Logopfad passt nicht zur ID")

	# --- Die Staffeln stimmen mit den Bundesländern überein
	var per_staffel := {}
	for lid in Data.REGIONAL_LEAGUES:
		var lg: LeagueData = Game.world.leagues[lid]
		per_staffel[lid] = lg.club_ids.size()
		for club_id in lg.club_ids:
			var c: ClubData = Game.world.clubs[club_id]
			assert(c.home_staffel() == lid, "%s (%s) steht in %s statt in %s" % [
				c.name, c.land, lg.name, Game.league(c.home_staffel()).name])
	print("Staffeln passen zu den Bundeslaendern: %s" % str(per_staffel))

	# --- Die Aufteilung entspricht der Vorgabe
	assert(ClubData.staffel_for_land("NW") == 6, "Nordrhein-Westfalen gehoert nach West")
	assert(ClubData.staffel_for_land("BY") == 8, "Bayern gehoert nach Bayern")
	for land in ["NI", "SH", "HB", "HH"]:
		assert(ClubData.staffel_for_land(land) == 4, "%s gehoert nach Nord" % land)
	for land in ["BE", "BB", "MV", "SN", "ST", "TH"]:
		assert(ClubData.staffel_for_land(land) == 5, "%s gehoert nach Nordost" % land)
	for land in ["BW", "HE", "RP", "SL"]:
		assert(ClubData.staffel_for_land(land) == 7, "%s gehoert nach Suedwest" % land)

	_check_relegation_targets()
	_check_same_land_conflict()
	print("=== BUNDESLAND-TEST OK ===")
	get_tree().quit(0)

## Eine echte Saison: Die Absteiger der Dritten Liga müssen in der Staffel
## ihres Bundeslands landen, und alle Staffeln behalten ihre Größe.
func _check_relegation_targets() -> void:
	var guard := 0
	while not Game.season_over() and guard < 500:
		guard += 1
		Game.play_matchday()
	var third: Array = Game.world.leagues[3].table()
	var going_down: Array = []
	for i in range(third.size() - 4, third.size()):
		going_down.append(int(third[i].club_id))
	var lands := {}
	for cid in going_down:
		var c: ClubData = Game.world.clubs[cid]
		lands[c.land] = int(lands.get(c.land, 0)) + 1

	Game.end_season()
	for cid in going_down:
		var c: ClubData = Game.world.clubs[cid]
		# JEDER Absteiger landet in der Staffel seines Bundeslands – ohne Ausnahme
		assert(c.league_id == c.home_staffel(),
			"%s (%s) ist in %s gelandet statt in %s" % [c.name, c.land_name(),
				Game.league(c.league_id).name, Game.league(c.home_staffel()).name])
		print("  %s (%s) -> %s" % [c.name, c.land_name(), Game.league(c.league_id).name])
	for lid in Data.REGIONAL_LEAGUES:
		var lg: LeagueData = Game.world.leagues[lid]
		assert(lg.club_ids.size() == 18, "%s hat nach dem Wechsel %d Vereine" % [lg.name, lg.club_ids.size()])
	print("Alle %d Absteiger in ihrer Heimatstaffel, alle Staffeln bei 18" % going_down.size())

## Der Konfliktfall: Vier Absteiger aus DEMSELBEN Bundesland. Alle vier gehen
## trotzdem nach Bayern – dafür erhöht sich dort die Zahl der Regelabsteiger,
## und in den Staffeln ohne Zugang rücken Vereine aus der Oberliga nach.
func _check_same_land_conflict() -> void:
	Game.new_game(2)
	var third: LeagueData = Game.world.leagues[3]
	# Vier Drittligisten künstlich nach Bayern verlegen
	var forced: Array = third.club_ids.slice(0, 4)
	for cid in forced:
		Game.world.clubs[cid].land = "BY"
	var guard := 0
	while not Game.season_over() and guard < 500:
		guard += 1
		Game.play_matchday()
	# Die vier Vereine ans Tabellenende setzen, damit sie absteigen
	var rows := third.table()
	var bottom: Array = []
	for i in range(rows.size() - 4, rows.size()):
		bottom.append(int(rows[i].club_id))
	for i in 4:
		_swap_results(third, int(bottom[i]), int(forced[i]))
	rows = third.table()
	var going_down: Array = []
	for i in range(rows.size() - 4, rows.size()):
		going_down.append(int(rows[i].club_id))

	var bayern_before: int = Game.world.leagues[8].club_ids.size()
	Game.end_season()
	for cid in going_down:
		var c: ClubData = Game.world.clubs[cid]
		assert(c.league_id == 8,
			"%s sollte nach Bayern absteigen, steht aber in %s" % [c.name, Game.league(c.league_id).name])
	# Jede Staffel wieder auf Sollstärke, niemand hat die Region gewechselt
	for lid in Data.REGIONAL_LEAGUES:
		var lg: LeagueData = Game.world.leagues[lid]
		assert(lg.club_ids.size() == Game.STAFFEL_SIZE,
			"Konfliktfall: %s hat %d statt %d Vereine" % [lg.name, lg.club_ids.size(), Game.STAFFEL_SIZE])
		for club_id in lg.club_ids:
			var c2: ClubData = Game.world.clubs[club_id]
			assert(c2.home_staffel() == lid,
				"%s (%s) steht regionsfremd in %s" % [c2.name, c2.land, lg.name])
	# Die zusätzlichen Regelabsteiger warten jetzt in der Oberliga
	var oberliga: LeagueData = Game.world.leagues[0]
	assert(oberliga.club_ids.size() > 0, "Kein Verein in der Oberliga – die Aufstockung wurde nicht ausgeglichen")
	for club_id in oberliga.club_ids:
		assert(Game.world.clubs[club_id].league_id == 0, "Oberliga-Verein mit falscher Liga")
	print("Konfliktfall geprueft: alle 4 Absteiger nach Bayern (vorher %d Vereine), %d Verein(e) in der Oberliga" % [
		bayern_before, oberliga.club_ids.size()])

	# Folgesaison: Die Staffeln müssen stabil bleiben
	var guard2 := 0
	while not Game.season_over() and guard2 < 500:
		guard2 += 1
		Game.play_matchday()
	Game.end_season()
	for lid in Data.REGIONAL_LEAGUES:
		var lg2: LeagueData = Game.world.leagues[lid]
		assert(lg2.club_ids.size() == Game.STAFFEL_SIZE,
			"Folgesaison: %s hat %d Vereine" % [lg2.name, lg2.club_ids.size()])
	print("Folgesaison stabil: alle Staffeln bei %d Vereinen" % Game.STAFFEL_SIZE)

## Tauscht alle Ergebnisse zweier Vereine, um die Tabelle gezielt zu stellen.
func _swap_results(lg: LeagueData, a: int, b: int) -> void:
	if a == b:
		return
	for f in lg.fixtures:
		if int(f.home) == a:
			f.home = b
		elif int(f.home) == b:
			f.home = a
		if int(f.away) == a:
			f.away = b
		elif int(f.away) == b:
			f.away = a
