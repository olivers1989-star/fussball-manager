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
	print("=== MIGRATIONS-TEST OK ===")
	get_tree().quit(0)
