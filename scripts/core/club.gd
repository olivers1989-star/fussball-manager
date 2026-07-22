class_name ClubData
extends RefCounted
## Ein Verein mit Kader, Finanzen, Stadion und Taktik.

## Formationen als konkrete Positions-Slots (11 pro Formation) – dienen als
## PRESETS; die tatsächliche Aufstellung ist frei positionierbar (lineup_spots).
const FORMATIONS := {
	"4-4-2": ["TW", "LV", "IV", "IV", "RV", "LM", "ZM", "ZM", "RM", "MS", "MS"],
	"4-4-2 (Raute)": ["TW", "LV", "IV", "IV", "RV", "DM", "ZM", "ZM", "OM", "MS", "MS"],
	"4-3-3": ["TW", "LV", "IV", "IV", "RV", "DM", "ZM", "OM", "LA", "MS", "RA"],
	"4-2-3-1": ["TW", "LV", "IV", "IV", "RV", "DM", "DM", "OM", "LA", "RA", "MS"],
	"4-5-1": ["TW", "LV", "IV", "IV", "RV", "LM", "DM", "ZM", "RM", "OM", "MS"],
	"3-5-2": ["TW", "IV", "IV", "IV", "LM", "DM", "ZM", "RM", "OM", "MS", "MS"],
	"5-3-2": ["TW", "LV", "IV", "IV", "IV", "RV", "DM", "ZM", "OM", "MS", "MS"],
	"4-4-1-1": ["TW", "LV", "IV", "IV", "RV", "LM", "ZM", "ZM", "RM", "OM", "MS"],
	"4-3-2-1": ["TW", "LV", "IV", "IV", "RV", "DM", "ZM", "ZM", "OM", "OM", "MS"],
	"4-1-3-2": ["TW", "LV", "IV", "IV", "RV", "DM", "LM", "ZM", "RM", "MS", "MS"],
	"4-1-4-1": ["TW", "LV", "IV", "IV", "RV", "DM", "LM", "ZM", "ZM", "RM", "MS"],
	"5-4-1": ["TW", "LV", "IV", "IV", "IV", "RV", "LM", "ZM", "ZM", "RM", "MS"],
	"3-4-3": ["TW", "IV", "IV", "IV", "LM", "ZM", "ZM", "RM", "LA", "MS", "RA"],
	"4-2-4": ["TW", "LV", "IV", "IV", "RV", "ZM", "ZM", "LA", "MS", "MS", "RA"],
}

