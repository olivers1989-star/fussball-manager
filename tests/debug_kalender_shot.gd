extends Node
## Debug: Screenshots des überarbeiteten Kalenders und des Spielergesprächs.

func _ready() -> void:
	Game.setup = {"name": "Oliver Smolinski", "mode": "vereinsauswahl", "origin": "Dortmund",
		"skills": {"taktik": 4, "training": 3, "motivation": 3, "verhandlung": 1, "jugend": 1}}
	Game.new_game(2)
	var hub: Control = load("res://scenes/hub.tscn").instantiate()
	add_child(hub)
	await get_tree().process_frame
	hub.show_screen("Kalender")
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png("user://kalender_shot.png")
	# Spielergespräch zeigen
	var p: PlayerData = Game.my_club().players(Game.world.players)[8]
	hub._show_talk_dialog({"kind": "player_talk", "pid": p.id, "topic": "einsatzzeit"})
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png("user://gespraech_shot.png")
	print("Screenshots gespeichert")
	get_tree().quit(0)
