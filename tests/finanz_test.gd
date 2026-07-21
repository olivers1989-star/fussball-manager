extends Node
## Finanz- und Karriereende-Check (v0.12.0): simuliert 3 Saisons und prüft
## Marktwert-Skala, Budget-Stabilität aller Vereine und die Rücktritts-Streuung.

func _ready() -> void:
	Game.setup = {"name": "Finanztester", "mode": "vereinsauswahl"}
	Game.new_game(1)

	print("=== MARKTWERT-STICHPROBEN (Saisonstart) ===")
	var samples := {}
	for pid in Game.world.players:
		var p: PlayerData = Game.world.players[pid]
		var bucket := int(p.strength / 10) * 10
		if not samples.has(bucket) or absi(samples[bucket].age - 25) > absi(p.age - 25):
			samples[bucket] = p
	var buckets: Array = samples.keys()
	buckets.sort()
	for b in buckets:
		var p: PlayerData = samples[b]
		print("  St %2d, %2d J.: %12s  (Gehalt %s/Monat)  %s" % [p.strength, p.age, Fmt.money(p.market_value()), Fmt.money(p.salary), p.full_name()])
	var top: Array = Game.world.players.values()
	top.sort_custom(func(a, b): return a.market_value() > b.market_value())
	print("  Teuerster Spieler: %s (St %d, %d J.) = %s" % [top[0].full_name(), top[0].strength, top[0].age, Fmt.money(top[0].market_value())])
	assert(top[0].market_value() >= 40000000, "Topspieler sollte >= 40 Mio wert sein")
	assert(top[0].market_value() <= 250000000, "Marktwert-Deckel verletzt")

	print("\n=== BUDGETS (Saisonstart) ===")
	var start_budget := {}
	for cid in Game.world.clubs:
		start_budget[cid] = Game.world.clubs[cid].budget
	for cid in [1, 10, 19, 30]:
		var c: ClubData = Game.world.clubs[cid]
		print("  %-28s L%d  Budget %12s  Sponsor/ST %10s  Gehälter/ST %10s" % [c.name, c.league_id, Fmt.money(c.budget), Fmt.money(c.sponsor_per_md), Fmt.money(c.salaries_per_matchday(Game.world.players))])

	for season in 3:
		for md in 34:
			Game.play_matchday()
		Game.end_season()
		print("Saison %d fertig." % (season + 1))

	print("\n=== BUDGET-DRIFT nach 3 Saisons ===")
	var broke := 0
	var exploded := 0
	for cid in Game.world.clubs:
		var c: ClubData = Game.world.clubs[cid]
		if c.budget < 0:
			broke += 1
			print("  PLEITE: %s  %s" % [c.name, Fmt.money(c.budget)])
		if c.budget > start_budget[cid] * 6 + 60000000:
			exploded += 1
			print("  EXPLODIERT: %s  %s -> %s" % [c.name, Fmt.money(start_budget[cid]), Fmt.money(c.budget)])
	for cid in [1, 10, 19, 30]:
		var c: ClubData = Game.world.clubs[cid]
		print("  %-28s %12s -> %12s" % [c.name, Fmt.money(start_budget[cid]), Fmt.money(c.budget)])
	assert(broke == 0, "Kein Verein darf pleitegehen")
	assert(exploded <= 3, "Budgets duerfen nicht explodieren")

	print("\n=== KARRIEREENDEN (3 Saisons, aus dem Archiv) ===")
	var by_age := {}
	var tw_ages: Array = []
	var field_ages: Array = []
	for r in Game.world.retired:
		by_age[int(r.age)] = by_age.get(int(r.age), 0) + 1
		if r.pos == "TW":
			tw_ages.append(int(r.age))
		else:
			field_ages.append(int(r.age))
	var ages: Array = by_age.keys()
	ages.sort()
	for a in ages:
		print("  %d Jahre: %s" % [a, "#".repeat(by_age[a])])
	print("  Gesamt: %d (Feldspieler: %d, Torhüter: %d)" % [Game.world.retired.size(), field_ages.size(), tw_ages.size()])
	assert(ages.size() >= 4, "Ruecktrittsalter muss streuen (mind. 4 verschiedene Alter)")
	assert(ages[0] <= 33, "Auch fruehe Karriereenden (<= 33) muessen vorkommen")
	assert(ages[-1] >= 36, "Auch spaete Karriereenden (>= 36) muessen vorkommen")
	if tw_ages.size() >= 3 and field_ages.size() >= 3:
		var tw_avg := 0.0
		for a in tw_ages: tw_avg += a
		tw_avg /= tw_ages.size()
		var f_avg := 0.0
		for a in field_ages: f_avg += a
		f_avg /= field_ages.size()
		print("  Durchschnitt: Feldspieler %.1f J., Torhüter %.1f J." % [f_avg, tw_avg])
		assert(tw_avg > f_avg, "Torhueter muessen im Schnitt laenger spielen")

	print("\nFINANZ-TEST OK")
	get_tree().quit(0)
