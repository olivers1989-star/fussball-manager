extends Node
## Sammelt beim 5-Saison-Lauf ALLE Daten und schreibt sie als eine JSON-Datei –
## Grundlage für das Analyse-Dashboard. Beobachtet den Verein des Spielers
## (Dortmund) über die Jahre und erfasst Tabellen, Meister, Torjäger, Noten,
## Relegation, Auf-/Abstieg, Karriereenden, Nachwuchs und Stärkeverläufe.

const SEASONS := 5
const OUT := "C:/Temp/report5.json"
const MY_CLUB := "BVW"   # beobachteter Verein (Dortmund)

func _ready() -> void:
	print("=== REPORT5 START ===")
	Game.setup = {"name": "Oliver Smolinski", "mode": "vereinsauswahl", "origin": "Dortmund",
		"skills": {"taktik": 3, "training": 3, "motivation": 3, "verhandlung": 2, "jugend": 2}}
	Game.new_game(2)

	var report := {
		"clubs": {}, "titles": {}, "strength_timeline": {},
		"seasons": [], "stars": [], "my_club": {"short": MY_CLUB, "journey": []},
	}
	for cid in Game.world.clubs:
		var c: ClubData = Game.world.clubs[cid]
		report.clubs[str(cid)] = {"name": c.name, "short": c.short_name, "color": c.color, "land": c.land}

	# Fünf stärkste 5★-Talente über alle Saisons verfolgen
	var stars: Array = []
	for pid in Game.world.players:
		var p: PlayerData = Game.world.players[pid]
		if p.talent == 5 and p.age <= 20:
			stars.append(pid)
	stars.sort_custom(func(a, b): return Game.world.players[a].potential > Game.world.players[b].potential)
	stars = stars.slice(0, 6)
	for pid in stars:
		var p: PlayerData = Game.world.players[pid]
		report.stars.append({"id": pid, "name": p.full_name(), "pos": p.pos, "nat": p.nat,
			"potential": p.potential, "points": []})

	for season_no in SEASONS:
		var label: String = Game.season_label()
		print("Report Saison %s ..." % label)
		var season := {"label": label, "goals": 0, "matches": 0,
			"yellow": 0, "red": 0, "penalties": 0}

		# Stärke-Zeitreihe (Saisonstart) für die spielbaren Ligen
		for lid in [1, 2, 3]:
			for cid in Game.world.leagues[lid].club_ids:
				if not report.strength_timeline.has(str(cid)):
					report.strength_timeline[str(cid)] = []
				report.strength_timeline[str(cid)].append({
					"season": season_no, "str": Game.world.clubs[cid].team_strength(Game.world.players)})
		# Talent-Punkte
		for i in stars.size():
			var pid: int = stars[i]
			if Game.world.players.has(pid):
				var p: PlayerData = Game.world.players[pid]
				report.stars[i].points.append({"season": season_no, "age": p.age,
					"str": p.strength, "club": Game.club(p.club_id).short_name, "mv": p.market_value()})

		# Saison spielen
		var guard := 0
		while not Game.season_over() and guard < 500:
			guard += 1
			var result := Game.play_matchday()
			var sims: Array = result.others.duplicate()
			if not result.mine.is_empty():
				sims.append(result.mine)
			for entry in sims:
				var f: Dictionary = entry.fixture
				season.goals += int(f.hg) + int(f.ag)
				season.matches += 1

		# Tabellen aller Ligen VOR dem Wechsel
		season["tables"] = {}
		season["champions"] = {}
		for def in Data.LEAGUE_DEFS:
			var lid := int(def.id)
			var rows: Array = Game.world.leagues[lid].table()
			season.tables[str(lid)] = _table_rows(lid, rows)
			if not rows.is_empty():
				season.champions[str(lid)] = Game.club(int(rows[0].club_id)).name

		# Statistik-Summen über alle Spieler dieser Saison
		for pid in Game.world.players:
			var pl: PlayerData = Game.world.players[pid]
			season.yellow += pl.yellow_cards
			season.red += pl.red_cards
		season["goals_per_match"] = snappedf(float(season.goals) / maxi(season.matches, 1), 0.01)
		season["scorers"] = _top_scorers()
		season["ratings"] = _top_rated()
		season["my_row"] = _my_club_row()

		# Abschluss
		var summary := Game.end_season()
		season["playoffs"] = summary.playoffs
		season["movements"] = summary.movements
		season["retired"] = summary.get("retired", [])
		season["retired_notable"] = summary.get("retired_notable", [])
		season["youth"] = summary.get("new_youth", [])
		season["oberliga"] = Game.world.leagues[0].club_ids.size() if Game.world.leagues.has(0) else 0

		# Titel zählen (Meister Erste Liga)
		var champ_cid := int(Game.world.leagues[1].table()[0].club_id) if false else -1
		var first_rows: Array = season.tables["1"]
		if not first_rows.is_empty():
			var champ := str(first_rows[0].cid)
			report.titles[champ] = int(report.titles.get(champ, 0)) + 1

		# Reise des beobachteten Vereins
		report.my_club.journey.append({"season": label, "league": _my_league_name(),
			"row": season.my_row})

		report.seasons.append(season)
		print("  %s: %.2f Tore/Spiel" % [label, season.goals_per_match])

	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(report))
	f.close()
	print("=== REPORT5 GESCHRIEBEN: %s ===" % OUT)
	get_tree().quit(0)

