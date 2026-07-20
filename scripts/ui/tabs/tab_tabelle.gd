class_name TabTabelle
extends TabBase
## Ligatabelle mit Ligaauswahl. Der eigene Verein wird hervorgehoben.

var _league_select: OptionButton
var _tree: Tree

func _init() -> void:
	super()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	box.add_child(top)
	top.add_child(heading("Tabelle"))
	_league_select = OptionButton.new()
	_league_select.add_item("Erste Liga", 1)
	_league_select.add_item("Zweite Liga", 2)
	_league_select.item_selected.connect(func(_i): refresh())
	top.add_child(_league_select)

	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	setup_columns(_tree, ["#", "Verein", "Spiele", "S", "U", "N", "Tore", "Diff.", "Punkte"], 1)
	_tree.set_column_custom_minimum_width(0, 50)
	box.add_child(_tree)

func select_my_league() -> void:
	_league_select.select(_league_select.get_item_index(Game.my_club().league_id))

func refresh() -> void:
	var lg := Game.league(_league_select.get_selected_id())
	_tree.clear()
	var root := _tree.create_item()
	var rows := lg.table()
	for i in rows.size():
		var row: Dictionary = rows[i]
		var c := Game.club(row.club_id)
		var item := _tree.create_item(root)
		item.set_text(0, str(i + 1))
		item.set_text(1, c.name)
		item.set_text(2, str(row.played))
		item.set_text(3, str(row.won))
		item.set_text(4, str(row.drawn))
		item.set_text(5, str(row.lost))
		item.set_text(6, "%d:%d" % [row.gf, row.ga])
		item.set_text(7, "%+d" % (row.gf - row.ga))
		item.set_text(8, str(row.points))
		if c.id == Game.my_club_id:
			for col in 9:
				item.set_custom_color(col, Color("#4ade80"))
		elif lg.tier == 1 and i >= 15:
			item.set_custom_color(0, Color("#f87171"))
		elif lg.tier == 2 and i < 3:
			item.set_custom_color(0, Color("#60a5fa"))
