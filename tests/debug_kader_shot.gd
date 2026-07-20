extends Node
## Debug: Screenshots des neuen Kaders und des Spielerprofils.

func _ready() -> void:
	Game.setup = {"name": "Oliver Smolinski", "mode": "vereinsauswahl", "origin": "Dortmund",
		"skills": {"taktik": 4, "training": 3, "motivation": 2, "verhandlung": 1, "jugend": 1}}
	Game.new_game(2)
	for i in 6:
		Game.play_matchday()
	var hub: Control = load("res://scenes/hub.tscn").instantiate()
	add_child(hub)
	await get_tree().process_frame
	hub.show_screen("Kader")
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("user://kader_shot.png")
	# Spielerprofil des besten Stürmers öffnen
	var kader = hub._screens["Kader"]
	var st: PlayerData = Game.my_club().players_by_pos(Game.world.players, "ST")[0]
	kader._profile.open_for(st.id)
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("user://profil_shot.png")
	print("Screenshots gespeichert")
	get_tree().quit(0)
