class_name TabSpielplan
extends TabBase
## Kompletter Saison-Spielplan des eigenen Vereins.

var _tree: Tree

func _init() -> void:
	super()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(heading("Mein Spielplan"))
	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	setup_columns(_tree, ["Spieltag", "Ort", "Gegner", "Ergebnis"], 2)
	box.add_child(_tree)

func refresh() -> void:
	var c := Game.my_club()
	_tree.clear()
	var root := _tree.create_item()
	for f in Game.my_league().fixtures_of_club(c.id):
		var home := int(f.home) == c.id
		var opponent := Game.club(int(f.away) if home else int(f.home))
		var item := _tree.create_item(root)
		item.set_text(0, str(int(f.round) + 1))
		item.set_text(1, "Heim" if home else "Auswärts")
		item.set_text(2, opponent.name)
		if f.played:
			var my_goals: int = int(f.hg) if home else int(f.ag)
			var their_goals: int = int(f.ag) if home else int(f.hg)
			item.set_text(3, "%d:%d" % [int(f.hg), int(f.ag)])
			var color := Color("#4ade80") if my_goals > their_goals else (Color("#e2e8f0") if my_goals == their_goals else Color("#f87171"))
			item.set_custom_color(3, color)
		else:
			item.set_text(3, "–")
		if int(f.round) == Game.matchday():
			for col in 4:
				item.set_custom_color(col, Color("#facc15"))
