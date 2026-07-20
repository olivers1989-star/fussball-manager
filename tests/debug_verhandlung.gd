extends Node
## Debug-Einstieg: direkt zum Verhandlungsbildschirm (visuelle Prüfung).

func _ready() -> void:
	Game.setup = {"name": "Oliver", "mode": "angebote", "difficulty": "Normal", "club_id": 23}
	get_tree().change_scene_to_file.call_deferred("res://scenes/verhandlung.tscn")
