class_name ClubData
extends RefCounted
## Ein Verein mit Kader, Finanzen, Stadion und Taktik.

const FORMATIONS := {
	"4-4-2": {"TW": 1, "AB": 4, "MF": 4, "ST": 2},
	"4-3-3": {"TW": 1, "AB": 4, "MF": 3, "ST": 3},
	"4-5-1": {"TW": 1, "AB": 4, "MF": 5, "ST": 1},
	"3-5-2": {"TW": 1, "AB": 3, "MF": 5, "ST": 2},
	"5-3-2": {"TW": 1, "AB": 5, "MF": 3, "ST": 2},
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

## Stellt die beste fitte Elf zusammen (Stärke × Form × Frische, keine Verletzten).
func best_eleven(all_players: Dictionary, p_formation: String = "") -> Array:
	var counts: Dictionary = FORMATIONS[p_formation if p_formation != "" else formation]
	var eleven: Array = []
	var used := {}
	for pos in PlayerData.POSITIONS:
		var pool := players_by_pos(all_players, pos).filter(func(p): return p.is_available())
		pool.sort_custom(func(a, b): return a.effective_rating() > b.effective_rating())
		var needed: int = counts[pos]
		for i in mini(needed, pool.size()):
			eleven.append(pool[i].id)
			used[pool[i].id] = true
	# Falls eine Position unterbesetzt ist: mit den besten fitten Restspielern auffüllen
	if eleven.size() < 11:
		var rest := players(all_players).filter(func(p): return not used.has(p.id) and p.is_available())
		rest.sort_custom(func(a, b): return a.effective_rating() > b.effective_rating())
		for p in rest:
			if eleven.size() >= 11:
				break
			eleven.append(p.id)
	return eleven

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
