extends Node
## Debug: Wochensimulation starten und nach einigen Sekunden einen
## Viewport-Screenshot nach user://sim_shot.png schreiben.

func _ready() -> void:
	Game.setup = {"name": "Oliver Smolinski", "mode": "vereinsauswahl", "origin": "Dortmund",
		"skills": {"taktik": 4, "training": 3, "motivation": 2, "verhandlung": 1, "jugend": 1}}
	Game.new_game(2)
	var hub: Control = load("res://scenes/hub.tscn").instantiate()
	add_child(hub)
	await get_tree().process_frame
	hub._start_week_sim()
	await get_tree().create_timer(4.5).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://sim_shot.png")
	print("Screenshot gespeichert: ", ProjectSettings.globalize_path("user://sim_shot.png"))
	get_tree().quit(0)
