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

## Erzeugt eine komplette neue Spielwelt: 2 Ligen, 36 Vereine, generierte Kader.
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

	var l1 := LeagueData.new()
	l1.id = 1
	l1.name = "Erste Liga"
	l1.tier = 1
	var l2 := LeagueData.new()
	l2.id = 2
	l2.name = "Zweite Liga"
	l2.tier = 2
	world.leagues[1] = l1
	world.leagues[2] = l2

	var sponsor_pool := sponsors.duplicate()
	sponsor_pool.shuffle()

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
		if c.league_id == 1:
			c.budget = (c.base_strength - 50) * 1200000
		else:
			c.budget = (c.base_strength - 44) * 400000
		c.sponsor_name = sponsor_pool[i % sponsor_pool.size()]
		c.sponsor_per_md = maxi((c.base_strength - 40) * 4000, 20000)
		c.chairman = def.get("chairman", "")
		world.clubs[c.id] = c
		world.leagues[c.league_id].club_ids.append(c.id)
		_generate_squad(world, c)
		c.lineup = c.best_eleven(world.players)

	l1.fixtures = ScheduleGen.build_fixtures(l1.club_ids)
	l2.fixtures = ScheduleGen.build_fixtures(l2.club_ids)
	return world

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
	p.potential = mini(96, p.strength + PlayerData.POTENTIAL_BONUS[p.talent - 1])
	p.form = randf_range(0.9, 1.1)
	p.stamina = clampi(randi_range(45, 90) - (8 if p.age >= 31 else 0), 30, 95)
	p.contract_years = randi_range(1, 4)
	p.salary = p.expected_salary()
	p.club_id = club.id
	world.players[p.id] = p
	club.player_ids.append(p.id)
	return p

## Erzeugt einen Jugendspieler (für das Auffüllen der Kader zum Saisonwechsel).
## bonus: zusätzliche Stärke, z. B. durch die Trainer-Fähigkeit "Jugendarbeit".
func create_youth_player(world: Dictionary, club: ClubData, pos: String, bonus: int = 0) -> PlayerData:
	var p := PlayerData.new()
	p.id = world.next_player_id
	world.next_player_id += 1
	p.first_name = first_names.pick_random()
	p.last_name = last_names.pick_random()
	p.pos = pos
	p.age = randi_range(17, 19)
	var target := clampi(club.base_strength + randi_range(-16, -4) + bonus, 28, 90)
	p.attributes = PlayerData.make_attributes(pos, target)
	p.recompute_strength()
	p.talent = PlayerData.roll_talent()
	p.potential = mini(96, p.strength + PlayerData.POTENTIAL_BONUS[p.talent - 1])
	p.form = randf_range(0.9, 1.1)
	p.stamina = randi_range(55, 90)
	p.contract_years = 3
	p.salary = p.expected_salary()
	p.club_id = club.id
	world.players[p.id] = p
	club.player_ids.append(p.id)
	return p
