extends Control
## Spielstart, Schritt 3/3: Verein auswählen und Karriere starten.

var _club_tree: Tree
var _start_button: Button
var _info_label: Label

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 60)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var step := Label.new()
	step.text = "Schritt 3 von 3  ·  %s (%s)  ·  Vereinsauswahl  ·  Schwierigkeit: %s" % [
		Game.setup.get("name", "?"), Game.setup.get("nat", "?"), Game.setup.get("difficulty", "Normal")]
	step.add_theme_color_override("font_color", Color("#64748b"))
	box.add_child(step)

	var title := Label.new()
	title.text = "Wähle deinen Verein"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("#4ade80"))
	box.add_child(title)

	_club_tree = Tree.new()
	_club_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_club_tree.columns = 4
	_club_tree.column_titles_visible = true
	_club_tree.set_column_title(0, "Verein")
	_club_tree.set_column_title(1, "Stadion")
	_club_tree.set_column_title(2, "Stärke")
	_club_tree.set_column_title(3, "Budget (Normal)")
	_club_tree.hide_root = true
	_club_tree.item_selected.connect(_on_club_selected)
	box.add_child(_club_tree)
	_fill_clubs()

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	box.add_child(bottom)
	var back := Button.new()
	back.text = "← Zurück"
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/spielmodus.tscn"))
	bottom.add_child(back)
	_start_button = Button.new()
	_start_button.text = "Zum Vertragsgespräch →"
	_start_button.add_theme_font_size_override("font_size", 20)
	UITheme.make_primary(_start_button)
	_start_button.disabled = true
	_start_button.pressed.connect(_on_start)
	bottom.add_child(_start_button)
	_info_label = Label.new()
	_info_label.add_theme_color_override("font_color", Color("#94a3b8"))
	bottom.add_child(_info_label)

func _fill_clubs() -> void:
	var root := _club_tree.create_item()
	# Die Regionalliga ist Unterbau – dort kann man keinen Posten übernehmen
	for league_def in Data.LEAGUE_DEFS:
		if not bool(league_def.playable):
			continue
		var league_no := int(league_def.id)
		var parent := _club_tree.create_item(root)
		parent.set_text(0, str(league_def.name))
		parent.set_selectable(0, false)
		parent.set_custom_color(0, Color("#4ade80"))
		for i in Data.club_defs.size():
			var def: Dictionary = Data.club_defs[i]
			if int(def.league) != league_no:
				continue
			if str(def.get("parent", "")) != "":
				continue   # Zweitmannschaften kann man nicht übernehmen
			var item := _club_tree.create_item(parent)
			item.set_text(0, def.name)
			item.set_custom_color(0, Color(def.color))
			item.set_text(1, "%s (%s Plätze)" % [def.stadium, Fmt.thousands(int(def.capacity))])
			item.set_text(2, "~%d" % int(def.strength))
			var budget: int = (int(def.strength) - 50) * 1200000 if league_no == 1 \
				else ((int(def.strength) - 44) * 400000 if league_no == 2 else maxi((int(def.strength) - 38) * 150000, 400000))
			item.set_text(3, Fmt.money(budget))
			# Feste Vereins-ID aus den Stammdaten – NICHT die Listenposition
			# (seit dem Vereinsumbau sind IDs nicht mehr positionsgebunden)
			item.set_metadata(0, int(def.get("id", i + 1)))

func _on_club_selected() -> void:
	var item := _club_tree.get_selected()
	_start_button.disabled = item == null or item.get_metadata(0) == null
	if item != null and item.get_metadata(0) != null:
		_info_label.text = "Ausgewählt: %s" % item.get_text(0)

func _on_start() -> void:
	var item := _club_tree.get_selected()
	if item == null or item.get_metadata(0) == null:
		return
	Game.setup["club_id"] = int(item.get_metadata(0))
	Game.setup["origin_scene"] = "res://scenes/vereinswahl.tscn"
	get_tree().change_scene_to_file("res://scenes/verhandlung.tscn")
