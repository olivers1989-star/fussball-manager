extends Control
## Spielstart, Schritt 3/3 (Echte Karriere): Angebote kleiner Zweitligisten
## als Detail-Karten. Ein Klick führt ins Vertragsgespräch.

func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	var step := Label.new()
	step.text = "Schritt 3 von 3  ·  %s  ·  Echte Karriere  ·  Schwierigkeit: %s" % [
		Game.setup.get("name", "?"), Game.setup.get("difficulty", "Normal")]
	step.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	box.add_child(step)

	var title := Label.new()
	title.text = "Deine ersten Angebote"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Als unbekannter Trainer klopfen nur kleine Zweitligisten an. Wähle dein Vertragsgespräch:"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	box.add_child(subtitle)

	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 20)
	box.add_child(cards)
	for club_id in _offers():
		cards.add_child(_offer_card(club_id))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	var back := Button.new()
	back.text = "← Zurück"
	back.custom_minimum_size = Vector2(160, 48)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/spielmodus.tscn"))
	buttons.add_child(back)

## Drei zufällige Vereine aus den acht schwächsten der Zweiten Liga.
## Bleiben beim Vor-/Zurücknavigieren dieselben (in Game.setup gemerkt).
func _offers() -> Array:
	if Game.setup.has("initial_offers"):
		return Game.setup.initial_offers
	var second_league: Array = []
	for i in Data.club_defs.size():
		if int(Data.club_defs[i].league) == 2:
			second_league.append({"club_id": i + 1, "strength": int(Data.club_defs[i].strength)})
	second_league.sort_custom(func(a, b): return a.strength < b.strength)
	var weakest := second_league.slice(0, 8)
	weakest.shuffle()
	var offers: Array = weakest.slice(0, 3).map(func(entry): return entry.club_id)
	Game.setup["initial_offers"] = offers
	return offers

func _offer_card(club_id: int) -> PanelContainer:
	var def: Dictionary = Data.club_defs[club_id - 1]
	var factor: float = Game.DIFFICULTY_FACTORS.get(Game.setup.get("difficulty", "Normal"), 1.0)
	var budget := int((int(def.strength) - 44) * 400000 * factor)

	var panel := UITheme.card()
	panel.custom_minimum_size = Vector2(360, 0)
	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 10)
	panel.add_child(card_box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	card_box.add_child(header)
	header.add_child(UITheme.club_badge(def.short, Color(def.color), 52))
	var head_text := VBoxContainer.new()
	head_text.add_theme_constant_override("separation", 0)
	head_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(head_text)
	var club_name := Label.new()
	club_name.text = def.name
	club_name.add_theme_font_size_override("font_size", 19)
	club_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	club_name.custom_minimum_size = Vector2(240, 0)
	head_text.add_child(club_name)
	var league_label := Label.new()
	league_label.text = "Zweite Liga"
	league_label.add_theme_font_size_override("font_size", 13)
	league_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	head_text.add_child(league_label)

	card_box.add_child(HSeparator.new())

	var strength_row := HBoxContainer.new()
	strength_row.add_theme_constant_override("separation", 10)
	card_box.add_child(strength_row)
	strength_row.add_child(_dim("Teamstärke"))
	var bar := ProgressBar.new()
	bar.min_value = 45
	bar.max_value = 90
	bar.value = int(def.strength)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(120, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	strength_row.add_child(bar)
	strength_row.add_child(_val("~%d" % int(def.strength)))

	card_box.add_child(_detail_row("Stadion", "%s (%s)" % [def.stadium, Fmt.thousands(int(def.capacity))]))
	card_box.add_child(_detail_row("Budget", Fmt.money(budget)))
	card_box.add_child(_detail_row("Gehaltsangebot", "~%s/Monat" % Fmt.money(Game.board_salary(int(def.strength)))))
	card_box.add_child(_detail_row("Saisonziel", _goal_text(def)))

	var talk := Button.new()
	talk.text = "Zum Vertragsgespräch →"
	UITheme.make_primary(talk)
	talk.pressed.connect(_on_talk.bind(club_id))
	card_box.add_child(talk)
	return panel

func _goal_text(def: Dictionary) -> String:
	var stronger := 0
	for d in Data.club_defs:
		if int(d.league) == int(def.league) and int(d.strength) > int(def.strength):
			stronger += 1
	return Game.goal_from_rank(stronger + 1, int(def.league)).text

func _detail_row(key: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var k := _dim(key)
	k.custom_minimum_size = Vector2(110, 0)
	row.add_child(k)
	var v := _val(value)
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	return row

func _dim(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	return l

func _val(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	return l

func _on_talk(club_id: int) -> void:
	Game.setup["club_id"] = club_id
	Game.setup["origin_scene"] = "res://scenes/angebote.tscn"
	get_tree().change_scene_to_file("res://scenes/verhandlung.tscn")
