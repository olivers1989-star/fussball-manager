extends Node
## Speichersystem: benannte Spielstände, Überschreiben, Löschen, reichhaltige
## Meta-Daten (Verein, Wappenfarbe, Tabellenstand) und die Browser-Oberfläche.

func _ready() -> void:
	Game.setup = {"name": "Speichertester", "mode": "vereinsauswahl"}
	Game.new_game(2)
	# Aufräumen: alle vorhandenen Spielstände dieses Tests entfernen
	for s in Game.list_saves():
		if str(s.meta.get("manager", "")) == "Speichertester":
			Game.delete_save(s.path)
	var before := Game.list_saves().size()

	# (1) Benannter Spielstand (eigener Testname, damit nichts kollidiert)
	const TEST_SLOT := "ZZTest Karriere"
	var name1 := Game.save_game(TEST_SLOT)
	assert(name1 == TEST_SLOT, "Benannter Spielstand muss den Namen behalten, war: %s" % name1)
	# (2) Automatischer Name
	var name2 := Game.save_game()
	assert(name2 != "" and name2 != name1, "Auto-Name muss eigener Slot sein")
	# Beide Slots müssen jetzt als eigene Dateien existieren
	var found := {}
	for s in Game.list_saves():
		found[s.path.get_file().get_basename()] = true
	assert(found.has(name1) and found.has(name2), "Beide Spielstände müssen existieren")
	print("Speichern OK: '%s' und '%s' (vorher %d Slots)" % [name1, name2, before])

	# (3) Meta-Daten für die Karten-Anzeige
	var entry := {}
	for s in Game.list_saves():
		if s.path.get_file().get_basename() == TEST_SLOT:
			entry = s
	assert(not entry.is_empty(), "Gespeicherter Slot muss auffindbar sein")
	for key in ["club", "club_short", "club_color", "manager", "season_year", "matchday", "position", "points", "saved_at", "game_mode", "difficulty"]:
		assert(entry.meta.has(key), "Meta-Feld fehlt: %s" % key)
	print("Meta OK: %s (%s) Platz %d, %d Punkte" % [entry.meta.club, entry.meta.club_short, int(entry.meta.position), int(entry.meta.points)])

	# (4) Überschreiben schreibt denselben Slot (keine Kopie)
	Game.play_matchday()
	var count_before := Game.list_saves().size()
	var again := Game.save_game(TEST_SLOT)
	assert(again == TEST_SLOT and Game.list_saves().size() == count_before, "Überschreiben darf keinen neuen Slot anlegen")
	for s in Game.list_saves():
		if s.path.get_file().get_basename() == TEST_SLOT:
			assert(int(s.meta.matchday) == Game.matchday(), "Überschriebener Slot muss den neuen Spieltag zeigen")
	print("Überschreiben OK (Spieltag %d)" % (Game.matchday() + 1))

	# (5) Ungültige Zeichen im Namen werden entschärft
	var tricky := Game.save_game("Test/Name:mit*Zeichen?")
	assert(not tricky.contains("/") and not tricky.contains(":") and not tricky.contains("*"), "Name muss bereinigt werden: %s" % tricky)
	print("Namens-Bereinigung OK: '%s'" % tricky)

	# (6) Laden eines benannten Spielstands
	var target := ""
	for s in Game.list_saves():
		if s.path.get_file().get_basename() == TEST_SLOT:
			target = s.path
	assert(Game.load_game(target), "Benannter Spielstand muss ladbar sein")
	print("Laden OK")

	# (7) Löschen
	var n_before := Game.list_saves().size()
	assert(Game.delete_save(target), "Löschen muss gelingen")
	assert(Game.list_saves().size() == n_before - 1, "Nach dem Löschen muss ein Slot weniger da sein")
	print("Löschen OK")

	# (8) Browser-Oberfläche baut beide Modi ohne Fehler auf
	var browser := SaveBrowser.new()
	add_child(browser)
	await get_tree().process_frame
	browser.open_browser("save")
	await get_tree().process_frame
	assert(browser.visible and browser.mode == "save")
	browser.open_browser("load")
	await get_tree().process_frame
	assert(browser.visible and browser.mode == "load")
	browser.close_browser()
	print("Browser OK (Speicher- und Lademodus)")

	# Aufräumen
	for s in Game.list_saves():
		if str(s.meta.get("manager", "")) == "Speichertester":
			Game.delete_save(s.path)

	print("=== SPEICHER-TEST OK ===")
	get_tree().quit(0)
