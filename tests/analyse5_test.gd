extends Node
## Analyse-Lauf: Simuliert 5 komplette Saisons und prüft in jeder Saison eine
## lange Liste von Invarianten. Alles, was von den Erwartungen abweicht, wird als
## PROBLEM gesammelt und am Ende zusammengefasst. Bricht NICHT bei der ersten
## Auffälligkeit ab, damit ein vollständiges Bild entsteht.

const SEASONS := 5

var _problems: Array = []
var _notes: Array = []

func _ready() -> void:
	print("=== 5-SAISON-ANALYSE START ===")
	Game.setup = {"name": "Analyst", "mode": "vereinsauswahl", "origin": "Dortmund",
		"skills": {"taktik": 3, "training": 3, "motivation": 3, "verhandlung": 2, "jugend": 2}}
	Game.new_game(1)

	_check_initial_world()

	for season_no in SEASONS:
		var label: String = Game.season_label()
		var pre := _squad_snapshot()
		var stats := _play_full_season(label)
		_check_league_sizes("Saison %s (vor Wechsel)" % label)
		_check_tables(label, stats)
		_check_players(label)
		_check_finances(label)
		var summary := Game.end_season()
		_check_summary(label, summary)
		_check_league_sizes("Saison %s (nach Wechsel)" % label)
		_check_development(label, pre)
		print("  Saison %s fertig – %d Tore/Spiel, Meister %s" % [
			label, stats.goals_per_match, summary.champion1])

	_report()
	get_tree().quit(0)

# ------------------------------------------------------------------ Prüfungen

func _check_initial_world() -> void:
	var clubs: int = Game.world.clubs.size()
	if clubs != 146:
		_problem("Weltgröße", "%d Vereine statt 146" % clubs)
	# Jede Spielklasse in der richtigen Größe, jede Liga voll besetzt
	var expect := {1: 18, 2: 18, 3: 20, 4: 18, 5: 18, 6: 18, 7: 18, 8: 18}
	for lid in expect:
		var lg: LeagueData = Game.world.leagues[lid]
		if lg.club_ids.size() != expect[lid]:
			_problem("Startaufstellung", "%s hat %d statt %d Vereine" % [lg.name, lg.club_ids.size(), expect[lid]])
	if Game.world.leagues.has(0) and not Game.world.leagues[0].club_ids.is_empty():
		_problem("Oberliga", "startet mit %d Vereinen statt leer" % Game.world.leagues[0].club_ids.size())
	# Jeder Verein: Bundesland, Kader-Mindestgröße, Startelf
	for cid in Game.world.clubs:
		var c: ClubData = Game.world.clubs[cid]
		if not ClubData.LAENDER.has(c.land):
			_problem("Bundesland", "%s hat kein gültiges Bundesland" % c.name)
		if c.player_ids.size() < 14:
			_problem("Kadergröße", "%s hat nur %d Spieler" % [c.name, c.player_ids.size()])
		if c.lineup.size() != 11:
			_problem("Startelf", "%s hat %d Aufgestellte" % [c.name, c.lineup.size()])
	_note("Start: %d Vereine, 8 Spielklassen + Oberliga, alle Bundesländer gesetzt" % clubs)

func _play_full_season(label: String) -> Dictionary:
	var goals := 0
	var matches := 0
	var guard := 0
	var reds := 0
	var penalties := 0
	while not Game.season_over() and guard < 500:
		guard += 1
		var result := Game.play_matchday()
		var sims: Array = result.others.duplicate()
		if not result.mine.is_empty():
			sims.append(result.mine)
		for entry in sims:
			var f: Dictionary = entry.fixture
			goals += int(f.hg) + int(f.ag)
			matches += 1
	if not Game.season_over():
		_problem("Saisonablauf", "%s wurde nach %d Spieltagen nicht beendet" % [label, guard])
	# Negative Tabellenwerte oder unmögliche Ergebnisse?
	for lid in Data.REGIONAL_LEAGUES + [1, 2, 3]:
		for row in Game.world.leagues[lid].table():
			if int(row.gf) < 0 or int(row.ga) < 0 or int(row.points) < 0:
				_problem("Tabelle", "%s: negativer Wert in %s" % [Game.league(lid).name, Game.club(int(row.club_id)).name])
	return {"goals_per_match": snappedf(float(goals) / maxi(matches, 1), 0.01), "matches": matches}

func _check_tables(label: String, stats: Dictionary) -> void:
	var gpm: float = stats.goals_per_match
	if gpm < 2.0 or gpm > 3.6:
		_problem("Torschnitt", "%s: %.2f Tore/Spiel (erwartet ~2,3–3,2)" % [label, gpm])
	# Jede Spielklasse: alle Vereine haben ihre volle Spielzahl gespielt
	for lid in [1, 2, 3, 4, 5, 6, 7, 8]:
		var expect_games: int = 38 if lid == 3 else 34
		for row in Game.world.leagues[lid].table():
			if int(row.played) != expect_games:
				_problem("Spielzahl", "%s: %s spielte %d statt %d" % [
					Game.league(lid).name, Game.club(int(row.club_id)).name, int(row.played), expect_games])
				break

