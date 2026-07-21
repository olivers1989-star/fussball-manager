extends Node
## Debug: Spielvorbereitungs-Overlay anzeigen und Screenshot machen.

func _ready() -> void:
	Game.setup = {"name": "Oliver Smolinski", "mode": "vereinsauswahl", "origin": "Dortmund",
		"skills": {"taktik": 4, "training": 3, "motivation": 2, "verhandlung": 1, "jugend": 1}}
	Game.new_game(2)
	for i in 3:
		Game.play_matchday()
	var hub: Control = load("res://scenes/hub.tscn").instantiate()
	add_child(hub)
	await get_tree().process_frame
	hub._show_prep_dialog()
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("user://prep_shot.png")
	print("Screenshot gespeichert")
	get_tree().quit(0)
