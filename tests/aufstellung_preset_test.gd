extends Node
## Gespeicherte Aufstellungen und Auswahl-Kriterien: Sichern, Laden (auch mit
## fehlenden Spielern), Löschen und Erhalt über Speichern/Laden des Spielstands.

func _ready() -> void:
	Game.setup = {"name": "Presettester", "mode": "vereinsauswahl"}
	Game.new_game(2)
	var c := Game.my_club()

	# (1) Aufstellung sichern
	c.apply_formation("4-3-3", Game.world.players)
	c.bench = c.best_bench(Game.world.players, c.lineup)
	var original := c.lineup.duplicate()
	var original_spots := c.lineup_spots.duplicate()
	var name1 := Game.save_lineup_preset("Offensiv")
	assert(name1 == "Offensiv", "Name muss übernommen werden")
	assert(Game.lineup_presets.size() == 1, "Es muss genau eine Aufstellung gespeichert sein")

	# (2) Aufstellung verändern und wieder laden
	c.apply_formation("5-3-2", Game.world.players)
	c.lineup = c.best_eleven(Game.world.players, "5-3-2")
	assert(c.formation == "5-3-2")
	var replaced := Game.load_lineup_preset(0)
	assert(replaced == 0, "Ohne fehlende Spieler darf nichts ersetzt werden, war: %d" % replaced)
	assert(c.formation == "4-3-3", "Formation muss wiederhergestellt sein")
	assert(c.lineup == original, "Elf muss exakt wiederhergestellt sein")
	for i in original_spots.size():
		assert(c.lineup_spots[i].distance_to(original_spots[i]) < 0.01, "Feldpositionen müssen erhalten bleiben")
	print("Sichern und Laden OK (%s, %d Spieler, Positionen exakt)" % [c.formation, c.lineup.size()])

	# (3) Fehlende/verletzte Spieler werden ersetzt, die Elf bleibt vollständig
	var hurt: PlayerData = Game.world.players[c.lineup[3]]
	hurt.injury_matchdays = 3
	replaced = Game.load_lineup_preset(0)
	assert(replaced >= 1, "Verletzter Spieler muss ersetzt werden")
	assert(c.lineup.size() == 11, "Die Elf muss vollständig bleiben")
	assert(not c.lineup.has(hurt.id), "Verletzter darf nicht aufgestellt sein")
	print("Ersatz OK: %d Spieler ersetzt, Elf weiter vollständig" % replaced)
	hurt.injury_matchdays = 0

	# (4) Zweite Aufstellung, Namensersetzung bei gleichem Namen
	Game.save_lineup_preset("Defensiv")
	assert(Game.lineup_presets.size() == 2)
	Game.save_lineup_preset("Defensiv")
	assert(Game.lineup_presets.size() == 2, "Gleicher Name darf keinen zweiten Eintrag anlegen")

	# (5) Kriterien und Aufstellungen überleben Speichern/Laden
	Game.pick_weights = {"str": 0.6, "fresh": 1.0, "form": 0.2}
	var save_name := Game.save_game("ZZPresetTest")
	Game.new_game(3)   # Zustand bewusst überschreiben
	assert(Game.lineup_presets.is_empty(), "Neues Spiel startet ohne Aufstellungen")
	var path := ""
	for s in Game.list_saves():
		if s.path.get_file().get_basename() == save_name:
			path = s.path
	assert(Game.load_game(path), "Spielstand muss ladbar sein")
	assert(Game.lineup_presets.size() == 2, "Aufstellungen müssen gespeichert werden")
	assert(absf(float(Game.pick_weights.fresh) - 1.0) < 0.001, "Kriterien müssen gespeichert werden")
	assert(absf(float(Game.pick_weights.str) - 0.6) < 0.001)
	print("Persistenz OK: %d Aufstellungen, Kriterien Stärke %.1f / Frische %.1f / Form %.1f" % [
		Game.lineup_presets.size(), Game.pick_weights.str, Game.pick_weights.fresh, Game.pick_weights.form])

	# (6) Kriterien wirken: Frische-Gewichtung stellt frischere Spieler auf
	var club := Game.my_club()
	for pid in club.player_ids:
		Game.world.players[pid].condition = 100.0
	# Die aktuell besten Spieler kräftig ermüden
	var strong := club.best_eleven(Game.world.players, "", {"str": 1.0, "fresh": 0.0, "form": 0.0})
	for pid in strong:
		Game.world.players[pid].condition = 20.0
	var fresh_first := club.best_eleven(Game.world.players, "", {"str": 0.3, "fresh": 2.0, "form": 0.0})
	var tired_in_fresh := 0
	for pid in fresh_first:
		if strong.has(pid):
			tired_in_fresh += 1
	print("Kriterien-Wirkung: %d der 11 müden Stammspieler stehen bei Frische-Priorität noch drin" % tired_in_fresh)
	assert(tired_in_fresh < 6, "Mit Frische-Priorität müssen überwiegend frische Spieler aufgestellt werden")

	# (7) Löschen
	Game.delete_lineup_preset(0)
	assert(Game.lineup_presets.size() == 1, "Löschen muss wirken")
	print("Löschen OK")

	# Aufräumen
	for s in Game.list_saves():
		if str(s.meta.get("manager", "")) == "Presettester":
			Game.delete_save(s.path)

	print("=== AUFSTELLUNGS-PRESET-TEST OK ===")
	get_tree().quit(0)
