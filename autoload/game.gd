extends Node
## Autoload "Game": hält den kompletten Spielstand (Welt, eigener Verein, Finanzen)
## und steuert Spieltage, Saisonwechsel, Transfers sowie Speichern/Laden.

const SAVE_DIR := "user://saves"
const ROUNDS_PER_SEASON := 34
const DIFFICULTY_FACTORS := {"Leicht": 1.5, "Normal": 1.0, "Schwer": 0.5}

## Trainer-Fähigkeiten mit Spielwirkung:
## Taktik -> Teamstärke im Spiel, Training -> Formaufbau, Motivation -> fängt Rückschläge auf,
## Verhandlung -> bessere Transferpreise, Jugendarbeit -> stärkere Jugendspieler
const SKILLS := {
	"taktik": "Taktik",
	"training": "Training",
	"motivation": "Motivation",
	"verhandlung": "Verhandlung",
	"jugend": "Jugendarbeit",
}
const SKILL_POOL := 10   # frei verteilbare Punkte (jede Fähigkeit startet bei 1)
const SKILL_MAX := 8

## Trainingsschwerpunkte (zwischen den Spieltagen, nur eigener Verein):
## Effekte werden in _regenerate_players() angewendet.
const TRAINING_FOCI := {
	"Ausgewogen": "Standardtraining ohne Besonderheiten.",
	"Kondition": "+8 Frische-Regeneration, Ausdauer der Spieler steigt langsam.",
	"Regeneration": "+16 Frische-Regeneration, aber keine Entwicklung.",
	"Leistung": "Formaufbau und Entwicklung junger Spieler, kostet aber Frische (−8 Regeneration).",
}

var world := {}
var manager_name := ""
var manager_birthday := {"day": 1, "month": 1, "year": 1986}
var manager_origin := ""
var manager_nat := "Deutschland"
var skills := {}               # Fähigkeit -> Punkte (1..SKILL_MAX)
var game_mode := "vereinsauswahl"   # "angebote" (echte Karriere) | "vereinsauswahl"
var difficulty := "Normal"
var reputation := 50.0         # Trainer-Ruf, bestimmt im Angebote-Modus die Jobangebote
var training_focus := "Ausgewogen"
var coach_salary := 20000      # Dein Trainergehalt pro Monat (in der Verhandlung ausgehandelt)
var coach_contract_years := 2
var season_goal := {}          # Saisonziel des Vorstands: {text, position}
var my_club_id := -1
var transactions: Array = []   # {text, amount, matchday, season}
var initialized := false

# Zwischenspeicher des Spielstart-Assistenten (Trainer anlegen -> Spielmodus -> Verein/Angebot)
var setup := {}

# ------------------------------------------------------------------ Neues Spiel

func new_game(p_club_id: int) -> void:
	world = Data.generate_world()
	manager_name = setup.get("name", "Der Trainer")
	manager_birthday = setup.get("birthday", {"day": 1, "month": 1, "year": 1986})
	manager_origin = setup.get("origin", "")
	manager_nat = setup.get("nat", "Deutschland")
	skills = {}
	var setup_skills: Dictionary = setup.get("skills", {})
	for key in SKILLS:
		skills[key] = clampi(int(setup_skills.get(key, 1)), 1, SKILL_MAX)
	game_mode = setup.get("mode", "vereinsauswahl")
	difficulty = setup.get("difficulty", "Normal")
	my_club_id = p_club_id
	reputation = float(my_club().base_strength)
	training_focus = "Ausgewogen"
	coach_salary = int(setup.get("coach_salary", board_salary(my_club().base_strength)))
	coach_contract_years = int(setup.get("coach_years", 2))
	season_goal = setup.get("season_goal", _board_goal_for(my_club()))
	transactions.clear()
	initialized = true
	my_club().budget = int(my_club().budget * DIFFICULTY_FACTORS.get(difficulty, 1.0))

# ------------------------------------------------------------------ Vorstand

