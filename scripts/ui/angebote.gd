extends Control
## Spielstart, Schritt 3/3 (Echte Karriere): Erste Jobangebote kleiner Zweitligisten.

var _offer_buttons: Array = []
var _selected_club_id := -1
var _start_button: Button

func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var screen_card := UITheme.card()
	center.add_child(screen_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	screen_card.add_child(box)

	var step := Label.new()
	step.text = "Schritt 3 von 3  ·  %s  ·  Echte Karriere  ·  Schwierigkeit: %s" % [
		Game.setup.get("name", "?"), Game.setup.get("difficulty", "Normal")]
	step.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step.add_theme_color_override("font_color", Color("#64748b"))
	box.add_child(step)

	var title := Label.new()
	title.text = "Deine ersten Angebote"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("#4ade80"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Als unbekannter Trainer klopfen nur kleine Zweitligisten an. Wähle deinen Einstieg:"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 19)
	subtitle.add_theme_color_override("font_color", Color("#94a3b8"))
	box.add_child(subtitle)

	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 20)
	box.add_child(cards)

	for club_id in _pick_initial_offers():
		var def: Dictionary = Data.club_defs[club_id - 1]
		var factor: float = Game.DIFFICULTY_FACTORS.get(Game.setup.get("difficulty", "Normal"), 1.0)
		var budget := int((int(def.strength) - 44) * 400000 * factor)
		var card := Button.new()
		card.toggle_mode = true
		card.custom_minimum_size = Vector2(330, 190)
		card.text = "%s\n\nZweite Liga\n%s (%s Plätze)\nTeamstärke: ~%d\nBudget: %s" % [
			def.name, def.stadium, Fmt.thousands(int(def.capacity)), int(def.strength), Fmt.money(budget)]
		card.add_theme_font_size_override("font_size", 18)
		card.pressed.connect(_on_offer_pressed.bind(club_id))
		cards.add_child(card)
		_offer_buttons.append({"club_id": club_id, "button": card})

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	box.add_child(buttons)
	var back := Button.new()
	back.text = "← Zurück"
	back.custom_minimum_size = Vector2(160, 48)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/spielmodus.tscn"))
	buttons.add_child(back)
	_start_button = Button.new()
	_start_button.text = "Angebot annehmen"
	_start_button.custom_minimum_size = Vector2(240, 48)
	_start_button.add_theme_font_size_override("font_size", 20)
	_start_button.disabled = true
	_start_button.pressed.connect(_on_start)
	buttons.add_child(_start_button)

## Drei zufällige Vereine aus den acht schwächsten der Zweiten Liga.
func _pick_initial_offers() -> Array:
	var second_league: Array = []
	for i in Data.club_defs.size():
		if int(Data.club_defs[i].league) == 2:
			second_league.append({"club_id": i + 1, "strength": int(Data.club_defs[i].strength)})
	second_league.sort_custom(func(a, b): return a.strength < b.strength)
	var weakest := second_league.slice(0, 8)
	weakest.shuffle()
	return weakest.slice(0, 3).map(func(entry): return entry.club_id)

func _on_offer_pressed(club_id: int) -> void:
	_selected_club_id = club_id
	for entry in _offer_buttons:
		entry.button.set_pressed_no_signal(entry.club_id == club_id)
	_start_button.disabled = false

func _on_start() -> void:
	if _selected_club_id < 0:
		return
	Game.new_game(_selected_club_id)
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
