extends Node
## Autoload "Game": hält den kompletten Spielstand (Welt, eigener Verein, Finanzen)
## und steuert Spieltage, Saisonwechsel, Transfers sowie Speichern/Laden.

const SAVE_DIR := "user://saves"
## Termine im gemeinsamen Spieltagskalender: 34 Samstage + 4 englische Wochen.
## Die 18er-Ligen spielen nur an den Samstagen, die 20er-Ligen an allen 38.
const ROUNDS_PER_SEASON := 38
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
var coach_exit_clause := false # Ausstiegsklausel: erlaubt den ablösefreien Wechsel trotz Vertrag
var coach_money := 0           # Dein persönliches Trainerkonto (Gehalt + Prämien)
var season_goal := {}          # Saisonziel des Vorstands: {text, position}
var season_just_rolled := false  # true direkt nach dem Saisonabschluss (Hub zeigt Angebote)
var lineup_presets: Array = [] # gespeicherte Aufstellungen: {name, formation, lineup, spots, bench}
var pick_weights := {"str": 1.0, "fresh": 0.4, "form": 0.4}  # Kriterien der Auto-Aufstellung
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
	coach_exit_clause = bool(setup.get("exit_clause", false))
	coach_money = 0
	season_goal = setup.get("season_goal", _board_goal_for(my_club()))
	lineup_presets = []
	pick_weights = {"str": 1.0, "fresh": 0.4, "form": 0.4}
	transactions.clear()
	news.clear()
	initialized = true
	my_club().budget = int(my_club().budget * DIFFICULTY_FACTORS.get(difficulty, 1.0))

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
	if not world.leagues.has(c.league_id):
		return {"text": "Klassenerhalt", "position": 15}
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

## Alle Spieltage gespielt – es folgt die Sommerpause bis zum 30. Juni.
func season_over() -> bool:
	return matchday() >= ROUNDS_PER_SEASON

## Der 1. Juli ist erreicht: Die Spielzeit ist kalendarisch vorbei und muss
## abgeschlossen werden (Auf-/Abstieg, Entwicklung, neuer Spielplan).
func season_rollover_due() -> bool:
	return date_unix() >= ScheduleGen.season_start(int(world.season_year) + 1)

## Letzter Tag der laufenden Spielzeit (30. Juni).
func season_end_unix() -> int:
	return ScheduleGen.season_end(int(world.season_year))

## Tage bis zum Saisonabschluss – nur nach dem letzten Spieltag interessant.
func days_until_season_end() -> int:
	return maxi(0, int((ScheduleGen.season_start(int(world.season_year) + 1) - date_unix()) / DAY))

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

## Heute wird irgendwo gespielt – auch an englischen Wochen, an denen nur die
## Dritte Liga und die Regionalliga antreten.
func is_matchday_today() -> bool:
	return not season_over() and date_unix() >= matchday_date(matchday())

## Spielt MEINE Mannschaft an diesem Spieltag? An englischen Wochen nicht,
## wenn sie in einer 18er-Liga steht.
func my_match_today() -> bool:
	return is_matchday_today() and my_league().plays_in_round(matchday())

## Spieltagsnummer innerhalb der eigenen Liga (für Anzeigen wie „12/34").
func my_matchday_number() -> int:
	var lg := my_league()
	var own: Array = lg.own_rounds()
	if own.is_empty():
		return 0
	var idx := own.find(matchday())
	if idx >= 0:
		return idx + 1
	return mini(lg.matchdays_done(matchday()) + 1, own.size())

func my_matchdays_total() -> int:
	return maxi(my_league().own_rounds().size(), 1)

## Termin der nächsten eigenen Partie (nicht des nächsten Spieltags überhaupt).
func next_fixture_date(cid: int) -> int:
	var f := next_fixture(cid)
	return matchday_date(int(f.round)) if not f.is_empty() else matchday_date(matchday())

func days_until_matchday() -> int:
	if season_over():
		return 0
	return maxi(0, int((matchday_date(matchday()) - date_unix()) / DAY))

## Realistischer Tagesrhythmus: Was steht an einem beliebigen Kalendertag an?
## Rückgabe: {kind, text} mit kind aus
## matchday · prep (Vortag) · rest (Tag nach dem Spiel) · preseason
## (Sommervorbereitung vor dem 1. Spieltag) · winter (Winterpause) ·
## free (spielfreier Sonntag) · training · offseason (vor dem Saisonstart).
func day_kind(unix: int) -> Dictionary:
	var dates: Array = world.matchday_dates
	if dates.is_empty():
		return {"kind": "training", "text": "Training"}
	var day_start := unix - (unix % DAY)
	var first := int(dates[0])
	var last := int(dates[dates.size() - 1])
	# Spieltag / Vortag / Tag danach
	for i in dates.size():
		var md_day := int(dates[i]) - (int(dates[i]) % DAY)
		if day_start == md_day:
			return {"kind": "matchday", "text": "Spieltag %d" % (i + 1), "matchday": i}
		if day_start == md_day - DAY:
			return {"kind": "prep", "text": "Spielvorbereitung", "matchday": i}
		if day_start == md_day + DAY:
			return {"kind": "rest", "text": "Regeneration"}
	# Vor dem ersten Spieltag: Sommerpause bzw. Vorbereitung ab Saisonstart
	if day_start < first:
		var start := int(ScheduleGen.season_start(int(world.season_year)))
		if day_start < start - (start % DAY):
			return {"kind": "offseason", "text": "Sommerpause"}
		return {"kind": "preseason", "text": "Vorbereitung"}
	if day_start > last:
		# Nach dem letzten Spieltag bis zum 30. Juni: Sommerpause
		return {"kind": "offseason", "text": "Sommerpause"}
	# Längere Lücke zwischen zwei Spieltagen (mehr als 10 Tage) = Winterpause
	for i in range(dates.size() - 1):
		var a := int(dates[i])
		var b := int(dates[i + 1])
		if b - a > 10 * DAY and day_start > a + DAY and day_start < b - DAY:
			return {"kind": "winter", "text": "Winterpause"}
	# Sonntag ohne Spiel ist frei
	if int(Time.get_datetime_dict_from_unix_time(day_start).weekday) == 0:
		return {"kind": "free", "text": "Spielfrei"}
	return {"kind": "training", "text": "Training"}

## Einen Tag weiterschalten (nicht über den anstehenden Spieltag hinaus).
## Rückgabe: {news: [Meldungen], decision: {} oder Entscheidungs-Ereignis}
func advance_day() -> Dictionary:
	# Nach dem letzten Spieltag läuft der Kalender weiter bis zum 30. Juni –
	# erst der 1. Juli stoppt ihn für den Saisonabschluss.
	if is_matchday_today() or season_rollover_due():
		return {"news": [], "decision": {}}
	world.date = date_unix() + DAY
	_daily_recovery()
	var result := _daily_events()
	# Spielvorbereitung: der Tag vor dem Spieltag gehört dem Matchplan (Popup im Hub)
	result["prep"] = days_until_matchday() == 1 and not season_over()
	return result

## Meldung nach der Matchplan-Wahl in der Spielvorbereitung.
func note_prep() -> Dictionary:
	var opponent_name := "den Gegner"
	var f := next_fixture(my_club_id)
	if not f.is_empty():
		opponent_name = club(int(f.away) if int(f.home) == my_club_id else int(f.home)).name
	return _add_news("training", "Spielvorbereitung auf %s: Matchplan „%s“ einstudiert." % [opponent_name, match_plan])