## Gehaltsangebot des Vorstands abhängig von der Vereinsgröße.
static func board_salary(strength: int) -> int:
	return maxi((strength - 40) * 3000, 15000)

## Saisonziel abhängig von der Kaderstärke im Ligavergleich (rank = 1 ist der Stärkste).
static func goal_from_rank(rank: int, tier: int) -> Dictionary:
	if tier == 1:
		if rank <= 2:
			return {"text": "Meisterschaft", "position": 1}
		if rank <= 5:
			return {"text": "Top-5-Platzierung", "position": 5}
		if rank <= 12:
			return {"text": "Gesichertes Mittelfeld (Platz 12 oder besser)", "position": 12}
		return {"text": "Klassenerhalt", "position": 15}
	if rank <= 3:
		return {"text": "Aufstieg (Platz 1–3)", "position": 3}
	if rank <= 12:
		return {"text": "Gesichertes Mittelfeld (Platz 12 oder besser)", "position": 12}
	return {"text": "Klassenerhalt", "position": 15}

func _board_goal_for(c: ClubData) -> Dictionary:
	var lg: LeagueData = world.leagues[c.league_id]
	var stronger := 0
	for cid in lg.club_ids:
		if world.clubs[cid].base_strength > c.base_strength:
			stronger += 1
	return goal_from_rank(stronger + 1, lg.tier)

func manager_age() -> int:
	return int(world.season_year) - int(manager_birthday.year)

func skill(key: String) -> int:
	return int(skills.get(key, 1))

# ------------------------------------------------------------------ Zugriff

func my_club() -> ClubData:
	return world.clubs[my_club_id]

func club(cid: int) -> ClubData:
	return world.clubs[cid]

func get_player(pid: int) -> PlayerData:
	return world.players[pid]

func league(lid: int) -> LeagueData:
	return world.leagues[lid]

func my_league() -> LeagueData:
	return world.leagues[my_club().league_id]

func matchday() -> int:
	return int(world.matchday)

func season_label() -> String:
	return "Saison %d/%02d" % [world.season_year, (int(world.season_year) + 1) % 100]

func season_over() -> bool:
	return matchday() >= ROUNDS_PER_SEASON

func next_fixture(cid: int) -> Dictionary:
	if season_over():
		return {}
	return league(club(cid).league_id).fixture_of(cid, matchday())

# ------------------------------------------------------------------ Spieltag

## Erstellt Live-Simulationen (MatchSim) für alle Partien des aktuellen Spieltags.
## Rückgabe: {mine: MatchSim oder null, others: [MatchSim]}
## Das eigene Spiel wird vom Match-Bildschirm Minute für Minute getickt –
## Eingriffe (Wechsel, Spielweise) wirken auf den weiteren Verlauf.
func start_matchday() -> Dictionary:
	# Fähigkeit "Taktik": bis zu ~5 % Teamstärke-Bonus für den eigenen Verein
	var tactic_factor := 1.0 + 0.006 * skill("taktik")
	var my_sim: MatchSim = null
	var others: Array = []
	for lid in world.leagues:
		var lg: LeagueData = world.leagues[lid]
		for f in lg.fixtures_for_round(matchday()):
			var sim := MatchSim.new()
			sim.setup(club(int(f.home)), club(int(f.away)), world.players)
			sim.fixture = f
			sim.league_name = lg.name
			if int(f.home) == my_club_id:
				sim.factor_h = tactic_factor
				sim.ai_h = false
				my_sim = sim
			elif int(f.away) == my_club_id:
				sim.factor_a = tactic_factor
				sim.ai_a = false
				my_sim = sim
			else:
				others.append(sim)
	return {"mine": my_sim, "others": others}

## Schreibt die zu Ende simulierten Spiele in den Spielplan und schließt den Spieltag ab.
func finish_matchday(md: Dictionary) -> void:
	var sims: Array = md.others.duplicate()
	if md.mine != null:
		sims.append(md.mine)
	for sim in sims:
		sim.fixture.played = true
		sim.fixture.hg = sim.hg
		sim.fixture.ag = sim.ag
	if md.mine != null:
		_apply_skill_form_effects({"fixture": md.mine.fixture})
	_regenerate_players()
	_apply_matchday_finances()
	world.matchday = matchday() + 1

