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

## Trainingsschwerpunkte (täglich wirksam, nur eigener Verein):
## regen = Frische-Bonus/Malus pro Tag, pool = trainierte Attribute,
## chance = tägliche Verbesserungschance pro Spieler (altersskaliert).
const TRAINING_FOCI := {
	"Ausgewogen": {"desc": "Solides Standardtraining ohne Schwerpunkte.", "regen": 0.0, "pool": [], "chance": 0.0},
	"Kondition": {"desc": "Mehr Frische-Regeneration, Ausdauer steigt langsam.", "regen": 1.2, "pool": [], "chance": 0.0},
	"Regeneration": {"desc": "Maximale Erholung – aber keine Entwicklung.", "regen": 2.3, "pool": [], "chance": 0.0},
	"Offensive": {"desc": "Abschluss, Dribbling und Technik verbessern sich – kostet Frische.", "regen": -0.8, "pool": ["abschluss", "dribbling", "technik"], "chance": 0.012},
	"Defensive": {"desc": "Zweikampf, Stellungsspiel und Konzentration verbessern sich – kostet Frische.", "regen": -0.8, "pool": ["zweikampf", "stellung", "konzentration"], "chance": 0.012},
	"Passspiel": {"desc": "Passspiel und Übersicht verbessern sich – kostet Frische.", "regen": -0.8, "pool": ["passen", "uebersicht"], "chance": 0.012},
	"Standards": {"desc": "Standards und Flanken verbessern sich.", "regen": -0.5, "pool": ["standards", "flanken"], "chance": 0.012},
}

## Matchpläne für die Spielvorbereitung: gelten NUR fürs nächste Spiel.
const MATCH_PLANS := {
	"Ausgeglichen": {"desc": "Keine besonderen Vorgaben.", "att": 1.0, "mid": 1.0, "def": 1.0, "setpiece": 0.0},
	"Offensivpressing": {"desc": "Früh stören, viele Angriffe – hinten wird es luftiger.", "att": 1.07, "mid": 1.03, "def": 0.96, "setpiece": 0.0},
	"Konter": {"desc": "Tief stehen, blitzschnell umschalten – stark gegen Favoriten.", "att": 1.05, "mid": 0.98, "def": 1.04, "setpiece": 0.0},
	"Defensivriegel": {"desc": "Alles dichtmachen und einen Punkt mitnehmen.", "att": 0.94, "mid": 1.0, "def": 1.08, "setpiece": 0.0},
	"Mittelfeldkontrolle": {"desc": "Ballbesitz und Rhythmus – das Spiel diktieren.", "att": 1.0, "mid": 1.07, "def": 1.0, "setpiece": 0.0},
	"Standardfokus": {"desc": "Einstudierte Freistöße und Ecken – doppelt so viele Standards.", "att": 1.0, "mid": 1.0, "def": 1.0, "setpiece": 0.006},
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
var match_plan := "Ausgeglichen"   # Matchplan der Spielvorbereitung (gilt nur fürs nächste Spiel)
var coach_salary := 20000      # Dein Trainergehalt pro Monat (in der Verhandlung ausgehandelt)
var coach_contract_years := 2
var goal_bonus := 0            # Ausgehandelte Erfolgsprämie bei Erreichen des Saisonziels
var win_bonus := 0             # Ausgehandelte Siegprämie pro gewonnenem Spiel
var coach_money := 0           # Dein persönliches Trainerkonto (Gehalt + Prämien)
var season_goal := {}          # Saisonziel des Vorstands: {text, position}
var my_club_id := -1
var transactions: Array = []   # {text, amount, matchday, season}
var news: Array = []           # Tagesereignisse: {day, text, kind}, neueste zuerst
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
	match_plan = "Ausgeglichen"
	coach_salary = int(setup.get("coach_salary", board_salary(my_club().base_strength)))
	coach_contract_years = int(setup.get("coach_years", 2))
	goal_bonus = int(setup.get("goal_bonus", 0))
	win_bonus = int(setup.get("win_bonus", 0))
	coach_money = 0
	season_goal = setup.get("season_goal", _board_goal_for(my_club()))
	transactions.clear()
	news.clear()
	initialized = true
	my_club().budget = int(my_club().budget * DIFFICULTY_FACTORS.get(difficulty, 1.0))
	# Ausgehandelte Transferbudget-Zusage des Vorstands
	var pledge := int(setup.get("transfer_pledge", 0))
	if pledge > 0:
		my_club().budget += pledge
		log_transaction("Transferbudget-Zusage des Vorstands", pledge)

# ------------------------------------------------------------------ Trainerprofile (wiederverwendbar)

const PROFILES_PATH := "user://trainer_profiles.json"

func list_profiles() -> Array:
	var f := FileAccess.open(PROFILES_PATH, FileAccess.READ)
	if f == null:
		return []
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		return data.get("profiles", [])
	return []

## Speichert ein Trainerprofil (überschreibt ein vorhandenes mit gleichem Namen).
func save_profile(profile: Dictionary) -> void:
	var profiles := list_profiles().filter(func(p):
		return p.get("first", "") != profile.get("first", "") or p.get("last", "") != profile.get("last", ""))
	profiles.append(profile)
	var f := FileAccess.open(PROFILES_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"profiles": profiles}))

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

