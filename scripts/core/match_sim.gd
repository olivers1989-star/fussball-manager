class_name MatchSim
extends RefCounted
## Live-Simulation eines Spiels, Minute für Minute.
## Das Ergebnis entsteht WÄHREND des Spiels: Taktikwechsel, Auswechslungen und
## Platzverweise wirken sich ab der jeweils nächsten Minute aus.
## Die KI passt ihre Spielweise je nach Spielstand selbst an (Minute 60 und 75).

const CHANCE_BASE := 0.048
const HOME_BONUS := 1.10
const MAX_SUBS := 5
const MENTALITIES := {
	"defensiv":   {"att": 0.90, "mid": 1.00, "def": 1.10},
	"ausgewogen": {"att": 1.00, "mid": 1.00, "def": 1.00},
	"offensiv":   {"att": 1.10, "mid": 1.03, "def": 0.90},
}

var home: ClubData
var away: ClubData
var players: Dictionary
var fixture: Dictionary = {}
var league_name := ""

var minute := 0
var hg := 0
var ag := 0
var events: Array = []      # {min, kind, text}
var finished := false

var lineup_h: Array = []
var lineup_a: Array = []
var slots_h: Array = []     # Formations-Slot je Aufstellungsindex: der Spieler
var slots_a: Array = []     # WIRD auf diesem Slot bewertet (slot-basiertes System)
var mentality_h := "ausgewogen"
var mentality_a := "ausgewogen"
var factor_h := 1.0         # externe Boni (z. B. Trainer-Fähigkeit "Taktik")
var factor_a := 1.0
var red_h := 1.0            # Malus nach Platzverweis
var red_a := 1.0
var plan_h := {}            # Matchplan aus der Spielvorbereitung (leer = neutral)
var plan_a := {}
var subs_h := 0
var subs_a := 0
var ai_h := true            # true = KI steuert die Spielweise dieser Seite
var ai_a := true
var is_friendly := false    # Testspiel: zählt nicht für Saisonstatistik und Sperren

var cond := {}              # pid -> aktuelle Frische im Spiel (sinkt Minute für Minute)
var dayform := {}           # pid -> Tagesform 0.94..1.06 (jeden Spieltag neu ausgewürfelt)

## Spielstatistik (für die Statistik-Anzeige im Spielbildschirm).
var stats := {
	"chances_h": 0, "chances_a": 0, "corners_h": 0, "corners_a": 0,
	"freekicks_h": 0, "freekicks_a": 0, "penalties_h": 0, "penalties_a": 0,
	"yellow_h": 0, "yellow_a": 0, "reds_h": 0, "reds_a": 0,
	"poss_h": 0.0, "poss_n": 0,
}

var match_goals := {}       # pid -> Tore in DIESEM Spiel (Live-Anzeige)
var goal_log: Array = []    # [{min, pid, home, score}] – für den Spielbericht
var ht_h := 0               # Halbzeitstand
var ht_a := 0

## Ballbesitz-Schätzung der Heimmannschaft (aus den Mittelfeld-Anteilen).
func possession_home() -> float:
	return (stats.poss_h / stats.poss_n) if stats.poss_n > 0 else 0.5

## Live-Note eines Spielers während des Spiels (gleiche Basis wie die Endnote).
func live_rating(pid: int) -> float:
	var result_adj := 0.0
	var is_home_player: bool = _is_home_side.get(pid, true)
	if hg != ag:
		result_adj = -0.4 if ((hg > ag) == is_home_player) else 0.4
	var day_adj: float = (1.0 - dayform.get(pid, 1.0)) * 8.0
	return clampf(3.5 + _note_adj.get(pid, 0.0) + result_adj + day_adj, 1.0, 6.0)

var bench_h: Array = []     # Ersatzbank (max. ClubData.BENCH_SIZE): nur von hier darf gewechselt werden
var bench_a: Array = []
var _off_h: Array = []      # Ausgewechselte dürfen nicht zurück aufs Feld
var _off_a: Array = []
var _is_home_side := {}     # pid -> true/false (für Eigenschaften wie Heimspielheld)
var _subbed_in := {}        # pid -> true für Eingewechselte (Eigenschaft "Joker")
var _note_adj := {}         # pid -> Noten-Anpassung durch Aktionen (Tore, Karten ...)
var _appeared := {}         # pid -> true für alle eingesetzten Spieler
var _rng := RandomNumberGenerator.new()

func setup(p_home: ClubData, p_away: ClubData, p_players: Dictionary) -> void:
	home = p_home
	away = p_away
	players = p_players
	_rng.randomize()
	lineup_h = home.match_lineup(players).duplicate()
	lineup_a = away.match_lineup(players).duplicate()
	slots_h = _slots_for(home, lineup_h)
	slots_a = _slots_for(away, lineup_a)
	bench_h = home.match_bench(players, lineup_h).duplicate()
	bench_a = away.match_bench(players, lineup_a).duplicate()
	for pid in home.player_ids:
		_is_home_side[pid] = true
	for pid in away.player_ids:
		_is_home_side[pid] = false
	# Frische übernehmen und Tagesform auswürfeln – jeder Spieler hat gute und schlechte Tage
	for pid in home.player_ids + away.player_ids:
		cond[pid] = players[pid].condition
		dayform[pid] = _rng.randf_range(0.94, 1.06)
	for pid in lineup_h + lineup_a:
		_appeared[pid] = true

