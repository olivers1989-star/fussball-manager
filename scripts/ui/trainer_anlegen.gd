extends Control
## Spielstart, Schritt 1/3: Trainerprofil anlegen
## (Name, Geburtsdatum, Herkunftsort, Nationalität, Fähigkeiten-Verteilung).

const NATIONS := [
	"Deutschland", "Österreich", "Schweiz", "Niederlande", "England",
	"Spanien", "Italien", "Frankreich", "Portugal", "Türkei",
	"Polen", "Kroatien", "Dänemark", "Brasilien", "Argentinien",
]
const MONTHS := ["Januar", "Februar", "März", "April", "Mai", "Juni",
	"Juli", "August", "September", "Oktober", "November", "Dezember"]

const SKILL_HINTS := {
	"taktik": "Stärkt dein Team an jedem Spieltag",
	"training": "Deine Spieler bauen stetig Form auf",
	"motivation": "Fängt Niederlagen und Remis ab",
	"verhandlung": "Bessere Kauf- und Verkaufspreise",
	"jugend": "Stärkerer Nachwuchs zum Saisonwechsel",
}

var _name_edit: LineEdit
var _day_spin: SpinBox
var _month_select: OptionButton
var _year_spin: SpinBox
var _origin_edit: LineEdit
var _nat_select: OptionButton
var _skill_values := {}
var _skill_labels := {}
var _points_label: Label

func _ready() -> void:
	for key in Game.SKILLS:
		_skill_values[key] = 1

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := UITheme.card()
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	card.add_child(box)

	var step := Label.new()
	step.text = "Schritt 1 von 3"
	step.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step.add_theme_color_override("font_color", Color("#64748b"))
	box.add_child(step)

	var title := Label.new()
	title.text = "Trainerprofil anlegen"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("#4ade80"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 60)
	box.add_child(columns)

	# --- Linke Spalte: persönliche Daten
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	columns.add_child(left)
	left.add_child(_section_label("Persönliche Daten"))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	left.add_child(grid)

	grid.add_child(_form_label("Name:"))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Dein Trainername"
	_name_edit.custom_minimum_size = Vector2(300, 0)
	_name_edit.add_theme_font_size_override("font_size", 19)
	grid.add_child(_name_edit)

	grid.add_child(_form_label("Geburtsdatum:"))
	var birth_row := HBoxContainer.new()
	birth_row.add_theme_constant_override("separation", 6)
	_day_spin = SpinBox.new()
	_day_spin.min_value = 1
	_day_spin.max_value = 31
	_day_spin.value = 1
	birth_row.add_child(_day_spin)
	_month_select = OptionButton.new()
	for month in MONTHS:
		_month_select.add_item(month)
	birth_row.add_child(_month_select)
	_year_spin = SpinBox.new()
	_year_spin.min_value = 1956
	_year_spin.max_value = 2004
	_year_spin.value = 1986
	birth_row.add_child(_year_spin)
	grid.add_child(birth_row)

	grid.add_child(_form_label("Herkunftsort:"))
	_origin_edit = LineEdit.new()
	_origin_edit.placeholder_text = "z. B. Dortmund"
	_origin_edit.custom_minimum_size = Vector2(300, 0)
	_origin_edit.add_theme_font_size_override("font_size", 19)
	grid.add_child(_origin_edit)

	grid.add_child(_form_label("Nationalität:"))
	_nat_select = OptionButton.new()
	for nation in NATIONS:
		_nat_select.add_item(nation)
	_nat_select.custom_minimum_size = Vector2(220, 0)
	grid.add_child(_nat_select)

	# --- Rechte Spalte: Fähigkeiten
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)
	right.add_child(_section_label("Fähigkeiten"))
	_points_label = Label.new()
	_points_label.add_theme_font_size_override("font_size", 18)
	right.add_child(_points_label)

	for key in Game.SKILLS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		right.add_child(row)
		var skill_name := Label.new()
		skill_name.text = Game.SKILLS[key]
		skill_name.custom_minimum_size = Vector2(130, 0)
		skill_name.add_theme_font_size_override("font_size", 19)
		row.add_child(skill_name)
		var minus := Button.new()
		minus.text = "–"
		minus.custom_minimum_size = Vector2(36, 36)
		minus.pressed.connect(_on_skill_change.bind(key, -1))
		row.add_child(minus)
		var value := Label.new()
		value.custom_minimum_size = Vector2(70, 0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.add_theme_font_size_override("font_size", 19)
		row.add_child(value)
		_skill_labels[key] = value
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(36, 36)
		plus.pressed.connect(_on_skill_change.bind(key, 1))
		row.add_child(plus)
		var hint := Label.new()
		hint.text = SKILL_HINTS[key]
		hint.add_theme_color_override("font_color", Color("#64748b"))
		row.add_child(hint)

	# --- Buttons
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	box.add_child(buttons)
	var back := Button.new()
	back.text = "← Hauptmenü"
	back.custom_minimum_size = Vector2(180, 48)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	buttons.add_child(back)
	var next := Button.new()
	next.text = "Weiter: Spielmodus →"
	next.custom_minimum_size = Vector2(240, 48)
	next.add_theme_font_size_override("font_size", 20)
	next.pressed.connect(_on_next)
	buttons.add_child(next)

	_restore_setup()
	_update_skill_display()

func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color("#4ade80"))
	return l

func _form_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 19)
	return l

func _points_spent() -> int:
	var spent := 0
	for key in _skill_values:
		spent += _skill_values[key] - 1
	return spent

func _on_skill_change(key: String, delta: int) -> void:
	var new_value: int = _skill_values[key] + delta
	if new_value < 1 or new_value > Game.SKILL_MAX:
		return
	if delta > 0 and _points_spent() >= Game.SKILL_POOL:
		return
	_skill_values[key] = new_value
	_update_skill_display()

func _update_skill_display() -> void:
	for key in _skill_labels:
		_skill_labels[key].text = "%d / %d" % [_skill_values[key], Game.SKILL_MAX]
	_points_label.text = "Verfügbare Punkte: %d von %d" % [Game.SKILL_POOL - _points_spent(), Game.SKILL_POOL]

func _restore_setup() -> void:
	if not Game.setup.has("name"):
		return
	_name_edit.text = Game.setup.name
	var bd: Dictionary = Game.setup.get("birthday", {"day": 1, "month": 1, "year": 1986})
	_day_spin.value = bd.day
	_month_select.select(bd.month - 1)
	_year_spin.value = bd.year
	_origin_edit.text = Game.setup.get("origin", "")
	for i in _nat_select.item_count:
		if _nat_select.get_item_text(i) == Game.setup.get("nat", ""):
			_nat_select.select(i)
			break
	var saved_skills: Dictionary = Game.setup.get("skills", {})
	for key in saved_skills:
		if _skill_values.has(key):
			_skill_values[key] = int(saved_skills[key])

func _on_next() -> void:
	var trainer_name := _name_edit.text.strip_edges()
	if trainer_name.is_empty():
		trainer_name = "Der Trainer"
	Game.setup["name"] = trainer_name
	Game.setup["birthday"] = {
		"day": int(_day_spin.value),
		"month": _month_select.selected + 1,
		"year": int(_year_spin.value),
	}
	Game.setup["origin"] = _origin_edit.text.strip_edges()
	Game.setup["nat"] = _nat_select.get_item_text(_nat_select.selected)
	Game.setup["skills"] = _skill_values.duplicate()
	get_tree().change_scene_to_file("res://scenes/spielmodus.tscn")
