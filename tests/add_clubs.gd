extends Node
## Werkzeug (einmalig): Ergänzt data/clubs.json um die Dritte Liga (20 Vereine)
## und die nicht spielbare Regionalliga (20 Vereine). Bestehende Einträge
## bleiben unverändert – ihre Reihenfolge bestimmt die Vereins-IDs.

const LIGA3 := [
	["Alemannia Kaiser Aachen", "AAC", "Aachen", "Tivoli am Westwall", 32000, 56, "#f4c400", "Gregor Vaassen"],
	["VfL Hase Osnabrück", "OSN", "Osnabrück", "Bremer Brücke", 16000, 55, "#4b2e83", "Hilmar Bruns"],
	["FC Hansekogge Rostock", "ROS", "Rostock", "Ostseestadion", 29000, 55, "#0d3f8f", "Ernst Wollweber"],
	["FC Spreewald Cottbus", "COT", "Cottbus", "Stadion der Lausitz", 22000, 54, "#c8102e", "Ronny Zschoche"],
	["MSV Rheinhafen Duisburg", "MSV", "Duisburg", "Hafenarena", 31000, 54, "#005ca9", "Wilfried Terhorst"],
	["Rot-Weiss Zeche Essen", "RWE", "Essen", "Stadion an der Kokerei", 20000, 53, "#e2001a", "Bernd Kuhlmann"],
	["1. FC Saarknappen Saarbrücken", "SAA", "Saarbrücken", "Ludwigspark", 16000, 53, "#1c4ba0", "Dieter Ollinger"],
	["FC Schanzer Ingolstadt", "ING", "Ingolstadt", "Donauring", 15000, 52, "#e2001a", "Markus Feldbauer"],
	["SSV Donaustadt Ulm", "ULM", "Ulm", "Münsterblick-Arena", 17000, 52, "#00539f", "Anton Riedlinger"],
	["FC Erzberg Aue", "AUE", "Aue", "Erzgebirgskessel", 16000, 51, "#8b1a1a", "Steffen Rappold"],
	["SC Ostwestfalen Verl", "VER", "Verl", "Holzarena", 6000, 51, "#00843d", "Hartmut Kuhlmann"],
	["SV Kurpark Wiesbaden", "WIE", "Wiesbaden", "Taunusstein-Arena", 13000, 50, "#c8102e", "Ralf Hufnagel"],
	["SV Kurpfalz Mannheim", "MAN", "Mannheim", "Quadrate-Arena", 25000, 50, "#0057a3", "Jürgen Bissantz"],
	["SSV Donau Regensburg", "REG", "Regensburg", "Jahnstadion an der Donau", 15000, 49, "#e2001a", "Konrad Pfaffinger"],
	["SV Salinen Halle", "HAL", "Halle", "Saalebogen-Arena", 15000, 49, "#e2001a", "Frank Osterloh"],
	["FC Saale Jena", "JEN", "Jena", "Paradies-Arena", 13000, 48, "#003b7a", "Detlef Ilbrecht"],
	["FC Erzgebirge Chemnitz", "CHE", "Chemnitz", "Nickelhütte", 16000, 48, "#8ec3ea", "Uwe Neuhold"],
	["SV Emsland Meppen", "MEP", "Meppen", "Hänsch-Wiese", 14000, 47, "#00843d", "Heiner Rolfes"],
	["VfB Holstentor Lübeck", "LUE", "Lübeck", "Lohmühle", 12000, 47, "#00843d", "Claus Petersen"],
	["SpVgg Hachinger Tal", "HAC", "Unterhaching", "Sportpark im Hachinger Tal", 15000, 46, "#c8102e", "Sepp Wildmoser"],
]