## Simuliert genau eine Spielminute.
func tick() -> void:
	if finished:
		return
	minute += 1
	if minute == 1:
		_emit("info", "Anpfiff im %s! %s empfängt %s." % [home.stadium, home.name, away.name])
	if minute == 46:
		_emit("info", "Die zweite Halbzeit läuft. Zwischenstand: %d:%d." % [hg, ag])
	if minute == 45:
		ht_h = hg
		ht_a = ag

	_ai_adjust()
	_drain_condition()
	_maybe_injury()

	var rat_h := _ratings(lineup_h, slots_h, mentality_h, factor_h * red_h, hg < ag, plan_h)
	var rat_a := _ratings(lineup_a, slots_a, mentality_a, factor_a * red_a, ag < hg, plan_a)

	var mid_sum: float = rat_h.mid + rat_a.mid
	stats.poss_h += rat_h.mid / mid_sum
	stats.poss_n += 1
	# Laufende Standards ohne Großchance (realistische Eckball-/Freistoßzahlen):
	# das dominierende Team erarbeitet sich mehr davon
	var home_share: float = rat_h.mid / mid_sum
	if _rng.randf() < 0.115:
		stats["corners_h" if _rng.randf() < home_share else "corners_a"] += 1
	if _rng.randf() < 0.24:
		stats["freekicks_h" if _rng.randf() < home_share else "freekicks_a"] += 1
	var p_home: float = CHANCE_BASE * (2.0 * rat_h.mid / mid_sum) * HOME_BONUS
	var p_away: float = CHANCE_BASE * (2.0 * rat_a.mid / mid_sum) * (2.0 - HOME_BONUS)

	if _rng.randf() < p_home:
		_chance(true, rat_h, rat_a)
	elif _rng.randf() < p_away:
		_chance(false, rat_a, rat_h)

	# Standards: Freistöße und Ecken (Standardfokus aus der Vorbereitung erhöht die Rate)
	if _rng.randf() < 0.006 + float(plan_h.get("setpiece", 0.0)):
		_set_piece(true, rat_h, rat_a)
	if _rng.randf() < 0.006 + float(plan_a.get("setpiece", 0.0)):
		_set_piece(false, rat_a, rat_h)

	# Elfmeter (selten)
	if _rng.randf() < 0.0009:
		_penalty(true, rat_a)
	elif _rng.randf() < 0.0009:
		_penalty(false, rat_h)

	_flow_commentary(rat_h, rat_a)
	_maybe_card()

	if minute >= 90:
		_emit("info", "Abpfiff! Endstand: %d:%d." % [hg, ag])
		finished = true
		_finalize()

## Spult das Spiel ohne Eingriffe bis zum Abpfiff durch (KI-Spiele, Schnellsimulation).
func run_full() -> void:
	while not finished:
		tick()

## Positions-Slots passend zur Aufstellung: frei positionierte Elf (Zonen der
## Feldpunkte) für die gespeicherte Aufstellung, sonst das Formations-Preset;
## Fallback auf die eigene Position bei Rumpfkadern.
func _slots_for(club: ClubData, lineup: Array) -> Array:
	if club.lineup == lineup and club.lineup_spots.size() == lineup.size() and not lineup.is_empty():
		return club.lineup_slots()
	var slots: Array = ClubData.FORMATIONS.get(club.formation, ClubData.FORMATIONS["4-4-2"]).duplicate()
	if slots.size() != lineup.size():
		slots.clear()
		for pid in lineup:
			slots.append(players[pid].pos)
	return slots

## Stellt die gespielte Position eines Feldspielers LIVE um (Aufstellungs-Overlay
## im Spiel) – wirkt ab der nächsten Minute auf die Teamwerte.
func set_slot(is_home: bool, pid: int, new_slot: String) -> bool:
	if not PlayerData.GROUP_OF.has(new_slot):
		return false
	var lineup: Array = lineup_h if is_home else lineup_a
	var idx := lineup.find(pid)
	var slots: Array = slots_h if is_home else slots_a
	if idx < 0 or idx >= slots.size():
		return false
	slots[idx] = new_slot
	return true

## Der Slot, auf dem ein Spieler gerade spielt (Bewertungsgrundlage).
func _slot_of(pid: int, is_home: bool) -> String:
	var lineup: Array = lineup_h if is_home else lineup_a
	var idx := lineup.find(pid)
	if idx < 0:
		return players[pid].pos
	var slots: Array = slots_h if is_home else slots_a
	return slots[idx] if idx < slots.size() else players[pid].pos

# ------------------------------------------------------------------ Eingriffe

