extends Node
## Debug: Screenshot der neuen Spielstands-Verwaltung (Speicher- und Lademodus).

func _ready() -> void:
	Game.setup = {"name": "Oliver Smolinski", "mode": "vereinsauswahl", "origin": "Dortmund",
		"skills": {"taktik": 4, "training": 3, "motivation": 2, "verhandlung": 1, "jugend": 1}}
	Game.new_game(2)
	# Ein paar Beispiel-Spielstände anlegen
	for i in 3:
		Game.play_matchday()
	Game.save_game("Meine Karriere")
	for i in 4:
		Game.play_matchday()
	Game.save_game("Vor dem Derby")
	Game.save_game()

	var hub: Control = load("res://scenes/hub.tscn").instantiate()
	add_child(hub)
	await get_tree().process_frame
	hub._on_save()
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png("user://speichern_shot.png")
	print("Screenshot gespeichert")
	get_tree().quit(0)
