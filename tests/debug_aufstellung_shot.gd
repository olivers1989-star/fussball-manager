extends Node
## Debug: Screenshots des 2D-Aufstellungsbildschirms (normal + Fehlbesetzung).

func _ready() -> void:
	Game.setup = {"name": "Oliver Smolinski", "mode": "vereinsauswahl", "origin": "Dortmund",
		"skills": {"taktik": 4, "training": 3, "motivation": 2, "verhandlung": 1, "jugend": 1}}
	Game.new_game(2)
	for i in 3:
		Game.play_matchday()
	var hub: Control = load("res://scenes/hub.tscn").instantiate()
	add_child(hub)
	await get_tree().process_frame
	hub.show_screen("Aufstellung")
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("user://aufstellung_shot.png")
	# Fehlbesetzung provozieren: Stürmer auf den LV-Slot ziehen (Slot 1)
	var tab = hub._screens["Aufstellung"]
	var st: PlayerData = Game.my_club().players_by_pos(Game.world.players, "MS")[0]
	if Game.my_club().lineup.has(st.id):
		# Freie Positionierung: Stürmer tief in die Abwehrzone ziehen (wird IV)
		Game.my_club().lineup_spots[Game.my_club().lineup.find(st.id)] = Vector2(0.5, 0.26)
		tab._refresh_all()
	else:
		tab._insert_at_slot(st.id, 1)
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png("user://aufstellung_warn_shot.png")
	# Andere Formation testen (4-2-3-1)
	tab._formation_select.select(3)
	tab._on_formation_changed(3)
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png("user://aufstellung_4231_shot.png")
	print("Screenshots gespeichert")
	get_tree().quit(0)