## Zwischen den Spieltagen: Verletzungen heilen, Sperren laufen ab, Frische regeneriert.
## Wer durchspielt, erholt sich nicht vollständig – Rotation wird wichtig.
## Die Fähigkeit "Training" und der Trainingsschwerpunkt wirken auf den eigenen Verein.
func _regenerate_players() -> void:
	for pid in world.players:
		var p: PlayerData = world.players[pid]
		if p.injury_matchdays > 0:
			p.injury_matchdays -= 1
		if p.suspended_matchdays > 0:
			p.suspended_matchdays -= 1
		var regen := 35.0
		if p.club_id == my_club_id:
			regen += 1.5 * skill("training")
			match training_focus:
				"Kondition":
					regen += 8.0
					if p.stamina < 95 and randf() < 0.02:
						p.stamina += 1
				"Regeneration":
					regen += 16.0
				"Leistung":
					regen -= 8.0
					p.form = clampf(p.form + 0.008, 0.8, 1.2)
					if p.age <= 26 and p.strength < 94 and randf() < 0.025:
						p.strength += 1
		p.condition = minf(100.0, p.condition + regen)

## Komplettsimulation ohne Eingriffe (Tests, Schnellrechnung).
## Rückgabe kompatibel: {mine: {fixture, res}, others: [{league, fixture}]}
func play_matchday() -> Dictionary:
	var md := start_matchday()
	if md.mine != null:
		md.mine.run_full()
	for sim in md.others:
		sim.run_full()
	finish_matchday(md)
	var my_result := {}
	if md.mine != null:
		my_result = {"fixture": md.mine.fixture, "res": {"hg": md.mine.hg, "ag": md.mine.ag, "events": md.mine.events}}
	var others: Array = []
	for sim in md.others:
		others.append({"league": sim.league_name, "fixture": sim.fixture})
	return {"mine": my_result, "others": others}

## Fähigkeiten "Training" und "Motivation": Training baut stetig Form auf,
## Motivation federt Niederlagen und Remis zusätzlich ab.
func _apply_skill_form_effects(my_result: Dictionary) -> void:
	if my_result.is_empty():
		return
	var f: Dictionary = my_result.fixture
	var home := int(f.home) == my_club_id
	var my_goals: int = int(f.hg) if home else int(f.ag)
	var their_goals: int = int(f.ag) if home else int(f.hg)
	var bonus := 0.0012 * skill("training")
	if my_goals <= their_goals:
		bonus += 0.0022 * skill("motivation")
	for pid in my_club().player_ids:
		var p: PlayerData = world.players[pid]
		p.form = clampf(p.form + bonus, 0.8, 1.2)

func _apply_matchday_finances() -> void:
	for cid in world.clubs:
		var c: ClubData = world.clubs[cid]
		var lg: LeagueData = world.leagues[c.league_id]
		var f := lg.fixture_of(cid, matchday())
		var ticket := 0
		if not f.is_empty() and int(f.home) == cid:
			var price := 28 if lg.tier == 1 else 16
			var fill := clampf(0.45 + (c.base_strength - 55) * 0.008 + randf() * 0.2, 0.3, 1.0)
			ticket = int(c.capacity * fill) * price
		var salaries := c.salaries_per_matchday(world.players)
		c.budget += ticket + c.sponsor_per_md - salaries
		if cid == my_club_id:
			var coach_cost := int(coach_salary * 12.0 / 34.0)
			c.budget -= coach_cost
			if ticket > 0:
				log_transaction("Ticketeinnahmen (%s)" % c.stadium, ticket)
			log_transaction("Sponsor: %s" % c.sponsor_name, c.sponsor_per_md)
			log_transaction("Gehälter", -salaries)
			log_transaction("Trainergehalt", -coach_cost)

