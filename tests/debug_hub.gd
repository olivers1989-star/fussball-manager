extends Node
## Debug-Einstieg: startet direkt ein Spiel und öffnet die Zentrale (für visuelle Prüfung).

func _ready() -> void:
	Game.setup = {"name": "Oliver Smolinski", "mode": "vereinsauswahl", "origin": "Dortmund",
		"skills": {"taktik": 4, "training": 3, "motivation": 2, "verhandlung": 1, "jugend": 1}}
	Game.new_game(2)   # BV Westfalia Dortmund
	get_tree().change_scene_to_file.call_deferred("res://scenes/hub.tscn")