## Tage bis zum Spieltag durchlaufen (Tests/Schnellsimulation).
## Entscheidungen werden dabei automatisch abgelehnt.
func advance_to_matchday() -> Array:
	var collected: Array = []
	while not season_over() and not is_matchday_today():
		var r := advance_day()
		collected.append_array(r.news)
		if not r.decision.is_empty():
			collected.append(resolve_decision(r.decision, 1))
		if r.get("prep", false):
			collected.append(note_prep())
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
	var kind: String = str(day_kind(date_unix()).kind)
	# In der Sommerpause hat die Mannschaft frei: kein Training, keine
	# Trainingsverletzungen – nur der Kalender läuft weiter.
	var resting := kind == "offseason"

	# Trainingsverletzung (selten, aber bitter)
	if not resting and randf() < 0.02:
		var fit := squad.filter(func(p): return p.is_available())
		if not fit.is_empty():
			var p: PlayerData = fit.pick_random()
			p.injury_matchdays = randi_range(1, 2)
			events.append(_add_news("injury", "%s verletzt sich im Training und fällt %d Spieltag%s aus." % [
				p.full_name(), p.injury_matchdays, "" if p.injury_matchdays == 1 else "e"]))

	# Trainingsheld: Formschub für einen Spieler
	var excel_chance := 0.0 if resting else (0.10 if training_focus == "Leistung" else 0.06)
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

	# Testspiel-Anfrage: in der Vorbereitung häufig, während der Saison selten,
	# und nur mit genug Abstand zum nächsten Pflichtspiel
	var friendly_chance := 0.0
	if kind == "preseason":
		friendly_chance = 0.30
	elif kind == "winter":
		friendly_chance = 0.16
	elif days_until_matchday() >= 4:
		friendly_chance = 0.05
	if randf() < friendly_chance:
		decision = _friendly_request()

	# Spielergespräch: ein Spieler sucht mit einem konkreten Anliegen das Gespräch
	if decision.is_empty() and not resting and randf() < 0.05:
		decision = _player_talk_request(squad, c)

	return {"news": events, "decision": decision}

## Testspiel-Anfrage gegen einen konkreten Gegner (schwächerer Verein der Region).
func _friendly_request() -> Dictionary:
	var candidates: Array = []
	for cid in world.clubs:
		if cid != my_club_id:
			candidates.append(cid)
	if candidates.is_empty():
		return {}
	var opponent: ClubData = world.clubs[candidates.pick_random()]
	var fee := int(my_club().capacity * randf_range(3.0, 6.0) / 10000.0) * 10000
	return {
		"kind": "friendly", "opponent_id": opponent.id, "fee": fee,
		"title": "Testspiel-Anfrage: %s" % opponent.name,
		"text": "%s (%s, Mannschaftsstärke %d) fragt ein Testspiel für morgen an.\n\nEinnahmen: %s. Testspiele kosten Frische, bringen aber Spielpraxis und Formaufbau – Karten und Tore zählen nicht für die Saison." % [
			opponent.name, world.leagues[opponent.league_id].name,
			opponent.team_strength(world.players), Fmt.money(fee)],
		"options": ["Testspiel austragen", "Absagen"],
	}

## Spielergespräch mit konkretem Anliegen und mehreren Antwortmöglichkeiten.
func _player_talk_request(squad: Array, c: ClubData) -> Dictionary:
	if squad.is_empty():
		return {}
	# Anliegen abhängig von der Situation des Spielers
	var reserves: Array = squad.filter(func(p): return not c.lineup.has(p.id) and p.is_available())
	var starters: Array = squad.filter(func(p): return c.lineup.has(p.id))
	var topic := ""
	var p: PlayerData
	var roll := randf()
	if not reserves.is_empty() and roll < 0.45:
		p = reserves.pick_random()
		topic = "einsatzzeit"
	elif not starters.is_empty() and roll < 0.7:
		p = starters.pick_random()
		topic = "form" if p.form < 1.0 else "lob"
	elif not squad.is_empty() and roll < 0.85:
		p = squad.pick_random()
		topic = "vertrag"
	else:
		p = squad.pick_random()
		topic = "kritik"
	return {
		"kind": "player_talk", "pid": p.id, "topic": topic,
		"title": "Gespräch mit %s" % p.full_name(),
	}

## Gesprächsinhalte: Anliegen des Spielers und die möglichen Antworten.
## Jede Antwort hat eine Grundwirkung auf die Form und eine Erfolgschance,
## die von der Trainer-Fähigkeit "Motivation" abhängt.
const TALK_TOPICS := {
	"einsatzzeit": {
		"opening": "Trainer, ich sitze seit Wochen nur draußen. Ich will spielen – oder ich muss mir Gedanken machen.",
		"replies": [
			{"text": "Du bekommst dein Spiel – ich stelle dich als Nächstes auf.", "risk": 0.0, "good": 0.10, "bad": -0.02, "hint": "Versprechen (wirkt stark, verpflichtet dich)"},
			{"text": "Zeig es mir im Training, dann kommst du zum Zug.", "risk": 0.25, "good": 0.05, "bad": -0.03, "hint": "Fordernd"},
			{"text": "Du bist Ergänzungsspieler – akzeptier deine Rolle.", "risk": 0.55, "good": 0.02, "bad": -0.07, "hint": "Hart (riskant)"},
		],
	},
	"form": {
		"opening": "Bei mir läuft gerade gar nichts. Ich weiß selbst nicht, woran es liegt.",
		"replies": [
			{"text": "Kopf hoch – ich glaube an dich, du spielst weiter.", "risk": 0.15, "good": 0.09, "bad": -0.02, "hint": "Rückendeckung"},
			{"text": "Wir arbeiten im Training gezielt daran.", "risk": 0.20, "good": 0.07, "bad": -0.02, "hint": "Sachlich"},
			{"text": "Dann nimm dir eine Pause und ordne deine Gedanken.", "risk": 0.35, "good": 0.05, "bad": -0.05, "hint": "Pause verordnen"},
		],
	},
	"lob": {
		"opening": "Ich fühle mich richtig gut gerade – das wollte ich dir mal sagen.",
		"replies": [
			{"text": "Das sehe ich auch – mach genau so weiter!", "risk": 0.05, "good": 0.06, "bad": -0.01, "hint": "Bestätigen"},
			{"text": "Schön – aber jetzt erst recht Vollgas, nicht nachlassen.", "risk": 0.25, "good": 0.08, "bad": -0.03, "hint": "Anspornen"},
			{"text": "Freut mich. Bleib bescheiden.", "risk": 0.15, "good": 0.03, "bad": -0.02, "hint": "Zurückhaltend"},
		],
	},
	"vertrag": {
		"opening": "Mein Berater hat angerufen. Wie sieht der Verein meine Zukunft hier?",
		"replies": [
			{"text": "Du bist fester Bestandteil unserer Planung.", "risk": 0.10, "good": 0.07, "bad": -0.02, "hint": "Zusagen"},
			{"text": "Das entscheiden deine Leistungen der nächsten Wochen.", "risk": 0.30, "good": 0.05, "bad": -0.04, "hint": "Offen halten"},
			{"text": "Konzentrier dich aufs Spielen, den Rest klärt der Vorstand.", "risk": 0.45, "good": 0.02, "bad": -0.06, "hint": "Abwimmeln"},
		],
	},
	"kritik": {
		"opening": "Ehrlich gesagt verstehe ich deine Taktik nicht – so kommen wir nicht weiter.",
		"replies": [
			{"text": "Erklär mir, was dich stört – ich höre zu.", "risk": 0.15, "good": 0.07, "bad": -0.03, "hint": "Zuhören"},
			{"text": "Ich erkläre dir die Idee dahinter in Ruhe.", "risk": 0.25, "good": 0.06, "bad": -0.03, "hint": "Überzeugen"},
			{"text": "Ich entscheide, wie wir spielen. Punkt.", "risk": 0.60, "good": 0.03, "bad": -0.09, "hint": "Machtwort"},
		],
	},
}