## Wechselt einen Spieler (nur gleiche Position, max. MAX_SUBS). "" bei Erfolg.
func substitute(is_home: bool, pid_out: int, pid_in: int) -> String:
	if finished:
		return "Das Spiel ist vorbei."
	var lineup: Array = lineup_h if is_home else lineup_a
	var off: Array = _off_h if is_home else _off_a
	var club: ClubData = home if is_home else away
	if (subs_h if is_home else subs_a) >= MAX_SUBS:
		return "Alle %d Wechsel sind bereits aufgebraucht." % MAX_SUBS
	if not lineup.has(pid_out):
		return "Dieser Spieler steht nicht auf dem Feld."
	if lineup.has(pid_in) or off.has(pid_in) or not club.player_ids.has(pid_in):
		return "Dieser Spieler kann nicht eingewechselt werden."
	if not (bench_h if is_home else bench_a).has(pid_in):
		return "Dieser Spieler steht nicht auf der Ersatzbank."
	var p_out: PlayerData = players[pid_out]
	var p_in: PlayerData = players[pid_in]
	if not p_in.is_available():
		return "%s ist nicht einsatzbereit (verletzt oder gesperrt)." % p_in.full_name()
	# Jeder Spieler darf jede Position einnehmen (auf der Zone des Ausgewechselten
	# bewertet, ggf. mit Vertrautheits-Abzug) – kein Positionsgruppen-Zwang mehr
	lineup[lineup.find(pid_out)] = pid_in
	off.append(pid_out)
	_appeared[pid_in] = true
	_subbed_in[pid_in] = true
	if is_home:
		subs_h += 1
	else:
		subs_a += 1
	_emit("sub", "Wechsel bei %s: %s kommt für %s." % [club.short_name, p_in.full_name(), p_out.full_name()])
	return ""

## Stellt die Spielweise um. Gibt true zurück, wenn sich etwas geändert hat.
func set_mentality(is_home: bool, m: String) -> bool:
	if finished or not MENTALITIES.has(m):
		return false
	if is_home:
		if mentality_h == m:
			return false
		mentality_h = m
	else:
		if mentality_a == m:
			return false
		mentality_a = m
	var club: ClubData = home if is_home else away
	_emit("info", "%s stellt die Spielweise um: %s." % [club.short_name, m])
	return true

func subs_used(is_home: bool) -> int:
	return subs_h if is_home else subs_a

## Wechselkandidaten: NUR die nominierte Ersatzbank (max. 7 Plätze).
func bench(is_home: bool) -> Array:
	var lineup: Array = lineup_h if is_home else lineup_a
	var off: Array = _off_h if is_home else _off_a
	var pool: Array = bench_h if is_home else bench_a
	return pool.filter(func(pid):
		return not lineup.has(pid) and not off.has(pid) and players[pid].is_available())

## Alle eingesetzten Spieler einer Seite (Startelf + Eingewechselte + Ausgewechselte).
func participants(is_home: bool) -> Array:
	var result: Array = []
	for pid in _appeared:
		if (home if is_home else away).player_ids.has(pid):
			result.append(pid)
	return result

# ------------------------------------------------------------------ Intern

## KI-Vereine reagieren auf den Spielstand.
func _ai_adjust() -> void:
	if minute != 60 and minute != 75:
		return
	if ai_h:
		var target_h := "ausgewogen"
		if hg < ag:
			target_h = "offensiv"
		elif hg > ag:
			target_h = "defensiv"
		set_mentality(true, target_h)
	if ai_a:
		var target_a := "ausgewogen"
		if ag < hg:
			target_a = "offensiv"
		elif ag > hg:
			target_a = "defensiv"
		set_mentality(false, target_a)

## Offene Spielchance: normaler Angriff oder Flankenangriff (Kopfball).
func _chance(for_home: bool, own: Dictionary, opp: Dictionary) -> void:
	var lineup: Array = lineup_h if for_home else lineup_a
	var club: ClubData = home if for_home else away
	stats["chances_h" if for_home else "chances_a"] += 1
	# Flankenangriffe: je besser die Außenbahnen, desto häufiger
	if _rng.randf() < clampf(0.12 + own.wide / 400.0, 0.12, 0.4):
		var header := _pick_scorer(lineup, "kopfball", for_home)
		var denom: float = opp.def * 0.75 + opp.box * 0.25
		var conversion := clampf(0.24 * pow(own.header / denom, 1.3), 0.05, 0.55)
		if header.has_trait("Kopfballungeheuer"):
			conversion *= 1.12
		if _rng.randf() < conversion:
			_goal(for_home, club, header, "TOR für %s! Nach einer scharfen Flanke köpft %s zum %s ein.")
		elif _rng.randf() < 0.4:
			_emit("chance", "Flanke auf %s – sein Kopfball geht knapp vorbei!" % header.full_name())
		return
	var scorer := _pick_scorer(lineup, "normal", for_home)
	# Die Abschlussstärke des Schützen entscheidet mit (Knipser-Faktor)
	var conversion := clampf(0.30 * pow(own.att / opp.def, 1.4) * (0.7 + scorer.attr("abschluss") / 200.0), 0.05, 0.7)
	if scorer.has_trait("Knipser"):
		conversion *= 1.12
	# Nervenstärke zählt in der Schlussphase
	if minute >= 75:
		conversion *= 0.9 + scorer.attr("nerven") / 500.0
	if _rng.randf() < conversion:
		_goal(for_home, club, scorer, "TOR für %s! %s trifft zum %s.")
	elif _rng.randf() < 0.45:
		_emit("chance", "Großchance für %s – %s scheitert!" % [club.name, scorer.full_name()])

