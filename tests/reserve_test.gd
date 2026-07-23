extends Node
## Prüft die Regeln für Zweitmannschaften:
##  1. Kopplung an die erste Mannschaft (parent_id, is_reserve).
##  2. Eine Zweitmannschaft steigt NICHT in die 1./2. Liga auf – der Platz geht
##     an den nächsten aufstiegsberechtigten Verein.
##  3. Zweitmannschaft und erste Mannschaft nie in derselben Liga – sonst
##     Zwangsabstieg der Zweitmannschaft.
## Zweitmannschaften werden für den Test synthetisch erzeugt und die Ergebnisse
## nach dem Spielen gezielt verbogen.

func _ready() -> void:
	print("=== ZWEITMANNSCHAFTS-TEST START ===")
	Game.setup = {"name": "Testtrainer", "mode": "vereinsauswahl", "origin": "Dortmund",
		"skills": {"taktik": 3, "training": 3, "motivation": 3, "verhandlung": 1, "jugend": 2}}
	Game.new_game(2)
	_check_no_promotion_to_second_league()
	_check_forced_relegation_with_parent()
	print("=== ZWEITMANNSCHAFTS-TEST OK ===")
	get_tree().quit(0)

## Zweitmannschaft eines Erstligisten wird Meister der Dritten Liga – darf aber
## nicht aufsteigen. Der nächste reguläre Verein rückt nach.
func _check_no_promotion_to_second_league() -> void:
	print("--- Aufstiegssperre ---")
	var third: LeagueData = Game.world.leagues[3]
	var parent_id: int = Game.world.leagues[1].club_ids[0]
	var reserve_id: int = third.club_ids[0]
	var reserve := Game.club(reserve_id)
	reserve.parent_id = parent_id
	reserve.name = Game.club(parent_id).name + " II"
	assert(reserve.is_reserve(), "Zweitmannschaft wird nicht erkannt")

	_play_season()
	_make_champion(third, reserve_id)
	var rows := third.table()
	assert(int(rows[0].club_id) == reserve_id, "Testaufbau: Reserve ist nicht Erster")
	# Bester regulärer Verein (kein Reserveteam)
	var runner := -1
	for i in range(1, rows.size()):
		if not Game.club(int(rows[i].club_id)).is_reserve():
			runner = int(rows[i].club_id); break

	Game.end_season()
	assert(Game.club(reserve_id).league_id == 3,
		"Reserve ist in Liga %d aufgestiegen – verboten!" % Game.club(reserve_id).league_id)
	assert(runner > 0 and Game.club(runner).league_id == 2,
		"Nachrücker %s ist nicht aufgestiegen" % Game.club(runner).name)
	print("Meister-Reserve bleibt in Liga 3, %s steigt an ihrer Stelle auf" % Game.club(runner).name)

## Zweitmannschaft (Meister Liga 3, bleibt) trifft auf ihre erste Mannschaft
## (aus Liga 2 abgestiegen) – die Reserve muss zwangsabsteigen.
func _check_forced_relegation_with_parent() -> void:
	print("--- Zwangsabstieg bei Kollision ---")
	Game.new_game(2)
	var second: LeagueData = Game.world.leagues[2]
	var third: LeagueData = Game.world.leagues[3]
	var parent_id: int = second.club_ids[0]           # erste Mannschaft in Liga 2
	var reserve_id: int = third.club_ids[0]           # Reserve in Liga 3
	var reserve := Game.club(reserve_id)
	reserve.parent_id = parent_id
	reserve.name = Game.club(parent_id).name + " II"

	_play_season()
	_make_champion(third, reserve_id)                 # Reserve wird Meister (bleibt Liga 3)
	_make_last(second, parent_id)                     # erste Mannschaft steigt nach Liga 3 ab

	Game.end_season()
	var p_league: int = Game.club(parent_id).league_id
	var r_league: int = Game.club(reserve_id).league_id
	assert(p_league == 3, "Testaufbau: erste Mannschaft ist nicht in Liga 3 (%d)" % p_league)
	assert(p_league != r_league,
		"Reserve (%d) und erste Mannschaft (%d) in derselben Liga" % [r_league, p_league])
	assert(Data.REGIONAL_LEAGUES.has(r_league),
		"Reserve wurde nicht in die Regionalliga zwangsabgestiegen (Liga %d)" % r_league)
	for lid in Data.REGIONAL_LEAGUES:
		assert(Game.world.leagues[lid].club_ids.size() == Game.STAFFEL_SIZE,
			"%s hat nach der Trennung %d Vereine" % [Game.league(lid).name, Game.world.leagues[lid].club_ids.size()])
	print("Kollision aufgelöst: erste Mannschaft Liga %d, Reserve zwangsab in Liga %d" % [p_league, r_league])

# ---- Werkzeug ----

func _play_season() -> void:
	var guard := 0
	while not Game.season_over() and guard < 500:
		guard += 1
		Game.play_matchday()

## Setzt alle gespielten Partien eines Vereins auf einen klaren Sieg.
func _make_champion(lg: LeagueData, cid: int) -> void:
	for f in lg.fixtures:
		if not f.played:
			continue
		if int(f.home) == cid:
			f.hg = 4; f.ag = 0
		elif int(f.away) == cid:
			f.hg = 0; f.ag = 4

## Setzt alle gespielten Partien eines Vereins auf eine klare Niederlage.
func _make_last(lg: LeagueData, cid: int) -> void:
	for f in lg.fixtures:
		if not f.played:
			continue
		if int(f.home) == cid:
			f.hg = 0; f.ag = 4
		elif int(f.away) == cid:
			f.hg = 4; f.ag = 0