## Gesprächsdaten für das UI (Anliegen + Antwortmöglichkeiten).
func talk_content(decision: Dictionary) -> Dictionary:
	var topic := str(decision.get("topic", "einsatzzeit"))
	return TALK_TOPICS.get(topic, TALK_TOPICS["einsatzzeit"])

## Führt eine Gesprächsantwort aus. Rückgabe: {text, success, news}
func resolve_talk(decision: Dictionary, reply_index: int) -> Dictionary:
	var p := get_player(int(decision.pid))
	var content := talk_content(decision)
	var replies: Array = content.replies
	var reply: Dictionary = replies[clampi(reply_index, 0, replies.size() - 1)]
	# Motivation des Trainers senkt das Risiko, dass die Antwort daneben geht
	var risk: float = maxf(float(reply.risk) - 0.045 * skill("motivation"), 0.0)
	# Eigene Eigenschaften des Spielers: Hitzköpfe reagieren gereizter
	if p.has_trait("Hitzkopf"):
		risk += 0.1
	if p.has_trait("Führungsspieler"):
		risk -= 0.05
	var success := randf() > risk
	var delta: float = float(reply.good) if success else float(reply.bad)
	p.form = clampf(p.form + delta, 0.8, 1.2)
	var text := ""
	if success:
		text = "%s nickt: „Verstanden, Trainer.“ – er geht bestärkt aus dem Gespräch." % p.full_name()
	else:
		text = "%s bleibt sichtlich unzufrieden – das Gespräch hat ihn nicht erreicht." % p.full_name()
	var news := _add_news("training", "Gespräch mit %s: %s" % [p.full_name(), "positiv aufgenommen" if success else "verlief schwierig"])
	return {"text": text, "success": success, "news": news, "delta": delta}

# ------------------------------------------------------------------ Gespeicherte Aufstellungen

## Sichert die aktuelle Aufstellung (Formation, Elf, Feldpositionen, Bank)
## unter einem Namen. Ein vorhandener Eintrag gleichen Namens wird ersetzt.
func save_lineup_preset(preset_name: String) -> String:
	var c := my_club()
	var clean := preset_name.strip_edges()
	if clean == "":
		clean = "%s %s" % [c.shape_label(), date_label()]
	var entry := {
		"name": clean,
		"formation": c.formation,
		"lineup": c.lineup.duplicate(),
		"bench": c.bench.duplicate(),
		"spots": c.lineup_spots.map(func(v): return [snappedf(v.x, 0.001), snappedf(v.y, 0.001)]),
	}
	for i in lineup_presets.size():
		if str(lineup_presets[i].name) == clean:
			lineup_presets[i] = entry
			return clean
	lineup_presets.append(entry)
	return clean

## Lädt eine gespeicherte Aufstellung. Fehlende oder nicht einsatzbereite
## Spieler werden durch die beste verfügbare Alternative ersetzt.
## Rückgabe: Anzahl der ersetzten Spieler.
func load_lineup_preset(index: int) -> int:
	if index < 0 or index >= lineup_presets.size():
		return -1
	var preset: Dictionary = lineup_presets[index]
	var c := my_club()
	c.formation = str(preset.get("formation", c.formation))
	c.lineup_spots.clear()
	for spot in preset.get("spots", []):
		c.lineup_spots.append(Vector2(float(spot[0]), float(spot[1])))
	# Elf übernehmen, soweit die Spieler noch da und fit sind
	var wanted: Array = []
	var replaced := 0
	for pid in preset.get("lineup", []):
		var id := int(pid)
		if c.player_ids.has(id) and world.players[id].is_available():
			wanted.append(id)
		else:
			wanted.append(-1)
			replaced += 1
	# Lücken mit den besten verfügbaren Spielern auffüllen
	if wanted.has(-1):
		var slots: Array = c.lineup_slots() if c.lineup_spots.size() == wanted.size() else ClubData.FORMATIONS[c.formation]
		var free := c.players(world.players).filter(func(p):
			return p.is_available() and not wanted.has(p.id))
		for i in wanted.size():
			if wanted[i] >= 0 or free.is_empty():
				continue
			var slot: String = slots[i] if i < slots.size() else "ZM"
			free.sort_custom(func(a, b): return a.strength_at(slot) > b.strength_at(slot))
			wanted[i] = free[0].id
			free.remove_at(0)
	c.lineup = wanted.filter(func(pid): return pid > 0)
	if c.lineup_spots.size() != c.lineup.size():
		c.lineup_spots = ClubData.FORMATION_SPOTS.get(c.formation, ClubData.FORMATION_SPOTS["4-4-2"]).duplicate()
	# Bank übernehmen, Rest auffüllen
	var bench: Array = []
	for pid in preset.get("bench", []):
		var id := int(pid)
		if c.player_ids.has(id) and world.players[id].is_available() and not c.lineup.has(id):
			bench.append(id)
	c.bench = bench if not bench.is_empty() else c.best_bench(world.players, c.lineup, pick_weights)
	return replaced

func delete_lineup_preset(index: int) -> void:
	if index >= 0 and index < lineup_presets.size():
		lineup_presets.remove_at(index)

## Trägt ein Testspiel gegen den angefragten Gegner aus (echte Simulation).
## Rückgabe: {hg, ag, opponent, goals: [{min, name, home}], fee}
func play_friendly(opponent_id: int) -> Dictionary:
	var opponent := club(opponent_id)
	var me := my_club()
	var sim := MatchSim.new()
	sim.is_friendly = true
	sim.setup(me, opponent, world.players)
	sim.run_full()
	var fee := int(me.capacity * randf_range(3.0, 6.0) / 10000.0) * 10000
	me.budget += fee
	log_transaction("Testspiel gegen %s" % opponent.name, fee)
	var goals: Array = []
	for entry in sim.goal_log:
		goals.append({
			"min": int(entry.min), "home": bool(entry.home),
			"name": get_player(int(entry.pid)).full_name(),
		})
	_add_news("friendly", "Testspiel: %s %d:%d %s (Einnahmen %s)." % [
		me.short_name, sim.hg, sim.ag, opponent.short_name, Fmt.money(fee)])
	return {"hg": sim.hg, "ag": sim.ag, "opponent": opponent, "goals": goals, "fee": fee, "sim": sim}

## Wendet die Wahl eines einfachen Entscheidungs-Ereignisses an.
func resolve_decision(decision: Dictionary, choice: int) -> Dictionary:
	match decision.get("kind", ""):
		"friendly":
			if choice == 0:
				return {}   # Das Testspiel wird über play_friendly ausgetragen
			return _add_news("presse", "Testspiel-Anfrage abgesagt – volle Konzentration aufs Training.")
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
			# Schwerpunkt-Training verbessert gezielt Attribute (Junge lernen schneller,
			# Trainingsweltmeister sowieso, Trainingsmuffel kaum)
			var pool: Array = focus.pool
			if not pool.is_empty():
				var age_scale := 1.0 if p.age <= 21 else (0.6 if p.age <= 26 else 0.25)
				if p.has_trait("Trainingsweltmeister"):
					age_scale *= 1.6
				elif p.has_trait("Trainingsmuffel"):
					age_scale *= 0.5
				if randf() < float(focus.chance) * age_scale:
					var key: String = pool.pick_random()
					p.attributes[key] = clampi(p.attr(key) + 1, 3, 99)
					p.recompute_strength()
		p.condition = minf(100.0, p.condition + regen)

