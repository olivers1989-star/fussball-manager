extends Node
## Prüft die v0.12-Migration: Ein Spielstand im alten Format (ohne Karriereenden-
## Archiv, alte Mini-Gehälter/-Budgets) muss beim Laden auf die neue Ökonomie
## gehoben werden, ohne dass Vereine pleitegehen.

func _ready() -> void:
	Game.setup = {"name": "Migrationstester", "mode": "vereinsauswahl"}
	Game.new_game(1)
	var name := Game.save_game()
	var path := "%s/%s.json" % [Game.SAVE_DIR, name]

	# Spielstand ins alte Format zurückbauen: kein Archiv, alte Geldskala (~1/10)
	var f := FileAccess.open(path, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	data.world.erase("retired")
	for pid in data.world.players:
		data.world.players[pid].sal = maxi(int(data.world.players[pid].sal / 10.0), 3000)
	for cid in data.world.clubs:
		data.world.clubs[cid].budget = int(data.world.clubs[cid].budget / 10.0)
		data.world.clubs[cid].sponsor_md = int(data.world.clubs[cid].sponsor_md / 10.0)
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	print("Altes Format geschrieben, lade ...")

	assert(Game.load_game(path), "Alter Spielstand muss ladbar sein")
	print("Geladen, pruefe Migration ...")
	assert(Game.world.has("retired"), "Archiv muss nach Migration existieren")
	var p: PlayerData = Game.world.players.values()[0]
	assert(p.salary == p.expected_salary(), "Gehaelter muessen neu berechnet sein")
	for cid in Game.world.clubs:
		var c: ClubData = Game.world.clubs[cid]
		var wage: int = c.salaries_per_matchday(Game.world.players)
		var income: int = c.sponsor_per_md + int(c.capacity * c.expected_fill() * c.ticket_price() / 2.0)
		assert(income >= wage, "%s: Einnahmen (%d) muessen Gehaelter (%d) decken" % [c.name, income, wage])
		assert(c.budget >= int(wage * 34 * 0.3), "%s: Budget zu klein nach Migration" % c.name)
	_check_lower_league_migration()
	print("=== MIGRATIONS-TEST OK ===")
	get_tree().quit(0)

## Prüft die v0.31-Migration: Spielstände mit nur zwei Ligen bekommen Dritte
## Liga und Regionalliga samt Vereinen, Kadern und Spielplan nachgeliefert –
## auch mitten in der Saison.
func _check_lower_league_migration() -> void:
	print("--- Ligaunterbau-Migration ---")
	Game.new_game(1)
	for i in 6:
		Game.play_matchday()
	var played_before := Game.matchday()
	var name := Game.save_game("ZZMigrationLigen")
	var path := "%s/%s.json" % [Game.SAVE_DIR, name]
	var f := FileAccess.open(path, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()

	# Auf den alten Stand zurückbauen: nur Liga 1 und 2, nur deren Vereine,
	# fortlaufende Spieltage 0..33 statt des 38er-Rasters
	var slots: Array = ScheduleGen.saturday_slots()
	for lid in ["3", "4", "5", "6", "7", "8"]:
		data.world.leagues.erase(lid)
	var keep := {}
	for lid in ["1", "2"]:
		for cid in data.world.leagues[lid].clubs:
			keep[int(cid)] = true
		for fx in data.world.leagues[lid].fixtures:
			fx.round = slots.find(int(fx.round))
	for cid in data.world.clubs.keys():
		if not keep.has(int(cid)):
			data.world.clubs.erase(cid)
	for pid in data.world.players.keys():
		if not keep.has(int(data.world.players[pid].club)):
			data.world.players.erase(pid)
	data.world.matchday = slots.find(played_before)
	data.world.matchday_dates = data.world.matchday_dates.slice(0, 34)
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	print("Zwei-Ligen-Spielstand geschrieben (%d Vereine, Spieltag %d)" % [
		data.world.clubs.size(), int(data.world.matchday) + 1])

	# Bundesländer entfernen: Der Spielstand muss sie beim Laden nachtragen
	for cid in data.world.clubs:
		data.world.clubs[cid].erase("land")
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()

	assert(Game.load_game(path), "Alter Zwei-Ligen-Spielstand muss ladbar sein")
	assert(Game.world.leagues.size() == 9, "Nach der Migration muessen 8 Ligen plus Oberliga existieren")
	for cid in Game.world.clubs:
		var club: ClubData = Game.world.clubs[cid]
		assert(ClubData.LAENDER.has(club.land), "%s ohne Bundesland nach der Migration" % club.name)
	assert(Game.world.clubs.size() == 146, "Es fehlen Vereine: %d" % Game.world.clubs.size())
	assert(Game.league(4).playable, "Die Regionalliga muss jetzt spielbar sein")
	assert(Game.league(8).club_ids.size() == 18, "Die fuenfte Staffel fehlt")
	for lid in [3, 4, 5, 6, 7, 8]:
		var lg: LeagueData = Game.world.leagues[lid]
		var want: int = 20 if lid == 3 else 18
		assert(lg.club_ids.size() == want, "%s hat %d statt %d Vereine" % [lg.name, lg.club_ids.size(), want])
		var played := 0
		for fx in lg.fixtures:
			if fx.played:
				played += 1
		assert(played > 0, "%s: vergangene Spieltage wurden nicht nachsimuliert" % lg.name)
		for row in lg.table():
			assert(int(row.played) > 0, "%s: %s ohne Spiele" % [lg.name, Game.club(int(row.club_id)).name])
	# Der eigene Spielplan liegt jetzt auf dem 38er-Raster und die Saison läuft weiter
	assert(Game.matchday() == played_before,
		"Spieltag nach Migration %d statt %d" % [Game.matchday(), played_before])
	assert(Game.league(1).own_rounds().size() == 34, "Erste Liga hat kein 34er-Raster")
	assert(Game.world.matchday_dates.size() == ScheduleGen.total_rounds(), "Kalender nicht erweitert")
	var before: int = int(Game.league(1).table()[0].played)
	Game.play_matchday()
	assert(Game.league(1).table()[0].played >= before, "Saison laesst sich nach der Migration nicht fortsetzen")
	print("Ligaunterbau ergaenzt: %d Vereine, Dritte Liga mit %d nachsimulierten Spieltagen" % [
		Game.world.clubs.size(), Game.league(3).table()[0].played])
	Game.delete_save(path)
	_check_regional_split_migration()

## Prüft die v0.32-Migration: Spielstände mit EINER Regionalliga (20 Vereine)
## werden auf die fünf Staffeln aufgeteilt und aufgefüllt.
func _check_regional_split_migration() -> void:
	print("--- Regionalliga-Staffel-Migration ---")
	Game.new_game(1)
	for i in 4:
		Game.play_matchday()
	var name := Game.save_game("ZZMigrationStaffeln")
	var path := "%s/%s.json" % [Game.SAVE_DIR, name]
	var f := FileAccess.open(path, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()

	# Auf den Stand von v0.31 zurückbauen: eine Regionalliga mit 20 Vereinen,
	# die Staffeln 5–8 gibt es noch nicht
	var regional: Array = []
	for lid in ["4", "5", "6", "7", "8"]:
		if data.world.leagues.has(lid):
			regional.append_array(data.world.leagues[lid].clubs)
			data.world.leagues.erase(lid)
	regional.sort()
	var keep: Array = regional.slice(0, 20)
	for cid in regional:
		if keep.has(cid):
			continue
		data.world.clubs.erase(str(int(cid)))
	for pid in data.world.players.keys():
		var owner: int = int(data.world.players[pid].club)
		if regional.has(owner) and not keep.has(owner):
			data.world.players.erase(pid)
	for cid in keep:
		data.world.clubs[str(int(cid))].league = 4
	data.world.leagues["4"] = {
		"id": 4, "name": "Regionalliga", "short": "RL", "tier": 4, "playable": false,
		"clubs": keep, "fixtures": [],
	}
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	print("Spielstand mit EINER Regionalliga geschrieben (%d Vereine)" % data.world.clubs.size())

	assert(Game.load_game(path), "Spielstand mit einer Regionalliga muss ladbar sein")
	assert(Game.world.leagues.size() == 9, "Die Staffeln wurden nicht angelegt")
	assert(Game.world.clubs.size() == 146, "Es fehlen Vereine: %d" % Game.world.clubs.size())
	var total := 0
	for lid in Data.REGIONAL_LEAGUES:
		var lg: LeagueData = Game.world.leagues[lid]
		assert(lg.club_ids.size() == 18, "%s hat %d statt 18 Vereine" % [lg.name, lg.club_ids.size()])
		assert(lg.playable, "%s muss spielbar sein" % lg.name)
		assert(lg.fixtures.size() == 306, "%s hat %d Partien" % [lg.name, lg.fixtures.size()])
		total += lg.club_ids.size()
	assert(total == 90, "Der Regionalliga-Pool hat %d statt 90 Vereine" % total)
	Game.play_matchday()
	print("Regionalliga aufgeteilt: 5 Staffeln, %d Vereine im Pool" % total)
	Game.delete_save(path)
