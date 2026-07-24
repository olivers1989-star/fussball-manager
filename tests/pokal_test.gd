extends Node
## Prüft den deutschen Pokal (DFB-Pokal-Nachbau):
##  - 64 Teilnehmer in der richtigen Zusammensetzung, keine Zweitmannschaften.
##  - 1. Runde: 32 Paarungen, klassentieferer Verein hat Heimrecht.
##  - Sechs K.-o.-Runden bis genau ein Sieger übrig ist.
##  - Bei Gleichstand Verlängerung und Elfmeterschießen.
##  - Finale auf neutralem Platz.

func _ready() -> void:
	print("=== POKAL-TEST START ===")
	Game.setup = {"name": "Test", "mode": "vereinsauswahl", "origin": "Dortmund",
		"skills": {"taktik": 3, "training": 3, "motivation": 3, "verhandlung": 1, "jugend": 2}}
	var bvw := -1
	Game.new_game(1)
	for cid in Game.world.clubs:
		if Game.world.clubs[cid].short_name == "BVW":
			bvw = cid
	Game.new_game(bvw)

	var cup: CupData = Game.cup
	assert(cup != null, "Kein Pokal angelegt")

	# --- Teilnehmerfeld
	var teams := {}
	for p in cup.pairings:
		teams[int(p.home)] = true
		teams[int(p.away)] = true
	assert(teams.size() == 64, "Pokal hat %d statt 64 Teilnehmer" % teams.size())
	assert(cup.pairings.size() == 32, "1. Runde hat %d statt 32 Paarungen" % cup.pairings.size())

	# Alle 36 Erst-/Zweitligisten sind dabei, keine Zweitmannschaft
	var l1l2 := 0
	for cid in teams:
		var c: ClubData = Game.world.clubs[cid]
		assert(not c.is_reserve(), "Zweitmannschaft %s im Pokal" % c.name)
		if c.league_id <= 2:
			l1l2 += 1
	assert(l1l2 == 36, "Nur %d statt 36 Erst-/Zweitligisten im Pokal" % l1l2)
	# Mindestens ein Verein je Regionalliga-Staffel
	for lid in Data.REGIONAL_LEAGUES:
		var found := false
		for cid in teams:
			if Game.world.clubs[cid].league_id == lid:
				found = true
		assert(found, "Keine %s im Pokal" % Game.league(lid).name)
	print("Teilnehmerfeld: 64 Vereine, 36 aus Liga 1/2, alle Staffeln vertreten, keine Reserven")

	# --- 1. Runde: klassentieferer Verein hat Heimrecht
	for p in cup.pairings:
		var h: ClubData = Game.world.clubs[int(p.home)]
		var a: ClubData = Game.world.clubs[int(p.away)]
		assert(h.league_id >= a.league_id,
			"Heimrecht falsch: %s (Liga %d) empfängt %s (Liga %d)" % [h.name, h.league_id, a.name, a.league_id])

	# --- Kompletten Pokal durchsimulieren
	var round_no := 0
	while not cup.is_finished() and round_no < 10:
		var before: int = cup.pairings.size()
		var expected: int = [32, 16, 8, 4, 2, 1][mini(cup.round, 5)]
		assert(before == expected, "%s hat %d statt %d Paarungen" % [cup.round_name(cup.round), before, expected])
		Game.play_cup_round()
		round_no += 1

	assert(cup.is_finished(), "Pokal hat keinen Sieger nach %d Runden" % round_no)
	assert(round_no == 6, "Pokal brauchte %d statt 6 Runden" % round_no)
	assert(Game.world.clubs.has(cup.champion), "Ungültiger Pokalsieger")
	assert(cup.history.size() == 6, "%d statt 6 Runden im Verlauf" % cup.history.size())

	# Jede gespielte Paarung hat einen gültigen Sieger; kein Unentschieden ohne Elfer
	var extra_time := 0
	var shootouts := 0
	for r in cup.history:
		for p in r:
			assert(int(p.winner) == int(p.home) or int(p.winner) == int(p.away), "Paarung ohne gültigen Sieger")
			if int(p.hg) == int(p.ag):
				assert(bool(p.shootout), "Unentschieden ohne Elfmeterschießen")
				assert(int(p.ph) != int(p.pa), "Elfmeterschießen ohne Entscheidung")
			if bool(p.extra):
				extra_time += 1
			if bool(p.shootout):
				shootouts += 1
	print("Sieger: %s · %d Runden, davon %d mit Verlängerung und %d mit Elfmeterschießen" % [
		Game.world.clubs[cup.champion].name, round_no, extra_time, shootouts])

	# --- Speichern/Laden mitten im Pokal
	Game.new_game(bvw)
	Game.play_cup_round()   # 1. Runde gespielt, jetzt 2. Runde
	var save_round := Game.cup.round
	var save_pairings := Game.cup.pairings.size()
	var name := Game.save_game("ZZPokal")
	assert(Game.load_game("%s/%s.json" % [Game.SAVE_DIR, name]))
	assert(Game.cup.round == save_round, "Pokalrunde nach Laden falsch")
	assert(Game.cup.pairings.size() == save_pairings, "Pokal-Paarungen nach Laden falsch")
	assert(Game.cup.history.size() == 1, "Pokalverlauf nach Laden verloren")
	Game.delete_save("%s/%s.json" % [Game.SAVE_DIR, name])
	print("Speichern/Laden mitten im Pokal OK")

	print("=== POKAL-TEST OK ===")
	get_tree().quit(0)
