class_name TabKader
extends TabBase
## Kaderübersicht des eigenen Vereins mit allen Spielerdaten.

const POS_ORDER := {"TW": 0, "AB": 1, "MF": 2, "ST": 3}

var _tree: Tree

func _init() -> void:
	super()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(heading("Kader"))
	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	setup_columns(_tree, ["Pos.", "Name", "Alter", "Stärke", "Form", "Frische", "Ausdauer", "Note", "Tore", "Vertrag", "Gehalt", "Marktwert", "Status"], 1)
	_tree.set_column_custom_minimum_width(0, 50)
	for col in [2, 3, 4, 5, 6, 7, 8, 9]:
		_tree.set_column_custom_minimum_width(col, 72)
	_tree.set_column_custom_minimum_width(10, 105)
	_tree.set_column_custom_minimum_width(11, 105)
	_tree.set_column_custom_minimum_width(12, 120)
	box.add_child(_tree)

func refresh() -> void:
	var c := Game.my_club()
	_tree.clear()
	var root := _tree.create_item()
	var squad := c.players(Game.world.players)
	squad.sort_custom(func(a, b):
		if POS_ORDER[a.pos] != POS_ORDER[b.pos]:
			return POS_ORDER[a.pos] < POS_ORDER[b.pos]
		return a.strength > b.strength)
	for p in squad:
		var item := _tree.create_item(root)
		item.set_text(0, p.pos)
		item.set_text(1, p.full_name())
		item.set_text(2, str(p.age))
		item.set_text(3, str(p.strength))
		item.set_text(4, Fmt.form_str(p.form))
		item.set_text(5, "%d%%" % int(p.condition))
		item.set_text(6, str(p.stamina))
		item.set_text(7, ("%.1f" % p.last_rating).replace(".", ",") if p.last_rating > 0.0 else "–")
		item.set_text(8, str(p.goals_season))
		item.set_text(9, "%d J." % p.contract_years)
		item.set_text(10, Fmt.money(p.salary))
		item.set_text(11, Fmt.money(p.market_value()))
		var status := "fit"
		if p.is_injured():
			status = "Verletzt (%d Sp.)" % p.injury_matchdays
		elif p.is_suspended():
			status = "Gesperrt (%d Sp.)" % p.suspended_matchdays
		item.set_text(12, status)
		if c.lineup.has(p.id):
			item.set_custom_color(1, Color("#4ade80"))
		if p.form >= 1.08:
			item.set_custom_color(4, Color("#4ade80"))
		elif p.form <= 0.92:
			item.set_custom_color(4, Color("#f87171"))
		if p.condition <= 60:
			item.set_custom_color(5, Color("#f87171"))
		elif p.condition >= 90:
			item.set_custom_color(5, Color("#4ade80"))
		if p.last_rating > 0.0:
			item.set_custom_color(7, Color("#4ade80") if p.last_rating <= 2.5 else (Color("#f87171") if p.last_rating >= 4.5 else Color("#e2e8f0")))
		if p.is_injured():
			item.set_custom_color(12, Color("#f87171"))
		elif p.is_suspended():
			item.set_custom_color(12, Color("#facc15"))
