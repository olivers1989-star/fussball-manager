extends Node
## Prüft die überarbeitete Vereinsdatenbank (Saison 26/27 nach Fotos):
##  - 146 Vereine, richtige Ligagrößen, eindeutige IDs und Kürzel.
##  - Jede Zweitmannschaft ist an eine existierende erste Mannschaft gekoppelt,
##    heißt wie diese mit " II" und steht NICHT in deren Liga.
##  - Reserveteams stehen in einer erlaubten Spielklasse (Tier >= 3).

func _ready() -> void:
	print("=== VEREINE-TEST START ===")
	Game.setup = {"name": "Testtrainer", "mode": "vereinsauswahl", "origin": "Dortmund",
		"skills": {"taktik": 3, "training": 3, "motivation": 3, "verhandlung": 1, "jugend": 2}}
	Game.new_game(2)

	assert(Game.world.clubs.size() == 146, "Es sind %d statt 146 Vereine" % Game.world.clubs.size())
	var expect := {1: 18, 2: 18, 3: 20, 4: 18, 5: 18, 6: 18, 7: 18, 8: 18}
	for lid in expect:
		var lg: LeagueData = Game.world.leagues[lid]
		assert(lg.club_ids.size() == expect[lid], "%s hat %d statt %d" % [lg.name, lg.club_ids.size(), expect[lid]])

	# Eindeutige IDs und Kürzel
	var seen_id := {}
	var seen_short := {}
	for cid in Game.world.clubs:
		var c: ClubData = Game.world.clubs[cid]
		assert(not seen_id.has(c.id), "Doppelte ID %d" % c.id)
		assert(not seen_short.has(c.short_name), "Doppeltes Kürzel %s" % c.short_name)
		seen_id[c.id] = true
		seen_short[c.short_name] = true

	# Zweitmannschaften
	var reserves := 0
	for cid in Game.world.clubs:
		var c: ClubData = Game.world.clubs[cid]
		if not c.is_reserve():
			continue
		reserves += 1
		var parent := Game.club(c.parent_id)
		assert(parent != null and parent.id > 0, "%s hat keine erste Mannschaft" % c.name)
		assert(not parent.is_reserve(), "%s ist an eine andere Reserve gekoppelt" % c.name)
		assert(c.name == parent.name + " II", "%s heißt nicht wie die erste Mannschaft + II" % c.name)
		assert(c.league_id != parent.league_id,
			"%s steht in derselben Liga wie %s" % [c.name, parent.name])
		assert(Game.world.leagues[c.league_id].tier >= ClubData.MAX_RESERVE_TIER,
			"%s startet zu hoch (Tier %d)" % [c.name, Game.world.leagues[c.league_id].tier])
		# Reserve in der richtigen Regionalliga-Staffel (Bundesland der ersten Mannschaft)
		if Data.REGIONAL_LEAGUES.has(c.league_id):
			assert(c.home_staffel() == c.league_id,
				"%s steht in der falschen Staffel (%s)" % [c.name, Game.league(c.league_id).name])
	assert(reserves == 22, "Es sind %d statt 22 Zweitmannschaften" % reserves)
	print("22 Zweitmannschaften korrekt gekoppelt, keine mit ihrer ersten Mannschaft in einer Liga")

	# Prominente Kontrollen: die Bundesliga muss die erwarteten Klubs enthalten
	var bl_shorts := {}
	for cid in Game.world.leagues[1].club_ids:
		bl_shorts[Game.world.clubs[cid].short_name] = true
	for s in ["FCB", "BVW", "S04", "SCP", "ELV"]:
		assert(bl_shorts.has(s), "Bundesliga fehlt %s" % s)
	print("Bundesliga enthält Bayern, Dortmund, Schalke, Paderborn, Elversberg (Fotos maßgeblich)")

	# Kadergrößen
	for cid in Game.world.clubs:
		var c: ClubData = Game.world.clubs[cid]
		assert(c.player_ids.size() >= 14, "%s hat nur %d Spieler" % [c.name, c.player_ids.size()])
		assert(c.lineup.size() == 11, "%s hat keine gültige Elf" % c.name)

	# Vereinsauswahl: die ID aus den Stammdaten muss zum richtigen Verein führen
	# (Regression: früher Listenposition statt fester ID -> falscher Verein)
	for def in Data.club_defs:
		var by_id := Data.club_def_by_id(int(def.id))
		assert(str(by_id.get("short", "")) == str(def.short),
			"club_def_by_id liefert falschen Verein für ID %d" % int(def.id))
	var bvw_id := -1
	for cid in Game.world.clubs:
		if Game.world.clubs[cid].short_name == "BVW":
			bvw_id = cid
	assert(bvw_id > 0)
	Game.setup = {"name": "Test", "mode": "vereinsauswahl", "club_id": bvw_id}
	Game.new_game(bvw_id)
	assert(Game.my_club().short_name == "BVW",
		"Auswahl BVW landet bei %s" % Game.my_club().short_name)
	print("Vereinsauswahl: BVW ausgewählt -> %s (feste ID)" % Game.my_club().name)

	print("=== VEREINE-TEST OK ===")
	get_tree().quit(0)