func _check_players(label: String) -> void:
	var bad_strength := 0
	var bad_cond := 0
	var bad_age := 0
	var negative_mv := 0
	for pid in Game.world.players:
		var p: PlayerData = Game.world.players[pid]
		if p.strength < 1 or p.strength > 99:
			bad_strength += 1
		if p.condition < 0.0 or p.condition > 100.0:
			bad_cond += 1
		if p.age < 14 or p.age > 45:
			bad_age += 1
		if p.market_value() < 0:
			negative_mv += 1
	if bad_strength > 0:
		_problem("Spielerstärke", "%s: %d Spieler außerhalb 1–99" % [label, bad_strength])
	if bad_cond > 0:
		_problem("Frische", "%s: %d Spieler mit unmöglicher Frische" % [label, bad_cond])
	if bad_age > 0:
		_problem("Alter", "%s: %d Spieler außerhalb 14–45 Jahre" % [label, bad_age])
	if negative_mv > 0:
		_problem("Marktwert", "%s: %d negative Marktwerte" % [label, negative_mv])

func _check_finances(label: String) -> void:
	var broke: Array = []
	for cid in Game.world.clubs:
		var c: ClubData = Game.world.clubs[cid]
		if c.budget < -50000000:
			broke.append("%s (%s)" % [c.short_name, Fmt.money(c.budget)])
	if broke.size() > 0:
		_problem("Finanzen", "%s: %d Vereine tief im Minus: %s" % [
			label, broke.size(), ", ".join(broke.slice(0, 5))])

func _check_summary(label: String, s: Dictionary) -> void:
	if s.tables.size() != 8:
		_problem("Abschluss", "%s: %d Abschlusstabellen statt 8" % [label, s.tables.size()])
	if s.playoffs.size() != 3:
		_problem("Relegation", "%s: %d Relegationsduelle statt 3" % [label, s.playoffs.size()])
	# Auf-/Abstieg zwischen den spielbaren Ligen muss ausgeglichen sein
	if s.promoted.size() != s.relegated.size():
		_problem("Auf-/Abstieg L1", "%s: %d rauf, %d runter" % [label, s.promoted.size(), s.relegated.size()])
	# Jedes Relegationsduell: Sieger passt zum Gesamtstand, keine Auswärtstorregel
	for po in s.playoffs:
		if int(po.total_a) == int(po.total_b) and not bool(po.shootout):
			_problem("Relegation", "%s: %s unentschieden ohne Elfmeterschießen" % [label, po.title])
		var expect: String = str(po.a) if bool(po.a_wins) else str(po.b)
		if str(po.winner) != expect:
			_problem("Relegation", "%s: Sieger passt nicht zum Ausgang (%s)" % [label, po.title])

func _check_league_sizes(phase: String) -> void:
	var expect := {1: 18, 2: 18, 3: 20, 4: 18, 5: 18, 6: 18, 7: 18, 8: 18}
	for lid in expect:
		var size: int = Game.world.leagues[lid].club_ids.size()
		if size != expect[lid]:
			_problem("Ligagröße", "%s: %s hat %d statt %d" % [phase, Game.league(lid).name, size, expect[lid]])
	# Jeder Regionalligist steht in der Staffel seines Bundeslands
	for lid in Data.REGIONAL_LEAGUES:
		for cid in Game.world.leagues[lid].club_ids:
			var c: ClubData = Game.world.clubs[cid]
			if c.home_staffel() != lid:
				_problem("Staffelzuordnung", "%s: %s (%s) regionsfremd in %s" % [
					phase, c.name, c.land, Game.league(lid).name])

func _check_development(label: String, pre: Dictionary) -> void:
	# Junge Talente sollten sich im Schnitt verbessern, alte Routiniers abbauen
	var young_delta := 0.0
	var young_n := 0
	var old_delta := 0.0
	var old_n := 0
	for pid in pre:
		if not Game.world.players.has(pid):
			continue   # Karriere beendet
		var p: PlayerData = Game.world.players[pid]
		var before: Dictionary = pre[pid]
		var delta: int = p.strength - int(before.str)
		if int(before.age) <= 20 and int(before.talent) >= 4:
			young_delta += delta
			young_n += 1
		elif int(before.age) >= 32:
			old_delta += delta
			old_n += 1
	if young_n > 0 and old_n > 0:
		var yavg := young_delta / young_n
		var oavg := old_delta / old_n
		_note("%s: junge Talente Ø %+.1f, Routiniers (32+) Ø %+.1f Stärke" % [label, yavg, oavg])
		if yavg <= oavg:
			_problem("Entwicklung", "%s: Talente (%+.1f) entwickeln sich nicht besser als Routiniers (%+.1f)" % [label, yavg, oavg])

# ------------------------------------------------------------------ Werkzeug

func _squad_snapshot() -> Dictionary:
	var snap := {}
	for pid in Game.world.players:
		var p: PlayerData = Game.world.players[pid]
		snap[pid] = {"str": p.strength, "age": p.age, "talent": p.talent}
	return snap

func _problem(area: String, text: String) -> void:
	_problems.append("[%s] %s" % [area, text])
	print("  ⚠ [%s] %s" % [area, text])

func _note(text: String) -> void:
	_notes.append(text)

func _report() -> void:
	print("\n===================== ANALYSE-ERGEBNIS =====================")
	print("Beobachtungen:")
	for n in _notes:
		print("  · %s" % n)
	print("")
	if _problems.is_empty():
		print("KEINE AUFFÄLLIGKEITEN in 5 Saisons.")
	else:
		print("%d AUFFÄLLIGKEIT(EN):" % _problems.size())
		for p in _problems:
			print("  ⚠ %s" % p)
	print("============================================================")