func log_transaction(text: String, amount: int) -> void:
	transactions.push_front({
		"text": text, "amount": amount,
		"matchday": matchday() + 1, "season": world.season_year,
	})
	if transactions.size() > 200:
		transactions.resize(200)

# ------------------------------------------------------------------ Saisonwechsel

## Wertet die Saison aus (Meister, Auf-/Abstieg), altert Spieler, füllt Kader auf
## und erzeugt neue Spielpläne. Rückgabe: Zusammenfassung fürs UI.
func end_season() -> Dictionary:
	var l1: LeagueData = world.leagues[1]
	var l2: LeagueData = world.leagues[2]
	var t1 := l1.table()
	var t2 := l2.table()

	var summary := {
		"season": season_label(),
		"champion1": club(t1[0].club_id).name,
		"champion2": club(t2[0].club_id).name,
		"relegated": [],
		"promoted": [],
		"retired": [],
		"my_position": my_league().position_of(my_club_id),
		"my_league_name": my_league().name,
	}

	# Saisonziel auswerten: Erfolg stärkt den Ruf, Misserfolg kostet ihn
	var goal_achieved: bool = int(summary.my_position) <= int(season_goal.get("position", 18))
	summary["goal_text"] = season_goal.get("text", "")
	summary["goal_achieved"] = goal_achieved
	if goal_achieved:
		reputation += 1.5
	else:
		reputation -= 1.0

	# Trainer-Ruf aktualisieren: gute Platzierungen steigern die Reputation dauerhaft
	var performance: float = my_club().base_strength + (10.0 - int(summary.my_position)) * 0.8
	reputation = maxf(reputation, performance)

	# Trainervertrag läuft weiter, der Vorstand setzt ein neues Saisonziel
	coach_contract_years -= 1
	if coach_contract_years <= 0:
		coach_contract_years = 2
	season_goal = _board_goal_for(my_club())

	# Auf- und Abstieg (3 runter, 3 rauf)
	for row in t1.slice(15):
		club(row.club_id).league_id = 2
		summary.relegated.append(club(row.club_id).name)
	for row in t2.slice(0, 3):
		club(row.club_id).league_id = 1
		summary.promoted.append(club(row.club_id).name)
	l1.club_ids.clear()
	l2.club_ids.clear()
	for cid in world.clubs:
		world.leagues[world.clubs[cid].league_id].club_ids.append(cid)

	# Spieler altern, Verträge laufen ab, Karriereenden
	var retiring: Array = []
	for pid in world.players:
		var p: PlayerData = world.players[pid]
		p.age += 1
		p.contract_years -= 1
		p.reset_season_stats()
		p.form = clampf(0.9 + (p.form - 1.0) * 0.3 + randf_range(-0.05, 0.05), 0.85, 1.15)
		p.condition = 100.0
		p.injury_matchdays = 0
		p.suspended_matchdays = 0
		p.last_rating = 0.0
		if p.age >= 31:
			p.stamina = clampi(p.stamina - randi_range(1, 4), 30, 95)
		if p.age >= 34 and randf() < 0.45:
			retiring.append(pid)
		elif p.contract_years <= 0:
			# Automatische Verlängerung (KI wie Spieler) – Vertragsverhandlungen kommen in einer späteren Ausbaustufe
			p.contract_years = randi_range(2, 3)
			p.salary = maxi(int(p.market_value() / 40.0 / 1000.0) * 1000, 3000)
		# Entwicklung: Junge werden besser, Alte bauen ab
		if p.age <= 23:
			p.strength = clampi(p.strength + randi_range(0, 3), 28, 96)
		elif p.age >= 31:
			p.strength = clampi(p.strength - randi_range(0, 3), 28, 96)

	for pid in retiring:
		var p: PlayerData = world.players[pid]
		if p.club_id == my_club_id:
			summary.retired.append(p.full_name())
		club(p.club_id).player_ids.erase(pid)
		club(p.club_id).lineup.erase(pid)
		world.players.erase(pid)

	# Kader mit Jugendspielern auffüllen
	var min_per_pos := {"TW": 2, "AB": 6, "MF": 6, "ST": 3}
	for cid in world.clubs:
		var c: ClubData = world.clubs[cid]
		# Fähigkeit "Jugendarbeit": der eigene Nachwuchs kommt stärker aus der Akademie
		var youth_bonus: int = (skill("jugend") >> 1) if cid == my_club_id else 0
		for pos in min_per_pos:
			while c.players_by_pos(world.players, pos).size() < min_per_pos[pos]:
				Data.create_youth_player(world, c, pos, youth_bonus)
		c.lineup = c.best_eleven(world.players)

	# Neue Saison
	l1.fixtures = ScheduleGen.build_fixtures(l1.club_ids)
	l2.fixtures = ScheduleGen.build_fixtures(l2.club_ids)
	world.matchday = 0
	world.season_year = int(world.season_year) + 1
	return summary

