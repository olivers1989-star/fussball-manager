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
var mentality_h := "ausgewogen"
var mentality_a := "ausgewogen"
var factor_h := 1.0         # externe Boni (z. B. Trainer-Fähigkeit "Taktik")
var factor_a := 1.0
var red_h := 1.0            # Malus nach Platzverweis
var red_a := 1.0
var subs_h := 0
var subs_a := 0
var ai_h := true            # true = KI steuert die Spielweise dieser Seite
var ai_a := true

var cond := {}              # pid -> aktuelle Frische im Spiel (sinkt Minute für Minute)
var dayform := {}           # pid -> Tagesform 0.94..1.06 (jeden Spieltag neu ausgewürfelt)

var _off_h: Array = []      # Ausgewechselte dürfen nicht zurück aufs Feld
var _off_a: Array = []
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

	_ai_adjust()
	_drain_condition()
	_maybe_injury()

	var rat_h := _ratings(lineup_h, mentality_h, factor_h * red_h)
	var rat_a := _ratings(lineup_a, mentality_a, factor_a * red_a)

	var mid_sum: float = rat_h.mid + rat_a.mid
	var p_home: float = CHANCE_BASE * (2.0 * rat_h.mid / mid_sum) * HOME_BONUS
	var p_away: float = CHANCE_BASE * (2.0 * rat_a.mid / mid_sum) * (2.0 - HOME_BONUS)

	if _rng.randf() < p_home:
		_chance(true, rat_h.att, rat_a.def)
	elif _rng.randf() < p_away:
		_chance(false, rat_a.att, rat_h.def)

	_maybe_card()

	if minute >= 90:
		_emit("info", "Abpfiff! Endstand: %d:%d." % [hg, ag])
		finished = true
		_finalize()

## Spult das Spiel ohne Eingriffe bis zum Abpfiff durch (KI-Spiele, Schnellsimulation).
func run_full() -> void:
	while not finished:
		tick()

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
	var p_out: PlayerData = players[pid_out]
	var p_in: PlayerData = players[pid_in]
	if not p_in.is_available():
		return "%s ist nicht einsatzbereit (verletzt oder gesperrt)." % p_in.full_name()
	if p_out.pos != p_in.pos:
		return "Wechsel nur auf gleicher Position möglich (%s gegen %s)." % [p_out.pos, p_in.pos]
	lineup[lineup.find(pid_out)] = pid_in
	off.append(pid_out)
	_appeared[pid_in] = true
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

