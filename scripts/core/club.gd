class_name ClubData
extends RefCounted
## Ein Verein mit Kader, Finanzen, Stadion und Taktik.

## Formationen als konkrete Positions-Slots (11 pro Formation).
const FORMATIONS := {
	"4-4-2": ["TW", "LV", "IV", "IV", "RV", "LM", "ZM", "ZM", "RM", "MS", "MS"],
	"4-4-2 (Raute)": ["TW", "LV", "IV", "IV", "RV", "DM", "ZM", "ZM", "OM", "MS", "MS"],
	"4-3-3": ["TW", "LV", "IV", "IV", "RV", "DM", "ZM", "OM", "LA", "MS", "RA"],
	"4-2-3-1": ["TW", "LV", "IV", "IV", "RV", "DM", "DM", "OM", "LA", "RA", "MS"],
	"4-5-1": ["TW", "LV", "IV", "IV", "RV", "LM", "DM", "ZM", "RM", "OM", "MS"],
	"3-5-2": ["TW", "IV", "IV", "IV", "LM", "DM", "ZM", "RM", "OM", "MS", "MS"],
	"5-3-2": ["TW", "LV", "IV", "IV", "IV", "RV", "DM", "ZM", "OM", "MS", "MS"],
}

var id: int = 0
var name: String = ""
var short_name: String = ""
var city: String = ""
var stadium: String = ""
var capacity: int = 20000
var color: String = "#ffffff"
var base_strength: int = 60
var league_id: int = 1
var budget: int = 5000000
var sponsor_name: String = ""
var sponsor_per_md: int = 50000
var chairman: String = ""      # Vorstandsvorsitzender (fest je Verein, aus clubs.json)
## Bankgröße in Liga 1 und 2 (später über eine Ligen-Basis editierbar).
const BENCH_SIZE := 7

var formation: String = "4-4-2"
var lineup: Array = []        # Spieler-IDs der Startelf (slot-treu zur Formation)
var bench: Array = []         # Spieler-IDs der Ersatzbank (max. BENCH_SIZE)
var player_ids: Array = []

func players(all_players: Dictionary) -> Array:
	var result: Array = []
	for pid in player_ids:
		result.append(all_players[pid])
	return result

func players_by_pos(all_players: Dictionary, p_pos: String) -> Array:
	var result: Array = []
	for pid in player_ids:
		var p: PlayerData = all_players[pid]
		if p.pos == p_pos:
			result.append(p)
	result.sort_custom(func(a, b): return a.rating() > b.rating())
	return result

func players_by_group(all_players: Dictionary, p_group: String) -> Array:
	var result: Array = []
	for pid in player_ids:
		var p: PlayerData = all_players[pid]
		if p.group() == p_group:
			result.append(p)
	result.sort_custom(func(a, b): return a.rating() > b.rating())
	return result

## Stellt die beste fitte Elf für die Formations-Slots zusammen – SLOT-TREU:
## lineup[i] gehört zu FORMATIONS[formation][i]. Erst exakte Position,
## dann gleiche Positionsgruppe, zuletzt beste Restspieler.
func best_eleven(all_players: Dictionary, p_formation: String = "") -> Array:
	var slots: Array = FORMATIONS[p_formation if p_formation != "" else formation]
	var available := players(all_players).filter(func(p): return p.is_available())
	return _fill_slots(slots, available)

## Ordnet einen Spieler-Pool den Slots zu (3 Durchgänge), Ergebnis slot-treu.
func _fill_slots(slots: Array, pool: Array) -> Array:
	var sorted := pool.duplicate()
	sorted.sort_custom(func(a, b): return a.effective_rating() > b.effective_rating())
	var eleven: Array = []
	eleven.resize(slots.size())
	eleven.fill(-1)
	var used := {}
	# 1. Durchgang: exakte Position
	for i in slots.size():
		eleven[i] = _pick_for_slot(sorted, used, func(p): return p.pos == slots[i])
	# 2. Durchgang: gleiche Positionsgruppe
	for i in slots.size():
		if eleven[i] < 0:
			eleven[i] = _pick_for_slot(sorted, used, func(p): return p.group() == PlayerData.GROUP_OF[slots[i]])
	# 3. Durchgang: beste Restspieler
	for i in slots.size():
		if eleven[i] < 0:
			eleven[i] = _pick_for_slot(sorted, used, func(_p): return true)
	return eleven.filter(func(pid): return pid > 0)

## Sortiert eine vorhandene Startelf slot-treu um (z. B. nach dem Laden alter
## Spielstände oder einem Formationswechsel mit denselben Spielern).
func align_lineup(all_players: Dictionary) -> void:
	if lineup.size() != FORMATIONS[formation].size():
		return
	var pool: Array = []
	for pid in lineup:
		if all_players.has(pid):
			pool.append(all_players[pid])
	lineup = _fill_slots(FORMATIONS[formation], pool)

