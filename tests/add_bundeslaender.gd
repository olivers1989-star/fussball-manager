extends Node
## Werkzeug (einmalig): Gibt jedem Verein in data/clubs.json eine STABILE ID
## und sein Bundesland. Die ID bleibt beim Editieren erhalten – an ihr hängen
## später die Vereinslogos. Das Bundesland entscheidet, in welche
## Regionalliga-Staffel ein Verein absteigt.

## Stadt → Bundesland (Kürzel wie im Kfz-Kennzeichen-Schema).
const LAND_OF_CITY := {
	"Aachen": "NW", "Aalen": "BW", "Ansbach": "BY", "Aschaffenburg": "BY", "Aue": "SN",
	"Augsburg": "BY", "Bad Kreuznach": "RP", "Bad Neustadt": "BY", "Bad Schwartau": "SH",
	"Bamberg": "BY", "Bayreuth": "BY", "Bensheim": "HE", "Berlin": "BE", "Bernburg": "ST",
	"Bielefeld": "NW", "Bochum": "NW", "Bonn": "NW", "Braunschweig": "NI", "Bremen": "HB",
	"Bremerhaven": "HB", "Chemnitz": "SN", "Coesfeld": "NW", "Cottbus": "BB", "Cuxhaven": "NI",
	"Darmstadt": "HE", "Deggendorf": "BY", "Delmenhorst": "NI", "Dessau": "ST",
	"Donauwörth": "BY", "Dortmund": "NW", "Dresden": "SN", "Duisburg": "NW", "Düren": "NW",
	"Düsseldorf": "NW", "Eichstätt": "BY", "Elversberg": "SL", "Emden": "NI", "Essen": "NW",
	"Eutin": "SH", "Flensburg": "SH", "Frankfurt": "HE", "Frankfurt (Oder)": "BB",
	"Freiburg": "BW", "Fulda": "HE", "Fürth": "BY", "Garbsen": "NI", "Gelsenkirchen": "NW",
	"Gevelsberg": "NW", "Greifswald": "MV", "Grimma": "SN", "Halle": "ST", "Hamburg": "HH",
	"Hameln": "NI", "Hannover": "NI", "Heidenheim": "BW", "Herne": "NW", "Hof": "BY",
	"Hoyerswerda": "SN", "Ingolstadt": "BY", "Iserlohn": "NW", "Jena": "TH",
	"Kaiserslautern": "RP", "Karlsruhe": "BW", "Kassel": "HE", "Kempten": "BY", "Kiel": "SH",
	"Koblenz": "RP", "Konstanz": "BW", "Köln": "NW", "Landsberg": "BY", "Landshut": "BY",
	"Leipzig": "SN", "Leverkusen": "NW", "Lippstadt": "NW", "Lübeck": "SH", "Lüneburg": "NI",
	"Magdeburg": "ST", "Mainz": "RP", "Mannheim": "BW", "Marburg": "HE", "Meiningen": "TH",
	"Meppen": "NI", "Mönchengladbach": "NW", "München": "BY", "Münster": "NW",
	"Neuburg": "BY", "Nienburg": "NI", "Norderstedt": "SH", "Nordhausen": "TH",
	"Nördlingen": "BY", "Nürnberg": "BY", "Nürtingen": "BW", "Oberhausen": "NW",
	"Offenbach": "HE", "Oldenburg": "NI", "Osnabrück": "NI", "Paderborn": "NW",
	"Papenburg": "NI", "Passau": "BY", "Pirmasens": "RP", "Plauen": "SN", "Potsdam": "BB",
	"Regensburg": "BY", "Rendsburg": "SH", "Rheda-Wiedenbrück": "NW", "Rheine": "NW",
	"Rostock": "MV", "Rudolstadt": "TH", "Saarbrücken": "SL", "Sandhausen": "BW",
	"Schwedt": "BB", "Siegen": "NW", "Sinsheim": "BW", "Soest": "NW", "Solingen": "NW",
	"Soltau": "NI", "Steinbach": "HE", "Straelen": "NW", "Stralsund": "MV",
	"Stuttgart": "BW", "Taunusstein": "HE", "Torgau": "SN", "Traunstein": "BY",
	"Trier": "RP", "Ulm": "BW", "Unterhaching": "BY", "Velbert": "NW", "Verl": "NW",
	"Villingen": "BW", "Völklingen": "SL", "Walldorf": "BW", "Weiden": "BY",
	"Wiesbaden": "HE", "Wilhelmshaven": "NI", "Wittenberge": "BB", "Wolfsburg": "NI",
	"Wuppertal": "NW", "Zuzenhausen": "BW", "Zwickau": "SN",
}

func _ready() -> void:
	print("=== IDS UND BUNDESLÄNDER ===")
	var clubs: Array = JSON.parse_string(FileAccess.open("res://data/clubs.json", FileAccess.READ).get_as_text())
	var missing: Array = []
	var by_land := {}
	for i in clubs.size():
		var c: Dictionary = clubs[i]
		# Die ID entspricht der bisherigen Position – so bleiben alte Spielstände gültig
		if not c.has("id"):
			c["id"] = i + 1
		var city := str(c.city)
		if LAND_OF_CITY.has(city):
			c["land"] = str(LAND_OF_CITY[city])
		else:
			missing.append(city)
			c["land"] = ""
		by_land[str(c.land)] = int(by_land.get(str(c.land), 0)) + 1

	assert(missing.is_empty(), "Ohne Bundesland: %s" % ", ".join(missing))
	var out := FileAccess.open("res://data/clubs.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(clubs, "\t"))
	out.close()
	print("%d Vereine mit ID und Bundesland versehen" % clubs.size())
	var lands: Array = by_land.keys()
	lands.sort()
	for land in lands:
		print("  %s: %d" % [land, int(by_land[land])])

	# Gegenprobe: Passen die Regionalliga-Vereine schon zu ihrer Staffel?
	var wrong := 0
	for c in clubs:
		var lid := int(c.league)
		if not Data.REGIONAL_LEAGUES.has(lid):
			continue
		if ClubData.staffel_for_land(str(c.land)) != lid:
			wrong += 1
			print("  Falsche Staffel: %s (%s, %s) steht in Liga %d statt %d" % [
				c.name, c.city, c.land, lid, ClubData.staffel_for_land(str(c.land))])
	print("Regionalliga-Zuordnung: %d Vereine in der falschen Staffel" % wrong)
	get_tree().quit(0)