## Vertragsende als echtes Datum: Verträge laufen immer bis zum 30. Juni.
func contract_until(p: PlayerData) -> String:
	return "30.06.%d" % (int(world.season_year) + p.contract_years)

func coach_contract_until() -> String:
	return "30.06.%d" % (int(world.season_year) + coach_contract_years)

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

# ------------------------------------------------------------------ Kalender & Tagesablauf

const DAY := 86400
const WEEKDAYS := ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]

func date_unix() -> int:
	return int(world.date)

func date_dict() -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(date_unix())

func date_label() -> String:
	var d := date_dict()
	return "%s, %02d.%02d.%d" % [WEEKDAYS[d.weekday], d.day, d.month, d.year]

func matchday_date(md: int) -> int:
	var dates: Array = world.matchday_dates
	return int(dates[mini(md, dates.size() - 1)])

func is_matchday_today() -> bool:
	return not season_over() and date_unix() >= matchday_date(matchday())

func days_until_matchday() -> int:
	if season_over():
		return 0
	return maxi(0, int((matchday_date(matchday()) - date_unix()) / DAY))

## Einen Tag weiterschalten (nicht über den anstehenden Spieltag hinaus).
## Rückgabe: {news: [Meldungen], decision: {} oder Entscheidungs-Ereignis}
func advance_day() -> Dictionary:
	if season_over() or is_matchday_today():
		return {"news": [], "decision": {}}
	world.date = date_unix() + DAY
	_daily_recovery()
	var result := _daily_events()
	# Spielvorbereitung: der Tag vor dem Spieltag gehört dem Matchplan
	if days_until_matchday() == 1 and not season_over():
		var f := next_fixture(my_club_id)
		if not f.is_empty():
			var home := int(f.home) == my_club_id
			var opponent := club(int(f.away) if home else int(f.home))
			result.news.append(_add_news("training", "Spielvorbereitung auf %s: Matchplan „%s“ wird einstudiert." % [opponent.name, match_plan]))
	return result

## Tage bis zum Spieltag durchlaufen (Tests/Schnellsimulation).
## Entscheidungen werden dabei automatisch abgelehnt.
func advance_to_matchday() -> Array:
	var collected: Array = []
	while not season_over() and not is_matchday_today():
		var r := advance_day()
		collected.append_array(r.news)
		if not r.decision.is_empty():
			collected.append(resolve_decision(r.decision, 1))
	return collected

func _add_news(kind: String, text: String) -> Dictionary:
	var entry := {"day": date_label(), "text": text, "kind": kind}
	news.push_front(entry)
	if news.size() > 60:
		news.resize(60)
	return entry

