extends Node
## Werkzeug (einmalig): Ergänzt data/players.json um Kader für Vereine, die noch
## keinen Eintrag haben. Bestehende Spieler bleiben Zeichen für Zeichen erhalten –
## die feste Datenbank soll sich für alte Vereine NICHT ändern.

const PLAN := {"TW": 3, "IV": 4, "LV": 2, "RV": 2, "DM": 2, "ZM": 3, "LM": 1, "RM": 1, "OM": 2, "LA": 1, "RA": 1, "MS": 3}

func _ready() -> void:
	print("=== KADER ERGÄNZEN ===")
	var db: Dictionary = JSON.parse_string(FileAccess.open("res://data/players.json", FileAccess.READ).get_as_text())
	var players: Array = db.players
	var have := {}
	for entry in players:
		have[int(entry.club)] = true
	print("Bestehend: %d Spieler für %d Vereine" % [players.size(), have.size()])

	var clubs: Array = JSON.parse_string(FileAccess.open("res://data/clubs.json", FileAccess.READ).get_as_text())
	var added := 0
	var new_entries: Array = []
	for i in clubs.size():
		var club_id := i + 1
		if have.has(club_id):
			continue
		var def: Dictionary = clubs[i]
		# Fester Seed je Verein: die Datenbank muss reproduzierbar bleiben
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("squad|%s|%s" % [str(def.short), str(def.name)])
		var star_given := false
		for pos in PLAN:
			for n in PLAN[pos]:
				var boost := 0
				if not star_given and pos == "MS":
					boost = 6
					star_given = true
				new_entries.append(_make_entry(club_id, int(def.strength), pos, boost, rng))
				added += 1
	players.append_array(new_entries)
	players.sort_custom(func(a, b):
		if int(a.club) != int(b.club):
			return int(a.club) < int(b.club)
		return PlayerData.POSITIONS.find(a.pos) < PlayerData.POSITIONS.find(b.pos))

	var out := FileAccess.open("res://data/players.json", FileAccess.WRITE)
	out.store_string(JSON.stringify({"players": players}, "\t"))
	out.close()
	print("Ergänzt: %d Spieler – jetzt %d gesamt" % [added, players.size()])
	get_tree().quit(0)

func _make_entry(club_id: int, base_strength: int, pos: String, boost: int, rng: RandomNumberGenerator) -> Dictionary:
	var first_name: String = Data.first_names[rng.randi() % Data.first_names.size()]
	var last_name: String = Data.last_names[rng.randi() % Data.last_names.size()]
	var age := rng.randi_range(18, 33)
	var target := clampi(base_strength + rng.randi_range(-9, 7) + boost, 28, 94)
	var attrs := PlayerData.make_attributes(pos, target)
	var p := PlayerData.new()
	p.pos = pos
	p.attributes = attrs
	p.recompute_strength()
	var talent := _roll_talent(rng)
	return {
		"club": club_id, "fn": first_name, "ln": last_name, "pos": pos, "age": age,
		"talent": talent, "potential": _roll_potential(talent, p.strength, rng),
		"stamina": clampi(rng.randi_range(45, 90) - (8 if age >= 31 else 0), 30, 95),
		"contract": rng.randi_range(1, 4), "attrs": attrs,
		"nat": Nations.guess_for_name(first_name, last_name),
		"traits": PlayerData.roll_traits(pos, rng),
		"secpos": _secpos(pos, rng),
	}

## Talentverteilung wie PlayerData.roll_talent, aber mit eigenem RNG.
func _roll_talent(rng: RandomNumberGenerator) -> int:
	var r := rng.randf()
	if r < 0.20:
		return 1
	if r < 0.55:
		return 2
	if r < 0.88:
		return 3
	if r < 0.98:
		return 4
	return 5

func _roll_potential(talent: int, strength: int, rng: RandomNumberGenerator) -> int:
	var band: Array = PlayerData.POTENTIAL_BANDS[talent]
	return clampi(rng.randi_range(int(band[0]), int(band[1])), strength, 99)

func _secpos(pos: String, rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	var related: Array = PlayerData.RELATED_POSITIONS.get(pos, [])
	if related.is_empty():
		return out
	var count := 0
	var r := rng.randf()
	if r > 0.75:
		count = 2
	elif r > 0.40:
		count = 1
	var pool: Array = related.duplicate()
	for i in mini(count, pool.size()):
		var pick: String = pool[rng.randi() % pool.size()]
		pool.erase(pick)
		out[pick] = snappedf(rng.randf_range(0.86, 0.94), 0.01)
	return out
