extends Node
## Autoload "Data": lädt Stammdaten (Vereine, Namen) aus JSON und erzeugt die Spielwelt.
## Die JSON-Dateien in res://data/ sind bewusst editierbar gehalten –
## wer echte Vereins-/Spielernamen möchte, passt einfach clubs.json und names.json an.

var club_defs: Array = []
var first_names: Array = []
var last_names: Array = []
var sponsors: Array = []

func _ready() -> void:
	# Globales Spiel-Design aktivieren (alle Szenen erben das Theme)
	get_window().theme = UITheme.build()
	club_defs = _load_json("res://data/clubs.json")
	var names: Dictionary = _load_json("res://data/names.json")
	first_names = names.get("first_names", [])
	last_names = names.get("last_names", [])
	sponsors = names.get("sponsors", [])

func _load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Kann Datei nicht laden: " + path)
		return null
	return JSON.parse_string(f.get_as_text())

## Erzeugt eine komplette neue Spielwelt: 4 Ligen, 76 Vereine, feste Kader.
func generate_world() -> Dictionary:
	var world := {
		"season_year": 2026,
		"matchday": 0,
		"date": ScheduleGen.season_start(2026),
		"matchday_dates": ScheduleGen.matchday_dates(2026),
		"next_player_id": 1,
		"players": {},   # id -> PlayerData
		"clubs": {},     # id -> ClubData
		"leagues": {},   # id -> LeagueData
	}

	for lg in build_leagues():
		world.leagues[lg.id] = lg

	var sponsor_pool := sponsors.duplicate()
	sponsor_pool.shuffle()

	# Feste Spielerdatenbank: identische Profi-Kader in jedem neuen Spielstand
	# (editierbar in data/players.json). Nur Jugendspieler werden zufällig erzeugt.
	var db_players := _load_players_db()
	world["youth_ids"] = []
	world["retired"] = []   # Karriereenden-Archiv (bleibt im Spielstand erhalten)

	for i in club_defs.size():
		var def: Dictionary = club_defs[i]
		var c := ClubData.new()
		c.id = i + 1
		c.name = def.name
		c.short_name = def.short
		c.city = def.city
		c.stadium = def.stadium
		c.capacity = int(def.capacity)
		c.color = def.color
		c.base_strength = int(def.strength)
		c.league_id = int(def.league)
		c.sponsor_name = sponsor_pool[i % sponsor_pool.size()]
		c.chairman = def.get("chairman", "")
		world.clubs[c.id] = c
		world.leagues[c.league_id].club_ids.append(c.id)
		if db_players.has(c.id):
			for entry in db_players[c.id]:
				_create_player_from_db(world, c, entry)
		else:
			_generate_squad(world, c)
		# Jeder Verein startet mit ein paar Nachwuchsspielern (14–18, immer zufällig)
		for youth_no in 3:
			world.youth_ids.append(create_youth_player(world, c, PlayerData.POSITIONS.pick_random()).id)
		c.lineup = c.best_eleven(world.players)
		# Finanzen aus dem tatsächlichen Kader ableiten: Sponsor/TV decken die
		# Gehälter plus Spielraum, das Transferbudget entspricht ~35 % des Jahresetats
		c.refresh_sponsor(world.players)
		c.budget = maxi(int(c.salaries_per_matchday(world.players) * 34 * 0.35), 500000)

	for lid in world.leagues:
		var lg: LeagueData = world.leagues[lid]
		lg.fixtures = ScheduleGen.build_league_fixtures(lg.club_ids)
	return world

## Der Ligaunterbau des Spiels. Die Regionalliga ist NICHT spielbar – sie läuft
## nur mit, damit Vereine in die Dritte Liga aufsteigen können.
const LEAGUE_DEFS := [
	{"id": 1, "name": "Erste Liga", "short": "1. Liga", "tier": 1, "playable": true},
	{"id": 2, "name": "Zweite Liga", "short": "2. Liga", "tier": 2, "playable": true},
	{"id": 3, "name": "Dritte Liga", "short": "3. Liga", "tier": 3, "playable": true},
	# Die Regionalliga ist wie in der Realität in fünf Staffeln aufgeteilt
	{"id": 4, "name": "Regionalliga Nord", "short": "RL Nord", "tier": 4, "playable": false},
	{"id": 5, "name": "Regionalliga Nordost", "short": "RL Nordost", "tier": 4, "playable": false},
	{"id": 6, "name": "Regionalliga West", "short": "RL West", "tier": 4, "playable": false},
	{"id": 7, "name": "Regionalliga Südwest", "short": "RL Südwest", "tier": 4, "playable": false},
	{"id": 8, "name": "Regionalliga Bayern", "short": "RL Bayern", "tier": 4, "playable": false},
]

