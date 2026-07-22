extends Node
## Slot-System-Check: (1) best_eleven ist slot-treu, (2) strength_at bestraft
## Positionsfremde, (3) eine absichtlich verdrehte Elf kassiert im Spiel messbar
## mehr Gegentore als dieselben 11 Spieler in richtiger Ordnung.

const N := 120

func _ready() -> void:
	Game.setup = {"name": "Auftester", "mode": "vereinsauswahl"}
	Game.new_game(1)

	# (1) Slot-Treue: an jedem Slot steht ein Spieler der passenden Positionsgruppe
	for cid in [1, 5, 20]:
		var c: ClubData = Game.club(cid)
		var eleven := c.best_eleven(Game.world.players)
		assert(eleven.size() == 11, "Beste Elf muss 11 Spieler haben")
		var slots: Array = ClubData.FORMATIONS[c.formation]
		for i in 11:
			var p: PlayerData = Game.world.players[eleven[i]]
			assert(p.group() == PlayerData.GROUP_OF[slots[i]],
				"%s: Slot %s (Index %d) besetzt mit %s (%s)" % [c.name, slots[i], i, p.full_name(), p.pos])
	print("Slot-Treue OK (3 Vereine, alle Slots gruppengerecht besetzt)")

	# (1b) Zonen-Erkennung: Feldpunkte werden korrekt in Positionen übersetzt
	assert(ClubData.zone_position(Vector2(0.5, 0.05)) == "TW")
	assert(ClubData.zone_position(Vector2(0.15, 0.3)) == "LV")
	assert(ClubData.zone_position(Vector2(0.5, 0.25)) == "IV")
	assert(ClubData.zone_position(Vector2(0.85, 0.3)) == "RV")
	assert(ClubData.zone_position(Vector2(0.5, 0.45)) == "DM")
	assert(ClubData.zone_position(Vector2(0.5, 0.55)) == "ZM")
	assert(ClubData.zone_position(Vector2(0.5, 0.7)) == "OM")
	assert(ClubData.zone_position(Vector2(0.1, 0.55)) == "LM")
	assert(ClubData.zone_position(Vector2(0.9, 0.55)) == "RM")
	assert(ClubData.zone_position(Vector2(0.15, 0.85)) == "LA")
	assert(ClubData.zone_position(Vector2(0.85, 0.85)) == "RA")
	assert(ClubData.zone_position(Vector2(0.5, 0.9)) == "MS")
	# Jede Preset-Koordinate muss per Zone exakt ihren Formations-Slot ergeben
	for fname in ClubData.FORMATIONS:
		var spots: Array = ClubData.FORMATION_SPOTS[fname]
		for i in 11:
			var zone := ClubData.zone_position(spots[i])
			assert(zone == ClubData.FORMATIONS[fname][i],
				"%s Slot %d: Zone %s statt %s" % [fname, i, zone, ClubData.FORMATIONS[fname][i]])
	print("Zonen-Erkennung OK (12 Zonen + alle 7 Presets konsistent)")

	# (2) strength_at: Stürmer sind als Innenverteidiger deutlich schwächer
	var checked := 0
	for pid in Game.world.players:
		var p: PlayerData = Game.world.players[pid]
		if p.pos == "MS" and p.strength >= 70:
			assert(p.strength_at("IV") < p.strength - 5,
				"%s: MS-Staerke %d, als IV %d – zu wenig Malus" % [p.full_name(), p.strength, p.strength_at("IV")])
			checked += 1
	print("strength_at OK (%d Stürmer geprüft, alle als IV deutlich schwächer)" % checked)

	# (3a) Direkter Ratings-Vergleich: gleiche Simulation, gleiche Tagesform,
	# nur die Elf verdreht – Angriffs- und Abwehrwert müssen deutlich einbrechen
	var a := Game.club(1)
	var b := Game.club(2)
	var probe := MatchSim.new()
	probe.setup(a, b, Game.world.players)
	var r_norm: Dictionary = probe._ratings(probe.lineup_h, probe.slots_h, "ausgewogen", 1.0, false)
	_twist(a, probe.lineup_h)
	var r_twist: Dictionary = probe._ratings(probe.lineup_h, probe.slots_h, "ausgewogen", 1.0, false)
	print("Ratings normal:   att %.1f  def %.1f" % [r_norm.att, r_norm.def])
	print("Ratings verdreht: att %.1f  def %.1f" % [r_twist.att, r_twist.def])
	assert(r_twist.att < r_norm.att * 0.9, "Angriffswert muss mit Verteidigern im Sturm deutlich sinken")
	assert(r_twist.def < r_norm.def * 0.93, "Abwehrwert muss mit Stürmern in der Abwehr deutlich sinken")
	print("Ratings-Beleg OK: Fehlbesetzung senkt die Teamwerte messbar")

	# (3b) Spiel-Beleg über viele Spiele: Tordifferenz muss sich verschlechtern
	var normal := _run_matches(a, b, false)
	var twisted := _run_matches(a, b, true)
	var gd_normal: float = (normal.gf - normal.ga) / float(N)
	var gd_twisted: float = (twisted.gf - twisted.ga) / float(N)
	print("Normale Elf:   %.2f : %.2f pro Spiel (Diff %+.2f)" % [normal.gf / float(N), normal.ga / float(N), gd_normal])
	print("Verdrehte Elf: %.2f : %.2f pro Spiel (Diff %+.2f)" % [twisted.gf / float(N), twisted.ga / float(N), gd_twisted])
	assert(gd_twisted < gd_normal - 0.15, "Verdrehte Elf muss die Tordifferenz verschlechtern")
	assert(twisted.gf < normal.gf, "Verdrehte Elf muss weniger Tore erzielen")
	print("Engine-Beleg OK: Fehlbesetzung kostet messbar Tordifferenz")

	# (4) KI-Vielfalt: Formationen passen zum verfügbaren Kader und sind
	# nicht alle gleich; auch die Grundausrichtungen unterscheiden sich
	var md := Game.start_matchday()
	var forms := {}
	for cid in Game.world.clubs:
		if cid != Game.my_club_id:
			forms[Game.world.clubs[cid].formation] = true
	var mentalities := {}
	for sim in md.others:
		mentalities[sim.mentality_h] = true
		mentalities[sim.mentality_a] = true
	print("KI-Formationen: %s · Ausrichtungen: %s" % [", ".join(forms.keys()), ", ".join(mentalities.keys())])
	assert(forms.size() >= 3, "KI muss verschiedene Formationen spielen (nur %d)" % forms.size())
	assert(mentalities.size() >= 2, "KI muss verschiedene Ausrichtungen spielen")

	print("=== AUFSTELLUNGS-TEST OK ===")
	get_tree().quit(0)