## Feld-Koordinaten je Formations-Preset (x: 0=links..1=rechts, y: 0=eigenes Tor..1=vorne).
const FORMATION_SPOTS := {
	"4-4-2": [Vector2(0.5, 0.05), Vector2(0.14, 0.3), Vector2(0.38, 0.24), Vector2(0.62, 0.24), Vector2(0.86, 0.3), Vector2(0.14, 0.58), Vector2(0.38, 0.52), Vector2(0.62, 0.52), Vector2(0.86, 0.58), Vector2(0.38, 0.84), Vector2(0.62, 0.84)],
	"4-4-2 (Raute)": [Vector2(0.5, 0.05), Vector2(0.14, 0.3), Vector2(0.38, 0.24), Vector2(0.62, 0.24), Vector2(0.86, 0.3), Vector2(0.5, 0.42), Vector2(0.26, 0.56), Vector2(0.74, 0.56), Vector2(0.5, 0.68), Vector2(0.38, 0.86), Vector2(0.62, 0.86)],
	"4-3-3": [Vector2(0.5, 0.05), Vector2(0.14, 0.3), Vector2(0.38, 0.24), Vector2(0.62, 0.24), Vector2(0.86, 0.3), Vector2(0.5, 0.44), Vector2(0.32, 0.58), Vector2(0.68, 0.66), Vector2(0.14, 0.8), Vector2(0.5, 0.86), Vector2(0.86, 0.8)],
	"4-2-3-1": [Vector2(0.5, 0.05), Vector2(0.14, 0.3), Vector2(0.38, 0.24), Vector2(0.62, 0.24), Vector2(0.86, 0.3), Vector2(0.36, 0.46), Vector2(0.64, 0.46), Vector2(0.5, 0.66), Vector2(0.14, 0.8), Vector2(0.86, 0.8), Vector2(0.5, 0.86)],
	"4-5-1": [Vector2(0.5, 0.05), Vector2(0.14, 0.3), Vector2(0.38, 0.24), Vector2(0.62, 0.24), Vector2(0.86, 0.3), Vector2(0.12, 0.6), Vector2(0.34, 0.46), Vector2(0.66, 0.52), Vector2(0.88, 0.6), Vector2(0.5, 0.68), Vector2(0.5, 0.86)],
	"3-5-2": [Vector2(0.5, 0.05), Vector2(0.32, 0.24), Vector2(0.5, 0.2), Vector2(0.68, 0.24), Vector2(0.12, 0.58), Vector2(0.36, 0.46), Vector2(0.64, 0.55), Vector2(0.88, 0.58), Vector2(0.5, 0.68), Vector2(0.38, 0.86), Vector2(0.62, 0.86)],
	"5-3-2": [Vector2(0.5, 0.05), Vector2(0.12, 0.34), Vector2(0.3, 0.24), Vector2(0.5, 0.2), Vector2(0.7, 0.24), Vector2(0.88, 0.34), Vector2(0.36, 0.46), Vector2(0.64, 0.55), Vector2(0.5, 0.68), Vector2(0.38, 0.86), Vector2(0.62, 0.86)],
	"4-4-1-1": [Vector2(0.5, 0.05), Vector2(0.14, 0.3), Vector2(0.38, 0.24), Vector2(0.62, 0.24), Vector2(0.86, 0.3), Vector2(0.14, 0.56), Vector2(0.38, 0.54), Vector2(0.62, 0.54), Vector2(0.86, 0.56), Vector2(0.5, 0.7), Vector2(0.5, 0.88)],
	"4-3-2-1": [Vector2(0.5, 0.05), Vector2(0.14, 0.3), Vector2(0.38, 0.24), Vector2(0.62, 0.24), Vector2(0.86, 0.3), Vector2(0.5, 0.44), Vector2(0.36, 0.56), Vector2(0.64, 0.56), Vector2(0.38, 0.7), Vector2(0.62, 0.7), Vector2(0.5, 0.88)],
	"4-1-3-2": [Vector2(0.5, 0.05), Vector2(0.14, 0.3), Vector2(0.38, 0.24), Vector2(0.62, 0.24), Vector2(0.86, 0.3), Vector2(0.5, 0.44), Vector2(0.14, 0.58), Vector2(0.5, 0.58), Vector2(0.86, 0.58), Vector2(0.38, 0.85), Vector2(0.62, 0.85)],
	"4-1-4-1": [Vector2(0.5, 0.05), Vector2(0.14, 0.3), Vector2(0.38, 0.24), Vector2(0.62, 0.24), Vector2(0.86, 0.3), Vector2(0.5, 0.44), Vector2(0.13, 0.57), Vector2(0.38, 0.56), Vector2(0.62, 0.56), Vector2(0.87, 0.57), Vector2(0.5, 0.86)],
	"5-4-1": [Vector2(0.5, 0.05), Vector2(0.1, 0.33), Vector2(0.3, 0.24), Vector2(0.5, 0.2), Vector2(0.7, 0.24), Vector2(0.9, 0.33), Vector2(0.14, 0.56), Vector2(0.38, 0.54), Vector2(0.62, 0.54), Vector2(0.86, 0.56), Vector2(0.5, 0.86)],
	"3-4-3": [Vector2(0.5, 0.05), Vector2(0.32, 0.24), Vector2(0.5, 0.2), Vector2(0.68, 0.24), Vector2(0.12, 0.55), Vector2(0.38, 0.52), Vector2(0.62, 0.52), Vector2(0.88, 0.55), Vector2(0.16, 0.82), Vector2(0.5, 0.88), Vector2(0.84, 0.82)],
	"4-2-4": [Vector2(0.5, 0.05), Vector2(0.14, 0.3), Vector2(0.38, 0.24), Vector2(0.62, 0.24), Vector2(0.86, 0.3), Vector2(0.38, 0.54), Vector2(0.62, 0.54), Vector2(0.15, 0.83), Vector2(0.4, 0.88), Vector2(0.6, 0.88), Vector2(0.85, 0.83)],
}

## Zonen-Erkennung: übersetzt einen Punkt auf dem Feld in eine Position.
## Reihen (vom eigenen Tor aus): TW · LV/IV/RV · DM/ZM/OM (+LM/RM außen) · LA/MS/RA.
static func zone_position(spot: Vector2) -> String:
	var x := clampf(spot.x, 0.0, 1.0)
	var y := clampf(spot.y, 0.0, 1.0)
	if y < 0.13 and absf(x - 0.5) < 0.22:
		return "TW"
	if y < 0.38:   # Abwehrreihe
		if x < 0.28:
			return "LV"
		if x > 0.72:
			return "RV"
		return "IV"
	if y < 0.74:   # Mittelfeldreihe
		if x < 0.24:
			return "LM"
		if x > 0.76:
			return "RM"
		if y < 0.5:
			return "DM"
		if y < 0.63:
			return "ZM"
		return "OM"
	# Angriffsreihe
	if x < 0.28:
		return "LA"
	if x > 0.72:
		return "RA"
	return "MS"

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
var lineup: Array = []        # Spieler-IDs der Startelf
var lineup_spots: Array = []  # Feld-Koordinaten je Startelf-Index (frei positionierbar)
var bench: Array = []         # Spieler-IDs der Ersatzbank (max. BENCH_SIZE)
var player_ids: Array = []