## Freistoß oder Ecke: die Standards- und Kopfballspezialisten übernehmen.
func _set_piece(for_home: bool, own: Dictionary, opp: Dictionary) -> void:
	var lineup: Array = lineup_h if for_home else lineup_a
	var club: ClubData = home if for_home else away
	var taker := _best_by(lineup, "standards")
	# Ein Freistoßspezialist schnappt sich den Ball, auch wenn andere bessere Standards haben
	for pid in lineup:
		if players[pid].has_trait("Freistoßspezialist"):
			taker = players[pid]
			break
	if _rng.randf() < 0.4:
		# Direkter Freistoß
		stats["freekicks_h" if for_home else "freekicks_a"] += 1
		var conversion := clampf(0.04 + taker.attr("standards") * 0.0013, 0.03, 0.17)
		if taker.has_trait("Freistoßspezialist"):
			conversion += 0.05
		if _rng.randf() < conversion:
			_goal(for_home, club, taker, "TOR für %s! %s zirkelt den Freistoß direkt ins Netz – %s.")
		elif _rng.randf() < 0.5:
			_emit("chance", "Freistoß %s: %s fordert den Torwart mit einem strammen Schuss." % [club.short_name, taker.full_name()])
	else:
		# Ecke → Kopfballchance
		stats["corners_h" if for_home else "corners_a"] += 1
		var header := _pick_scorer(lineup, "kopfball", for_home)
		var denom: float = opp.def * 0.7 + opp.box * 0.3
		var conversion := clampf(0.16 * pow(own.header / denom, 1.2), 0.04, 0.4)
		if _rng.randf() < conversion:
			_goal(for_home, club, header, "TOR für %s! Ecke von " + taker.last_name + ", %s köpft wuchtig ein – %s!")
		elif _rng.randf() < 0.4:
			_emit("chance", "Ecke für %s – %s köpft über das Tor." % [club.short_name, header.full_name()])

## Elfmeter: Standards + Nervenstärke des Schützen gegen die Reflexe des Torwarts.
func _penalty(for_home: bool, opp: Dictionary) -> void:
	var lineup: Array = lineup_h if for_home else lineup_a
	var club: ClubData = home if for_home else away
	stats["penalties_h" if for_home else "penalties_a"] += 1
	var taker := _best_by_combo(lineup, "standards", "nerven")
	# Ein Elfmeterspezialist übernimmt die Verantwortung immer selbst
	for pid in lineup:
		if players[pid].has_trait("Elfmeterspezialist"):
			taker = players[pid]
			break
	_emit("chance", "ELFMETER für %s! %s legt sich den Ball zurecht …" % [club.name, taker.full_name()])
	var composure := (taker.attr("standards") + taker.attr("nerven")) / 2.0
	var conversion := clampf(0.55 + (composure - 40.0) * 0.005 - (opp.gk_reflex - 60.0) * 0.002, 0.45, 0.92)
	if taker.has_trait("Elfmeterspezialist"):
		conversion += 0.08
	if _keeper_of(not for_home).has_trait("Elfmeterkiller"):
		conversion -= 0.12
	conversion = clampf(conversion, 0.3, 0.95)
	if _rng.randf() < conversion:
		_goal(for_home, club, taker, "TOR für %s! %s verwandelt den Elfmeter eiskalt – %s.")
	else:
		_note_adj[taker.id] = _note_adj.get(taker.id, 0.0) + 0.5
		_emit("chance", "Der Torwart ahnt die Ecke – %s scheitert vom Punkt!" % taker.full_name())

## Laufender Spielkommentar: hält den Ticker lebendig, ohne Tore zu übertönen.
func _flow_commentary(rat_h: Dictionary, rat_a: Dictionary) -> void:
	if _rng.randf() >= 0.17:
		return
	var home_edge: float = rat_h.mid / (rat_h.mid + rat_a.mid)
	var attacking_home := _rng.randf() < home_edge
	var club: ClubData = home if attacking_home else away
	var lineup: Array = lineup_h if attacking_home else lineup_a
	var p: PlayerData = players[lineup[_rng.randi_range(1, lineup.size() - 1)]]
	var trailing: bool = (hg < ag) if attacking_home else (ag < hg)
	var pool: Array
	if trailing and minute > 60:
		pool = [
			"%s wirft jetzt alles nach vorn!" % club.name,
			"%s treibt seine Mitspieler mit wilden Gesten an." % p.full_name(),
			"Druckphase von %s – der Gegner steht ganz tief." % club.short_name,
			"Die Fans von %s peitschen ihre Mannschaft nach vorn." % club.short_name,
		]
	else:
		pool = [
			"%s kombiniert sich gefällig durchs Mittelfeld." % club.name,
			"%s setzt sich über die Außenbahn durch, aber die Hereingabe wird geklärt." % p.full_name(),
			"Weitschuss von %s – sichere Beute für den Torwart." % p.full_name(),
			"%s gewinnt einen wichtigen Zweikampf im Zentrum." % p.full_name(),
			"Abseits! %s ist einen Schritt zu früh gestartet." % p.full_name(),
			"Viel Kampf, wenig Räume – %s beißt sich im Mittelfeld fest." % club.short_name,
			"Ecke für %s – die kurze Variante verpufft." % club.short_name,
			"%s foult im Mittelfeld – der Freistoß bringt nichts ein." % p.full_name(),
			"%s schaltet schnell um, doch der Pass in die Tiefe ist zu lang." % club.short_name,
			"Kopfballduell im Mittelfeld – %s behauptet den Ball." % p.full_name(),
		]
	_emit("flow", pool.pick_random())

