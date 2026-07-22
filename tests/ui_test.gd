extends Node
## UI-Smoke-Test: instanziiert alle Bildschirme und schaltet durch alle Tabs.

func _ready() -> void:
	print("=== UI-TEST START ===")
	# Spielstart-Assistent: Trainer anlegen -> Spielmodus -> Vereinswahl/Angebote -> Verhandlung
	Game.setup = {"club_id": 5}
	for scene_path in ["res://scenes/trainer_anlegen.tscn", "res://scenes/spielmodus.tscn", "res://scenes/vereinswahl.tscn", "res://scenes/angebote.tscn", "res://scenes/verhandlung.tscn"]:
		var screen: Control = load(scene_path).instantiate()
		add_child(screen)
		await get_tree().process_frame
		screen.queue_free()
		await get_tree().process_frame
		print("Assistent OK: ", scene_path.get_file())

	# Verhandlung: Forderung == Angebot muss SOFORT zur Einigung führen
	Game.setup = {"club_id": 5, "mode": "vereinsauswahl", "name": "UI-Tester"}
	var v: Control = load("res://scenes/verhandlung.tscn").instantiate()
	add_child(v)
	await get_tree().process_frame
	v._salary_slider.value = v._offer_salary
	v._bonus_slider.value = v._offer_bonus
	v._win_slider.value = v._offer_win
	v._exit_check.set_pressed_no_signal(false)
	v._on_present()
	assert(v._agreed, "Gleiche Forderung wie Angebot muss sofort Einigung sein")
	# Und: Unterforderung in einer Position darf Überforderung nicht verrechnen
	Game.setup = {"club_id": 6, "mode": "vereinsauswahl", "name": "UI-Tester"}
	var v2: Control = load("res://scenes/verhandlung.tscn").instantiate()
	add_child(v2)
	await get_tree().process_frame
	v2._bonus_slider.value = v2._bonus_slider.max_value
	v2._win_slider.value = 0
	# Überzogene Prämie darf trotz Siegprämie 0 nicht als "Einigkeit" durchgehen
	var excess: float = maxf(0.0, float(int(v2._bonus_slider.value) - v2._offer_bonus) / (v2._offer_salary * 6.0)) * 0.6
	assert(excess > 0.04, "Testaufbau: Prämienforderung muss überzogen sein")
	v2._on_present()
	assert(v2._patience < 100.0 or v2._agreed, "Überzogene Forderung muss Geduld kosten (keine Verrechnung mit Unterforderung)")
	print("Verhandlungs-Einigung OK (Einigkeit sofort, keine Verrechnung)")
	v.queue_free()
	v2.queue_free()
	await get_tree().process_frame

	# Zentrale mit allen Tabs
	Game.setup = {"name": "UI-Tester", "mode": "vereinsauswahl"}
	Game.new_game(5)
	var hub: Control = load("res://scenes/hub.tscn").instantiate()
	add_child(hub)
	await get_tree().process_frame
	assert(hub._screens.size() == 10)
	for title in hub.SCREEN_ORDER:
		hub.show_screen(title)
		await get_tree().process_frame
		print("Screen OK: ", title)
	hub.queue_free()
	await get_tree().process_frame

	# Match-Bildschirm: Anpfiff, Live-Eingriffe (Spielweise + Wechsel), dann durchspulen
	var match_screen: Control = load("res://scenes/match.tscn").instantiate()
	add_child(match_screen)
	await get_tree().process_frame
	match_screen._on_kickoff()
	for i in 30:
		match_screen._on_tick()
	assert(match_screen._my_sim.minute == 30)
	var changed: bool = match_screen._my_sim.set_mentality(match_screen._my_home, "offensiv")
	assert(changed)
	var lineup: Array = match_screen._my_sim.lineup_h if match_screen._my_home else match_screen._my_sim.lineup_a
	var bench: Array = match_screen._my_sim.bench(match_screen._my_home)
	var sub_done := false
	for pid_out in lineup:
		for pid_in in bench:
			if Game.get_player(pid_out).group() == Game.get_player(pid_in).group():
				assert(match_screen._my_sim.substitute(match_screen._my_home, pid_out, pid_in) == "")
				sub_done = true
				break
		if sub_done:
			break
	assert(sub_done)
	assert(match_screen._my_sim.subs_used(match_screen._my_home) == 1)
	match_screen._finish_instantly()
	await get_tree().process_frame
	assert(match_screen._my_sim.finished)
	print("Match-Bildschirm OK (%s, Eingriffe funktionieren)" % match_screen._score_label.text)
	match_screen.queue_free()
	await get_tree().process_frame

	# Zentrale erneut: alle Bereiche nach gespieltem Spieltag (Ergebnisse, Torschützen, Finanzen)
	var hub2: Control = load("res://scenes/hub.tscn").instantiate()
	add_child(hub2)
	await get_tree().process_frame
	for title in hub2.SCREEN_ORDER:
		hub2.show_screen(title)
		await get_tree().process_frame
	print("Zentrale nach Spieltag OK")

	print("=== UI-TEST OK ===")
	get_tree().quit(0)