func next_fixture(cid: int) -> Dictionary:
	if season_over():
		return {}
	# Ab dem aktuellen Termin suchen: An englischen Wochen pausieren die
	# 18er-Ligen, ihr nächstes Spiel liegt dann einen Slot später.
	return league(club(cid).league_id).next_fixture_of(cid, matchday())

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
			# KI-Vereine reagieren auf ihren verfügbaren Kader: passende Formation
			# wählen (Verletzte/Gesperrte eingerechnet) und beste Elf aufstellen
			for cid in [int(f.home), int(f.away)]:
				if cid != my_club_id:
					var c := club(cid)
					c.formation = c.pick_best_formation(world.players)
					c.lineup = c.best_eleven(world.players)
					c.lineup_spots = []
			var sim := MatchSim.new()
			sim.setup(club(int(f.home)), club(int(f.away)), world.players)
			sim.fixture = f
			sim.league_name = lg.name
			_set_ai_mentality(sim)
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

## KI-Grundausrichtung: Außenseiter mauern, klare Favoriten drücken –
## plus etwas Trainer-Eigenart, damit nicht alle gleich spielen.
func _set_ai_mentality(sim: MatchSim) -> void:
	var str_h := sim.home.overall_strength(world.players)
	var str_a := sim.away.overall_strength(world.players)
	if sim.home.id != my_club_id:
		var diff_h := str_h - str_a
		if diff_h <= -5.0 or (diff_h < 0.0 and randf() < 0.3):
			sim.mentality_h = "defensiv"
		elif diff_h >= 6.0 or (diff_h > 2.0 and randf() < 0.35):
			sim.mentality_h = "offensiv"
		elif randf() < 0.12:
			sim.mentality_h = ["defensiv", "offensiv"].pick_random()
	if sim.away.id != my_club_id:
		var diff_a := str_a - str_h
		if diff_a <= -3.0 or (diff_a < 0.0 and randf() < 0.4):
			sim.mentality_a = "defensiv"
		elif diff_a >= 8.0 or (diff_a > 4.0 and randf() < 0.3):
			sim.mentality_a = "offensiv"
		elif randf() < 0.12:
			sim.mentality_a = ["defensiv", "offensiv"].pick_random()

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
		# Nur zählen, wenn die Liga des Spielers an diesem Termin gespielt hat
		var player_league: int = club(p.club_id).league_id
		if not world.leagues.has(player_league) or not world.leagues[player_league].plays_in_round(matchday()):
			continue
		if p.injury_matchdays > 0:
			p.injury_matchdays -= 1
			if p.injury_matchdays == 0 and p.club_id == my_club_id:
				_add_news("fit", "%s ist wieder fit und steigt ins Mannschaftstraining ein." % p.full_name())
		if p.suspended_matchdays > 0:
			p.suspended_matchdays -= 1
			if p.suspended_matchdays == 0 and p.club_id == my_club_id:
				_add_news("fit", "%s hat seine Sperre abgesessen und ist wieder spielberechtigt." % p.full_name())

