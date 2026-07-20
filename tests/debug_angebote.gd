extends Node
## Debug-Einstieg: direkt zum Angebote-Bildschirm (visuelle Prüfung).

func _ready() -> void:
	Game.setup = {"name": "Oliver", "mode": "angebote", "difficulty": "Normal"}
	get_tree().change_scene_to_file.call_deferred("res://scenes/angebote.tscn")
