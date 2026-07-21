extends Node
## Mechanik-Nachweis: Wirken Attribute, Positionen, Frische, Form, Entwicklung
## und Marktwerte wirklich? Kontrollierte Experimente + Langzeitverlauf.

const N := 150   # Simulationen je Experimentbedingung

var world: Dictionary

func _ready() -> void:
	print("=== MECHANIK-TEST START ===")
	Game.setup = {"name": "Labor", "mode": "vereinsauswahl"}
	Game.new_game(1)
	world = Game.world

	_experiment_abschluss()
	_experiment_flanken()
	_experiment_konzentration()
	_experiment_aggressivitaet()
	_experiment_robustheit()
	_experiment_torwart()
	_check_frische_form()
	_check_entwicklung_marktwert()

	print("=== MECHANIK-TEST OK ===")
	get_tree().quit(0)

# ------------------------------------------------------------------ Labor-Helfer

## Beide Teams komplett vereinheitlichen: alle Attribute 60, Form 1,0, fit.
func _uniformize(c: ClubData) -> void:
	for p in c.players(world.players):
		for key in PlayerData.ATTRIBUTES:
			p.attributes[key] = 60
		p.recompute_strength()
		p.form = 1.0
		p.condition = 100.0
		p.stamina = 70
		p.injury_matchdays = 0
		p.suspended_matchdays = 0
	c.formation = "4-4-2"
	c.lineup = c.best_eleven(world.players)

func _set_attr(c: ClubData, group: String, key: String, value: int) -> void:
	for p in c.players(world.players):
		if group == "ALLE" or p.group() == group:
			p.attributes[key] = value
			p.recompute_strength()
	c.lineup = c.best_eleven(world.players)

func _reset_state(c: ClubData) -> void:
	for p in c.players(world.players):
		p.form = 1.0
		p.condition = 100.0
		p.injury_matchdays = 0
		p.suspended_matchdays = 0

## Simuliert N Spiele A (heim) gegen B und sammelt Kennzahlen.
func _run(a: ClubData, b: ClubData) -> Dictionary:
	var stats := {"goals_a": 0, "goals_b": 0, "header_a": 0, "late_a": 0, "cards_a": 0, "inj_a": 0, "gk_saves_b": 0}
	for i in N:
		_reset_state(a)
		_reset_state(b)
		var sim := MatchSim.new()
		sim.setup(a, b, world.players)
		sim.run_full()
		stats.goals_a += sim.hg
		stats.goals_b += sim.ag
		for ev in sim.events:
			var text: String = ev.text
			if ev.kind == "goal_home" and ("köpft" in text or "Flanke" in text or "Ecke" in text):
				stats.header_a += 1
			if ev.kind == "goal_home" and int(ev.min) > 70:
				stats.late_a += 1
			if ev.kind in ["card", "red"] and ("(%s)" % a.short_name) in text:
				stats.cards_a += 1
			if ev.kind == "injury" and ("(%s)" % a.short_name) in text:
				stats.inj_a += 1
	return stats

# ------------------------------------------------------------------ Experimente

func _experiment_abschluss() -> void:
	var a := Game.club(1)
	var b := Game.club(2)
	_uniformize(a)
	_uniformize(b)
	_set_attr(a, "ST", "abschluss", 90)
	var high := _run(a, b)
	_set_attr(a, "ST", "abschluss", 35)
	var low := _run(a, b)
	print("Abschluss 90 vs. 35 (Sturm): %.2f vs. %.2f Tore/Spiel" % [high.goals_a / float(N), low.goals_a / float(N)])
	assert(high.goals_a > low.goals_a * 1.2)

func _experiment_flanken() -> void:
	var a := Game.club(1)
	var b := Game.club(2)
	_uniformize(a)
	_uniformize(b)
	_set_attr(a, "ALLE", "flanken", 90)
	_set_attr(a, "ST", "kopfball", 85)
	_set_attr(a, "ST", "sprung", 85)
	var high := _run(a, b)
	_set_attr(a, "ALLE", "flanken", 25)
	_set_attr(a, "ST", "kopfball", 35)
	_set_attr(a, "ST", "sprung", 35)
	var low := _run(a, b)
	print("Flanken/Kopfball hoch vs. niedrig: %.2f vs. %.2f Kopfballtore/Spiel" % [high.header_a / float(N), low.header_a / float(N)])
	assert(high.header_a > low.header_a)

func _experiment_konzentration() -> void:
	var a := Game.club(1)
	var b := Game.club(2)
	_uniformize(a)
	_uniformize(b)
	_set_attr(b, "ALLE", "konzentration", 25)
	var sloppy := _run(a, b)
	_set_attr(b, "ALLE", "konzentration", 92)
	var focused := _run(a, b)
	print("Gegner-Konzentration 25 vs. 92: %.2f vs. %.2f Gegentore/Spiel (davon nach Min. 70: %.2f vs. %.2f)" % [
		sloppy.goals_a / float(N), focused.goals_a / float(N), sloppy.late_a / float(N), focused.late_a / float(N)])
	assert(sloppy.late_a > focused.late_a)

func _experiment_aggressivitaet() -> void:
	var a := Game.club(1)
	var b := Game.club(2)
	_uniformize(a)
	_uniformize(b)
	_set_attr(a, "ALLE", "aggressivitaet", 90)
	var wild := _run(a, b)
	_set_attr(a, "ALLE", "aggressivitaet", 20)
	var calm := _run(a, b)
	print("Aggressivität 90 vs. 20: %.2f vs. %.2f Karten/Spiel" % [wild.cards_a / float(N), calm.cards_a / float(N)])
	assert(wild.cards_a > calm.cards_a * 1.4)

