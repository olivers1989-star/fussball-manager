extends Node
## Balance-Check: Wie stark korreliert die Teamstärke mit der Endplatzierung?
## Simuliert 5 Saisons und gibt die Tabelle der Ersten Liga mit Basisstärken aus.

func _ready() -> void:
	print("=== BALANCE-TEST (5 Saisons) ===")
	var rank_sum := {}   # club_name -> Platzsumme (nur Erste Liga, Saison 1)
	for season in 5:
		Game.setup = {"name": "Balancetester", "mode": "vereinsauswahl"}
		Game.new_game(1)
		for md in 34:
			Game.play_matchday()
		var table := Game.league(1).table()
		var line := "Saison %d: " % (season + 1)
		for i in table.size():
			var c := Game.club(table[i].club_id)
			if i < 3 or i >= 15:
				line += "%d. %s(St%d,%dP)  " % [i + 1, c.short_name, c.base_strength, table[i].points]
			var key: String = c.name
			rank_sum[key] = rank_sum.get(key, 0.0) + (i + 1)
		print(line)
	print("--- Durchschnittsplatzierung ---")
	var entries: Array = []
	for key in rank_sum:
		entries.append([key, rank_sum[key] / 5.0])
	entries.sort_custom(func(a, b): return a[1] < b[1])
	for e in entries:
		print("%5.1f  %s" % [e[1], e[0]])
	get_tree().quit(0)