## Was passiert heute rund um deinen Verein? Meldungen haben Effekte,
## Entscheidungs-Ereignisse pausieren die Simulation und verlangen eine Wahl.
func _daily_events() -> Dictionary:
	var events: Array = []
	var c := my_club()
	var squad := c.players(world.players)

	# Trainingsverletzung (selten, aber bitter)
	if randf() < 0.02:
		var fit := squad.filter(func(p): return p.is_available())
		if not fit.is_empty():
			var p: PlayerData = fit.pick_random()
			p.injury_matchdays = randi_range(1, 2)
			events.append(_add_news("injury", "%s verletzt sich im Training und fällt %d Spieltag%s aus." % [
				p.full_name(), p.injury_matchdays, "" if p.injury_matchdays == 1 else "e"]))

	# Trainingsheld: Formschub für einen Spieler
	var excel_chance := 0.10 if training_focus == "Leistung" else 0.06
	if randf() < excel_chance and not squad.is_empty():
		var p: PlayerData = squad.pick_random()
		p.form = clampf(p.form + 0.02, 0.8, 1.2)
		events.append(_add_news("training", "%s überzeugt im Training – seine Form steigt." % p.full_name()))

	# Sponsor-Sonderzahlung
	if randf() < 0.02:
		var bonus := randi_range(2, 8) * 10000
		c.budget += bonus
		log_transaction("Sonderzahlung Sponsor", bonus)
		events.append(_add_news("sponsor", "Sponsor %s überweist eine Sonderzahlung von %s." % [c.sponsor_name, Fmt.money(bonus)]))

	# --- Entscheidungs-Ereignisse (max. eines pro Tag)
	var decision := {}

	# Transferangebot für einen deiner Spieler
	if randf() < 0.03 and squad.size() > 16:
		var p: PlayerData = squad.pick_random()
		var other_ids: Array = world.clubs.keys().filter(func(cid): return cid != my_club_id and world.clubs[cid].player_ids.size() < 29)
		if not other_ids.is_empty():
			var other: ClubData = world.clubs[other_ids.pick_random()]
			var price := maxi(int(p.market_value() * randf_range(0.9, 1.35) / 10000.0) * 10000, 50000)
			decision = {
				"kind": "transfer_offer", "pid": p.id, "club_id": other.id, "price": price,
				"title": "Transferangebot für %s" % p.full_name(),
				"text": "%s bietet %s für %s (%s, Stärke %d, Vertrag noch %d J.).\nMarktwert: %s. Verkaufen?" % [
					other.name, Fmt.money(price), p.full_name(), p.pos, p.strength, p.contract_years, Fmt.money(p.market_value())],
				"options": ["Verkaufen", "Ablehnen"],
			}

	# Freundschaftsspiel-Anfrage (nur wenn genug Abstand zum Spieltag)
	if decision.is_empty() and randf() < 0.03 and days_until_matchday() >= 3:
		var fee := int(c.capacity * randf_range(4.0, 6.0) / 10000.0) * 10000
		decision = {
			"kind": "friendly", "fee": fee,
			"title": "Freundschaftsspiel-Anfrage",
			"text": "Ein Verein aus der Region fragt für morgen ein Freundschaftsspiel an.\nEinnahmen: ca. %s – aber deine Spieler verlieren spürbar Frische." % Fmt.money(fee),
			"options": ["Zusagen (+%s)" % Fmt.money(fee), "Absagen"],
		}

	# Unzufriedener Ergänzungsspieler sucht das Gespräch
	if decision.is_empty() and randf() < 0.03:
		var bench := squad.filter(func(p): return not c.lineup.has(p.id))
		if not bench.is_empty():
			var p: PlayerData = bench.pick_random()
			decision = {
				"kind": "player_talk", "pid": p.id,
				"title": "Spielergespräch",
				"text": "%s (%s, Stärke %d) ist unzufrieden mit seiner Einsatzzeit und bittet um ein Gespräch." % [
					p.full_name(), p.pos, p.strength],
				"options": ["Gespräch suchen", "Abblocken"],
			}

	return {"news": events, "decision": decision}

