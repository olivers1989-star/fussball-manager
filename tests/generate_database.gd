extends Node
## Werkzeug: Erzeugt die feste Spielerdatenbank data/players.json aus dem
## aktuellen Generator (einmalig; zum Neu-Generieren die Datei vorher löschen).
## Danach prüft ein Determinismus-Check, dass jeder neue Spielstand
## identische Profi-Kader lädt.

func _ready() -> void:
	print("=== DATENBANK-GENERATOR ===")
	var world := Data.generate_world()
	var youth := {}
	for pid in world.get("youth_ids", []):
		youth[pid] = true

	var players: Array = []
	for pid in world.players.keys():
		if youth.has(pid):
			continue
		var p: PlayerData = world.players[pid]
		players.append({
			"club": p.club_id, "fn": p.first_name, "ln": p.last_name, "pos": p.pos,
			"age": p.age, "talent": p.talent, "potential": p.potential,
			"stamina": p.stamina, "contract": p.contract_years, "attrs": p.attributes,
		})
	players.sort_custom(func(a, b):
		if int(a.club) != int(b.club):
			return int(a.club) < int(b.club)
		return PlayerData.POSITIONS.find(a.pos) < PlayerData.POSITIONS.find(b.pos))

	var f := FileAccess.open("res://data/players.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"players": players}, "\t"))
	f.close()
	print("Datenbank geschrieben: %d Profispieler" % players.size())

	# Determinismus-Check: zwei frische Welten müssen identische Profi-Kader haben
	var w1 := Data.generate_world()
	var w2 := Data.generate_world()
	var mismatch := 0
	var checked := 0
	for pid in w1.players.keys():
		if w1.get("youth_ids", []).has(pid):
			continue
		if not w2.players.has(pid):
			mismatch += 1
			continue
		var p1: PlayerData = w1.players[pid]
		var p2: PlayerData = w2.players[pid]
		checked += 1
		if p1.full_name() != p2.full_name() or p1.strength != p2.strength or p1.talent != p2.talent or p1.pos != p2.pos:
			mismatch += 1
	print("Determinismus-Check: %d Profis verglichen, %d Abweichungen" % [checked, mismatch])
	assert(mismatch == 0)
	print("=== DATENBANK OK ===")
	get_tree().quit(0)