## Die Staffeln der Regionalliga (vierte Ebene).
const REGIONAL_LEAGUES := [4, 5, 6, 7, 8]

static func build_leagues() -> Array:
	var out: Array = []
	for def in LEAGUE_DEFS:
		var lg := LeagueData.new()
		lg.id = int(def.id)
		lg.name = str(def.name)
		lg.short_name = str(def.short)
		lg.tier = int(def.tier)
		lg.playable = bool(def.playable)
		out.append(lg)
	return out

## Ergänzt eine bestehende Welt um Vereine aus clubs.json, die noch fehlen –
## für Spielstände, die vor der Erweiterung des Ligaunterbaus entstanden sind.
func add_missing_clubs(world: Dictionary) -> void:
	var db_players := _load_players_db()
	var sponsor_pool := sponsors.duplicate()
	for i in club_defs.size():
		var club_id := i + 1
		if world.clubs.has(club_id):
			continue
		var def: Dictionary = club_defs[i]
		var c := ClubData.new()
		c.id = club_id
		c.name = def.name
		c.short_name = def.short
		c.city = def.city
		c.stadium = def.stadium
		c.capacity = int(def.capacity)
		c.color = def.color
		c.base_strength = int(def.strength)
		c.league_id = int(def.league)
		c.sponsor_name = sponsor_pool[i % sponsor_pool.size()]
		c.chairman = def.get("chairman", "")
		world.clubs[c.id] = c
		if world.leagues.has(c.league_id):
			world.leagues[c.league_id].club_ids.append(c.id)
		if db_players.has(c.id):
			for entry in db_players[c.id]:
				_create_player_from_db(world, c, entry)
		else:
			_generate_squad(world, c)
		for youth_no in 3:
			var yp := create_youth_player(world, c, PlayerData.POSITIONS.pick_random())
			if world.has("youth_ids"):
				world.youth_ids.append(yp.id)
		c.lineup = c.best_eleven(world.players)
		c.refresh_sponsor(world.players)
		c.budget = maxi(int(c.salaries_per_matchday(world.players) * 34 * 0.35), 500000)

## Lädt die feste Spielerdatenbank (data/players.json), gruppiert nach Verein.
func _load_players_db() -> Dictionary:
	if not FileAccess.file_exists("res://data/players.json"):
		return {}
	var data: Variant = _load_json("res://data/players.json")
	if not (data is Dictionary) or not data.has("players"):
		return {}
	var by_club := {}
	for entry in data.players:
		var cid := int(entry.club)
		if not by_club.has(cid):
			by_club[cid] = []
		by_club[cid].append(entry)
	return by_club

## Erzeugt einen Spieler aus einem Datenbank-Eintrag (fester Kader).
func _create_player_from_db(world: Dictionary, club: ClubData, entry: Dictionary) -> void:
	var p := PlayerData.new()
	p.id = world.next_player_id
	world.next_player_id += 1
	p.first_name = entry.fn
	p.last_name = entry.ln
	p.pos = entry.pos
	p.age = int(entry.age)
	for key in PlayerData.ATTRIBUTES:
		p.attributes[key] = int(entry.attrs.get(key, 40))
	p.recompute_strength()
	p.talent = clampi(int(entry.talent), 1, 5)
	p.potential = int(entry.potential)
	p.stamina = int(entry.stamina)
	p.contract_years = int(entry.contract)
	p.salary = p.expected_salary()
	p.form = randf_range(0.9, 1.1)
	# Nationalität und Eigenschaften aus der Datenbank; ältere DB-Stände ohne
	# diese Felder bekommen sie deterministisch aus dem Namen abgeleitet
	p.nat = str(entry.get("nat", ""))
	if p.nat == "":
		p.nat = Nations.guess_for_name(p.first_name, p.last_name)
	if entry.has("traits"):
		for t in entry.traits:
			if PlayerData.TRAITS.has(str(t)):
				p.traits.append(str(t))
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s|%s|traits" % [p.first_name, p.last_name])
		p.traits = PlayerData.roll_traits(p.pos, rng)
	if entry.has("secpos"):
		for key in entry.secpos:
			p.sec_positions[str(key)] = float(entry.secpos[key])
	else:
		var srng := RandomNumberGenerator.new()
		srng.seed = hash("%s|%s|sec" % [p.first_name, p.last_name])
		p.sec_positions = PlayerData.roll_secondary_positions(p.pos, srng)
	p.club_id = club.id
	world.players[p.id] = p
	club.player_ids.append(p.id)

