class_name TabTrainer
extends TabBase
## Trainerprofil im Spiel: persönliche Daten, Vertrag, Konto und Fähigkeiten.

var _name_label: Label
var _personal := {}    # key -> Label
var _contract := {}    # key -> Label
var _career := {}      # key -> Label
var _skill_bars := {}  # key -> ProgressBar
var _skill_values := {}

func _init() -> void:
	super()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	box.add_child(heading("Trainerprofil"))

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 32)
	box.add_child(_name_label)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(columns)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 16)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	left.add_child(_card("Persönliche Daten", _personal, [
		["birthday", "Geburtsdatum"], ["age", "Alter"], ["origin", "Herkunftsort"], ["nat", "Nationalität"]]))
	left.add_child(_card("Karriere", _career, [
		["reputation", "Trainer-Ruf"], ["money", "Kontostand"], ["mode", "Spielmodus"], ["difficulty", "Schwierigkeit"]]))

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 16)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	right.add_child(_card("Vertrag", _contract, [
		["club", "Verein"], ["years", "Restlaufzeit"], ["salary", "Gehalt"],
		["goal", "Saisonziel"], ["goal_bonus", "Erfolgsprämie"], ["win_bonus", "Siegprämie"]]))
	right.add_child(_skills_card())

func _card(title: String, store: Dictionary, rows: Array) -> PanelContainer:
	var panel := UITheme.card()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 20)
	head.add_theme_color_override("font_color", UITheme.ACCENT)
	box.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for row in rows:
		var key := Label.new()
		key.text = row[1] + ":"
		key.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		key.custom_minimum_size = Vector2(140, 0)
		grid.add_child(key)
		var value := Label.new()
		value.add_theme_font_size_override("font_size", 18)
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(value)
		store[row[0]] = value
	return panel

func _skills_card() -> PanelContainer:
	var panel := UITheme.card()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var head := Label.new()
	head.text = "Fähigkeiten"
	head.add_theme_font_size_override("font_size", 20)
	head.add_theme_color_override("font_color", UITheme.ACCENT)
	box.add_child(head)
	for key in Game.SKILLS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		var skill_name := Label.new()
		skill_name.text = Game.SKILLS[key]
		skill_name.custom_minimum_size = Vector2(130, 0)
		skill_name.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		row.add_child(skill_name)
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = Game.SKILL_MAX
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(180, 16)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		_skill_bars[key] = bar
		var value := Label.new()
		value.custom_minimum_size = Vector2(50, 0)
		row.add_child(value)
		_skill_values[key] = value
	return panel

func refresh() -> void:
	_name_label.text = Game.manager_name
	var bd := Game.manager_birthday
	_personal.birthday.text = "%02d.%02d.%d" % [int(bd.day), int(bd.month), int(bd.year)]
	_personal.age.text = "%d Jahre" % Game.manager_age()
	_personal.origin.text = Game.manager_origin if not Game.manager_origin.is_empty() else "–"
	_personal.nat.text = Game.manager_nat

	_career.reputation.text = str(int(Game.reputation))
	_career.money.text = Fmt.money(Game.coach_money)
	_career.mode.text = "Echte Karriere" if Game.game_mode == "angebote" else "Vereinsauswahl"
	_career.difficulty.text = Game.difficulty

	var c := Game.my_club()
	_contract.club.text = c.name
	_contract.club.add_theme_color_override("font_color", Color(c.color))
	_contract.years.text = "%d Jahr%s" % [Game.coach_contract_years, "" if Game.coach_contract_years == 1 else "e"]
	_contract.salary.text = "%s pro Monat" % Fmt.money(Game.coach_salary)
	_contract.goal.text = Game.season_goal.get("text", "–")
	_contract.goal_bonus.text = Fmt.money(Game.goal_bonus)
	_contract.win_bonus.text = "%s pro Sieg" % Fmt.money(Game.win_bonus)

	for key in Game.SKILLS:
		_skill_bars[key].value = Game.skill(key)
		_skill_values[key].text = "%d/%d" % [Game.skill(key), Game.SKILL_MAX]
