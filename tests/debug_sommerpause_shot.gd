extends Node
## Debug: Screenshot der Zentrale in der Sommerpause und am 1. Juli.

func _ready() -> void:
	Game.setup = {"name": "Oliver Smolinski", "mode": "vereinsauswahl", "origin": "Dortmund",
		"skills": {"taktik": 4, "training": 3, "motivation": 2, "verhandlung": 1, "jugend": 2}}
	Game.new_game(2)
	var guard := 0
	while not Game.season_over() and guard < 500:
		guard += 1
		Game.play_matchday()
	# Ein paar Tage in die Sommerpause
	for i in 6:
		Game.advance_day()
	var hub: Control = load("res://scenes/hub.tscn").instantiate()
	add_child(hub)
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("user://sommerpause_shot.png")
	print("Sommerpause: %s · Button „%s“" % [Game.date_label(), hub._play_button.text])
	remove_child(hub)
	hub.free()
	# Bis zum 1. Juli weiter – dort muss die Zentrale in den Abschluss springen
	while not Game.season_rollover_due():
		Game.advance_day()
	print("Abschluss faellig am %s" % Game.date_label())
	print("Screenshot gespeichert")
	get_tree().quit(0)
