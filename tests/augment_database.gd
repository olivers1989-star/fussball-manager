extends Node
## Einmal-Werkzeug: ergänzt die feste Spielerdatenbank (data/players.json) um
## "nat" (Nationalität, aus dem Namen abgeleitet) und "traits" (0–2 Eigenschaften,
## deterministisch gewürfelt). Alle übrigen Daten bleiben unverändert –
## die Kader aller Spielstände bleiben identisch.

func _ready() -> void:
	var f := FileAccess.open("res://data/players.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	var nat_count := {}
	var trait_count := 0
	for entry in data.players:
		if not entry.has("nat"):
			entry["nat"] = Nations.guess_for_name(entry.fn, entry.ln)
		if not entry.has("traits"):
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("%s|%s|traits" % [entry.fn, entry.ln])
			entry["traits"] = PlayerData.roll_traits(entry.pos, rng)
		nat_count[entry.nat] = nat_count.get(entry.nat, 0) + 1
		trait_count += entry.traits.size()
	f = FileAccess.open("res://data/players.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	print("Datenbank ergänzt: %d Spieler, %d Eigenschaften vergeben" % [data.players.size(), trait_count])
	var nations: Array = nat_count.keys()
	nations.sort_custom(func(a, b): return nat_count[a] > nat_count[b])
	for n in nations:
		print("  %4d  %s" % [nat_count[n], n])
	get_tree().quit(0)
