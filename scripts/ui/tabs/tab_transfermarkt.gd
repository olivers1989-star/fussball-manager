class_name TabTransfermarkt
extends TabBase
## Transfermarkt: Spieler anderer Vereine kaufen, eigene Spieler verkaufen.

const MARKET_LIMIT := 200

var _pos_filter: OptionButton
var _market_tree: Tree
var _squad_tree: Tree
var _message: Label

func _init() -> void:
	super()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	box.add_child(top)
	top.add_child(heading("Transfermarkt"))
	var filter_label := Label.new()
	filter_label.text = "Position:"
	top.add_child(filter_label)
	_pos_filter = OptionButton.new()
	for entry in ["Alle", "TW", "AB", "MF", "ST"]:
		_pos_filter.add_item(entry)
	_pos_filter.item_selected.connect(func(_i): refresh())
	top.add_child(_pos_filter)
	_message = info_label()
	top.add_child(_message)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 24)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(split)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(left)
	left.add_child(heading("Verfügbare Spieler"))
	_market_tree = Tree.new()
	_market_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	setup_columns(_market_tree, ["Pos.", "Name", "Alter", "Stärke", "Verein", "Preis"], 1)
	_market_tree.set_column_custom_minimum_width(0, 50)
	_market_tree.set_column_custom_minimum_width(4, 140)
	_market_tree.set_column_custom_minimum_width(5, 110)
	left.add_child(_market_tree)
	var buy := Button.new()
	buy.text = "Ausgewählten Spieler kaufen"
	buy.pressed.connect(_on_buy)
	left.add_child(buy)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	right.add_child(heading("Mein Kader (verkaufen)"))
	_squad_tree = Tree.new()
	_squad_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	setup_columns(_squad_tree, ["Pos.", "Name", "Alter", "Stärke", "Marktwert"], 1)
	_squad_tree.set_column_custom_minimum_width(0, 50)
	_squad_tree.set_column_custom_minimum_width(4, 110)
	right.add_child(_squad_tree)
	var sell := Button.new()
	sell.text = "Ausgewählten Spieler verkaufen"
	sell.pressed.connect(_on_sell)
	right.add_child(sell)

func refresh() -> void:
	var wanted_pos := _pos_filter.get_item_text(_pos_filter.selected)
	var candidates: Array = []
	for pid in Game.world.players:
		var p: PlayerData = Game.world.players[pid]
		if p.club_id == Game.my_club_id:
			continue
		if wanted_pos != "Alle" and p.pos != wanted_pos:
			continue
		candidates.append(p)
	candidates.sort_custom(func(a, b): return a.market_value() > b.market_value())

	_market_tree.clear()
	var root := _market_tree.create_item()
	for i in mini(MARKET_LIMIT, candidates.size()):
		var p: PlayerData = candidates[i]
		var item := _market_tree.create_item(root)
		item.set_text(0, p.pos)
		item.set_text(1, p.full_name())
		item.set_text(2, str(p.age))
		item.set_text(3, str(p.strength))
		item.set_text(4, Game.club(p.club_id).name)
		item.set_text(5, Fmt.money(int(p.market_value() * 1.1)))
		item.set_metadata(0, p.id)

	_squad_tree.clear()
	var squad_root := _squad_tree.create_item()
	var squad := Game.my_club().players(Game.world.players)
	squad.sort_custom(func(a, b): return a.market_value() > b.market_value())
	for p in squad:
		var item := _squad_tree.create_item(squad_root)
		item.set_text(0, p.pos)
		item.set_text(1, p.full_name())
		item.set_text(2, str(p.age))
		item.set_text(3, str(p.strength))
		item.set_text(4, Fmt.money(p.market_value()))
		item.set_metadata(0, p.id)

func _on_buy() -> void:
	var item := _market_tree.get_selected()
	if item == null:
		_message.text = "Bitte links einen Spieler auswählen."
		return
	var pid: int = item.get_metadata(0)
	var error := Game.buy_player(pid)
	if error.is_empty():
		_message.text = "%s wurde verpflichtet!" % Game.get_player(pid).full_name()
		notify_world_changed()
		refresh()
	else:
		_message.text = error

func _on_sell() -> void:
	var item := _squad_tree.get_selected()
	if item == null:
		_message.text = "Bitte rechts einen Spieler auswählen."
		return
	var pid: int = item.get_metadata(0)
	var player_name := Game.get_player(pid).full_name()
	var error := Game.sell_player(pid)
	if error.is_empty():
		_message.text = "%s wurde verkauft." % player_name
		notify_world_changed()
		refresh()
	else:
		_message.text = error
