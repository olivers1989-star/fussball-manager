extends Node
## Debug: einige Spieltage simulieren, dann Screenshot der neuen Dashboard-Übersicht.

func _ready() -> void:
	Game.setup = {"name": "Oliver Smolinski", "mode": "vereinsauswahl", "origin": "Dortmund",
		"skills": {"taktik": 4, "training": 3, "motivation": 2, "verhandlung": 1, "jugend": 1}}
	Game.new_game(2)
	for i in 6:
		Game.play_matchday()
	var hub: Control = load("res://scenes/hub.tscn").instantiate()
	add_child(hub)
	await get_tree().process_frame
	hub.show_screen("Übersicht")
	await get_tree().create_timer(1.0).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://dashboard_shot.png")
	print("Screenshot gespeichert")
	get_tree().quit(0)