const REGIONALLIGA := [
	["SC Weser Oldenburg", "OLD", "Oldenburg", "Marschweg-Stadion", 15000, 45, "#0057a3", "Eilert Janßen"],
	["SpVgg Markgrafen Bayreuth", "BAY", "Bayreuth", "Hans-Walter-Wild-Kampfbahn", 12000, 44, "#f4c400", "Roland Zeitler"],
	["VfR Härtsfeld Aalen", "AAL", "Aalen", "Ostalb-Arena", 14000, 44, "#c8102e", "Manfred Häussler"],
	["Kickers Bieberer Offenbach", "OFF", "Offenbach", "Bieberer Berg", 20000, 44, "#c8102e", "Waldemar Kling"],
	["SV Hardtwald Sandhausen", "SAN", "Sandhausen", "Hardtwaldstadion", 10000, 43, "#000000", "Jürgen Machmeier"],
	["FSV Muldental Zwickau", "ZWI", "Zwickau", "Muldental-Arena", 10000, 43, "#c8102e", "Tobias Leubner"],
	["BFC Nordost Berlin", "BFC", "Berlin", "Sportforum Hohenschönhausen", 12000, 42, "#8b1a1a", "Rainer Lisiewicz"],
	["FC Uni Greifswald", "GRW", "Greifswald", "Volksstadion am Bodden", 5000, 42, "#00843d", "Jörn Lubinus"],
	["SV Werrapark Fulda", "FUL", "Fulda", "Johannisau", 6000, 41, "#000000", "Alois Ziegler"],
	["FC Nordheide Lüneburg", "LUN", "Lüneburg", "Wilschenbruch", 5000, 41, "#0057a3", "Hauke Meinke"],
	["TSV Bergstraße Steinbach", "STE", "Steinbach", "Haiger-Arena", 4000, 41, "#f4c400", "Wilfried Ritter"],
	["SV Rheinaue Bonn", "BON", "Bonn", "Sportpark Nord", 12000, 40, "#0057a3", "Andreas Zenner"],
	["FC Kurhessen Kassel", "KAS", "Kassel", "Auestadion", 18000, 40, "#c8102e", "Volker Hasselbring"],
	["SC Lahntal Marburg", "MAR", "Marburg", "Georg-Gaßmann-Kampfbahn", 6000, 39, "#00843d", "Bernd Schuchardt"],
	["VfB Vogtland Plauen", "PLA", "Plauen", "Vogtlandstadion", 15000, 39, "#0057a3", "Karsten Gerber"],
	["SV Nordsee Wilhelmshaven", "WIL", "Wilhelmshaven", "Jadestadion", 7000, 38, "#000000", "Onno Freese"],
	["FC Grenzland Trier", "TRI", "Trier", "Moselstadion", 10000, 38, "#000000", "Peter Rauen"],
	["SV Moselwein Koblenz", "KOB", "Koblenz", "Stadion Oberwerth", 9000, 38, "#0057a3", "Hermann-Josef Klöckner"],
	["TSV Isartal Landshut", "LAN", "Landshut", "Sportpark Schönbrunn", 5000, 37, "#c8102e", "Sebastian Hartl"],
	["FC Bodensee Konstanz", "KON", "Konstanz", "Bodenseestadion", 6000, 37, "#f4c400", "Ulrich Bürgin"],
]

func _ready() -> void:
	print("=== VEREINE ERGÄNZEN ===")
	var f := FileAccess.open("res://data/clubs.json", FileAccess.READ)
	var clubs: Array = JSON.parse_string(f.get_as_text())
	f.close()
	print("Bestehend: %d Vereine" % clubs.size())

	var shorts := {}
	var names := {}
	for c in clubs:
		shorts[str(c.short)] = true
		names[str(c.name)] = true

	var added := 0
	for entry in LIGA3:
		added += _append(clubs, shorts, names, entry, 3)
	for entry in REGIONALLIGA:
		added += _append(clubs, shorts, names, entry, 4)

	var out := FileAccess.open("res://data/clubs.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(clubs, "\t"))
	out.close()
	var counts := {}
	for c in clubs:
		counts[int(c.league)] = counts.get(int(c.league), 0) + 1
	print("Ergänzt: %d Vereine – jetzt %d gesamt %s" % [added, clubs.size(), str(counts)])
	get_tree().quit(0)

func _append(clubs: Array, shorts: Dictionary, names: Dictionary, e: Array, league: int) -> int:
	if shorts.has(str(e[1])) or names.has(str(e[0])):
		print("Übersprungen (existiert bereits): %s" % str(e[0]))
		return 0
	clubs.append({
		"name": e[0], "short": e[1], "city": e[2], "stadium": e[3],
		"capacity": e[4], "strength": e[5], "league": league,
		"color": e[6], "chairman": e[7],
	})
	shorts[str(e[1])] = true
	names[str(e[0])] = true
	return 1
