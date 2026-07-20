class_name TabBase
extends MarginContainer
## Basisklasse für alle Tabs der Manager-Zentrale.
## Statischer Aufbau in _init/_build, Daten-Aktualisierung in refresh().

func _init() -> void:
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		add_theme_constant_override(side, 16)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func refresh() -> void:
	pass

func notify_world_changed() -> void:
	# Der Hub aktualisiert daraufhin die Kopfzeile (Budget etc.)
	get_tree().call_group("hub", "update_topbar")

static func heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color("#4ade80"))
	return l

static func info_label() -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", Color("#94a3b8"))
	return l

static func setup_columns(tree: Tree, titles: Array, expand_col: int) -> void:
	tree.columns = titles.size()
	tree.column_titles_visible = true
	tree.hide_root = true
	for i in titles.size():
		tree.set_column_title(i, titles[i])
		tree.set_column_expand(i, i == expand_col)
		if i != expand_col:
			tree.set_column_custom_minimum_width(i, 90)
