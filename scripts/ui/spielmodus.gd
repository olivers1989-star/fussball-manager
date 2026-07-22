extends Control
## Spielstart, Schritt 2/3: Spielmodus und Schwierigkeit – große Auswahl-Karten
## mit Akzent-Rahmen, Schwierigkeit als Schalter mit Erklärung.

const MODES := [
	{
		"id": "angebote",
		"icon": "🛤",
		"title": "Echte Karriere",
		"desc": "Du beginnst ganz unten: Kleine Zweitligisten bieten dir deinen ersten Trainerposten an. Mit guten Leistungen steigt dein Ruf – und größere Vereine melden sich von selbst.",
	},
	{
		"id": "vereinsauswahl",
		"icon": "🎯",
		"title": "Vereinsauswahl",
		"desc": "Freie Wahl: Übernimm sofort jeden Verein aus beiden Ligen – vom Titelkandidaten bis zum Abstiegskampf. Ideal, um direkt bei deinem Herzensverein loszulegen.",
	},
]
const DIFF_HINTS := {
	"Leicht": "150 % Startbudget – entspannter Einstieg",
	"Normal": "100 % Startbudget – der gedachte Weg",
	"Schwer": "50 % Startbudget – für Sparfüchse",
}

var _mode_cards := {}
var _selected_mode := "angebote"
var _diff_buttons := {}
var _selected_diff := "Normal"
var _diff_hint: Label

func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	box.add_child(WizardUI.step_header(2, "Spielmodus wählen", "Trainer: %s  ·  Wie beginnt deine Karriere?" % Game.setup.get("name", "?")))

	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 18)
	box.add_child(cards)

	for mode in MODES:
		var card := Button.new()
		card.toggle_mode = true
		card.focus_mode = Control.FOCUS_NONE
		card.custom_minimum_size = Vector2(430, 200)
		card.pressed.connect(_on_mode_pressed.bind(mode.id))
		cards.add_child(card)
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 6)
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pad := MarginContainer.new()
		pad.set_anchors_preset(Control.PRESET_FULL_RECT)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
			pad.add_theme_constant_override(side, 20)
		card.add_child(pad)
		pad.add_child(inner)
		var icon := Label.new()
		icon.text = mode.icon
		icon.add_theme_font_size_override("font_size", 30)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(icon)
		var title := Label.new()
		title.text = mode.title
		title.add_theme_font_size_override("font_size", 23)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(title)
		var desc := Label.new()
		desc.text = mode.desc
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 14)
		desc.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(desc)
		_mode_cards[mode.id] = card

	# Schwierigkeit
	var diff_card := WizardUI.section_card("🎚 Schwierigkeit")
	diff_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(diff_card)
	var diff_box: VBoxContainer = diff_card.get_meta("content")
	var diff_row := HBoxContainer.new()
	diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_row.add_theme_constant_override("separation", 8)
	diff_box.add_child(diff_row)
	for diff in Game.DIFFICULTY_FACTORS:
		var b := Button.new()
		b.text = diff
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(130, 42)
		b.pressed.connect(_on_diff_pressed.bind(diff))
		diff_row.add_child(b)
		_diff_buttons[diff] = b
	_diff_hint = Label.new()
	_diff_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_diff_hint.add_theme_font_size_override("font_size", 13)
	_diff_hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	diff_box.add_child(_diff_hint)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	box.add_child(buttons)
	var back := Button.new()
	back.text = "← Zurück"
	back.custom_minimum_size = Vector2(160, 46)
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/trainer_anlegen.tscn"))
	buttons.add_child(back)
	var next := Button.new()
	next.text = "Weiter  →"
	next.custom_minimum_size = Vector2(240, 46)
	next.add_theme_font_size_override("font_size", 18)
	UITheme.make_primary(next)
	next.pressed.connect(_on_next)
	buttons.add_child(next)

	_selected_mode = Game.setup.get("mode", "angebote")
	_selected_diff = Game.setup.get("difficulty", "Normal")
	_update_selection()

func _on_mode_pressed(mode_id: String) -> void:
	_selected_mode = mode_id
	_update_selection()

func _on_diff_pressed(diff: String) -> void:
	_selected_diff = diff
	_update_selection()

func _update_selection() -> void:
	for id in _mode_cards:
		var card: Button = _mode_cards[id]
		var active: bool = id == _selected_mode
		card.set_pressed_no_signal(active)
		var sb := UITheme.box(UITheme.SURFACE2 if active else UITheme.SURFACE, 14, UITheme.ACCENT if active else UITheme.BORDER)
		sb.set_border_width_all(2 if active else 1)
		card.add_theme_stylebox_override("normal", sb)
		var hover := sb.duplicate()
		hover.bg_color = sb.bg_color.lightened(0.03)
		card.add_theme_stylebox_override("hover", hover)
		card.add_theme_stylebox_override("pressed", sb)
	for diff in _diff_buttons:
		_diff_buttons[diff].set_pressed_no_signal(diff == _selected_diff)
	_diff_hint.text = DIFF_HINTS.get(_selected_diff, "")

func _on_next() -> void:
	Game.setup["mode"] = _selected_mode
	Game.setup["difficulty"] = _selected_diff
	if _selected_mode == "angebote":
		get_tree().change_scene_to_file("res://scenes/angebote.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/vereinswahl.tscn")
