extends Node
## Autoload "Data": lädt Stammdaten (Vereine, Namen) aus JSON und erzeugt die Spielwelt.
## Die JSON-Dateien liegen nach der Installation OFFEN im Programmordner
## (Unterordner data) und sind editierbar – wer echte Vereins-/Spielernamen
## möchte, passt einfach clubs.json und names.json an. Fehlt eine Datei,
## greift die mitgelieferte Fassung aus dem PCK.

var club_defs: Array = []
var first_names: Array = []
var last_names: Array = []
var sponsors: Array = []

func _ready() -> void:
	# Globales Spiel-Design aktivieren (alle Szenen erben das Theme)
	get_window().theme = UITheme.build()
	club_defs = _load_json(data_file("clubs.json"))
	var names: Dictionary = _load_json(data_file("names.json"))
	first_names = names.get("first_names", [])
	last_names = names.get("last_names", [])
	sponsors = names.get("sponsors", [])

## Der Stammdaten-Ordner NEBEN der EXE. Dort liegen die Dateien offen und
## editierbar; nur wenn sie fehlen, greift die mitgelieferte Fassung im PCK.
## Im Editor gibt es keinen externen Ordner – dann zählt res://data.
static func data_dir() -> String:
	if OS.has_feature("editor"):
		return "res://data"
	var external := OS.get_executable_path().get_base_dir().path_join("data")
	return external if DirAccess.dir_exists_absolute(external) else "res://data"

## Vereins-Stammdaten anhand der festen ID (nicht der Listenposition!). Seit
## dem Vereinsumbau sind IDs nicht mehr durchnummeriert – Zugriffe müssen hier
## durch, nicht über club_defs[id-1].
func club_def_by_id(club_id: int) -> Dictionary:
	for d in club_defs:
		if int(d.get("id", -1)) == club_id:
			return d
	return {}

## Pfad einer Stammdatendatei: extern, wenn vorhanden, sonst aus dem PCK.
static func data_file(file_name: String) -> String:
	var external := data_dir().path_join(file_name)
	if FileAccess.file_exists(external):
		return external
	return "res://data".path_join(file_name)

func _load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Kann Datei nicht laden: " + path)
		return null
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("Fehlerhafte JSON-Datei: " + path)
	return parsed

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
	# Warteschlange unterhalb der Regionalliga (wird nicht gespielt)
	world.leagues[0] = build_oberliga()

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
		c.id = int(def.get("id", i + 1))
		c.name = def.name
		c.short_name = def.short
		c.city = def.city
		c.land = str(def.get("land", ""))
		c.stadium = def.stadium
		c.capacity = int(def.capacity)
		c.color = def.color
		c.base_strength = int(def.strength)
		c.league_id = int(def.league)
		c.parent_short = str(def.get("parent", ""))
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

	resolve_reserve_parents(world)
	for lid in world.leagues:
		var lg: LeagueData = world.leagues[lid]
		lg.fixtures = ScheduleGen.build_league_fixtures(lg.club_ids)
	return world

## Löst die Parent-Kürzel der Zweitmannschaften zu IDs auf (nachdem alle Vereine
## existieren). So bleibt clubs.json von Hand editierbar – dort steht das Kürzel
## der ersten Mannschaft, z. B. "parent": "BVW".
static func resolve_reserve_parents(world: Dictionary) -> void:
	var by_short := {}
	for cid in world.clubs:
		by_short[world.clubs[cid].short_name] = cid
	for cid in world.clubs:
		var c: ClubData = world.clubs[cid]
		if c.parent_short != "" and by_short.has(c.parent_short):
			c.parent_id = int(by_short[c.parent_short])

## Der Ligaunterbau des Spiels. Die Regionalliga ist NICHT spielbar – sie läuft
## nur mit, damit Vereine in die Dritte Liga aufsteigen können.
const LEAGUE_DEFS := [
	{"id": 1, "name": "Erste Liga", "short": "1. Liga", "tier": 1, "playable": true},
	{"id": 2, "name": "Zweite Liga", "short": "2. Liga", "tier": 2, "playable": true},
	{"id": 3, "name": "Dritte Liga", "short": "3. Liga", "tier": 3, "playable": true},
	# Die Regionalliga ist wie in der Realität in fünf Staffeln aufgeteilt –
	# spielbar (man kann einen Staffelverein übernehmen).
	{"id": 4, "name": "Regionalliga Nord", "short": "RL Nord", "tier": 4, "playable": true},
	{"id": 5, "name": "Regionalliga Nordost", "short": "RL Nordost", "tier": 4, "playable": true},
	{"id": 6, "name": "Regionalliga West", "short": "RL West", "tier": 4, "playable": true},
	{"id": 7, "name": "Regionalliga Südwest", "short": "RL Südwest", "tier": 4, "playable": true},
	{"id": 8, "name": "Regionalliga Bayern", "short": "RL Bayern", "tier": 4, "playable": true},
]

## Die Staffeln der Regionalliga (vierte Ebene).
const REGIONAL_LEAGUES := [4, 5, 6, 7, 8]

## Die Oberliga (Liga 0) ist die Warteschlange unterhalb der Regionalliga. Sie
## wird NICHT gespielt – hier warten Vereine, die aus einer Staffel absteigen
## mussten, bis in ihrer Region wieder ein Platz frei wird. Sie steht bewusst
## nicht in LEAGUE_DEFS und taucht deshalb in keiner Tabellenansicht auf.
static func build_oberliga() -> LeagueData:
	var lg := LeagueData.new()
	lg.id = 0
	lg.name = "Oberliga"
	lg.short_name = "OL"
	lg.tier = 5
	lg.playable = false
	return lg

