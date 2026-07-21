extends Node
## Debug: Screenshots der neuen Spielansicht (Vorschau, Live-Phase, Abpfiff).

func _ready() -> void:
	Game.setup = {"name": "Oliver Smolinski", "mode": "vereinsauswahl", "origin": "Dortmund",
		"skills": {"taktik": 4, "training": 3, "motivation": 2, "verhandlung": 1, "jugend": 1}}
	Game.new_game(2)
	Game.advance_to_matchday()
	var screen: Control = load("res://scenes/match.tscn").instantiate()
	add_child(screen)
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png("user://match_pre_shot.png")
	# Anpfiff und 60 Minuten durchlaufen lassen
	screen._on_kickoff()
	screen._timer.stop()
	for i in 60:
		screen._on_tick()
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png("user://match_live_shot.png")
	screen._finish_instantly()
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png("user://match_post_shot.png")
	print("Screenshots gespeichert")
	get_tree().quit(0)