func _table_rows(lid: int, rows: Array) -> Array:
	var out: Array = []
	var rules: Dictionary = Game.LEAGUE_RULES.get(lid, {})
	var size := rows.size()
	for i in rows.size():
		var row: Dictionary = rows[i]
		var c := Game.club(int(row.club_id))
		var mark := ""
		if i == 0:
			mark = "champion"
		elif not rules.is_empty():
			if i < int(rules.up_direct):
				mark = "promoted"
			elif int(rules.up_playoff) > 0 and i == int(rules.up_direct):
				mark = "playoff_up"
			elif i >= size - int(rules.down_direct):
				mark = "relegated"
			elif int(rules.down_playoff) > 0 and i == size - int(rules.down_direct) - 1:
				mark = "playoff_down"
		out.append({"pos": i + 1, "cid": c.id, "name": c.name, "short": c.short_name,
			"color": c.color, "land": c.land, "pl": int(row.played), "w": int(row.won),
			"d": int(row.drawn), "l": int(row.lost), "gf": int(row.gf), "ga": int(row.ga),
			"pts": int(row.points), "mark": mark, "mine": c.short_name == MY_CLUB})
	return out

func _top_scorers() -> Array:
	var list: Array = []
	for pid in Game.world.players:
		var p: PlayerData = Game.world.players[pid]
		if p.goals_season <= 0:
			continue
		var c := Game.club(p.club_id)
		list.append({"name": p.full_name(), "short": c.short_name, "color": c.color,
			"pos": p.pos, "nat": p.nat, "goals": p.goals_season, "matches": p.matches_season,
			"league": c.league_id})
	list.sort_custom(func(a, b): return int(a.goals) > int(b.goals))
	return list.slice(0, 15)

func _top_rated() -> Array:
	var list: Array = []
	for pid in Game.world.players:
		var p: PlayerData = Game.world.players[pid]
		if p.matches_season < 15:
			continue
		var c := Game.club(p.club_id)
		list.append({"name": p.full_name(), "short": c.short_name, "color": c.color,
			"pos": p.pos, "nat": p.nat, "note": snappedf(p.avg_rating(), 0.01),
			"matches": p.matches_season, "league": c.league_id})
	list.sort_custom(func(a, b): return float(a.note) < float(b.note))
	return list.slice(0, 10)

func _my_club_id() -> int:
	for cid in Game.world.clubs:
		if Game.world.clubs[cid].short_name == MY_CLUB:
			return cid
	return -1

func _my_league_name() -> String:
	var cid := _my_club_id()
	return Game.league(Game.world.clubs[cid].league_id).name if cid > 0 else "?"

func _my_club_row() -> Dictionary:
	var cid := _my_club_id()
	if cid < 0:
		return {}
	var c: ClubData = Game.world.clubs[cid]
	var lg: LeagueData = Game.world.leagues[c.league_id]
	var rows := lg.table()
	for i in rows.size():
		if int(rows[i].club_id) == cid:
			var r: Dictionary = rows[i]
			return {"pos": i + 1, "league": lg.name, "pl": int(r.played), "w": int(r.won),
				"d": int(r.drawn), "l": int(r.lost), "gf": int(r.gf), "ga": int(r.ga), "pts": int(r.points)}
	return {}