func _goal(for_home: bool, club: ClubData, scorer: PlayerData, template: String) -> void:
	if not is_friendly:
		scorer.goals_season += 1
	match_goals[scorer.id] = match_goals.get(scorer.id, 0) + 1
	_note_adj[scorer.id] = _note_adj.get(scorer.id, 0.0) - 0.7
	if for_home:
		hg += 1
		_emit("goal_home", template % [club.name, scorer.full_name(), "%d:%d" % [hg, ag]])
	else:
		ag += 1
		_emit("goal_away", template % [club.name, scorer.full_name(), "%d:%d" % [hg, ag]])
	goal_log.append({"min": maxi(minute, 1), "pid": scorer.id, "home": for_home, "score": "%d:%d" % [hg, ag]})

func _best_by(lineup: Array, key: String) -> PlayerData:
	var best: PlayerData = players[lineup[0]]
	for pid in lineup:
		if players[pid].attr(key) > best.attr(key):
			best = players[pid]
	return best

func _best_by_combo(lineup: Array, key_a: String, key_b: String) -> PlayerData:
	var best: PlayerData = players[lineup[0]]
	for pid in lineup:
		if players[pid].combo(key_a, key_b, 0.5) > best.combo(key_a, key_b, 0.5):
			best = players[pid]
	return best

## Kartenrisiko pro Seite: aggressive Teams foulen wirklich häufiger.
func _maybe_card() -> void:
	_maybe_card_side(true)
	_maybe_card_side(false)

func _maybe_card_side(card_home: bool) -> void:
	var lineup: Array = lineup_h if card_home else lineup_a
	var off: Array = _off_h if card_home else _off_a
	var club: ClubData = home if card_home else away
	var aggr_sum := 0.0
	for pid in lineup:
		aggr_sum += players[pid].attr("aggressivitaet")
	var chance := 0.0055 * (0.5 + (aggr_sum / lineup.size()) / 75.0)
	if _rng.randf() >= chance:
		return
	# Aggressive Spieler kassieren häufiger Karten (Hitzköpfe erst recht)
	var total := 0.0
	var weights: Array = []
	for i in range(1, lineup.size()):
		var w: float = 0.4 + players[lineup[i]].attr("aggressivitaet") / 70.0
		if players[lineup[i]].has_trait("Hitzkopf"):
			w *= 1.9
		elif players[lineup[i]].has_trait("Fairplay"):
			w *= 0.35
		total += w
		weights.append([lineup[i], w])
	var roll := _rng.randf() * total
	var pid: int = weights.back()[0]
	for entry in weights:
		roll -= entry[1]
		if roll <= 0.0:
			pid = entry[0]
			break
	var p: PlayerData = players[pid]
	var red_chance := clampf(0.03 + p.attr("aggressivitaet") * 0.0006, 0.03, 0.12)
	if p.has_trait("Hitzkopf"):
		red_chance += 0.03
	if _rng.randf() < red_chance:
		stats["reds_h" if card_home else "reds_a"] += 1
		if not is_friendly:   # Testspiel-Karten zählen nicht für Sperren
			p.red_cards += 1
			p.suspended_matchdays += 2
		_note_adj[p.id] = _note_adj.get(p.id, 0.0) + 1.2
		_emit("red", "ROTE KARTE! %s (%s) muss vom Platz und ist für 2 Spieltage gesperrt!" % [p.full_name(), club.short_name])
		var ridx := lineup.find(p.id)
		lineup.remove_at(ridx)
		var rslots: Array = slots_h if card_home else slots_a
		if ridx < rslots.size():
			rslots.remove_at(ridx)
		off.append(p.id)
		if card_home:
			red_h *= 0.86
		else:
			red_a *= 0.86
	elif is_friendly:
		stats["yellow_h" if card_home else "yellow_a"] += 1
		_note_adj[p.id] = _note_adj.get(p.id, 0.0) + 0.2
		_emit("card", "Gelbe Karte für %s (%s)." % [p.full_name(), club.short_name])
	else:
		stats["yellow_h" if card_home else "yellow_a"] += 1
		p.yellow_cards += 1
		_note_adj[p.id] = _note_adj.get(p.id, 0.0) + 0.2
		if p.yellow_cards % 5 == 0:
			p.suspended_matchdays += 1
			_emit("card", "Gelbe Karte für %s (%s) – seine %d. der Saison, er ist damit einen Spieltag gesperrt!" % [p.full_name(), club.short_name, p.yellow_cards])
		else:
			_emit("card", "Gelbe Karte für %s (%s)." % [p.full_name(), club.short_name])