## Städte für neue Oberliga-Vereine je Staffel: [Stadt, Bundesland].
const OBERLIGA_CITIES := {
	4: [["Buxtehude", "NI"], ["Itzehoe", "SH"], ["Stade", "NI"], ["Celle", "NI"],
		["Gifhorn", "NI"], ["Heide", "SH"], ["Husum", "SH"], ["Vechta", "NI"],
		["Leer", "NI"], ["Uelzen", "NI"], ["Buchholz", "NI"], ["Elmshorn", "SH"]],
	5: [["Eberswalde", "BB"], ["Riesa", "SN"], ["Gotha", "TH"], ["Bautzen", "SN"],
		["Neubrandenburg", "MV"], ["Wismar", "MV"], ["Weimar", "TH"], ["Görlitz", "SN"],
		["Stendal", "ST"], ["Merseburg", "ST"], ["Senftenberg", "BB"], ["Anklam", "MV"]],
	6: [["Ahlen", "NW"], ["Bocholt", "NW"], ["Gütersloh", "NW"], ["Hamm", "NW"],
		["Kleve", "NW"], ["Lünen", "NW"], ["Moers", "NW"], ["Neuss", "NW"],
		["Recklinghausen", "NW"], ["Remscheid", "NW"], ["Gummersbach", "NW"], ["Erkelenz", "NW"]],
	7: [["Baunatal", "HE"], ["Worms", "RP"], ["Idar-Oberstein", "RP"], ["Pforzheim", "BW"],
		["Reutlingen", "BW"], ["Göppingen", "BW"], ["Hanau", "HE"], ["Wetzlar", "HE"],
		["Homburg", "SL"], ["Kehl", "BW"], ["Neunkirchen", "SL"], ["Gießen", "HE"]],
	8: [["Amberg", "BY"], ["Coburg", "BY"], ["Erlangen", "BY"], ["Fürstenfeldbruck", "BY"],
		["Garmisch", "BY"], ["Kaufbeuren", "BY"], ["Memmingen", "BY"], ["Rosenheim", "BY"],
		["Schweinfurt", "BY"], ["Straubing", "BY"], ["Cham", "BY"], ["Kulmbach", "BY"]],
}

const OBERLIGA_PREFIXES := ["SV", "FC", "TSV", "SpVgg", "1. FC", "VfB", "SC", "FSV"]

## Erzeugt einen neuen Verein für die Oberliga einer Region und gibt seine ID
## zurück. Kommt zum Zug, wenn eine Staffel Platz hat und niemand wartet.
func create_oberliga_club(world: Dictionary, staffel: int) -> int:
	var used_shorts := {}
	var used_names := {}
	var max_id := 0
	for cid in world.clubs:
		var existing: ClubData = world.clubs[cid]
		used_shorts[existing.short_name] = true
		used_names[existing.name] = true
		max_id = maxi(max_id, existing.id)

	var pool: Array = OBERLIGA_CITIES.get(staffel, OBERLIGA_CITIES[4])
	var entry: Array = pool.pick_random()
	var name := ""
	for attempt in 40:
		entry = pool.pick_random()
		name = "%s %s" % [OBERLIGA_PREFIXES.pick_random(), str(entry[0])]
		if not used_names.has(name):
			break
	var short_name := _unique_short(str(entry[0]), used_shorts)

	var c := ClubData.new()
	c.id = max_id + 1
	c.name = name
	c.short_name = short_name
	c.city = str(entry[0])
	c.land = str(entry[1])
	c.stadium = "Sportplatz %s" % str(entry[0])
	c.capacity = randi_range(2000, 6000)
	c.color = ["#c8102e", "#0057a3", "#00843d", "#f4c400", "#000000"].pick_random()
	c.base_strength = randi_range(30, 36)
	c.league_id = 0
	c.chairman = "%s %s" % [first_names.pick_random(), last_names.pick_random()]
	c.sponsor_name = sponsors.pick_random() if not sponsors.is_empty() else "Regionalsponsor"
	world.clubs[c.id] = c
	_generate_squad(world, c)
	c.lineup = c.best_eleven(world.players)
	c.refresh_sponsor(world.players)
	c.budget = maxi(int(c.salaries_per_matchday(world.players) * 34 * 0.35), 200000)
	return c.id

func _unique_short(city: String, used: Dictionary) -> String:
	var base := city.to_upper().replace("Ä", "A").replace("Ö", "O").replace("Ü", "U").replace("ß", "S")
	base = base.substr(0, 3)
	if not used.has(base):
		return base
	for i in range(2, 100):
		var candidate := "%s%d" % [base.substr(0, 2), i]
		if not used.has(candidate):
			return candidate
	return base + "X"

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
		var def: Dictionary = club_defs[i]
		var club_id := int(def.get("id", i + 1))
		if world.clubs.has(club_id):
			continue
		var c := ClubData.new()
		c.id = club_id
		c.name = def.name
		c.short_name = def.short
		c.city = def.city
		c.land = str(def.get("land", ""))
		c.stadium = def.stadium
		c.capacity = int(def.capacity)
		c.color = def.color
		c.base_strength = int(def.strength)
		c.league_id = int(def.league)
		c.parent_short = str(def.get("parent", ""))
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
	var path := data_file("players.json")
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = _load_json(path)
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
