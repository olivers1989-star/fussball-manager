class_name LeagueData
extends RefCounted
## Eine Liga mit Vereinen, Spielplan und Tabellenberechnung.

var id: int = 1
var name: String = ""
var tier: int = 1
var club_ids: Array = []
var fixtures: Array = []   # Dictionaries: {round, home, away, played, hg, ag}

func rounds_total() -> int:
	return (club_ids.size() - 1) * 2

func fixtures_for_round(r: int) -> Array:
	return fixtures.filter(func(f): return int(f.round) == r)

func fixture_of(p_club_id: int, r: int) -> Dictionary:
	for f in fixtures:
		if int(f.round) == r and (int(f.home) == p_club_id or int(f.away) == p_club_id):
			return f
	return {}

func fixtures_of_club(p_club_id: int) -> Array:
	return fixtures.filter(func(f): return int(f.home) == p_club_id or int(f.away) == p_club_id)

## Tabelle als sortierte Liste von Zeilen-Dictionaries.
func table() -> Array:
	var rows := {}
	for cid in club_ids:
		rows[cid] = {
			"club_id": cid, "played": 0, "won": 0, "drawn": 0, "lost": 0,
			"gf": 0, "ga": 0, "points": 0,
		}
	for f in fixtures:
		if not f.played:
			continue
		var h: Dictionary = rows[int(f.home)]
		var a: Dictionary = rows[int(f.away)]
		h.played += 1
		a.played += 1
		h.gf += int(f.hg)
		h.ga += int(f.ag)
		a.gf += int(f.ag)
		a.ga += int(f.hg)
		if f.hg > f.ag:
			h.won += 1
			h.points += 3
			a.lost += 1
		elif f.hg < f.ag:
			a.won += 1
			a.points += 3
			h.lost += 1
		else:
			h.drawn += 1
			a.drawn += 1
			h.points += 1
			a.points += 1
	var arr: Array = rows.values()
	arr.sort_custom(_compare_rows)
	return arr

static func _compare_rows(x: Dictionary, y: Dictionary) -> bool:
	if x.points != y.points:
		return x.points > y.points
	var dx: int = x.gf - x.ga
	var dy: int = y.gf - y.ga
	if dx != dy:
		return dx > dy
	return x.gf > y.gf

func position_of(p_club_id: int) -> int:
	var t := table()
	for i in t.size():
		if t[i].club_id == p_club_id:
			return i + 1
	return 0

func to_dict() -> Dictionary:
	return {"id": id, "name": name, "tier": tier, "clubs": club_ids, "fixtures": fixtures}

static func from_dict(d: Dictionary) -> LeagueData:
	var l := LeagueData.new()
	l.id = int(d.id)
	l.name = d.name
	l.tier = int(d.tier)
	for cid in d.clubs:
		l.club_ids.append(int(cid))
	for f in d.fixtures:
		l.fixtures.append({
			"round": int(f.round), "home": int(f.home), "away": int(f.away),
			"played": bool(f.played), "hg": int(f.hg), "ag": int(f.ag),
		})
	return l