## Wendet die Wahl eines Entscheidungs-Ereignisses an. Rückgabe: die Ergebnis-Meldung.
func resolve_decision(decision: Dictionary, choice: int) -> Dictionary:
	match decision.get("kind", ""):
		"transfer_offer":
			var p := get_player(int(decision.pid))
			if choice == 0 and my_club().player_ids.size() > 16 and p.club_id == my_club_id:
				var buyer: ClubData = world.clubs[int(decision.club_id)]
				my_club().player_ids.erase(p.id)
				my_club().lineup.erase(p.id)
				my_club().budget += int(decision.price)
				buyer.player_ids.append(p.id)
				p.club_id = buyer.id
				p.contract_years = 3
				log_transaction("Verkauf: %s an %s" % [p.full_name(), buyer.name], int(decision.price))
				return _add_news("transfer", "%s wechselt für %s zu %s." % [p.full_name(), Fmt.money(int(decision.price)), buyer.name])
			return _add_news("transfer", "Angebot abgelehnt: %s bleibt im Verein." % p.full_name())
		"friendly":
			if choice == 0:
				var fee := int(decision.fee)
				my_club().budget += fee
				log_transaction("Freundschaftsspiel", fee)
				for p in my_club().players(world.players):
					p.condition = maxf(0.0, p.condition - 8.0)
				return _add_news("sponsor", "Freundschaftsspiel absolviert: %s eingenommen, die Beine sind etwas schwerer." % Fmt.money(fee))
			return _add_news("presse", "Freundschaftsspiel-Anfrage abgesagt – volle Konzentration aufs Training.")
		"player_talk":
			var p := get_player(int(decision.pid))
			if choice == 0:
				if randf() < 0.40 + 0.06 * skill("motivation"):
					p.form = clampf(p.form + 0.05, 0.8, 1.2)
					return _add_news("training", "Dein Gespräch mit %s fruchtet – er brennt auf seine Chance." % p.full_name())
				p.form = clampf(p.form - 0.02, 0.8, 1.2)
				return _add_news("training", "Das Gespräch mit %s verlief frostig – er bleibt unzufrieden." % p.full_name())
			p.form = clampf(p.form - 0.03, 0.8, 1.2)
			return _add_news("training", "%s fühlt sich übergangen – seine Form leidet." % p.full_name())
	return {}

## Tägliche Erholung und Trainingseffekte. Die Fähigkeit "Training" und der
## Wochenschwerpunkt wirken auf den eigenen Verein.
func _daily_recovery() -> void:
	for pid in world.players:
		var p: PlayerData = world.players[pid]
		var regen := 5.0
		if p.club_id == my_club_id:
			regen += 0.21 * skill("training")
			var focus: Dictionary = TRAINING_FOCI.get(training_focus, TRAINING_FOCI.Ausgewogen)
			regen += focus.regen
			if training_focus == "Kondition" and p.stamina < 95 and randf() < 0.003:
				p.stamina += 1
			# Schwerpunkt-Training verbessert gezielt Attribute (Junge lernen schneller)
			var pool: Array = focus.pool
			if not pool.is_empty():
				var age_scale := 1.0 if p.age <= 21 else (0.6 if p.age <= 26 else 0.25)
				if randf() < float(focus.chance) * age_scale:
					var key: String = pool.pick_random()
					p.attributes[key] = clampi(p.attr(key) + 1, 3, 99)
					p.recompute_strength()
		p.condition = minf(100.0, p.condition + regen)

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
	# Einstudierter Matchplan aus der Spielvorbereitung wirkt nur in diesem Spiel
	if my_sim != null and MATCH_PLANS.has(match_plan):
		var plan: Dictionary = MATCH_PLANS[match_plan]
		if my_sim.home.id == my_club_id:
			my_sim.plan_h = plan
		else:
			my_sim.plan_a = plan
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
	# Der Matchplan ist verbraucht – nächste Woche neu wählen
	match_plan = "Ausgeglichen"
	_heal_and_suspend_tick()
	_apply_matchday_finances()
	world.matchday = matchday() + 1

