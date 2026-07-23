extends Node
## Debug: Screenshots der neuen Spielansicht (Vorschau, Live-Phase, Abpfiff).

func _ready() -> void:
	Game.setup = {"name": "Oliver Smolinski", "mode": "vereinsauswahl", "origin": "Dortmund",
		"skills": {"taktik": 4, "training": 3, "motivation": 2, "verhandlung": 1, "jugend": 1}}
	Game.new_game(2)
	Game.advance_to_matchday()
	var screen: Control = load("res://scenes/match.tscn").instantiate()
	add_child(screen)
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png("user://match_pre_shot.png")
	# Anpfiff und 60 Minuten durchlaufen lassen
	screen._on_kickoff()
	screen._timer.stop()
	for i in 45:
		screen._on_tick()
	# Halbzeit: das Aufstellungsfenster öffnet automatisch
	await get_tree().create_timer(0.8).timeout
	assert(screen._overlay != null and screen._overlay.visible, "Halbzeit öffnet die Aufstellung nicht")
	get_viewport().get_texture().get_image().save_png("user://match_halftime_shot.png")
	screen._close_overlay()
	for i in 20:
		screen._on_tick()
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png("user://match_live_shot.png")
	# Aufstellungs-Overlay mit beiden Teams
	screen._open_overlay()
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png("user://match_overlay_shot.png")
	# Erst nach den Aufnahmen prüfen – die Ablagen stellen die Elf absichtlich um
	_check_drag_and_drop(screen)
	screen._close_overlay()
	screen._finish_instantly()
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png("user://match_post_shot.png")
	print("Screenshots gespeichert")
	get_tree().quit(0)

## Prüft die Ablage-Wege im Halbzeit-Fenster: Karte auf Karte (tauschen),
## Karte auf Rasen (freie Position), Bank auf Karte und Liste auf Liste.
func _check_drag_and_drop(screen: Control) -> void:
	var sim = screen._my_sim
	var home: bool = screen._my_home
	var lineup: Array = sim.lineup_h if home else sim.lineup_a
	var pitch = screen._my_pitch

	# Für jeden Aufgestellten muss genau eine Karte auf dem Feld liegen
	assert(pitch.chips.size() == lineup.size(), "Karten und Elf passen nicht zusammen")
	assert(pitch.get_child_count() == lineup.size(),
		"Alte Karten hängen noch im Feld: %d statt %d" % [pitch.get_child_count(), lineup.size()])

	# 1) Karte auf Karte, Mitte getroffen = Positionen tauschen
	var a: int = lineup[1]
	var b: int = lineup[4]
	var zone_a: String = sim._slot_of(a, home)
	var zone_b: String = sim._slot_of(b, home)
	assert(zone_a != zone_b, "Testvoraussetzung: zwei verschiedene Positionen")
	var chip_a = pitch.chips[a]
	screen._overlay_drop_on_chip(a, chip_a, chip_a.size * 0.5, {"kind": "mslot", "pid": b})
	assert(sim._slot_of(a, home) == zone_b and sim._slot_of(b, home) == zone_a,
		"Tausch per Drag hat nicht gegriffen")

	# 2) Karte auf den Rasen = frei positionieren, Zone wird neu erkannt
	var keeper: int = lineup[0]
	screen._overlay_drop_on_pitch(Vector2(pitch.size.x * 0.5, pitch.size.y * 0.12),
		{"kind": "mslot", "pid": keeper}, pitch)
	assert(sim._slot_of(keeper, home) == "MS",
		"Ablage im Angriffsdrittel ergibt %s statt MS" % sim._slot_of(keeper, home))

	# 3) Bank auf Karte = Wechsel
	var bench: Array = sim.bench(home)
	assert(not bench.is_empty(), "Testvoraussetzung: besetzte Bank")
	var before: int = sim.subs_used(home)
	var target: int = -1
	for pid in (sim.lineup_h if home else sim.lineup_a):
		if sim._slot_of(pid, home) == Game.get_player(bench[0]).pos:
			target = pid
			break
	if target > 0:
		var chip = screen._my_pitch.chips[target]
		screen._overlay_drop_on_chip(target, chip, Vector2.ZERO, {"kind": "mbench", "pid": bench[0]})
		assert(sim.subs_used(home) == before + 1, "Wechsel per Drag auf die Karte fehlt")

	# 4) Bankzeile in der Liste auf einen Feldspieler ziehen
	var bench2: Array = sim.bench(home)
	var lineup2: Array = sim.lineup_h if home else sim.lineup_a
	var before2: int = sim.subs_used(home)
	for pid_in in bench2:
		for pid_out in lineup2:
			if sim._slot_of(pid_out, home) == Game.get_player(pid_in).pos:
				screen._overlay_drop_on_row(pid_out, true, {"kind": "mbench", "pid": pid_in})
				assert(sim.subs_used(home) == before2 + 1, "Wechsel aus der Liste fehlt")
				return
	print("Hinweis: kein passendes Paar für den Listen-Wechsel gefunden")
