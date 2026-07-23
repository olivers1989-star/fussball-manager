extends Node
## Werkzeug (einmalig): Baut die Regionalliga auf FÜNF STAFFELN mit je 18
## Vereinen aus (Liga-IDs 4–8, wie in der Realität Nord/Nordost/West/Südwest/
## Bayern). Die 20 bisherigen Regionalliga-Vereine werden ihrer Region
## zugeordnet, der Rest kommt neu dazu. Bestehende Einträge bleiben unberührt.

const STAFFELN := {
	4: "Nord", 5: "Nordost", 6: "West", 7: "Südwest", 8: "Bayern",
}

## Zuordnung der schon vorhandenen Regionalliga-Vereine zu ihrer Staffel.
const EXISTING := {
	"OLD": 4, "LUN": 4, "WIL": 4,
	"BAY": 8, "LAN": 8,
	"AAL": 7, "OFF": 7, "SAN": 7, "FUL": 7, "STE": 7, "TRI": 7, "KOB": 7, "KON": 7, "MAR": 7,
	"ZWI": 5, "BFC": 5, "GRW": 5, "PLA": 5,
	"BON": 6, "KAS": 6,
}

## Neue Vereine je Staffel: Name, Kürzel, Stadt, Stadion, Kapazität, Stärke, Farbe, Vorsitzender
const NEW_CLUBS := {
	4: [
		["Eintracht Geest Norderstedt", "NOR", "Norderstedt", "Ochsenzoll-Arena", 4000, 40, "#c8102e", "Jens Petersen"],
		["TSV Elbmarsch Havelse", "HAV", "Garbsen", "Wilhelm-Langrehr-Platz", 3500, 40, "#00843d", "Dirk Lange"],
		["SC Weserbergland Hameln", "HAM", "Hameln", "Weserstadion am Wall", 5000, 39, "#0057a3", "Uwe Rätzel"],
		["FC Störtebeker Cuxhaven", "CUX", "Cuxhaven", "Nordseekampfbahn", 4000, 38, "#000000", "Focke Hagena"],
		["VfL Heidekreis Soltau", "SOL", "Soltau", "Heidepark-Sportplatz", 3000, 38, "#f4c400", "Heiko Bostelmann"],
		["SV Kanaltal Rendsburg", "REN", "Rendsburg", "Kanalstadion", 3500, 37, "#0057a3", "Sönke Thomsen"],
		["TuS Hafenstraße Bremerhaven", "BRV", "Bremerhaven", "Nordseestadion", 6000, 37, "#c8102e", "Gerd Ahlers"],
		["SC Moorland Delmenhorst", "DEL", "Delmenhorst", "Düsternortstadion", 5000, 36, "#00843d", "Bernd Rohlfs"],
		["FC Hansaring Lübeck II", "LBK", "Bad Schwartau", "Ostsee-Sportpark", 2500, 36, "#000000", "Malte Ohlsen"],
		["SV Ostfriesland Emden", "EMD", "Emden", "Embdena-Stadion", 7000, 36, "#0057a3", "Ubbo Focken"],
		["TSV Alstertal Hamburg", "ALS", "Hamburg", "Alsterpark-Arena", 3000, 35, "#c8102e", "Torben Krüger"],
		["SV Heidmoor Eutin", "EUT", "Eutin", "Kellersee-Kampfbahn", 2500, 35, "#f4c400", "Nils Ratjen"],
		["FC Weserdeich Nienburg", "NIE", "Nienburg", "Deichstadion", 3000, 34, "#00843d", "Frank Schierhorn"],
		["SpVgg Papenburg Ems", "PAP", "Papenburg", "Werftarena", 3000, 34, "#0057a3", "Josef Tebbe"],
		["SV Nordmark Flensburg", "FLE", "Flensburg", "Manfred-Werner-Stadion", 5000, 33, "#c8102e", "Sönke Jessen"],
	],
	5: [
		["FC Elbaue Torgau", "TOR", "Torgau", "Elbufer-Sportpark", 3000, 40, "#c8102e", "Ronny Steinbach"],
		["SV Oderbruch Frankfurt", "ODE", "Frankfurt (Oder)", "Stadion der Freundschaft", 6000, 40, "#0057a3", "Heiko Zeidler"],
		["FSV Harzquell Nordhausen", "NDH", "Nordhausen", "Albert-Kuntz-Kampfbahn", 6000, 39, "#f4c400", "Uwe Rennert"],
		["SV Havelland Babelsberg", "BAB", "Potsdam", "Karl-Liebknecht-Platz", 10000, 39, "#00843d", "Archibald Horlitz"],
		["FC Spreeathen Berlin", "SPB", "Berlin", "Poststadion", 8000, 38, "#8b1a1a", "Karsten Prüfer"],
		["SV Salzland Bernburg", "BER", "Bernburg", "Saalestadion", 4000, 38, "#0057a3", "Detlef Ihle"],
		["FC Lausitz Hoyerswerda", "HOY", "Hoyerswerda", "Lausitzhalle-Arena", 4000, 37, "#c8102e", "Ralf Naumann"],
		["SV Werrabogen Meiningen", "MEI", "Meiningen", "Maßfelder Weg", 3000, 37, "#00843d", "Steffen Amthor"],
		["FC Anhalt Dessau", "DES", "Dessau", "Paul-Greifzu-Stadion", 8000, 36, "#f4c400", "Lutz Schlingmann"],
		["SV Ostseewelle Stralsund", "STR", "Stralsund", "Kupfermühle", 5000, 36, "#0057a3", "Jens Voigtländer"],
		["FC Schwarza Rudolstadt", "RUD", "Rudolstadt", "Kalkstein-Arena", 3000, 35, "#8b1a1a", "Andreas Köhler"],
		["SV Prignitz Wittenberge", "WIT", "Wittenberge", "Elbufer-Kampfbahn", 3000, 35, "#00843d", "Torsten Peters"],
		["FC Muldeaue Grimma", "GRI", "Grimma", "Muldental-Sportpark", 2500, 34, "#c8102e", "Sven Böttcher"],
		["SV Uckermark Schwedt", "SDT", "Schwedt", "Oderbruch-Arena", 4000, 34, "#0057a3", "Mario Kliem"],
	],
	6: [
		["SC Rheinbogen Wuppertal", "WUP", "Wuppertal", "Zoostadion", 22000, 41, "#c8102e", "Friedhelm Runge"],
		["SV Halden Herne", "HER", "Herne", "Emscherstadion", 8000, 40, "#0057a3", "Heinz-Werner Boms"],
		["FC Kohlenpott Oberhausen", "OBE", "Oberhausen", "Niederrhein-Kampfbahn", 21000, 40, "#c8102e", "Hajo Sommers"],
		["SV Ruhrhöhen Velbert", "VEL", "Velbert", "Sonnenblume", 4000, 39, "#000000", "Dirk Rosenbaum"],
		["SC Niederrhein Straelen", "STL", "Straelen", "Römerstadion", 3000, 38, "#00843d", "Hermann Tecklenburg"],
		["FC Lippeaue Lippstadt", "LIP", "Lippstadt", "Stadion am Bruchbaum", 4000, 38, "#0057a3", "Bernhard Wulf"],
		["SV Bergland Wiedenbrück", "WDB", "Rheda-Wiedenbrück", "Jahnstadion an der Ems", 3000, 37, "#00843d", "Ludger Beckmann"],
		["FC Siegtal Siegen", "SIE", "Siegen", "Leimbachstadion", 18000, 37, "#c8102e", "Gerd Schneider"],
		["SV Rurtal Düren", "DUE", "Düren", "Westkampfbahn", 6000, 36, "#f4c400", "Hans-Peter Braun"],
		["FC Ennepetal Gevelsberg", "ENN", "Gevelsberg", "Stefansbachtal", 3000, 36, "#0057a3", "Michael Höhle"],
		["SV Sauerland Iserlohn", "ISE", "Iserlohn", "Hemberg-Arena", 5000, 35, "#00843d", "Klaus Ostrop"],
		["FC Baumberge Coesfeld", "COE", "Coesfeld", "Sportzentrum Süd", 2500, 35, "#c8102e", "Anton Nienhaus"],
		["SC Wupperaue Solingen", "SOG", "Solingen", "Jahnkampfbahn", 4000, 34, "#000000", "Rüdiger Weiss"],
		["FC Ems-Vechte Rheine", "RHE", "Rheine", "Jahnstadion an der Ems", 5000, 34, "#0057a3", "Werner Terhalle"],
		["SV Möhnesee Soest", "SOE", "Soest", "Alter Schlachthof", 3000, 33, "#00843d", "Ulrich Kortmann"],
		["FC Baldeney Essen-Werden", "WER", "Essen", "Baldeneysee-Arena", 3000, 33, "#c8102e", "Norbert Sieger"],
	],
	7: [
		["FC Odenwald Walldorf", "WAL", "Walldorf", "Dietmar-Hopp-Sportpark", 6000, 40, "#0057a3", "Timo Wenzel"],
		["SV Rheingau Wehen", "WEH", "Taunusstein", "Halberg-Arena", 5000, 40, "#c8102e", "Nikolaus Kraus"],
		["FSV Nahetal Bad Kreuznach", "KRE", "Bad Kreuznach", "Salinental-Stadion", 4000, 39, "#00843d", "Peter Best"],
		["FC Pfalzwald Pirmasens", "PIR", "Pirmasens", "Sportpark Husterhöhe", 10000, 39, "#000000", "Jürgen Neubauer"],
		["SV Schwarzwald Villingen", "VIL", "Villingen", "Friedengrund", 6000, 38, "#f4c400", "Klaus Wichmann"],
		["FC Kraichbach Hoffenheim II", "HOF", "Zuzenhausen", "Dietmar-Hopp-Akademie", 3000, 38, "#0057a3", "Frank Briel"],
		["SV Neckartal Nürtingen", "NUE", "Nürtingen", "Neckarstadion", 3000, 37, "#c8102e", "Volker Hagg"],
		["FC Bergstraße Bensheim", "BEN", "Bensheim", "Weiherhaus-Sportpark", 3000, 37, "#00843d", "Manfred Forst"],
		["FC Saarkohle Völklingen", "VOE", "Völklingen", "Hermann-Neuberger-Platz", 4000, 36, "#c8102e", "Alfred Kunz"],
	],
	8: [
		["SpVgg Isarwinkel München", "ISA", "München", "Grünwalder Kampfbahn", 12000, 41, "#0057a3", "Robert Hettich"],
		["FC Frankenhöhe Ansbach", "ANS", "Ansbach", "Rezat-Stadion", 4000, 40, "#c8102e", "Uwe Zeilinger"],
		["SV Rottal Passau", "PAS", "Passau", "Dreiflüsse-Arena", 5000, 40, "#00843d", "Georg Steinbauer"],
		["FC Altmühltal Eichstätt", "EIC", "Eichstätt", "Sportpark Rebdorf", 3000, 39, "#f4c400", "Alois Wagner"],
		["TSV Maintal Aschaffenburg", "ASC", "Aschaffenburg", "Schönbusch-Stadion", 7000, 39, "#0057a3", "Thomas Wissel"],
		["SV Chiemgau Traunstein", "TRA", "Traunstein", "Alpenblick-Arena", 3000, 38, "#c8102e", "Sepp Aicher"],
		["FC Steigerwald Bamberg", "BAM", "Bamberg", "Fuchspark", 6000, 38, "#00843d", "Klaus Rudel"],
		["SV Ries Nördlingen", "NOE", "Nördlingen", "Rieser Sportpark", 3000, 37, "#0057a3", "Franz Kurz"],
		["FC Fichtelgebirge Hof", "HOF2", "Hof", "Grüne Au", 4000, 37, "#f4c400", "Harald Fischer"],
		["TSV Lechfeld Landsberg", "LSB", "Landsberg", "Lechstadion", 3000, 36, "#c8102e", "Michael Sedlmeier"],
		["SV Donaumoos Neuburg", "NEU", "Neuburg", "Donauring-Sportpark", 2500, 36, "#00843d", "Josef Mayr"],
		["FC Rhön Bad Neustadt", "BNE", "Bad Neustadt", "Rhönstadion", 2500, 35, "#0057a3", "Erwin Grimm"],
		["SV Bayerwald Deggendorf", "DEG", "Deggendorf", "Donauhalle-Arena", 3000, 35, "#c8102e", "Ludwig Bergmann"],
		["TSV Wörnitz Donauwörth", "DON", "Donauwörth", "Kaiser-Ludwig-Platz", 2500, 34, "#f4c400", "Anton Weber"],
		["FC Oberpfalz Weiden", "WEI", "Weiden", "Wasserwerkstadion", 4000, 34, "#00843d", "Reinhold Bauer"],
		["SV Allgäu Kempten", "KEM", "Kempten", "Illerstadion", 4000, 33, "#0057a3", "Bernhard Stiefenhofer"],
	],
}

