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

## Saisonbeginn: 1. Juli. Eine Spielzeit läuft kalendarisch vom 1. Juli bis zum
## 30. Juni des Folgejahres – der Saisonwechsel liegt also im Sommer.
static func season_start(year: int) -> int:
	return int(Time.get_unix_time_from_datetime_dict({
		"year": year, "month": 7, "day": 1, "hour": 12, "minute": 0, "second": 0}))

## Letzter Tag der Spielzeit: 30. Juni des Folgejahres.
static func season_end(year: int) -> int:
	return season_start(year + 1) - 86400

## Die vier ENGLISCHEN WOCHEN: Positionen im Samstags-Raster (0-basiert), nach
## denen jeweils ein Dienstagstermin eingeschoben wird. Nur die 20er-Ligen
## (Dritte Liga, Regionalliga) spielen an diesen Terminen – sie brauchen 38
## Spieltage, die 18er-Ligen nur 34.
const MIDWEEK_AFTER := [3, 8, 22, 27]

## Alle Spieltagstermine einer Saison im gemeinsamen Kalender: 34 Samstage plus
## vier Dienstage. Hinrunde ab dem ersten August-Samstag – davor liegen rund
## fünf Wochen Sommervorbereitung. Rückrunde ab dem ersten Februar-Samstag,
## damit der letzte Spieltag Ende Mai fällt und der Juni frei bleibt.
static func matchday_dates(year: int) -> Array:
	var saturdays := _saturdays(year)
	var dates: Array = []
	for i in saturdays.size():
		dates.append(saturdays[i])
		if MIDWEEK_AFTER.has(i):
			dates.append(int(saturdays[i]) + 3 * 86400)   # Dienstag darauf
	return dates

## Die Slot-Nummern der Samstagstermine im Gesamtkalender – das Raster der
## 18er-Ligen.
static func saturday_slots() -> Array:
	var slots: Array = []
	var slot := 0
	for i in 34:
		slots.append(slot)
		slot += 2 if MIDWEEK_AFTER.has(i) else 1
	return slots

## Gesamtzahl der Spieltags-Termine einer Saison (34 Samstage + 4 Dienstage).
static func total_rounds() -> int:
	return 34 + MIDWEEK_AFTER.size()

static func _saturdays(year: int) -> Array:
	var dates: Array = []
	var t := int(Time.get_unix_time_from_datetime_dict({
		"year": year, "month": 8, "day": 1, "hour": 12, "minute": 0, "second": 0}))
	while Time.get_datetime_dict_from_unix_time(t).weekday != Time.WEEKDAY_SATURDAY:
		t += 86400
	for i in 17:
		dates.append(t + i * 7 * 86400)
	# Rückrunde: erster Samstag im Februar des Folgejahres
	var rt := int(Time.get_unix_time_from_datetime_dict({
		"year": year + 1, "month": 2, "day": 1, "hour": 12, "minute": 0, "second": 0}))
	while Time.get_datetime_dict_from_unix_time(rt).weekday != Time.WEEKDAY_SATURDAY:
		rt += 86400
	for i in 17:
		dates.append(rt + i * 7 * 86400)
	return dates

## Baut den Spielplan einer Liga und legt ihn auf das gemeinsame Spieltagsraster.
## 18er-Ligen bekommen die 34 Samstage, 20er-Ligen alle 38 Termine.
static func build_league_fixtures(club_ids: Array) -> Array:
	if club_ids.size() < 2:
		return []   # z. B. die Oberliga: Warteschlange ohne Spielbetrieb
	var fixtures := build_fixtures(club_ids)
	var rounds: int = (club_ids.size() - 1) * 2
	if rounds >= total_rounds():
		return fixtures
	var slots := saturday_slots()
	for f in fixtures:
		f.round = int(slots[int(f.round)]) if int(f.round) < slots.size() else int(f.round)
	return fixtures