func _experiment_robustheit() -> void:
	var a := Game.club(1)
	var b := Game.club(2)
	_uniformize(a)
	_uniformize(b)
	_set_attr(a, "ALLE", "robust", 20)
	var fragile := _run(a, b)
	_set_attr(a, "ALLE", "robust", 92)
	var tough := _run(a, b)
	print("Robustheit 20 vs. 92: %d vs. %d Verletzungen in %d Spielen" % [fragile.inj_a, tough.inj_a, N])
	assert(fragile.inj_a > tough.inj_a)

func _experiment_torwart() -> void:
	var a := Game.club(1)
	var b := Game.club(2)
	_uniformize(a)
	_uniformize(b)
	_set_attr(b, "TW", "reflexe", 92)
	_set_attr(b, "TW", "strafraum", 92)
	var world_class := _run(a, b)
	_set_attr(b, "TW", "reflexe", 30)
	_set_attr(b, "TW", "strafraum", 30)
	var weak := _run(a, b)
	print("Gegnerischer Torwart 92 vs. 30: %.2f vs. %.2f Tore/Spiel gegen ihn" % [world_class.goals_a / float(N), weak.goals_a / float(N)])
	assert(weak.goals_a > world_class.goals_a)

# ------------------------------------------------------------------ Zustand & Entwicklung

func _check_frische_form() -> void:
	# Frische Welt, ein Spieltag: Frische der Startelf muss sinken, Form sich ändern
	Game.setup = {"name": "Labor", "mode": "vereinsauswahl"}
	Game.new_game(1)
	world = Game.world
	var starters: Array = Game.my_club().lineup.duplicate()
	var cond_before := {}
	var form_before := {}
	for pid in starters:
		cond_before[pid] = Game.get_player(pid).condition
		form_before[pid] = Game.get_player(pid).form
	Game.play_matchday()
	var cond_drop := 0.0
	var form_changed := 0
	for pid in starters:
		cond_drop += cond_before[pid] - Game.get_player(pid).condition
		if absf(form_before[pid] - Game.get_player(pid).form) > 0.001:
			form_changed += 1
	print("Nach 1 Spieltag: Ø Frischeverlust Startelf %.1f%%, Form verändert bei %d/11 Spielern" % [cond_drop / starters.size(), form_changed])
	assert(cond_drop / starters.size() > 15.0)
	assert(form_changed >= 8)
	# Erholung über Trainingstage
	var tired: PlayerData = Game.get_player(starters[5])
	var before_regen := tired.condition
	Game.advance_day()
	Game.advance_day()
	print("Frische-Erholung: %d%% -> %d%% nach 2 Trainingstagen" % [int(before_regen), int(tired.condition)])
	assert(tired.condition > before_regen)

func _check_entwicklung_marktwert() -> void:
	# Kohorten-Experiment: alle jungen Spieler abwechselnd auf 5★ und 1★ setzen,
	# 2 Saisons simulieren, Entwicklungsunterschied messen. Dazu Veteranen-Abbau.
	Game.setup = {"name": "Labor", "mode": "vereinsauswahl"}
	Game.new_game(1)
	world = Game.world
	var five := {}
	var one := {}
	var vets := {}
	var flip := true
	for pid in world.players:
		var p: PlayerData = world.players[pid]
		if p.age <= 21:
			if flip:
				p.talent = 5
				p.potential = mini(96, p.strength + 19)
				five[pid] = p.strength
			else:
				p.talent = 1
				p.potential = mini(96, p.strength + 4)
				one[pid] = p.strength
			flip = not flip
		elif p.age >= 31 and p.age <= 32:
			vets[pid] = p.strength
	for season in 2:
		for md in 34:
			Game.play_matchday()
		Game.end_season()
	var gain5 := _avg_gain(five)
	var gain1 := _avg_gain(one)
	var vet_gain := _avg_gain(vets)
	print("Entwicklung über 2 Saisons: 5★-Talente Ø %+.1f, 1★-Talente Ø %+.1f, Routiniers (31/32 J.) Ø %+.1f Stärke" % [gain5, gain1, vet_gain])
	assert(gain5 > gain1 + 1.0)
	assert(gain5 >= 2.0)
	assert(vet_gain < 0.0)
	# Marktwert des besten 5★-Aufsteigers
	var best_pid := -1
	var best_gain := -99
	for pid in five:
		if world.players.has(pid) and world.players[pid].strength - five[pid] > best_gain:
			best_gain = world.players[pid].strength - five[pid]
			best_pid = pid
	var star: PlayerData = world.players[best_pid]
	print("Bestes 5★-Talent: %s (%s), Stärke %d -> %d (Einsätze letzte Saison wirken), Marktwert jetzt %s" % [
		star.full_name(), star.pos, five[best_pid], star.strength, Fmt.money(star.market_value())])
	assert(best_gain >= 4)

func _avg_gain(cohort: Dictionary) -> float:
	var total := 0.0
	var count := 0
	for pid in cohort:
		if world.players.has(pid):
			total += world.players[pid].strength - cohort[pid]
			count += 1
	return (total / count) if count > 0 else 0.0
