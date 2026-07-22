extends Node
## Kalender-Rhythmus und Tagesereignisse: realistische Tagesarten, keine
## Transferangebote mehr, echte Spielergespräche, austragbare Testspiele.

func _ready() -> void:
	Game.setup = {"name": "Kalendertester", "mode": "vereinsauswahl"}
	Game.new_game(2)
	var dates: Array = Game.world.matchday_dates
	var day := 86400

	# (1) Tagesarten rund um den ersten Spieltag
	var md0 := int(dates[0])
	assert(Game.day_kind(md0).kind == "matchday", "Spieltag muss erkannt werden")
	assert(Game.day_kind(md0 - day).kind == "prep", "Vortag muss Spielvorbereitung sein")
	assert(Game.day_kind(md0 + day).kind == "rest", "Tag nach dem Spiel muss Regeneration sein")

	# (2) Vor dem ersten Spieltag: Vorbereitung, davor Sommerpause – KEIN Training
	var pre := Game.day_kind(md0 - 10 * day)
	assert(pre.kind == "preseason", "Vor dem 1. Spieltag gehört zur Vorbereitung, war: %s" % pre.kind)
	var season_start := int(ScheduleGen.season_start(int(Game.world.season_year)))
	var before := Game.day_kind(season_start - 5 * day)
	assert(before.kind == "offseason", "Vor dem Saisonstart darf kein Training stehen, war: %s" % before.kind)
	print("Tagesarten OK: Spieltag/Vortag/Regeneration, Vorbereitung '%s', vor Start '%s'" % [pre.text, before.text])

	# (3) Winterpause zwischen den Spieltagen mit großer Lücke
	var winter_found := false
	for i in range(dates.size() - 1):
		if int(dates[i + 1]) - int(dates[i]) > 10 * day:
			var mid := int((int(dates[i]) + int(dates[i + 1])) / 2)
			assert(Game.day_kind(mid).kind == "winter", "Lange Lücke muss Winterpause sein")
			winter_found = true
			break
	assert(winter_found, "Der Spielplan muss eine Winterpause enthalten")
	print("Winterpause OK")

	# (4) Keine Transferangebote mehr in den Tagesereignissen
	var kinds := {}
	for i in 400:
		var r: Dictionary = Game.advance_day()
		if not r.decision.is_empty():
			kinds[str(r.decision.kind)] = true
			# Gespräche und Testspiele sofort auflösen, damit es weitergeht
			if str(r.decision.kind) == "player_talk":
				Game.resolve_talk(r.decision, 0)
			else:
				Game.resolve_decision(r.decision, 1)
		if Game.is_matchday_today():
			Game.play_matchday()
		if Game.season_over():
			break
	assert(not kinds.has("transfer_offer"), "Transferangebote dürfen nicht mehr auftreten")
	print("Ereignis-Arten über eine Saison: %s" % ", ".join(kinds.keys()))

	# (5) Spielergespräch: Inhalte und Antworten vorhanden, Antwort wirkt
	var squad := Game.my_club().players(Game.world.players)
	var p: PlayerData = squad[0]
	var talk := {"kind": "player_talk", "pid": p.id, "topic": "einsatzzeit"}
	var content := Game.talk_content(talk)
	assert(content.has("opening") and content.replies.size() >= 3, "Gespräch braucht Anliegen und mind. 3 Antworten")
	p.form = 1.0   # definierter Startwert, damit die Änderung nicht am Limit hängt
	var form_before := p.form
	var outcome := Game.resolve_talk(talk, 0)
	assert(outcome.has("text") and outcome.has("success"), "Gespräch muss ein Ergebnis liefern")
	assert(absf(p.form - form_before) > 0.0001, "Antwort muss die Form verändern")
	print("Gespräch OK: '%s' → %s (Form %+.3f)" % [str(content.replies[0].text).substr(0, 30), "positiv" if outcome.success else "schwierig", outcome.delta])
	for topic in Game.TALK_TOPICS:
		var c2: Dictionary = Game.TALK_TOPICS[topic]
		assert(c2.replies.size() >= 3, "Thema %s braucht mind. 3 Antworten" % topic)
	print("Alle %d Gesprächsthemen haben Antwortmöglichkeiten" % Game.TALK_TOPICS.size())

	# (6) Testspiel wird wirklich ausgetragen und verfälscht die Saison nicht
	var opponent_id := 5 if Game.my_club_id != 5 else 6
	var stats_before := {}
	for pid in Game.my_club().player_ids:
		var pl: PlayerData = Game.world.players[pid]
		stats_before[pid] = [pl.matches_season, pl.goals_season, pl.yellow_cards, pl.suspended_matchdays]
	var budget_before := Game.my_club().budget
	var result := Game.play_friendly(opponent_id)
	assert(result.has("hg") and result.has("ag"), "Testspiel muss ein Ergebnis liefern")
	assert(Game.my_club().budget > budget_before, "Testspiel muss Einnahmen bringen")
	for pid in stats_before:
		var pl: PlayerData = Game.world.players[pid]
		var b: Array = stats_before[pid]
		assert(pl.matches_season == b[0], "Testspiel darf keine Saison-Einsätze zählen")
		assert(pl.goals_season == b[1], "Testspiel-Tore dürfen nicht in die Saisonstatistik")
		assert(pl.yellow_cards == b[2], "Testspiel-Karten dürfen nicht zählen")
		assert(pl.suspended_matchdays == b[3], "Testspiel darf keine Sperren erzeugen")
	print("Testspiel OK: %s %d:%d %s (%d Tore protokolliert, Einnahmen %s)" % [
		Game.my_club().short_name, int(result.hg), int(result.ag), result.opponent.short_name,
		result.goals.size(), Fmt.money(int(result.fee))])

	print("=== KALENDER-EVENTS-TEST OK ===")
	get_tree().quit(0)
