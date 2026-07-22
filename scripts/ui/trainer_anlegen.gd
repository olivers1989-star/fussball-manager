extends Control
## Spielstart, Schritt 1/3: Trainerprofil anlegen – modernes Karten-Layout mit
## Schritt-Anzeige, Flaggen bei der Nationalität und Fähigkeiten mit Punkte-Skala.

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
const SKILL_ICONS := {"taktik": "♟", "training": "🏃", "motivation": "🔥", "verhandlung": "💬", "jugend": "🌱"}

var _first_edit: LineEdit
var _last_edit: LineEdit
var _day_spin: SpinBox
var _month_select: OptionButton
var _year_spin: SpinBox
var _origin_edit: LineEdit
var _nat_select: OptionButton
var _skill_values := {}
var _skill_dots := {}
var _points_label: Label
var _profile_select: OptionButton
var _profile_status: Label
var _profiles: Array = []

func _ready() -> void:
	for key in Game.SKILLS:
		_skill_values[key] = 1

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	box.add_child(WizardUI.step_header(1, "Trainerprofil anlegen", "Wer steht bei dir an der Seitenlinie?"))

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	box.add_child(columns)

	# --- Karte: Persönliche Daten
	var left_card := WizardUI.section_card("👤 Persönliche Daten")
	columns.add_child(left_card)
	var left: VBoxContainer = left_card.get_meta("content")

	var profile_row := HBoxContainer.new()
	profile_row.add_theme_constant_override("separation", 8)
	left.add_child(profile_row)
	_profile_select = OptionButton.new()
	_profile_select.custom_minimum_size = Vector2(220, 0)
	_profile_select.item_selected.connect(_on_profile_selected)
	profile_row.add_child(_profile_select)
	var save_profile_button := Button.new()
	save_profile_button.text = "💾 Speichern"
	save_profile_button.pressed.connect(_on_save_profile)
	profile_row.add_child(save_profile_button)
	_profile_status = Label.new()
	_profile_status.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	profile_row.add_child(_profile_status)
	_reload_profiles()

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 11)
	left.add_child(grid)

	grid.add_child(WizardUI.form_label("Vorname"))
	_first_edit = LineEdit.new()
	_first_edit.placeholder_text = "Vorname"
	_first_edit.custom_minimum_size = Vector2(280, 0)
	_first_edit.add_theme_font_size_override("font_size", 17)
	grid.add_child(_first_edit)

	grid.add_child(WizardUI.form_label("Nachname"))
	_last_edit = LineEdit.new()
	_last_edit.placeholder_text = "Nachname"
	_last_edit.custom_minimum_size = Vector2(280, 0)
	_last_edit.add_theme_font_size_override("font_size", 17)
	grid.add_child(_last_edit)

	grid.add_child(WizardUI.form_label("Geburtsdatum"))
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

	grid.add_child(WizardUI.form_label("Herkunftsort"))
	_origin_edit = LineEdit.new()
	_origin_edit.placeholder_text = "z. B. Dortmund"
	_origin_edit.custom_minimum_size = Vector2(280, 0)
	_origin_edit.add_theme_font_size_override("font_size", 17)
	grid.add_child(_origin_edit)

	grid.add_child(WizardUI.form_label("Nationalität"))
	_nat_select = OptionButton.new()
	for nation in NATIONS:
		_nat_select.add_icon_item(Flags.texture(nation), nation)
	_nat_select.custom_minimum_size = Vector2(220, 0)
	grid.add_child(_nat_select)

	# --- Karte: Fähigkeiten
	var right_card := WizardUI.section_card("⚡ Fähigkeiten")
	columns.add_child(right_card)
	var right: VBoxContainer = right_card.get_meta("content")

	_points_label = Label.new()
	_points_label.add_theme_font_size_override("font_size", 15)
	_points_label.add_theme_color_override("font_color", UITheme.WARN)
	right.add_child(_points_label)

	for key in Game.SKILLS:
		var row_box := VBoxContainer.new()
		row_box.add_theme_constant_override("separation", 1)
		right.add_child(row_box)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row_box.add_child(row)
		var skill_name := Label.new()
		skill_name.text = "%s  %s" % [SKILL_ICONS.get(key, ""), Game.SKILLS[key]]
		skill_name.custom_minimum_size = Vector2(160, 0)
		skill_name.add_theme_font_size_override("font_size", 17)
		row.add_child(skill_name)
		var minus := Button.new()
		minus.text = "–"
		minus.custom_minimum_size = Vector2(34, 34)
		minus.focus_mode = Control.FOCUS_NONE
		minus.pressed.connect(_on_skill_change.bind(key, -1))
		row.add_child(minus)
		var dots := Label.new()
		dots.custom_minimum_size = Vector2(150, 0)
		dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dots.add_theme_font_size_override("font_size", 16)
		dots.add_theme_color_override("font_color", UITheme.ACCENT)
		row.add_child(dots)
		_skill_dots[key] = dots
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(34, 34)
		plus.focus_mode = Control.FOCUS_NONE
		plus.pressed.connect(_on_skill_change.bind(key, 1))
		row.add_child(plus)
		var hint := Label.new()
		hint.text = SKILL_HINTS[key]
		hint.add_theme_font_size_override("font_size", 12)
		hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		row_box.add_child(hint)

	# --- Navigation
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	box.add_child(buttons)
	var back := Button.new()
	back.text = "← Hauptmenü"
	back.custom_minimum_size = Vector2(180, 46)
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	buttons.add_child(back)
	var next := Button.new()
	next.text = "Weiter: Spielmodus  →"
	next.custom_minimum_size = Vector2(260, 46)
	next.add_theme_font_size_override("font_size", 18)
	UITheme.make_primary(next)
	next.pressed.connect(_on_next)
	buttons.add_child(next)

	_restore_setup()
	_update_skill_display()

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
	for key in _skill_dots:
		_skill_dots[key].text = "●".repeat(_skill_values[key]) + "○".repeat(Game.SKILL_MAX - _skill_values[key])
	var free := Game.SKILL_POOL - _points_spent()
	_points_label.text = "Noch %d von %d Punkten zu verteilen" % [free, Game.SKILL_POOL] if free > 0 else "Alle Punkte verteilt ✓"

