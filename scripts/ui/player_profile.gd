class_name PlayerProfileDialog
extends AcceptDialog
## Spielerprofil: per Rechtsklick auf einen Spieler zu öffnen.
## Zeigt Attribute als Balken, Zustand, Vertrag und Saisonstatistik.

const GROUP_COLORS := {"TW": Color("#7c3aed"), "AB": Color("#2563eb"), "MF": Color("#16a34a"), "ST": Color("#dc2626")}

static func pos_color(pos: String) -> Color:
	return GROUP_COLORS[PlayerData.GROUP_OF[pos]]

var _pos_pill: Label
var _name_label: Label
var _club_label: Label
var _info := {}          # key -> Label
var _state_bars := {}    # key -> {bar, label}
var _attr_bars := {}     # key -> {bar, label}

var _tw_column: VBoxContainer

func _init() -> void:
	title = "Spielerprofil"
	ok_button_text = "Schließen"
	min_size = Vector2i(1240, 620)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)
	_pos_pill = UITheme.pill("ZM", GROUP_COLORS.MF)
	_pos_pill.add_theme_font_size_override("font_size", 18)
	header.add_child(_pos_pill)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 28)
	header.add_child(_name_label)
	_club_label = Label.new()
	_club_label.add_theme_font_size_override("font_size", 17)
	_club_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_club_label)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	box.add_child(columns)

	# Linke Spalte: Infos + Zustand
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size = Vector2(360, 0)
	columns.add_child(left)

	left.add_child(_section("Spieler & Vertrag"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	left.add_child(grid)
	for entry in [["age", "Alter"], ["strength", "Gesamtstärke"], ["talent", "Talent"], ["contract", "Vertrag"], ["salary", "Gehalt"],
		["value", "Marktwert"], ["status", "Status"]]:
		var key := Label.new()
		key.text = entry[1] + ":"
		key.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		grid.add_child(key)
		var value := Label.new()
		value.add_theme_font_size_override("font_size", 17)
		grid.add_child(value)
		_info[entry[0]] = value

	left.add_child(_section("Saison"))
	var season_grid := GridContainer.new()
	season_grid.columns = 2
	season_grid.add_theme_constant_override("h_separation", 18)
	season_grid.add_theme_constant_override("v_separation", 6)
	left.add_child(season_grid)
	for entry in [["matches", "Einsätze"], ["goals", "Tore"], ["cards", "Gelb/Rot"], ["rating", "Ø Note"]]:
		var key := Label.new()
		key.text = entry[1] + ":"
		key.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		season_grid.add_child(key)
		var value := Label.new()
		value.add_theme_font_size_override("font_size", 17)
		season_grid.add_child(value)
		_info[entry[0]] = value

	left.add_child(_section("Zustand"))
	for entry in [["condition", "Frische"], ["form", "Form"], ["stamina", "Ausdauer"]]:
		left.add_child(_bar_row(entry[0], entry[1], _state_bars))

	# Attribut-Spalten: Technisch / Mental / Physisch (+ Torwart)
	for category in ["Technisch", "Mental", "Physisch"]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(col)
		col.add_child(_section(category))
		for key in PlayerData.CATEGORIES[category]:
			col.add_child(_bar_row(key, PlayerData.ATTRIBUTES[key], _attr_bars))
		if category == "Physisch":
			_tw_column = VBoxContainer.new()
			_tw_column.add_theme_constant_override("separation", 8)
			col.add_child(_tw_column)
			_tw_column.add_child(_section("Torwart"))
			for key in PlayerData.CATEGORIES.Torwart:
				_tw_column.add_child(_bar_row(key, PlayerData.ATTRIBUTES[key], _attr_bars))

func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", UITheme.ACCENT)
	return l

func _bar_row(key: String, label_text: String, store: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(130, 0)
	name_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	row.add_child(name_label)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(180, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(44, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	store[key] = {"bar": bar, "label": value_label}
	return row

func _set_bar(store: Dictionary, key: String, value: float, text: String, max_value := 100.0) -> void:
	var entry: Dictionary = store[key]
	entry.bar.max_value = max_value
	entry.bar.value = value
	entry.label.text = text
	var ratio := value / max_value
	var color := UITheme.ACCENT
	if ratio < 0.45:
		color = UITheme.DANGER
	elif ratio < 0.62:
		color = UITheme.WARN
	entry.bar.add_theme_stylebox_override("fill", UITheme.box(color, 6))

## Füllt das Profil mit den Daten des Spielers und öffnet das Fenster.
func open_for(pid: int) -> void:
	var p: PlayerData = Game.world.players[pid]
	var club := Game.club(p.club_id)
	title = "Spielerprofil – %s (%s)" % [p.full_name(), PlayerData.POSITION_NAMES[p.pos]]
	_pos_pill.text = p.pos
	_pos_pill.add_theme_stylebox_override("normal", UITheme.box(pos_color(p.pos), 999))
	_name_label.text = p.full_name()
	_club_label.text = club.name
	_club_label.add_theme_color_override("font_color", Color(club.color))

	_info.age.text = "%d Jahre" % p.age
	_info.strength.text = str(p.strength)
	_info.talent.text = p.talent_stars()
	_info.talent.add_theme_color_override("font_color", UITheme.WARN if p.talent >= 4 else UITheme.TEXT)
	_info.contract.text = "bis %s" % Game.contract_until(p)
	_info.salary.text = "%s/Monat" % Fmt.money(p.salary)
	_info.value.text = Fmt.money(p.market_value())
	if p.is_injured():
		_info.status.text = "Verletzt (%d Sp.)" % p.injury_matchdays
		_info.status.add_theme_color_override("font_color", UITheme.DANGER)
	elif p.is_suspended():
		_info.status.text = "Gesperrt (%d Sp.)" % p.suspended_matchdays
		_info.status.add_theme_color_override("font_color", UITheme.WARN)
	else:
		_info.status.text = "fit"
		_info.status.add_theme_color_override("font_color", UITheme.ACCENT)
	_info.matches.text = str(p.matches_season)
	_info.goals.text = str(p.goals_season)
	_info.cards.text = "%d / %d" % [p.yellow_cards, p.red_cards]
	_info.rating.text = ("%.1f" % p.avg_rating()).replace(".", ",") if p.matches_season > 0 else "–"

	_set_bar(_state_bars, "condition", p.condition, "%d%%" % int(p.condition))
	_set_bar(_state_bars, "form", (p.form - 0.8) / 0.4 * 100.0, Fmt.form_str(p.form))
	_set_bar(_state_bars, "stamina", p.stamina, str(p.stamina))
	for key in PlayerData.ATTRIBUTES:
		_set_bar(_attr_bars, key, p.attr(key), str(p.attr(key)))
	# Torwart-Spezialwerte nur beim Torwart zeigen
	_tw_column.visible = p.pos == "TW"
	popup_centered()