## Torschützen-Auswahl: bei normalen Angriffen zählt der Abschluss (Knipser-Effekt),
## bei Flanken und Ecken Kopfball × Sprungkraft (dann köpfen auch Innenverteidiger).
## Gewichtet nach dem SLOT, auf dem der Spieler gerade spielt.
func _pick_scorer(lineup: Array, mode: String, is_home: bool) -> PlayerData:
	var group_weights: Dictionary
	if mode == "kopfball":
		group_weights = {"TW": 0.01, "AB": 2.0, "MF": 1.5, "ST": 5.0}
	else:
		group_weights = {"TW": 0.05, "AB": 1.0, "MF": 3.0, "ST": 7.0}
	var total := 0.0
	var pool: Array = []
	for pid in lineup:
		var p: PlayerData = players[pid]
		var value: float = p.combo("kopfball", "sprung") if mode == "kopfball" else float(p.attr("abschluss"))
		var w: float = group_weights[PlayerData.GROUP_OF[_slot_of(pid, is_home)]] * (value / 60.0)
		if mode == "kopfball" and p.has_trait("Kopfballungeheuer"):
			w *= 1.5
		total += w
		pool.append([p, w])
	var roll := _rng.randf() * total
	for entry in pool:
		roll -= entry[1]
		if roll <= 0.0:
			return entry[0]
	return pool.back()[0]

## Leistung eines Spielers in dieser Minute: Stärke × Form × Tagesform × Frische × Eigenschaften.
func _player_effective(pid: int) -> float:
	var p: PlayerData = players[pid]
	return p.rating() * dayform[pid] * (0.72 + 0.28 * cond[pid] / 100.0) * _situ_factor(pid)

## Effektiver Attributwert in dieser Minute (Form, Tagesform, Frische und
## situative Eigenschaften wie Joker/Eiskalt/Heimspielheld eingerechnet).
func _attr_val(pid: int, key: String) -> float:
	var p: PlayerData = players[pid]
	return p.attr(key) * p.form * dayform[pid] * (0.72 + 0.28 * cond[pid] / 100.0) * _situ_factor(pid)

## Situative Eigenschafts-Boni dieser Minute.
func _situ_factor(pid: int) -> float:
	var p: PlayerData = players[pid]
	if p.traits.is_empty():
		return 1.0
	var f := 1.0
	if _subbed_in.has(pid) and p.has_trait("Joker"):
		f *= 1.06
	if minute >= 75:
		if p.has_trait("Eiskalt"):
			f *= 1.05
		elif p.has_trait("Nervenbündel"):
			f *= 0.94
	if p.has_trait("Spätzünder"):
		f *= 1.05 if minute > 45 else 0.97
	var at_home: bool = _is_home_side.get(pid, true)
	if p.has_trait("Heimspielheld") and at_home:
		f *= 1.05
	if p.has_trait("Auswärtskämpfer") and not at_home:
		f *= 1.05
	return f

## Der Torwart einer Seite (der Spieler auf dem TW-Slot).
func _keeper_of(is_home: bool) -> PlayerData:
	var lineup: Array = lineup_h if is_home else lineup_a
	for pid in lineup:
		if _slot_of(pid, is_home) == "TW":
			return players[pid]
	return players[lineup[0]]

const WIDE_POS := ["LV", "RV", "LM", "RM", "LA", "RA"]