## Nach jedem Spieltag: Verletzungen heilen und Sperren laufen ab (in Spieltagen gezählt).
## Die Frische regeneriert dagegen täglich über advance_day()/_daily_recovery().
func _heal_and_suspend_tick() -> void:
	for pid in world.players:
		var p: PlayerData = world.players[pid]
		if p.injury_matchdays > 0:
			p.injury_matchdays -= 1
			if p.injury_matchdays == 0 and p.club_id == my_club_id:
				_add_news("fit", "%s ist wieder fit und steigt ins Mannschaftstraining ein." % p.full_name())
		if p.suspended_matchdays > 0:
			p.suspended_matchdays -= 1
			if p.suspended_matchdays == 0 and p.club_id == my_club_id:
				_add_news("fit", "%s hat seine Sperre abgesessen und ist wieder spielberechtigt." % p.full_name())

## Komplettsimulation ohne Eingriffe (Tests, Schnellrechnung).
## Springt vorher per Tagessimulation zum Spieltagstermin.
## Rückgabe kompatibel: {mine: {fixture, res}, others: [{league, fixture}]}
func play_matchday() -> Dictionary:
	advance_to_matchday()
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
			coach_money += coach_cost
			# Siegprämie bei gewonnenem Spiel
			if win_bonus > 0 and not f.is_empty() and f.played:
				var my_goals: int = int(f.hg) if int(f.home) == cid else int(f.ag)
				var their_goals: int = int(f.ag) if int(f.home) == cid else int(f.hg)
				if my_goals > their_goals:
					c.budget -= win_bonus
					coach_money += win_bonus
					log_transaction("Siegprämie Trainer", -win_bonus)
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
	summary["bonus_paid"] = 0
	if goal_achieved:
		reputation += 1.5
		if goal_bonus > 0:
			coach_money += goal_bonus
			my_club().budget -= goal_bonus
			summary["bonus_paid"] = goal_bonus
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

	# Spieler entwickeln sich (VOR dem Statistik-Reset), altern, Verträge laufen ab
	var retiring: Array = []
	for pid in world.players:
		var p: PlayerData = world.players[pid]
		p.develop_by_strength(_season_development(p))
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
			p.salary = p.expected_salary()

	for pid in retiring:
		var p: PlayerData = world.players[pid]
		if p.club_id == my_club_id:
			summary.retired.append(p.full_name())
		club(p.club_id).player_ids.erase(pid)
		club(p.club_id).lineup.erase(pid)
		world.players.erase(pid)

	# Kader mit Jugendspielern auffüllen
	var min_per_pos := {"TW": 2, "IV": 3, "LV": 1, "RV": 1, "DM": 2, "ZM": 2, "LM": 1, "RM": 1, "OM": 1, "LA": 1, "RA": 1, "MS": 2}
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
	world.date = ScheduleGen.season_start(int(world.season_year))
	world.matchday_dates = ScheduleGen.matchday_dates(int(world.season_year))
	return summary