func _ready() -> void:
	print("=== REGIONALLIGA-STAFFELN ===")
	var clubs: Array = JSON.parse_string(FileAccess.open("res://data/clubs.json", FileAccess.READ).get_as_text())

	# Bestehende Regionalliga-Vereine ihrer Staffel zuordnen
	var moved := 0
	for c in clubs:
		if int(c.league) >= 4 and EXISTING.has(str(c.short)):
			c.league = int(EXISTING[str(c.short)])
			moved += 1

	var shorts := {}
	for c in clubs:
		shorts[str(c.short)] = true

	var added := 0
	for staffel in NEW_CLUBS:
		for e in NEW_CLUBS[staffel]:
			if shorts.has(str(e[1])):
				print("Übersprungen (Kürzel existiert): %s" % str(e[0]))
				continue
			clubs.append({
				"name": e[0], "short": e[1], "city": e[2], "stadium": e[3],
				"capacity": e[4], "strength": e[5], "league": int(staffel),
				"color": e[6], "chairman": e[7],
			})
			shorts[str(e[1])] = true
			added += 1

	var out := FileAccess.open("res://data/clubs.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(clubs, "\t"))
	out.close()

	var counts := {}
	for c in clubs:
		counts[int(c.league)] = counts.get(int(c.league), 0) + 1
	print("%d Vereine umgehängt, %d neu – jetzt %d gesamt" % [moved, added, clubs.size()])
	for lid in [1, 2, 3, 4, 5, 6, 7, 8]:
		print("  Liga %d: %d Vereine" % [lid, int(counts.get(lid, 0))])
	get_tree().quit(0)
