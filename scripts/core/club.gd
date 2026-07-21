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
var formation: String = "4-4-2"
var lineup: Array = []        # Spieler-IDs der Startelf (wird v. a. für den eigenen Verein gepflegt)
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

## Stellt die beste fitte Elf für die Formations-Slots zusammen:
## erst exakte Position, dann gleiche Positionsgruppe, zuletzt beste Restspieler.
func best_eleven(all_players: Dictionary, p_formation: String = "") -> Array:
	var slots: Array = FORMATIONS[p_formation if p_formation != "" else formation]
	var available := players(all_players).filter(func(p): return p.is_available())
	available.sort_custom(func(a, b): return a.effective_rating() > b.effective_rating())
	var eleven: Array = []
	var used := {}
	var open_slots: Array = []
	# 1. Durchgang: exakte Position
	for slot in slots:
		var picked := _pick_for_slot(available, used, func(p): return p.pos == slot)
		if picked > 0:
			eleven.append(picked)
		else:
			open_slots.append(slot)
	# 2. Durchgang: gleiche Positionsgruppe
	var still_open: Array = []
	for slot in open_slots:
		var group: String = PlayerData.GROUP_OF[slot]
		var picked := _pick_for_slot(available, used, func(p): return p.group() == group)
		if picked > 0:
			eleven.append(picked)
		else:
			still_open.append(slot)
	# 3. Durchgang: beste Restspieler
	for slot in still_open:
		var picked := _pick_for_slot(available, used, func(_p): return true)
		if picked > 0:
			eleven.append(picked)
	return eleven

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

func salaries_per_month(all_players: Dictionary) -> int:
	var total := 0
	for p in players(all_players):
		total += p.salary
	return total

func salaries_per_matchday(all_players: Dictionary) -> int:
	# Saison = 34 Spieltage über ~12 Monate verteilt
	return int(salaries_per_month(all_players) * 12.0 / 34.0)

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
		"lineup": lineup, "players": player_ids,
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
	for pid in d.players:
		c.player_ids.append(int(pid))
	return c