## Saison-Entwicklung in Stärkepunkten: steile Jugendkurve (ab 14!), Talent,
## Einsatzzeit (ab 18) bzw. Akademie-Training (bis 17), Noten, Entschlossenheit –
## gebremst vom Potenzial. Negativ ab Anfang 30.
func _season_development(p: PlayerData) -> float:
	var delta := 0.0
	if p.age <= 16:
		delta = 5.5
	elif p.age <= 19:
		delta = 4.0
	elif p.age <= 21:
		delta = 2.6
	elif p.age <= 23:
		delta = 1.6
	elif p.age <= 26:
		delta = 0.7
	elif p.age <= 29:
		delta = 0.0
	elif p.age <= 31:
		delta = -0.8
	elif p.age <= 33:
		delta = -1.9
	else:
		delta = -2.8
	if delta > 0.0:
		# Talent bestimmt das Tempo
		delta *= [0.5, 0.75, 1.0, 1.35, 1.75][p.talent - 1]
		if p.age <= 17:
			# Jugendliche wachsen im Akademie-Training – Jugendarbeit beschleunigt
			if p.club_id == my_club_id:
				delta *= 1.0 + skill("jugend") * 0.04
		else:
			# Profis brauchen Einsatzzeit und Leistung
			delta *= 0.6 + minf(p.matches_season, 28.0) / 28.0 * 0.8
			if p.matches_season >= 5:
				delta *= clampf(1.0 + (3.2 - p.avg_rating()) * 0.25, 0.8, 1.3)
		delta *= 1.0 + (p.attr("entschlossenheit") - 50.0) / 500.0
		if p.club_id == my_club_id and p.age <= 26 and TRAINING_FOCI.get(training_focus, {}).get("chance", 0.0) > 0.0:
			delta += 0.4
		# Potenzialbremse: nahe der eigenen Obergrenze wird die Luft dünn
		var headroom := float(p.potential - p.strength)
		if headroom <= 0.0:
			delta = 0.0
		else:
			delta = minf(delta, headroom) * clampf(headroom / 5.0, 0.25, 1.0)
	delta += randf_range(-0.3, 0.3)
	return clampf(delta, -4.0, 9.0)

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
	p.salary = p.expected_salary()
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
			"match_plan": match_plan,
			"coach_salary": coach_salary,
			"coach_years": coach_contract_years,
			"goal_bonus": goal_bonus,
			"win_bonus": win_bonus,
			"coach_money": coach_money,
			"season_goal": season_goal,
			"my_club_id": my_club_id,
			"club": my_club().name,
			"season_year": world.season_year,
			"matchday": matchday(),
			"saved_at": Time.get_datetime_string_from_system(false, true),
		},
		"world": _world_to_dict(),
		"transactions": transactions,
		"news": news,
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
	if not TRAINING_FOCI.has(training_focus):
		training_focus = "Ausgewogen"   # alte Spielstände (z. B. "Leistung")
	match_plan = data.meta.get("match_plan", "Ausgeglichen")
	coach_salary = int(data.meta.get("coach_salary", 20000))
	coach_contract_years = int(data.meta.get("coach_years", 2))
	goal_bonus = int(data.meta.get("goal_bonus", 0))
	win_bonus = int(data.meta.get("win_bonus", 0))
	coach_money = int(data.meta.get("coach_money", 0))
	season_goal = data.meta.get("season_goal", {})
	my_club_id = int(data.meta.my_club_id)
	if season_goal.is_empty():
		season_goal = {"text": "Klassenerhalt", "position": 15}
	transactions = data.get("transactions", [])
	news = data.get("news", [])
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
		"date": world.date,
		"matchday_dates": world.matchday_dates,
		"next_player_id": world.next_player_id,
		"players": players,
		"clubs": clubs,
		"leagues": leagues,
	}

func _world_from_dict(d: Dictionary) -> Dictionary:
	var w := {
		"season_year": int(d.season_year),
		"matchday": int(d.matchday),
		"date": int(d.get("date", 0)),
		"matchday_dates": [],
		"next_player_id": int(d.next_player_id),
		"players": {},
		"clubs": {},
		"leagues": {},
	}
	for t in d.get("matchday_dates", []):
		w.matchday_dates.append(int(t))
	if w.matchday_dates.is_empty():
		w.matchday_dates = ScheduleGen.matchday_dates(w.season_year)
	if w.date == 0:
		# Alte Spielstände ohne Kalender: Datum auf den anstehenden Spieltag setzen
		w.date = int(w.matchday_dates[mini(w.matchday, w.matchday_dates.size() - 1)])
	for key in d.players:
		w.players[int(key)] = PlayerData.from_dict(d.players[key])
	for key in d.clubs:
		w.clubs[int(key)] = ClubData.from_dict(d.clubs[key])
	for key in d.leagues:
		w.leagues[int(key)] = LeagueData.from_dict(d.leagues[key])
	return w
