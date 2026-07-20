class_name TabFinanzen
extends TabBase
## Finanzübersicht: Budget, laufende Kosten/Einnahmen und Transaktionshistorie.

var _summary: Label
var _tree: Tree

func _init() -> void:
	super()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(heading("Finanzen"))
	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 18)
	box.add_child(_summary)
	box.add_child(heading("Letzte Buchungen"))
	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	setup_columns(_tree, ["Spieltag", "Buchung", "Betrag"], 1)
	_tree.set_column_custom_minimum_width(2, 140)
	box.add_child(_tree)

func refresh() -> void:
	var c := Game.my_club()
	var salaries_month := c.salaries_per_month(Game.world.players)
	_summary.text = "Budget: %s    ·    Gehälter: %s/Monat (%s je Spieltag)    ·    Sponsor %s: %s je Spieltag    ·    %s: %s Plätze" % [
		Fmt.money(c.budget),
		Fmt.money(salaries_month),
		Fmt.money(c.salaries_per_matchday(Game.world.players)),
		c.sponsor_name,
		Fmt.money(c.sponsor_per_md),
		c.stadium,
		Fmt.thousands(c.capacity),
	]
	_tree.clear()
	var root := _tree.create_item()
	for i in mini(60, Game.transactions.size()):
		var tx: Dictionary = Game.transactions[i]
		var item := _tree.create_item(root)
		item.set_text(0, "S%d, ST %d" % [int(tx.season) % 100, int(tx.matchday)])
		item.set_text(1, tx.text)
		item.set_text(2, Fmt.money(int(tx.amount)))
		item.set_custom_color(2, Color("#4ade80") if int(tx.amount) >= 0 else Color("#f87171"))