## Teamwerte direkt aus den Spielerattributen – jedes Attribut wirkt:
## - Torwart: Reflexe, Strafraumbeherrschung, Beweglichkeit
## - Abwehr: Zweikampf, Stellungsspiel, Kraft, Kopfball, Konzentration
## - Mittelfeld: Passspiel, Übersicht, Technik, Einsatzbereitschaft (Pressing),
##   defensiv zusätzlich Aggressivität
## - Angriff: Abschluss, Tempo, Dribbling×Beweglichkeit, Technik, Nervenstärke
## - Außenbahnen: Flanken speisen Flankenangriffe (wide/header)
## - Team: Führungsqualität (Kapitänseffekt), Entschlossenheit (Aufholjagd),
##   Konzentration (Schlussphase der Abwehr)
func _ratings(lineup: Array, slots: Array, mentality: String, factor: float, trailing: bool, plan: Dictionary = {}) -> Dictionary:
	var gk := 0.0
	var gk_box := 45.0
	var gk_reflex := 45.0
	var gk_n := 0
	var defense := 0.0
	var def_n := 0
	var header := 0.0
	var header_n := 0
	var mid := 0.0
	var mid_def := 0.0
	var mf_att := 0.0
	var mid_n := 0
	var attack := 0.0
	var att_n := 0
	var wide := 0.0
	var wide_n := 0
	var best_leader := 0.0
	var ent_sum := 0.0
	var konz_sum := 0.0
	for i in lineup.size():
		var pid: int = lineup[i]
		var p: PlayerData = players[pid]
		# Bewertet wird der Spieler auf seinem FORMATIONS-SLOT: Ein Stürmer im
		# Abwehr-Slot verteidigt mit seinen (schwachen) Defensiv-Attributen und
		# zusätzlichem Vertrautheits-Abzug (fremde Laufwege).
		var slot: String = slots[i] if i < slots.size() else p.pos
		var fam := p.position_familiarity(slot)
		# Eigenschaften: Spielmacher heben das Mittelfeldspiel, Führungsspieler
		# verstärken den Kapitänseffekt
		if p.has_trait("Spielmacher") and PlayerData.GROUP_OF[slot] == "MF":
			fam *= 1.06
		best_leader = maxf(best_leader, float(p.attr("fuehrung")) + (12.0 if p.has_trait("Führungsspieler") else 0.0))
		ent_sum += p.attr("entschlossenheit")
		konz_sum += p.attr("konzentration")
		if slot in WIDE_POS:
			wide += _attr_val(pid, "flanken") * fam
			wide_n += 1
		match PlayerData.GROUP_OF[slot]:
			"TW":
				gk += (_attr_val(pid, "reflexe") * 0.55 + _attr_val(pid, "strafraum") * 0.25 + _attr_val(pid, "beweglichkeit") * 0.2) * fam
				gk_box = _attr_val(pid, "strafraum") * fam
				gk_reflex = _attr_val(pid, "reflexe") * fam
				gk_n += 1
			"AB":
				defense += (_attr_val(pid, "zweikampf") * 0.3 + _attr_val(pid, "stellung") * 0.25 + _attr_val(pid, "kraft") * 0.1 + _attr_val(pid, "kopfball") * 0.15 + _attr_val(pid, "konzentration") * 0.2) * fam
				def_n += 1
				header += _attr_val(pid, "kopfball") * 0.6 + _attr_val(pid, "sprung") * 0.4
				header_n += 1
			"MF":
				mid += (_attr_val(pid, "passen") * 0.3 + _attr_val(pid, "uebersicht") * 0.25 + _attr_val(pid, "technik") * 0.2 + _attr_val(pid, "einsatz") * 0.25) * fam
				mid_def += (_attr_val(pid, "zweikampf") * 0.45 + _attr_val(pid, "einsatz") * 0.25 + _attr_val(pid, "aggressivitaet") * 0.1 + _attr_val(pid, "stellung") * 0.2) * fam
				mf_att += (_attr_val(pid, "passen") * 0.35 + _attr_val(pid, "uebersicht") * 0.35 + _attr_val(pid, "technik") * 0.3) * fam
				mid_n += 1
			"ST":
				var dribble: float = _attr_val(pid, "dribbling") * 0.7 + _attr_val(pid, "beweglichkeit") * 0.3
				attack += (_attr_val(pid, "abschluss") * 0.3 + _attr_val(pid, "tempo") * 0.2 + dribble * 0.25 + _attr_val(pid, "technik") * 0.15 + _attr_val(pid, "nerven") * 0.1) * fam
				att_n += 1
				header += _attr_val(pid, "kopfball") * 0.6 + _attr_val(pid, "sprung") * 0.4
				header_n += 1
	var gk_avg := (gk / gk_n) if gk_n > 0 else 40.0
	var def_avg := (defense / def_n) if def_n > 0 else 45.0
	var mid_avg := (mid / mid_n) if mid_n > 0 else 45.0
	var mid_def_avg := (mid_def / mid_n) if mid_n > 0 else 45.0
	var mf_att_avg := (mf_att / mid_n) if mid_n > 0 else 45.0
	var att_avg := (attack / att_n) if att_n > 0 else mf_att_avg
	var wide_avg := (wide / wide_n) if wide_n > 0 else 40.0
	var header_avg := (header / header_n) if header_n > 0 else 45.0

	# Team-Effekte
	var lead_f := 1.0 + (best_leader - 55.0) * 0.0006          # Kapitänseffekt
	var det_f := 1.0
	if trailing:
		det_f = 1.0 + clampf(ent_sum / lineup.size() - 50.0, 0.0, 45.0) * 0.0008
	var late_def := 1.0
	if minute > 70:
		late_def = clampf(0.82 + (konz_sum / lineup.size()) * 0.003, 0.8, 1.1)

	var total_f := factor * lead_f * det_f
	var m: Dictionary = MENTALITIES[mentality]
	return {
		"att": (0.6 * att_avg + 0.25 * mf_att_avg + 0.15 * wide_avg) * m.att * total_f * float(plan.get("att", 1.0)),
		"mid": mid_avg * m.mid * total_f * float(plan.get("mid", 1.0)),
		"def": (0.5 * def_avg + 0.25 * gk_avg + 0.25 * mid_def_avg) * m.def * total_f * late_def * float(plan.get("def", 1.0)),
		"wide": wide_avg,
		"header": header_avg,
		"box": gk_box,
		"gk_reflex": gk_reflex,
	}

## Spieler auf dem Feld verlieren Frische – abhängig von Ausdauer und Spielweise.
func _drain_condition() -> void:
	for pid in lineup_h:
		cond[pid] = maxf(0.0, cond[pid] - _drain_rate(players[pid], mentality_h))
	for pid in lineup_a:
		cond[pid] = maxf(0.0, cond[pid] - _drain_rate(players[pid], mentality_a))

func _drain_rate(p: PlayerData, mentality: String) -> float:
	var m := 1.15 if mentality == "offensiv" else (0.9 if mentality == "defensiv" else 1.0)
	# Einsatzbereite Spieler ackern mehr – das kostet zusätzlich Frische
	var work := 0.92 + p.attr("einsatz") * 0.0016
	if p.has_trait("Dauerbrenner"):
		work *= 0.78
	return 0.55 * (1.6 - p.stamina / 100.0) * m * work

