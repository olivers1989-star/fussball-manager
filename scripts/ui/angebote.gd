extends Control
## Spielstart, Schritt 3/3 (Echte Karriere): Angebote kleiner Zweitligisten.
## Jedes Angebot passt zum Verein: Der Vorstand schreibt dir passend zum
## Vereinscharakter (schlafender Riese / Abstiegskampf / Ausbildungsverein),
## mit vereinsgerechtem Gehalt, Laufzeit und Saisonziel.

## Vorstands-Botschaften je Vereinscharakter (%s = Stadt bzw. Vereinsdetails).
const QUOTES_GIANT := [
	"Dieser Verein gehört nicht in die Zweite Liga. %s Zuschauer warten jeden Spieltag darauf, dass jemand diesen Riesen wachküsst. Trauen Sie sich das zu?",
	"Tradition, volle Ränge, riesige Erwartungen – und trotzdem Liga zwei. Wir suchen jemanden, der den Druck im %s aushält.",
]
const QUOTES_RELEGATION := [
	"Ich will ehrlich sein: Bei uns geht es ums nackte Überleben. Wir brauchen einen Kämpfer, der %s vor dem Absturz bewahrt.",
	"Kleines Budget, enge Kabine, treue Fans – mehr haben wir in %s nicht zu bieten. Aber wer uns rettet, wird hier nie wieder vergessen.",
]
const QUOTES_ACADEMY := [
	"Wir sind ein Ausbildungsverein: Bei uns bekommen junge Spieler und junge Trainer ihre Chance. In %s können Sie in Ruhe wachsen.",
	"Keine Wunder nötig – wir wollen solide Arbeit, kluge Entwicklung und mutigen Fußball. %s ist ein guter Ort, um eine Karriere zu starten.",
]

func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	box.add_child(WizardUI.step_header(3, "Deine ersten Angebote",
		"%s · Echte Karriere · Schwierigkeit %s — als unbekannter Trainer klopfen nur kleine Zweitligisten an." % [
			Game.setup.get("name", "?"), Game.setup.get("difficulty", "Normal")]))

	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 18)
	box.add_child(cards)
	for club_id in _offers():
		cards.add_child(_offer_card(club_id))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	var back := Button.new()
	back.text = "← Zurück"
	back.custom_minimum_size = Vector2(160, 46)
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

## Vereinscharakter: bestimmt Ton der Botschaft, Laufzeit und Ambition.
func _character(def: Dictionary) -> String:
	if int(def.capacity) >= 45000:
		return "giant"
	var weaker := 0
	for d in Data.club_defs:
		if int(d.league) == 2 and int(d.strength) < int(def.strength):
			weaker += 1
	return "relegation" if weaker <= 2 else "academy"

