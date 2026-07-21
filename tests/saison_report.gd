extends Node
## Saison-Report: simuliert 5 komplette Saisons (beide Ligen) und schreibt alle
## Daten als JSON (Tabellen, Torjäger, Noten, Karten, Entwicklung, Karriereenden,
## Vereinsstärken-Verlauf, 5-Sterne-Talente) – Grundlage für den HTML-Report.

const SEASONS := 5
const OUT_PATH := "C:/Users/Administrator/AppData/Local/Temp/claude/C--Fussball-Manager/5ee35f79-e44e-45d6-a1ff-3232e6d24c3e/scratchpad/saison5.json"

func _ready() -> void:
	Game.setup = {"name": "Reporter", "mode": "vereinsauswahl"}
	Game.new_game(1)

	var report := {"seasons": [], "clubs": {}, "strength_timeline": {}, "stars": []}

	# Vereins-Stammdaten und Zeitreihen-Gerüst
	for cid in Game.world.clubs:
		var c: ClubData = Game.world.clubs[cid]
		report.clubs[str(cid)] = {"name": c.name, "short": c.short_name, "color": c.color}
		report.strength_timeline[str(cid)] = []

	# Die 5-Sterne-Talente der Datenbank über alle Saisons verfolgen
	var star_ids: Array = []
	for pid in Game.world.players:
		if Game.world.players[pid].talent == 5:
			star_ids.append(pid)
	for pid in star_ids:
		var p: PlayerData = Game.world.players[pid]
		report.stars.append({"id": pid, "name": p.full_name(), "pos": p.pos, "potential": p.potential, "seasons": [{"age": p.age, "strength": p.strength, "club": Game.club(p.club_id).short_name, "mv": p.market_value()}]})

	for season_no in SEASONS:
		var label: String = Game.season_label()
		print("Simuliere Saison %s ..." % label)

		# Saisonstart-Schnappschuss (Stärke, Alter, Marktwert, Name, Verein)
		var snap := {}
		for pid in Game.world.players:
			var p: PlayerData = Game.world.players[pid]
			snap[pid] = {"str": p.strength, "age": p.age, "mv": p.market_value(), "name": p.full_name(), "club": Game.club(p.club_id).short_name, "talent": p.talent, "pos": p.pos}
		for cid in Game.world.clubs:
			report.strength_timeline[str(cid)].append(snapshot_strength(cid))

		for md in 34:
			Game.play_matchday()

		var s := {"label": label, "leagues": []}
		for lid in [1, 2]:
			s.leagues.append(_league_data(lid))

		# Saisonabschluss: Entwicklung + Karriereenden erfassen
		var summary := Game.end_season()
		s["champion1"] = summary.champion1
		s["champion2"] = summary.champion2
		s["promoted"] = summary.promoted
		s["relegated"] = summary.relegated

		var retired: Array = []
		var devs: Array = []
		var youth_sum := 0.0
		var youth_n := 0
		for pid in snap:
			if not Game.world.players.has(pid):
				retired.append({"name": snap[pid].name, "age": snap[pid].age, "club": snap[pid].club, "strength": snap[pid].str})
				continue
			var p: PlayerData = Game.world.players[pid]
			var diff: int = p.strength - snap[pid].str
			if snap[pid].age <= 18:
				youth_sum += diff
				youth_n += 1
			if diff != 0:
				devs.append({"name": p.full_name(), "age": p.age, "pos": p.pos, "talent": p.talent, "old": snap[pid].str, "new": p.strength, "diff": diff, "club": Game.club(p.club_id).short_name, "mv_diff": p.market_value() - snap[pid].mv})
		devs.sort_custom(func(a, b): return a.diff > b.diff)
		s["dev_up"] = devs.slice(0, 10)
		s["dev_down"] = devs.slice(maxi(0, devs.size() - 10)).duplicate()
		s.dev_down.reverse()
		s["retired"] = retired
		s["youth_avg"] = (youth_sum / youth_n) if youth_n > 0 else 0.0
		s["youth_count"] = youth_n
		var mvs := devs.duplicate()
		mvs.sort_custom(func(a, b): return a.mv_diff > b.mv_diff)
		s["mv_top"] = mvs.slice(0, 6)
		report.seasons.append(s)

		# 5-Sterne-Talente fortschreiben
		for star in report.stars:
			if Game.world.players.has(star.id):
				var p: PlayerData = Game.world.players[star.id]
				star.seasons.append({"age": p.age, "strength": p.strength, "club": Game.club(p.club_id).short_name, "mv": p.market_value()})

	# Endstand der Gesamtstärken als letzter Zeitreihen-Punkt
	for cid in Game.world.clubs:
		report.strength_timeline[str(cid)].append(snapshot_strength(cid))

	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	print("Report geschrieben: %s (%d Saisons)" % [OUT_PATH, report.seasons.size()])
	get_tree().quit(0)

func snapshot_strength(cid: int) -> Dictionary:
	var c: ClubData = Game.world.clubs[cid]
	return {"league": c.league_id, "strength": snappedf(c.overall_strength(Game.world.players), 0.1)}

func _league_data(lid: int) -> Dictionary:
	var lg: LeagueData = Game.league(lid)
	var table: Array = lg.table()
	var out := {"name": lg.name, "table": [], "goals": 0, "scorers": [], "notes": [], "yellow": 0, "red": 0, "card_top": []}
	for i in table.size():
		var row: Dictionary = table[i]
		var c: ClubData = Game.club(row.club_id)
		out.goals += row.gf
		out.table.append({"pos": i + 1, "club": c.name, "short": c.short_name, "won": row.won, "drawn": row.drawn, "lost": row.lost, "gf": row.gf, "ga": row.ga, "pts": row.points})

	var players: Array = []
	for cid in lg.club_ids:
		for pid in Game.club(cid).player_ids:
			players.append(Game.world.players[pid])

	players.sort_custom(func(a, b): return a.goals_season > b.goals_season)
	for i in 10:
		var p: PlayerData = players[i]
		out.scorers.append({"name": p.full_name(), "pos": p.pos, "goals": p.goals_season, "strength": p.strength, "club": Game.club(p.club_id).short_name})

	var regulars: Array = players.filter(func(p): return p.matches_season >= 20)
	regulars.sort_custom(func(a, b): return a.avg_rating() < b.avg_rating())
	for i in mini(10, regulars.size()):
		var p: PlayerData = regulars[i]
		out.notes.append({"name": p.full_name(), "pos": p.pos, "note": snappedf(p.avg_rating(), 0.01), "matches": p.matches_season, "club": Game.club(p.club_id).short_name})

	for p in players:
		out.yellow += p.yellow_cards
		out.red += p.red_cards
	players.sort_custom(func(a, b): return a.yellow_cards + a.red_cards * 3 > b.yellow_cards + b.red_cards * 3)
	for i in 5:
		var p: PlayerData = players[i]
		out.card_top.append({"name": p.full_name(), "yellow": p.yellow_cards, "red": p.red_cards, "aggr": p.attr("aggressivitaet"), "club": Game.club(p.club_id).short_name})
	return out
