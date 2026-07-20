class_name ScheduleGen
extends RefCounted
## Erzeugt einen doppelten Round-Robin-Spielplan (Hin- und Rückrunde) nach Berger-Verfahren.

static func build_fixtures(club_ids: Array) -> Array:
	var teams := club_ids.duplicate()
	teams.shuffle()
	var n := teams.size()
	var half := n >> 1
	var fixed = teams[0]
	var rest := teams.slice(1)
	var first_leg: Array = []   # Array von Runden, jede Runde ist Array von [heim, gast]

	for r in n - 1:
		var line: Array = [fixed] + rest
		var pairs: Array = []
		for i in half:
			var a = line[i]
			var b = line[n - 1 - i]
			if r % 2 == 0:
				pairs.append([a, b])
			else:
				pairs.append([b, a])
		first_leg.append(pairs)
		rest = [rest.back()] + rest.slice(0, rest.size() - 1)

	var fixtures: Array = []
	for r in first_leg.size():
		for pair in first_leg[r]:
			fixtures.append(_fixture(r, pair[0], pair[1]))
	# Rückrunde: gleiche Paarungen mit getauschtem Heimrecht
	for r in first_leg.size():
		for pair in first_leg[r]:
			fixtures.append(_fixture(r + n - 1, pair[1], pair[0]))
	return fixtures

static func _fixture(p_round: int, p_home: int, p_away: int) -> Dictionary:
	return {"round": p_round, "home": p_home, "away": p_away, "played": false, "hg": 0, "ag": 0}
