extends Node
## Debug: Screenshots der neuen Tabelle und des Spielplans.

func _ready() -> void:
	Game.setup = {"name": "Oliver Smolinski", "mode": "vereinsauswahl", "origin": "Dortmund",
		"skills": {"taktik": 4, "training": 3, "motivation": 2, "verhandlung": 1, "jugend": 1}}
	Game.new_game(2)
	for i in 8:
		Game.play_matchday()
	var hub: Control = load("res://scenes/hub.tscn").instantiate()
	add_child(hub)
	await get_tree().process_frame
	hub.show_screen("Tabelle")
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("user://tabelle_shot.png")
	hub.show_screen("Spielplan")
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("user://spielplan_shot.png")
	print("Screenshots gespeichert")
	get_tree().quit(0)
