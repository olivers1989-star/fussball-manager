extends Node
## Debug: Screenshot des Saisonabschluss-Bildschirms nach einer kompletten Saison.

func _ready() -> void:
	Game.setup = {"name": "Oliver Smolinski", "mode": "vereinsauswahl", "origin": "Dortmund",
		"skills": {"taktik": 4, "training": 3, "motivation": 2, "verhandlung": 1, "jugend": 2}}
	Game.new_game(2)
	var guard := 0
	while not Game.season_over() and guard < 500:
		guard += 1
		Game.play_matchday()
	while not Game.season_rollover_due():
		Game.advance_day()
	var screen: Control = load("res://scenes/saison.tscn").instantiate()
	add_child(screen)
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("user://saison_shot.png")
	print("Screenshot gespeichert")
	get_tree().quit(0)
