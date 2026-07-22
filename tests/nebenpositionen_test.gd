extends Node
## Nebenpositionen-System: (1) verwandte Rollen sind besser bespielbar als
## gruppenfremde, (2) jeder darf überall gewechselt werden, (3) Einsätze auf
## einer Nebenposition steigern die Vertrautheit bis zur Meisterschaft.

func _ready() -> void:
	Game.setup = {"name": "Nebentester", "mode": "vereinsauswahl"}
	Game.new_game(1)

	# (1) Vertrautheits-Abstufung: RM ist als RV/RA besser als als IV/MS
	var rm := PlayerData.new()
	rm.pos = "RM"
	assert(rm.base_familiarity("RM") == 1.0)
	assert(rm.base_familiarity("RV") > rm.base_familiarity("DM"), "Verwandte Rolle RV muss besser sein als gruppenfremd")
	assert(rm.base_familiarity("RA") >= 0.8, "RM als RA soll gut bespielbar sein")
	assert(rm.base_familiarity("TW") <= 0.5, "Feldspieler im Tor bleibt Notnagel")
	assert(rm.base_familiarity("MS") >= 0.55, "Auch gruppenfremd muss spielbar bleiben (kein Verbot)")
	print("Vertrautheits-Abstufung OK: RV %.2f · RA %.2f · DM %.2f · MS %.2f · TW %.2f" % [
		rm.base_familiarity("RV"), rm.base_familiarity("RA"), rm.base_familiarity("DM"),
		rm.base_familiarity("MS"), rm.base_familiarity("TW")])

	# (2) Wechsel ohne Positionsgruppen-Zwang
	var a := Game.club(1)
	var b := Game.club(2)
	a.lineup = a.best_eleven(Game.world.players)
	a.bench = a.best_bench(Game.world.players, a.lineup)
	var sim := MatchSim.new()
	sim.setup(a, b, Game.world.players)
	# Verteidiger raus, gruppenfremden Bankspieler rein – muss jetzt gehen
	var def_pid := -1
	for pid in sim.lineup_h:
		if Game.world.players[pid].group() == "AB":
			def_pid = pid
			break
	var cross_pid := -1
	for pid in sim.bench_h:
		if Game.world.players[pid].group() != "AB":
			cross_pid = pid
			break
	assert(def_pid > 0 and cross_pid > 0, "Testaufbau: Verteidiger und gruppenfremder Bankspieler nötig")
	var err := sim.substitute(true, def_pid, cross_pid)
	assert(err == "", "Gruppenfremder Wechsel muss erlaubt sein, war: '%s'" % err)
	print("Freier Wechsel OK (%s für %s)" % [Game.world.players[cross_pid].pos, Game.world.players[def_pid].pos])

	# (3) Lernen: RM lernt RV durch wiederholte Einsätze dazu
	var learner := PlayerData.new()
	learner.pos = "RM"
	var start_fam := learner.position_familiarity("RV")
	for i in 20:
		learner.learn_position("RV", 0.014)
	var end_fam := learner.position_familiarity("RV")
	assert(end_fam > start_fam, "Vertrautheit muss durch Einsätze steigen")
	assert(end_fam <= 0.97, "Vertrautheit darf nicht über die Meisterschaft hinaus")
	assert(learner.learned_positions().has("RV"), "RV muss nach Lernphase als gelernt gelten")
	print("Lernen OK: RV %.2f -> %.2f nach 20 Einsätzen (gelernt: %s)" % [start_fam, end_fam, str(learner.learned_positions())])

	# (4) Persistenz: sec_positions überlebt Speichern/Laden
	var dict := learner.to_dict()
	var restored := PlayerData.from_dict(dict)
	assert(absf(restored.position_familiarity("RV") - end_fam) < 0.001, "Gelernte Position muss gespeichert werden")

	# (5) Die feste DB hat vielseitige und reine Spieler gemischt
	var versatile := 0
	for pid in Game.world.players:
		if not Game.world.players[pid].learned_positions().is_empty():
			versatile += 1
	print("Vielseitige Spieler in der Welt: %d von %d" % [versatile, Game.world.players.size()])
	assert(versatile > 100, "Es sollte eine ordentliche Zahl vielseitiger Spieler geben")

	print("=== NEBENPOSITIONEN-TEST OK ===")
	get_tree().quit(0)