## Simuliert N Spiele; bei twisted=true wird die Elf von Verein a vor jedem
## Spiel verdreht: Abwehr- und Sturm-Slots tauschen die Spieler.
func _run_matches(a: ClubData, b: ClubData, twisted: bool) -> Dictionary:
	var result := {"gf": 0, "ga": 0}
	for i in N:
		for pid in Game.world.players:
			var p: PlayerData = Game.world.players[pid]
			p.condition = 100.0
			p.injury_matchdays = 0
			p.suspended_matchdays = 0
			# Positionslernen zwischen den Experiment-Spielen zurücksetzen, damit
			# nur der reine Positions-Abzug gemessen wird (nicht das Dazulernen)
			p.sec_positions.clear()
		a.lineup = a.best_eleven(Game.world.players)
		b.lineup = b.best_eleven(Game.world.players)
		if twisted:
			_twist(a, a.lineup)
		var sim := MatchSim.new()
		sim.setup(a, b, Game.world.players)
		sim.run_full()
		result.gf += sim.hg
		result.ga += sim.ag
	return result

## Verdreht eine Elf: Abwehr-Slots und Sturm-Slots tauschen ihre Spieler.
func _twist(club: ClubData, lineup: Array) -> void:
	var slots: Array = ClubData.FORMATIONS[club.formation]
	var def_idx: Array = []
	var att_idx: Array = []
	for s in slots.size():
		if PlayerData.GROUP_OF[slots[s]] == "AB":
			def_idx.append(s)
		elif PlayerData.GROUP_OF[slots[s]] == "ST":
			att_idx.append(s)
	for k in mini(def_idx.size(), att_idx.size()):
		var tmp: int = lineup[def_idx[k]]
		lineup[def_idx[k]] = lineup[att_idx[k]]
		lineup[att_idx[k]] = tmp