## Die Positionen der aktuellen Aufstellung, aus den Feld-Koordinaten abgeleitet
## (Zonen-Erkennung). Fallback: die Slots des Formations-Presets.
func lineup_slots() -> Array:
	if lineup_spots.size() == lineup.size() and not lineup_spots.is_empty():
		var slots: Array = []
		for spot in lineup_spots:
			slots.append(zone_position(spot))
		return slots
	return FORMATIONS[formation].slice(0, lineup.size())

## Setzt ein Formations-Preset: Feldpunkte übernehmen, Spieler passend verteilen.
func apply_formation(name: String, all_players: Dictionary) -> void:
	formation = name
	lineup_spots = FORMATION_SPOTS[name].duplicate()
	if lineup.size() == 11:
		align_lineup(all_players)
	else:
		lineup = best_eleven(all_players)

## Anzeigename der aktuellen Ausrichtung, z. B. "4-4-2" oder "3-2-5".
func shape_label() -> String:
	var def := 0
	var mid := 0
	var att := 0
	for slot in lineup_slots():
		match PlayerData.GROUP_OF[slot]:
			"AB": def += 1
			"MF": mid += 1
			"ST": att += 1
	return "%d-%d-%d" % [def, mid, att]

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

## KI: Wählt die Formation, die zum VERFÜGBAREN Kader passt – jede Formation
## wird mit ihrer besten Elf bewertet (Stärke der Spieler auf ihren Slots).
## Ein kleiner Zufallsbonus sorgt für Vielfalt zwischen ähnlich guten Systemen.
func pick_best_formation(all_players: Dictionary) -> String:
	var scored: Array = []
	for name in FORMATIONS:
		var eleven := best_eleven(all_players, name)
		if eleven.size() < 11:
			continue
		var slots: Array = FORMATIONS[name]
		var score := 0.0
		for i in 11:
			var p: PlayerData = all_players[eleven[i]]
			score += p.strength_at(slots[i])
			# Trainer besetzen Positionen bevorzugt mit gelernten Spielern –
			# das hält Flügelsysteme im Rennen (LM/RM/LA/RA sind rar im Kader)
			if p.pos == slots[i]:
				score += 2.5
		scored.append([name, score])
	if scored.is_empty():
		return formation
	scored.sort_custom(func(a, b): return a[1] > b[1])
	# Nicht stur das Maximum: Trainer haben Vorlieben – gewichtete Wahl unter den Top 4
	var top := scored.slice(0, mini(4, scored.size()))
	var weights := [0.42, 0.28, 0.18, 0.12]
	var roll := randf()
	for i in top.size():
		roll -= weights[i]
		if roll <= 0.0:
			return top[i][0]
	return top[0][0]

## Sortiert eine vorhandene Startelf slot-treu um (z. B. nach dem Laden alter
## Spielstände oder einem Preset-Wechsel mit denselben Spielern). Nutzt die
## Zonen der aktuellen Feldpunkte, sonst die Slots des Formations-Presets.
func align_lineup(all_players: Dictionary) -> void:
	var slots: Array = lineup_slots()
	if lineup.size() != slots.size() or lineup.is_empty():
		return
	var pool: Array = []
	for pid in lineup:
		if all_players.has(pid):
			pool.append(all_players[pid])
	lineup = _fill_slots(slots, pool)

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
		"spots": lineup_spots.map(func(v): return [snappedf(v.x, 0.001), snappedf(v.y, 0.001)]),
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
	for spot in d.get("spots", []):
		c.lineup_spots.append(Vector2(float(spot[0]), float(spot[1])))
	# Ältere Spielstände ohne freie Positionen: Preset-Punkte der Formation
	if c.lineup_spots.size() != c.lineup.size() and c.lineup.size() == 11:
		c.lineup_spots = FORMATION_SPOTS.get(c.formation, FORMATION_SPOTS["4-4-2"]).duplicate()
	for pid in d.players:
		c.player_ids.append(int(pid))
	return c