## Erzeugt einen kompletten Kader für einen Verein (24 Spieler über alle Positionen).
func _generate_squad(world: Dictionary, club: ClubData) -> void:
	var plan := {"TW": 3, "IV": 4, "LV": 2, "RV": 2, "DM": 2, "ZM": 3, "LM": 1, "RM": 1, "OM": 2, "LA": 1, "RA": 1, "MS": 3}
	var star_given := false
	for pos in plan:
		for i in plan[pos]:
			var boost := 0
			if not star_given and pos == "MS":
				boost = 8
				star_given = true
			_create_player(world, club, pos, boost)

func _create_player(world: Dictionary, club: ClubData, pos: String, boost: int = 0) -> PlayerData:
	var p := PlayerData.new()
	p.id = world.next_player_id
	world.next_player_id += 1
	p.first_name = first_names.pick_random()
	p.last_name = last_names.pick_random()
	p.pos = pos
	p.age = randi_range(18, 33)
	var target := clampi(club.base_strength + randi_range(-9, 7) + boost, 30, 94)
	p.attributes = PlayerData.make_attributes(pos, target)
	p.recompute_strength()
	p.talent = PlayerData.roll_talent()
	p.potential = PlayerData.roll_potential(p.talent, p.strength)
	p.form = randf_range(0.9, 1.1)
	p.stamina = clampi(randi_range(45, 90) - (8 if p.age >= 31 else 0), 30, 95)
	p.contract_years = randi_range(1, 4)
	p.salary = p.expected_salary()
	p.nat = Nations.roll(p.first_name, p.last_name)
	p.traits = PlayerData.roll_traits(p.pos)
	p.sec_positions = PlayerData.roll_secondary_positions(p.pos)
	p.club_id = club.id
	world.players[p.id] = p
	club.player_ids.append(p.id)
	return p

## Erzeugt einen Jugendspieler (14–18 Jahre). Je jünger, desto schwächer der Start –
## ein 14-Jähriger kann mit Stärke ~15–30 beginnen und trotzdem 5★-Potenzial haben.
## bonus: zusätzliche Stärke, z. B. durch die Trainer-Fähigkeit "Jugendarbeit".
func create_youth_player(world: Dictionary, club: ClubData, pos: String, bonus: int = 0) -> PlayerData:
	var p := PlayerData.new()
	p.id = world.next_player_id
	world.next_player_id += 1
	p.first_name = first_names.pick_random()
	p.last_name = last_names.pick_random()
	p.pos = pos
	p.age = randi_range(14, 18)
	var deficit := (19 - p.age) * 6 + randi_range(4, 12)
	var target := clampi(club.base_strength - deficit + bonus, 12, 90)
	p.attributes = PlayerData.make_attributes(pos, target)
	p.recompute_strength()
	p.talent = PlayerData.roll_talent()
	p.potential = PlayerData.roll_potential(p.talent, p.strength)
	p.form = randf_range(0.9, 1.1)
	p.stamina = randi_range(55, 90)
	p.contract_years = 3
	p.salary = p.expected_salary()
	p.nat = Nations.roll(p.first_name, p.last_name, true)
	p.traits = PlayerData.roll_traits(p.pos)
	p.sec_positions = PlayerData.roll_secondary_positions(p.pos)
	p.club_id = club.id
	world.players[p.id] = p
	club.player_ids.append(p.id)
	return p
