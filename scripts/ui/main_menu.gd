extends Control
## Hauptmenü: Neues Spiel, Spiel laden, Beenden.

var _load_dialog: AcceptDialog
var _save_list: ItemList
var _saves: Array = []

func _ready() -> void:
	# Dezente "Rasen"-Fläche im Hintergrund
	var pitch := ColorRect.new()
	pitch.color = Color("#0d1a12")
	pitch.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(pitch)
	var stripe := ColorRect.new()
	stripe.color = Color("#22c55e")
	stripe.set_anchors_preset(Control.PRESET_TOP_WIDE)
	stripe.custom_minimum_size = Vector2(0, 4)
	add_child(stripe)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := UITheme.card()
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	card.add_child(box)

	var ball := Label.new()
	ball.text = "⚽"
	ball.add_theme_font_size_override("font_size", 52)
	ball.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(ball)

	var title := Label.new()
	title.text = "FUSSBALL MANAGER"
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Zwei Ligen. Ein Ziel. Deine Karriere."
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	box.add_child(_spacer(20))
	var new_button := _menu_button("Neues Spiel", _on_new_game)
	UITheme.make_primary(new_button)
	box.add_child(new_button)
	box.add_child(_menu_button("Spiel laden", _on_load))
	box.add_child(_menu_button("Beenden", _on_quit))

	_load_dialog = AcceptDialog.new()
	_load_dialog.title = "Spiel laden"
	_load_dialog.ok_button_text = "Laden"
	_load_dialog.min_size = Vector2i(600, 400)
	_save_list = ItemList.new()
	_save_list.custom_minimum_size = Vector2(560, 320)
	_load_dialog.add_child(_save_list)
	_load_dialog.confirmed.connect(_on_load_confirmed)
	add_child(_load_dialog)

func _menu_button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 54)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(handler)
	return b

func _spacer(height: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	return s

func _on_new_game() -> void:
	Game.setup = {}
	get_tree().change_scene_to_file("res://scenes/trainer_anlegen.tscn")

func _on_load() -> void:
	_saves = Game.list_saves()
	_save_list.clear()
	if _saves.is_empty():
		_save_list.add_item("Keine Spielstände vorhanden.")
		_save_list.set_item_disabled(0, true)
	else:
		for s in _saves:
			var m: Dictionary = s.meta
			var mode: String = "Echte Karriere" if m.get("game_mode", "") == "angebote" else "Vereinsauswahl"
			_save_list.add_item("%s – %s, Saison %d, Spieltag %d · %s  (%s)" % [
				m.manager, m.club, int(m.season_year), int(m.matchday) + 1, mode, m.saved_at])
		_save_list.select(0)
	_load_dialog.popup_centered()

func _on_load_confirmed() -> void:
	if _saves.is_empty() or _save_list.get_selected_items().is_empty():
		return
	var idx: int = _save_list.get_selected_items()[0]
	if Game.load_game(_saves[idx].path):
		get_tree().change_scene_to_file("res://scenes/hub.tscn")

func _on_quit() -> void:
	get_tree().quit()
