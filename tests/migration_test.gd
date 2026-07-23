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
	for lid in ["3", "4"]:
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

	assert(Game.load_game(path), "Alter Zwei-Ligen-Spielstand muss ladbar sein")
	assert(Game.world.leagues.size() == 4, "Nach der Migration muessen 4 Ligen existieren")
	assert(Game.world.clubs.size() == 76, "Es fehlen Vereine: %d" % Game.world.clubs.size())
	assert(not Game.league(4).playable, "Die Regionalliga darf nicht spielbar sein")
	for lid in [3, 4]:
		var lg: LeagueData = Game.world.leagues[lid]
		assert(lg.club_ids.size() == 20, "%s hat %d Vereine" % [lg.name, lg.club_ids.size()])
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