func _pick_for_slot(available: Array, used: Dictionary, predicate: Callable) -> int:
	for p in available:
		if not used.has(p.id) and predicate.call(p):
			used[p.id] = true
			return p.id
	return -1

## Gültige Startelf für ein Spiel: gespeicherte Aufstellung (sofern komplett und fit),
## sonst automatisch die beste Elf.
func match_lineup(all_players: Dictionary) -> Array:
	if lineup.size() == 11:
		var valid := true
		for pid in lineup:
			if not player_ids.has(pid) or not all_players[pid].is_available():
				valid = false
				break
		if valid:
			return lineup
	return best_eleven(all_players)

## Beste Ersatzbank: Ersatztorwart zuerst (falls vorhanden), dann die stärksten
## fitten Restspieler bis BENCH_SIZE.
func best_bench(all_players: Dictionary, the_lineup: Array) -> Array:
	var rest := players(all_players).filter(func(p): return p.is_available() and not the_lineup.has(p.id))
	rest.sort_custom(func(a, b): return a.effective_rating() > b.effective_rating())
	var result: Array = []
	for p in rest:
		if p.group() == "TW":
			result.append(p.id)
			break
	for p in rest:
		if result.size() >= BENCH_SIZE:
			break
		if not result.has(p.id):
			result.append(p.id)
	return result

## Gültige Bank für ein Spiel: gespeicherte Bank (bereinigt um Unfitte/Aufgestellte),
## bei leerer Bank automatisch die beste.
func match_bench(all_players: Dictionary, the_lineup: Array) -> Array:
	var valid := bench.filter(func(pid):
		return player_ids.has(pid) and not the_lineup.has(pid) and all_players[pid].is_available())
	if valid.is_empty():
		return best_bench(all_players, the_lineup)
	return valid.slice(0, BENCH_SIZE)

func salaries_per_month(all_players: Dictionary) -> int:
	var total := 0
	for p in players(all_players):
		total += p.salary
	return total

func salaries_per_matchday(all_players: Dictionary) -> int:
	# Saison = 34 Spieltage über ~12 Monate verteilt
	return int(salaries_per_month(all_players) * 12.0 / 34.0)

func ticket_price() -> int:
	return 35 if league_id == 1 else 20

## Erwartete Stadionauslastung (ohne Tagesschwankung).
func expected_fill() -> float:
	return clampf(0.55 + (base_strength - 55) * 0.008, 0.3, 1.0)

## Sponsor- und TV-Gelder pro Spieltag, abgeleitet vom tatsächlichen Gehaltsetat:
## Einnahmen decken die Gehälter plus ~10 % Spielraum, abzüglich der erwarteten
## Ticketeinnahmen. Große Kader = große Vermarktung – skaliert automatisch mit.
func refresh_sponsor(all_players: Dictionary) -> void:
	var ticket_avg := int(capacity * expected_fill() * ticket_price() / 2.0)
	sponsor_per_md = maxi(int(salaries_per_matchday(all_players) * 1.1) - ticket_avg, 25000)

## Gesamtstärke des Vereins: Durchschnitt über ALLE Kaderspieler
## (nicht nur die aktuelle Spieltagself).
func overall_strength(all_players: Dictionary) -> float:
	if player_ids.is_empty():
		return 0.0
	var total := 0.0
	for pid in player_ids:
		total += all_players[pid].strength
	return total / player_ids.size()

func squad_strength(all_players: Dictionary) -> float:
	var eleven := match_lineup(all_players)
	if eleven.is_empty():
		return 0.0
	var total := 0.0
	for pid in eleven:
		total += all_players[pid].rating()
	return total / eleven.size()

func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "short": short_name, "city": city,
		"stadium": stadium, "cap": capacity, "color": color, "base": base_strength,
		"league": league_id, "budget": budget, "sponsor": sponsor_name,
		"sponsor_md": sponsor_per_md, "chairman": chairman, "formation": formation,
		"lineup": lineup, "bench": bench, "players": player_ids,
	}

static func from_dict(d: Dictionary) -> ClubData:
	var c := ClubData.new()
	c.id = int(d.id)
	c.name = d.name
	c.short_name = d.short
	c.city = d.city
	c.stadium = d.stadium
	c.capacity = int(d.cap)
	c.color = d.color
	c.base_strength = int(d.base)
	c.league_id = int(d.league)
	c.budget = int(d.budget)
	c.sponsor_name = d.sponsor
	c.sponsor_per_md = int(d.sponsor_md)
	c.chairman = d.get("chairman", "")
	c.formation = d.formation
	for pid in d.lineup:
		c.lineup.append(int(pid))
	for pid in d.get("bench", []):
		c.bench.append(int(pid))
	for pid in d.players:
		c.player_ids.append(int(pid))
	return c
