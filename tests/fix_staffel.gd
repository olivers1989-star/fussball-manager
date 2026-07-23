extends Node
## Werkzeug (einmalig): Bringt die Regionalliga-Staffeln mit den Bundesländern
## in Einklang. Kassel (Hessen) gehört nach Südwest, nicht nach West – dafür
## wird der Südwest-Platz von Marburg zu einem Verein aus Nordrhein-Westfalen.

func _ready() -> void:
	print("=== STAFFELN KORRIGIEREN ===")
	var clubs: Array = JSON.parse_string(FileAccess.open("res://data/clubs.json", FileAccess.READ).get_as_text())
	for c in clubs:
		match str(c.short):
			"KAS":
				c.league = 7           # Kurhessen Kassel → Südwest (Hessen)
			"MAR":
				# Marburg (Hessen) weicht einem Verein aus dem Ruhrgebiet,
				# damit die West-Staffel wieder voll ist
				c.name = "SV Ruhrtal Witten"
				c.short = "WIN"
				c.city = "Witten"
				c.land = "NW"
				c.stadium = "Husemannstadion"
				c.league = 6
	var out := FileAccess.open("res://data/clubs.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(clubs, "\t"))
	out.close()

	var wrong := 0
	var counts := {}
	for c in clubs:
		var lid := int(c.league)
		counts[lid] = int(counts.get(lid, 0)) + 1
		if not Data.REGIONAL_LEAGUES.has(lid):
			continue
		if ClubData.staffel_for_land(str(c.land)) != lid:
			wrong += 1
			print("  Falsch: %s (%s) in Liga %d" % [c.name, c.land, lid])
	for lid in [1, 2, 3, 4, 5, 6, 7, 8]:
		print("  Liga %d: %d Vereine" % [lid, int(counts.get(lid, 0))])
	print("Fehlplatzierungen: %d" % wrong)
	assert(wrong == 0)
	get_tree().quit(0)