func _offer_card(club_id: int) -> PanelContainer:
	var def: Dictionary = Data.club_defs[club_id - 1]
	var character := _character(def)
	var factor: float = Game.DIFFICULTY_FACTORS.get(Game.setup.get("difficulty", "Normal"), 1.0)
	var chairman: String = def.get("chairman", "Der Vorstand")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(def.name)

	var panel := PanelContainer.new()
	var sb := UITheme.box(UITheme.SURFACE, 14, UITheme.BORDER)
	sb.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(390, 0)
	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 0)
	panel.add_child(card_box)

	# Kopfband in Vereinsfarbe
	var band := PanelContainer.new()
	var band_style := UITheme.box(Color(def.color).darkened(0.45), 0)
	band_style.corner_radius_top_left = 14
	band_style.corner_radius_top_right = 14
	band_style.set_content_margin_all(14)
	band.add_theme_stylebox_override("panel", band_style)
	card_box.add_child(band)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	band.add_child(header)
	header.add_child(UITheme.club_badge(def.short, Color(def.color), 50))
	var head_text := VBoxContainer.new()
	head_text.add_theme_constant_override("separation", 0)
	head_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(head_text)
	var club_name := Label.new()
	club_name.text = def.name
	club_name.add_theme_font_size_override("font_size", 18)
	club_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	club_name.custom_minimum_size = Vector2(250, 0)
	head_text.add_child(club_name)
	var league_label := Label.new()
	league_label.text = "Zweite Liga · %s" % def.city
	league_label.add_theme_font_size_override("font_size", 12)
	league_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	head_text.add_child(league_label)

	# Inhalt
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 9)
	var body_margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		body_margin.add_theme_constant_override(side, 16)
	body_margin.add_child(body)
	card_box.add_child(body_margin)

	# Persönliche Botschaft des Vorstands (passend zum Vereinscharakter)
	var quote_panel := PanelContainer.new()
	quote_panel.add_theme_stylebox_override("panel", UITheme.box(UITheme.FIELD, 10, UITheme.BORDER, 12))
	body.add_child(quote_panel)
	var quote_box := VBoxContainer.new()
	quote_box.add_theme_constant_override("separation", 4)
	quote_panel.add_child(quote_box)
	var quote := Label.new()
	var pool: Array
	var fill: String
	match character:
		"giant":
			pool = QUOTES_GIANT
			fill = Fmt.thousands(int(def.capacity)) if rng.randi() % 2 == 0 else def.stadium
			quote.text = pool[rng.randi() % pool.size()] % fill
		"relegation":
			pool = QUOTES_RELEGATION
			quote.text = pool[rng.randi() % pool.size()] % def.city
		_:
			pool = QUOTES_ACADEMY
			quote.text = pool[rng.randi() % pool.size()] % def.city
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote.add_theme_font_size_override("font_size", 13)
	quote.custom_minimum_size = Vector2(330, 0)
	quote_box.add_child(quote)
	var quote_by := Label.new()
	quote_by.text = "— %s, Vorstandsvorsitzender" % chairman
	quote_by.add_theme_font_size_override("font_size", 12)
	quote_by.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	quote_box.add_child(quote_by)

	var tag_row := HBoxContainer.new()
	tag_row.add_theme_constant_override("separation", 6)
	body.add_child(tag_row)
	match character:
		"giant":
			tag_row.add_child(UITheme.mini_pill("SCHLAFENDER RIESE", Color("#7c2d12"), Color.WHITE, 130))
		"relegation":
			tag_row.add_child(UITheme.mini_pill("ABSTIEGSKAMPF", Color("#7f1d1d"), Color.WHITE, 110))
		_:
			tag_row.add_child(UITheme.mini_pill("AUSBILDUNGSVEREIN", Color("#14532d"), Color.WHITE, 130))
	tag_row.add_child(UITheme.mini_pill("Stärke ~%d" % int(def.strength), Color("#1e293b"), Color.WHITE, 80))

	var offer_years := 1 if character == "relegation" else (2 if character == "academy" else 2)
	body.add_child(_detail_row("🏟 Stadion", "%s (%s Plätze)" % [def.stadium, Fmt.thousands(int(def.capacity))]))
	body.add_child(_detail_row("💰 Budget", Fmt.money(int((int(def.strength) - 44) * 400000 * factor))))
	body.add_child(_detail_row("📄 Gehaltsangebot", "~%s/Monat · %d Jahr%s" % [Fmt.money(Game.board_salary(int(def.strength))), offer_years, "" if offer_years == 1 else "e"]))
	body.add_child(_detail_row("🎯 Saisonziel", _goal_text(def)))

	var talk := Button.new()
	talk.text = "Zum Vertragsgespräch  →"
	UITheme.make_primary(talk)
	talk.pressed.connect(_on_talk.bind(club_id))
	body.add_child(talk)
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
	var k := Label.new()
	k.text = key
	k.add_theme_font_size_override("font_size", 13)
	k.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	k.custom_minimum_size = Vector2(130, 0)
	row.add_child(k)
	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 14)
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	return row

func _on_talk(club_id: int) -> void:
	Game.setup["club_id"] = club_id
	Game.setup["origin_scene"] = "res://scenes/angebote.tscn"
	get_tree().change_scene_to_file("res://scenes/verhandlung.tscn")