func bench(is_home: bool) -> Array:
	var lineup: Array = lineup_h if is_home else lineup_a
	var off: Array = _off_h if is_home else _off_a
	var club: ClubData = home if is_home else away
	return club.player_ids.filter(func(pid):
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

func _chance(for_home: bool, att: float, def: float) -> void:
	var lineup: Array = lineup_h if for_home else lineup_a
	var club: ClubData = home if for_home else away
	var conversion: float = clampf(0.30 * pow(att / def, 1.4), 0.06, 0.65)
	var scorer := _pick_scorer(lineup)
	if _rng.randf() < conversion:
		scorer.goals_season += 1
		_note_adj[scorer.id] = _note_adj.get(scorer.id, 0.0) - 0.7
		if for_home:
			hg += 1
			_emit("goal_home", "TOR für %s! %s trifft zum %d:%d." % [club.name, scorer.full_name(), hg, ag])
		else:
			ag += 1
			_emit("goal_away", "TOR für %s! %s trifft zum %d:%d." % [club.name, scorer.full_name(), hg, ag])
	elif _rng.randf() < 0.45:
		_emit("chance", "Großchance für %s – %s scheitert!" % [club.name, scorer.full_name()])

func _maybe_card() -> void:
	if _rng.randf() >= 0.014:
		return
	var card_home := _rng.randf() < 0.5
	var lineup: Array = lineup_h if card_home else lineup_a
	var off: Array = _off_h if card_home else _off_a
	var club: ClubData = home if card_home else away
	var p: PlayerData = players[lineup[_rng.randi_range(1, lineup.size() - 1)]]
	if _rng.randf() < 0.06:
		p.red_cards += 1
		p.suspended_matchdays += 2
		_note_adj[p.id] = _note_adj.get(p.id, 0.0) + 1.2
		_emit("red", "ROTE KARTE! %s (%s) muss vom Platz und ist für 2 Spieltage gesperrt!" % [p.full_name(), club.short_name])
		lineup.erase(p.id)
		off.append(p.id)
		if card_home:
			red_h *= 0.86
		else:
			red_a *= 0.86
	else:
		p.yellow_cards += 1
		_note_adj[p.id] = _note_adj.get(p.id, 0.0) + 0.2
		if p.yellow_cards % 5 == 0:
			p.suspended_matchdays += 1
			_emit("card", "Gelbe Karte für %s (%s) – seine %d. der Saison, er ist damit einen Spieltag gesperrt!" % [p.full_name(), club.short_name, p.yellow_cards])
		else:
			_emit("card", "Gelbe Karte für %s (%s)." % [p.full_name(), club.short_name])

func _pick_scorer(lineup: Array) -> PlayerData:
	var weights := {"TW": 0.05, "AB": 1.0, "MF": 3.0, "ST": 7.0}
	var total := 0.0
	var pool: Array = []
	for pid in lineup:
		var p: PlayerData = players[pid]
		var w: float = weights[p.pos] * (p.strength / 60.0)
		total += w
		pool.append([p, w])
	var roll := _rng.randf() * total
	for entry in pool:
		roll -= entry[1]
		if roll <= 0.0:
			return entry[0]
	return pool.back()[0]

## Leistung eines Spielers in dieser Minute: Stärke × Form × Tagesform × Frische.
func _player_effective(pid: int) -> float:
	var p: PlayerData = players[pid]
	return p.rating() * dayform[pid] * (0.72 + 0.28 * cond[pid] / 100.0)

func _ratings(lineup: Array, mentality: String, factor: float) -> Dictionary:
	var sums := {"TW": 0.0, "AB": 0.0, "MF": 0.0, "ST": 0.0}
	var counts := {"TW": 0, "AB": 0, "MF": 0, "ST": 0}
	for pid in lineup:
		var p: PlayerData = players[pid]
		sums[p.pos] += _player_effective(pid)
		counts[p.pos] += 1
	var avg := {}
	for pos in sums:
		avg[pos] = (sums[pos] / counts[pos]) if counts[pos] > 0 else 45.0
	var m: Dictionary = MENTALITIES[mentality]
	return {
		"att": (0.7 * avg.ST + 0.3 * avg.MF) * m.att * factor,
		"mid": avg.MF * m.mid * factor,
		"def": (0.55 * avg.AB + 0.25 * avg.TW + 0.2 * avg.MF) * m.def * factor,
	}

## Spieler auf dem Feld verlieren Frische – abhängig von Ausdauer und Spielweise.
func _drain_condition() -> void:
	for pid in lineup_h:
		cond[pid] = maxf(0.0, cond[pid] - _drain_rate(players[pid], mentality_h))
	for pid in lineup_a:
		cond[pid] = maxf(0.0, cond[pid] - _drain_rate(players[pid], mentality_a))

func _drain_rate(p: PlayerData, mentality: String) -> float:
	var m := 1.15 if mentality == "offensiv" else (0.9 if mentality == "defensiv" else 1.0)
	return 0.55 * (1.6 - p.stamina / 100.0) * m

## Verletzungen: müde Spieler trifft es eher. Es folgt ein automatischer Zwangswechsel.
func _maybe_injury() -> void:
	if _rng.randf() >= 0.0045:
		return
	var is_home := _rng.randf() < 0.5
	var lineup: Array = lineup_h if is_home else lineup_a
	var off: Array = _off_h if is_home else _off_a
	var club: ClubData = home if is_home else away
	# Gewichtete Auswahl: geringe Frische erhöht das Risiko
	var total := 0.0
	var weights: Array = []
	for pid in lineup:
		var w: float = 1.5 - cond[pid] / 100.0
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
	p.injury_matchdays = _rng.randi_range(1, 5)
	_emit("injury", "%s (%s) verletzt sich und kann nicht weiterspielen! (Pause: %d Spieltage)" % [p.full_name(), club.short_name, p.injury_matchdays])
	lineup.erase(injured_pid)
	off.append(injured_pid)
	# Zwangswechsel: bester fitter Ersatz, bevorzugt gleiche Position
	if (subs_h if is_home else subs_a) < MAX_SUBS:
		var candidates := bench(is_home)
		var same_pos := candidates.filter(func(pid): return players[pid].pos == p.pos)
		var pool: Array = same_pos if not same_pos.is_empty() else candidates
		if not pool.is_empty():
			pool.sort_custom(func(a, b): return _player_effective(a) > _player_effective(b))
			var pid_in: int = pool[0]
			lineup.append(pid_in)
			_appeared[pid_in] = true
			if is_home:
				subs_h += 1
			else:
				subs_a += 1
			_emit("sub", "Verletzungsbedingter Wechsel bei %s: %s kommt für %s." % [club.short_name, players[pid_in].full_name(), p.full_name()])
			return
	# Kein Wechsel mehr möglich: in Unterzahl weiter
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
	# Frische & Noten für alle Eingesetzten
	for pid in _appeared:
		var p: PlayerData = players[pid]
		p.condition = cond[pid]
		var is_home_player := home.player_ids.has(pid)
		var result_adj := 0.0
		if hg != ag:
			result_adj = -0.4 if ((hg > ag) == is_home_player) else 0.4
		var day_adj: float = (1.0 - dayform[pid]) * 8.0   # guter Tag = bessere Note
		p.last_rating = clampf(3.5 + _note_adj.get(pid, 0.0) + result_adj + day_adj + _rng.randf_range(-0.4, 0.4), 1.0, 6.0)

func _emit(kind: String, text: String) -> void:
	events.append({"min": maxi(minute, 1), "kind": kind, "text": text})