func _restore_setup() -> void:
	if not Game.setup.has("name"):
		return
	_apply_profile({
		"first": Game.setup.get("first_name", ""),
		"last": Game.setup.get("last_name", ""),
		"birthday": Game.setup.get("birthday", {"day": 1, "month": 1, "year": 1986}),
		"origin": Game.setup.get("origin", ""),
		"nat": Game.setup.get("nat", "Deutschland"),
		"skills": Game.setup.get("skills", {}),
	})

# ------------------------------------------------------------------ Profile speichern/laden

func _collect_profile() -> Dictionary:
	return {
		"first": _first_edit.text.strip_edges(),
		"last": _last_edit.text.strip_edges(),
		"birthday": {
			"day": int(_day_spin.value),
			"month": _month_select.selected + 1,
			"year": int(_year_spin.value),
		},
		"origin": _origin_edit.text.strip_edges(),
		"nat": _nat_select.get_item_text(_nat_select.selected),
		"skills": _skill_values.duplicate(),
	}

func _apply_profile(p: Dictionary) -> void:
	_first_edit.text = p.get("first", "")
	_last_edit.text = p.get("last", "")
	var bd: Dictionary = p.get("birthday", {"day": 1, "month": 1, "year": 1986})
	_day_spin.value = int(bd.day)
	_month_select.select(int(bd.month) - 1)
	_year_spin.value = int(bd.year)
	_origin_edit.text = p.get("origin", "")
	for i in _nat_select.item_count:
		if _nat_select.get_item_text(i) == p.get("nat", ""):
			_nat_select.select(i)
			break
	for key in _skill_values:
		_skill_values[key] = clampi(int(p.get("skills", {}).get(key, 1)), 1, Game.SKILL_MAX)
	_update_skill_display()

func _reload_profiles() -> void:
	_profiles = Game.list_profiles()
	_profile_select.clear()
	_profile_select.add_item("– Gespeichertes Profil laden –")
	for p in _profiles:
		_profile_select.add_item("%s %s" % [p.get("first", ""), p.get("last", "")])

func _on_profile_selected(index: int) -> void:
	if index <= 0 or index > _profiles.size():
		return
	_apply_profile(_profiles[index - 1])
	_profile_status.text = "Profil geladen ✓"

func _on_save_profile() -> void:
	var profile := _collect_profile()
	if profile.first.is_empty() and profile.last.is_empty():
		_profile_status.text = "Bitte erst einen Namen eingeben."
		return
	Game.save_profile(profile)
	_reload_profiles()
	_profile_status.text = "Profil gespeichert ✓"

# ------------------------------------------------------------------ Weiter

func _on_next() -> void:
	var profile := _collect_profile()
	var first: String = profile.first if not profile.first.is_empty() else "Der"
	var last: String = profile.last if not profile.last.is_empty() else "Trainer"
	Game.setup["first_name"] = first
	Game.setup["last_name"] = last
	Game.setup["name"] = "%s %s" % [first, last]
	Game.setup["birthday"] = profile.birthday
	Game.setup["origin"] = profile.origin
	Game.setup["nat"] = profile.nat
	Game.setup["skills"] = profile.skills
	get_tree().change_scene_to_file("res://scenes/spielmodus.tscn")
