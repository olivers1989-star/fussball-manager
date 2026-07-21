extends Node
## Eigenschaften- und Bank-Check: Vergaberegeln, Bank-Beschränkung beim Wechseln
## und messbare Wirkung ausgewählter Eigenschaften (Dauerbrenner, Joker, Eiskalt,
## Heimspielheld, Elfmeterkiller, Trainingsweltmeister).

func _ready() -> void:
	Game.setup = {"name": "Traittester", "mode": "vereinsauswahl"}
	Game.new_game(1)

	# (1) Vergaberegeln: keine Konflikte, Elfmeterkiller nur für Torhüter
	for i in 500:
		var t := PlayerData.roll_traits("MS")
		assert(t.size() <= 2, "Maximal 2 Eigenschaften")
		assert(not t.has("Elfmeterkiller"), "Elfmeterkiller nur fuer TW")
		for pair in PlayerData.TRAIT_CONFLICTS:
			assert(not (t.has(pair[0]) and t.has(pair[1])), "Konflikt vergeben: %s" % str(pair))
	var nat_check := 0
	for pid in Game.world.players:
		var p: PlayerData = Game.world.players[pid]
		assert(p.nat != "", "Jeder Spieler braucht eine Nationalität")
		if p.nat == "Deutschland":
			nat_check += 1
	print("Vergaberegeln OK (Nationalitäten: %d/%d Deutsche)" % [nat_check, Game.world.players.size()])

	# (2) Ersatzbank: max. 7, Ersatztorwart dabei, Wechsel nur von der Bank
	var a := Game.club(1)
	var b := Game.club(2)
	a.lineup = a.best_eleven(Game.world.players)
	a.bench = a.best_bench(Game.world.players, a.lineup)
	assert(a.bench.size() <= ClubData.BENCH_SIZE, "Bank zu gross")
	var has_tw := false
	for pid in a.bench:
		assert(not a.lineup.has(pid), "Bankspieler darf nicht in der Elf stehen")
		if Game.world.players[pid].group() == "TW":
			has_tw = true
	assert(has_tw, "Ersatztorwart muss auf der Bank sitzen")
	var sim := MatchSim.new()
	sim.setup(a, b, Game.world.players)
	var reserve := a.player_ids.filter(func(pid): return not sim.lineup_h.has(pid) and not sim.bench_h.has(pid))
	assert(not reserve.is_empty(), "Es muss Reservespieler geben")
	var out_pid: int = sim.lineup_h[5]
	var err := sim.substitute(true, out_pid, reserve[0])
	assert("Ersatzbank" in err, "Wechsel von ausserhalb der Bank muss scheitern, war: %s" % err)
	print("Bank OK (%d Plätze, Ersatz-TW dabei, Wechsel nur von der Bank)" % a.bench.size())

	# (3) Dauerbrenner: Frische-Verbrauch sinkt um ~22 %
	var p0: PlayerData = Game.world.players[sim.lineup_h[6]]
	p0.traits = []
	var base_drain := sim._drain_rate(p0, "ausgewogen")
	p0.traits = ["Dauerbrenner"]
	var db_drain := sim._drain_rate(p0, "ausgewogen")
	assert(absf(db_drain / base_drain - 0.78) < 0.01, "Dauerbrenner-Faktor falsch: %f" % (db_drain / base_drain))
	print("Dauerbrenner OK (Drain x%.2f)" % (db_drain / base_drain))

	# (4) Situative Boni: Joker, Eiskalt, Heimspielheld, Auswärtskämpfer
	sim.minute = 80
	p0.traits = ["Eiskalt"]
	assert(absf(sim._situ_factor(p0.id) - 1.05) < 0.001, "Eiskalt-Faktor falsch")
	p0.traits = ["Nervenbündel"]
	assert(absf(sim._situ_factor(p0.id) - 0.94) < 0.001, "Nervenbuendel-Faktor falsch")
	p0.traits = ["Joker"]
	sim._subbed_in[p0.id] = true
	assert(absf(sim._situ_factor(p0.id) - 1.06) < 0.001, "Joker-Faktor falsch")
	sim._subbed_in.erase(p0.id)
	p0.traits = ["Heimspielheld"]
	assert(absf(sim._situ_factor(p0.id) - 1.05) < 0.001, "Heimspielheld daheim falsch")
	var away_p: PlayerData = Game.world.players[sim.lineup_a[6]]
	away_p.traits = ["Heimspielheld"]
	assert(absf(sim._situ_factor(away_p.id) - 1.0) < 0.001, "Heimspielheld auswaerts darf nicht wirken")
	away_p.traits = ["Auswärtskämpfer"]
	assert(absf(sim._situ_factor(away_p.id) - 1.05) < 0.001, "Auswaertskaempfer falsch")
	p0.traits = []
	away_p.traits = []
	print("Situative Boni OK (Joker/Eiskalt/Nervenbündel/Heim/Auswärts)")

	# (5) Elfmeterkiller: Torwart hält messbar mehr Elfmeter
	var keeper := sim._keeper_of(false)
	keeper.traits = []
	var goals_before := sim.hg
	for i in 600:
		sim._penalty(true, {"gk_reflex": 60.0})
	var without_trait := sim.hg - goals_before
	keeper.traits = ["Elfmeterkiller"]
	goals_before = sim.hg
	for i in 600:
		sim._penalty(true, {"gk_reflex": 60.0})
	var with_trait := sim.hg - goals_before
	keeper.traits = []
	print("Elfmeter: %d/600 ohne, %d/600 mit Elfmeterkiller" % [without_trait, with_trait])
	assert(with_trait < without_trait - 20, "Elfmeterkiller muss deutlich mehr halten")

	# (6) Trainingsweltmeister: Saisonentwicklung ~25 % schneller
	var dev_p: PlayerData = Game.world.players[Game.club(3).player_ids[5]]
	dev_p.age = 20
	dev_p.potential = 99
	dev_p.matches_season = 20
	dev_p.ratings_sum = 20 * 3.0
	dev_p.traits = []
	var sum_base := 0.0
	for i in 400:
		sum_base += Game._season_development(dev_p)
	dev_p.traits = ["Trainingsweltmeister"]
	var sum_trait := 0.0
	for i in 400:
		sum_trait += Game._season_development(dev_p)
	dev_p.traits = []
	var ratio := sum_trait / sum_base
	print("Trainingsweltmeister: Entwicklung x%.2f" % ratio)
	assert(ratio > 1.12 and ratio < 1.42, "Trainingsweltmeister-Faktor unplausibel: %f" % ratio)

	print("=== TRAITS-TEST OK ===")
	get_tree().quit(0)
