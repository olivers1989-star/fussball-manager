extends Node
## Headless-Smoke-Test: komplette Saison simulieren, speichern, laden, Saisonwechsel.
## Aufruf: godot --headless --path . res://tests/smoke_test.tscn

func _ready() -> void:
	print("=== SMOKE-TEST START ===")
	Game.setup = {
		"name": "Testtrainer",
		"birthday": {"day": 15, "month": 6, "year": 1980},
		"origin": "Teststadt",
		"mode": "vereinsauswahl",
		"skills": {"taktik": 3, "training": 3, "motivation": 2, "verhandlung": 2, "jugend": 2},
	}
	Game.new_game(1)
	assert(Game.manager_age() == 2026 - 1980)
	assert(Game.skill("taktik") == 3)
	Game.training_focus = "Leistung"
	var world: Dictionary = Game.world
	print("Spieler: %d, Vereine: %d, Ligen: %d" % [world.players.size(), world.clubs.size(), world.leagues.size()])
	assert(world.clubs.size() == 36)
	assert(Game.league(1).fixtures.size() == 306)

	# Kalender: Saison startet am 1. August, Spieltage samstags, Winterpause vorhanden
	assert(Game.date_dict().month == 8 and Game.date_dict().day == 1)
	assert(Game.world.matchday_dates.size() == 34)
	assert(Time.get_datetime_dict_from_unix_time(Game.matchday_date(0)).weekday == Time.WEEKDAY_SATURDAY)
	assert(Game.matchday_date(17) - Game.matchday_date(16) > 30 * 86400)
	assert(Time.get_datetime_dict_from_unix_time(Game.matchday_date(17)).month == 2)
	Game.advance_day()
	assert(Game.date_dict().day == 2)

	var total_goals := 0
	var total_matches := 0
	for md in 34:
		var result := Game.play_matchday()
		assert(not result.mine.is_empty())
		total_goals += int(result.mine.fixture.hg) + int(result.mine.fixture.ag)
		total_matches += 1
		for entry in result.others:
			total_goals += int(entry.fixture.hg) + int(entry.fixture.ag)
			total_matches += 1
	print("34 Spieltage simuliert: %d Spiele, %.2f Tore/Spiel" % [total_matches, float(total_goals) / total_matches])
	assert(total_matches == 34 * 18)
	assert(Game.season_over())

	# Kondition, Verletzungen, Sperren und Noten müssen im Saisonverlauf entstanden sein
	var injured := 0
	var rated := 0
	var five_yellows := 0
	for pid in Game.world.players:
		var pl: PlayerData = Game.world.players[pid]
		assert(pl.condition >= 0.0 and pl.condition <= 100.0)
		if pl.is_injured():
			injured += 1
		if pl.last_rating > 0.0:
			rated += 1
		if pl.yellow_cards >= 5:
			five_yellows += 1
	print("Aktuell Verletzte: %d, Spieler mit Note: %d, Spieler mit 5+ Gelben: %d, Meldungen: %d" % [injured, rated, five_yellows, Game.news.size()])
	assert(rated > 300)
	assert(injured > 0)
	assert(five_yellows > 0)
	assert(Game.news.size() > 0)

	var table := Game.league(1).table()
	print("Meister: %s (%d Punkte)" % [Game.club(table[0].club_id).name, table[0].points])
	assert(table[0].played == 34)

	var save_name := Game.save_game()
	print("Gespeichert: ", save_name)
	assert(not save_name.is_empty())

	var summary := Game.end_season()
	print("Saisonwechsel: Aufsteiger %s / Absteiger %s" % [", ".join(summary.promoted), ", ".join(summary.relegated)])
	assert(summary.promoted.size() == 3 and summary.relegated.size() == 3)
	assert(Game.matchday() == 0)
	assert(Game.league(1).club_ids.size() == 18 and Game.league(2).club_ids.size() == 18)

	var result2 := Game.play_matchday()
	assert(not result2.mine.is_empty())
	print("Erster Spieltag der neuen Saison simuliert.")

	var saves := Game.list_saves()
	assert(not saves.is_empty())
	assert(Game.load_game(saves[0].path))
	assert(Game.season_over())
	print("Spielstand geladen: %s, Spieltag %d" % [Game.my_club().name, Game.matchday()])

	# Transfertest
	Game.end_season()
	var candidate := -1
	for pid in Game.world.players:
		if Game.world.players[pid].club_id != Game.my_club_id:
			candidate = pid
			break
	Game.my_club().budget = 999000000
	var buy_error := Game.buy_player(candidate)
	assert(buy_error == "")
	assert(Game.get_player(candidate).club_id == Game.my_club_id)
	var sell_error := Game.sell_player(candidate)
	assert(sell_error == "")
	print("Transfertest OK.")

	# Echte Karriere: Angebote und Vereinswechsel (aus Sicht eines schwachen Zweitligisten)
	Game.game_mode = "angebote"
	var weak_club_id := -1
	for cid in Game.world.clubs:
		if Game.world.clubs[cid].base_strength <= 56:
			weak_club_id = cid
			break
	assert(weak_club_id > 0)
	Game.my_club_id = weak_club_id
	Game.reputation = 62.0
	var offers := Game.season_offers()
	print("Jobangebote bei Ruf 62: %d" % offers.size())
	assert(offers.size() > 0)
	var old_club := Game.my_club_id
	Game.switch_club(offers[0])
	assert(Game.my_club_id != old_club)
	assert(Game.my_club().lineup.size() == 11)
	print("Vereinswechsel OK: jetzt bei %s" % Game.my_club().name)

	print("=== SMOKE-TEST OK ===")
	get_tree().quit(0)
