extends Node
## Entwicklungs-Beobachtung: 5 Saisons simulieren und verfolgte Spieler
## (je Talentstufe ein junges Talent, dazu Peak-Spieler und Routinier)
## Jahr für Jahr protokollieren.

var _tracked: Array = []   # {pid, label}

func _ready() -> void:
	print("=== ENTWICKLUNGS-SIMULATION: 5 SAISONS ===")
	Game.setup = {"name": "Beobachter", "mode": "vereinsauswahl"}
	Game.new_game(1)

	# Verfolgte Spieler auswählen: je Talentstufe ein 17-19-Jähriger,
	# dazu ein Peak-Spieler (26/27) und ein Routinier (30/31)
	for stars in [5, 4, 3, 2, 1]:
		var pick := _find(func(p): return p.age <= 19 and p.talent == stars)
		if pick != null:
			_tracked.append({"pid": pick.id, "label": "%d★ Talent" % stars})
	var peak := _find(func(p): return p.age >= 26 and p.age <= 27 and p.talent >= 3)
	if peak != null:
		_tracked.append({"pid": peak.id, "label": "Peak 26 J."})
	var vet := _find(func(p): return p.age >= 30 and p.age <= 31)
	if vet != null:
		_tracked.append({"pid": vet.id, "label": "Routinier"})

	# Wunderkind-Szenario: 14-Jähriger mit Stärke ~17 und 5★-Potenzial 95
	var kid := _find(func(p): return p.age <= 18 and p.pos == "MS")
	if kid != null:
		kid.age = 14
		kid.attributes = PlayerData.make_attributes(kid.pos, 17)
		kid.recompute_strength()
		kid.talent = 5
		kid.potential = 95
		_tracked.push_front({"pid": kid.id, "label": "Wunderkind"})

	print("Verfolgte Spieler (Start %s):" % Game.season_label())
	for t in _tracked:
		var p: PlayerData = Game.world.players[t.pid]
		print("  [%s] %s (%s) – %d J., Stärke %d, Potenzial %d, Wert %s" % [
			t.label, p.full_name(), p.pos, p.age, p.strength, p.potential, Fmt.money(p.market_value())])

	for season in 5:
		var season_name := Game.season_label()
		for md in 34:
			Game.play_matchday()
		# Einsatzdaten VOR dem Saisonwechsel sichern (end_season setzt sie zurück)
		var usage := {}
		for t in _tracked:
			if Game.world.players.has(t.pid):
				var p: PlayerData = Game.world.players[t.pid]
				usage[t.pid] = {"m": p.matches_season, "note": p.avg_rating()}
		Game.end_season()
		print("--- Nach %s ---" % season_name)
		for t in _tracked:
			if not Game.world.players.has(t.pid):
				print("  [%s] Karriere beendet." % t.label)
				continue
			var p: PlayerData = Game.world.players[t.pid]
			var u: Dictionary = usage.get(t.pid, {"m": 0, "note": 0.0})
			var note_text: String = ("%.1f" % u.note).replace(".", ",") if u.m > 0 else "–"
			print("  [%s] %d J. | Stärke %d/%d | %d Einsätze, Ø Note %s | Wert %s" % [
				t.label, p.age, p.strength, p.potential, u.m, note_text, Fmt.money(p.market_value())])

	# Liga-Gesundheit: Stärkeverteilung nach 5 Saisons
	var total := 0.0
	var count := 0
	var top := 0
	for pid in Game.world.players:
		var p: PlayerData = Game.world.players[pid]
		total += p.strength
		top = maxi(top, p.strength)
		count += 1
	print("Liga nach 5 Saisons: %d Spieler, Ø Stärke %.1f, Topwert %d" % [count, total / count, top])
	print("=== SIMULATION ENDE ===")
	get_tree().quit(0)

func _find(predicate: Callable) -> PlayerData:
	for pid in Game.world.players:
		var p: PlayerData = Game.world.players[pid]
		if predicate.call(p):
			return p
	return null
