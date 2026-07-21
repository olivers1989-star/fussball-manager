extends Node
## Debug: Match bis Minute ~50 laufen lassen und Screenshot (Ticker + Live-Frische).

func _ready() -> void:
	Game.setup = {"name": "Oliver Smolinski", "mode": "vereinsauswahl", "origin": "Dortmund",
		"skills": {"taktik": 4, "training": 3, "motivation": 2, "verhandlung": 1, "jugend": 1}}
	Game.new_game(2)
	Game.match_plan = "Offensivpressing"
	Game.advance_to_matchday()
	var match_screen: Control = load("res://scenes/match.tscn").instantiate()
	add_child(match_screen)
	await get_tree().process_frame
	match_screen._on_kickoff()
	match_screen._set_paused(true)
	for i in 50:
		match_screen._on_tick()
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("user://match_shot.png")
	print("Screenshot gespeichert")
	get_tree().quit(0)
