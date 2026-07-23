extends Node
## Werkzeug: Schreibt data/clubs.json sauber zurück – Zahlen als ganze Zahlen
## statt als Kommazahlen. Die Datei ist die editierbare Stammdatenquelle,
## deshalb soll sie lesbar bleiben.

const INT_FIELDS := ["id", "capacity", "strength", "league"]

func _ready() -> void:
	var clubs: Array = JSON.parse_string(FileAccess.open("res://data/clubs.json", FileAccess.READ).get_as_text())
	for c in clubs:
		for key in INT_FIELDS:
			if c.has(key):
				c[key] = int(c[key])
	var out := FileAccess.open("res://data/clubs.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(clubs, "\t"))
	out.close()
	print("clubs.json aufgeräumt: %d Vereine" % clubs.size())
	get_tree().quit(0)
