extends Control
## Vertragsverhandlung mit dem Vorstand vor Amtsantritt:
## Gehalt (nachverhandelbar), Vertragslaufzeit und Saisonziel.

const DEMANDS := [
	{"label": "+10 % Gehalt", "pct": 0.10},
	{"label": "+25 % Gehalt", "pct": 0.25},
	{"label": "+50 % Gehalt", "pct": 0.50},
]

var _club_id := 1
var _def: Dictionary
var _tier := 1
var _salary := 20000
var _attempts := 2

var _salary_label: Label
var _years_select: OptionButton
var _demand_select: OptionButton
var _negotiate_button: Button
var _message: Label

func _ready() -> void:
	_club_id = int(Game.setup.get("club_id", 1))
	_def = Data.club_defs[_club_id - 1]
	_tier = int(_def.league)
	_salary = Game.board_salary(int(_def.strength))
	_build_ui()

func _goal() -> Dictionary:
	var stronger := 0
	for d in Data.club_defs:
		if int(d.league) == _tier and int(d.strength) > int(_def.strength):
			stronger += 1
	return Game.goal_from_rank(stronger + 1, _tier)

func _budget() -> int:
	var factor: float = Game.DIFFICULTY_FACTORS.get(Game.setup.get("difficulty", "Normal"), 1.0)
	var base: int = (int(_def.strength) - 50) * 1200000 if _tier == 1 else (int(_def.strength) - 44) * 400000
	return int(base * factor)

func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var screen_card := UITheme.card()
	center.add_child(screen_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(720, 0)
	screen_card.add_child(box)

	var step := Label.new()
	step.text = "Vertragsgespräch"
	step.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	box.add_child(step)

	# Vereinskopf
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	box.add_child(header)
	header.add_child(UITheme.club_badge(_def.short, Color(_def.color), 62))
	var head_text := VBoxContainer.new()
	head_text.add_theme_constant_override("separation", 0)
	head_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(head_text)
	var club_name := Label.new()
	club_name.text = _def.name
	club_name.add_theme_font_size_override("font_size", 30)
	head_text.add_child(club_name)
	var club_sub := Label.new()
	club_sub.text = "%s  ·  %s (%s Plätze)" % [
		"Erste Liga" if _tier == 1 else "Zweite Liga", _def.stadium, Fmt.thousands(int(_def.capacity))]
	club_sub.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	head_text.add_child(club_sub)

	# Vereinsdetails
	var details := GridContainer.new()
	details.columns = 2
	details.add_theme_constant_override("h_separation", 24)
	details.add_theme_constant_override("v_separation", 8)
	box.add_child(details)
	details.add_child(_dim_label("Teamstärke:"))
	var strength_row := HBoxContainer.new()
	strength_row.add_theme_constant_override("separation", 10)
	var bar := ProgressBar.new()
	bar.min_value = 45
	bar.max_value = 90
	bar.value = int(_def.strength)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(220, 16)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	strength_row.add_child(bar)
	strength_row.add_child(_value_label("~%d" % int(_def.strength)))
	details.add_child(strength_row)
	details.add_child(_dim_label("Vereinsbudget:"))
	details.add_child(_value_label(Fmt.money(_budget())))

	box.add_child(HSeparator.new())

	# Angebot des Vorstands
	var offer_heading := Label.new()
	offer_heading.text = "Das Angebot des Vorstands"
	offer_heading.add_theme_font_size_override("font_size", 22)
	offer_heading.add_theme_color_override("font_color", UITheme.ACCENT)
	box.add_child(offer_heading)

	var offer := GridContainer.new()
	offer.columns = 2
	offer.add_theme_constant_override("h_separation", 24)
	offer.add_theme_constant_override("v_separation", 10)
	box.add_child(offer)
	offer.add_child(_dim_label("Trainergehalt:"))
	_salary_label = _value_label("")
	_salary_label.add_theme_font_size_override("font_size", 21)
	offer.add_child(_salary_label)
	offer.add_child(_dim_label("Vertragslaufzeit:"))
	_years_select = OptionButton.new()
	for years in [1, 2, 3]:
		_years_select.add_item("%d Jahr%s" % [years, "" if years == 1 else "e"])
	_years_select.select(1)
	offer.add_child(_years_select)
	offer.add_child(_dim_label("Saisonziel:"))
	offer.add_child(_value_label(_goal().text))

	# Nachverhandeln
	var negotiate_row := HBoxContainer.new()
	negotiate_row.add_theme_constant_override("separation", 10)
	box.add_child(negotiate_row)
	_demand_select = OptionButton.new()
	for demand in DEMANDS:
		_demand_select.add_item(demand.label)
	negotiate_row.add_child(_demand_select)
	_negotiate_button = Button.new()
	_negotiate_button.pressed.connect(_on_negotiate)
	negotiate_row.add_child(_negotiate_button)
	_message = Label.new()
	_message.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	negotiate_row.add_child(_message)

	# Aktionen
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	box.add_child(buttons)
	var back := Button.new()
	back.text = "← Zurück"
	back.custom_minimum_size = Vector2(160, 48)
	back.pressed.connect(func():
		get_tree().change_scene_to_file(Game.setup.get("origin_scene", "res://scenes/vereinswahl.tscn")))
	buttons.add_child(back)
	var sign := Button.new()
	sign.text = "✍ Vertrag unterschreiben"
	sign.custom_minimum_size = Vector2(280, 48)
	sign.add_theme_font_size_override("font_size", 20)
	UITheme.make_primary(sign)
	sign.pressed.connect(_on_sign)
	buttons.add_child(sign)

	_update_labels()

func _dim_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	return l

func _value_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l

func _update_labels() -> void:
	_salary_label.text = "%s pro Monat" % Fmt.money(_salary)
	_negotiate_button.text = "Gegenangebot stellen (%d Versuch%s übrig)" % [_attempts, "" if _attempts == 1 else "e"]
	_negotiate_button.disabled = _attempts <= 0

func _on_negotiate() -> void:
	if _attempts <= 0:
		return
	_attempts -= 1
	var pct: float = DEMANDS[_demand_select.selected].pct
	var chance := 0.65 - pct * 1.1
	if Game.setup.get("mode", "") == "vereinsauswahl":
		chance += 0.1   # In der freien Vereinswahl will der Verein dich unbedingt
	if randf() < chance:
		_salary = int(_salary * (1.0 + pct) / 1000.0) * 1000
		_message.text = "Der Vorstand akzeptiert dein Gegenangebot!"
		_message.add_theme_color_override("font_color", UITheme.ACCENT)
	else:
		_message.text = "Abgelehnt – der Vorstand bleibt bei seinem Angebot."
		_message.add_theme_color_override("font_color", UITheme.DANGER)
	_update_labels()

func _on_sign() -> void:
	Game.setup["coach_salary"] = _salary
	Game.setup["coach_years"] = _years_select.selected + 1
	Game.setup["season_goal"] = _goal()
	Game.new_game(_club_id)
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
