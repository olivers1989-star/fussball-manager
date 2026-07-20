extends Control
## Spielstart, Schritt 2/3: Spielmodus und Schwierigkeit wählen.

const MODES := [
	{
		"id": "angebote",
		"title": "Echte Karriere",
		"desc": "Du beginnst ganz unten: Kleine Zweitligisten bieten dir\ndeinen ersten Trainerposten an. Mit guten Leistungen\nsteigt dein Ruf – und größere Vereine melden sich.",
	},
	{
		"id": "vereinsauswahl",
		"title": "Vereinsauswahl",
		"desc": "Freie Wahl: Übernimm sofort jeden Verein aus\nbeiden Ligen – vom Titelkandidaten bis zum\nAbstiegskampf-Kandidaten.",
	},
]

var _mode_buttons: Array = []
var _selected_mode := "angebote"
var _difficulty_select: OptionButton

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
	step.text = "Schritt 2 von 3  ·  Trainer: %s" % Game.setup.get("name", "?")
	step.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step.add_theme_color_override("font_color", Color("#64748b"))
	box.add_child(step)

	var title := Label.new()
	title.text = "Spielmodus wählen"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("#4ade80"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 20)
	box.add_child(cards)

	for mode in MODES:
		var card := Button.new()
		card.toggle_mode = true
		card.custom_minimum_size = Vector2(400, 170)
		card.text = "%s\n\n%s" % [mode.title, mode.desc]
		card.add_theme_font_size_override("font_size", 19)
		card.pressed.connect(_on_mode_pressed.bind(mode.id))
		cards.add_child(card)
		_mode_buttons.append({"id": mode.id, "button": card})

	var diff_row := HBoxContainer.new()
	diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_row.add_theme_constant_override("separation", 12)
	box.add_child(diff_row)
	var diff_label := Label.new()
	diff_label.text = "Schwierigkeit:"
	diff_label.add_theme_font_size_override("font_size", 20)
	diff_row.add_child(diff_label)
	_difficulty_select = OptionButton.new()
	for diff in Game.DIFFICULTY_FACTORS:
		_difficulty_select.add_item(diff)
	_difficulty_select.select(1)   # Normal
	_difficulty_select.custom_minimum_size = Vector2(160, 0)
	diff_row.add_child(_difficulty_select)
	var diff_hint := Label.new()
	diff_hint.text = "(bestimmt dein Startbudget: 150 % / 100 % / 50 %)"
	diff_hint.add_theme_color_override("font_color", Color("#64748b"))
	diff_row.add_child(diff_hint)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	box.add_child(buttons)
	var back := Button.new()
	back.text = "← Zurück"
	back.custom_minimum_size = Vector2(160, 48)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/trainer_anlegen.tscn"))
	buttons.add_child(back)
	var next := Button.new()
	next.text = "Weiter →"
	next.custom_minimum_size = Vector2(260, 48)
	next.add_theme_font_size_override("font_size", 20)
	next.pressed.connect(_on_next)
	buttons.add_child(next)

	# Vorauswahl wiederherstellen
	_selected_mode = Game.setup.get("mode", "angebote")
	_update_mode_buttons()
	var saved_diff: String = Game.setup.get("difficulty", "Normal")
	for i in _difficulty_select.item_count:
		if _difficulty_select.get_item_text(i) == saved_diff:
			_difficulty_select.select(i)
			break

func _on_mode_pressed(mode_id: String) -> void:
	_selected_mode = mode_id
	_update_mode_buttons()

func _update_mode_buttons() -> void:
	for entry in _mode_buttons:
		entry.button.set_pressed_no_signal(entry.id == _selected_mode)

func _on_next() -> void:
	Game.setup["mode"] = _selected_mode
	Game.setup["difficulty"] = _difficulty_select.get_item_text(_difficulty_select.selected)
	if _selected_mode == "angebote":
		get_tree().change_scene_to_file("res://scenes/angebote.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/vereinswahl.tscn")