## Verletzungen: müde Spieler trifft es eher, robuste stecken mehr weg.
## Es folgt ein automatischer Zwangswechsel.
func _maybe_injury() -> void:
	if _rng.randf() >= 0.0062:
		return
	var is_home := _rng.randf() < 0.5
	var lineup: Array = lineup_h if is_home else lineup_a
	var off: Array = _off_h if is_home else _off_a
	var club: ClubData = home if is_home else away
	# Gewichtete Auswahl: geringe Frische und geringe Robustheit erhöhen das Risiko
	var total := 0.0
	var weights: Array = []
	for pid in lineup:
		var w: float = (1.5 - cond[pid] / 100.0) * (1.35 - players[pid].attr("robust") / 100.0)
		if players[pid].has_trait("Verletzungsanfällig"):
			w *= 1.5
		elif players[pid].has_trait("Eisenmann"):
			w *= 0.6
		total += w
		weights.append([pid, w])
	var roll := _rng.randf() * total
	var injured_pid: int = weights.back()[0]
	for entry in weights:
		roll -= entry[1]
		if roll <= 0.0:
			injured_pid = entry[0]
			break
	var p: PlayerData = players[injured_pid]
	# Robuste Spieler stecken den Schlag oft weg – die Verletzung bleibt aus
	var risk := clampf(1.35 - p.attr("robust") / 100.0, 0.3, 1.3)
	if p.has_trait("Verletzungsanfällig"):
		risk *= 1.35
	elif p.has_trait("Eisenmann"):
		risk *= 0.55
	if _rng.randf() > risk * 0.85:
		return
	p.injury_matchdays = _rng.randi_range(1, 5)
	_emit("injury", "%s (%s) verletzt sich und kann nicht weiterspielen! (Pause: %d Spieltage)" % [p.full_name(), club.short_name, p.injury_matchdays])
	var idx := lineup.find(injured_pid)
	off.append(injured_pid)
	# Zwangswechsel: bester fitter Ersatz, bevorzugt gleiche Positionsgruppe –
	# der Ersatzmann übernimmt den Formations-Slot des Verletzten
	if (subs_h if is_home else subs_a) < MAX_SUBS:
		var candidates := bench(is_home)
		var same_group := candidates.filter(func(pid): return players[pid].group() == p.group())
		var pool: Array = same_group if not same_group.is_empty() else candidates
		if not pool.is_empty():
			pool.sort_custom(func(a, b): return _player_effective(a) > _player_effective(b))
			var pid_in: int = pool[0]
			lineup[idx] = pid_in
			_appeared[pid_in] = true
			_subbed_in[pid_in] = true
			if is_home:
				subs_h += 1
			else:
				subs_a += 1
			_emit("sub", "Verletzungsbedingter Wechsel bei %s: %s kommt für %s." % [club.short_name, players[pid_in].full_name(), p.full_name()])
			return
	# Kein Wechsel mehr möglich: in Unterzahl weiter (Slot fällt mit weg)
	lineup.remove_at(idx)
	var slots: Array = slots_h if is_home else slots_a
	if idx < slots.size():
		slots.remove_at(idx)
	if is_home:
		red_h *= 0.88
	else:
		red_a *= 0.88
	_emit("info", "%s muss ohne Ersatz weiterspielen!" % club.short_name)

## Spielende: Formkurven anpassen, Frische zurückschreiben, Noten vergeben.
func _finalize() -> void:
	var delta_h := 0.0
	var delta_a := 0.0
	if hg > ag:
		delta_h = 0.03
		delta_a = -0.03
	elif hg < ag:
		delta_h = -0.03
		delta_a = 0.03
	for pid in lineup_h:
		var p: PlayerData = players[pid]
		p.form = clampf(p.form + delta_h + _rng.randf_range(-0.015, 0.015), 0.8, 1.2)
	for pid in lineup_a:
		var p: PlayerData = players[pid]
		p.form = clampf(p.form + delta_a + _rng.randf_range(-0.015, 0.015), 0.8, 1.2)
	# Frische, Noten und Einsatzstatistik für alle Eingesetzten
	for pid in _appeared:
		var p: PlayerData = players[pid]
		p.condition = cond[pid]
		var is_home_player := home.player_ids.has(pid)
		var result_adj := 0.0
		if hg != ag:
			result_adj = -0.4 if ((hg > ag) == is_home_player) else 0.4
		var day_adj: float = (1.0 - dayform[pid]) * 8.0   # guter Tag = bessere Note
		p.last_rating = clampf(3.5 + _note_adj.get(pid, 0.0) + result_adj + day_adj + _rng.randf_range(-0.4, 0.4), 1.0, 6.0)
		if not is_friendly:   # Testspiele zählen nicht für die Saisonstatistik
			p.matches_season += 1
			p.ratings_sum += p.last_rating
	# Positionslernen: Wer auf einer Nebenposition ausläuft, lernt sie dazu.
	for i in lineup_h.size():
		players[lineup_h[i]].learn_position(slots_h[i] if i < slots_h.size() else "", 0.014)
	for i in lineup_a.size():
		players[lineup_a[i]].learn_position(slots_a[i] if i < slots_a.size() else "", 0.014)

func _emit(kind: String, text: String) -> void:
	events.append({"min": maxi(minute, 1), "kind": kind, "text": text})
