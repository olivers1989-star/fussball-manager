extends Node
## Debug: Verhandlung mit erzwungener Einigung -> Vertragsdokument mit Unterschriftsfeld.

func _ready() -> void:
	Game.setup = {"name": "Oliver Smolinski", "mode": "angebote", "difficulty": "Normal", "club_id": 23}
	var v: Control = load("res://scenes/verhandlung.tscn").instantiate()
	add_child(v)
	await get_tree().process_frame
	v._reach_agreement()
	await get_tree().process_frame
	v._agreement_dialog.hide()
	v._show_signature()