## Spieltag OHNE eigene Beteiligung (englische Woche der unteren Ligen):
## läuft automatisch durch. Rückgabe: kurze Meldung für den Wochendurchlauf.
func simulate_matchday_without_me() -> Dictionary:
	var md := start_matchday()
	for sim in md.others:
		sim.run_full()
	if md.mine != null:
		md.mine.run_full()
	var names: Array = []
	for lid in world.leagues:
		var lg: LeagueData = world.leagues[lid]
		if lg.plays_in_round(matchday()):
			names.append(lg.short_name if lg.short_name != "" else lg.name)
	finish_matchday(md)
	return _add_news("matchday", "Englische Woche: %s spielen einen Spieltag ohne dich." % ", ".join(names))

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
		if not world.leagues.has(c.league_id):
			continue   # Oberliga-Verein: wartet nur, spielt nicht
		var lg: LeagueData = world.leagues[c.league_id]
		# An englischen Wochen pausieren die 18er-Ligen – dann fallen dort weder
		# Zuschauereinnahmen noch Gehälter für diesen Spieltag an
		if not lg.plays_in_round(matchday()):
			continue
		var f := lg.fixture_of(cid, matchday())
		var ticket := 0
		if not f.is_empty() and int(f.home) == cid:
			var fill := clampf(c.expected_fill() + randf_range(-0.1, 0.1), 0.3, 1.0)
			ticket = int(c.capacity * fill) * c.ticket_price()
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
	var tables := {}      # league_id -> Abschlusstabelle (Zeilen)
	for lid in world.leagues:
		tables[lid] = world.leagues[lid].table()

	var display_tables: Array = []
	for def in Data.LEAGUE_DEFS:
		if world.leagues.has(int(def.id)):
			display_tables.append(_final_table(world.leagues[int(def.id)], tables[int(def.id)]))

	var summary := {
		"season": season_label(),
		"season_year": int(world.season_year),
		"champion1": club(tables[1][0].club_id).name,
		"champion2": club(tables[2][0].club_id).name,
		"relegated": [],
		"promoted": [],
		"retired": [],
		"my_position": my_league().position_of(my_club_id),
		"my_league_name": my_league().name,
		# Abschlussdaten VOR jeder Veränderung sichern – danach sind Tabellen
		# geleert, Statistiken zurückgesetzt und Spieler gealtert.
		"tables": display_tables,
		"scorers": _season_scorers(),
		"ratings": _season_best_rated(),
		"my_squad": _my_season_squad(),
		"my_row": _my_table_row(tables[my_club().league_id]),
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

	_apply_promotion_and_relegation(tables, summary)

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
		if randf() < _retire_chance(p):
			retiring.append(pid)
		elif p.contract_years <= 0:
			# Automatische Verlängerung (KI wie Spieler) – Vertragsverhandlungen kommen in einer späteren Ausbaustufe
			p.contract_years = randi_range(2, 3)
			p.salary = p.expected_salary()

	summary["retired_notable"] = []
	for pid in retiring:
		var p: PlayerData = world.players[pid]
		if p.club_id == my_club_id:
			summary.retired.append("%s (%d J.)" % [p.full_name(), p.age])
		# Ins Karriereenden-Archiv statt ins Nichts – Grundlage für spätere Rekordlisten
		world.retired.append({
			"name": p.full_name(), "pos": p.pos, "age": p.age, "talent": p.talent,
			"club": club(p.club_id).name, "strength": p.strength, "season": season_label(),
		})
		if p.strength >= 74 and p.club_id != my_club_id:
			summary.retired_notable.append("%s (%s, %d J., Stärke %d)" % [p.full_name(), club(p.club_id).short_name, p.age, p.strength])
		if p.strength >= 74 or p.club_id == my_club_id:
			_add_news("retirement", "Karriereende: %s (%s) tritt mit %d Jahren ab." % [p.full_name(), club(p.club_id).name, p.age])
		club(p.club_id).player_ids.erase(pid)
		club(p.club_id).lineup.erase(pid)
		world.players.erase(pid)

	# Kader mit Jugendspielern auffüllen – der Nachwuchs rückt sichtbar nach
	var min_per_pos := {"TW": 2, "IV": 3, "LV": 1, "RV": 1, "DM": 2, "ZM": 2, "LM": 1, "RM": 1, "OM": 1, "LA": 1, "RA": 1, "MS": 2}
	summary["new_youth"] = []
	for cid in world.clubs:
		var c: ClubData = world.clubs[cid]
		# Fähigkeit "Jugendarbeit": der eigene Nachwuchs kommt stärker aus der Akademie
		var youth_bonus: int = (skill("jugend") >> 1) if cid == my_club_id else 0
		for pos in min_per_pos:
			while c.players_by_pos(world.players, pos).size() < min_per_pos[pos]:
				var yp := Data.create_youth_player(world, c, pos, youth_bonus)
				if cid == my_club_id:
					summary.new_youth.append("%s (%s, %d J., Talent %s)" % [yp.full_name(), yp.pos, yp.age, yp.talent_stars()])
					_add_news("youth", "Aus der eigenen Jugend: %s (%s, %d J.) rückt in den Profikader auf." % [yp.full_name(), yp.pos, yp.age])
		c.lineup = c.best_eleven(world.players)
		# Sponsor-/TV-Verträge an die neue Liga und den aktuellen Kader anpassen
		c.refresh_sponsor(world.players)

	# Neue Saison
	for lid in world.leagues:
		var lg: LeagueData = world.leagues[lid]
		lg.fixtures = ScheduleGen.build_league_fixtures(lg.club_ids)
	world.matchday = 0
	world.season_year = int(world.season_year) + 1
	world.date = ScheduleGen.season_start(int(world.season_year))
	world.matchday_dates = ScheduleGen.matchday_dates(int(world.season_year))
	return summary

## Auf- und Abstiegsregeln je Liga (Positionen 1-basiert gedacht):
## up_direct   = direkte Aufstiegsplätze von oben
## up_playoff  = 1, wenn der Platz danach in die Relegation muss
## down_direct = direkte Abstiegsplätze von unten
## down_playoff= 1, wenn der Platz darüber in die Relegation muss
## Die fünf Regionalliga-Staffeln spielen um vier Plätze in der Dritten Liga:
## Die drei besten Staffelmeister steigen direkt auf, die beiden übrigen
## ermitteln den vierten Aufsteiger in der Aufstiegsrelegation.
const LEAGUE_RULES := {
	1: {"up_direct": 0, "up_playoff": 0, "down_direct": 2, "down_playoff": 1},
	2: {"up_direct": 2, "up_playoff": 1, "down_direct": 2, "down_playoff": 1},
	3: {"up_direct": 2, "up_playoff": 1, "down_direct": 4, "down_playoff": 0},
	4: {"up_direct": 0, "up_playoff": 1, "down_direct": 0, "down_playoff": 0},
	5: {"up_direct": 0, "up_playoff": 1, "down_direct": 0, "down_playoff": 0},
	6: {"up_direct": 0, "up_playoff": 1, "down_direct": 0, "down_playoff": 0},
	7: {"up_direct": 0, "up_playoff": 1, "down_direct": 0, "down_playoff": 0},
	8: {"up_direct": 0, "up_playoff": 1, "down_direct": 0, "down_playoff": 0},
}

## Abschlusstabelle einer Liga als reine Anzeigedaten, Markierungen aus den
## Auf-/Abstiegsregeln der Liga.
func _final_table(lg: LeagueData, rows: Array) -> Dictionary:
	var rules: Dictionary = LEAGUE_RULES.get(lg.id, LEAGUE_RULES[4])
	var out: Array = []
	for i in rows.size():
		var row: Dictionary = rows[i]
		var c := club(int(row.club_id))
		var mark := ""
		if i == 0:
			mark = "champion"
		elif i < int(rules.up_direct):
			mark = "promoted"
		elif int(rules.up_playoff) > 0 and i == int(rules.up_direct):
			mark = "playoff_up"
		elif i >= rows.size() - int(rules.down_direct):
			mark = "relegated"
		elif int(rules.down_playoff) > 0 and i == rows.size() - int(rules.down_direct) - 1:
			mark = "playoff_down"
		out.append({
			"pos": i + 1, "club_id": c.id, "name": c.name, "short": c.short_name, "color": c.color,
			"played": int(row.played), "won": int(row.won), "drawn": int(row.drawn), "lost": int(row.lost),
			"gf": int(row.gf), "ga": int(row.ga), "diff": int(row.gf) - int(row.ga),
			"points": int(row.points), "mark": mark, "mine": c.id == my_club_id,
		})
	return {"league": lg.name, "league_id": lg.id, "playable": lg.playable, "rows": out}

## Zeile der eigenen Mannschaft aus der Abschlusstabelle.
func _my_table_row(rows: Array) -> Dictionary:
	for i in rows.size():
		if int(rows[i].club_id) == my_club_id:
			var row: Dictionary = rows[i]
			return {"pos": i + 1, "played": int(row.played), "won": int(row.won), "drawn": int(row.drawn),
				"lost": int(row.lost), "gf": int(row.gf), "ga": int(row.ga), "points": int(row.points)}
	return {}

## Torjägerliste beider Ligen (die besten 12).
func _season_scorers() -> Array:
	var list: Array = []
	for pid in world.players:
		var p: PlayerData = world.players[pid]
		if p.goals_season <= 0:
			continue
		var c := club(p.club_id)
		list.append({"name": p.full_name(), "pos": p.pos, "nat": p.nat, "short": c.short_name,
			"color": c.color, "league": c.league_id, "goals": p.goals_season,
			"matches": p.matches_season, "mine": p.club_id == my_club_id})
	list.sort_custom(func(a, b): return int(a.goals) > int(b.goals))
	return list.slice(0, 12)

## Der eigene Kader mit seiner Saisonbilanz, nach Note sortiert.
func _my_season_squad() -> Array:
	var list: Array = []
	for pid in my_club().player_ids:
		if not world.players.has(pid):
			continue
		var p: PlayerData = world.players[pid]
		if p.matches_season <= 0:
			continue
		list.append({"name": p.full_name(), "pos": p.pos, "nat": p.nat, "age": p.age,
			"matches": p.matches_season, "goals": p.goals_season, "note": p.avg_rating(),
			"strength": p.strength})
	list.sort_custom(func(a, b): return float(a.note) < float(b.note))
	return list

## Beste Durchschnittsnoten der Saison (mindestens 15 Einsätze).
func _season_best_rated() -> Array:
	var list: Array = []
	for pid in world.players:
		var p: PlayerData = world.players[pid]
		if p.matches_season < 15:
			continue
		var c := club(p.club_id)
		list.append({"name": p.full_name(), "pos": p.pos, "nat": p.nat, "short": c.short_name,
			"color": c.color, "note": p.avg_rating(), "matches": p.matches_season,
			"mine": p.club_id == my_club_id})
	list.sort_custom(func(a, b): return float(a.note) < float(b.note))
	return list.slice(0, 10)

## Setzt Auf- und Abstieg um – inklusive der Relegationsspiele zwischen dem
## ersten Nichtabstiegsplatz oben und dem ersten Nichtaufstiegsplatz unten.
## Die Zusammenfassung bekommt Bewegungen und Relegationsergebnisse.
func _apply_promotion_and_relegation(tables: Dictionary, summary: Dictionary) -> void:
	var moves := {}          # club_id -> neue Liga (4 = "irgendeine Staffel")
	var playoffs: Array = []

	for lid in world.leagues:
		var rules: Dictionary = LEAGUE_RULES.get(lid, {})
		if rules.is_empty():
			continue
		var rows: Array = tables[lid]
		for i in int(rules.up_direct):
			moves[int(rows[i].club_id)] = lid - 1
		for i in int(rules.down_direct):
			moves[int(rows[rows.size() - 1 - i].club_id)] = lid + 1

	# Relegation: Der bedrohte Verein der oberen Liga gegen den besten
	# Nichtaufsteiger der unteren – Hinspiel unten, Rückspiel oben.
	for pair in [[1, 2], [2, 3]]:
		var upper: int = pair[0]
		var lower: int = pair[1]
		if not (world.leagues.has(upper) and world.leagues.has(lower)):
			continue
		var upper_rows: Array = tables[upper]
		var lower_rows: Array = tables[lower]
		var keeper := club(int(upper_rows[upper_rows.size() - 1 - int(LEAGUE_RULES[upper].down_direct)].club_id))
		var challenger := club(int(lower_rows[int(LEAGUE_RULES[lower].up_direct)].club_id))
		var result := _play_two_legs(keeper, challenger)
		result["kind"] = "relegation"
		result["title"] = "Relegation %s ↔ %s" % [world.leagues[upper].name, world.leagues[lower].name]
		playoffs.append(result)
		if not bool(result.a_wins):
			moves[keeper.id] = lower
			moves[challenger.id] = upper
		_add_news("relegation", "Relegation %s: %s gegen %s %d:%d nach zwei Spielen – %s %s." % [
			world.leagues[upper].name, keeper.name, challenger.name,
			int(result.total_a), int(result.total_b), str(result.winner),
			("bleibt oben" if bool(result.a_wins) else "steigt auf")])

	_promote_from_regional(tables, moves, playoffs)
	_spread_relegated_to_staffeln(moves)

	# Bewegungen anwenden und alle Ligen neu besetzen
	var movements := {}
	for lid in world.leagues:
		movements[lid] = {"league": world.leagues[lid].name, "up": [], "down": []}
	for cid in moves:
		var c := club(cid)
		var from_league: int = c.league_id
		var to_league: int = int(moves[cid])
		c.league_id = to_league
		if to_league < from_league:
			movements[to_league].up.append(c.name)
		else:
			movements[from_league].down.append(c.name)
	for lid in world.leagues:
		world.leagues[lid].club_ids.clear()
	for cid in world.clubs:
		var lid: int = world.clubs[cid].league_id
		if world.leagues.has(lid):
			world.leagues[lid].club_ids.append(cid)
	_balance_staffeln(tables, movements)

	summary["movements"] = []
	for def in Data.LEAGUE_DEFS:
		var lid := int(def.id)
		if movements.has(lid) and not (movements[lid].up.is_empty() and movements[lid].down.is_empty()):
			summary.movements.append(movements[lid])
	summary["playoffs"] = playoffs
	# Für Übersicht und Tests: Wer ist neu in der Ersten Liga, wer musste raus?
	summary["promoted"] = movements[1].up if movements.has(1) else []
	summary["relegated"] = movements[1].down if movements.has(1) else []

## Aufstieg aus der Regionalliga: Die fünf Staffelmeister werden verglichen.
## Die drei besten steigen direkt auf, die beiden übrigen spielen in der
## Aufstiegsrelegation den vierten Platz in der Dritten Liga aus.
func _promote_from_regional(tables: Dictionary, moves: Dictionary, playoffs: Array) -> void:
	var champions: Array = []
	for lid in Data.REGIONAL_LEAGUES:
		if not world.leagues.has(lid):
			continue
		var rows: Array = tables[lid]
		if rows.is_empty():
			continue
		champions.append({"lid": lid, "row": rows[0], "club_id": int(rows[0].club_id)})
	champions.sort_custom(func(x, y):
		if int(x.row.points) != int(y.row.points):
			return int(x.row.points) > int(y.row.points)
		var dx: int = int(x.row.gf) - int(x.row.ga)
		var dy: int = int(y.row.gf) - int(y.row.ga)
		if dx != dy:
			return dx > dy
		return int(x.row.gf) > int(y.row.gf))

	for i in mini(3, champions.size()):
		moves[int(champions[i].club_id)] = 3
		_add_news("liga", "%s ist Meister der %s und steigt direkt in die Dritte Liga auf." % [
			club(int(champions[i].club_id)).name, world.leagues[int(champions[i].lid)].name])
	if champions.size() < 5:
		# Weniger als fünf Staffeln (alte Spielstände): dann rückt der Vierte nach
		if champions.size() >= 4:
			moves[int(champions[3].club_id)] = 3
		return
	var a := club(int(champions[3].club_id))
	var b := club(int(champions[4].club_id))
	var result := _play_two_legs(a, b)
	result["kind"] = "aufstiegsrunde"
	result["title"] = "Aufstiegsrelegation zur Dritten Liga"
	playoffs.append(result)
	moves[a.id if bool(result.a_wins) else b.id] = 3
	_add_news("relegation", "Aufstiegsrelegation: %s gegen %s %d:%d – %s steigt in die Dritte Liga auf." % [
		a.name, b.name, int(result.total_a), int(result.total_b), str(result.winner)])

## Absteiger aus der Dritten Liga gehen IMMER in die Staffel ihres Bundeslands –
## niemand wird in eine fremde Region verschoben.
func _spread_relegated_to_staffeln(moves: Dictionary) -> void:
	for cid in moves:
		if club(cid).league_id == 3 and int(moves[cid]) >= 4:
			moves[cid] = club(cid).home_staffel()

## Sollstärke jeder Regionalliga-Staffel.
const STAFFEL_SIZE := 18

## Bringt jede Staffel wieder auf ihre Sollstärke – so wie im echten
## Spielbetrieb: Kommen aus der Dritten Liga mehr Vereine in eine Region als
## dort Plätze frei wurden, ERHÖHT SICH DIE ZAHL DER REGELABSTEIGER dieser
## Staffel. Die zusätzlichen Absteiger gehen in die Oberliga (Liga 0, wird
## nicht simuliert). Umgekehrt rückt aus der Oberliga derselben Region ein
## Verein nach, wenn eine Staffel zu klein ist. Niemand wechselt die Region.
func _balance_staffeln(tables: Dictionary, movements: Dictionary) -> void:
	if not world.leagues.has(0):
		world.leagues[0] = Data.build_oberliga()
	var oberliga: LeagueData = world.leagues[0]
	for lid in Data.REGIONAL_LEAGUES:
		if not world.leagues.has(lid):
			continue
		var lg: LeagueData = world.leagues[lid]
		var surplus: int = lg.club_ids.size() - STAFFEL_SIZE
		if surplus > 0:
			_extra_relegations(lg, tables.get(lid, []), surplus, movements)
		elif surplus < 0:
			_promote_from_oberliga(lg, -surplus, movements)
	oberliga.club_ids.clear()
	for cid in world.clubs:
		if world.clubs[cid].league_id == 0:
			oberliga.club_ids.append(cid)

## Zusätzliche Regelabsteiger einer Staffel: die Schlusslichter der gerade
## beendeten Saison, die noch in dieser Staffel stehen.
func _extra_relegations(lg: LeagueData, rows: Array, count: int, movements: Dictionary) -> void:
	var done := 0
	for i in range(rows.size() - 1, -1, -1):
		if done >= count:
			break
		var cid := int(rows[i].club_id)
		if not lg.club_ids.has(cid):
			continue   # schon aufgestiegen
		var c := club(cid)
		c.league_id = 0
		lg.club_ids.erase(cid)
		movements[lg.id].down.append(c.name)
		done += 1
		_add_news("liga", "%s muss in die Oberliga – die %s hatte diese Saison %d Absteiger, weil mehr Vereine aus der Dritten Liga in die Region kamen als Plätze frei wurden." % [
			c.name, lg.name, count])

## Nachrücker aus der Oberliga derselben Region – der stärkste zuerst.
func _promote_from_oberliga(lg: LeagueData, count: int, movements: Dictionary) -> void:
	for n in count:
		var best := -1
		var best_strength := -1
		for cid in world.clubs:
			var c: ClubData = world.clubs[cid]
			if c.league_id != 0 or c.home_staffel() != lg.id:
				continue
			if c.base_strength > best_strength:
				best_strength = c.base_strength
				best = cid
		if best < 0:
			# Keiner in der Warteschlange: Ein neuer Verein rückt nach
			best = Data.create_oberliga_club(world, lg.id)
		var c2 := club(best)
		c2.league_id = lg.id
		lg.club_ids.append(best)
		movements[lg.id].up.append(c2.name)
		_add_news("liga", "%s rückt aus der Oberliga in die %s nach." % [c2.name, lg.name])

## Zwei Spiele mit Gesamtstand: Verein A hat im RÜCKSPIEL Heimrecht, Verein B
## im Hinspiel. Steht es nach beiden Partien gleich, folgen im Rückspiel
## zweimal 15 Minuten Verlängerung und danach das Elfmeterschießen. Es gibt
## KEINE Auswärtstorregel.
func _play_two_legs(a: ClubData, b: ClubData) -> Dictionary:
	for c in [a, b]:
		c.formation = c.pick_best_formation(world.players)
		c.lineup = c.best_eleven(world.players)
		c.lineup_spots = []

	var first := _knockout_leg(b, a)     # Hinspiel bei B
	first.run_full()
	first.finalize_now()
	var second := _knockout_leg(a, b)    # Rückspiel bei A
	second.run_full()

	var total_a: int = first.ag + second.hg
	var total_b: int = first.hg + second.ag
	# Gesamtstand nach den regulären 2×90 Minuten – danach kann die
	# Verlängerung ihn noch verändern
	var reg_a := total_a
	var reg_b := total_b
	var extra := false
	var pens := [0, 0]
	if total_a == total_b:
		extra = true
		second.run_extra_time()
		total_a = first.ag + second.hg
		total_b = first.hg + second.ag
		if total_a == total_b:
			pens = _penalty_shootout(a, b)
	else:
		second.finalize_now()

	var a_wins: bool = total_a > total_b or (total_a == total_b and pens[0] > pens[1])
	return {
		"a": a.name, "a_short": a.short_name, "a_color": a.color,
		"b": b.name, "b_short": b.short_name, "b_color": b.color,
		# Hinspiel bei B, Rückspiel bei A
		"leg1_b": first.hg, "leg1_a": first.ag,
		"leg2_a": second.hg, "leg2_b": second.ag,
		"total_a": total_a, "total_b": total_b,
		"reg_a": reg_a, "reg_b": reg_b,
		"extra_time": extra, "shootout": pens[0] + pens[1] > 0,
		"pens_a": pens[0], "pens_b": pens[1],
		"a_wins": a_wins, "winner": a.name if a_wins else b.name,
		"mine": a.id == my_club_id or b.id == my_club_id,
	}

func _knockout_leg(home_club: ClubData, away_club: ClubData) -> MatchSim:
	var sim := MatchSim.new()
	sim.is_friendly = true   # zählt nicht für Saisonstatistik und Sperren
	sim.knockout = true
	sim.setup(home_club, away_club, world.players)
	return sim

## Elfmeterschießen: Abschluss und Nervenstärke der Schützen gegen die Reflexe
## des Torhüters – fünf Schüsse, dann Sudden Death.
func _penalty_shootout(a: ClubData, b: ClubData) -> Array:
	var goals := [0, 0]
	var chance := [_penalty_chance(a, b), _penalty_chance(b, a)]
	for i in 5:
		for side in 2:
			if randf() < chance[side]:
				goals[side] += 1
	var guard := 0
	while goals[0] == goals[1] and guard < 20:
		guard += 1
		var scored := [randf() < chance[0], randf() < chance[1]]
		if scored[0]:
			goals[0] += 1
		if scored[1]:
			goals[1] += 1
	if goals[0] == goals[1]:
		goals[0] += 1   # Notbremse: irgendwer muss gewinnen
	return goals

func _penalty_chance(shooters: ClubData, defender: ClubData) -> float:
	var quality := 0.0
	var count := 0
	for pid in shooters.lineup:
		if not world.players.has(pid):
			continue
		var p: PlayerData = world.players[pid]
		if p.pos == "TW":
			continue
		quality += (p.attr("abschluss") + p.attr("nerven")) / 2.0
		count += 1
	if count > 0:
		quality /= count
	var keeper_skill := 50.0
	for pid in defender.lineup:
		if world.players.has(pid) and world.players[pid].pos == "TW":
			keeper_skill = float(world.players[pid].attr("reflexe"))
			break
	return clampf(0.70 + (quality - 60.0) * 0.0035 - (keeper_skill - 60.0) * 0.0022, 0.55, 0.92)

## Karriereende individuell statt Stichtag: Feldspieler hören meist mit 33–37 auf,
## Torhüter deutlich später (bis ~40), Stars hängen gern noch Jahre dran,
## schwache oder ausgelaugte Spieler gehen früher (ab 31 möglich).
func _retire_chance(p: PlayerData) -> float:
	if p.age >= 40:
		return 1.0
	var eff_age := p.age - (3 if p.pos == "TW" else 0)
	if eff_age < 31:
		return 0.0
	var chance := (eff_age - 30) * 0.09
	if p.strength >= 78:
		chance *= 0.5
	elif p.strength < 55:
		chance *= 1.5
	if p.stamina <= 45:
		chance *= 1.4
	if p.attr("robust") < 40:
		chance *= 1.25
	return clampf(chance, 0.0, 0.9)

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
		# Eigenschaften: Trainingsweltmeister entwickeln sich schneller, Muffel langsamer
		if p.has_trait("Trainingsweltmeister"):
			delta *= 1.25
		elif p.has_trait("Trainingsmuffel"):
			delta *= 0.75
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
		if not world.leagues.has(c.league_id) or not world.leagues[c.league_id].playable:
			continue   # aus dem Unterbau kommen keine Trainerangebote
		if c.base_strength > my_club().base_strength and absf(c.base_strength - reputation) <= 4.0:
			candidates.append(cid)
	candidates.shuffle()
	return candidates.slice(0, 2)

func switch_club(cid: int) -> void:
	# Vertragsbruch ohne Ausstiegsklausel kostet Reputation (der alte Vorstand tobt)
	if not coach_exit_clause and coach_contract_years > 0:
		reputation -= 3.0
		_add_news("contract", "Vertragsbruch: Dein Abgang von %s ohne Ausstiegsklausel schadet deinem Ruf." % my_club().name)
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

## Speichert den Spielstand. Ohne Namen wird automatisch benannt
## (Verein_Saison_Spieltag); mit Namen wird genau dieser Slot geschrieben.
func save_game(custom_name: String = "") -> String:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var save_name := custom_name.strip_edges() if custom_name.strip_edges() != "" \
		else "%s_%d_ST%02d" % [my_club().short_name, world.season_year, matchday()]
	save_name = sanitize_save_name(save_name)
	var path := "%s/%s.json" % [SAVE_DIR, save_name]
	var table_row := {}
	for row in my_league().table():
		if int(row.club_id) == my_club_id:
			table_row = row
			break
	var data := {
		"meta": {
			"manager": manager_name,
			"club_short": my_club().short_name,
			"club_color": my_club().color,
			"league": my_league().name,
			"position": my_league().position_of(my_club_id),
			"points": int(table_row.get("points", 0)),
			"budget": my_club().budget,
			"season_goal_text": season_goal.get("text", ""),
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
			"exit_clause": coach_exit_clause,
			"coach_money": coach_money,
			"season_goal": season_goal,
			"lineup_presets": lineup_presets,
			"pick_weights": pick_weights,
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

## Entfernt für Dateinamen unzulässige Zeichen aus einem Spielstandsnamen.
const SAVE_NAME_ALLOWED := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_äöüÄÖÜß."

static func sanitize_save_name(name: String) -> String:
	var out := ""
	for c in name:
		out += c if SAVE_NAME_ALLOWED.contains(c) else "_"
	out = out.strip_edges()
	return out.substr(0, 48) if out != "" else "Spielstand"

## Löscht einen Spielstand. true bei Erfolg.
func delete_save(path: String) -> bool:
	return DirAccess.remove_absolute(path) == OK

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
	coach_exit_clause = bool(data.meta.get("exit_clause", false))
	coach_money = int(data.meta.get("coach_money", 0))
	season_goal = data.meta.get("season_goal", {})
	lineup_presets = data.meta.get("lineup_presets", [])
	var saved_weights: Dictionary = data.meta.get("pick_weights", {})
	pick_weights = {
		"str": float(saved_weights.get("str", 1.0)),
		"fresh": float(saved_weights.get("fresh", 0.4)),
		"form": float(saved_weights.get("form", 0.4)),
	}
	my_club_id = int(data.meta.my_club_id)
	if season_goal.is_empty():
		season_goal = {"text": "Klassenerhalt", "position": 15}
	transactions = data.get("transactions", [])
	news = data.get("news", [])
	world = _world_from_dict(data.world)
	if not data.world.has("retired"):
		_migrate_economy_v012()
	_migrate_lower_leagues_v031()
	_migrate_bundeslaender()
	# Startaufstellungen slot-treu ausrichten (Spielstände vor dem Slot-System
	# haben eine ungeordnete Elf – die Engine bewertet seitdem pro Formations-Slot)
	for cid in world.clubs:
		world.clubs[cid].align_lineup(world.players)
	initialized = true
	return true

## Migration für Spielstände vor v0.12.0 (erkennbar am fehlenden Karriereenden-
## Archiv): Die Marktwert-Skala wurde ver-zehnfacht, also Gehälter, Sponsorgelder
## und Budgets auf die neue Ökonomie heben – sonst wäre jeder Verein sofort pleite.
func _migrate_economy_v012() -> void:
	for pid in world.players:
		var p: PlayerData = world.players[pid]
		p.salary = p.expected_salary()
	for cid in world.clubs:
		var c: ClubData = world.clubs[cid]
		c.refresh_sponsor(world.players)
		c.budget = maxi(c.budget, int(c.salaries_per_matchday(world.players) * 34 * 0.35))

## Migration für Spielstände vor v0.31.0: Dritte Liga und Regionalliga gab es
## noch nicht. Die fehlenden Ligen samt Vereinen und Kadern werden aus den
## Stammdaten nachgeladen; bereits vergangene Spieltage der laufenden Saison
## werden nachsimuliert, damit die Tabellen stimmen.
func _migrate_lower_leagues_v031() -> void:
	var missing: Array = []
	for def in Data.LEAGUE_DEFS:
		if not world.leagues.has(int(def.id)):
			missing.append(int(def.id))
	if missing.is_empty():
		return
	for lg in Data.build_leagues():
		if world.leagues.has(lg.id):
			# Namen und Spielbarkeit aktualisieren, Bestand bleibt
			world.leagues[lg.id].name = lg.name
			world.leagues[lg.id].short_name = lg.short_name
			world.leagues[lg.id].playable = lg.playable
			continue
		world.leagues[lg.id] = lg
	# Spielstände mit EINER Regionalliga (v0.31.0): Die Vereine wandern in die
	# Staffel, die ihnen in den Stammdaten zugewiesen ist.
	var regional_split := false
	for cid in world.clubs:
		var c: ClubData = world.clubs[cid]
		if c.league_id != 4 or cid > Data.club_defs.size():
			continue
		var target := int(Data.club_defs[cid - 1].league)
		if target != 4:
			c.league_id = target
			regional_split = true
	if regional_split:
		for lid in Data.REGIONAL_LEAGUES:
			if world.leagues.has(lid):
				world.leagues[lid].club_ids.clear()
		for cid in world.clubs:
			var lid: int = world.clubs[cid].league_id
			if Data.REGIONAL_LEAGUES.has(lid):
				world.leagues[lid].club_ids.append(cid)
		missing = Data.REGIONAL_LEAGUES.duplicate()
	Data.add_missing_clubs(world)
	for lid in missing:
		var lg: LeagueData = world.leagues[lid]
		lg.fixtures = ScheduleGen.build_league_fixtures(lg.club_ids)
		# Die bereits gespielten Spieltage der laufenden Saison nachholen
		for f in lg.fixtures:
			if int(f.round) >= matchday():
				continue
			var sim := MatchSim.new()
			sim.is_friendly = true   # keine Sperren/Karten nachträglich verhängen
			sim.setup(club(int(f.home)), club(int(f.away)), world.players)
			sim.run_full()
			f.played = true
			f.hg = sim.hg
			f.ag = sim.ag
	# Der Spielplan der oberen Ligen liegt jetzt auf dem 38er-Raster
	_remap_upper_league_rounds()
	_add_news("liga", "Der Ligaunterbau wurde erweitert: Dritte Liga und Regionalliga sind ab sofort dabei.")

## Spielstände ohne Bundesland (vor v0.33.0) bekommen es aus den Stammdaten
## nachgetragen – ohne das würde jeder Absteiger in der Staffel Nord landen.
func _migrate_bundeslaender() -> void:
	if not world.leagues.has(0):
		world.leagues[0] = Data.build_oberliga()
	var by_id := {}
	for i in Data.club_defs.size():
		var def: Dictionary = Data.club_defs[i]
		by_id[int(def.get("id", i + 1))] = str(def.get("land", ""))
	var filled := 0
	for cid in world.clubs:
		var c: ClubData = world.clubs[cid]
		if c.land == "" and by_id.has(cid):
			c.land = str(by_id[cid])
			filled += 1
	if filled > 0:
		print("Bundesländer nachgetragen: %d Vereine" % filled)

## Alte Spielstände hatten 34 fortlaufende Spieltage. Im neuen Kalender liegen
## die 18er-Ligen auf den 34 Samstagsterminen des 38er-Rasters.
func _remap_upper_league_rounds() -> void:
	if int(world.matchday_dates.size()) >= ScheduleGen.total_rounds():
		return
	var slots := ScheduleGen.saturday_slots()
	for lid in [1, 2]:
		if not world.leagues.has(lid):
			continue
		for f in world.leagues[lid].fixtures:
			var r := int(f.round)
			if r < slots.size():
				f.round = int(slots[r])
	world.matchday = int(slots[mini(int(world.matchday), slots.size() - 1)])
	world.matchday_dates = ScheduleGen.matchday_dates(int(world.season_year))

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
		"retired": world.get("retired", []),
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
		"retired": d.get("retired", []),
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
