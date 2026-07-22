extends Node
## Debug: Screenshots des modernisierten Spielstart-Assistenten
## (Trainerprofil, Spielmodus, Angebote, Verhandlung).

func _ready() -> void:
	Game.setup = {"name": "Oliver Smolinski", "first_name": "Oliver", "last_name": "Smolinski",
		"mode": "angebote", "difficulty": "Normal", "origin": "Dortmund", "nat": "Deutschland",
		"skills": {"taktik": 4, "training": 3, "motivation": 2, "verhandlung": 2, "jugend": 1}}
	var shots := [
		["res://scenes/trainer_anlegen.tscn", "user://wiz1_shot.png"],
		["res://scenes/spielmodus.tscn", "user://wiz2_shot.png"],
		["res://scenes/angebote.tscn", "user://wiz3_shot.png"],
	]
	for entry in shots:
		var screen: Control = load(entry[0]).instantiate()
		add_child(screen)
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png(entry[1])
		screen.queue_free()
		await get_tree().process_frame
	# Verhandlung mit dem ersten Angebots-Verein
	Game.setup["club_id"] = int(Game.setup.initial_offers[0])
	var v: Control = load("res://scenes/verhandlung.tscn").instantiate()
	add_child(v)
	await get_tree().create_timer(0.6).timeout
	get_viewport().get_texture().get_image().save_png("user://wiz4_shot.png")
	print("Screenshots gespeichert")
	get_tree().quit(0)