# ------------------------------------------------------------------ Jobangebote (Echte Karriere)

## Angebote nach Saisonende: bessere Vereine im Bereich der aktuellen Reputation.
func season_offers() -> Array:
	if game_mode != "angebote":
		return []
	var candidates: Array = []
	for cid in world.clubs:
		if cid == my_club_id:
			continue
		var c: ClubData = world.clubs[cid]
		if c.base_strength > my_club().base_strength and absf(c.base_strength - reputation) <= 4.0:
			candidates.append(cid)
	candidates.shuffle()
	return candidates.slice(0, 2)

func switch_club(cid: int) -> void:
	my_club_id = cid
	reputation = maxf(reputation, float(my_club().base_strength))
	my_club().lineup = my_club().best_eleven(world.players)
	log_transaction("Neuer Trainerposten: %s" % my_club().name, 0)

# ------------------------------------------------------------------ Transfers

## Kauft einen Spieler für den eigenen Verein. Rückgabe: Fehlertext oder "" bei Erfolg.
func buy_player(pid: int) -> String:
	var p := get_player(pid)
	var seller := club(p.club_id)
	var buyer := my_club()
	# Fähigkeit "Verhandlung" drückt den Aufschlag beim Kauf
	var price := int(p.market_value() * (1.10 - 0.012 * skill("verhandlung")))
	if buyer.player_ids.size() >= 30:
		return "Dein Kader ist voll (max. 30 Spieler)."
	if seller.player_ids.size() <= 17:
		return "%s hat zu wenige Spieler und verkauft nicht." % seller.name
	if buyer.budget < price:
		return "Nicht genug Budget (%s benötigt)." % Fmt.money(price)
	seller.player_ids.erase(pid)
	seller.lineup.erase(pid)
	seller.budget += price
	buyer.player_ids.append(pid)
	buyer.budget -= price
	p.club_id = my_club_id
	p.contract_years = 3
	log_transaction("Transfer: %s verpflichtet" % p.full_name(), -price)
	return ""

## Verkauft einen eigenen Spieler an einen zufälligen Verein. "" bei Erfolg.
func sell_player(pid: int) -> String:
	var p := get_player(pid)
	var seller := my_club()
	if seller.player_ids.size() <= 16:
		return "Dein Kader ist zu klein (min. 16 Spieler)."
	var candidates: Array = []
	for cid in world.clubs:
		if cid != my_club_id and world.clubs[cid].player_ids.size() < 29:
			candidates.append(cid)
	if candidates.is_empty():
		return "Aktuell findet sich kein Abnehmer."
	var buyer: ClubData = world.clubs[candidates.pick_random()]
	# Fähigkeit "Verhandlung" holt beim Verkauf mehr heraus
	var price := int(p.market_value() * (1.0 + 0.012 * skill("verhandlung")))
	seller.player_ids.erase(pid)
	seller.lineup.erase(pid)
	seller.budget += price
	buyer.player_ids.append(pid)
	p.club_id = buyer.id
	p.contract_years = 3
	log_transaction("Transfer: %s an %s verkauft" % [p.full_name(), buyer.name], price)
	return ""

# ------------------------------------------------------------------ Speichern / Laden

func save_game() -> String:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var save_name := "%s_%d_ST%02d" % [my_club().short_name, world.season_year, matchday()]
	var path := "%s/%s.json" % [SAVE_DIR, save_name]
	var data := {
		"meta": {
			"manager": manager_name,
			"manager_birthday": manager_birthday,
			"manager_origin": manager_origin,
			"manager_nat": manager_nat,
			"skills": skills,
			"game_mode": game_mode,
			"difficulty": difficulty,
			"reputation": reputation,
			"training_focus": training_focus,
			"coach_salary": coach_salary,
			"coach_years": coach_contract_years,
			"season_goal": season_goal,
			"my_club_id": my_club_id,
			"club": my_club().name,
			"season_year": world.season_year,
			"matchday": matchday(),
			"saved_at": Time.get_datetime_string_from_system(false, true),
		},
		"world": _world_to_dict(),
		"transactions": transactions,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(data))
	return save_name

func list_saves() -> Array:
	var result: Array = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return result
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var path := "%s/%s" % [SAVE_DIR, file]
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var data: Variant = JSON.parse_string(f.get_as_text())
		if data is Dictionary and data.has("meta"):
			result.append({"path": path, "meta": data.meta})
	result.reverse()
	return result

func load_game(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary) or not data.has("world"):
		return false
	manager_name = data.meta.manager
	var bd: Dictionary = data.meta.get("manager_birthday", {"day": 1, "month": 1, "year": 1986})
	manager_birthday = {"day": int(bd.day), "month": int(bd.month), "year": int(bd.year)}
	manager_origin = data.meta.get("manager_origin", "")
	manager_nat = data.meta.get("manager_nat", "Deutschland")
	skills = {}
	var saved_skills: Dictionary = data.meta.get("skills", {})
	for key in SKILLS:
		skills[key] = clampi(int(saved_skills.get(key, 1)), 1, SKILL_MAX)
	game_mode = data.meta.get("game_mode", "vereinsauswahl")
	difficulty = data.meta.get("difficulty", "Normal")
	reputation = float(data.meta.get("reputation", 50.0))
	training_focus = data.meta.get("training_focus", "Ausgewogen")
	coach_salary = int(data.meta.get("coach_salary", 20000))
	coach_contract_years = int(data.meta.get("coach_years", 2))
	season_goal = data.meta.get("season_goal", {})
	my_club_id = int(data.meta.my_club_id)
	if season_goal.is_empty():
		season_goal = {"text": "Klassenerhalt", "position": 15}
	transactions = data.get("transactions", [])
	world = _world_from_dict(data.world)
	initialized = true
	return true

func _world_to_dict() -> Dictionary:
	var players := {}
	for pid in world.players:
		players[str(pid)] = world.players[pid].to_dict()
	var clubs := {}
	for cid in world.clubs:
		clubs[str(cid)] = world.clubs[cid].to_dict()
	var leagues := {}
	for lid in world.leagues:
		leagues[str(lid)] = world.leagues[lid].to_dict()
	return {
		"season_year": world.season_year,
		"matchday": world.matchday,
		"next_player_id": world.next_player_id,
		"players": players,
		"clubs": clubs,
		"leagues": leagues,
	}

func _world_from_dict(d: Dictionary) -> Dictionary:
	var w := {
		"season_year": int(d.season_year),
		"matchday": int(d.matchday),
		"next_player_id": int(d.next_player_id),
		"players": {},
		"clubs": {},
		"leagues": {},
	}
	for key in d.players:
		w.players[int(key)] = PlayerData.from_dict(d.players[key])
	for key in d.clubs:
		w.clubs[int(key)] = ClubData.from_dict(d.clubs[key])
	for key in d.leagues:
		w.leagues[int(key)] = LeagueData.from_dict(d.leagues[key])
	return w
